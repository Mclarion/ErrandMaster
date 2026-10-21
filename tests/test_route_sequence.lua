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
assert(visible[1].id=='fixed' and visible[2].locationID=='city-ammo' and visible[3].id=='unresolved',
 'unknown location cannot anchor ahead of located services')
assert(visible[1].directYards and visible[2].directYards and visible[2].cumulativeYards and
 visible[2].directYards<30 and visible[3].canOverride==false,
 'later services must resolve from the last valid stop, while unknown location is not draggable')
assert(uncertain[1].manualPosition==1 and uncertain[1].mapID==nil,
 'routing must retain the saved unresolved request and its manual order')
ordered,deferred=addon.route:Sequence({{id='specific',category='Ammo Vendor',npcID=1}},
 {mapID=20,x=.1,y=.1},true,{},context)
assert(ordered[1].npcID==1,'explicit NPC identity must not be replaced by a nearer same-function NPC')
print('unresolved manual stops, unknown totals and explicit NPC identity passed')
local freeUncertain={{id='missing-free',category='Missing'},
 {id='fixed-free',mapID=20,x=.1,y=.1},{id='bank-free',category='Bank'}}
ordered,deferred=addon.route:Sequence(freeUncertain,{mapID=10,x=.1,y=.1},false,{},context)
visible=addon.route:DisplayOrder(ordered,deferred)
assert(visible[1].id=='fixed-free' and visible[2].locationID=='city-bank' and
 visible[3].id=='missing-free','unresolved free stop must be displayed last')
assert(visible[1].directYards and visible[1].cumulativeYards,
 'fixed stop retains its player-origin leg despite earlier missing service')
assert(visible[2].directYards and visible[2].cumulativeYards and visible[2].directYards<11,
 'later service resolves against the preceding located stop')
print('unresolved free stops move below resolved destinations without losing origin')
local mailbox={{id='mail',category='Mailbox',manualPosition=1},
 {id='auction',category='Auction House',manualPosition=2},
 {id='bank',category='Bank'}, {id='ammo',category='Ammo Vendor'}}
ordered,deferred=addon.route:Sequence(mailbox,{mapID=10,x=.1,y=.1},false,{},context)
visible=addon.route:DisplayOrder(ordered,deferred)
assert(#ordered==3 and #deferred==1 and visible[1].locationID=='city-auction' and
 visible[2].locationID=='city-bank' and visible[3].locationID=='city-ammo' and
 visible[4].id=='mail' and visible[4].canOverride==false,
 'unresolved Mailbox must not cascade into valid later services')
assert(visible[2].directYards<11 and visible[3].directYards<11 and
 visible[3].cumulativeYards and not mailbox[2].mapID,
 'resolved legs remain connected and saved errands remain unmodified')
local walkUnknown=addon.route:DisplayOrder({{id='walk-unknown',mapID=10,x=.2,y=.2,
 walkStatus='unknown-route',manualPosition=1}},{{id='not-located',manualPosition=1}})
assert(walkUnknown[1].id=='walk-unknown' and walkUnknown[2].id=='not-located',
 'unknown walking path does not make a located destination unorderable')
local fallback,fallbackDeferred=addon.route:Plan({
 {id='stale-quest',questID=98,mapID=10,x=.1,y=.1,manualPosition=1},
 {id='valid',mapID=10,x=.2,y=.2}},10,.1,.1,true,nil,{},1000,1000)
local fallbackDisplay=addon.route:DisplayOrder(fallback,fallbackDeferred)
assert(fallbackDisplay[1].id=='valid' and fallbackDisplay[2].id=='stale-quest' and
 fallbackDisplay[2].canOverride==false and not fallbackDisplay[2].x,
 'fallback planner cannot treat stale quest coordinates as a known location')
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
assert(visible[1].locationID=='city-bank' and visible[2].questID==99 and
 not visible[2].x and not visible[2].y and visible[2].canOverride==false,
 'vanished objective must be last, never use stale coordinates or block a valid service')
