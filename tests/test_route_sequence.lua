-- Synthetic geography: no real NPC coordinates or terrain connectivity.
local addon={discovery={PlayerClass=function() return 'Hunter' end}}
assert(loadfile('Routing/RoutePlanner.lua'))('ErrandMaster',addon)
local places={
 {id='local-ammo',mapID=10,x=.11,y=.1,category='Vendor',specialty='Ammo Vendor',npcID=1},
 {id='city-auction',mapID=20,x=.1,y=.1,category='Auction House',npcID=2},
 {id='city-ammo',mapID=20,x=.12,y=.1,category='Vendor',specialty='Ammo Vendor',npcID=3},
 {id='city-bank',mapID=20,x=.11,y=.1,category='Bank',npcID=4},
 {id='wrong-service',mapID=20,x=.1001,y=.1,category='Vendor',npcID=5}}
local function metric(a,b)
 if not a or not b or not a.x or not b.x then return end
 local ax=(a.mapID==20 and 1000 or 0)+a.x*1000
 local bx=(b.mapID==20 and 1000 or 0)+b.x*1000
 return math.sqrt((ax-bx)^2+((a.y-b.y)*1000)^2)
end
local context={distance=metric,candidates=function() return places end}
local requests={{id='ammo',category='Ammo Vendor'},
 {id='auction',category='Auction House',manualPosition=1},{id='bank',category='Bank'}}
assert(type(addon.route.Sequence)=='function','planner needs an ordered, cross-map destination resolver')
local ordered,deferred=addon.route:Sequence(requests,{mapID=10,x=.1,y=.1},true,{},context)
local visible=addon.route:DisplayOrder(ordered,deferred)
assert(#visible==3 and #deferred==0 and visible[1].locationID=='city-auction')
assert(visible[2].locationID=='city-bank' and visible[3].locationID=='city-ammo',
 'services after a forced city stop must resolve from that destination, not original player position')
assert(visible[2].directYards<11 and visible[3].directYards<11)
assert(not requests[1].mapID and not requests[1].npcID,'planning must not pin or mutate saved service requests')
requests[2].manualPosition=nil
ordered,deferred=addon.route:Sequence(requests,{mapID=10,x=.1,y=.1},true,{},context)
visible=addon.route:DisplayOrder(ordered,deferred)
assert(visible[1].locationID=='local-ammo','without forced order the nearby matching service should win')
print('sequential cross-map service selection and manual priority passed')
local uncertain={{id='unresolved',category='Missing',manualPosition=1},
 {id='fixed',mapID=20,x=.1,y=.1,manualPosition=2},{id='ammo',category='Ammo Vendor'}}
ordered,deferred=addon.route:Sequence(uncertain,{mapID=10,x=.1,y=.1},true,{},context)
visible=addon.route:DisplayOrder(ordered,deferred)
assert(visible[1].id=='unresolved' and visible[2].id=='fixed' and visible[3].locationID=='city-ammo')
assert(visible[2].directYards==nil and visible[3].directYards and visible[3].cumulativeYards==nil,
 'known later leg must not invent a total across an unresolved manual stop')
ordered,deferred=addon.route:Sequence({{id='specific',category='Ammo Vendor',npcID=1}},
 {mapID=20,x=.1,y=.1},true,{},context)
assert(ordered[1].npcID==1,'explicit NPC identity must not be replaced by a nearer same-function NPC')
print('unresolved manual stops, unknown totals and explicit NPC identity passed')
local freeUncertain={{id='missing-free',category='Missing'},
 {id='fixed-free',mapID=20,x=.1,y=.1},{id='bank-free',category='Bank'}}
ordered,deferred=addon.route:Sequence(freeUncertain,{mapID=10,x=.1,y=.1},false,{},context)
visible=addon.route:DisplayOrder(ordered,deferred)
assert(visible[1].id=='missing-free' and visible[2].id=='fixed-free' and
 visible[3].locationID=='city-bank','unresolved free stop must remain in order')
assert(visible[2].directYards==nil and visible[2].cumulativeYards==nil,
 'a fixed stop after an unresolved nonreserved stop has no known preceding distance')
assert(visible[3].directYards and visible[3].cumulativeYards==nil,
 'a later measurable leg must not reconstruct the lost cumulative distance')
print('unresolved nonreserved stops reset route origin and cumulative distance')
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
assert(loadfile('Core/Init.lua'))('ErrandMaster',addon)
addon.Position=function() return 10,.1,.1 end
addon.MapWorldSize=function() return 1000,1000 end
addon.ProfessionFilters=function() return {} end
addon.db={data={settings={optimize=true,routeMode='direct'}}}
requests[2].manualPosition=1
addon.errands={All=function() return requests end}
addon.locations={All=function() return {} end}
addon.quests={OnMap=function() return {} end}
addon.zoneSearch={RouteContext=function() return context end}
ordered,deferred=addon:Plan()
visible=addon.route:DisplayOrder(ordered,deferred)
assert(visible[1].locationID=='city-auction' and visible[2].locationID=='city-bank' and visible[3].locationID=='city-ammo',
 'the actual addon Plan entry point must use successive destinations, not player-centered hints')
print('live plan entry point uses sequential service resolution')
local questRequests={{id='quest',questID=99,mapID=20,x=.9,y=.9,manualPosition=1},
 {id='bank',category='Bank'}}
addon.errands.All=function() return questRequests end
addon.quests.OnMap=function(_,map)
 if map==20 then return {{questID=99,mapID=20,x=.1,y=.1,title='Current objective'}} end
 return {}
end
ordered,deferred=addon:Plan()
visible=addon.route:DisplayOrder(ordered,deferred)
assert(#deferred==0 and visible[1].x==.1 and visible[2].locationID=='city-bank',
 'a queued other-zone quest must refresh its destination and anchor following services there')
assert(questRequests[1].x==.9,'planning must not overwrite the saved quest snapshot')
print('other-zone active quests anchor successive service selection')
addon.quests.OnMap=function() return {} end
ordered,deferred=addon:Plan()
visible=addon.route:DisplayOrder(ordered,deferred)
assert(visible[1].questID==99 and not visible[1].x and not visible[1].y,
 'a vanished quest objective must not leave a navigable stale snapshot')
