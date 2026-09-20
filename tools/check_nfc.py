"""NFC read/retry regressions on Lua 5.4/5.5; optional extra game.lua paths."""
import sys
from pathlib import Path
from lupa import lua54, lua55

ROOT = Path(__file__).resolve().parent.parent
CHECKS = br'''
local source=...
local now,reads,clears,hits,last,enables,logs=0,0,0,0,nil,0,0
local payload,err,present,enabled,pending,deny,enabled_at,in_button,throwing
local text=""
local noop=function() end
local widget={set_text=noop,set_size=noop,align=noop,hidden=noop}
W={EN=widget,EB=widget,EH=widget,PN=widget,PB=widget,PH=widget,MSG=widget,MENU=widget,CUE=widget,BG=widget}
W.MSG={set_text=function(self,s) text=s end,set_size=noop}
PI=widget UI_ROOT={}
badge={sys={ms=function() return now end,gc_step=noop,log=function(s)
  assert(#s<220)
  if s:find("NFC retry:",1,true) then logs=logs+1 else assert(s:find("NFC v3:",1,true)) end end},
  input={BUTTON={A=1,B=2,HOME=3,UP=4,DOWN=5},KIND={PRESSED=1,RELEASED=2}},
  nfc={enable=function()
      assert(not pending,"enable raced deferred disable") assert(not in_button,"NFC started inside button") enables=enables+1
      if throwing then error("injected enable failure") end
      enabled=not deny enabled_at=now return enabled
    end,
    disable=function() pending=true end,
    clear=function() clears=clears+1 present=false end,
    card=function() if present then return {uid="same-tag"} end end,
    read_text=function()
      assert(enabled and now-enabled_at>=200,"read before reader settled")
      reads=reads+1 return payload,err
    end}}
FX={tick=noop,ambient=noop}
BT={encounter=function(i) hits=hits+1 last=i S=3 end}
local M=assert(load(source))()
home=function() S=0 cur=1 act=1 end
local function event(fn,...)
  in_button=fn==M.button fn(...) in_button=false
  if pending then pending=false enabled=false end
end
local function poll(t,e,card,dt)
  payload,err,present=t,e,card~=false now=now+(dt or 200)
  local before=reads event(M.tick) assert(reads-before<=1,"multiple reads in one tick")
end
local function start()
  home() local before=enables event(M.button,1,1)
  assert(S==2 and not enabled and enables==before and text:find("Starting NFC",1,true))
  poll(nil,nil,false,100) assert(enabled)
end
local function restart_ticks()
  local n=enables
  poll(nil,nil,false,100) assert(enables==n,"restart did not wait")
  poll(nil,nil,false,200) assert(enables==n+1)
end
start()
local clear_start=clears
poll(nil,"timeout")
assert(S==2 and hits==0 and text:find("Reading tag",1,true),"failed read labeled invalid")
assert(clears==clear_start,"lost card before retry")
poll("",nil)
assert(clears==clear_start and hits==0,"empty read consumed card")
poll("PKM01",nil)
assert(hits==1 and last==2 and not enabled,"valid retry did not encounter")
for i=1,20 do start() poll("PKM01") assert(last==2 and not enabled) end
start() local n=enables local l=logs
poll(nil,"timeout") poll(" ",nil) poll(nil,"timeout")
assert(not enabled and text:find("Resetting",1,true) and S==2,"no reader recovery")
restart_ticks()
poll("PKM02") assert(last==3 and not enabled and enables==n+1 and logs==l+1)
start() n=reads poll(nil,nil,false) assert(reads==n)
poll("PKM03","timeout") assert(S==2 and enabled)
poll("PKM",nil) assert(S==2 and text:find("Reading tag",1,true),"partial text rejected too soon")
poll("\r\n PKM03\t") assert(last==4 and not enabled,"surrounding whitespace rejected")
-- Invalid data must persist through retries and one recovery before being rejected.
for _,bad in ipairs({"hello","PKM00","PKM99","xPKM01","PKM01x","PKM01\nPKM02"}) do
  start() local before=hits n=enables
  for i=1,3 do poll(bad) end
  restart_ticks()
  for i=1,3 do poll(bad) end
  assert(S==2 and hits==before and text:find("not a",1,true) and enables==n+1,"wrong tag accepted")
  poll("PKM01") assert(hits==before+1,"invalid read blocked next valid tag")
end
-- No endless reader power-cycling or diagnostic spam while a bad tag is held.
start() n=enables l=logs
for i=1,3 do poll(nil,"timeout") end
restart_ticks()
for i=1,30 do poll(nil,"timeout") end
assert(enables==n+1 and logs==l+1 and enabled,"unbounded recovery/logging")
-- A can recover a reader that never detects a tag.
start() poll(nil,nil,false) event(M.button,1,1)
assert(not enabled and S==2) restart_ticks() poll("PKM01") assert(last==2 and not enabled)
-- B, HOME, and exit must cancel a scheduled re-enable.
for _,action in ipairs({"B","HOME","EXIT"}) do
  start() event(M.button,1,1) n=enables
  if action=="B" then event(M.button,2,1)
  elseif action=="HOME" then event(M.button,3,2)
  else event(M.exit) end
  poll(nil,nil,false,1000)
  assert(not enabled and enables==n,"cancelled recovery restarted NFC")
end
-- Failed re-enable leaves a recoverable scanner; A works after the reader returns.
start() event(M.button,1,1) deny=true restart_ticks()
assert(not enabled and S==2 and text:find("unavailable",1,true))
deny=false event(M.button,1,1) restart_ticks() poll("PKM02") assert(last==3 and not enabled)
-- Initial startup must also be cancellable before touching the reader.
for _,action in ipairs({"B","HOME","EXIT"}) do
  home() event(M.button,1,1) n=enables
  if action=="B" then event(M.button,2,1)
  elseif action=="HOME" then event(M.button,3,2) else event(M.exit) end
  poll(nil,nil,false,1000) assert(enables==n and not enabled)
end
-- A returning Lua error must not automatically repeat the native enable call.
home() event(M.button,1,1) throwing=true
local ok,e=pcall(function() poll(nil,nil,false,200) end)
assert(not ok and e:find("injected enable failure",1,true))
n=enables poll(nil,nil,false,1000) assert(enables==n)
event(M.button,2,1) assert(S==0 and not enabled) throwing=false
start() n=reads poll("PKM01",nil,true,100) assert(reads==n,"initial warmup skipped")
poll("PKM01",nil,true,100) assert(last==2 and not enabled)
start() poll("PKM04")
if #P==5 then assert(last==5 and not enabled)
else
  assert(S==2 and enabled) poll("PKM04") poll("PKM04") restart_ticks()
  for i=1,3 do poll("PKM04") end
  assert(S==2 and text:find("not a",1,true),"four-Pokemon roster changed")
end
return true
'''

for engine in (lua54, lua55):
    for path in [ROOT / 'game.lua', ROOT / 'dist/game.lua', *map(Path, sys.argv[1:])]:
        rt = engine.LuaRuntime(encoding=None)
        rt.eval(b'function(test,source) return assert(load(test))(source) end')(CHECKS, path.read_bytes())
        print(f'NFC checks passed: {engine.__name__} {path}')
