--[==[badge-app
slug=hackamon
name=Hackamon
icon=PKM
api=2
heap_kb=96
wake_lock=1
home_button=1
]==]
-- Small entry chunk: gameplay is not compiled until the title is gone.
BIT={1,2,4,8}
S,act,owned=13,1,1
local TMP,nxt,frame=nil,0,0
function own(i) return (owned//BIT[i])%2==1 end
local function gc() collectgarbage("collect") end
local function gcset(p)
  if _VERSION=="Lua 5.5" then collectgarbage("param","pause",p) collectgarbage("param","stepmul",400)
  else collectgarbage("incremental",p,400) end
end
-- Sprite image files live in the app folder (the image widget accepts nothing else).
function spr(i) return "p"..i..".bin" end
-- Some firmware reports exists=false for files visible in the console. Read the
-- actual image instead; only one 3,212-byte string is retained by this helper.
function valid(i) local b=badge.fs.read(spr(i)) return b and #b==3212 end
function log(t)
  local s=badge.sys.stats()
  badge.sys.log(t.." lua="..s.lua_used.." peak="..s.lua_peak.." free="..s.free_heap.." widgets="..s.widgets)
end

function save() badge.store.set_int("act",act) badge.store.set_int("owned",owned) end
-- Schedule screen compilation separately from the last sprite write and UI creation.
local function start()
  S,valid=11,nil
  if TMP then TMP:delete() TMP=nil end
end

function on_enter(root)
  UI_ROOT=root gc()
  -- Default GC waits for memory to double before finishing a cycle; with this much live
  -- code and this little spare RAM that never happens. Collect continuously instead.
  gcset(100)
  act=badge.store.get_int("act",1) owned=badge.store.get_int("owned",1)
  if owned<1 or owned>15 or owned%2==0 then owned=1 end
  if act<1 or act>4 or not own(act) then act=1 end
  log(badge.sys.version())
  -- Render sprite images once, a few rows per tick, before any widgets exist.
  -- Bump the number when sprites change.
  local missing=badge.fs.read("sprites10.ok")~="10" and "sprites10.ok" or nil
  for i=1,4 do if not valid(i) then missing=spr(i) end end
  if missing then
    log("prepare: "..missing)
    S=9 nxt=badge.sys.ms() TMP=badge.ui.label(root,"Preparing sprites...") TMP:align("center",0,0)
    require("gen") gc() log("renderer")
  else start() end
  on_enter=nil -- Release initialization code and its GC-configuration helper.
end

function on_tick()
  local now=badge.sys.ms()
  if S==13 then return end
  if S==11 then
    S=13 require("screens") S=12 gc() log("screens compiled")
  elseif S==12 then
    S=13
    if BUILD() then BUILD=nil S=7 gc() log("screens ready") else S=12 end
  elseif S==6 then
    S=13 require("game") S=6
  elseif S==9 then
    badge.led.set_all(0,30,120) badge.led.show()
    S=13 local done,id=GEN() S=9
    if id then TMP:set_text("Preparing sprite "..id.."/4") end
    if done then GEN=nil SPR=nil gc() log("sprites ready in "..(now-nxt).."ms") start() end
  elseif now>=frame then
    frame=now+33
    local state=S S=13
    if TITLE.tick(now) then
      TITLE=nil gc() log("title dropped")
      W.MSG:set_text("Getting ready...") W.MENU:set_text("") S=6
    else S=state end
  end
end
function on_button(b,k)
  if b==badge.input.BUTTON.HOME and k==badge.input.KIND.RELEASED then badge.app.exit()
  elseif S==7 and b==badge.input.BUTTON.A and k==badge.input.KIND.PRESSED then S=8 TITLE.go() end
end
function on_exit()
  save() badge.led.clear() badge.led.show()
  if EI then EI:delete() end
  if PI then PI:delete() end
end
