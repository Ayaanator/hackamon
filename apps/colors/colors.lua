--[==[badge-app
slug=colors
name=Color Buttons
icon=CLR
api=2
heap_kb=48
]==]
-- Each button paints the whole screen and the LEDs a colour.
-- A red  B blue  UP green  DOWN yellow  LEFT purple  RIGHT cyan  START white
-- HOME exits.
local bg,lbl
local C={}
local function paint(name,rgb,dark)
  bg:style({bg_color=rgb})
  lbl:style({text_color=dark and 0x000000 or 0xffffff})
  lbl:set_text(name)
  badge.led.set_all(math.floor(rgb/65536)%256, math.floor(rgb/256)%256, rgb%256)
  badge.led.show()
end
function on_enter(root)
  bg=badge.ui.box(root,badge.ui.screen_width,badge.ui.screen_height)
  bg:align("center",0,0)
  lbl=badge.ui.label(bg,"Press a button")
  lbl:style({text_font=24,text_align="center"})
  lbl:align("center",0,0)
  local B=badge.input.BUTTON
  C[B.A]={"RED",0xff0000}
  C[B.B]={"BLUE",0x0040ff}
  C[B.UP]={"GREEN",0x00c000}
  C[B.DOWN]={"YELLOW",0xffd000,true}
  C[B.LEFT]={"PURPLE",0xa000ff}
  C[B.RIGHT]={"CYAN",0x00e0e0,true}
  C[B.START]={"WHITE",0xffffff,true}
  paint("Press a button",0x202020)
end
function on_button(b,k)
  if k~=badge.input.KIND.PRESSED then return end
  local c=C[b]
  if c then paint(c[1],c[2],c[3]) end
end
function on_exit()
  badge.led.clear()
  badge.led.show()
end
