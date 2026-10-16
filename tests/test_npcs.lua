-- QuestieDB is the required runtime source; these are contract mocks, not copied NPC data.
local addon={}
local originalSpawns={
  [101]={[215]={{36.43,55.89}}},
  [102]={[215]={{70,42,2},{-1,-1}},[12]={{20,30}}},
  [103]={[215]={{12,20}}},
  [104]={[215]={{13,21}}},
}
local rows={
  [101]={name='Banker One',subName='Banker',npcFlags=256,friendlyToFaction='AH',minLevel=20},
  [102]={name='Repair Two',subName='Vendor',npcFlags=16384+4,friendlyToFaction='A',minLevel=30},
  [103]={name='Hostile Three',npcFlags=256,friendlyToFaction='H'},
  [104]={name='Ordinary Four',npcFlags=0,friendlyToFaction='AH'},
}
LibQuestieDB={flavor={name='Forever'},Enum={npcFlags={BANKER=256,REPAIR=16384,VENDOR=4,
  TRAINER=16,AUCTIONEER=4096,FLIGHT_MASTER=8,INNKEEPER=128}},
  RequireContract=function(version) assert(version==4); return true end,
  Support={Get=function(name) assert(name=='ZoneDB'); return {private={
    areaIdToUiMapId='return {[215]=1412,[12]=1429}'}} end},
  Npc={GetAllIds=function() return {101,102,103,104} end,
    spawns=function(id) return originalSpawns[id] end,
    name=function(id) return rows[id].name end,
    subName=function(id) return rows[id].subName end,
    npcFlags=function(id) return rows[id].npcFlags end,
    friendlyToFaction=function(id) return rows[id].friendlyToFaction end,
    minLevel=function(id) return rows[id].minLevel end}}
UnitFactionGroup=function() return 'Alliance' end
assert(loadfile('Data/NpcCatalog.lua'))('ErrandMaster',addon)
local npcs=addon.npcs
assert(npcs:Initialize() and not npcs:IsReady())
assert(not npcs:Step(2) and npcs:Status().processed==2)
assert(npcs:Step(2) and npcs:IsReady() and npcs:Status().total==4)
local bank=npcs:LocationsOnMap(1412,'Bank')
assert(#bank==1 and bank[1].npcID==101 and bank[1].x==.3643 and bank[1].y==.5589 and
  bank[1].source=='questiedb-forever' and bank[1].precision=='candidate-spawn',
  'service NPC locations are preloaded from the provider, not player observations')
assert(#npcs:LocationsOnMap(1412,'Vendor')==1 and
  #npcs:LocationsOnMap(1429,'Repair')==1,
  'provider AreaIDs map to Forever UiMapIDs without treating numbers as interchangeable')
local repair=npcs:LocationsOnMap(1412,'Repair')
assert(#repair==1 and repair[1].phaseUnverified and repair[1].npcID==102,
  'phase-tagged spawns are only candidates, never guaranteed available')
