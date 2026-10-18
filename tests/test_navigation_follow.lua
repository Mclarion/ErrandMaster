-- Observed routes are followed one certified connector at a time.
local addon={}
assert(loadfile('Routing/WalkGraph.lua'))('ErrandMaster',addon)
assert(loadfile('Routing/Navigation.lua'))('ErrandMaster',addon)
local nav=addon.navigation
local x,y=.5,.5
addon.Position=function() return 10,x,y end
addon.MapWorldSize=function() return 1000,1000 end
addon.trails={NativeSample=function() return {uiMapID=10,floor=0,worldMapID=100,wz=10} end,
  edges={{a='start',b='corner',yards=100,source='observed-walk'},
    {a='corner',b='end',yards=200,source='observed-walk'}}}
GetPlayerFacing=function() return 0 end
local function node(id,nx,ny)
  return {id=id,uiMapID=10,floor=0,x=nx,y=ny,worldMapID=100,wz=10}
end
local path={node('start',.5,.5),node('corner',.4,.5),node('end',.4,.7)}
local target={id='goal',mapID=10,x=.4,y=.7,walkStatus='known-route',
  unknownStart=false,unknownEnd=false,walkWaypoints=path,walkYards=300}
assert(nav:Next(target))
local reading=nav:Guidance(target)
assert(reading and reading.targetDistance==nav:Measure(target).distance,
  'observed waypoint guidance must retain live direct distance to the actual destination')
assert(reading and reading.mode=='observed' and reading.waypoint==path[2] and
  reading.angle>1 and math.abs(reading.distance-100)<.001,
  'dogleg first bearing points west, away from final southwest goal')
local originalEdge=addon.trails.edges[1]
addon.trails.edges[1]=nil
assert(nav:Guidance(target).mode=='direct-unknown',
  'removed evidence must invalidate guidance immediately, without waiting for a replan')
assert(nav:Next(target) and nav:Guidance(target).mode=='direct-unknown',
  'removed evidence invalidates even a previously active observed leg')
addon.trails.edges[1]=originalEdge
assert(nav:Next(target) and nav:Guidance(target).mode=='observed')
-- A fresh plan produces new item/node tables; unchanged evidence must retain progress.
local replanned={id='goal',mapID=10,x=.4,y=.7,walkStatus='known-route',
  unknownStart=false,unknownEnd=false,walkWaypoints={node('start',.5,.5),
  node('corner',.4,.5),node('end',.4,.7)},walkYards=300}
assert(nav:Next(replanned))
x,y=.401,.5
reading=nav:Guidance(replanned)
assert(reading.mode=='observed' and reading.waypoint.id=='end',
  'only near the next connector may the follower advance')
assert(nav:Next(replanned) and nav:Guidance(replanned).waypoint.id=='end',
  'the bounded replan retains connector progress on identical evidence')
x,y=.4,.699
reading=nav:Guidance(replanned)
assert(reading.mode=='observed' and reading.waypoint.id=='end',
  'the final connector is never silently treated as an off-graph endpoint')
x,y=.5,.5
assert(nav:Guidance(replanned).mode=='direct-unknown',
  'leaving the current leg invalidates the route rather than skipping a corner')
assert(nav:Guidance(replanned).mode=='direct-unknown',
  'off-corridor invalidation remains until a new plan or target')
nav:Clear()
assert(nav:Next(target))
x,y=.4,.7
assert(nav:Guidance(target).mode=='direct-unknown',
  'standing at the goal cannot jump past the unvisited dogleg corner')
x,y=.5,.5
assert(nav:Next({id='goal',mapID=10,x=.4,y=.7,walkStatus='partial-route',
  unknownStart=true,walkWaypoints=path}))
assert(nav:Guidance(nav.target).mode=='direct-unknown',
  'partial-start connector never implies walking from the player')
local partial={id='goal',mapID=10,x=.4,y=.71,walkStatus='partial-route',
  unknownEnd=true,walkWaypoints=path,walkYards=300}
assert(nav:Next(partial))
assert(nav:Guidance(partial).mode=='observed' and nav:Guidance(partial).routeStatus=='partial-end')
addon.trails.NativeSample=function() return {uiMapID=10,floor=0,worldMapID=100,wz=30} end
assert(nav:Guidance(partial).mode=='direct-unknown',
  'different elevation cannot follow an apparently matching 2D corridor')
addon.trails.NativeSample=function() return nil end
assert(nav:Next(target) and nav:Guidance(target).mode=='direct-unknown',
  'unknown layer cannot certify floor-zero connectors')
assert(nav:Next({id='goal',mapID=10,x=.4,y=.7,walkStatus='unknown-route'}) and
  nav:Guidance(nav.target).mode=='direct-unknown')
-- WalkGraph snaps only to nodes, so a normal midpoint replan is unknown even
-- though the already-started directed connector remains observed.
addon.trails.edges={{a='start',b='corner',yards=100,source='observed-walk'},
  {a='corner',b='end',yards=200,source='observed-walk'}}
addon.trails.NativeSample=function() return {uiMapID=10,floor=0,worldMapID=100,wz=10} end
local function graphTarget()
  local origin={uiMapID=10,floor=0,x=x,y=y,worldMapID=100,wz=10}
  local destination={uiMapID=10,floor=0,x=.4,y=.7,worldMapID=100,wz=10}
  local plan=addon.walkGraph:Plan(path,addon.trails.edges,origin,destination,20)
  return {id='goal',mapID=10,x=.4,y=.7,walkStatus=plan.status,
    unknownStart=plan.unknownStart,unknownEnd=plan.unknownEnd,
    walkWaypoints=plan.waypoints,walkYards=plan.yards}
