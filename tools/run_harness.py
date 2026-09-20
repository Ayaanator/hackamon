"""Exercise source AND deploy files under Lua 5.4/5.5 (pip install lupa).

Mocks check state, images, bounded buffers and widget reuse, not ESP32 memory,
LVGL decoding, timing, USB, or Bluetooth. No physical-badge guarantee.
"""
from pathlib import Path
from lupa import lua54, lua55

ROOT = Path(__file__).resolve().parent.parent
HARNESS = (ROOT / 'tools/harness.lua').read_bytes()


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
        run(engine, directory, 'recipient', files)
        damaged = dict(files)
        del damaged[b's2.bin']
        run(engine, directory, 'missing', damaged)
        run(engine, directory, 'invalid_save', files)
        run(engine, directory, 'no_nfc', files)
print('All 20 scenarios passed.')
