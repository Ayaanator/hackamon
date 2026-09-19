--[==[badge-app
slug=scanner
name=Tag Scanner
icon=NFC
api=2
heap_kb=48
wake_lock=1
]==]
-- Hold an NFC tag (card, sticker, phone in tag mode) to the back of the badge.
-- Shows its UID and any NDEF text. Counts unique tags this session and
-- keeps a lifetime scan total. A = forget last tag and scan again. HOME exits.
local ok,last,nxt,seen,uniq,total=false,nil,0,{},0,0
local L1,L2,L3,anim=nil,nil,nil,0

local function leds(r,g,b) badge.led.set_all(r,g,b) badge.led.show() end

local function counts()
  L3:set_text("Session "..uniq.."   Lifetime "..total)
end

function on_enter(root)
  total=badge.store.get_int("total",0)
  local t=badge.ui.label(root,"TAG SCANNER")
  t:style({text_font=22}) t:align("top_mid",0,12)
  L1=badge.ui.label(root,"Starting reader...")
  L1:style({text_font=20,text_align="center"}) L1:align("center",0,-30)
  L2=badge.ui.label(root,"")
  L2:style({text_font=16,text_align="center",text_color=0xffd060}) L2:align("center",0,14)
  L3=badge.ui.label(root,"")
  L3:style({text_font=14,text_color=0xaaaaaa}) L3:align("bottom_mid",0,-34)
  local h=badge.ui.label(root,"A scan again   HOME exit")
  h:style({text_font=14,text_color=0xaaaaaa}) h:align("bottom_mid",0,-12)
  ok=badge.nfc.enable()
  if ok then badge.nfc.clear() end
  L1:set_text(ok and "Hold a tag to\nthe badge" or "NFC unavailable")
  counts()
end

function on_tick()
  if not ok then return end
  local now=badge.sys.ms()
  if now<nxt then return end
  nxt=now+200
  local c=badge.nfc.card()
  if c and c.uid~=last then
    last=c.uid
    L1:set_text("UID\n"..c.uid)
    local txt=badge.nfc.read_text()
    L2:set_text(txt and ("\""..txt.."\"") or "(no text record)")
    total=total+1
    if not seen[c.uid] then seen[c.uid]=true uniq=uniq+1 end
    counts()
    leds(0,140,40)
    return
  end
  -- Idle: slow blue chase around the six LEDs while waiting.
  if not last then
    anim=anim%6+1
    badge.led.clear()
    badge.led.set(anim,0,40,120)
    badge.led.show()
  end
end

function on_button(b,k)
  if k~=badge.input.KIND.PRESSED then return end
  if b==badge.input.BUTTON.A and ok then
    badge.nfc.clear()
    last=nil
    L1:set_text("Hold a tag to\nthe badge")
    L2:set_text("")
  end
end

function on_exit()
  badge.store.set_int("total",total)
  badge.led.clear() badge.led.show()
  if ok then badge.nfc.disable() end
end
