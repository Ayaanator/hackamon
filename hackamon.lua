--[==[badge-app
slug=hackamon
name=Hackamon
icon=PKM
api=2
heap_kb=96
wake_lock=1
home_button=1
]==]
-- HACKAMON. Start with PIKACHU. Scan stickers PKM01 (Charmander), PKM02 (Squirtle),
-- PKM03 (Bulbasaur) to battle wild Pokemon; win to add them to your team. If one of
-- yours faints you lose the whole team. UP/DOWN cursor, A select / next line, B back / run.
-- HOME returns to the home screen from anywhere; EXIT on the home menu leaves the game.
-- Generate opaque sprites before creating the UI. Release title resources before
-- loading battle/effects, one module per tick. Buttons never compile modules.
-- Shared game state lives in globals so battle.lua can see it.
local scan
-- name, HP, type, attack name, special name, effect, special power (normal power is 7).
P={
 {"PIKACHU",35,4,"QUICK ATTACK","THUNDER WAVE","par",0},
 {"CHARMANDER",39,1,"SCRATCH","EMBER","burn",4},
 {"SQUIRTLE",44,2,"TACKLE","WITHDRAW","def",0},
 {"BULBASAUR",45,3,"TACKLE","LEECH SEED","seed",0},
}
BIT,SUP,TP={1,2,4,8},{3,1,2,2},{"fire","water","grass","elec"}
S,cur,act,owned=0,1,1,1
me,en,team={},{},{}
local nfc,nxt,frame=false,0,0
local HM={"SCAN","SWITCH LEAD","EXIT"}
local q,qi,after={},0,nil
local R,EN,EB,EH,PN,PB,PH,MSG,MENU,CUE,BG,TMP

