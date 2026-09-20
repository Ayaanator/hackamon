-- Exercise the real battle code with reproducible rolls, without UI or animation.
local dir=...
assert(loadfile(dir.."/hackamon.lua"))()
local noop=function() end
badge={sys={random=function(n) return math.random(0,n-1) end}}
W={MSG={set_text=noop},EB={hidden=noop}}
assert(loadfile(dir.."/game.lua"))()
EI={set_src=noop,hidden=noop} PI=EI FX={idle=noop,reset=noop}
log,save,push=noop,noop,noop
local options
function menu(t) options=t end
function home() S=0 end
function say(f) f() end
assert(loadfile(dir.."/battle.lua"))()
return function(seed,smart,solo)
  math.randomseed(seed)
  owned,act=15,solo or 1 me=side(act) en={}
  BT.encounter(5)
  if solo then for i=1,4 do if i~=solo then team[i].hp=0 end end end
  local turns=0
  while S~=0 and turns<100 do
    if S==5 then
      local priority=smart and {1,4,2,3} or {1,2,3,4}
      local choice
      for _,id in ipairs(priority) do
        for j,name in ipairs(options) do if name==P[id][1] then choice=j break end end
        if choice then break end
      end
      assert(choice) cur=choice BT.button(false,false,true,false)
    else
      assert(S==3)
      local special=smart and ((me.id==1 and en.par+en.burn==0)
        or (me.id==4 and en.seed==0) or me.id==2
        or (me.id==3 and me.def<2 and en.hp>25))
      cur=special and 2 or 1
      BT.button(false,false,true,false)
      turns=turns+1
    end
  end
  assert(turns<100,"battle did not terminate")
  local survivors=0
  for i=1,4 do if team[i].hp>0 then survivors=survivors+1 end end
  return en.hp==0,turns,survivors
end
