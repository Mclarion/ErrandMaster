-- Queue and service fallback regressions; actual provider records are not assumed.
local addon={discovery={PlayerClass=function() return 'Hunter' end}}
assert(loadfile('Routing/WalkGraph.lua'))('ErrandMaster',addon)
assert(loadfile('Routing/RoutePlanner.lua'))('ErrandMaster',addon)
local observed={mode='observed',floor=0,nodes={},edges={}}
local places={{id='local-ammo',name='Local ammo',mapID=10,x=.11,y=.2,
  category='Ammo Vendor',vendorGroup='Ammo Vendor'},
  {id='local-generic',name='Generic',mapID=10,x=.101,y=.2,category='Vendor'}}
local ammo={{id='ammo',name='Ammo',category='Ammo Vendor',origin='suggested'}}
local ordered,deferred=addon.route:Plan(ammo,10,.1,.2,true,places,nil,1000,1000,observed)
assert(#ordered==1 and #deferred==0 and ordered[1].locationID=='local-ammo' and
  ordered[1].walkStatus=='unknown-route' and ordered[1].x==.11 and
  ordered[1].walkYards==nil and ordered[1].walkWaypoints==nil,
  'local specific ammo candidate remains navigable; no invented walking path')
local unlocated={{id='missing',name='Missing ammo',category='Ammo Vendor'}}
local absent,waiting=addon.route:Plan(unlocated,10,.1,.2,true,{places[2]},nil,1000,1000,observed)
assert(#absent==0 and #waiting==1 and not waiting[1].mapID,
  'no matching service never substitutes a generic vendor')
local items={{id='far',mapID=10,x=.8,y=.2},
  {id='offmap',mapID=20,x=.2,y=.2,manualPosition=1},
  {id='near',mapID=10,x=.12,y=.2},
  {id='unknown',manualPosition=3}}
local plan,pending=addon.route:Plan(items,10,.1,.2,true,nil,nil,1000,1000,observed)
assert(#plan==2 and #pending==2 and plan[1].id=='near' and
  plan[1].walkStatus=='unknown-route', 'same-map unknown path still has a ranked stop')
local visible=addon.route:DisplayOrder(plan,pending)
assert(#visible==4 and visible[1].id=='offmap' and visible[3].id=='unknown',
  'manual anchors cover off-map and unlocated stops in displayed order')
print('queue/vendor regression passed')
