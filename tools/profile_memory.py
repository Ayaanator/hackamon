"""Compare incremental live Lua bytes on 64-bit host Lua 5.5.

Usage: python tools/profile_memory.py [directory ...]
Flash contents live outside Lua. Shared mocks are subtracted as a baseline.
This measures post-GC live Lua allocations, NOT transient peak, native/LVGL
memory, ESP32 fragmentation or callback time. Use badge logs for those.
"""
import argparse
import json
import subprocess
from pathlib import Path
from lupa import lua55
ROOT = Path(__file__).resolve().parent.parent


def profile(directory, revision=None):
    files, marks = {}, {}
    rt = lua55.LuaRuntime(encoding=None, unpack_returned_tuples=True)
    glob = rt.globals()
    directory = Path(directory).resolve()
    sources = {}
    for name in ('hackamon.lua', 'screens.lua', 'fx.lua', 'battle.lua', 'gen.lua'):
        sources[(directory / name).as_posix().encode()] = (
            subprocess.check_output(['git', 'show', f'{revision}:dist/{name}'], cwd=ROOT)
            if revision else (directory / name).read_bytes()
        )
    glob.READ = lambda path, offset: sources[path][offset:offset+256]
    glob.WRITE = lambda n, data: files.__setitem__(n, data)
    glob.APPEND = lambda n, data: files.__setitem__(n, files.get(n, b'') + data)
    glob.EXISTS = lambda n: n in files
    glob.REMOVE = lambda n: files.pop(n, None) is not None
    glob.MARK = lambda name, used: marks.__setitem__(name.decode(), used)
    fn = rt.execute((ROOT / 'tools/memory_probe.lua').read_bytes())
    fn(Path(directory).resolve().as_posix().encode())
    return marks


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directories', nargs='*')
    parser.add_argument('--compare', help='Git revision containing the baseline dist files')
    args = parser.parse_args()
    if args.compare:
        print(args.compare, json.dumps(profile(ROOT / 'dist', args.compare)))
    for directory in args.directories or [ROOT / 'dist']:
        print(str(directory), json.dumps(profile(directory)))
