local addon={}
LibQuestieDB={flavor={name='Forever'},Enum={npcFlags={VENDOR=4}},
 RequireContract=function() return true end,
 Support={Get=function() return {private={areaIdToUiMapId='return {[38]=1432}'}} end},
 Item={GetAllIds=function() return {1,2,3} end,
 class=function(id) if id==2 then return 6 elseif id==3 then return 'bad' end end,
 subClass=function() return 0 end,
 vendors=function() return {10,'invalid'} end},
 Npc={GetAllIds=function() return {10,11,12,13} end,
 npcFlags=function(id) if id~=11 then return 4 end end,
 name=function() return 'Synthetic merchant' end,
 friendlyToFaction=function() return 'A' end,
 spawns=function(id) if id==12 then return nil elseif id==13 then return {[999]={{50,50}}} end return {[38]={{35,48}}} end}}
UnitFactionGroup=function() return 'Alliance' end
assert(loadfile('Data/NpcCatalog.lua'))('ErrandMaster',addon)
local c=addon.npcs
assert(c:Initialize())
while not c:Step(2) do end
local status=c:Status()
assert(c.mapServices and c.mapServices[1432] and c.mapServices[1432].Vendor,
 'indexing must expose service flags per map for bounded global lookup')
assert(status.limited,'malformed field returns must declare incomplete coverage')
for _,code in ipairs({'item-class','item-vendor-id','npc-flags','npc-spawns','unmapped-area'}) do
 assert(status.issues[code] and status.issues[code]>0,code..' must remain independently visible')
end
assert(#c:LocationsOnMap(1432,'Ammo Vendor')==1,'good evidence must survive bad sibling records')
status.issues['item-class']=999
assert(c:Status().issues['item-class']~=999,'diagnostic snapshots must not mutate catalog')
print('provider diagnostic counters retain valid candidates and multiple failure reasons')
local food=c:Diagnostics(1432,'Food Vendor')
assert(food.candidates==0 and food.inventoryEvidence=='not-evidenced',
 'missing food evidence is unknown coverage, not proof of no food seller')
local ammo=c:Diagnostics(1432,'Ammo Vendor')
assert(ammo.candidates==1 and ammo.inventoryEvidence=='candidate-evidence')
UnitFactionGroup=function() return 'Horde' end
local hostile=c:Diagnostics(1432,'Ammo Vendor')
assert(hostile.candidates==0 and hostile.factionExcluded==1)
assert(hostile.inventoryEvidence=='not-evidenced','only eligible inventory evidence counts')
print('map/service diagnostics distinguish evidence and faction exclusions')
UnitFactionGroup=function() return 'Alliance' end
LibQuestieDB.Item.GetAllIds=function() return {} end
LibQuestieDB.Npc.GetAllIds=function() return {10,12} end
LibQuestieDB.Npc.spawns=function(id)
 if id==12 then return {} end
 return {[38]={{35,48},{101,20},{0/0,20},false}}
end
assert(c:Initialize())
while not c:Step(2) do end
assert(c:Status().issues['empty-spawns']==1,'empty whole spawn tables must be reported')
local damaged=c:Diagnostics(1432,'Vendor')
assert(damaged.candidates==1,'invalid coordinates must not discard valid siblings')
assert(damaged.mapLimited and damaged.mapIssues['invalid-coordinate']==3,
 'discarded coordinates require map-specific reasons')
damaged.mapIssues['invalid-coordinate']=999
assert(c:Diagnostics(1432,'Vendor').mapIssues['invalid-coordinate']==3,
 'cached reads must not recount issues or expose mutable counters')
assert(not c:Diagnostics(999,'Vendor').mapLimited,'map issues must not leak to unrelated maps')
print('empty spawn and map-coordinate diagnostics passed')
local sparseNPCs={[2]=10,[8]=12,[9]=10,[11]='bad'}
LibQuestieDB.Npc.GetAllIds=function() return sparseNPCs end
LibQuestieDB.Item.GetAllIds=function() return {[4]=20} end
LibQuestieDB.Item.class=function() return 6 end
LibQuestieDB.Item.vendors=function() return {[3]=10,[8]=12} end
LibQuestieDB.Npc.spawns=function() return {[38]={[3]={35,48},[9]={40,50}}} end
assert(c:Initialize())
while not c:Step(1) do end
local sparse=c:Diagnostics(1432,'Ammo Vendor')
assert(sparse.candidates==4,'sparse ID, vendor and spawn lists must retain valid entries after holes')
assert(c:Status().total==2,'duplicate and invalid IDs must not inflate processing totals')
assert(sparse.issues['npc-ids-sparse'] and sparse.issues['item-ids-sparse'] and
 sparse.mapIssues['spawn-list-sparse'],'sparse provider lists must remain explicitly limited')
assert(sparseNPCs[2]==10 and sparseNPCs[9]==10 and sparseNPCs[11]=='bad',
 'provider-owned lists must not be modified')
print('sparse provider lists preserve valid evidence without duplicate candidates')
LibQuestieDB.Item.GetAllIds=function() return {1,2} end
LibQuestieDB.Item.class=function(id) if id==1 then error('synthetic item failure') end return 6 end
LibQuestieDB.Item.vendors=function() return 'invalid vendor list' end
LibQuestieDB.Npc.GetAllIds=function() return {10,12} end
LibQuestieDB.Npc.name=function(id) if id==12 then return nil end return 'Valid merchant' end
LibQuestieDB.Npc.spawns=function() return {[38]={{35,48}}} end
assert(c:Initialize())
while not c:Step(2) do end
local failures=c:Diagnostics(1432,'Vendor')
assert(failures.issues['item-read']==1 and failures.issues['item-vendors-read']==1,
 'independent exceptions and malformed lists require separate counters')
assert(failures.candidates==1 and failures.mapIssues['npc-record']==1,
 'late malformed NPC records must mark only their map incomplete')
LibQuestieDB.Item.GetAllIds=function() return {} end
LibQuestieDB.Npc.GetAllIds=function() return {10} end
LibQuestieDB.Enum.npcFlags.TRAINER=16
LibQuestieDB.Npc.npcFlags=function() return 20 end
local many={}; for i=1,6000 do many[i]={35,48} end
LibQuestieDB.Npc.spawns=function() return {[38]=many} end
assert(c:Initialize()); while not c:Step(200) do end
local capped=c:Diagnostics(1432)
assert(capped.candidates==10000 and capped.mapIssues['record-cap'],
 'record truncation must be explicitly attributed to the affected map')
print('exception, late-record and capacity diagnostics passed')
local touched=false
local hostileList=setmetatable({10},{__index=function() touched=true; error('metatable touched') end})
assert(#c:ReadIds(hostileList,2,'guarded-ids')==0 and not touched,
 'provider list metatables must be rejected without execution')
assert(c:Status().issues['guarded-ids-read']==1)
local bounded=c:ReadIds({10,12,14},2,'bounded-ids')
assert(#bounded==2 and c:Status().issues['bounded-ids-cap']==1,
 'raw entry iteration must honor its explicit capacity')
local malformed=c:ReadIds({[1]=10,[2]=-1,[3]=10,extra=12},10,'malformed-ids')
assert(#malformed==1 and malformed[1]==10 and c:Status().issues['malformed-ids-key'] and
 c:Status().issues['malformed-ids-value'] and c:Status().issues['malformed-ids-duplicate'])
print('provider list safety boundaries passed')
