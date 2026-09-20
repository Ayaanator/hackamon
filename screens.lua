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

-- A moving parade reuses the enemy image; no separate wipe widget or rainbow table.
local colors={0xffa000,0xff1800,0x0030ff,0x08d020}
local t0,pk,finish,STAGE
TITLE={}
function TITLE.go(fn) finish=fn end
function TITLE.tick(now)
  if finish then
    STAGE:delete() EI:hidden(true) finish() return true
  end
  local t=now-t0
  local k=(t//2800)%4+1
  if k~=pk then pk=k EI:set_src(spr(k)) EI:hidden(false) end
  EI:align("top_right",65-405*(t%2800)//2800,66-math.floor(5*math.abs(math.sin(t/160))))
  local c=colors[k]
  local v=130+math.floor(100*math.abs(math.sin(t/300)))
  badge.led.set_all((c//65536)*v//255,((c//256)%256)*v//255,(c%256)*v//255) badge.led.show()
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
    t0,pk=badge.sys.ms(),0
    return true
  end
  return false
end
return W
