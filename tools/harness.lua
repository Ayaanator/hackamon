-- Off-badge test harness for Hackamon. Run with tools/run_harness.py (needs lupa).
-- Provides a mock badge API, then drives the game through a scripted session and
-- fails loudly on any Lua error. It does not check pixels, only that the code runs.
local DIR=...
local now=0
local store={}
local files=INPUT_FILES or {}
local mode=TEST_MODE or "cold"
local widgets=0
local live,peak,max_write,writes,io=0,0,0,0,0
local in_button=false
local in_generation_tick=false
local loading_module=nil
local modules={}
local log={}
local errors={}
local exited=false
local ui_calls=0

local function W(kind)
  assert(loading_module~="screens","screen module constructed widgets during require")
  if mode=="widget_error" and widgets==13 then error("injected widget failure") end
  if mode=="fx_error" and FX then error("injected particle setup failure") end
  widgets=widgets+1
  live=live+1 peak=math.max(peak,live)
  local w={kind=kind,text="",hidden_=false}
  function w:style(t,sel) assert(type(t)=="table") return self end
  function w:align(a,x,y) assert(type(a)=="string") assert(math.type(x)=="integer" and math.type(y)=="integer","non-integer align "..tostring(x)..","..tostring(y)) self.align_,self.x,self.y=a,x,y return self end
  function w:set_pos(x,y) assert(math.type(x)=="integer" and math.type(y)=="integer","non-integer pos") return self end
  function w:set_size(x,y) assert(math.type(x)=="integer" and math.type(y)=="integer","non-integer size") return self end
  function w:set_text(s)
    if mode=="home_error" and S==13 and FX and not FX.init then error("injected home transition failure") end
    assert(type(s)=="string","set_text needs a string, got "..type(s)) self.text=s return self
  end
  function w:hidden(b) self.hidden_=b return self end
  function w:set_src(p) assert(type(p)=="string") assert(files[p],"set_src of missing file "..p) self.src=p return self end
  function w:set_range(a,b) return self end
  function w:set_value(v) assert(math.type(v)=="integer","bar value not integer") return self end
  function w:bring_to_front() assert(not self.deleted) end
  function w:delete()
    assert(not self.deleted,"double delete") self.deleted=true live=live-1
    if mode=="title_error" and S==13 and TITLE and not BUILD and self.kind=="box" then error("injected title cleanup failure") end
  end
  for name,fn in pairs(w) do
    if type(fn)=="function" then w[name]=function(self,...) ui_calls=ui_calls+1 return fn(self,...) end end
  end
  return w
end

