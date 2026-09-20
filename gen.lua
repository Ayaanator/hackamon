-- Preserve the original 20x20 art at a crisp integer 2x scale. Sprites are
-- opaque RGB565 with the cream background baked in (3,212 bytes each).
-- Write two rows per tick, never assemble a complete bitmap in Lua memory.
-- The completion marker travels with Share; private store flags do not.
SPR={
 {{k=0x202020,a=0xf8d030,b=0xc89820,r=0xe04040,w=0xffffff},
  ".kk..............kk..kkk............kkk..kkak..........kakk...kaak........kaak....kaaak......kaaak.....kaakkkkkkkkaak......kaaaaaaaaaaaak.....kaaaaaaaaaaaaaak....kaakwaaaaaakwaak....kaakkaaaaaakkaak....kaaaaaakkaaaaaak...krraaaakaaaakaaarrk.krraaaaakaakaaaarrk..kaaaaaaakkaaaaakkk..kaaaaaaaaaaaaakaak.kaaakaaaaaaaakaaaak.kaaaakaaaaaakaaaak..kbbaaaaaaaaaaaabbk...kkbaaakaakaaabkk......kkkkkkkkkkkkk..."}, -- Pikachu
 {{k=0x202020,a=0xf08838,b=0xc05820,c=0xf8e0a0,f=0xf8d838,g=0xf05028,w=0xffffff},
  "......kkkkk..............kaaaaak............kaaaaaaak...........kawkaawkk...........kakkaakkk...........kaaaaaaak............kaakaak..............kkkkk..............kaaaaak..kk........kaakcckaak.kk......kaaakccckaak.kf.....kaaakccckaak.kgk....kaaakccckaaakkfgk...kaakkccckbaaakffk....kakccckbbaaaakk.....kaakkkbbaaaaak.....kbaaaaaabkkkkk.....kbbkaaaaakbbk.......kbkkkaaakkkbk.......kkk.kkkkk..kk....."}, -- Charmander
 {{k=0x202020,a=0x70b0e8,b=0x3878b8,c=0xd09848,d=0x886030,e=0xf0d8a0,w=0xffffff},
  ".....kkkkkk.............kaaaaaak...........kaaaaaaaak..........kaawkaaawk..........kaakkaaakk..........kaaaaaaaak...........kaakaaak............kkaaaaakkkk........kbbkkkkkcccdk......kbbbkeeekccccdk.....kbbbkeeeekccccdk....kbbbkeeeekcccdck.....kbkkeeeekccddk.......kkeeeeekdddk.......kbbkeeekkkkk.......kbbbkkkkkbbbk.......kbbbk...kbbbk.......kbbbk...kbbbk........kkk.....kkk.........................."}, -- Squirtle
 {{k=0x202020,a=0x60c8a8,b=0x309878,c=0x80d860,d=0x40a040,r=0xd03030,w=0xffffff},
  "..........kkkkkk............kkcccccdk..........kcccddcccdk........kccdccccdcck.......kkcdccccccddk......kaakkcddccddk......kaaaaakkkkkkk......kaaaaaaaaaaaak.....kaarkaaaaaakraak....kaakkaaaaaakkaak....kaaaaaaaaaaaaaaak...kakaaaakbbaaakaak...kaakkkkaaaaaaaaak...kbaaaaaabaaaabaak....kaaaakkaaaaakbbk....kaaaak.kaaaak.kk....kbbbk..kbbbbk.......kbbbk..kbbbbk........kkk....kkkk.........................."}, -- Bulbasaur
}

local job=-10
local function px(c)
  local v=(c//65536//8)*2048+((c//256)%256//4)*32+(c%256//8)
  return string.char(v%256,v//256)
end
GEN=function()
  if job<0 then
    -- One obsolete generated asset per tick; keep saves and the launcher icon.
    local i=-job
    if i==10 then badge.fs.remove("sprites10.ok")
    elseif i==9 then badge.fs.remove("sprites9.ok")
    else badge.fs.remove((i%2==0 and "m" or "s")..((i+1)//2)..".bin") end
    job=job+1 return false
  end
  local id,part=job//11+1,job%11
  local name=spr(id)
  if part==0 then
    badge.fs.write(name,string.char(0x19,0x12,0,0,40,0,40,0,80,0,0,0))
  else
    local pal,art=SPR[id][1],SPR[id][2]
    local row={}
    for y=part*2-1,part*2 do
      for x=1,20 do
        local at=(y-1)*20+x
        local ch=string.sub(art,at,at)
        local p=px(ch=="." and 0xf8f8f0 or pal[ch])
        row[x]=p..p
      end
      local bytes=table.concat(row)
      badge.fs.append(name,bytes..bytes)
    end
  end
  job=job+1
  if job%3==0 then collectgarbage("collect") end
  if job==44 then badge.fs.write("sprites10.ok","10") return true end
  return false
end
