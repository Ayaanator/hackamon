-- Battle logic: moves, status effects, the enemy's turn, encounters, and the battle
-- menus. Loaded with fx.lua on the first SCAN and resident for the session. Shares state with
-- main.lua through globals: P BIT TP S cur act owned me en team, the helpers own
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
  for i=1,5 do if team[i] and i~=me.id and team[i].hp>0 then o[#o+1]=i t[#t+1]=P[i][1] end end
  return o,t
end

local function use(u,t,special,who)
  if u.hp==0 or t.hp==0 then return end
  if u.par>0 and badge.sys.random(4)==0 then push(u.name.." is\nparalyzed! It\ncan't move!") return end
  local p,d=P[u.id],P[t.id]
  local fx=special and p[6]
  local msg=u.name.." used\n"..p[special and 5 or 4].."!"
  local target=fx=="def" and (who=="me" and "en" or "me") or who
  local pattern=special and (fx=="burn" and "fireL" or fx.."L") or "hit"
  if (fx=="par" or fx=="seed") and badge.sys.random(100)>=90 then
    push(msg) push("But it missed!") return
  end
  if not fx or fx=="burn" or fx=="psy" then
    -- Swift: Normal/special/60. Psystrike: Psychic/special/100, targets Defense.
    local sp=fx or u.id==5
    local power=u.id==5 and (special and 100 or 60) or 40
    local defense=sp and fx~="psy" and d[10] or d[8]*(2+t.def)//2
    local dmg=(8*power*p[sp and 9 or 7]//defense)//50+2
    dmg=dmg*(85+badge.sys.random(16))//100
    local e=fx=="psy" and (t.id==4 and 4 or (t.id==5 and 1 or 2))
      or (fx=="burn" and (d[3]==3 and 4 or ((d[3]==1 or d[3]==2) and 1 or 2)) or 2)
    if fx then dmg=dmg*3//2 end
    dmg=dmg*e//2
    if not sp and u.burn>0 then dmg=dmg//2 end
    t.hp=math.max(0,t.hp-math.max(1,dmg))
    push(msg,target,pattern)
    if e==4 then push("It's super\neffective!") elseif e==1 then push("It's not very\neffective...") end
    if fx~="burn" or t.hp==0 or d[3]==1 or t.burn+t.par>0 or badge.sys.random(10)~=0 then return end
    t.burn=1 push(t.name.."\nwas burned!",who,"burn")
  else
    push(msg,target,pattern)
    if fx=="def" and u.def<6 then u.def=u.def+1 push(u.name.."'s\nDefense rose!")
    elseif fx=="seed" and d[3]~=3 and t.seed==0 then t.seed=1 push(t.name.."\nwas seeded!")
    elseif fx=="par" and d[3]~=4 and t.par+t.burn==0 then t.par=1 push(t.name.."\nis paralyzed!")
    else push("But it failed!") end
  end
end
local function tick(s,o,who,seed)
  if s.hp==0 or o.hp==0 then return end
  if seed and s.seed>0 then
    local drain=math.min(s.hp,math.max(1,s.max//8))
    s.hp=s.hp-drain o.hp=math.min(o.max,o.hp+drain)
    push("LEECH SEED saps\n"..s.name.."!",who,"seed")
  end
  if not seed and s.burn>0 then
    s.hp=math.max(0,s.hp-math.max(1,s.max//16)) push(s.name.."\nis hurt by\nits burn!",who,"burn")
  end
end
local function speed(s) return P[s.id][11]//(s.par>0 and 2 or 1) end
-- Quick Attack has +1 priority. Otherwise Speed decides; ties are random.
local function turn(move)
  local fx=P[en.id][6]
  local special=badge.sys.random(10)>=6 and (fx=="burn" or fx=="psy" or (fx=="seed" and me.seed==0 and me.id~=4)
    or (fx=="par" and me.par+me.burn==0 and me.id~=1) or (fx=="def" and en.def<6))
  local a=speed(me)+(move==1 and me.id==1 and 100 or 0)
  local b=speed(en)+(not special and en.id==1 and 100 or 0)
  local first=a>b or (a==b and badge.sys.random(2)==0)
  if move and first then use(me,en,move==2,"en") end
  use(en,me,special,"me")
  if move and not first then use(me,en,move==2,"en") end
  for j=1,2 do
    if speed(me)>=speed(en) then tick(me,en,"me",j==1) tick(en,me,"en",j==1)
    else tick(en,me,"en",j==1) tick(me,en,"me",j==1) end
  end
  local f=bmenu
  if en.hp==0 then
    push(en.name.."\nfainted!")
    if own(en.id) then push("You won!",nil,"win")
    else owned=owned+BIT[en.id] push("You caught\n"..P[en.id][1].."!",nil,"win") save() end
    f=home
  elseif me.hp==0 then
    push(P[me.id][1].."\nfainted!",nil,"lose") push("Your team rests\nand recovers.")
    f=home
  end
  say(f)
end

function BT.encounter(i)
  en=side(i,true) team={} FX.reset() FX.idle(P[act][3])
  for j=1,5 do if own(j) then team[j]=side(j) end end
  me=team[act]
  W.EB:hidden(false) EI:set_src(spr(i,false)) EI:hidden(false) log("wild "..i)
  push("Wild "..P[i][1].."\nappeared!",nil,"appear") push("Go! "..P[me.id][1].."!")
  say(bmenu)
end

-- Button handling for the move menu (S==3) and the switch menu (S==5).
function BT.button(up,dn,A,B)
  if up or dn then cursor(up and -1 or 1) return end
  if S==3 then
    if A and cur==3 then
      local o,t=others()
      if #o==0 then W.MSG:set_text("No other Pokemon\ncan fight!") return end
      S=5 cur=1 menu(t) W.MSG:set_text("Switch to\nwhich Pokemon?")
    elseif A then turn(cur)
    elseif B then push("Got away safely!") say(home) end
  elseif S==5 then
    local o,t=others()
    if B then bmenu()
    elseif A then
      local i=o[cur]
      push("Come back,\n"..P[me.id][1].."!") me.seed,me.def=0,0
      me=team[i] PI:set_src(spr(i,true)) FX.idle(P[i][3])
      push("Go! "..P[i][1].."!") turn()
    end
  end
end