function own(i) return (owned//BIT[i])%2==1 end
local function gc() collectgarbage("collect") end
local function gcset(p)
  if _VERSION=="Lua 5.5" then collectgarbage("param","pause",p) collectgarbage("param","stepmul",400)
  else collectgarbage("incremental",p,400) end
end
-- Sprite image files live in the app folder (the image widget accepts nothing else).
function spr(i) return "p"..i..".bin" end
function log(t)
  local s=badge.sys.stats()
  badge.sys.log(t.." lua="..s.lua_used.." peak="..s.lua_peak.." free="..s.free_heap.." widgets="..s.widgets)
end

local function bar(b,h,m)
  b:set_range(0,m) b:set_value(h)
  b:style({bg_color=h*4<=m and 0xe03030 or (h*2<=m and 0xe8b020 or 0x30c030)},"indicator")
end
local function bars(n,mh,mm,eh)
  PN:set_text(n) PH:set_text(mh.."/ "..mm) bar(PB,mh,mm)
  if en.id then EN:set_text(P[en.id][1]) EH:set_text(eh.."/ "..en.max) bar(EB,eh,en.max) end
end
-- A menu shares the box: prompt on the left, choices in a wider column on the right.
function menu(t)
  MSG:set_size(118,58) CUE:hidden(true)
  local s=""
  for i=1,#t do s=s..(i==cur and "> " or "  ")..t[i].."\n" end
  MENU:set_text(s)
end
function side(i,e)
  return {id=i,hp=P[i][2],max=P[i][2],burn=0,seed=0,def=0,par=0,name=(e and "Enemy " or "")..P[i][1]}
end
function save() badge.store.set_int("act",act) badge.store.set_int("owned",owned) end

-- Dialogue queue. Each line snapshots HP so bars move with the text; f = side hit, p = fx pattern.
function push(m,f,p) q[#q+1]={m,P[me.id][1],me.hp,me.max,en.id and en.hp or 0,f,p} end
local function advance()
  if qi<#q then
    qi=qi+1 local e=q[qi]
    MSG:set_text(e[1]) bars(e[2],e[3],e[4],e[5])
    if e[7] then FX.start(e[7],e[6]) end
    return
  end
  q,qi={},0 CUE:hidden(true) local f=after after=nil if f then f() end
end
-- Dialogue lines get the whole box.
function say(f) after=f S=4 MENU:set_text("") MSG:set_size(272,58) advance() end

function home()
  q,qi,after={},0,nil team={}
  S=0 cur=1 en={} me=side(act) gc()
  if FX then FX.reset() end
  local n=0 for i=1,4 do if own(i) then n=n+1 end end
  BG:style({bg_color=0xf8f8f0}) PI:hidden(false) EB:hidden(true) EI:hidden(true) PB:hidden(false)
  EN:style({text_font=16,text_color=0x101010}) EN:set_text("Team "..n.."/4")
  EH:style({text_color=0x101010}) EH:set_text("")
  PI:set_src(spr(act,true)) bars(P[act][1],me.hp,me.max,0)
  MSG:set_text("What will you\ndo?") menu(HM)
  log("home")
end
scan=function(on)
  if on then
    PI:align("bottom_left",14,-70)
    nfc=badge.nfc.enable()
    if nfc then badge.nfc.clear() S=2 MSG:set_text("Scanning...\nHold a sticker\nto the badge.") MENU:set_text("B stop")
    else MSG:set_text("NFC reader\nunavailable.") end
  elseif nfc then badge.nfc.disable() nfc=false end
end
-- Schedule screen compilation separately from the last sprite write and UI creation.
local function start()
  S=11
  if TMP then TMP:delete() TMP=nil end
end

function on_enter(root)
  R=root UI_ROOT=root gc()
  -- Default GC waits for memory to double before finishing a cycle; with this much live
  -- code and this little spare RAM that never happens. Collect continuously instead.
  gcset(100)
  act=badge.store.get_int("act",1) owned=badge.store.get_int("owned",1)
  if owned<1 or owned>15 or owned%2==0 then owned=1 end
  if act<1 or act>4 or not own(act) then act=1 end
  log(_VERSION.." main lua "..badge.sys.heap())
  -- Render sprite images once, a few rows per tick, before any widgets exist.
  -- Bump the number when sprites change.
  local ready=badge.fs.exists("sprites10.ok")
  for i=1,4 do ready=ready and badge.fs.exists(spr(i,false)) end
  if not ready then
    S=9 TMP=badge.ui.label(root,"First launch:\npreparing sprites...") TMP:align("center",0,0)
    require("gen") gc() log("renderer loaded")
  else start() end
  on_enter=nil -- Release initialization code and its GC-configuration helper.
end

function on_tick()
  local now=badge.sys.ms()
  -- Leave setup suspended after an error; HOME can exit even with a partial UI.
  if S==13 then return end
  if S==11 then
    S=13 require("screens") S=12 gc() log("screens compiled")
    return
  end
  if S==12 then
    S=13
    if BUILD() then
      BUILD=nil
      EN,EB,EH,PN,PB,PH,MSG,MENU,CUE,BG=W.EN,W.EB,W.EH,W.PN,W.PB,W.PH,W.MSG,W.MENU,W.CUE,W.BG
      S=7 gc() log("screens ready")
    else S=12 end
    return
  end
  if S==6 then
    if not BT then require("battle") gc() log("battle loaded")
    elseif not FX then FX=require("fx") gc() log("fx loaded")
    elseif FX.init(R) then home() end
    return
  end
  if S==9 then
    if (now//150)%2==0 then badge.led.set_all(0,30,120) else badge.led.set_all(0,10,40) end badge.led.show()
    if GEN() then S=11 GEN=nil SPR=nil gc() log("renderer dropped") start() end
    return
  end
  if now<frame then return end
  frame=now+33 badge.sys.gc_step()
  if TITLE and TITLE.tick(now) then
    TITLE=nil gc() log("title dropped")
    S=6 MSG:set_text("Getting ready...") MENU:set_text("")
    return
  end
  if S==0 then FX.ambient(now,P[act][3]) return end
  if FX then FX.tick(now) end
  if S==4 then CUE:hidden(FX.busy() or (now//400)%2==1) end
  if S~=2 or not nfc or now<nxt then return end
  nxt=now+300
  if not badge.nfc.card() then return end
  local t=badge.nfc.read_text() badge.nfc.clear()
  local m=string.match(t or "","^PKM(%d+)$")
  local i=m and tonumber(m)+1
  if i and i>=2 and i<=4 then scan(false) BT.encounter(i) else MSG:set_text("That is not a\nPokemon sticker.") end
end

function on_button(b,k)
  local I=badge.input.BUTTON
  -- HOME is delivered to us (home_button=1); its Released is the reliable edge.
  if b==I.HOME then
    if k==badge.input.KIND.RELEASED and S>=11 then badge.app.exit() return end
    if k==badge.input.KIND.RELEASED and S~=6 and S~=8 and S~=9 and S~=10 then
      if S==7 then badge.app.exit() else scan(false) home() end
    end
    return
  end
  if k~=badge.input.KIND.PRESSED then return end
  local up,dn,A,B=b==I.UP,b==I.DOWN,b==I.A,b==I.B
  if S==0 then
    if up then cur=(cur+1)%3+1 menu(HM)
    elseif dn then cur=cur%3+1 menu(HM)
    elseif A and cur==1 then scan(true)
    elseif A and cur==3 then badge.app.exit()
    elseif A then for _=1,4 do act=act%4+1 if own(act) then break end end save() home() end
  elseif S==2 then
    if B then scan(false) home() end
  elseif S==3 or S==5 then BT.button(up,dn,A,B)
  elseif S==7 then
    if A then S=8 TITLE.go(home) end
  elseif S==4 and A and not FX.busy() then advance() end
end

function on_exit()
  save() badge.led.clear() badge.led.show()
  if nfc then badge.nfc.disable() end
  if EI then EI:delete() end
  if PI then PI:delete() end
end
