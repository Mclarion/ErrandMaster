local addon={}
assert(loadfile('Routing/WalkGraph.lua'))('ErrandMaster',addon)
assert(loadfile('Routing/RoutePlanner.lua'))('ErrandMaster',addon)
local nodes={
  {id='origin',uiMapID=10,floor=0,x=.1,y=.1,worldMapID=100,wz=10},
  {id='near-air',uiMapID=10,floor=0,x=.101,y=.1,worldMapID=100,wz=10},
  {id='walk-first',uiMapID=10,floor=0,x=.2,y=.1,worldMapID=100,wz=10},
  {id='isolated',uiMapID=10,floor=0,x=.3,y=.1,worldMapID=100,wz=10},
  {id='upstairs',uiMapID=10,floor=1,x=.1,y=.1},
}
local edges={
  {a='origin',b='walk-first',yards=20,source='observed-walk'},
  {a='origin',b='near-air',yards=200,source='observed-walk'},
  {a='walk-first',b='near-air',yards=100,source='observed-walk'},
}
local items={
  {id='b',name='Near by air',mapID=10,x=.101,y=.1,worldMapID=100,wz=10},
  {id='a',name='Far by air',mapID=10,x=.2,y=.1,worldMapID=100,wz=10},
  {id='c',name='No observed edge',mapID=10,x=.3,y=.1,worldMapID=100,wz=10},
}
local context={nodes=nodes,edges=edges,playerLevel=20,mode='observed',floor=0,
  worldMapID=100,wz=10}
local ordered,deferred=addon.route:Plan(items,10,.1,.1,true,nil,nil,1000,1000,context)
assert(#ordered==3 and ordered[1].id=='a' and ordered[2].id=='b' and ordered[3].id=='c',
  'observed cost selects known stops; unknown located stop remains queued')
assert(ordered[1].walkStatus=='known-route' and ordered[1].walkYards==20)
assert(ordered[2].walkYards==100 and ordered[2].walkWaypoints[1].id=='walk-first')
assert(#deferred==0 and ordered[3].walkStatus=='unknown-route' and
  ordered[3].walkWaypoints==nil and ordered[3].walkYards==nil)
local manual,manualDeferred=addon.route:Plan(items,10,.1,.1,false,nil,nil,1000,1000,context)
assert(manual[1].id=='b' and #manual==3 and manual[2].id=='a' and
  manual[2].walkStatus=='unknown-route' and #manualDeferred==0,
  'manual order remains, but no reverse observed edge is invented')
local partial,rest=addon.route:Plan({{id='poi',name='POI',mapID=10,x=.2001,y=.1}},
  10,.1,.1,true,nil,nil,1000,1000,context)
assert(#partial==1 and partial[1].walkStatus=='partial-route' and
  partial[1].walkYards==20 and partial[1].unknownEnd==true and #rest==0,
  'nearby objective gets useful observed segment, with unsampled endpoint disclosed')
local empty,unknown=addon.route:Plan(items,10,.1,.1,true,nil,nil,1000,1000,
  {nodes={},edges={},playerLevel=20,mode='observed',floor=0})
assert(#empty==3 and #unknown==0 and empty[1].walkStatus=='unknown-route' and
  empty[1].walkYards==nil, 'without observed edges, expose coordinates, never a walk')
local upstairs,blocked=addon.route:Plan({{id='up',mapID=10,x=.1,y=.1,floor=1}},10,.1,.1,
  true,nil,nil,1000,1000,context)
assert(#upstairs==1 and #blocked==0 and upstairs[1].walkStatus=='unknown-route' and
  not upstairs[1].walkWaypoints, 'floor transition is a location, not a proven walk')
local anchored={
  {id='isolated-anchor',mapID=10,x=.3,y=.1,manualPosition=1,worldMapID=100,wz=10},
  {id='walkable',mapID=10,x=.2,y=.1,worldMapID=100,wz=10},
  {id='next',mapID=10,x=.101,y=.1,worldMapID=100,wz=10},
}
local navigable,held=addon.route:Plan(anchored,10,.1,.1,true,nil,nil,1000,1000,context)
assert(#navigable==3 and navigable[1].id=='isolated-anchor' and
  navigable[1].walkStatus=='unknown-route' and #held==0 and
  navigable[2].walkStatus=='unknown-route',
  'anchored unknown stop keeps first slot without inventing subsequent observed legs')
local ranked,rankDeferred=addon.route:Plan({
  {id='anchored-second',mapID=10,x=.101,y=.1,worldMapID=100,wz=10,manualPosition=2},
  {id='free-first',mapID=10,x=.2,y=.1,worldMapID=100,wz=10},
},10,.1,.1,true,nil,nil,1000,1000,context)
assert(#ranked==2 and ranked[1].id=='free-first' and
  ranked[2].id=='anchored-second' and #rankDeferred==0,
  'reachable manual slot retains desired rank while free stops optimize')
local direct=addon.route:Plan(items,10,.1,.1,true,nil,nil,1000,1000,
  {nodes=nodes,edges=edges,mode='direct'})
assert(direct[1].id=='b' and direct[1].walkStatus==nil,
  'direct estimate remains an explicit separate mode')
print('observed route ordering, unknown edges and floor isolation passed')
dofile('tests/test_queue_vendor_regression.lua')
