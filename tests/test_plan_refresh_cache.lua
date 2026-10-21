-- Count real Core/Init planning entry calls, not only UI refreshes.
local requests={{id='one',mapID=10,x=.4,y=.5,name='Visit',category='Custom'}}
local calls=0
local addon={}
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
assert(loadfile('Core/Init.lua'))('ErrandMaster',addon)
addon.Position=function() return 10,.1,.5 end
addon.MapWorldSize=function() return 1000,1000 end
addon.db={character='test',data={settings={optimize=true,routeMode='direct'},characters={test={}}}}
addon.errands={revision=0,All=function() return requests end,Get=function(_,id) return id=='one' and requests[1] end}
addon.locations={All=function() return {} end}
addon.quests={OnMap=function() return {} end}
addon.zoneSearch={RouteContext=function() return {} end}
addon.route={Sequence=function() calls=calls+1; return requests,{} end,
 DisplayOrder=function(_,ordered) return ordered end}
addon.navigation={Next=function(self,target) self.target=target end,Clear=function() end}
local function render() addon:Plan() end
addon.ui={Refresh=render}; addon.worldMap={Refresh=render}; addon.destinations={Refresh=render}
addon:Refresh()
assert(calls==1,'one refresh must share a single route solve among its consumers; got '..calls)
print('refresh consumers share one route solve')
UnitOnTaxi=function() return false end
local initial=calls
for i=1,20 do addon:CheckArrival(10,.1,.5); addon:RevalidateNavigation() end
assert(calls==initial,'stationary arrival/navigation ticks must not rerun global selection')
addon.errands.revision=1
addon:RevalidateNavigation()
assert(calls==initial+1,'a changed queue must invalidate the route snapshot')
addon:Refresh()
assert(calls==initial+2,'explicit refresh must rebuild once')
addon.ui.Refresh=function() error('synthetic render failure') end
assert(not pcall(addon.Refresh,addon) and addon.refreshPlans==nil,'failed renders must not strand refresh cache')
print('stationary ticks reuse route snapshot; queue edits invalidate it')
