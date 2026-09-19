--[==[badge-app
slug=rps_solo
name=RPS vs Badge
icon=RPS
api=2
heap_kb=48
]==]
-- Single badge. A=ROCK  B=PAPER  UP=SCISSORS.  DOWN resets the score.
local w,l,d,L1,L2=0,0,0
local N={"ROCK","PAPER","SCISSORS"}
local MENU="A rock  B paper\nUP scissors"
local function show(s)
  L1:set_text("W "..w.."  L "..l.."  D "..d)
  L2:set_text(s)
end
local function led(r,g,b) badge.led.set_all(r,g,b) badge.led.show() end
function on_enter(root)
  L1=badge.ui.label(root,"") L1:align("top_mid",0,20)
  L2=badge.ui.label(root,"") L2:style({text_align="center"}) L2:align("center",0,0)
  w=badge.store.get_int("w",0) l=badge.store.get_int("l",0) d=badge.store.get_int("d",0)
  show(MENU) led(0,30,80)
end
function on_button(b,k)
  if k~=badge.input.KIND.PRESSED then return end
  local I=badge.input.BUTTON
  local m
  if b==I.A then m=1 elseif b==I.B then m=2 elseif b==I.UP then m=3
  elseif b==I.DOWN then w,l,d=0,0,0 show(MENU) led(0,30,80) return
  else return end
  local t=badge.sys.random(3)+1
  local s
  if m==t then d=d+1 s="TIE" led(100,80,0)
  elseif (m-t)%3==1 then w=w+1 s="YOU WIN" led(0,120,20)
  else l=l+1 s="BADGE WINS" led(120,0,10) end
  show(N[m].." vs "..N[t].."\n"..s.."\n\n"..MENU)
end
function on_exit()
  badge.store.set_int("w",w) badge.store.set_int("l",l) badge.store.set_int("d",d)
  badge.led.clear() badge.led.show()
end
