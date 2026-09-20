-- Preserve the original 20x20 art at a crisp integer 2x scale. Sprites are
-- opaque RGB565 with the cream background baked in (3,212 bytes each).
-- Batch eight output rows per write: at most 652 bytes including the header.
-- The completion marker travels with Share; private store flags do not.
-- Run-length art: a number repeats the following pixel letter (or background dot).
SPR={
 {{k=0x202020,a=0xf8d030,b=0xc89820,r=0xe04040,w=0xffffff},
  ".kk14.kk..3k12.3k..kkak10.kakk3.kaak8.kaak4.k3ak6.k3ak5.kaa8kaak6.k12ak5.k14ak4.kaakw6akwaak4.kaakk6akkaak4.k6akk6ak3.krr4ak4ak3arrk.krr5akaak4arrk..k7akk5a3k..k13akaak.k3ak8ak4ak.k4ak6ak4ak..kbb12abbk3.kkb3akaak3abkk6.13k3."}, -- Pikachu
 {{k=0x202020,a=0xf08838,b=0xc05820,c=0xf8e0a0,f=0xf8d838,g=0xf05028,w=0xffffff},
  "6.5k14.k5ak12.k7ak11.kawkaawkk11.kakkaa3k11.k7ak12.kaakaak14.5k14.k5ak..kk8.kaakcckaak.kk6.k3ak3ckaak.kf5.k3ak3ckaak.kgk4.k3ak3ck3akkfgk3.kaakk3ckb3akffk4.kak3ckbb4akk5.kaa3kbb5ak5.kb6ab5k5.kbbk5akbbk7.kb3k3a3kbk7.3k.5k..kk5."}, -- Charmander
 {{k=0x202020,a=0x70b0e8,b=0x3878b8,c=0xd09848,d=0x886030,e=0xf0d8a0,w=0xffffff},
  "5.6k13.k6ak11.k8ak10.kaawk3awk10.kaakk3akk10.k8ak11.kaak3ak12.kk5a4k8.kbb5k3cdk6.k3bk3ek4cdk5.k3bk4ek4cdk4.k3bk4ek3cdck5.kbkk4ekccddk7.kk5ek3dk7.kbbk3e5k7.k3b5k3bk7.k3bk3.k3bk7.k3bk3.k3bk8.3k5.3k26."}, -- Squirtle
 {{k=0x202020,a=0x60c8a8,b=0x309878,c=0x80d860,d=0x40a040,r=0xd03030,w=0xffffff},
  "10.6k12.kk5cdk10.k3cdd3cdk8.kccd4cdcck7.kkcd6cddk6.kaakkcddccddk6.k5a7k6.k12ak5.kaark6akraak4.kaakk6akkaak4.k15ak3.kak4akbb3akaak3.kaa4k9ak3.kb6ab4abaak4.k4akk5akbbk4.k4ak.k4ak.kk4.k3bk..k4bk7.k3bk..k4bk8.3k4.4k26."}, -- Bulbasaur
 {{k=0x302038,a=0xe8e0f0,b=0xaaa0c0,c=0xc858a8,d=0xf080d0,w=0xffffff,r=0xe050d8},
  "6.kk..kk14.kak.kak13.k5ak12.kawrakwrk12.k4abk14.kbbk14.3kaa3k10.kk7abkk7.kak.k4abk.kak5.kk..k4abk..kk10.kabbk5.kk8.kaccbk3.kddk6.kaa3cbk..kcdk5.kaabkccabk.kcck5.kaak.kcaak.kcck5.kaak..kaak3ck6.kabk..kabkcck6.k3ak..kaabkk6.kawaak..kaawak7.4k4.4k4."}, -- Mewtwo
}

local job=-11
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
    if i==11 then badge.fs.remove("sprites11.ok")
    elseif i==10 then badge.fs.remove("sprites10.ok")
    elseif i==9 then badge.fs.remove("sprites9.ok")
    else badge.fs.remove((i%2==0 and "m" or "s")..((i+1)//2)..".bin") end
    job=job+1 return false
  end
  if job>=25 then
    -- Read back one sprite per tick; do not trust exists() on affected firmware.
    if job<30 then assert(valid(job-24),"Sprite invalid: "..(job-24))
    elseif job==30 then written(badge.fs.write("sprites11.ok","11"))
    else assert(badge.fs.read("sprites11.ok")=="11","Sprite marker not saved") return true end
    job=job+1 return false
  end
  local id,part=job//5+1,job%5
  local name=spr(id)
  local pal,art=SPR[id][1],SPR[id][2]
  local batch,row={},{}
  if part==0 then
    art=string.gsub(art,"(%d+)(.)",function(n,c) return string.rep(c,tonumber(n)) end)
    SPR[id][2]=art
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
