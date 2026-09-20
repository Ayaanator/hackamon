-- Gameplay is compiled only after startup and title resources are released.
local M={}
local scan
-- Fixed level 15, neutral nature, zero IV/EV: name, HP, type, two moves, effect,
-- Attack, Defense, Sp. Attack, Sp. Defense, Speed. Mewtwo has a custom 100 HP.
P={
 {"PIKACHU",35,4,"QUICK ATTACK","THUNDER WAVE","par",21,17,20,20,32},
 {"CHARMANDER",36,1,"SCRATCH","EMBER","burn",20,17,23,20,24},
 {"SQUIRTLE",38,2,"TACKLE","WITHDRAW","def",19,24,20,24,17},
 {"BULBASAUR",38,3,"TACKLE","LEECH SEED","seed",19,19,24,24,18},
 {"MEWTWO",100,5,"SWIFT","PSYSTRIKE","psy",38,32,51,32,44},
}
TP={"fire","water","grass","elec","psy"}
cur=1 me,en,team={},{},{}
local nfc,nxt,frame=false,0,0
local HM={"SCAN","SWITCH LEAD","EXIT"}
local count=0
local choices,top
local q,qi,after,pending={},0,nil,false
local R=UI_ROOT
local EN,EB,EH,PN,PB,PH,MSG,MENU,CUE,BG=W.EN,W.EB,W.EH,W.PN,W.PB,W.PH,W.MSG,W.MENU,W.CUE,W.BG
local function gc() collectgarbage("collect") end
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
  count=#t choices,top=t,1 MSG:set_size(104,58) MENU:set_text(table.concat(t,"\n",1,math.min(3,count)))
  CUE:set_text(">") cursor(0) CUE:hidden(false)
end
function cursor(dir)
  cur=(cur-1+dir)%count+1
  local first=cur<top and cur or (cur>top+2 and cur-2 or top)
  if first~=top then top=first MENU:set_text(table.concat(choices,"\n",top,math.min(top+2,count))) end
  CUE:align("top_left",118,3+(cur-top)*19)
end
function side(i,e)
  return {id=i,hp=P[i][2],max=P[i][2],burn=0,seed=0,def=0,par=0,name=(e and "Enemy " or "")..P[i][1]}
end

-- Dialogue queue. Each line snapshots HP so bars move with the text; f = side hit, p = fx pattern.
function push(m,f,p) q[#q+1]={m,P[me.id][1],me.hp,me.max,en.id and en.hp or 0,f,p} end
local function advance()
  if qi<#q then
    qi=qi+1 local e=q[qi]
    MSG:set_text(e[1])
    if e[7] then FX.start(e[7],e[6]) end
    pending=not FX.impact()
    if not pending then bars(e[2],e[3],e[4],e[5]) end
    return
  end
  q,qi={},0 CUE:hidden(true) local f=after after=nil if f then f() end
end
-- Dialogue lines get the whole box.
function say(f)
  after=f S=4 MENU:set_text("") MSG:set_size(272,58)
  CUE:set_text("v") CUE:align("bottom_right",-6,-1) CUE:hidden(true) advance()
end

function home()
  q,qi,after={},0,nil team={}
  S=13 cur=1 en={} me=side(act) badge.sys.gc_step()
  if FX then FX.reset() end
  local n=0 for i=1,5 do if own(i) then n=n+1 end end
  BG:style({bg_color=0xf8f8f0}) PI:hidden(false) EB:hidden(true) EI:hidden(true) PB:hidden(false)
  EN:style({text_font=16,text_color=0x101010}) EN:set_text("Team "..n.."/5")
  EH:style({text_color=0x101010}) EH:set_text("")
  PI:set_src(spr(act,true)) bars(P[act][1],me.hp,me.max,0)
  MSG:set_text("What will you\ndo?") menu(HM)
  log("home") S=0
end
scan=function(on)
  if on then
    PI:align("bottom_left",14,-70)
    CUE:hidden(true) MSG:set_size(118,58) nfc=badge.nfc.enable()
    if nfc then badge.nfc.clear() S=2 MSG:set_text("Scanning...\nHold a sticker\nto the badge.") MENU:set_text("B stop")
    else CUE:hidden(false) MSG:set_text("NFC reader\nunavailable.") end
  elseif nfc then badge.nfc.disable() nfc=false end
end

function M.tick()
  if S==13 then return end
  local now=badge.sys.ms()
  if S==6 then
    S=13 gc()
    if not BT then require("battle") gc() log("battle loaded")
    elseif not FX then FX=require("fx") gc() log("fx loaded")
    elseif FX.init(R) then home() return end
    S=6
    return
  end
  if now<frame then return end
  frame=now+33 badge.sys.gc_step()
  if S==0 then FX.ambient(now,P[act][3]) return end
  if FX then FX.tick(now) end
  if S==4 then
    if pending and FX.impact() then
      pending=false local e=q[qi] bars(e[2],e[3],e[4],e[5])
    end
    CUE:hidden(FX.busy() or (now//400)%2==1)
  end
  if S~=2 or not nfc or now<nxt then return end
  nxt=now+300
  if not badge.nfc.card() then return end
  local t=badge.nfc.read_text() badge.nfc.clear()
  local m=string.match(t or "","^PKM(%d+)$")
  local i=m and tonumber(m)+1
  if i and i>=2 and i<=5 then scan(false) BT.encounter(i) else MSG:set_text("That is not a\nPokemon sticker.") end
end

function M.button(b,k)
  local I=badge.input.BUTTON
  -- HOME is delivered to us (home_button=1); its Released is the reliable edge.
  if b==I.HOME then
    if k==badge.input.KIND.RELEASED then
      if S>=6 or TITLE then badge.app.exit() else scan(false) home() end
    end
    return
  end
  if k~=badge.input.KIND.PRESSED then return end
  local up,dn,A,B=b==I.UP,b==I.DOWN,b==I.A,b==I.B
  if S==0 then
    if up or dn then cursor(up and -1 or 1)
    elseif A and cur==1 then scan(true)
    elseif A and cur==3 then badge.app.exit()
    elseif A then for _=1,5 do act=act%5+1 if own(act) then break end end save() home() end
  elseif S==2 then
    if B then scan(false) home() end
  elseif S==3 or S==5 then BT.button(up,dn,A,B)
  elseif S==4 and A and not FX.busy() then advance() end
end

function M.exit()
  if nfc then badge.nfc.disable() end
end
return M
