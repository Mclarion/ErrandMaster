-- Native Forever quest pin fallback: no saved-player files or watch mutation.
local addon={}
local function load(path) assert(loadfile(path))('ErrandMaster',addon) end
ErrandMasterDB=nil
load('Core/Database.lua');load('Core/Errands.lua');load('Routing/RoutePlanner.lua')
addon.db:Initialize('Native-Test')
load('Data/QuestWaypoints.lua');load('Data/Quests.lua')
local pins={}
local nextMap,nextX,nextY
local watchWrites=0
C_Map={GetBestMapForUnit=function(unit) assert(unit=='player'); return 10 end}
C_QuestLog={
 GetNumQuestLogEntries=function() return 4,3 end,
 GetInfo=function(i) if i==1 then return {title='Zone',isHeader=true} end
  local id=i==2 and 501 or i==3 and 502 or 503
  return {title='Quest '..id,questID=id,isHeader=false,isComplete=false} end,
 GetLogIndexForQuestID=function(id)
  if id==501 then return 2 elseif id==502 then return 3 elseif id==503 then return 4 end end,
 GetNextWaypoint=function(id) if id==502 then return nextMap,nextX,nextY end end,
 GetQuestsOnMap=function(map) return pins[map] or {} end,
 AddQuestWatch=function() watchWrites=watchWrites+1 end,
 SetMapForQuestPOIs=function() watchWrites=watchWrites+1 end,
}
local first=assert(addon.quests:Add(501))
assert(first.questID==501 and first.x==nil)
local _,waiting=addon.route:Plan(addon.errands:All(),10,0,0,true,{},addon.quests:OnMap(10))
assert(#waiting==1,'unlocated quest is deferred')
pins[10]={{questID=501,mapID=10,x=.25,y=.3,numObjectives=2,inProgress=true}}
addon.quests:Invalidate()
local areas=addon.quests:QueuedWaypoints()
assert(#areas==1 and areas[1].questID==501 and areas[1].source=='active-quest-poi' and
 areas[1].x==.25 and areas[1].areaTarget==true,'queued pin resolves without native next waypoint')
local route=addon.route:Plan(addon.errands:All(),10,0,0,true,{},areas)
assert(#route==1 and route[1].x==.25,'native pin reaches Plan')
assert(first.x==nil,'stored snapshot is not mutated by live pins')
pins[10][1].x=.75
areas=addon.quests:QueuedWaypoints()
assert(areas[1].x==.75,'objective transition reads fresh native position')
nextMap,nextX,nextY=11,.4,.6
local second=assert(addon.quests:Add(502))
areas=addon.quests:QueuedWaypoints()
assert(#areas==2 and areas[2].mapID==11 and areas[2].source=='game-next-waypoint',
 'remote native next waypoint must not be discarded by current-map lookup')
nextMap,nextX,nextY=nil,nil,nil
pins[10]={}
areas=addon.quests:QueuedWaypoints()
assert(#areas==0,'vanished native positions cannot be replaced with saved snapshots')
assert(watchWrites==0,'reading native tracker never changes quest watches or POI map')
-- A fresh click on an active quest can pick up a current-map pin immediately.
pins[10]={{questID=503,mapID=10,x=.6,y=.7,isQuestStart=true}}
addon.quests:Invalidate()
assert(#addon.quests:OnMap(10)==0,'quest-start pin is not an active objective')
assert(#addon.quests:QueuedWaypoints()==0,'quest-start pin cannot promote an errand')
pins[10]={{questID=503,mapID=10,x=.6,y=.7,inProgress=true}}
local third=assert(addon.quests:Add(503))
assert(third.mapID==10 and third.x==.6 and third.y==.7,
 'click locates native pin on current map without a next waypoint')
assert(watchWrites==0,'click must not modify game watches')
local originalIndex=C_QuestLog.GetLogIndexForQuestID
C_QuestLog.GetLogIndexForQuestID=function(id)
 if id==503 then return nil end
 return originalIndex(id)
end
addon.quests:Invalidate()
assert(#addon.quests:QueuedWaypoints()==0 and #addon.quests:OnMap(10)==0,
 'a stale pin for a removed quest is not accepted without active log identity')
print('native quest pin and deferred routing tests passed')
