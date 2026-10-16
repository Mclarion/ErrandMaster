-- Next-game-waypoint evidence is not a spawn catalog or a walked path.
local addon={}
assert(loadfile('Data/QuestWaypoints.lua'))('ErrandMaster',addon)
local waypoints=addon.questWaypoints
C_QuestLog={
  GetLogIndexForQuestID=function(id) return id==501 and 4 or nil end,
  GetInfo=function(index) return index==4 and {questID=501,title='Find camp',isHeader=false} end,
  GetNextWaypoint=function(id) if id==501 then return 10,.2,.4 end end,
  GetNextWaypointForMap=function(id,map) if id==501 and map==11 then return .8,.3 end end,
  GetNextWaypointText=function() return 'Reach the camp' end,
}
local point=waypoints:ForQuest(501,10)
assert(point and point.mapID==10 and point.x==.2 and point.text=='Reach the camp')
assert(point.source=='game-next-waypoint' and point.title=='Find camp')
assert(not waypoints:ForQuest(502,10),'inactive quest has no destination')
point=waypoints:ForQuest(501,11)
assert(point and point.mapID==11 and point.x==.8 and point.projected==true,
  'a game-projected point on another map is labeled as such')
C_QuestLog.GetNextWaypointForMap=nil
assert(not waypoints:ForQuest(501,11),'wrong-map native point is not silently reused')
C_QuestLog.GetNextWaypoint=function() return 10,3,.2 end
assert(not waypoints:ForQuest(501,10),'invalid coordinates are refused')
C_QuestLog.GetNextWaypoint=function() error('unavailable') end
assert(not waypoints:ForQuest(501,10),'throwing API is refused')
C_QuestLog.GetNextWaypoint=function() return 10,.4,.5 end
local secret={}
issecretvalue=function(value) return value==secret end
C_QuestLog.GetInfo=function() return {questID=secret,title='Hidden',isHeader=false} end
assert(not waypoints:ForQuest(501,10),'secret log ID is refused before comparing')
issecretvalue=nil
C_QuestLog=nil
assert(not waypoints:ForQuest(501,10),'missing native namespace is harmless')
print('native active-quest waypoint tests passed')
