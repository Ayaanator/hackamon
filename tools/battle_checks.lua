-- Deterministic battle checks, independent of native widgets and animation timing.
local dir=...
assert(loadfile(dir.."/hackamon.lua"))()
local lines,finished,rolls
badge={sys={random=function(n)
  local value=rolls[n] or 0
  assert(value>=0 and value<n)
  return value
end}}
W={MSG={set_text=function() end},EB={hidden=function() end}}
assert(loadfile(dir.."/game.lua"))()
EI={set_src=function() end,hidden=function() end}
PI=EI
FX={idle=function() end,reset=function() end}
function log() end
function save() end
function home() S=0 end
function menu() end
function say(f) finished=f S=4 end
function push(text,target,pattern)
  lines[#lines+1]={text=text,target=target,pattern=pattern,hp=me.hp,enemy=en.hp}
end
assert(loadfile(dir.."/battle.lua"))()
local function setup(a,b)
  owned,act,S,cur=31,a,3,1
  team={} for i=1,5 do team[i]=side(i) end
  me,en=team[a],side(b,true)
  lines,rolls={}, {[16]=15,[4]=1}
end
local function move(choice)
  cur=choice BT.button(false,false,true,false)
end
local function find(text)
  for _,e in ipairs(lines) do if e.text:find(text,1,true) then return e end end
end
local function resetlines() lines={} S=3 end

-- These are neutral-nature level-15 zero-IV/EV stats, calculated independently.
local base={{35,55,40,50,50,90},{39,52,43,60,50,65},{44,48,65,50,64,43},{45,49,49,65,65,45}}
for i,s in ipairs(base) do
  assert(P[i][2]==s[1]*30//100+25)
  for j=2,6 do assert(P[i][j+5]==s[j]*30//100+5) end
end

-- Normal attacks: no Electric STAB or super-effective bonus against Squirtle.
setup(1,3) move(1)
assert(lines[1].pattern=="hit" and lines[1].enemy==31,"Quick Attack should deal 7, Normal damage")
assert(not find("effective"))
setup(1,3) rolls[16]=0 move(1)
assert(lines[1].enemy==33,"85% damage roll should deal 5")
setup(2,3) move(1)
assert(lines[1].enemy==31 and lines[1].pattern=="hit","Scratch is Normal")

-- Ember: base 40, special stats, STAB, 2x Grass, 0.5x Water/Fire.
setup(2,4) move(2)
assert(lines[1].enemy==14 and lines[1].pattern=="fireL","Ember vs Grass should deal 24")
assert(find("super") and en.burn==1,"10% roll should burn")
setup(2,3) move(2)
assert(lines[1].enemy==32 and find("not very"),"Ember vs Water should deal 6")
setup(2,2) move(2)
assert(lines[1].enemy==30 and en.burn==0,"Fire resists Ember and cannot burn")
for roll=0,9 do
  setup(2,3) rolls[10]=roll move(2)
  assert(en.burn==(roll==0 and 1 or 0),"Ember burn probability is not 1/10")
end

-- Withdraw changes physical Defense by one stage, max +6, no special reduction.
setup(3,4) move(2)
assert(me.def==1 and lines[2].target=="me" and lines[2].pattern=="defL","Withdraw should affect the user")
setup(1,3) en.def=1 move(1)
assert(lines[1].enemy==33,"+1 Defense is 1.5x, not 2x")
setup(2,3) en.def=6 move(2)
assert(lines[1].enemy==32,"Withdraw must not weaken Ember")
setup(3,4) me.def=6 move(2)
assert(me.def==6 and find("failed"),"Defense must cap at +6")

-- Status moves never deal direct damage; modern accuracy and type immunity.
setup(1,3) move(2)
assert(lines[1].enemy==en.max and en.par==1 and me.hp==me.max-9)
for roll=0,3 do
  setup(3,4) me.par=1 rolls[4]=roll move(1)
  assert((find("SQUIRTLE used")~=nil)==(roll~=0),"player paralysis must block 1/4 moves")
  setup(3,4) en.par=1 rolls[4]=roll move(1)
  assert((find("Enemy BULBASAUR used")~=nil)==(roll~=0),"enemy paralysis must block 1/4 moves")
end
setup(1,3) rolls[100]=90 move(2)
assert(en.par==0 and find("missed"))
setup(1,1) move(2)
assert(en.par==0 and find("failed"),"Electric Pokemon resist paralysis")
setup(1,3) en.burn=1 move(2)
assert(en.par==0 and en.burn==1,"major statuses cannot stack")
setup(3,4) me.par=1
for _=1,5 do me.hp=me.max en.hp=en.max resetlines() move(1) assert(me.par==1) end

-- Speed determines turn order, including paralysis; Quick Attack keeps priority.
setup(3,4) move(1) assert(lines[1].text:find("Enemy BULBASAUR",1,true))
setup(3,4) en.par=1 move(1) assert(lines[1].text:find("SQUIRTLE used",1,true))
setup(1,2) me.par=1 move(1) assert(lines[1].text:find("PIKACHU used",1,true))
setup(1,2) me.par=1 move(2) assert(lines[1].text:find("Enemy CHARMANDER",1,true))
setup(3,2) me.hp=1 move(1)
assert(not find("SQUIRTLE used"),"a fainted Pokemon must not act")
setup(2,2) rolls[2]=1 move(1) assert(lines[1].text:find("Enemy CHARMANDER",1,true),"Speed tie must be randomized")

-- Burn persists, halves physical damage, not special; chip is floor(max HP/16).
setup(1,3) me.burn=1 move(1)
assert(lines[1].enemy==35 and me.burn==1 and me.hp==me.max-9-2)
setup(2,3) me.burn=1 move(2)
assert(lines[1].enemy==32,"burn should not halve special damage")

-- Seed drains 1/8 max HP, heals actual HP lost, fails against Grass, clears on switch.
setup(4,3) me.hp=20 move(2)
assert(en.seed==1 and en.hp==34 and me.hp==20-8+4)
setup(4,4) move(2) assert(en.seed==0 and find("failed"))
setup(4,3) rolls[100]=90 move(2) assert(en.seed==0 and find("missed"))
setup(3,4) me.hp=1 me.seed=1 me.def=2 me.burn=1 me.par=1
move(3) cur=1 BT.button(false,false,true,false)
assert(me.id==1 and team[3].hp==1 and team[3].seed==0 and team[3].def==0)
assert(team[3].burn==1 and team[3].par==1,"switching must preserve major statuses and HP")
setup(3,4) en.hp=1 en.seed=1 me.hp=10 me.par=1 rolls[4]=0
-- Force the enemy to use a status move; player is immobilized, seed takes the final 1 HP.
rolls[10]=9 move(1)
assert(en.hp==0 and me.hp==11,"seed must heal actual damage, not the nominal 1/8")
-- Mewtwo uses custom boss stats: lower damage/defenses, still 100 HP.
assert(P[5][1]=="MEWTWO" and P[5][2]==100 and P[5][3]==5)
for j,v in ipairs({20,18,13,18,33}) do assert(P[5][j+6]==v) end
assert(P[5][4]=="SWIFT" and P[5][5]=="PSYSTRIKE")
-- Swift is special, Normal/60, no Psychic STAB, burn penalty or Defense-stage effect.
setup(5,3) move(1)
assert(lines[1].enemy==31 and lines[1].pattern=="hit" and en.burn==0,"Swift should deal 7")
setup(5,3) me.burn=1 en.def=6 move(1)
assert(lines[1].enemy==31,"Swift incorrectly used physical rules")
setup(5,3) rolls[16]=0 move(1) assert(lines[1].enemy==33,"Swift minimum roll should deal 5")
-- Psystrike is Psychic/100, uses Sp. Attack against physical Defense, with STAB.
setup(5,3) en.hp=200 move(2)
assert(lines[1].enemy==185 and lines[1].pattern=="psyL" and en.burn==0,"Psystrike should deal 15")
setup(5,3) me.burn=1 en.def=2 en.hp=200 move(2)
assert(lines[1].enemy==191,"Psystrike must respect Withdraw, not burn")
setup(5,4) en.hp=200 move(2)
assert(lines[1].enemy==164 and find("super"),"Bulbasaur's Poison typing is weak to Psychic")
setup(5,5) move(2)
assert(lines[1].enemy==91 and find("not very"),"Mewtwo resists Psychic")
setup(3,5) rolls[10]=9 move(1)
assert(lines[1].pattern=="psyL" and lines[1].target=="me" and me.hp==23,"enemy cannot use Psystrike")
setup(1,5) move(1)
assert(lines[1].text:find("PIKACHU used",1,true),"Quick Attack lost priority against Mewtwo")
-- Loss ends the battle and heals at home; it no longer deletes the collection.
setup(3,2) me.hp=1 move(1) finished()
assert(S==0 and owned==31 and act==3,"loss changed saved ownership/lead")
-- Neither Mewtwo move can one-shot any healthy starter, even at maximum roll.
for id=1,4 do for choice=1,2 do for roll=0,15 do
  setup(5,id) rolls[16]=roll move(choice)
  assert(en.hp>0,"Mewtwo one-shot a healthy starter")
end end end
-- Starter hits are stronger against Mewtwo's lower defenses.
setup(1,5) move(1) assert(lines[1].enemy==91,"Quick Attack should deal 9")
setup(1,5) rolls[16]=0 move(1) assert(lines[1].enemy==93,"Quick Attack minimum should deal 7")
setup(2,5) move(2)
assert(find("CHARMANDER used").enemy==85,"Ember should deal 15 before burn")
-- Boss seed resistance prevents percentage damage from replacing the whole team.
setup(4,5) move(2) assert(en.seed==1 and en.hp==97,"Mewtwo seed drain should be 3")
setup(4,5) en.hp=1 en.seed=1 me.par=1 rolls[4]=0 move(1)
assert(en.hp==0,"resisted seed must still finish a weakened boss")
-- Every starter is required, regardless of which other ownership bits are set.
for mask=1,31,2 do
  setup(1,3) owned=mask
  local before=en
  BT.encounter(5)
  if mask%16~=15 then
    assert(en==before and find("Bring PIKACHU"),"incomplete team reached the boss")
    finished() assert(S==0)
  else assert(en.id==5 and en.hp==100) end
end
-- Boss faint replacements are free; cancellation cannot revive/act with a fainted lead.
setup(1,5) me.hp=1 rolls[10]=9 move(1) finished()
assert(S==5 and team[1].hp==0,"boss faint ended the whole battle")
local boss_hp=en.hp
BT.button(false,false,false,true) assert(S==5,"cancel returned to a fainted Pokemon")
cur=1 BT.button(false,false,true,false)
assert(me.id==2 and me.hp==36 and en.hp==boss_hp,"replacement consumed an enemy attack")
finished() assert(S==3)
-- Only running out of surviving teammates ends a Mewtwo battle.
setup(1,5) me.hp=1 for i=2,5 do team[i].hp=0 end
rolls[10]=9 move(1) finished()
assert(S==0 and owned==31,"team wipe did not return home with collection intact")
print("BATTLE CHECKS OK "..dir)