badge={
  ui={
    screen_width=320,screen_height=240,
    label=function(p,t) local w=W("label") w.text=t return w end,
    box=function(p,x,y) return W("box") end,
    bar=function(p,a,b,c) return W("bar") end,
    image=function(p,src) local w=W("image") assert(files[src],"image of missing file "..src) w.src=src return w end,
  },
  led={
    set=function(i,r,g,b)
      assert(i>=1 and i<=6,"led index "..i)
      for _,v in ipairs{r,g,b} do assert(math.type(v)=="integer" and v>=0 and v<=255,"led channel "..tostring(v)) end
    end,
    set_all=function(r,g,b) badge.led.set(1,r,g,b) end,
    clear=function() end, show=function() end, count=function() return 6 end,
  },
  sys={
    ms=function() return now end,
    version=function() return "test-firmware" end,
    log=function(s) log[#log+1]=s end,
    random=function(n) if n then return math.random(0,n-1) end return math.random(0,2^31) end,
    stats=function() return {free_heap=30000,lua_used=math.floor(collectgarbage("count")*1024),lua_peak=0,widgets=live} end,
    heap=function() return math.floor(collectgarbage("count")*1024) end,
    gc_step=function() collectgarbage("step") end,
  },
  store={
    get_int=function(k,d) return store[k] or d end,
    set_int=function(k,v) assert(math.type(v)=="integer") store[k]=v end,
  },
  nfc={
    enabled=false, text=nil,
    enable=function() badge.nfc.enabled=mode~="no_nfc" return badge.nfc.enabled end,
    disable=function() badge.nfc.enabled=false end,
    clear=function() badge.nfc.text=nil end,
    card=function() if badge.nfc.text then return {uid="04AA"} end return nil end,
    read_text=function() return badge.nfc.text end,
  },
  fs={
    write=function(n,d)
      io=io+1
      if n=="sprites10.ok" and mode=="marker_error" then return nil,"storage quota" end
      if n=="sprites10.ok" and mode=="silent_marker" then return end
      max_write=math.max(max_write,#d) writes=writes+1 files[n]=d
    end,
    append=function(n,d)
      io=io+1
      if mode=="interrupted" then error("injected interrupted sprite write") end
      if mode=="write_error" then return false,"storage quota" end
      max_write=math.max(max_write,#d) files[n]=(files[n] or "")..d
    end,
    read=function(n) return files[n] end,
    remove=function(n) files[n]=nil return true end,
    exists=function(n) return files[n]~=nil end,
  },
  input={BUTTON={A=1,B=2,HOME=3,DOWN=4,LEFT=5,RIGHT=6,UP=7,AUX1=8,START=9},KIND={PRESSED=1,RELEASED=2}},
  app={exit=function() exited=true end},
}

package.path=DIR.."/?.lua"
-- The firmware uses a private module cache; package is unavailable to game code.
require=function(name)
  assert(not in_button,"module compilation inside on_button: "..name)
  assert(not in_generation_tick,"module compiled during sprite generation")
  if modules[name] then return modules[name] end
  if name=="screens" and mode=="screen_error" then error("injected screen load failure") end
  if name=="battle" and mode=="battle_error" then error("injected battle load failure") end
  if name=="battle" or name=="fx" then assert(TITLE==nil,"title retained while loading gameplay") end
  local f=assert(loadfile(DIR.."/"..name..".lua"))
  loading_module=name
  local result=f()
  loading_module=nil
  modules[name]=result or true
  return modules[name]
end

local function ticks(n,step)
  for _=1,n do
    now=now+(step or 20)
    local stage,before,beforeio=S,widgets,io
    in_generation_tick=stage==9
    on_tick()
    in_generation_tick=false
    if stage==9 then assert(io-beforeio<=1,"multiple flash writes in one tick") end
    if stage==6 or stage==11 or stage==12 then assert(widgets-before<=1,"startup created multiple widgets per tick") end
  end
end
local function press(b) in_button=true on_button(b,1) on_button(b,2) in_button=false end
local B=badge.input.BUTTON

-- ---- run ----
store.owned=3 store.act=1              -- own Pikachu and Charmander so SWITCH appears
if mode=="invalid_save" then store.owned=128 store.act=99 end
local chunk=assert(loadfile(DIR.."/hackamon.lua"))
chunk()
on_enter({})
if mode=="write_error" or mode=="marker_error" or mode=="silent_marker" then
  local ok,err=pcall(function() ticks(120) end)
  assert(not ok and string.find(err,"Sprite"),"storage failure was not reported")
  assert(S==13,"failed generation not suspended")
  ticks(3) press(B.HOME) assert(exited,"HOME did not exit failed generation")
  on_exit()
  return {files=files,peak=peak,writes=writes}
end
if mode=="interrupted" then
  local ok,err=pcall(function() ticks(120) end)
  assert(not ok and string.find(err,"injected"),"expected interrupted write")
  assert(files["sprites10.ok"]==nil,"stale completion marker survived interrupted regeneration")
  return {files=files,peak=peak,writes=writes}
end
if mode=="screen_error" or mode=="widget_error" then
  local ok,err=pcall(function() ticks(120) end)
  assert(not ok and string.find(err,"injected"),"expected setup failure was not reached")
  assert(S==13 and GEN==nil,"failed setup retained the renderer state")
  ticks(3) -- Must not call cleared GEN or continue a partially completed UI step.
  press(B.HOME) assert(exited,"HOME did not exit failed setup")
  on_exit() -- A partial UI may contain EI but no PI.
  print("HARNESS OK "..mode.." (no secondary error; HOME exits)")
  return {files=files,peak=peak,writes=writes}
end
ticks(120)                       -- first-launch render: 88 parts
for i=1,4 do
  local front,back=files["p"..i..".bin"],files["p"..i..".bin"]
  assert(#front==3212 and #back==3212,"wrong sprite size")
  assert(string.sub(front,1,12)==string.char(0x19,0x12,0,0,40,0,40,0,80,0,0,0),"not RGB565")
  for y=0,39 do for x=0,39 do
    local a,b=13+y*80+x*2,13+(y//2*2)*80+(x//2*2)*2
    assert(string.sub(front,a,a+1)==string.sub(back,b,b+1),"incorrect 2x pixel scale")
  end end
end
assert(files["sprites10.ok"]=="10")
assert(max_write<=652,"renderer exceeded the 652-byte chunk bound")
assert(io==0 or io==21,"expected zero cached writes or 21 generation writes")
if mode=="recipient" then assert(writes==0,"received sprites were regenerated") end
if mode=="missing" or mode=="upgrade" then assert(writes==5,"missing sprite not repaired") end
assert(TITLE,"title not loaded")
if mode=="upgrade" then
  for i=1,4 do assert(files["m"..i..".bin"]==nil and files["s"..i..".bin"]==nil,"old sprite survived migration") end
  assert(files["sprites9.ok"]==nil and files["icon.bin"]=="keep icon" and files["appdata/save"]=="keep save","migration changed unrelated data")
end
ticks(150)                       -- parade
press(B.A)
if mode=="title_error" or mode=="battle_error" or mode=="fx_error" or mode=="home_error" then
  local ok,err=pcall(function() ticks(40) end)
  assert(not ok and string.find(err,"injected"),"expected transition failure")
  assert(S==13,"failed transition did not enter escape state")
  ticks(3) press(B.HOME) assert(exited,"HOME did not exit stalled transition") on_exit()
  return {files=files,peak=peak,writes=writes}
end
if mode=="loading_exit" then
  ticks(1,100) assert(S==6,"not loading gameplay")
  press(B.HOME) assert(exited,"HOME did not exit gameplay loading") on_exit()
  return {files=files,peak=peak,writes=writes}
end
for _=1,40 do ticks(1) if S~=0 then press(B.A) press(B.DOWN) end end
ticks(10)
assert(TITLE==nil,"title not dropped")
assert(S==0 and BT and FX,"gameplay not ready")
local function arrows(n)
  local text=_G.W.MENU.text
  for _=1,300 do
    local old,ops=cur,ui_calls
    press(B.DOWN)
    assert(cur==old%n+1 and ui_calls==ops+1,"arrow press did more than one UI update")
    assert(_G.W.MENU.text==text and _G.W.CUE.align_=="top_left" and _G.W.CUE.y==3+(cur-1)*19,"arrow misplaced or menu rebuilt")
  end
  while cur~=1 do press(B.DOWN) end
end
arrows(3)
if mode=="invalid_save" then assert(owned==1 and act==1,"invalid save not repaired") end
press(B.A)                       -- SCAN
if mode=="no_nfc" then
  assert(not badge.nfc.enabled and S==0,"unavailable NFC not handled")
  on_exit()
  return {files=files,peak=peak,writes=writes}
end
assert(badge.nfc.enabled,"scan did not enable nfc")
badge.nfc.text="PKM03" ticks(20)
assert(not badge.nfc.enabled,"nfc still on after encounter")
press(B.A) ticks(60) press(B.A) ticks(60) press(B.A)
assert(S==3,"opening dialogue did not reach moves")
arrows(owned==1 and 2 or 3)
press(B.A)
for _=1,24 do
  if S~=4 then break end
  ticks(1,4000) press(B.A)
end
assert(S==3 or S==0,"round did not finish")
-- HOME from wherever we are, then SWITCH LEAD, then EXIT
on_button(B.HOME,2) ticks(5)
assert(not badge.nfc.enabled,"nfc on at home")
-- Interrupt dialogue repeatedly: no stale lines, callbacks, or accumulating particles.
local allocated=widgets
for round=1,40 do
  press(B.A) badge.nfc.text="PKM03" ticks(20)
  assert(S==4 and _G.W.MSG.text=="Wild BULBASAUR\nappeared!","unexpected encounter: S="..S.." text=".._G.W.MSG.text)
  on_button(B.HOME,2) ticks(2)
end
assert(widgets==allocated,"widgets grew across repeated encounters")
-- Exercise the four preallocated particles; play must never create more widgets.
S=3 -- Home uses its idle animation instead of FX.tick.
for round=1,10 do
  for _,pattern in ipairs({"fire","water","grass","elec","fireL","win","lose"}) do
    FX.start(pattern,"en") ticks(pattern=="fireL" and 90 or 5) ticks(1,4000)
  end
end
local settled=widgets
assert(settled==allocated,"particle pool grew during play")
assert(peak<=17,"widget budget exceeded")
for _=1,30 do FX.start("elec","en") ticks(5) ticks(1,4000) end
assert(widgets==settled,"particle widgets were not reused")
on_button(B.HOME,2) ticks(5)
-- Deterministic win, duplicate capture, loss, and a real mid-battle switch.
local function drain()
  for _=1,24 do
    if S~=4 then return end
    ticks(1,4000) press(B.A)
  end
  error("dialogue did not finish")
end
local function encounter(code)
  press(B.A) badge.nfc.text=code ticks(20) drain()
  assert(S==3,"encounter did not reach move menu")
end
owned,act=1,1 home()
encounter("PKM03") en.hp=1 press(B.A) drain()
assert(S==0 and owned==9 and store.owned==9,"capture was not saved")
encounter("PKM03") en.hp=1 press(B.A) drain()
assert(owned==9,"duplicate capture changed ownership")
encounter("PKM01") me.hp=1 press(B.A) drain()
assert(S==0 and owned==1 and act==1 and store.owned==1,"loss did not reset team")
owned,act=3,1 home()
encounter("PKM03")
press(B.DOWN) press(B.DOWN) press(B.A)
assert(S==5,"switch menu missing")
arrows(1)
press(B.A)
assert(me.id==2 and S==4,"switch did not change Pokemon")
drain() assert(S==3,"switch turn did not return to moves")
on_button(B.HOME,2) ticks(5)
press(B.DOWN) press(B.A) ticks(5)
on_button(B.HOME,2) ticks(5)
press(B.DOWN) press(B.DOWN) press(B.A) ticks(200,20)
assert(exited,"EXIT did not exit")
on_exit()
print("HARNESS OK "..mode.." peak_widgets="..peak.." max_write="..max_write.." writes="..io)
return {files=files,peak=peak,writes=writes}
