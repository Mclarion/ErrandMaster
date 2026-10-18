-- Character quest-log zone inventory contract; no player saves or client involved.
local addon = {}
assert(loadfile('Data/Quests.lua'))('ErrandMaster', addon)
local rows = {
  {title='Loch Modan', isHeader=true, isCollapsed=false},
  {title='Find the camp', questID=501, isHeader=false, isComplete=false},
  {title='Lac Modan', isHeader=true, isCollapsed=false},
  {title='Second quest', questID=502, isHeader=false, isComplete=true},
}
C_QuestLog = {
  GetNumQuestLogEntries=function() return #rows, 2 end,
  GetInfo=function(index) return rows[index] end,
}
local zones = addon.quests:ZoneInventory()
assert(#zones == 2, 'returns zone groups across the entire quest log')
assert(zones[1].name == 'Loch Modan' and zones[1].quests[1].questID == 501)
assert(zones[2].name == 'Lac Modan' and zones[2].quests[1].questID == 502)
assert(zones[1].quests[1].hasLocation == false and zones[1].quests[1].mapID == nil and
  zones[1].quests[1].x == nil and zones[1].quests[1].y == nil,
  'log entries without locations remain visible but cannot be navigated to')
assert(zones[2].quests[1].isComplete == true, 'completion is read from the live log')
-- Re-scan on each call: updates and removal cannot return stale menu entries.
C_QuestLog.IsComplete=function(id) return id == 501 end
rows[2].title='Camp located'
table.remove(rows, 4)
zones=addon.quests:ZoneInventory()
assert(zones[1].quests[1].title=='Camp located' and zones[1].quests[1].isComplete)
assert(#zones[2].quests==0, 'a removed quest is no longer present')

-- Only native coordinates from an active quest's own waypoint are navigable.
C_QuestLog.GetNextWaypoint=function(id)
  if id == 501 then return 10, .3, .4 end
end
zones=addon.quests:ZoneInventory()
local point=zones[1].quests[1]
assert(point.hasLocation and point.mapID==10 and point.x==.3 and point.y==.4 and
  point.source=='game-next-waypoint')
C_QuestLog.GetNextWaypoint=function() return 10, 2, .4 end
assert(not addon.quests:ZoneInventory()[1].quests[1].hasLocation)

-- The number of shown entries excludes quests underneath a collapsed header.
local collapsed=true
C_QuestLog.GetNumQuestLogEntries=function() return collapsed and 2 or 3, 1 end
C_QuestLog.GetInfo=function(i)
  if i==1 then return {title='Loch Modan',isHeader=true,isCollapsed=collapsed} end
  if i==2 and not collapsed then
    return {title='Hidden in UI',questID=601,isHeader=false,isComplete=false}
  end
  return {title='Ashenvale',isHeader=true,isCollapsed=false}
end
ExpandQuestHeader=function(i) assert(i==1); collapsed=false end
CollapseQuestHeader=function(i) assert(i==1); collapsed=true end
C_QuestLog.GetNextWaypoint=nil
zones=addon.quests:ZoneInventory()
assert(collapsed and #zones==2 and zones[1].quests[1].questID==601,
  'enumerate collapsed quests and restore the UI header state')
ExpandQuestHeader=nil
CollapseQuestHeader=nil
zones=addon.quests:ZoneInventory()
assert(#zones[1].quests==0 and zones[1].incomplete == true,
  'never claim collapsed quests were enumerated when expansion is unavailable')

-- Two headers may be collapsed independently; both must be restored exactly.
local state={true,true}
C_QuestLog.GetNumQuestLogEntries=function()
  return 2+(state[1] and 0 or 1)+(state[2] and 0 or 1),2
end
C_QuestLog.GetInfo=function(i)
  local visible={{title='Loch Modan',isHeader=true,isCollapsed=state[1]}}
  if not state[1] then visible[#visible+1]={title='First',isHeader=false,questID=601} end
  visible[#visible+1]={title='Ashenvale',isHeader=true,isCollapsed=state[2]}
  if not state[2] then visible[#visible+1]={title='Second',isHeader=false,questID=602} end
  return visible[i]
end
ExpandQuestHeader=function(i)
  local row=C_QuestLog.GetInfo(i)
  state[row.title=='Loch Modan' and 1 or 2]=false
end
CollapseQuestHeader=function(i)
  local row=C_QuestLog.GetInfo(i)
  state[row.title=='Loch Modan' and 1 or 2]=true
end
zones=addon.quests:ZoneInventory()
assert(state[1] and state[2] and zones[1].quests[1].questID==601 and
  zones[2].quests[1].questID==602, 'both collapsed headers restore independently')
ExpandQuestHeader=nil
CollapseQuestHeader=nil

-- Hidden entries are deliberately absent; malformed and secret IDs never leak.
local secret={}
issecretvalue=function(v) return rawequal(v,secret) end
C_QuestLog.GetNumQuestLogEntries=function() return 5,4 end
C_QuestLog.GetInfo=function(i)
  if i==1 then return {title='Zone',isHeader=true} end
  if i==2 then return {title='Hidden',questID=700,isHeader=false,isHidden=true} end
  if i==3 then return {title='Secret',questID=secret,isHeader=false} end
  if i==4 then return {title='Visible',questID=701,isHeader=false} end
  return {title='Repeated',questID=701,isHeader=false}
end
zones=addon.quests:ZoneInventory()
assert(#zones[1].quests==1 and zones[1].quests[1].questID==701 and
  select(2,addon.quests:ZoneInventory())==false,
  'hidden and duplicate rows are ignored, malformed IDs report partial inventory')
C_QuestLog.GetInfo=function(i)
  if i==3 then return {title='Also hidden',questID=702,isHeader=false,isHidden=true} end
  if i==1 then return {title='Zone',isHeader=true} end
  if i==2 then return {title='Hidden',questID=700,isHeader=false,isHidden=true} end
  if i==4 then return {title='Visible',questID=701,isHeader=false} end
  return {title='Repeated',questID=701,isHeader=false}
end
assert(select(2,addon.quests:ZoneInventory())==true,
  'legitimate hidden or duplicate rows do not falsely report incomplete')
issecretvalue=nil

-- A quest before any recognized header belongs to the explicitly unknown zone.
C_QuestLog.GetNumQuestLogEntries=function() return 1, 1 end
C_QuestLog.GetInfo=function() return {questID=701,title='Unsorted',isHeader=false} end
zones=addon.quests:ZoneInventory()
assert(#zones==1 and zones[1].name=='Unknown Zone' and zones[1].quests[1].questID==701)

-- Broken/absent APIs and untrusted input fail closed; finite enumeration.
C_QuestLog.GetNumQuestLogEntries=function() return 1000000 end
assert(#addon.quests:ZoneInventory()==0)
C_QuestLog=nil
assert(#addon.quests:ZoneInventory()==0)
C_QuestLog={GetNumQuestLogEntries=function() return 1 end}
assert(#addon.quests:ZoneInventory()==0)

-- A legacy client lacking C_QuestLog.GetInfo can still expose its native log.
C_QuestLog=nil
GetNumQuestLogEntries=function() return 2, 1 end
GetQuestLogTitle=function(i)
  if i==1 then return 'Lac Modan', 0, nil, true, false end
  return 'A la recherche', 10, nil, false, false, 1, nil, 801
end
zones=addon.quests:ZoneInventory()
assert(#zones==1 and zones[1].name=='Lac Modan' and zones[1].quests[1].questID==801)
GetNumQuestLogEntries=nil
GetQuestLogTitle=nil
print('quest zone inventory tests passed')
