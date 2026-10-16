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
assert(#ordered==2 and ordered[1].id=='a' and ordered[2].id=='b',
  'observed cost, not direct-air distance, selects the next stop')
assert(ordered[1].walkStatus=='known-route' and ordered[1].walkYards==20)
assert(ordered[2].walkYards==100 and ordered[2].walkWaypoints[1].id=='walk-first')
assert(#deferred==1 and deferred[1].id=='c' and deferred[1].walkStatus=='unknown-route')
local manual,manualDeferred=addon.route:Plan(items,10,.1,.1,false,nil,nil,1000,1000,context)
assert(manual[1].id=='b' and #manual==1 and manualDeferred[1].id=='a',
  'manual order must not be overridden, nor a reverse edge invented')
local partial,rest=addon.route:Plan({{id='poi',name='POI',mapID=10,x=.2001,y=.1}},
  10,.1,.1,true,nil,nil,1000,1000,context)
assert(#partial==1 and partial[1].walkStatus=='partial-route' and
  partial[1].walkYards==20 and partial[1].unknownEnd==true and #rest==0,
  'nearby objective gets useful observed segment, with unsampled endpoint disclosed')
local empty,unknown=addon.route:Plan(items,10,.1,.1,true,nil,nil,1000,1000,
  {nodes={},edges={},playerLevel=20,mode='observed',floor=0})
assert(#empty==0 and #unknown==3 and unknown[1].walkStatus=='unknown-route',
  'without observed edges, report unknown instead of falling back to air distance')
local upstairs,blocked=addon.route:Plan({{id='up',mapID=10,x=.1,y=.1,floor=1}},10,.1,.1,
  true,nil,nil,1000,1000,context)
assert(#upstairs==0 and #blocked==1, 'do not infer same-coordinate floor transition')
local direct=addon.route:Plan(items,10,.1,.1,true,nil,nil,1000,1000,
  {nodes=nodes,edges=edges,mode='direct'})
assert(direct[1].id=='b' and direct[1].walkStatus==nil,
  'direct estimate remains an explicit separate mode')
print('observed route ordering, unknown edges and floor isolation passed')
