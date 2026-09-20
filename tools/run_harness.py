"""Exercise source AND deploy files under Lua 5.4/5.5 (pip install lupa).

Mocks check state, images, bounded buffers and widget reuse, not ESP32 memory,
LVGL decoding, timing, USB, or Bluetooth. No physical-badge guarantee.
"""
from pathlib import Path
from itertools import count
from lupa import lua54, lua55

ROOT = Path(__file__).resolve().parent.parent
HARNESS = (ROOT / 'tools/harness.lua').read_bytes()
SEEDS = count(1)


def check_installed_size(files):
    files = shared(files)
    header, body = (ROOT / 'dist/hackamon.lua').read_bytes().split(b']==]\n', 1)
    text = [header.split(b'\n', 1)[1], body]
    text.extend((ROOT / 'dist' / name).read_bytes() for name in ('game.lua', 'battle.lua', 'fx.lua', 'screens.lua', 'gen.lua'))
    total = sum(len(s.replace(b'\n', b'\r\n')) for s in text) + sum(map(len, files.values())) + 5304
    assert total <= 42 * 1024, f'Actual installed bundle over budget: {total}'
    assert len(text) + len(files) + 1 <= 16
    print(f'Actual installed bytes including icon and CRLF: {total}', flush=True)


def shared(files):
    return {k: v for k, v in files.items() if not k.startswith(b'appdata/')}


def run(engine, directory, mode, files=None, expected=None):
    rt = engine.LuaRuntime(unpack_returned_tuples=True, encoding=None)
    # Separate badges have separate random streams. Lua 5.5 runtimes created in
    # the same clock tick can otherwise start with identical math.random seeds.
    rt.eval(b'math.randomseed')(next(SEEDS))
    rt.globals().TEST_MODE = mode.encode()
    rt.globals().INPUT_FILES = rt.table_from(files or {})
    if expected:
        rt.globals().EXPECT_OWNED, rt.globals().EXPECT_ACT = expected
    fn = rt.eval(b'function(src, dir) return assert(load(src, "=harness"))(dir) end')
    result = fn(HARNESS, directory.as_posix().encode())
    return dict(result[b'files'].items())


for engine in (lua54, lua55):
    for directory in (ROOT, ROOT / 'dist'):
        print(f'Testing {engine.__name__}: {directory.name}', flush=True)
        files = run(engine, directory, 'cold')
        check_installed_size(files)
        old_sprite = dict(files)
        old_sprite.pop(b'sprites11.ok')
        old_sprite[b'sprites10.ok'] = b'10'
        old_sprite[b'p5.bin'] = b'old art' + b'\0' * 3205
        updated = run(engine, directory, 'sprite_upgrade', old_sprite)
        assert b'sprites10.ok' not in updated and updated[b'p5.bin'] != old_sprite[b'p5.bin']
        assert all(updated[f'p{i}.bin'.encode()] == files[f'p{i}.bin'.encode()] for i in range(1,5))
        run(engine, directory, 'recipient', shared(files))
        run(engine, directory, 'scan_exit', files)
        run(engine, directory, 'exists_false', files)
        run(engine, directory, 'exists_false_cold')
        damaged = dict(files)
        del damaged[b'p2.bin']
        run(engine, directory, 'missing', damaged)
        damaged = dict(files)
        damaged[b'p2.bin'] = damaged[b'p2.bin'][:652]
        run(engine, directory, 'short_sprite', damaged)
        run(engine, directory, 'invalid_save', files)
        run(engine, directory, 'no_nfc', files)
        run(engine, directory, 'screen_error')
        run(engine, directory, 'widget_error')
        old = {f'{f}{i}.bin'.encode(): b'old sprite' for f in ('s','m') for i in range(1,5)}
        old.update({b'sprites9.ok': b'9', b'icon.bin': b'keep icon', b'appdata/save': b'keep save'})
        run(engine, directory, 'upgrade', old)
        partial = run(engine, directory, 'interrupted', damaged)
        run(engine, directory, 'recovery', partial)
        for failure in ('write_error', 'marker_error', 'silent_marker', 'silent_append'):
            run(engine, directory, failure)
        for failure in ('title_error', 'game_error', 'battle_error', 'fx_error', 'home_error', 'loading_exit'):
            run(engine, directory, failure, files)
        for failure in ('save_error', 'silent_save', 'transfer_marker_error'):
            run(engine, directory, failure)
        # Each runtime below is a real reopen: no Lua globals/module cache survive.
        donor = run(engine, directory, 'save_capture', shared(files), (1, 1))
        donor_reopen = run(engine, directory, 'save_open', donor, (31, 5))
        assert donor_reopen == donor
        recipient = run(engine, directory, 'save_open', shared(donor), (1, 1))
        assert recipient[b'trainer.id'] != donor[b'trainer.id']
        run(engine, directory, 'save_open', recipient, (1, 1))
        captured = run(engine, directory, 'save_capture', recipient, (1, 1))
        run(engine, directory, 'save_open', captured, (31, 5))
        # Reinstall over an existing recipient, whose private files are preserved.
        received_again = dict(captured)
        received_again.update(shared(donor))
        reset = run(engine, directory, 'save_open', received_again, (1, 1))
        run(engine, directory, 'save_open', reset, (1, 1))
        # Onward sharing and a copy coming back to its original sender.
        onward = run(engine, directory, 'save_open', shared(captured), (1, 1))
        returned = dict(donor)
        returned.update(shared(onward))
        run(engine, directory, 'save_open', returned, (1, 1))
        # Ordinary IDE code updates keep the marker and private collection.
        run(engine, directory, 'save_open', captured, (31, 5))
print('All 156 scenarios passed.')
