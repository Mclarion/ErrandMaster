local addon={}
local ids,points={},{}
for i=1,1000 do ids[i]=i; points[i]={35,48} end
local names,levels=0,0
LibQuestieDB={flavor={name='Forever'},Enum={npcFlags={VENDOR=4}},
 RequireContract=function() return true end,
 Support={Get=function() return {private={areaIdToUiMapId='return {[38]=1432}'}} end},
 Npc={GetAllIds=function() return ids end,npcFlags=function() return 4 end,
  spawns=function() return {[38]=points} end,
  name=function() names=names+1; return 'Synthetic' end,
  minLevel=function() levels=levels+1; return 10 end,
  friendlyToFaction=function() return 'AH' end}}
assert(loadfile('Data/NpcCatalog.lua'))('ErrandMaster',addon)
local c=addon.npcs
assert(c:Initialize()); while not c:Step(200) do end
local report=c:Diagnostics(1432,'Vendor')
assert(report.candidates==10000 and report.mapIssues['record-cap'])
assert(names==10,'map materialization must stop reading NPCs once its record capacity is exhausted')
assert(levels==10,'NPC level metadata must be read once per admitted NPC, not once per spawn')
assert(c:Diagnostics(1432,'Vendor').candidates==10000 and names==10 and levels==10,
 'cached reads must not revisit the provider')
assert(not c:Diagnostics(999,'Vendor').mapLimited,'capacity exhaustion must not leak to other maps')
print('map materialization capacity and per-NPC metadata budgets passed')
LibQuestieDB.Npc.GetAllIds=function() local exact={} for i=1,10 do exact[i]=i end return exact end
assert(c:Initialize()); while not c:Step(200) do end
local exact=c:Diagnostics(1432,'Vendor')
assert(exact.candidates==10000 and not exact.mapIssues['record-cap'] and not exact.mapLimited,
 'exactly filling capacity without unread records must not claim truncation')
print('exact map capacity does not falsely report discarded records')
