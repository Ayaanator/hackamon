-- Preserve the original 20x20 art at a crisp integer 2x scale. Sprites are
-- opaque RGB565 with the cream background baked in (3,212 bytes each).
-- Batch eight output rows per write: at most 652 bytes including the header.
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
local function written(ok,err)
  if ok==false or err then error("Sprite write failed: "..tostring(err)) end
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
  if job>=20 then
    -- Read back one sprite per tick; do not trust exists() on affected firmware.
    if job<24 then assert(valid(job-19),"Sprite invalid: "..(job-19))
    elseif job==24 then written(badge.fs.write("sprites10.ok","10"))
    else assert(badge.fs.read("sprites10.ok")=="10","Sprite marker not saved") return true end
    job=job+1 return false
  end
  local id,part=job//5+1,job%5
  local name=spr(id)
  local pal,art=SPR[id][1],SPR[id][2]
  local batch,row={},{}
  if part==0 then
    for k,c in pairs(pal) do local p=px(c) pal[k]=p..p end
    local p=px(0xf8f8f0) pal["."]=p..p
    batch[1]=string.char(0x19,0x12,0,0,40,0,40,0,80,0,0,0)
  end
  for y=part*4+1,part*4+4 do
    for x=1,20 do
      local at=(y-1)*20+x
      row[x]=pal[string.sub(art,at,at)]
    end
    local bytes=table.concat(row)
    batch[#batch+1]=bytes..bytes
  end
  local bytes=table.concat(batch)
  if part==0 then written(badge.fs.write(name,bytes)) else written(badge.fs.append(name,bytes)) end
  job=job+1
  badge.sys.gc_step()
  return false,part==0 and id or nil
end
