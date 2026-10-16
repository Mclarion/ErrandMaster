-- A traversed-edge graph must never quietly turn air distance into walking distance.
local addon={}
assert(loadfile('Routing/WalkGraph.lua'))('ErrandMaster',addon)
local graph=addon.walkGraph
local nodes={
  {id='start',uiMapID=10,floor=1,x=.1,y=.1,source='observed-walk'},
  {id='north',uiMapID=10,floor=1,x=.1,y=.9,source='observed-walk'},
  {id='east',uiMapID=10,floor=1,x=.9,y=.9,source='observed-walk'},
  {id='goal',uiMapID=10,floor=1,x=.9,y=.1,source='observed-walk'},
  {id='above',uiMapID=10,floor=2,x=.1,y=.1,source='observed-walk'},
}
local edges={
  {a='start',b='north',yards=80,source='observed-walk'},
  {a='north',b='east',yards=80,source='observed-walk'},
  {a='east',b='goal',yards=80,source='observed-walk'},
  {a='start',b='goal',yards=90,source='air'}, -- not traversed
  {a='start',b='goal',yards=140,source='observed-walk',minLevel=60},
}
local start={uiMapID=10,floor=1,x=.1,y=.1}
local goal={uiMapID=10,floor=1,x=.9,y=.1}
local path=graph:Plan(nodes,edges,start,goal,20)
assert(path.status=='known-route' and path.yards==240 and #path.waypoints==4,
  'underlevel player prefers a longer observed, lower-level detour')
local prepared=graph:Prepare(nodes,edges,start,20)
local built=graph:Build(nodes,edges,20)
assert(graph:FromPrepared(graph:PrepareBuilt(built,start),goal).yards==path.yards,
  'adjacency is reusable for each origin in a multi-stop itinerary')
local shared=graph:FromPrepared(prepared,goal)
assert(shared.status==path.status and shared.yards==path.yards and
  #shared.waypoints==#path.waypoints,
  'one-to-many graph preparation preserves single-destination semantics')
local assessed=graph:Assess(prepared,goal)
assert(assessed.status==shared.status and assessed.weightedCost==shared.weightedCost and
  assessed.hasSegment and assessed.waypoints==nil,
  'candidate assessment does not allocate a path for every possible stop')
assert(path.waypoints[2].id=='north' and path.warning==nil and path.weightedCost==240)
local higher=graph:Plan(nodes,edges,start,goal,70)
assert(higher.status=='known-route' and higher.yards==140 and #higher.waypoints==2)
assert(graph:Plan(nodes,edges,start,{uiMapID=10,floor=2,x=.1,y=.1},20).status=='unknown-route',
  'the same 2D position on another floor is not reachable without a verified transition')
local higherFloor={uiMapID=10,floor=2,x=.1,y=.1}
local unverified={{a='start',b='above',yards=5,source='observed-transition'}}
assert(graph:Plan(nodes,unverified,start,higherFloor,70).status=='unknown-route')
local stair={{a='start',b='above',yards=30,source='observed-transition',verified=true}}
assert(graph:Plan(nodes,stair,start,higherFloor,70).status=='known-route',
  'only an explicitly verified traversed stair can join floors')
assert(graph:Plan(nodes,edges,start,{uiMapID=11,floor=1,x=.9,y=.1},70).status=='unknown-route')
local onlyAir=graph:Plan(nodes,{{a='start',b='goal',yards=90,source='air'}},start,goal,70)
assert(onlyAir.status=='unknown-route' and onlyAir.yards==nil and #onlyAir.waypoints==0)
local forwardOnly={{a='start',b='north',yards=80,source='observed-walk'}}
assert(graph:Plan(nodes,forwardOnly,{uiMapID=10,floor=1,x=.1,y=.9},start,70).status=='unknown-route',
  'one observed downhill traversal cannot certify its reverse')
local nearGoal={uiMapID=10,floor=1,x=.9006,y=.1}
local partial=graph:Plan(nodes,edges,start,nearGoal,70)
assert(partial.status=='partial-route' and partial.yards==140 and partial.unknownEnd==true,
  'a small untraversed connector cannot be described as a fully walkable route')
local disconnected={
  {id='entry',uiMapID=10,floor=1,x=.1,y=.1},
  {id='reached',uiMapID=10,floor=1,x=.5,y=.5},
  {id='island',uiMapID=10,floor=1,x=.5004,y=.5},
}
local entered={uiMapID=10,floor=1,x=.1,y=.1}
local nearIsland={uiMapID=10,floor=1,x=.50035,y=.5}
local islandEdges={{a='entry',b='reached',yards=40,source='observed-walk'}}
local alternative=graph:Plan(disconnected,islandEdges,entered,nearIsland,70)
assert(alternative.status=='partial-route' and alternative.yards==40 and
  alternative.unknownEnd and #alternative.waypoints==2,
  'a closer disconnected sample must not hide a reachable, unverified connector')
assert(graph:Plan(disconnected,islandEdges,entered,
  {uiMapID=10,floor=1,x=.5004,y=.5},70).status=='unknown-route',
  'an exact disconnected endpoint must not be silently rerouted to a nearby node')
assert(graph:Plan(nodes,edges,{uiMapID=10,floor=1,x=.14,y=.1},goal,70).status=='unknown-route',
  'do not snap through a nearby but unobserved gap')
local stacked={
  {id='lower',uiMapID=10,floor=0,x=.5,y=.5,worldMapID=100,wz=10},
  {id='upper',uiMapID=10,floor=0,x=.5,y=.5,worldMapID=100,wz=80},
}
local lower={uiMapID=10,floor=0,x=.5,y=.5,worldMapID=100,wz=10}
local upper={uiMapID=10,floor=0,x=.5,y=.5,worldMapID=100,wz=80}
assert(graph:Plan(stacked,{{a='lower',b='upper',yards=70,source='observed-walk'}},
  lower,upper,70).status=='unknown-route',
  'unknown floor number is not permission to connect different elevations')
assert(graph:Plan(stacked,{}, {uiMapID=10,floor=0,x=.5,y=.5},lower,70).status=='unknown-route',
  'origin without observed height cannot select a stacked layer')
local ambiguous={
  {id='near-low',uiMapID=10,floor=0,x=.5001,y=.5,worldMapID=100,wz=10},
  {id='far-high',uiMapID=10,floor=0,x=.5002,y=.5,worldMapID=100,wz=80},
  {id='near-low-again',uiMapID=10,floor=0,x=.5003,y=.5,worldMapID=100,wz=10},
}
local unlayered={uiMapID=10,floor=0,x=.5,y=.5}
assert(graph:Plan(ambiguous,{},lower,unlayered,70).status=='unknown-route',
  'a pin near multiple elevations cannot be assigned a layer by proximity')
local invalid={{a='start',b='goal',yards=-1,source='observed-walk'},
  {a='start',b='goal',yards=1,source='observed-walk',minLevel=math.huge}}
assert(graph:Plan(nodes,invalid,start,goal,70).status=='unknown-route')
local secret={}
issecretvalue=function(value) return value==secret end
assert(graph:Plan(nodes,edges,secret,goal,70).status=='unknown-route')
issecretvalue=nil
print('observed-walk graph, floor, level and unknown-route tests passed')
