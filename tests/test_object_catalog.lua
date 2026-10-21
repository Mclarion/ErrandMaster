-- Contract mocks only; no QuestieDB rows or coordinates are bundled.
local addon={}
local rows={
  [11]={raw='Mailbox',name='Boîte aux lettres',spawns={[215]={{36,55},{70,42,2}},[12]={{20,30}}}},
  [12]={raw='Doodad_PostBoxGnome01',name='Doodad_PostBoxGnome01',spawns={[215]={{1,2}}}},
  [13]={raw='Postbox Parcel',name='Postbox Parcel',spawns={[215]={{3,4}}}},
  [14]={raw='Mailbox',name='Mailbox',spawns=nil},
  [15]={raw='Mailbox',name='Mailbox',spawns={[215]={{-1,20},{101,40}}}},
}
local reads=0
LibQuestieDB={flavor={name='Forever'},RequireContract=function(v) return v==4 end,
  Support={Get=function(key) assert(key=='ZoneDB');return {private={areaIdToUiMapId='return {[215]=1412,[12]=1429}'}} end},
  Object={GetAllIds=function() return {11,12,13,14,15} end,
    GetRaw=function(id,key) assert(key=='name'); return rows[id].raw end,
    name=function(id) return rows[id].name end,
    spawns=function(id) reads=reads+1; return rows[id].spawns end}}
assert(loadfile('Data/ObjectCatalog.lua'))('ErrandMaster',addon)
local objects=addon.objects
assert(objects:Initialize() and not objects:IsReady())
assert(not objects:Step(1) and not objects:IsReady())
while not objects:Step(2) do end
assert(objects:Status().total==5 and objects:Status().processed==5 and reads==3)
local places=objects:LocationsOnMap(1412,'Mailbox')
assert(#places==2 and places[1].objectID==11 and places[1].x==.36 and
  places[1].y==.55 and places[2].phaseUnverified,
  'raw name identifies translated mailboxes, coordinates map by AreaID')
assert(#objects:LocationsOnMap(1429,'Mailbox')==1)
local cachedReads=reads
objects:LocationsOnMap(1412,'Mailbox')
assert(reads==cachedReads,'repeated planning must reuse materialized object spawns')
assert(#objects:LocationsOnMap(1412,'Bank')==0 and #objects:LocationsOnMap(215)==0)
assert(objects:Status().limited and objects:Status().reason and
  objects:Status().issues['invalid-coordinate'], 'incomplete index must report limitations')
assert(places[1].category=='Mailbox' and places[1].source=='questiedb-forever' and
  places[1].precision=='candidate-spawn' and places[1].id=='object-11-215-1')
local original=rows[11].spawns[215][1][1]
places[1].x=0
assert(rows[11].spawns[215][1][1]==original, 'never mutate provider rows')
rows[16]={raw='Mailbox',name='Mailbox',spawns={[215]={{10,10}}}}
LibQuestieDB.Object.GetAllIds=function() return {16} end
assert(objects:Initialize())
while not objects:Step(2) do end
assert(#objects:LocationsOnMap(1412,'Mailbox')==1 and objects:Status().processed==1,
  'reinitialize discards old index')
LibQuestieDB.Object.GetRaw=nil
assert(not objects:Initialize() and objects:Status().reason and
  #objects:LocationsOnMap(1412,'Mailbox')==0, 'without raw identity do not guess by localized name')
LibQuestieDB.Object.GetRaw=function(id) return rows[id].raw end
local many={}
for i=1,1000 do many[i*2]=1000+i; rows[1000+i]={raw='Chest',name='Chest'} end
LibQuestieDB.Object.GetAllIds=function() return many end
assert(objects:Initialize() and objects:Status().normalizedEntries==0)
assert(not objects:Step(7) and objects:Status().normalizedEntries==7 and
  objects:Status().processed==0 and not objects:IsReady(),
  'ID normalization is incremental even for sparse provider arrays')
while objects:Status().normalizing do objects:Step(200) end
assert(objects:Status().total==1000)
while not objects:Step(200) do end
assert(objects:Status().processed==1000)
LibQuestieDB.Object.GetAllIds=function() return {11} end
LibQuestieDB.Object.spawns=function() error('provider failed') end
assert(objects:Initialize())
while not objects:Step(2) do end
assert(objects:Status().issues['object-spawns-read'] and objects:Status().limited and
  #objects:LocationsOnMap(1412,'Mailbox')==0)
LibQuestieDB.flavor.name='Vanilla'
assert(not objects:Initialize() and not objects:IsReady())
LibQuestieDB=nil
assert(not objects:Initialize() and not objects:IsReady())
print('Object mailbox raw identity, bounded indexing, map projection and partial coverage passed')
