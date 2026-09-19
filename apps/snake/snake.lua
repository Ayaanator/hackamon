--[==[badge-app
slug=snake
name=Snake
icon=SNK
api=2
heap_kb=48
wake_lock=1
confirm_home=1
]==]
-- D-pad steers. A starts / restarts. HOME exits.
-- Eat the orange food to grow. Walls and your own tail end the game.
local CELL,COLS,ROWS,OX,OY,MAX=16,19,12,0,0,48
local px,py,bx={}, {}, {}
local h,len,dx,dy,ndx,ndy=1,0,1,0,1,0
local fx,fy,food,score,best,state=0,0,nil,0,0,0
local step,nxt,hud,msg,field=200,0

local function slot(i) return (i-1)%MAX+1 end

local function place(b,x,y) b:set_pos(OX+x*CELL,OY+y*CELL) end

local function box(parent,color)
  local b=badge.ui.box(parent,CELL-1,CELL-1)
  b:style({bg_color=color,radius=3,border_width=0})
  return b
end

local function leds(r,g,b) badge.led.set_all(r,g,b) badge.led.show() end

local function hud_text()
  hud:set_text("SCORE "..score.."   BEST "..best)
end

local function on_snake(x,y)
  for i=0,len-1 do
    local s=slot(h-i)
    if px[s]==x and py[s]==y then return true end
  end
  return false
end

local function drop_food()
  for _=1,30 do
    fx,fy=badge.sys.random(COLS),badge.sys.random(ROWS)
    if not on_snake(fx,fy) then break end
  end
  place(food,fx,fy)
end

local function reset()
  for i=1,MAX do if bx[i] then bx[i]:hidden(true) end end
  h,len,score,step=1,3,0,200
  dx,dy,ndx,ndy=1,0,1,0
  for i=1,3 do
    local s=slot(h-3+i)
    px[s],py[s]=6+i,6
    if not bx[s] then bx[s]=box(field,0x40e060) end
    bx[s]:hidden(false) place(bx[s],px[s],py[s])
  end
  drop_food()
  hud_text()
  msg:set_text("") msg:hidden(true)
  leds(0,20,40)
  state=1
  nxt=badge.sys.ms()+step
end

local function die()
  state=2
  if score>best then best=score badge.store.set_int("best",best) hud_text() end
  msg:set_text("GAME OVER\n\nA to restart") msg:hidden(false)
  leds(120,0,0)
end

local function advance()
  dx,dy=ndx,ndy
  local hs=slot(h)
  local nx,ny=px[hs]+dx,py[hs]+dy
  if nx<0 or ny<0 or nx>=COLS or ny>=ROWS then return die() end
  local grow=(nx==fx and ny==fy)
  local tail=slot(h-len+1)
  -- Tail moves away this step, so it is safe to step onto it unless we grow.
  for i=0,len-1 do
    local s=slot(h-i)
    if (s~=tail or grow) and px[s]==nx and py[s]==ny then return die() end
  end
  local ns
  if grow and len<MAX then
    ns=slot(h+1) len=len+1
    if not bx[ns] then bx[ns]=box(field,0x40e060) end
    bx[ns]:hidden(false)
  else
    ns=tail
  end
  h=h+1
  if ns~=slot(h) then
    -- Reusing the tail slot: swap its bookkeeping into the head slot.
    local hs2=slot(h)
    bx[hs2],bx[ns]=bx[ns],bx[hs2]
    ns=hs2
  end
  px[ns],py[ns]=nx,ny
  place(bx[ns],nx,ny)
  if grow then
    score=score+1
    if step>90 then step=step-6 end
    hud_text()
    drop_food()
    leds(0,120,30)
  elseif score>0 then
    leds(0,20,40)
  end
end

function on_enter(root)
  best=badge.store.get_int("best",0)
  hud=badge.ui.label(root,"")
  hud:style({text_font=18}) hud:align("top_mid",0,8)
  field=badge.ui.box(root,COLS*CELL+2,ROWS*CELL+2)
  field:style({bg_color=0x101418,border_color=0x30a0ff,border_width=1,radius=0,pad_all=0})
  field:align("top_mid",0,30)
  food=box(field,0xff8020)
  msg=badge.ui.label(root,"SNAKE\n\nD-pad steers\nA to start")
  msg:style({text_font=22,text_align="center"}) msg:align("center",0,10)
  hud_text()
  leds(0,20,40)
end

function on_tick()
  if state~=1 then return end
  local now=badge.sys.ms()
  if now<nxt then return end
  nxt=now+step
  advance()
end

function on_button(b,k)
  if k~=badge.input.KIND.PRESSED then return end
  local I=badge.input.BUTTON
  if state~=1 then
    if b==I.A then reset() end
    return
  end
  if b==I.UP and dy==0 then ndx,ndy=0,-1
  elseif b==I.DOWN and dy==0 then ndx,ndy=0,1
  elseif b==I.LEFT and dx==0 then ndx,ndy=-1,0
  elseif b==I.RIGHT and dx==0 then ndx,ndy=1,0 end
end

function on_exit()
  if score>best then badge.store.set_int("best",score) end
  badge.led.clear() badge.led.show()
end
