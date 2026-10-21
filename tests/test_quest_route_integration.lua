-- Click -> native pin -> planner modes -> sidebar, including vanishing native state.
local addon={}
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
ErrandMasterDB=nil
for _,path in ipairs({'Core/Database.lua','Core/Errands.lua','Routing/RoutePlanner.lua',
    'Data/QuestWaypoints.lua','Data/Quests.lua','Core/Init.lua','UI/Destinations.lua'}) do
  assert(loadfile(path))('ErrandMaster',addon)
end
addon.db:Initialize('Quest-Integration')
addon.db.data.settings.routeMode='direct'
addon.db.data.settings.optimize=true
addon.Position=function() return 10,.1,.1 end
addon.MapWorldSize=function() return 1000,1000 end
addon.locations={All=function() return {} end}
local pins={{questID=501,mapID=10,x=.3,y=.4,isQuestStart=false}}
local native={}
local watchWrites=0
C_Map={GetBestMapForUnit=function() return 10 end}
C_QuestLog={
 GetNumQuestLogEntries=function() return 3,2 end,
 GetInfo=function(i)
   if i==1 then return {title='Zone',isHeader=true} end
   local id=i==2 and 501 or 502
   return {title='Quest '..id,questID=id,isHeader=false,isComplete=false}
 end,
 GetLogIndexForQuestID=function(id) if id==501 then return 2 elseif id==502 then return 3 end end,
 GetNextWaypoint=function(id)
   local point=native[id]
   if point then return point.mapID,point.x,point.y end
 end,
 GetQuestsOnMap=function(map) return map==10 and pins or {} end,
 AddQuestWatch=function() watchWrites=watchWrites+1 end,
 SetMapForQuestPOIs=function() watchWrites=watchWrites+1 end,
}
local first=assert(addon.quests:Add(501))
assert(first.mapID==10 and first.x==.3,'click saves a native pin rather than a fabricated objective')
local second=assert(addon.quests:Add(502))
assert(not second.mapID,'unlocated active quest remains queued without guessed coordinates')
local function target(id,ordered,deferred)
 for _,group in ipairs({ordered,deferred}) do
  for _,item in ipairs(group) do if item.questID==id then return item end end
 end
end
local ordered,deferred=addon:Plan()
assert(target(501,ordered,deferred).x==.3 and target(501,ordered,deferred).areaTarget==true,
 'direct planner keeps approximate native pin provenance')
assert(target(502,ordered,deferred).x==nil)
-- Minimal sidebar frame: exercise real row construction, not frame rendering.
local sidebar=addon.destinations
sidebar.frame={Show=function() end,Hide=function() end}
sidebar.Render=function() end
sidebar:Refresh()
assert(sidebar.entries[1].text:find('Quest area',1,true),
 'sidebar must distinguish a quest area from an exact objective')
native[501]={mapID=10,x=.65,y=.7}
ordered,deferred=addon:Plan()
assert(target(501,ordered,deferred).x==.65 and not target(501,ordered,deferred).areaTarget and
 target(501,ordered,deferred).questLocationSource=='game-next-waypoint',
 'native next waypoint supersedes area POI by quest ID')
sidebar:Refresh()
assert(not sidebar.entries[1].text:find('Quest area',1,true))
native[501]=nil
addon.quests:Invalidate()
addon.zoneSearch={RouteContext=function()
 return {distance=function(from,to) return math.abs(from.x-to.x)+math.abs(from.y-to.y) end,
 candidates=function() return {} end}
end}
ordered,deferred=addon:Plan()
assert(target(501,ordered,deferred).areaTarget==true,'sequential path retains area provenance')
sidebar:Refresh()
assert(sidebar.entries[1].text:find('Quest area',1,true))
native[501]={mapID=10,x=.8,y=.9}
ordered,deferred=addon:Plan()
assert(target(501,ordered,deferred).x==.8 and not target(501,ordered,deferred).areaTarget,
 'sequential path must deduplicate area pin in favor of precise next waypoint')
pins={}
native[501]=nil
addon.quests:Invalidate() -- Native log/map event invalidates the cached map snapshot.
ordered,deferred=addon:Plan()
assert(target(501,ordered,deferred).x==nil and target(501,ordered,deferred).mapID==nil,
 'stale saved coordinates cannot survive disappearance of the native pin')
sidebar:Refresh()
assert(sidebar.entries[1].text:find('Unknown Location',1,true) and
 not sidebar.entries[1].text:find('Quest area',1,true),
 'sidebar clears approximate indicator when pin vanishes')
addon.zoneSearch=nil
ordered,deferred=addon:Plan()
assert(target(501,ordered,deferred).x==nil and target(501,ordered,deferred).mapID==nil,
 'direct planner also rejects stale saved quest coordinates')
sidebar:Refresh()
assert(not sidebar.entries[1].text:find('Quest area',1,true))
assert(first.x==.3 and watchWrites==0,'planning must not mutate stored queue or user watches')
print('quest click, both plan modes, provenance, sidebar, and stale disappearance passed')
