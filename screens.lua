-- Widgets and the title screen. Loaded once at startup. The widget table W stays for
-- the whole session; the title code is dropped after the wipe (main sets TITLE=nil).
-- Reads the globals UI_ROOT, act and spr; creates the sprite images EI and PI.
local root=UI_ROOT
W={}
local function lbl(f,al,x,y)
  local l=badge.ui.label(root,"") l:style({text_font=f,text_color=0x101010}) l:align(al,x,y) return l
end
local function hb(al,x,y)
  local b=badge.ui.bar(root,0,100,100) b:set_size(110,8) b:align(al,x,y) b:style({bg_color=0xc8c8c0},"main") return b
end
local d,step= nil,0

-- Title parade: each Pokemon walks in from the right, poses centre stage with its
-- element's LED colour and bobs, then walks off left. A runs a black wipe to home.
local C={0xffa000,0xff1800,0x0030ff,0x08d020}   -- LED colour by Pokemon 1..4
local RB={0xff0000,0xff6000,0xffc000,0x00ff20,0x0040ff,0x8000ff}
local t0,pk,wt,wcb,wdone,WIPE,STAGE
local function set(i,c,k) badge.led.set(i,(c//65536)*k//255,((c//256)%256)*k//255,(c%256)*k//255) end

TITLE={}
function TITLE.go(fn) wt,wcb=badge.sys.ms(),fn WIPE:hidden(false) WIPE:set_size(1,240) end
-- Returns true once the wipe has fully cleared and this module can be dropped.
function TITLE.tick(now)
  if not t0 then return false end
  if wt then
    local u=now-wt
    if u<300 then WIPE:set_size(1+319*u//300,240)
    elseif not wdone then
      wdone=true STAGE:delete() STAGE=nil EI:hidden(true) W.EN:align("top_left",8,6) wcb() S=8 wcb=nil
    elseif u<620 then WIPE:set_size(math.max(1,320-320*(u-300)//300),240)
    else WIPE:delete() return true end
    if wdone then return false end
  end
  local t=now-t0
  W.EN:align("top_left",8,6-math.floor(3+3*math.sin(t/250)))
  local u,k=t%1900,(t//1900)%4+1
  if k~=pk then pk=k EI:set_src(spr(k,false)) EI:hidden(false) end
  local dx
  if u<500 then dx=70-205*u//500 elseif u<1400 then dx=-135 else dx=-135-200*(u-1400)//500 end
  local dy=(u>=500 and u<1400) and -math.floor(6*math.abs(math.sin((u-500)/150))) or 0
  EI:align("top_right",-10+dx,66+dy)
  if u>=500 and u<1400 then for i=1,6 do set(i,C[k],120+badge.sys.random(136)) end
  else for i=1,6 do set(i,RB[((t//150)+i)%6+1],120) end end
  badge.led.show()
  return false
end

-- Requiring this module only defines code. Build at most one widget per tick;
-- initialize its final title appearance immediately to avoid a second styling pass.
BUILD=function()
  step=step+1
  if step==1 then
    W.BG=badge.ui.box(root,320,240) W.BG:style({bg_color=0x101838,border_width=0,radius=0}) W.BG:align("center",0,0)
  elseif step==2 then
    W.EN=lbl(24,"top_left",8,6) W.EN:style({text_color=0xffd000}) W.EN:set_text("HACKAMON")
  elseif step==3 then W.EB=hb("top_left",8,28) W.EB:hidden(true)
  elseif step==4 then
    W.EH=lbl(14,"top_left",8,40) W.EH:style({text_color=0x80c0ff}) W.EH:set_text("Scan. Battle. Catch.")
  elseif step==5 then W.PN=lbl(16,"bottom_right",-8,-112)
  elseif step==6 then W.PB=hb("bottom_right",-8,-98) W.PB:hidden(true)
  elseif step==7 then W.PH=lbl(16,"bottom_right",-8,-76)
  elseif step==8 then
    d=badge.ui.box(root,288,64)
    d:style({bg_color=0xffffff,border_color=0x101010,border_width=2,radius=4,pad_all=0}) d:align("bottom_mid",0,-2)
  elseif step==9 then
    W.MSG=badge.ui.label(d,"Press A\nto start") W.MSG:style({text_font=16,text_color=0x101010}) W.MSG:set_size(272,58) W.MSG:set_pos(8,3)
  elseif step==10 then
    W.MENU=badge.ui.label(d,"") W.MENU:style({text_font=16,text_color=0x101010}) W.MENU:set_size(150,58) W.MENU:set_pos(130,3)
  elseif step==11 then
    W.CUE=badge.ui.label(d,"v") W.CUE:style({text_font=14,text_color=0x101010}) W.CUE:align("bottom_right",-6,-1) W.CUE:hidden(true)
  elseif step==12 then EI=badge.ui.image(root,spr(1,false)) EI:align("top_right",-10,6) EI:hidden(true)
  elseif step==13 then PI=badge.ui.image(root,spr(act,true)) PI:align("bottom_left",14,-70) PI:hidden(true)
  elseif step==14 then
    STAGE=badge.ui.box(root,320,62)
    STAGE:style({bg_color=0xf8f8f0,border_width=0,radius=0}) STAGE:set_pos(0,54) EI:bring_to_front()
  elseif step==15 then
    WIPE=badge.ui.box(root,320,240)
    WIPE:style({bg_color=0x000000,border_width=0,radius=0}) WIPE:align("right_mid",0,0) WIPE:hidden(true)
    t0,pk,wdone=badge.sys.ms(),0,false
    return true
  end
  return false
end
return W
