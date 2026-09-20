"""NFC read/retry regressions on Lua 5.4/5.5; optional extra game.lua paths."""
import sys
from pathlib import Path
from lupa import lua54, lua55

ROOT = Path(__file__).resolve().parent.parent
CHECKS = br'''
local source=...
local now,reads,clears,hits,last=0,0,0,0,nil
local payload,err,present,enabled
local text=""
local noop=function() end
local widget={set_text=function(self,s) text=s end,set_size=noop,align=noop,hidden=noop}
W={EN=widget,EB=widget,EH=widget,PN=widget,PB=widget,PH=widget,MSG=widget,MENU=widget,CUE=widget,BG=widget}
PI=widget UI_ROOT={}
badge={sys={ms=function() return now end,gc_step=noop},
  input={BUTTON={A=1,B=2,HOME=3,UP=4,DOWN=5},KIND={PRESSED=1,RELEASED=2}},
  nfc={enable=function() enabled=true return true end,
    disable=function() enabled=false end,
    clear=function() clears=clears+1 present=false end,
    card=function() if present then return {uid="same-tag"} end end,
    read_text=function() reads=reads+1 return payload,err end}}
FX={tick=noop,ambient=noop}
BT={encounter=function(i) hits=hits+1 last=i S=3 end}
local M=assert(load(source))()
home=function() S=0 cur=1 end
local function start() home() M.button(1,1) assert(S==2 and enabled) end
local function poll(t,e,card,dt)
  payload,err,present=t,e,card~=false now=now+(dt or 300)
  local before=reads M.tick() assert(reads-before<=1,"multiple reads in one tick")
end
start()
local clear_start=clears
poll(nil,"timeout")
assert(S==2 and hits==0 and text:find("Read incomplete",1,true),"failed read labeled invalid")
assert(clears==clear_start,"lost card before retry")
poll("",nil)
assert(clears==clear_start and hits==0,"empty read consumed card")
poll("PKM01",nil)
assert(hits==1 and last==2 and not enabled,"valid retry did not encounter")
-- Same UID remains usable on every new scan; no permanent seen-tag cache.
for i=1,20 do start() poll("PKM01") assert(last==2 and not enabled) end
start() clear_start=clears
poll(nil,"timeout") poll(" ",nil) poll(nil,"timeout")
assert(clears==clear_start+1 and text:find("Lift tag",1,true) and S==2,"retry batch not bounded")
poll("PKM02") assert(last==3 and not enabled,"retap after retry exhaustion failed")
-- No card, error-with-text, incomplete text, and wrong payload are distinct.
start() local n=reads poll(nil,nil,false) assert(reads==n)
poll("PKM03","timeout") assert(S==2 and enabled)
poll("\r\n PKM03\t") assert(last==4 and not enabled,"surrounding whitespace rejected")
for _,bad in ipairs({"hello","PKM00","PKM99","xPKM01","PKM01x","PKM01\nPKM02"}) do
  start() local before=hits poll(bad)
  assert(S==2 and hits==before and text:find("not a",1,true),"wrong tag accepted")
  poll("PKM01") assert(hits==before+1,"invalid read blocked next valid tag")
end
start() poll(nil,"timeout") n=reads poll(nil,"timeout",true,100)
assert(reads==n,"retry ignored polling interval")
M.button(2,1) assert(not enabled and S==0,"B did not cancel retries")
start() poll(nil,"timeout") M.button(3,2) assert(not enabled and S==0,"HOME did not cancel retries")
start() poll(nil,"timeout") M.exit() assert(not enabled,"exit leaked NFC")
start() poll("PKM04")
assert((#P==5 and last==5 and not enabled) or (#P==4 and S==2 and enabled),"roster bounds changed")
return true
'''

for engine in (lua54, lua55):
    for path in [ROOT / 'game.lua', ROOT / 'dist/game.lua', *map(Path, sys.argv[1:])]:
        rt = engine.LuaRuntime(encoding=None)
        rt.eval(b'function(test,source) return assert(load(test))(source) end')(CHECKS, path.read_bytes())
        print(f'NFC checks passed: {engine.__name__} {path}')
