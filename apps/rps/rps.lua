--[==[badge-app
slug=rps
name=Rock Paper Scissors
icon=RPS
api=2
heap_kb=48
wake_lock=1
]==]
-- Two badges. Open on both; first badge heard is your opponent.
-- A=ROCK  B=PAPER  UP=SCISSORS.  First to 3 wins.
local ok,opp,r,m,t,lm=false,nil,1,nil,nil,nil
local w,l,nx,L1,L2=0,0,0
local N={"ROCK","PAPER","SCISSORS"}
local MENU="A rock  B paper\nUP scissors"
local function show(s)
  L1:set_text("YOU "..w.."  THEM "..l)
  L2:set_text(s)
end
local function fight()
  local s
  if m==t then s="TIE"
  elseif (m-t)%3==1 then w=w+1 s="YOU WIN"
  else l=l+1 s="THEY WIN" end
  s=N[m].." vs "..N[t].."\n"..s
  lm,m,t,r=m,nil,nil,r+1
  if w>=3 then show(s.."\n\nYOU TAKE IT!")
  elseif l>=3 then show(s.."\n\nTHEY TAKE IT")
  else show(s.."\n\n"..MENU) end
end
local function rx(mac,_,p)
  if p=="RPS1H" then
    if not opp then opp=mac show(MENU) end
    return
  end
  if mac~=opp then return end
  local rr,mm=string.match(p,"^RPS1M(%d+),([123])$")
  if not rr then return end
  rr=tonumber(rr)
  if rr==r then t=tonumber(mm) if m then fight() end
  elseif rr==r-1 and lm then badge.radio.send("RPS1M"..rr..","..lm) end
end
function on_enter(root)
  ok=badge.radio.enable()
  L1=badge.ui.label(root,"ROCK PAPER SCISSORS") L1:align("top_mid",0,20)
  L2=badge.ui.label(root,ok and "Searching..." or "Radio failed")
  L2:style({text_align="center"}) L2:align("center",0,0)
  if ok then badge.radio.on_recv(rx) end
end
function on_tick()
  if not ok then return end
  local now=badge.sys.ms()
  if now<nx then return end
  nx=now+700
  if m and not t then badge.radio.send("RPS1M"..r..","..m)
  elseif not m then badge.radio.send("RPS1H") end
end
function on_button(b,k)
  if k~=badge.input.KIND.PRESSED or not opp or m or w>=3 or l>=3 then return end
  local I=badge.input.BUTTON
  if b==I.A then m=1 elseif b==I.B then m=2 elseif b==I.UP then m=3 else return end
  if t then fight() else show(N[m].." locked\nWaiting...") end
end
function on_exit()
  if ok then badge.radio.on_recv(nil) badge.radio.disable() end
end
