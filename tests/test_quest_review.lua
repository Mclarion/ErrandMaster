local addon={}
ErrandMasterDB=nil
for _,file in ipairs({'Core/Database.lua','Core/Errands.lua','Data/Quests.lua'}) do
 assert(loadfile(file))('ErrandMaster',addon)
end
addon.db:Initialize('Review-Test')
local label=string.rep('a',79)..string.char(195,169)..' end'
local nextMap
C_QuestLog={
 GetNumQuestLogEntries=function() return 1,1 end,
 GetLogIndexForQuestID=function(id) if id==91 then return 1 end end,
 GetInfo=function() return {questID=91,title=label,isHeader=false} end,
 GetNextWaypoint=function() return nextMap,.2,.3 end,
}
local saved=assert(addon.quests:Add(91))
assert(saved.name==string.rep('a',79),'saved quest names must not split a UTF-8 codepoint')
assert(not saved.mapID)
print('localized quest title truncation preserves UTF-8 boundaries')
nextMap=20
addon.quests:Invalidate()
assert(type(addon.quests.QueuedWaypoints)=='function','queued quests need native destination discovery independent of saved map')
local points=addon.quests:QueuedWaypoints()
assert(#points==1 and points[1].questID==91 and points[1].mapID==20 and points[1].x==.2)
assert(saved.mapID==nil,'native resolution must not persist a transient objective on the request')
print('previously unlocated quest discovers its new remote native waypoint')
CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end
for _,file in ipairs({'Routing/RoutePlanner.lua','Data/ZoneSearch.lua','Core/Init.lua'}) do
 assert(loadfile(file))('ErrandMaster',addon)
end
addon.Position=function() return 10,.5,.5 end
addon.MapWorldSize=function() return 1000,1000 end
addon.locations={All=function() return {} end}
addon.db.data.settings.routeMode='direct'
local ordered,deferred=addon:Plan()
assert(#ordered==1 and #deferred==0 and ordered[1].mapID==20 and saved.mapID==nil,
 'live planning must promote an unlocated quest when a remote native waypoint appears')
print('actual planner promotes a deferred quest using its newly available remote waypoint')
