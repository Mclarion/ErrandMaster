-- Synthetic profession-title coverage; no provider NPC data bundled.
local addon={}
local rows,ids={},{}
local function add(title,profession,flags,side,name)
 local id=#ids+1
 rows[id]={title=title,profession=profession,flags=flags or 16,side=side or 'A',name=name or ('Tutor '..id)}
 ids[id]=id
 return id
end
local leather=add('Journeyman Leatherworker','Leatherworking')
local ranks={'','Apprentice ','Journeyman ','Expert ','Artisan ','Master ','Superior '}
local aliases={Leatherworker='Leatherworking',Leathercrafter='Leatherworking',
 Blacksmith='Blacksmithing',Tailor='Tailoring',Enchanter='Enchanting',
 Alchemist='Alchemy',Engineer='Engineering',Herbalist='Herbalism',
 Fisherman='Fishing',Miner='Mining',Skinner='Skinning',Cook='Cooking',Physician='First Aid'}
for alias,profession in pairs(aliases) do
 for _,rank in ipairs(ranks) do add(rank..alias,profession) end
end
add('Master Dragonscale Leatherworker','Leatherworking')
add('Master Elemental Leatherworker','Leatherworking')
add('Master Tribal Leatherworker','Leatherworking')
add('Master Goblin Engineer','Engineering')
add('Master Gnome Engineer','Engineering')
add('Master Shadoweave Tailor','Tailoring')
local merchant=add('Leatherworker',nil,4)
local supply=add('Leatherworker Supplies',nil,20)
local unrelated=add('NotALeatherworker',nil,16)
local hostile=add('Expert Leatherworker','Leatherworking',16,'H')
add(nil,'Leatherworking',16,'A','Leatherworker')
LibQuestieDB={flavor={name='Forever'},Enum={npcFlags={VENDOR=4,TRAINER=16}},
 RequireContract=function(v) return v==4 end,
 Support={Get=function() return {private={areaIdToUiMapId='return {[38]=1432}'}} end},
 Npc={GetAllIds=function() return ids end,
 npcFlags=function(id) return rows[id].flags end,
 name=function(id) return rows[id].name end,
 subName=function(id) return rows[id].title end,
 friendlyToFaction=function(id) return rows[id].side end,
 spawns=function(id) return {[38]={{50,50}}} end}}
UnitFactionGroup=function() return 'Alliance' end
assert(loadfile('Data/NpcCatalog.lua'))('ErrandMaster',addon)
local c=addon.npcs
assert(c:Initialize());while not c:Step(200) do end
local function found(label)
 local result={}
 for _,r in ipairs(c:LocationsOnMap(1432,label)) do result[r.npcID]=r end
 return result
end
assert(found('Leatherworking Trainer')[leather],
 'Journeyman Leatherworker must be discoverable as Leatherworking Trainer')
for id,row in ipairs(rows) do
 if row.profession and row.side=='A' then
  assert(found(row.profession..' Trainer')[id],'missing trainer title '..tostring(row.title or row.name))
  assert(found('Profession Trainer')[id],'missing profession group')
 end
end
local matches=found('Leatherworking Trainer')
assert(not matches[merchant] and not matches[supply] and not matches[unrelated],
 'require trainer flag and exact occupation title, not merchant/substring guesses')
assert(not matches[hostile],'faction filtering remains intact')
local nearest=c:Nearest(1432,.5,.5,'Leatherworking Trainer',1000,1000,20)
assert(#nearest>0 and nearest[1].specialty=='Leatherworking Trainer')
assert(#c:Find('Leatherworking',1432,.5,.5,1000,1000)>0,
 'canonical profession text must find occupation-titled trainers')
print('ranked profession titles, nearest lookup, search and safety regression passed')
