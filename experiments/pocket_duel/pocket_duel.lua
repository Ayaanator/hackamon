--[==[badge-app
slug=pocket_duel
name=Pocket Duel
icon=PD
api=2
heap_kb=48
wake_lock=1
]==]
-- Open on two badges. First badge heard becomes your opponent.
-- A=STRIKE(6)  B=GUARD(2, blocks 4)  UP=BLAST(9, costs you 1)
local ok,opp,r,m,t,lm=false,nil,1,nil,nil,nil
local hp,oh,nx,L1,L2=20,20,0
local D={6,2,9}
local MENU="A strike  B guard\nUP blast"
local function show(s)
  L1:set_text("R"..r.."  YOU "..hp.."  THEM "..oh)
  L2:set_text(s)
end
local function fight()
  local a,b=D[m],D[t]
  if t==2 then a=math.max(0,a-4) end
  if m==2 then b=math.max(0,b-4) end
  if m==3 then hp=hp-1 end
  if t==3 then oh=oh-1 end
  oh=math.max(0,oh-a) hp=math.max(0,hp-b)
  lm,m,t,r=m,nil,nil,r+1
  if hp<=0 and oh<=0 then show("DRAW")
  elseif oh<=0 then show("YOU WIN!")
  elseif hp<=0 then show("YOU LOSE")
  else show(MENU) end
end
local function rx(mac,_,p)
  if p=="PD1H" then
    if not opp then opp=mac show(MENU) end
    return
  end
  if mac~=opp then return end
  local rr,mm=string.match(p,"^PD1M(%d+),([123])$")
  if not rr then return end
  rr=tonumber(rr)
  if rr==r then t=tonumber(mm) if m then fight() end
  elseif rr==r-1 and lm then badge.radio.send("PD1M"..rr..","..lm) end
end
function on_enter(root)
  ok=badge.radio.enable()
  L1=badge.ui.label(root,"POCKET DUEL") L1:align("top_mid",0,20)
  L2=badge.ui.label(root,ok and "Searching..." or "Radio failed") L2:align("center",0,0)
  if ok then badge.radio.on_recv(rx) end
end
function on_tick()
  if not ok then return end
  local now=badge.sys.ms()
  if now<nx then return end
  nx=now+700
  if m and not t then badge.radio.send("PD1M"..r..","..m)
  elseif not m then badge.radio.send("PD1H") end
end
function on_button(b,k)
  if k~=badge.input.KIND.PRESSED or not opp or m or hp<=0 or oh<=0 then return end
  local I=badge.input.BUTTON
  if b==I.A then m=1 elseif b==I.B then m=2 elseif b==I.UP then m=3 else return end
  if t then fight() else show("Locked. Waiting...") end
end
function on_exit()
  if ok then badge.radio.on_recv(nil) badge.radio.disable() end
end
