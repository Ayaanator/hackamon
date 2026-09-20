local M={}
local L,R={1,6,5},{2,3,4}
local ROOT,EI,PI,pat,long,side,t0,dur
local idle=0
local C={fire=0xff1800,water=0x0030ff,grass=0x08d020,elec=0xffa000,burn=0xff0800,seed=0x08c018,par=0xffa000,def=0x1060ff,win=0x00ff30,lose=0xff0000,appear=0xffffff}
local TYPE={"fire","water","grass","elec"}
local MOVE={fire=1,water=1,grass=1,elec=1}
local PC={fire={0xff4000,0xffc000},water={0x40a0ff,0xd0f0ff},grass={0x20c040,0x90e060},elec={0xffe000,0xffffff}}
local PS={fire={8,8,4},water={9,9,4},grass={11,5,2},elec={4,12,1}}
local PB={}
local SZ=40   -- sprite image size in px
local STYLE={bg_color=0,radius=0}
local function set(i,c,k) badge.led.set(i,(c//65536)*k//255,((c//256)%256)*k//255,(c%256)*k//255) end
local function place(w,en,dx,dy) if en then w:align("top_right",-10+dx,6+dy) else w:align("bottom_left",14+dx,-70+dy) end end
local function put(b,en,x,y,w,h) if en then b:align("top_right",-10-SZ+x+w,6+y) else b:align("bottom_left",14+x,-70-SZ+y+h) end end
local function pbox(i)
  local b=PB[i]
  if not b then b=badge.ui.box(ROOT,8,8) b:style({border_width=0}) b:hidden(true) PB[i]=b end
  return b
end
local function hidep() for i=1,#PB do PB[i]:hidden(true) end end
local function particles(en,h,kind)
  local pc,ps=PC[kind],PS[kind]
  for i=1,6 do
    local b=pbox(i)
    local w,hh=ps[1],ps[2]
    local x,y
    if kind=="fire" or kind=="water" then x=2+((i*13+h//60)%36) y=40-((h//7+i*9)%40)
    elseif kind=="grass" then x=((i*11+h//40)%36) y=((h//8+i*9)%40)
    else x=badge.sys.random(34) y=badge.sys.random(34) if (i+h//50)%3==0 then w,hh=12,4 end end
    b:set_size(w,hh) STYLE.bg_color=pc[(i+h//90)%2+1] STYLE.radius=ps[3] b:style(STYLE)
    put(b,en,x,y,w,hh)
    b:hidden(kind=="elec" and badge.sys.random(3)==0)
  end
end
function M.init(root,ei,pi) ROOT,EI,PI=root,ei,pi end
function M.busy() return pat~=nil end
function M.idle(t) idle=C[TYPE[t]] or idle if not pat then for i=1,6 do set(i,idle,200) end badge.led.show() end end
function M.reset() pat=nil place(EI,true,0,0) place(PI,false,0,0) hidep() end
function M.start(p,s)
  long=string.sub(p,-1)=="L"
  if long then p=string.sub(p,1,-2) end
  pat,side,t0=p,s,badge.sys.ms()
  if MOVE[p] then dur=long and 3200 or 450
  elseif p=="win" or p=="lose" then dur=1500
  elseif p=="appear" then dur=700 else dur=550 end
end
function M.tick(now)
  if not pat then return end
  local t=now-t0
  if t>=dur then M.reset() EI:hidden(false) PI:hidden(false) M.idle(0) return end
  local c,tg=C[pat],(side=="en") and R or L
  local tw=(side=="en") and EI or PI
  badge.led.clear()
  if MOVE[pat] and long then
    if t<1500 then local i=(t//80)%6+1 set(i,c,255) set((i+4)%6+1,c,60)
    else for i=1,6 do set(i,c,255) end end
  elseif MOVE[pat] then
    if (t//70)%2==0 then for i=1,6 do set(i,c,255) end end
  elseif pat=="win" or pat=="appear" then
    local i=(t//100)%6+1 set(i,c,255) set(i%6+1,c,80)
  elseif pat=="lose" then
    for i=1,6 do set(i,c,255-255*t//dur) end
  else
    local k=math.floor(150+100*math.sin(t/80))
    for i=1,3 do set(tg[i],c,k) end
  end
  badge.led.show()
  if MOVE[pat] then
    local h=t-(long and 1500 or 0)
    local lunge=(h>=-100 and h<100) and 12 or 0
    local shake=(h>=60 and h<400) and (((t//50)%2==0) and 5 or -5) or 0
    if side=="en" then place(PI,false,lunge,-(lunge//2)) place(EI,true,shake,0)
    else place(EI,true,-lunge,lunge//2) place(PI,false,shake,0) end
    tw:hidden(h>=0 and h<360 and (h//60)%2==1)
    if h>=0 and h<450 then particles(side=="en",h,pat) else hidep() end
  elseif pat=="burn" or pat=="seed" then
    tw:hidden(t<240 and (t//60)%2==1)
  end
end
return M
