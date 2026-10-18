local addon={db={data={characters={test={activeErrandId=nil}},settings={}},character='test'}}
local events={}
function events:RegisterEvent() end
function events:SetScript() end
CreateFrame=function() return events end
assert(loadfile('Routing/WalkGraph.lua'))('ErrandMaster',addon)
assert(loadfile('Routing/RoutePlanner.lua'))('ErrandMaster',addon)
assert(loadfile('Core/Init.lua'))('ErrandMaster',addon)
local first={id='first',name='Local vendor',category='Ammo Vendor',mapID=10,x=.12,y=.5}
local second={id='second',name='Offmap',mapID=20,x=.2,y=.5,manualPosition=1}
local saved={[first.id]=first,[second.id]=second}
addon.errands={Get=function(_,id) return saved[id] end,Delete=function(_,id) saved[id]=nil end,
  Reorder=function(_,id,rank)
    for _,item in pairs(saved) do item.manualPosition=nil end
    saved[id].manualPosition=rank
  end}
local ordered,deferred=addon.route:Plan({first,second},10,.1,.5,true,nil,nil,1000,1000,
  {mode='observed',floor=0,nodes={},edges={}})
local display=addon.route:DisplayOrder(ordered,deferred)
assert(addon:ActiveTarget(ordered,deferred).id==display[1].id,
  'navigation must share first visible target even when off-map is manually first')
addon.Refresh=function() end
addon.db.data.characters.test.activeErrandId=first.id
assert(addon:ActiveTarget(ordered,deferred).id==display[1].id,
  'a stale saved selection must not override the first displayed target')
addon:ActivateTarget(first.id)
ordered,deferred=addon.route:Plan({first,second},10,.1,.5,true,nil,nil,1000,1000)
assert(addon:ActiveTarget(ordered,deferred).id==first.id,
  'explicit navigation moves the chosen target to the first displayed position')
second.manualPosition=nil; first.manualPosition=1
assert(addon:ActiveTarget(ordered,deferred).id==first.id)
addon.db.data.characters.test.activeErrandId=first.id
saved[first.id]=nil
assert(addon:ActiveTarget(ordered,deferred).id==second.id and
  addon.db.data.characters.test.activeErrandId==second.id,
  'arrival removes old target and promotes next visible stop')
-- Native world size absent on some clients; projection gives signed yard axes.
addon.navigation={WorldPosition=function(_,map,x,y)
  if map~=10 then return end
  return 99, 800-y*400, 900-x*200
end}
C_Map={GetMapWorldSize=nil,GetBestMapForUnit=function() return 10 end,
  GetPlayerMapPosition=function() return {GetXY=function() return .1,.5 end} end}
local width,height=addon:MapWorldSize(10)
assert(width==200 and height==400,'two projected points recover native yard scale')
C_Map.GetMapWorldSize=function() return 0/0, -1 end
assert(addon:MapWorldSize(10)==200,
  'invalid native size also falls back to guarded projections')
C_Map.GetMapWorldSize=nil
addon.navigation.WorldPosition=function(_,map,x,y)
  return x==0 and 99 or 98,800-y*400,900-x*200
end
assert(addon:MapWorldSize(10)==nil,'different projection instances cannot yield a size')
addon.navigation.WorldPosition=function(_,map,x,y)
  return 99,800-y*400,900-x*200
end
local px=.1
C_Map.GetPlayerMapPosition=function() return {GetXY=function() return px,.5 end} end
UnitOnTaxi=function() return false end
addon.CheckArrival=function() return false end
local refreshed=0
addon.Refresh=function() refreshed=refreshed+1 end
assert(not addon:MovementTick())
px=.145
assert(not addon:MovementTick() and refreshed==0,'nine yards does not trigger refresh')
px=.151
assert(addon:MovementTick() and refreshed==1,'past ten yards triggers refresh with projected scale')
local vendor={id='vendor',name='Find ammunition',category='Ammo Vendor',origin='suggested'}
addon.errands.All=function() return {vendor} end
addon.locations={All=function() return {{id='local-vendor',name='Nearby ammunition',
  category='Ammo Vendor',vendorGroup='Ammo Vendor',mapID=10,x=.16,y=.5}} end}
addon.npcs={IsReady=function() return true end,LocationsOnMap=function() return {} end}
addon.quests={OnMap=function() return {} end}
addon.trails={nodes={},edges={},NativeSample=function() return nil end}
addon.zoneSearch={Nearby=function() error('cross-zone hint must not replace local stop') end}
addon.db.data.settings.routeMode='observed'
addon.db.data.settings.optimize=true
local localPlan,localDeferred=addon:Plan()
assert(#localPlan==1 and localPlan[1].locationID=='local-vendor' and
  localPlan[1].walkStatus=='unknown-route' and #localDeferred==0,
  'observed-empty graph retains a local vendor and never requests a farther zone hint')
print('init queue and projected-size cadence regression passed')