end
nav:Clear()
x,y=.5,.5
local fromStart=graphTarget()
assert(fromStart.walkStatus=='known-route' and #fromStart.walkWaypoints==3)
assert(nav:Next(fromStart) and nav:Guidance(fromStart).mode=='observed')
x=.45
local midPlan=graphTarget()
assert(midPlan.walkStatus=='unknown-route' and #midPlan.walkWaypoints==0,
  'real WalkGraph replan loses its start snap halfway along the connector')
assert(nav:Next(midPlan) and nav:Guidance(midPlan).mode=='observed' and
  nav:Guidance(midPlan).waypoint.id=='corner',
  'mid-edge unknown replan keeps the certified active connector')
assert(nav:Next(graphTarget()) and nav:Guidance(nav.target).mode=='observed',
  'successive two-second unknown replans keep the same certified leg')
x=.4
assert(nav:Guidance(nav.target).mode=='observed' and nav:Guidance(nav.target).waypoint.id=='end',
  'retained path advances at its real next node')
x=.45
addon.trails.edges[1]=nil
assert(nav:Next(midPlan) and nav:Guidance(midPlan).mode=='direct-unknown',
  'removed directed evidence must discard the retained path')
addon.trails.edges[1]={a='start',b='corner',yards=100,source='observed-walk'}
x=.5
assert(nav:Next(fromStart) and nav:Guidance(fromStart).mode=='observed')
x=.45
assert(nav:Next(graphTarget()))
local changed={id='other',mapID=10,x=.4,y=.7,walkStatus='unknown-route'}
assert(nav:Next(changed) and nav:Guidance(changed).mode=='direct-unknown',
  'a different identity cannot inherit a leg')
assert(nav:Next(fromStart) and nav:Guidance(fromStart).mode=='direct-unknown',
  'a new start snap cannot be invented at the midpoint')
x=.5
assert(nav:Next(fromStart) and nav:Guidance(fromStart).mode=='observed')
x=.45
local moved={id='goal',mapID=10,x=.41,y=.7,walkStatus='unknown-route'}
assert(nav:Next(moved) and nav:Guidance(moved).mode=='direct-unknown',
  'changed coordinates cannot inherit a leg')
x=.5
assert(nav:Next(fromStart) and nav:Guidance(fromStart).mode=='observed')
x,y=.45,.53
assert(nav:Next(graphTarget()) and nav:Guidance(nav.target).mode=='direct-unknown',
  'off-corridor replans cannot keep stale legs')
x,y=.5,.5
assert(nav:Next(fromStart) and nav:Guidance(fromStart).mode=='observed')
x=.45
local oldPosition=addon.Position
addon.Position=function() return 11,x,y end
assert(nav:Next(midPlan) and not nav.follower, 'map change cannot preserve a leg')
addon.Position=oldPosition

-- Both directions of a legitimate rise of five yards remain navigable;
-- matching just either endpoint would falsely accept the stacked layer.
local slope={node('low',.5,.5),node('high',.4,.5)}
slope[2].wz=15
addon.trails.edges={{a='low',b='high',yards=100,source='observed-walk'},
  {a='high',b='low',yards=100,source='observed-walk'}}
local built=addon.walkGraph:Build(slope,addon.trails.edges,20)
assert(#built.neighbors.low==1 and #built.neighbors.high==1,
  'WalkGraph accepts both observed directions with a five-yard elevation change')
local elevation=10
addon.trails.NativeSample=function() return {uiMapID=10,floor=0,worldMapID=100,wz=elevation} end
local uphill={id='hill',mapID=10,x=.4,y=.5,walkStatus='known-route',
  unknownStart=false,unknownEnd=false,walkWaypoints=slope,walkYards=100}
x,y=.5,.5
assert(nav:Next(uphill) and nav:Guidance(uphill).mode=='observed',
  'rise five is a valid observed-walk edge at its low endpoint')
x,elevation=.45,12.5
assert(nav:Guidance(uphill).mode=='observed', 'uphill midpoint follows interpolated elevation')
elevation=17
assert(nav:Guidance(uphill).mode=='direct-unknown',
  'elevation near the high endpoint must not authorize the wrong midpoint layer')
elevation=12.5
assert(nav:Next(uphill) and nav:Guidance(uphill).mode=='direct-unknown',
  'invalidated stacked-layer follower cannot revive at the midpoint')
local downhill={id='hill',mapID=10,x=.5,y=.5,walkStatus='known-route',
  unknownStart=false,unknownEnd=false,walkWaypoints={slope[2],slope[1]},walkYards=100}
x,elevation=.4,15
assert(nav:Next(downhill) and nav:Guidance(downhill).mode=='observed',
  'fall five is a valid directed observed-walk edge at its high endpoint')
x,elevation=.45,12.5
assert(nav:Guidance(downhill).mode=='observed', 'downhill midpoint follows interpolated elevation')
elevation=10
assert(nav:Guidance(downhill).mode=='direct-unknown',
  'low endpoint elevation cannot authorize the wrong midpoint layer')
local sampleWorld=100
addon.trails.NativeSample=function()
  return {uiMapID=10,floor=0,worldMapID=100,wz=15}
end
x=.4
assert(nav:Next(downhill) and nav:Guidance(downhill).mode=='observed')
x=.45
sampleWorld=101
addon.trails.NativeSample=function()
  return {uiMapID=10,floor=0,worldMapID=sampleWorld,wz=12.5}
end
assert(nav:Next(downhill) and nav:Guidance(downhill).mode=='direct-unknown',
  'matching interpolated elevation on another world layer is not enough')
print('observed navigation follower tests passed')
