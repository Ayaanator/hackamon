--[==[badge-app
slug=hackemon
name=Hackemon
icon=HKM
api=2
heap_kb=48
wake_lock=1
]==]
-- HACKEMON: find NFC stickers around campus, battle wild Hackemon, catch them all.
-- Stickers hold NDEF text "HKM07" (creature 7, level 1) or "HKM07L5" (level 5).
-- Menu: A scan  B hackadex  UP switch active.
-- Battle: A attack  B special  UP defend  DOWN catch.
-- Types beat the next type in the ring HW > AI > WEB > DSGN > SEC > SYS > HW.
local TN={"HW","AI","WEB","DSGN","SEC","SYS"}
local C={ -- name, type, base hp, base atk, colour a, colour b, 8x8 sprite (. a b w)
 {"Soldrat",1,22,6,0xff8a2a,0x7a3a10,"..a..a...aaaaaa..awaawa..aaaaaa...abba...aaaaaa..a.aa.a.b......b"},
 {"Neuron",2,20,7,0xb060ff,0x5020a0,"..aaaa...abaaba.aaaaaaaaawaaaawaaaabbaaa.aaaaaa...a..a...b....b."},
 {"Crawly",3,18,8,0x30a0ff,0x104080,"b.aaaa.b.baaaab.bbawwabb.aaaaaa.b.aaaa.b.b.aa.b.b.b..b.b........"},
 {"Pixie",4,17,8,0xff70c0,0xffd0e8,"b..aa..b.b.aa.b...aaaa...awaawa..aaaaaa...abba...b.aa.b.b..aa..b"},
 {"Lockjaw",5,26,5,0x30c060,0x106030,"..bbbb...b....b..b....b.aaaaaaaaawaaaawaaaaaaaaaaabbbbaaaaaaaaaa"},
 {"Kernel",6,24,6,0x9aa4b0,0x40485a,"..bbbb...baaaab.baaaaaabbawaawabbaaaaaabbaabbaab.baaaab...bbbb.."},
 {"Voltra",1,19,9,0xffe030,0xa08000,"....aaa....aaa....aaa....aaaaaa...wwaa.....aaa....aab....aa....."},
 {"Gradient",2,21,7,0x40e0e0,0x208080,"..aaaa...aaaaaa..awaawa..aaaaaa.aabaabaaaaaaaaaaaaaaaaaaa.aa.aa."},
 {"Cachemander",6,23,8,0xff4040,0x802020,".....aa.....awab...aaaa.aa.aaa...aaaaa....aaaaa...b..b...bb..bb."},
 {"Rootkat",5,25,9,0x303040,0xe0e0f0,".a....a..aa..aa..aaaaaa..awaawa..aaaaaa...abba...aaaaaa.b.a..a.b"},
}
local N=#C
local P={1,2,4,8,16,32,64,128,256,512}
local LS,RS={1,6,5},{2,3,4}
local S,act,xp,caught,seen,wins,sel=0,0,0,0,0,0,1
local lv={}
local T,A,L,HB,WB,SP,px={},{},{},{},{},{},{}
local wid,wlv,whp,wmax,mhp,mmax,def,nxt,anim,nfc=0,0,0,1,0,1,false,0,0,false

