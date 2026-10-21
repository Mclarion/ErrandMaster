-- Synthetic subset of SPF's pinned Routes/Portals schema; no shipped coordinates.
local addon={transportData={
  Docks={
    {map=0,x=-100,y=200,z=5,walk={map=0,x=-90,y=210,z=7}},
    {map=0,x=300,y=400,z=0},
  },
  Routes={
    [241]={kind='boat',stops={{dock=1},{dock=2}}},
  },
  Portals={
    {name='Portal A',kind='portal',from={map=0,x=-50,y=100,z=3},to={map=0,x=50,y=100,z=4}},
  },
}}
local calls={}
CreateVector2D=function(x,y) return {GetXY=function() return x,y end} end
C_Map={GetWorldPosFromMapPos=function(mapID,position)
  assert(mapID==1412)
  return 0,CreateVector2D(0,0)
end,GetMapPosFromWorldPos=function(instance,position,mapID)
  local x,y=position:GetXY()
  calls[#calls+1]={instance,x,y,mapID}
  assert(mapID==1412 and (instance==0 or instance==1))
  return mapID,CreateVector2D(instance==0 and .2 or .8,.4)
end}
UnitFactionGroup=function() return 'Alliance' end
assert(loadfile('Data/StaticTransport.lua'))('ErrandMaster',addon)
local catalog=assert(addon.staticTransport)
local boats=catalog:LocationsOnMap(1412,'Boat')
assert(#boats==2 and boats[1].category=='Boat' and boats[2].category=='Boat')
assert(boats[1].mapID==1412 and boats[1].x==.2 and boats[1].y==.4)
assert(boats[1].worldInstance==0 and boats[1].worldX==-100 and boats[1].worldY==200 and boats[1].worldZ==5,
  'dock world coordinates (not walk position or assumed normalized coordinates) must be retained')
assert(boats[1].plannerEligible==false and boats[1].precision=='endpoint-candidate')
local portals=catalog:LocationsOnMap(1412,'Portal')
assert(#portals==1 and portals[1].category=='Portal' and portals[1].endpoint=='from',
  'arrival points are not selectable entrances without a separate reverse portal')
assert(portals[1].worldInstance==0 and portals[1].worldX==-50 and portals[1].worldZ==3)
assert(portals[1].plannerEligible==false)
-- A native map's world instance must be checked even if an API projection
-- returns the requested map for unrelated instance-space coordinates.
local second={transportData={Docks={{map=1,x=40,y=50,z=0},
  {map=0,x=10,y=20,z=0}},Routes={[3]={kind='boat',faction='Alliance',
    stops={{dock=1},{dock=2}}}}}}
assert(loadfile('Data/StaticTransport.lua'))('ErrandMaster',second)
local before=#calls
local found=second.staticTransport:LocationsOnMap(1412,'Boat')
assert(#found==1 and found[1].worldInstance==0 and #calls==before+1,
  'wrong instance must never be projected into requested UI map')
local originalMap=C_Map
local projections=0
C_Map={GetWorldPosFromMapPos=function(mapID)
  if mapID==1413 then return 1,CreateVector2D(0,0) end
  if mapID==9999 then return nil end
  return 0,CreateVector2D(0,0)
end,GetMapPosFromWorldPos=function(instance,position,mapID)
  projections=projections+1
  local x=position:GetXY()
  if x==-999 then return nil end
  if x==-10 then return mapID+1,CreateVector2D(.1,.1) end
  if x==0 then return mapID,CreateVector2D(1.01,.1) end
  return mapID,CreateVector2D(.25,.75)
end}
local third={transportData={Docks={{map=0,x=10,y=1,z=0},
  {map=0,x=20,y=2,z=2},{map=0,x=-999,y=3,z=3},
  {map=0,x=-10,y=4,z=4},{map=0,x=0,y=5,z=5},
  {map=0,x=0/0,y=5,z=5},{map=0,x=30,y=5,z=5},
  {map=1,x=40,y=5,z=5}},Routes={
    [7]={kind='boat',faction='Horde',stops={{dock=1}}},
    [8]={kind='boat',faction='Alliance',stops={{dock=2},{dock=3},
      {dock=4},{dock=5},{dock=6},{dock=8}}},
    [9]={kind='zeppelin',stops={{dock=7}}},
    [10]={kind='boat',stops={{dock=7}}}},Portals={
      {kind='passage',name='Passage',from={map=0,x=11,y=0,z=0}},
      {kind='portal',name='Portal',from={map=0,x=12,y=0,z=0},
        to={map=1,x=13,y=0,z=0}},
      {kind='portal',faction='Horde',from={map=0,x=14,y=0,z=0}},
  }}}
assert(loadfile('Data/StaticTransport.lua'))('ErrandMaster',third)
local boat=third.staticTransport:LocationsOnMap(1412,'Boat')
assert(#boat==2 and ((boat[1].worldX==20 and boat[2].worldX==30) or
  (boat[1].worldX==30 and boat[2].worldX==20)),
  'exclude faction-locked, other-kind, unprojectable and invalid endpoints')
assert(projections==5,'only same-instance allowed-faction boat points are projected')
local portal=third.staticTransport:LocationsOnMap(1412,'Portal')
assert(#portal==1 and portal[1].endpoint=='from' and portal[1].worldX==12,
  'passages and other-faction portals are not generic portal candidates')
local total=projections
boat[1].x=0
assert(third.staticTransport:LocationsOnMap(1412,'Boat')[1].x==.25 and
  projections==total,'cached records are insulated from caller mutation')
assert(#third.staticTransport:LocationsOnMap(1413,'Boat')==1 and
  third.staticTransport:LocationsOnMap(1413,'Boat')[1].worldX==40)
assert(#third.staticTransport:LocationsOnMap(9999,'Boat')==0)
assert(#third.staticTransport:LocationsOnMap(1412,'Flight Master')==0)
UnitFactionGroup=function() return 'Horde' end
assert(#third.staticTransport:LocationsOnMap(1412,'Boat')==2 and
  third.staticTransport:LocationsOnMap(1412,'Boat')[2].worldX==10,
  'cache partitions by current faction')
for map=1500,1540 do third.staticTransport:LocationsOnMap(map,'Portal') end
assert(#third.staticTransport.order<=32,'map cache must be bounded')
C_Map.GetMapPosFromWorldPos=nil
assert(#third.staticTransport:LocationsOnMap(1600,'Portal')==0,
  'native projection absent means no guessed coordinates')
C_Map=originalMap
local vector=CreateVector2D
CreateVector2D=function(x,y)
  if x==.5 then error('native vector unavailable') end
  return vector(x,y)
end
local ok,empty=pcall(function() return third.staticTransport:LocationsOnMap(1601,'Boat') end)
assert(ok and #empty==0,'native vector creation failure is an empty result')
CreateVector2D=vector
print('static transport source endpoint projection, filtering and bounded cache passed')
