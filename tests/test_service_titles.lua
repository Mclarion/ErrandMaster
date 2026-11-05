-- Synthetic coverage of all confirmed service-title gaps, not provider records.
local addon={}
local rows={
 {title='Pet Trainer',flags=16}, {title='Weapon Master',flags=16},
 {title='Weapon Trainer',flags=16}, {title='Journeyman Alchemist Trainer',flags=16},
 {title='Leatherworking & Tailoring Supplies',flags=4},
 {title='Engineering and Mining Supplies',flags=4},
 {title='Herbalism & Alchemy Supplies',flags=4},
 {title='Reagents & Magical Goods',flags=4},
 {title='Pet Trainer',flags=4}, {title='Weapon Master',flags=4},
 {title='Weapon Crafter',flags=16}, {title='NotReagents',flags=4},
 {title='Alchemy & Food & Reagents',flags=4},
 {title='Leatherworking & Tailoring Supplies',flags=0},
}
local ids={};for i=1,#rows do ids[i]=i end
LibQuestieDB={flavor={name='Forever'},Enum={npcFlags={VENDOR=4,TRAINER=16}},
 RequireContract=function(v) return v==4 end,
 Support={Get=function() return {private={areaIdToUiMapId='return {[38]=1432}'}} end},
 Npc={GetAllIds=function() return ids end,
 npcFlags=function(id) return rows[id].flags end,
 name=function(id) return 'Synthetic '..id end,
 subName=function(id) return rows[id].title end,
 friendlyToFaction=function() return 'AH' end,
 spawns=function() return {[38]={{50,50}}} end},
 Item={GetAllIds=function() return {1,2} end,
 class=function(id) return id==1 and 5 or 0 end,
 subClass=function() return 5 end,
 vendors=function() return {13} end}}
UnitFactionGroup=function() return 'Alliance' end
assert(loadfile('Data/NpcCatalog.lua'))('ErrandMaster',addon)
assert(loadfile('Routing/RoutePlanner.lua'))('ErrandMaster',addon)
local c=addon.npcs
assert(c:Initialize());while not c:Step(200) do end
local function find(id,label)
 for _,r in ipairs(c:LocationsOnMap(1432,label)) do if r.npcID==id then return r end end
end
local cases={{1,'Pet Trainer'},{2,'Weapon Trainer'},{3,'Weapon Trainer'},
 {4,'Alchemy Trainer'},{5,'Leatherworking Vendor'},{5,'Tailoring Vendor'},
 {6,'Engineering Vendor'},{6,'Mining Vendor'},{7,'Herbalism Vendor'},
 {7,'Alchemy Vendor'},{8,'Reagent Vendor'}}
for _,case in ipairs(cases) do
 local r=find(case[1],case[2]);assert(r,'missing '..case[2]..' for '..rows[case[1]].title)
 assert(addon.route:Matches({category=case[2]},r),'route must accept specialty')
end
assert(not find(1,'Profession Trainer') and not find(2,'Class Trainer'))
assert(not find(9,'Pet Trainer') and not find(10,'Weapon Trainer'))
assert(not find(11,'Weapon Trainer') and not find(12,'Reagent Vendor'))
assert(not find(14,'Tailoring Vendor'))
assert(find(5,'Profession Vendor') and find(5,'Vendor'))
local seen={};local count=0
for _,r in ipairs(c:LocationsOnMap(1432,'Vendor')) do
 if r.npcID==13 then
  assert(not seen[r.specialty],'overlapping inventory/title evidence must deduplicate')
  seen[r.specialty]=true;count=count+1
  assert((r.vendorGroup=='Profession Vendor')==(r.specialty=='Alchemy Vendor'),
   'do not leak profession grouping onto food/reagent records')
 end
end
assert(count==3 and seen['Food Vendor'] and seen['Reagent Vendor'] and seen['Alchemy Vendor'])
assert(find(13,'Reagent Vendor').functionEvidence=='QuestieDB Item vendors/class')
print('pet/weapon trainers, ranked suffixes, multi-vendor specialties and route regression passed')