local function bit(m,i) return (m//P[i])%2==1 end
local function setbit(m,i) if not bit(m,i) then m=m+P[i] end return m end
local function maxhp(id,l) return C[id][3]+3*l end
local function atk(id,l) return C[id][4]+l end
local function eff(a,d) if a%6+1==d then return 3 elseif d%6+1==a then return 1 end return 2 end
local function ncaught() local n=0 for i=1,N do if bit(caught,i) then n=n+1 end end return n end

local function leds(c) badge.led.set_all(c//65536,(c//256)%256,c%256) badge.led.show() end

local function hpside(idx,h,m)
  local n=math.ceil(h*3/m) local r,g=0,120
  if h*4<=m then r,g=120,0 elseif h*2<=m then r,g=120,90 end
  for i=1,3 do if i<=n then badge.led.set(idx[i],r,g,0) end end
end
local function ledhp() badge.led.clear() hpside(LS,mhp,mmax) hpside(RS,whp,wmax) badge.led.show() end

local function draw(id)
  local c=C[id]
  for i=1,64 do
    local ch=string.sub(c[7],i,i)
    if ch=="." then px[i]:hidden(true)
    else
      px[i]:hidden(false)
      px[i]:style({bg_color=(ch=="a" and c[5]) or (ch=="b" and c[6]) or 0xffffff})
    end
  end
  SP:hidden(false)
end

local function save()
  badge.store.set_int("act",act) badge.store.set_int("xp",xp)
  badge.store.set_int("caught",caught) badge.store.set_int("seen",seen)
  badge.store.set_int("wins",wins)
  badge.store.set_str("lv",table.concat(lv,","))
end

local function load()
  act=badge.store.get_int("act",0) xp=badge.store.get_int("xp",0)
  caught=badge.store.get_int("caught",0) seen=badge.store.get_int("seen",0)
  wins=badge.store.get_int("wins",0)
  local i=0
  for n in string.gmatch(badge.store.get_str("lv",""),"%d+") do i=i+1 lv[i]=tonumber(n) end
  for j=1,N do lv[j]=lv[j] or 0 end
end

local function mystat() A:set_text(C[act][1].." Lv"..lv[act].."\nHP "..mhp.."/"..mmax) end

local function show(s)
  S=s
  A:set_text("") L:set_text("")
  HB:hidden(s~=3) WB:hidden(s~=3) SP:hidden(true)
  if nfc then badge.nfc.disable() nfc=false end
  if s==0 then
    T:set_text("CHOOSE YOUR STARTER")
    local t=""
    for i=1,3 do t=t..(i==sel and "> " or "  ")..C[i][1].."  "..TN[C[i][2]].."\n" end
    A:set_text(t) L:set_text("UP/DOWN pick   A choose") draw(sel) leds(C[sel][5])
  elseif s==1 then
    local c=C[act]
    T:set_text("HACKEMON")
    A:set_text(c[1].."  "..TN[c[2]].."\nLv"..lv[act].."  XP "..xp.."/"..(20*lv[act]).."\nHP "..maxhp(act,lv[act]).."  ATK "..atk(act,lv[act]).."\n\nCaught "..ncaught().."/"..N.."   Wins "..wins)
    L:set_text("A scan   B hackadex   UP switch") draw(act) leds(c[5])
  elseif s==2 then
    T:set_text("SCANNING")
    nfc=badge.nfc.enable()
    if nfc then badge.nfc.clear() A:set_text("Find a Hackemon\nsticker and hold\nit to the badge")
    else A:set_text("NFC unavailable") end
    L:set_text("B back") badge.led.clear() badge.led.show()
  elseif s==4 then
    local c=C[sel]
    T:set_text("HACKADEX  "..ncaught().."/"..N)
    if bit(seen,sel) then
      A:set_text("#"..sel.."  "..c[1].."\nType "..TN[c[2]].."\nHP "..c[3].."  ATK "..c[4].."\n\n"..(bit(caught,sel) and ("CAUGHT  Lv"..lv[sel]) or "Seen, not caught"))
      draw(sel) leds(c[5])
    else
      A:set_text("#"..sel.."  ???\n\nNot yet found.\nKeep exploring!") leds(0x202030)
    end
    L:set_text("UP/DOWN browse   B back")
  end
end

local function finish(msg)
  S=5
  while xp>=20*lv[act] do xp=xp-20*lv[act] lv[act]=lv[act]+1 msg=msg.."\nLEVEL UP! Lv"..lv[act] end
  save()
  HB:set_value(mhp) WB:set_value(whp)
  A:set_text(msg) L:set_text("A continue")
  leds(mhp>0 and 0x20c040 or 0xc02020)
end

local function hit(a,al,d)
  local x=atk(a,al)+badge.sys.random(4)
  return math.max(1,math.floor(x*eff(C[a][2],C[d][2])/2))
end

local function turn(mv)
  local log
  if mv==4 then
    if whp*2>wmax then log="Too strong to catch!\n"
    elseif badge.sys.random(100)<120-math.floor(100*whp/wmax) then
      caught=setbit(caught,wid) if lv[wid]<wlv then lv[wid]=wlv end
      xp=xp+5 wins=wins+1
      return finish("CAUGHT "..C[wid][1].."!")
    else log="It broke free!\n" end
  elseif mv==3 then def=true log="You brace.\n"
  else
    local d=hit(act,lv[act],wid)
    if mv==2 then if badge.sys.random(10)<7 then d=math.floor(d*1.6) else d=0 end end
    whp=math.max(0,whp-d)
    log=d>0 and ("You hit "..d.."!\n") or "Special missed!\n"
    if whp==0 then xp=xp+10+2*wlv wins=wins+1 return finish("You beat "..C[wid][1].."!") end
  end
  local d=hit(wid,wlv,act)
  if badge.sys.random(10)<3 then d=math.floor(d*1.5) end
  if def then d=math.floor(d/2) def=false end
  mhp=math.max(0,mhp-d) log=log.."Wild hits "..d.."."
  HB:set_value(mhp) WB:set_value(whp) ledhp()
  if mhp==0 then return finish("You fainted...") end
  mystat() L:set_text(log)
end

local function encounter(id,l)
  wid,wlv=id,l wmax=maxhp(id,l) whp=wmax
  mmax=maxhp(act,lv[act]) mhp=mmax def=false
  seen=setbit(seen,id)
  show(3)
  T:set_text("WILD "..C[id][1].."  Lv"..l.."  "..TN[C[id][2]])
  HB:set_range(0,mmax) WB:set_range(0,wmax) HB:set_value(mhp) WB:set_value(whp)
  draw(id) mystat()
  L:set_text("A attack  B special\nUP defend  DOWN catch") ledhp()
end

function on_enter(root)
  load()
  T=badge.ui.label(root,"") T:style({text_font=20}) T:align("top_mid",0,10)
  A=badge.ui.label(root,"") A:style({text_font=18}) A:align("top_left",12,44)
  L=badge.ui.label(root,"") L:style({text_font=16,text_color=0xffd060}) L:align("bottom_left",12,-12)
  SP=badge.ui.box(root,80,80) SP:style({bg_opa=0,border_width=0,pad_all=0}) SP:set_pos(224,40)
  for i=1,64 do
    local b=badge.ui.box(SP,9,9)
    b:style({bg_color=0xffffff,radius=1,border_width=0})
    b:set_pos(((i-1)%8)*10,((i-1)//8)*10) b:hidden(true) px[i]=b
  end
  HB=badge.ui.bar(root,0,100,100) HB:set_size(120,10) HB:set_pos(12,100) HB:style({bg_color=0x30d050},"indicator")
  WB=badge.ui.bar(root,0,100,100) WB:set_size(80,10) WB:set_pos(224,126) WB:style({bg_color=0xff5050},"indicator")
  sel=1
  if act==0 then show(0) else show(1) end
end

function on_tick()
  if S~=2 or not nfc then return end
  local now=badge.sys.ms()
  if now<nxt then return end
  nxt=now+300
  anim=anim%6+1 badge.led.clear() badge.led.set(anim,0,40,120) badge.led.show()
  local c=badge.nfc.card()
  if not c then return end
  local t=badge.nfc.read_text() badge.nfc.clear()
  local id,l=string.match(t or "","^HKM(%d+)L?(%d*)$")
  id=tonumber(id) l=tonumber(l) or 1
  if id and C[id] then encounter(id,l)
  else A:set_text("Not a Hackemon\nsticker") end
end

function on_button(b,k)
  if k~=badge.input.KIND.PRESSED then return end
  local I=badge.input.BUTTON
  if S==0 then
    if b==I.UP then sel=(sel+1)%3+1 show(0)
    elseif b==I.DOWN then sel=sel%3+1 show(0)
    elseif b==I.A then act=sel lv[act]=1 caught=setbit(caught,act) seen=setbit(seen,act) save() show(1) end
  elseif S==1 then
    if b==I.A then show(2)
    elseif b==I.B then sel=act show(4)
    elseif b==I.UP then
      for _=1,N do act=act%N+1 if bit(caught,act) then break end end
      save() show(1)
    end
  elseif S==2 then
    if b==I.B then show(1) end
  elseif S==3 then
    if b==I.A then turn(1) elseif b==I.B then turn(2)
    elseif b==I.UP then turn(3) elseif b==I.DOWN then turn(4) end
  elseif S==4 then
    if b==I.UP then sel=(sel+N-2)%N+1 show(4)
    elseif b==I.DOWN then sel=sel%N+1 show(4)
    elseif b==I.B then show(1) end
  elseif S==5 then
    if b==I.A then show(1) end
  end
end

function on_exit()
  save()
  badge.led.clear() badge.led.show()
  if nfc then badge.nfc.disable() end
end
