-- Feed the compiler 256-byte chunks from host storage, for both compared revisions.
loadfile=function(path)
  local at=0
  return load(function()
    local chunk=READ(path,at) at=at+#chunk
    if #chunk>0 then return chunk end
  end,"@"..path)
end
-- Headless comparison only. Flash bytes live in Python; widgets are tiny Lua mocks.
-- Subtract the same harness baseline from both versions. Not ESP32/native RAM.
local noop=function() end
local widgets=0
local methods={}
for _,name in ipairs({"style","align","set_pos","set_size","set_text","hidden","set_src","set_range","set_value","bring_to_front"}) do methods[name]=noop end
methods.delete=function() widgets=widgets-1 end
local mt={__index=methods}
local function widget() widgets=widgets+1 return setmetatable({},mt) end
local now=0
local modules={}
local cache={}
badge={
 ui={label=widget,box=widget,bar=widget,image=widget},
 led={set=noop,set_all=noop,clear=noop,show=noop},
 sys={ms=function() return now end,log=noop,random=function(n) return math.random(0,(n or 65536)-1) end,
 heap=function() return math.floor(collectgarbage("count")*1024) end,
 gc_step=function() collectgarbage("step") end,
 stats=function() return {lua_used=badge.sys.heap(),lua_peak=0,free_heap=77728,widgets=widgets} end},
 store={get_int=function(k,d) return cache[k] or d end,set_int=function(k,v) cache[k]=v end},
 fs={write=WRITE,append=APPEND,exists=EXISTS,remove=REMOVE},
 nfc={enable=function() return true end,disable=noop,
 clear=function() badge.nfc.text=nil end,
 card=function() if badge.nfc.text then return true end end,
 read_text=function() return badge.nfc.text end},
 input={BUTTON={A=1,B=2,HOME=3,DOWN=4,LEFT=5,RIGHT=6,UP=7},KIND={PRESSED=1,RELEASED=2}},
 app={exit=noop}
}
return function(dir)
 require=function(name)
   if not modules[name] then modules[name]=assert(loadfile(dir.."/"..name..".lua"))() or true end
   return modules[name]
 end
 local function ticks(n,dt) for _=1,n do now=now+(dt or 20) on_tick() end end
 local function press(b) on_button(b,1) on_button(b,2) end
 math.randomseed(42)
 collectgarbage("collect")
 local baseline=badge.sys.heap()
 local function sample(name)
   collectgarbage("collect") MARK(name,badge.sys.heap()-baseline)
 end
 local fn=assert(loadfile(dir.."/hackamon.lua")) fn() fn=nil
 sample("main loaded")
 on_enter({}) ticks(250)
 assert(S==7,"title did not load") sample("title")
 press(1) ticks(80)
 assert(S==0,"game not ready") sample("home")
 press(1) badge.nfc.text="PKM03" ticks(20)
 for _=1,24 do if S~=4 then break end ticks(1,4000) press(1) end
 assert(S==3,"battle not ready") sample("battle")
 press(1)
 ticks(5) sample("attack")
 for _=1,24 do if S~=4 then break end ticks(1,4000) press(1) end
 on_button(3,2) sample("after battle")
end