assert(#npcs:Find('bank',1412)==1 and npcs:Find('bank',1412)[1].id==101)
assert(originalSpawns[102][215][2][1]==-1,
  'consumer never alters shared or copied QuestieDB tables')
rows[110]={name='Banker Near',subName='Banker',npcFlags=256,friendlyToFaction='AH'}
originalSpawns[101][215][2]={11,20}
originalSpawns[110]={[215]={{10,20}}}
LibQuestieDB.Npc.GetAllIds=function() return {101,102,103,104,110} end
assert(npcs:Initialize() and npcs:Step(20))
local matching=npcs:Find('bank',1412,.101,.20,1000,1000)
assert(#matching==2 and matching[1].id==110 and matching[2].id==101 and
  matching[2].x==.11 and matching[2].y==.20,
  'search ranks the closest spawn for each NPC, not alphabetic first or first spawn')
rows[105]={name='Arcanist',subName='Mage Trainer',npcFlags=16,friendlyToFaction='AH'}
rows[106]={name='Alchemist',subName='Alchemy Trainer',npcFlags=16,friendlyToFaction='AH'}
rows[107]={name='Unknown Tutor',subName='Trainer',npcFlags=16,friendlyToFaction='AH'}
originalSpawns[105]={[215]={{10,20}}}
originalSpawns[106]={[215]={{15,20}}}
originalSpawns[107]={[215]={{18,20}}}
LibQuestieDB.Npc.GetAllIds=function() return {101,102,103,104,105,106,107} end
assert(npcs:Initialize())
while not npcs:Step(2) do end
assert(#npcs:LocationsOnMap(1412,'Mage Trainer')==1 and
  #npcs:LocationsOnMap(1412,'Alchemy Trainer')==1 and
  #npcs:LocationsOnMap(1412,'Profession Trainer')==1 and
  #npcs:Find('alchemy',1412)==1,
  'specialized trainers require positive QuestieDB subtitle evidence')
local nearest=npcs:Nearest(1412,.11,.20,'Mage Trainer',1000,1000,2)
assert(#nearest==1 and nearest[1].npcID==105 and nearest[1].directYards>0,
  'nearest NPC is a labeled direct estimate, not a walkable route')
addon.discovery={PlayerClass=function() return 'Mage' end}
assert(loadfile('Routing/RoutePlanner.lua'))('ErrandMaster',addon)
local plan=addon.route:Plan({{id='class',category='Class Trainer',name='Class trainer'}},
  1412,.11,.20,true,npcs:LocationsOnMap(1412),nil,1000,1000)
assert(plan[1] and plan[1].npcID==105 and plan[1].locationSource=='questiedb-forever',
  'class wheel errand must route to matching trainer, not every trainer')
local profession=addon.route:Plan({{id='trade',category='Profession Trainer',name='Trade trainer'}},
  1412,.11,.20,true,npcs:LocationsOnMap(1412),nil,1000,1000)
assert(profession[1] and profession[1].npcID==106,
  'trade trainer excludes unclassified class and generic trainers')
rows[108]={name='Trade Merchant',subName='Alchemy Supplies',npcFlags=4,
  friendlyToFaction='AH'}
rows[109]={name='Ingredient Merchant',subName='Reagent Vendor',npcFlags=4,
  friendlyToFaction='AH'}
originalSpawns[108]={[215]={{16,20}}}
originalSpawns[109]={[215]={{17,20}}}
LibQuestieDB.Npc.GetAllIds=function() return {101,102,103,104,105,106,107,108,109} end
assert(npcs:Initialize())
while not npcs:Step(3) do end
assert(#npcs:LocationsOnMap(1412,'Profession Vendor')==1 and
  #npcs:LocationsOnMap(1412,'Reagent Vendor')==1,
  'vendor subtypes need explicit provider subtitle evidence')
local trade=addon.route:Plan({{id='vendor',category='Profession Vendor',name='Trade supplies'}},
  1412,.11,.20,true,npcs:LocationsOnMap(1412),nil,1000,1000)
assert(trade[1] and trade[1].npcID==108,
  'profession vendor wheel option finds a labeled vendor candidate')
local normalSpawns=LibQuestieDB.Npc.spawns
LibQuestieDB.Npc.spawns=function(id)
  if id==105 then error('provider read refused') end
  return normalSpawns(id)
end
assert(npcs:Initialize() and npcs:Step(20))
assert(npcs:Status().limited and npcs:Status().reason and npcs:IsReady(),
  'partial provider indexing must be visibly incomplete, never silently complete')
LibQuestieDB.Npc.spawns=normalSpawns
LibQuestieDB.flavor.name='Vanilla'
assert(not npcs:Initialize() and not npcs:IsReady(),
  'wrong flavor fails visibly rather than serving Era coordinates on Forever')
LibQuestieDB.flavor.name='Forever'
LibQuestieDB.RequireContract=function() return false,'old contract' end
assert(not npcs:Initialize() and npcs:Status().reason=='old contract')
LibQuestieDB=nil
assert(not npcs:Initialize() and not npcs:IsReady())
print('QuestieDB contract, area mapping, service and faction tests passed')
