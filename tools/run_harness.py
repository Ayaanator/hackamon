"""Exercise source AND deploy files under Lua 5.4/5.5 (pip install lupa).

Mocks check state, images, bounded buffers and widget reuse, not ESP32 memory,
LVGL decoding, timing, USB, or Bluetooth. No physical-badge guarantee.
"""
from pathlib import Path
from lupa import lua54, lua55

ROOT = Path(__file__).resolve().parent.parent
HARNESS = (ROOT / 'tools/harness.lua').read_bytes()


def check_installed_size(files):
    header, body = (ROOT / 'dist/hackamon.lua').read_bytes().split(b']==]\n', 1)
    text = [header.split(b'\n', 1)[1], body]
    text.extend((ROOT / 'dist' / name).read_bytes() for name in ('battle.lua', 'fx.lua', 'screens.lua', 'gen.lua'))
    total = sum(len(s.replace(b'\n', b'\r\n')) for s in text) + sum(map(len, files.values())) + 5304
    assert total <= 36 * 1024, f'Actual installed bundle over budget: {total}'
    assert len(text) + len(files) + 1 <= 16
    print(f'Actual installed bytes including icon and CRLF: {total}', flush=True)


def run(engine, directory, mode, files=None):
    rt = engine.LuaRuntime(unpack_returned_tuples=True, encoding=None)
    rt.globals().TEST_MODE = mode.encode()
    rt.globals().INPUT_FILES = rt.table_from(files or {})
    fn = rt.eval(b'function(src, dir) return assert(load(src, "=harness"))(dir) end')
    result = fn(HARNESS, directory.as_posix().encode())
    return dict(result[b'files'].items())


for engine in (lua54, lua55):
    for directory in (ROOT, ROOT / 'dist'):
        print(f'Testing {engine.__name__}: {directory.name}', flush=True)
        files = run(engine, directory, 'cold')
        check_installed_size(files)
        run(engine, directory, 'recipient', files)
        damaged = dict(files)
        del damaged[b'p2.bin']
        run(engine, directory, 'missing', damaged)
        run(engine, directory, 'invalid_save', files)
        run(engine, directory, 'no_nfc', files)
        run(engine, directory, 'screen_error')
        run(engine, directory, 'widget_error')
        old = {f'{f}{i}.bin'.encode(): b'old sprite' for f in ('s','m') for i in range(1,5)}
        old.update({b'sprites9.ok': b'9', b'icon.bin': b'keep icon', b'appdata/save': b'keep save'})
        run(engine, directory, 'upgrade', old)
        partial = run(engine, directory, 'interrupted', damaged)
        run(engine, directory, 'recovery', partial)
print('All 40 scenarios passed.')
