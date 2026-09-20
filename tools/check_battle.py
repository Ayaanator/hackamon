"""Deterministic mechanics and deployment-token tests (requires lupa)."""
from pathlib import Path
from lupa import lua54, lua55
from build import compact

ROOT = Path(__file__).resolve().parent.parent
CHECKS = (ROOT / 'tools/battle_checks.lua').read_bytes()
for engine in (lua54, lua55):
    for snippet in (
        'local a=1 local b=2 return a+b',
        'local a=0x1 local b=2 return a+b',
        'local a="two  spaces -- here" return a',
        r'local a="say \"hi\"" return a',
        'return 1 .. "2"',
        'return 1 - -2',
        'return 2 / / 2',  # rejected equally; never becomes floor division
    ):
        rt = engine.LuaRuntime()
        compile_ = rt.eval('function(s) local f=load(s); return f end')
        original, packed = compile_(snippet), compile_(compact(snippet))
        assert bool(original) == bool(packed), snippet
        if original:
            assert original() == packed(), snippet
    for directory in (ROOT, ROOT / 'dist'):
        rt = engine.LuaRuntime(encoding=None)
        rt.eval(b'function(src, dir) return assert(load(src))(dir) end')(CHECKS, directory.as_posix().encode())
print('Mechanics and token checks passed in Lua 5.4/5.5, source/dist.')
