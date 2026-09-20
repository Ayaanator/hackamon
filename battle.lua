-- Battle logic: moves, status effects, the enemy's turn, encounters, and the battle
-- menus. Loaded with fx.lua on the first SCAN and resident for the session. Shares state with
-- main.lua through globals: P BIT SUP TP S cur act owned me en team, the helpers own
-- spr log push say menu side save home, the widget table W, images EI PI, and FX.
BT={}
local function items()
  local t={P[me.id][4],P[me.id][5]}
  if owned~=BIT[me.id] then t[3]="SWITCH" end
  return t
end
local function bmenu() S=3 cur=1 W.MSG:set_text("What will\n"..P[me.id][1].." do?") menu(items()) end
local function others()
  local o,t={},{}
  for i=1,4 do if own(i) and i~=me.id and (team[i] or 0)>0 then o[#o+1]=i t[#t+1]=P[i][1] end end
  return o,t
end

local function use(u,t,special,who)
  local p=P[u.id]
  local a,d=p[3],P[t.id][3]
  local power= special and p[7] or 7
  local name=p[special and 5 or 4]
  local effect=special and p[6] or nil
  if power>0 then
    local e=SUP[a]==d and 3 or ((SUP[d]==a or (a==4 and d==3)) and 1 or 2)
    local dmg=math.max(1,(power+badge.sys.random(3))*e//2)
    if t.def>0 then dmg=math.max(1,dmg//2) end
    t.hp=math.max(0,t.hp-dmg)
    push(u.name.." used\n"..name.."!",who,TP[a]..(effect and "L" or ""))
    if e==3 then push("It's super\neffective!") elseif e==1 then push("It's not very\neffective...") end
  else push(u.name.." used\n"..name.."!",who,TP[a].."L") end
  local fx,self=effect,who=="me" and "en" or "me"
  if fx=="burn" and t.burn==0 then t.burn=3 push(t.name.."\nwas burned!",who,"burn")
  elseif fx=="def" then u.def=3 push(u.name.."\nwithdrew into\nits shell!",self,"def")
  elseif fx=="seed" and t.seed==0 then t.seed=3 push(t.name.."\nwas seeded!",who,"grass")
  elseif fx=="par" and t.par==0 then t.par=3 push(t.name.."\nis paralyzed!",who,"par") end
end
local function tick(s,o,who)
  if s.hp==0 then return end
  if s.burn>0 then s.hp=math.max(0,s.hp-2) s.burn=s.burn-1 push(s.name.."\nis hurt by\nits burn!",who,"burn") end
  if s.seed>0 and s.hp>0 then
    s.hp=math.max(0,s.hp-3) o.hp=math.min(o.max,o.hp+3) s.seed=s.seed-1
    push("LEECH SEED saps\n"..s.name.."!",who,"seed")
  end
  if s.def>0 then s.def=s.def-1 end
end
-- Enemy acts, effects tick, then win / loss / back to the menu.
local function turn()
  if en.hp>0 then
    local go=true
    if en.par>0 then
      en.par=en.par-1
      if badge.sys.random(2)==0 then push(en.name.." is\nparalyzed! It\ncan't move!") go=false end
    end
    if go then
      local special,fx=false,P[en.id][6]
      if badge.sys.random(10)>=6 and ((fx=="burn" and me.burn==0) or (fx=="seed" and me.seed==0)
         or (fx=="par" and me.par==0) or (fx=="def" and en.def==0)) then special=true end
      use(en,me,special,"me")
    end
  end
  tick(me,en,"me") tick(en,me,"en")
  local f=bmenu
  if en.hp==0 then
    push(en.name.."\nfainted!")
    if own(en.id) then push("You won!",nil,"win")
    else owned=owned+BIT[en.id] push("You caught\n"..P[en.id][1].."!",nil,"win") save() end
    f=home
  elseif me.hp==0 then
    push(P[me.id][1].."\nfainted!",nil,"lose") push("You lost all\nyour Pokemon...") push("Starting over\nwith PIKACHU.")
    f=function() owned=1 act=1 save() home() end
  end
  say(f)
end

function BT.encounter(i)
  en=side(i,true) team={} FX.reset() FX.idle(P[act][3])
  for j=1,4 do if own(j) then team[j]=P[j][2] end end
  me=side(act)
  W.EB:hidden(false) EI:set_src(spr(i,false)) EI:hidden(false) log("wild "..i)
  push("Wild "..P[i][1].."\nappeared!",nil,"appear") push("Go! "..P[me.id][1].."!")
  say(bmenu)
end

-- Button handling for the move menu (S==3) and the switch menu (S==5).
function BT.button(up,dn,A,B)
  if S==3 then
    local it=items() local n=#it
    if up then cur=(cur+n-2)%n+1 menu(it)
    elseif dn then cur=cur%n+1 menu(it)
    elseif A and cur==3 then
      local o,t=others()
      if #o==0 then W.MSG:set_text("No other Pokemon\ncan fight!") return end
      S=5 cur=1 menu(t) W.MSG:set_text("Switch to\nwhich Pokemon?")
    elseif A then use(me,en,cur==2,"en") turn()
    elseif B then push("Got away safely!") say(home) end
  elseif S==5 then
    local o,t=others()
    if up then cur=(cur+#o-2)%#o+1 menu(t)
    elseif dn then cur=cur%#o+1 menu(t)
    elseif B then bmenu()
    elseif A then
      local i=o[cur]
      push("Come back,\n"..P[me.id][1].."!") team[me.id]=me.hp
      me=side(i) me.hp=team[i] PI:set_src(spr(i,true)) FX.idle(P[i][3])
      push("Go! "..P[i][1].."!") turn()
    end
  end
end
