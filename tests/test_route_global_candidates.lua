local addon={}
assert(loadfile('Routing/RoutePlanner.lua'))('ErrandMaster',addon)
assert(loadfile('Data/ZoneSearch.lua'))('ErrandMaster',addon)
local records={
 [10]={{id='local',category='Ammo Vendor',mapID=10,x=.995,y=.5,npcID=1}},
 [20]={{id='border',category='Ammo Vendor',mapID=20,x=.01,y=.5,npcID=2}},
 [30]={{id='remote-auction',category='Auction House',mapID=30,x=.1,y=.5,npcID=3}}}
local offsets={[10]=0,[20]=1000,[30]=50000}
addon.navigation={WorldPosition=function(_,map,x,y) if offsets[map] then return 0,offsets[map]+x*1000,y*1000 end end}
addon.MapWorldSize=function() return 1000,1000 end
addon.npcs={byMap={[10]={[1]=true},[20]={[2]=true},[30]={[3]=true}},IsReady=function() return true end,
 LocationsOnMap=function(_,map) return records[map] or {} end}
assert(type(addon.zoneSearch.RouteContext)=='function','route discovery needs global comparable-map context')
local context=addon.zoneSearch:RouteContext({})
local from={mapID=10,x=1,y=.5}
local ammo=context.candidates(from,{category='Ammo Vendor'})
assert(#ammo==1 and ammo[1].id=='local','closest matching candidate must win by distance, not map preference')
records[10][1].x=.5
context=addon.zoneSearch:RouteContext({})
ammo=context.candidates(from,{category='Ammo Vendor'})
assert(ammo[1].id=='border','a closer candidate just across a zone border must beat the local-map candidate')
local auction=context.candidates(from,{category='Auction House'})
assert(auction[1].id=='remote-auction','no fixed radius or sibling-map-only limit may hide the closest known service')
assert(context.distance(from,auction[1])>10000)
local pinned=context.candidates(from,{category='Ammo Vendor',npcID=1})
assert(pinned[1].npcID==1,'global lookup must preserve explicit NPC identity')
print('global route candidates cross borders, exceed old radius and preserve identity')
local originalWorld=addon.navigation.WorldPosition
addon.navigation.WorldPosition=function(self,map,x,y)
 local instance,wx,wy=originalWorld(self,map,x,y)
 if map==30 then instance=1 end
 return instance,wx,wy
end
context=addon.zoneSearch:RouteContext({})
assert(#context.candidates(from,{category='Auction House'})==0,
 'different world instances must not be compared as if they shared coordinates')
print('uncomparable world instances remain unresolved rather than falsely nearest')
addon.npcs.mapServices={[10]={Vendor=true},[20]={Vendor=true},[30]={['Auction House']=true}}
local detailReads=0
local originalLocations=addon.npcs.LocationsOnMap
addon.npcs.LocationsOnMap=function(self,map)
 detailReads=detailReads+1; return originalLocations(self,map)
end
context=addon.zoneSearch:RouteContext({})
assert(#context.candidates(from,{category='Repair'})==0 and detailReads==0,
 'service-index exclusion must avoid loading every map for an absent function')
print('global search skips maps without the requested service flag')
-- The projection API does not promise an affine map: all four corners can
-- project far away even when an interior service is adjacent to the origin.
records[40]={{id='nonlinear-interior',category='Ammo Vendor',mapID=40,x=.5,y=.5,npcID=4}}
addon.npcs.byMap[40]={[4]=true}
addon.npcs.mapServices[40]={Vendor=true}
local previousWorld=addon.navigation.WorldPosition
addon.navigation.WorldPosition=function(self,map,x,y)
 if map==40 then
  if x==.5 and y==.5 then return 0,1001,500 end
  return 0,10000+x*1000,y*1000
 end
 return previousWorld(self,map,x,y)
end
context=addon.zoneSearch:RouteContext({})
ammo=context.candidates(from,{category='Ammo Vendor'})
assert(#ammo==1 and ammo[1].id=='nonlinear-interior',
 'four projected corners cannot bound a nonlinear map interior or prune its nearer service')
print('nonlinear interior candidate survives invalid four-corner spatial bound')
