-- Integrated click path through the real log inventory and native waypoint adapter.
local f=dofile('tests/wheel_fixture.lua')()
local addon,w=f.addon,f.wheel
local log={
 {title='Loch Modan',isHeader=true,isCollapsed=false},
 {title='No POI',questID=101,isHeader=false,isComplete=false},
 {title='Quest with native waypoint',questID=102,isHeader=false,isComplete=false},
 {title='Ashenvale',isHeader=true,isCollapsed=false},
 {title='Second zone quest',questID=201,isHeader=false,isComplete=false},
}
C_QuestLog={
 GetNumQuestLogEntries=function() return #log,3 end,
 GetInfo=function(i) return log[i] end,
 GetLogIndexForQuestID=function(id)
   for i,row in ipairs(log) do if row.questID==id then return i end end
 end,
 GetNextWaypoint=function(id)
   if id==102 then return 44,.2,.3 end
   if id==201 then return 53,.4,.5 end
 end,
 GetQuestsOnMap=function() return {} end,
}
local queued={}
addon.errands={All=function() return queued end,
 Add=function(_,item) queued[#queued+1]=item;return item end}
assert(loadfile('Data/QuestWaypoints.lua'))('ErrandMaster',addon)
assert(loadfile('Data/Quests.lua'))('ErrandMaster',addon)
f:root();f:click(9)
assert(w.menuEntries[1].name=='Loch Modan' and w.menuEntries[2].name=='Ashenvale')
f:click(1)
assert(w.menuEntries[1].name=='No POI' and w.menuEntries[2].name=='Quest with native waypoint')
f:click(1)
assert(#queued==0 and w.frame.shown,'no-POI quest cannot queue a fabricated location')
f:click(2)
assert(#queued==1 and queued[1].questID==102 and queued[1].mapID==44 and
  queued[1].x==.2,'native waypoint map, not player map, reaches real queue')
f:root();f:click(9);f:click(2)
table.remove(log,5)
f:click(1)
assert(#queued==1,'removed live quest cannot queue a stale waypoint')
C_QuestLog=nil
w:Close();f:root();f:click(9)
assert(w.count==1 and w.menuEntries[1].category=='Back',
  'unavailable native log retains a safe Back path')
print('integrated wheel quest-log click path passed')
