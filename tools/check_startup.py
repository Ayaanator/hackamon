"""Bound entry-chunk compilation/execution with Lupa's allocator, and compare art.

These are host Lua checks, not ESP32 RAM, native allocation or timing claims.
The source reader emits 256-byte chunks; the byte strings live in Python.
"""
import subprocess
from pathlib import Path
from lupa import lua54, lua55

ROOT = Path(__file__).resolve().parent.parent
BASELINE = '01cbf93'


def compiles(engine, source, allowance):
    rt = engine.LuaRuntime(encoding=None, max_memory=1024 * 1024)
    rt.globals().READ = lambda offset: source[offset:offset + 256]
    run = rt.eval(b'''function()
      local at=0
      local f,err=load(function()
        local s=READ(at) at=at+#s if #s>0 then return s end
      end,"@main.lua")
      assert(f,err) f()
    end''')
    rt.gccollect()
    baseline = rt.get_memory_used(total=True)
    rt.set_max_memory(baseline + allowance, total=True)
    try:
        run()
        assert rt.globals().on_enter is not None
        return True
    except engine.LuaError as exc:
        if 'memory' not in str(exc).lower() and not isinstance(exc, engine.LuaMemoryError):
            raise
        return False


def render(engine, source):
    rt = engine.LuaRuntime(encoding=None)
    run = rt.eval(b'''function(source)
      local files={}
      function spr(i) return "p"..i..".bin" end
      function valid(i) return files[spr(i)] and #files[spr(i)]==3212 end
      badge={sys={gc_step=function() end},fs={
        read=function(n) return files[n] end,
        exists=function(n) return files[n]~=nil end,
        remove=function(n) files[n]=nil end,
        write=function(n,b) files[n]=b end,
        append=function(n,b) files[n]=files[n]..b end
      }}
      assert(load(source))()
      for i=1,100 do if GEN() then return files end end
      error("generation did not finish")
    end''')
    return dict(run(source).items())


old_main = subprocess.check_output(['git', 'show', f'{BASELINE}:dist/hackamon.lua'], cwd=ROOT)
old_art = subprocess.check_output(['git', 'show', f'{BASELINE}:gen.lua'], cwd=ROOT)
for engine in (lua54, lua55):
    # The old entry chunk cannot compile/execute with this allowance. The new
    # loader must, even with comments/whitespace from the editable source copy.
    assert not compiles(engine, old_main, 24 * 1024), 'baseline unexpectedly fits; reassess the regression budget'
    for directory in (ROOT, ROOT / 'dist'):
        assert compiles(engine, (directory / 'hackamon.lua').read_bytes(), 24 * 1024), 'entry chunk exceeds 24 KiB host allowance'
        sprites = render(engine, (directory / 'gen.lua').read_bytes())
        assert sprites == render(engine, old_art), 'sprite pixels or completion marker changed'
    print(engine.__name__, 'entry chunk fits 24 KiB additional host Lua memory; baseline fails')
print('All four sprites and their marker are byte-identical to', BASELINE)
