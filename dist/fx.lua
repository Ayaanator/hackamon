local M,pool={},{}
local color={fire=0xff1800,water=0x0030ff,grass=0x08d020,elec=0xffa000,burn=0xff0800,seed=0x08c018,par=0xffa000,def=0x1060ff,win=0x00ff30,lose=0xff0000,appear=0xffffff}
local pat,target,t0,delay,duration,c
local idle=0
local style={bg_color=0,radius=0}
local function lights(c,k)
badge.led.set_all((c//65536)*k//255,((c//256)%256)*k//255,(c%256)*k//255) badge.led.show()
end
local function place(w,enemy,x,y)
w:align(enemy and "top_right" or "bottom_left",(enemy and -10 or 14)+x,(enemy and 6 or -70)+y)
end
function M.init(root)
local p=badge.ui.box(root,6,6) p:style({border_width=0,radius=3}) p:hidden(true)
pool[#pool+1]=p
if #pool==4 then M.init=nil return true end
return false
end
function M.ambient(now,t)
lights(color[TP[t]],120+math.floor(80*math.sin(now/500)))
place(PI,false,0,-math.floor(2+2*math.sin(now/300)))
end
function M.busy() return pat~=nil end
function M.idle(t) idle=color[TP[t]] or idle lights(idle,180) end
function M.reset()
pat=nil place(EI,true,0,0) place(PI,false,0,0)
EI:hidden(false) PI:hidden(false)
for i=1,4 do pool[i]:hidden(true) end
end
function M.start(p,side)
delay=string.sub(p,-1)=="L" and 900 or 0
pat=delay>0 and string.sub(p,1,-2) or p
target,t0,c=side=="en",badge.sys.ms(),color[pat]
duration=delay+650
end
function M.tick(now)
if not pat then return end
local t=now-t0
if t>=duration then M.reset() lights(idle,180) return end
lights(c,80+math.floor(150*math.abs(math.sin(t/130))))
local h=t-delay
local tw=target and EI or PI
local attacker=target and PI or EI
local shift=h>=0 and h<100 and 10 or 0
place(attacker,not target,target and shift or -shift,0)
place(tw,target,h>=100 and h<350 and (h//50%2==0 and 4 or -4) or 0,0)
tw:hidden(h>=0 and h<350 and h//70%2==1)
for i=1,4 do
local p=pool[i]
local active=h>=0 and h<500
if active then
local x=(i*11+h//40)%32
local y=32-(h//9+i*7)%32
style.bg_color=i%2==0 and c or 0xffffff
style.radius=pat=="elec" and 0 or 3
p:style(style)
p:align(target and "top_right" or "bottom_left",target and -44+x or 14+x,target and 6+y or -104+y)
end
p:hidden(not active)
end
end
return M
