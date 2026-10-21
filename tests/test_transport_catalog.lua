-- Synthetic native MapTaxiNodeInfo; no shipped taxi graph or coordinates.
local addon={}
local reads=0
local nodes={
  {nodeID=11,name='North Landing',position={GetXY=function() return .2,.3 end},faction=2,isUndiscovered=true},
  {nodeID=12,name='Other Landing',position={GetXY=function() return .7,.8 end},faction=1,isUndiscovered=false},
  {nodeID=13,name='Shared Landing',position={GetXY=function() return .4,.5 end},faction=0,isUndiscovered=false},
}
C_TaxiMap={GetTaxiNodesForMap=function(map) reads=reads+1; assert(map==1412); return nodes end}
UnitFactionGroup=function() return 'Alliance' end
local handlers={}
CreateFrame=function()
  return {RegisterEvent=function(_,event) handlers[event]=true end,
    SetScript=function(_,name,fn) handlers[name]=fn end}
end
assert(loadfile('Data/TransportCatalog.lua'))('ErrandMaster',addon)
local catalog=assert(addon.transportCatalog)
local places=catalog:LocationsOnMap(1412,'Flight Master')
assert(#places==3 and places[1].id=='taxi-1412-11' and places[1].x==.2 and places[1].y==.3)
assert(places[1].category=='Flight Master' and places[1].source=='native-taxi-map' and
  places[1].precision=='map-node' and places[1].isUndiscovered==true and
  places[1].plannerEligible==false, 'map-wide positions are not planner eligibility')
assert(places[2].faction=='Horde' and places[2].plannerEligible==false and
  places[2].isUndiscovered==false)
assert(#catalog:EligibleOnMap(1412,'Flight Master')==0,
  'native nodes alone, even apparently discovered, cannot establish NPC eligibility')
local services=catalog:ServiceCandidatesOnMap(1412)
assert(#services==2 and services[1].nodeID==11 and services[2].nodeID==13,
  'friendly and neutral positions are visitable service candidates, not flight connections')
assert(services[1].rideEligibility=='unknown' and services[1].friendlyToFaction=='A')
assert(loadfile('Routing/RoutePlanner.lua'))('ErrandMaster',addon)
assert(loadfile('Data/ZoneSearch.lua'))('ErrandMaster',addon)
addon.navigation={WorldPosition=function(_,map,x,y) return 0,x*1000,y*1000 end}
local context=addon.zoneSearch:RouteContext({})
local chosen=context.candidates({mapID=1412,x=.2,y=.3},{category='Flight Master'})
assert(#chosen==1 and chosen[1].nodeID==11 and chosen[1].rideEligibility=='unknown',
  'native service positions must be integrated without claiming a flight connection')
assert(#context.candidates({mapID=1412,x=.2,y=.3},{category='Flight Master',npcID=999})==0,
  'native map nodes must not substitute for an explicitly requested NPC')
places[1].x=0
assert(catalog:LocationsOnMap(1412,'Flight Master')[1].x==.2 and reads==1,
  'bounded materialization and detached results')
assert(#catalog:LocationsOnMap(1412,'Bank')==0 and #catalog:LocationsOnMap(0,'Flight Master')==0 and reads==1)
assert(catalog:Status().limited and catalog:Status().rawPositions==3 and
  catalog:Status().eligibleCandidates==0)
addon.npcs={IsReady=function() return true end,LocationsOnMap=function(_,map,wanted)
  assert(map==1412 and wanted=='Flight Master')
  return {{id='npc-10',name='Flight Master Ada',category='Flight Master',
    friendlyToFaction='A',x=.21,y=.31,mapID=1412,source='questiedb-forever'},
    {id='npc-11',category='Flight Master',friendlyToFaction='H',x=.7,y=.8,mapID=1412},
    {id='npc-12',category='Flight Master',friendlyToFaction='AH',x=.4,y=.5,mapID=1412}}
end}
local candidates=catalog:NpcCandidatesOnMap(1412,'Flight Master')
assert(#candidates==2 and candidates[1].id=='npc-10' and candidates[2].id=='npc-12' and
  candidates[1].plannerEligible==false and #catalog:EligibleOnMap(1412,'Flight Master')==0,
  'NPC candidate corroboration is separate from confirmed taxi eligibility')
candidates[1].x=0
assert(catalog:NpcCandidatesOnMap(1412,'Flight Master')[1].x==.21)
UnitFactionGroup=function() return nil end
assert(#catalog:NpcCandidatesOnMap(1412,'Flight Master')==0,'unknown player faction fails closed')
UnitFactionGroup=function() return 'Alliance' end
addon.npcs.IsReady=function() return false end
assert(#catalog:NpcCandidatesOnMap(1412,'Flight Master')==0,'partial NPC index fails closed')
addon.npcs.IsReady=function() return true end
assert(not handlers.OnEvent,'catalog must reuse the core event dispatcher')
nodes[1].position.GetXY=function() return .3,.3 end
catalog:OnEvent('TAXI_NODE_STATUS_CHANGED')
assert(catalog:LocationsOnMap(1412,'Flight Master')[1].x==.3 and reads==2,
  'native status changes invalidate cached coordinates')
nodes[1].position.GetXY=function() return .2,.3 end
for _,event in ipairs({'TAXIMAP_OPENED','TAXIMAP_CLOSED','PLAYER_ENTERING_WORLD'}) do
  catalog:OnEvent(event)
  catalog:LocationsOnMap(1412,'Flight Master')
end
assert(reads==5)
nodes[4]={nodeID=11,name='Duplicate',position={GetXY=function() return .1,.1 end},faction=2}
nodes[5]={nodeID=14,name='Bad',position={GetXY=function() return 0/0,.2 end},faction=2}
nodes[6]={nodeID=15,name='Throw',position={GetXY=function() error('secret') end},faction=2}
nodes[7]={nodeID=16,name='Missing',position=nil,faction=2}
catalog:Invalidate()
assert(#catalog:LocationsOnMap(1412,'Flight Master')==3 and catalog:Status().issues['node-invalid'])
C_TaxiMap.GetTaxiNodesForMap=function() error('unavailable') end
catalog:Invalidate()
assert(#catalog:LocationsOnMap(1412,'Flight Master')==0 and catalog:Status().issues['map-read'])
local tooMany={}
for i=1,600 do tooMany[i]={nodeID=i,name='Node '..i,
  position={GetXY=function() return .5,.5 end},faction=2,isUndiscovered=false} end
C_TaxiMap.GetTaxiNodesForMap=function() return tooMany end
assert(#catalog:LocationsOnMap(1412,'Flight Master')==512 and catalog:Status().issues['node-cap'])
assert(catalog:Status().cachedMaps==1 and catalog:Status().rawPositions==512)
C_TaxiMap.GetTaxiNodesForMap=nil
catalog:Invalidate()
assert(catalog:Status().state=='unavailable' and #catalog:LocationsOnMap(1412,'Flight Master')==0)
print('transport native positions, guarded reads, caching, events and eligibility separation passed')
