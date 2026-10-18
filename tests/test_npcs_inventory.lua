-- Synthetic Item contract: no provider records copied or bundled.
local addon={}
local rows={
 [1]={name='Mixed merchant',subName='General Supplies',flags=4,side='A'},
 [2]={name='Hostile merchant',flags=4,side='H'},
 [3]={name='No service',flags=0,side='A'},
 [4]={name='Alchemist',subName='Trainer',flags=16,side='A'},
 [5]={name='Herbalist',flags=16,side='A'},
 [6]={name='Fisherman',flags=16,side='A'},
 [7]={name='Engineer',flags=16,side='A'},
 [8]={name='Alchemist',flags=4,side='A'},
 [9]={name='Tutor Nine',subName='Journeyman Alchemist',flags=16,side='A'},
}
local ids={1,2,3,4,5,6,7,8,9}
local items={
 [100]={class=6,subClass=2,vendors={1,2,3}},
 [101]={class=6,subClass=3,vendors={1}},
 [102]={class=5,vendors={1}},
 [103]={class=0,subClass=5,vendors={1}},
 [104]={class=6,subClass=2,vendors={4}},
 [105]={class=4,subClass=2,vendors={1}},
}
local itemids={100,101,102,103,104,105}
LibQuestieDB={flavor={name='Forever'},Enum={npcFlags={VENDOR=4,TRAINER=16}},
 RequireContract=function(v) assert(v==4); return true end,
 Support={Get=function() return {private={areaIdToUiMapId='return {[38]=1432}'}} end},
 Npc={GetAllIds=function() return ids end,
 npcFlags=function(id) return rows[id].flags end,
 name=function(id) return rows[id].name end,
 subName=function(id) return rows[id].subName end,
 friendlyToFaction=function(id) return rows[id].side end,
 spawns=function(id) return {[38]={{50,50}}} end},
 Item={GetAllIds=function() return itemids end,
 class=function(id) return items[id].class end,
 subClass=function(id) return items[id].subClass end,
 vendors=function(id) return items[id].vendors end}}
UnitFactionGroup=function() return 'Alliance' end
assert(loadfile('Data/NpcCatalog.lua'))('ErrandMaster',addon)
local npcs=addon.npcs
assert(npcs:Initialize())
assert(not npcs:Step(2) and not npcs:IsReady(), 'item pass must not appear ready early')
assert(npcs:Status().processed==0, 'item work must not count as NPC IDs')
assert(npcs:Status().itemsProcessed==2, 'item pass is bounded by Step batch')
while not npcs:Step(2) do end
assert(npcs:IsReady() and npcs:Status().itemsProcessed==6)
local function matches(label)
 local found={}
 for _,r in ipairs(npcs:LocationsOnMap(1432,label)) do found[r.npcID]=true end
 return found
end
for _,label in ipairs({'Ammo Vendor','Reagent Vendor','Food Vendor','Vendor'}) do
 assert(matches(label)[1],label..' must retain independently classified merchant')
end
assert(not matches('Ammo Vendor')[2] and not matches('Ammo Vendor')[3] and
 not matches('Ammo Vendor')[4], 'faction, vendor flag and unrelated trainer filter')
assert(#npcs:LocationsOnMap(1432,'Projectile Vendor')==0 and
 #npcs:LocationsOnMap(1432,'Potion Vendor')==0, 'subtype exact matching')
for id,label in pairs({[4]='Alchemy Trainer',[5]='Herbalism Trainer',
 [6]='Fishing Trainer',[7]='Engineering Trainer',[9]='Alchemy Trainer'}) do
 assert(matches(label)[id] and matches('Profession Trainer')[id],label..' alias')
end
assert(not matches('Alchemy Trainer')[8], 'trainer aliases require trainer flag')
local ammo=npcs:LocationsOnMap(1432,'Ammo Vendor')[1]
assert(ammo.functionEvidence=='QuestieDB Item vendors/class', 'inventory evidence is distinct from subtitle')
local originalVendors=LibQuestieDB.Item.vendors
LibQuestieDB.Item.vendors=function(id)
 if id==100 then error('synthetic provider read failure') end
 return originalVendors(id)
end
assert(npcs:Initialize())
while not npcs:Step(2) do end
assert(npcs:Status().limited and npcs:Status().reason:find('Item reads failed'),
 'partial Item failures must not be reported as complete inventory coverage')
LibQuestieDB.Item.vendors=originalVendors
-- An older NPC-only contract remains usable, with explicitly limited subtype coverage.
LibQuestieDB.Item=nil
assert(npcs:Initialize())
while not npcs:Step(2) do end
assert(npcs:IsReady() and npcs:Status().limited and npcs:Status().reason:find('Item'),
 'NPC-only provider must declare missing inventory coverage')
assert(#npcs:LocationsOnMap(1432,'Ammo Vendor')==0)
print('synthetic Item inventory indexing and trainer alias contracts passed')
