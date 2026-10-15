local addon = {}
local function load(path) assert(loadfile(path))("ErrandMaster", addon) end
ErrandMasterDB = nil
load("Core/Database.lua")
load("Core/Errands.lua")
load("Routing/RoutePlanner.lua")
addon.db:Initialize("Test-Realm")
local pois = {
  {questID=501, mapID=10, x=.2, y=.3},
  {questID=502, mapID=10, x=.7, y=.8},
  {questID=503, mapID=11, x=.4, y=.4},
  {questID=504, mapID=10, x=2, y=.4},
}
C_QuestLog = {
  GetQuestsOnMap=function(id) return id == 10 and pois or {} end,
  GetLogIndexForQuestID=function(id) if id == 501 or id == 503 or id == 504 then return id end end,
  GetInfo=function(index) return {questID=index, title="Quest " .. index, isHeader=false} end,
}
load("Data/Quests.lua")
local found = addon.quests:OnMap(10)
assert(#found == 1 and found[1].questID == 501 and found[1].title == "Quest 501")
local task = assert(addon.quests:Add(501, 10))
assert(task.questID == 501 and task.category == "Quest" and task.scope == "character")
assert(not addon.quests:Add(501, 10)) -- No duplicate task for the same active quest.
local route = addon.route:Plan(addon.errands:All(), 10, 0, 0, true, {}, found, 1000, 500)
assert(#route == 1 and route[1].questID == 501 and route[1].directYards)
assert(task.directYards == nil, "route estimates must not be persisted on errands")
pois[1].x = .4
addon.quests:Invalidate()
found = addon.quests:OnMap(10)
route = addon.route:Plan(addon.errands:All(), 10, 0, 0, true, {}, found, 1000, 500)
assert(route[1].x == .4 and task.x == .2, "quest destination must use current POI without mutating snapshot")
pois[1] = nil
addon.quests:Invalidate()
local ordered, deferred = addon.route:Plan(addon.errands:All(), 10, 0, 0, true, {}, addon.quests:OnMap(10), 1000, 500)
assert(#ordered == 0 and #deferred == 1 and deferred[1] == task, "stale quests must not route to old coordinates")
-- Physical map aspect ratio determines the order when world size is available.
local choices = {
  {id="a", name="A", mapID=10, x=.4, y=.1},
  {id="b", name="B", mapID=10, x=.1, y=.5},
}
local physical = addon.route:Plan(choices, 10, 0, 0, true, nil, nil, 1000, 100)
assert(physical[1].id == "b" and physical[1].directYards and physical[2].cumulativeYards > physical[1].directYards)
local fallback = addon.route:Plan(choices, 10, 0, 0, true, nil, nil)
assert(fallback[1].id == "a" and fallback[1].directYards == nil)
assert(choices[1].directYards == nil)
C_QuestLog.GetQuestsOnMap = function() return setmetatable({}, {__index=function() error("protected") end}) end
issecrettable = function(value) return getmetatable(value) ~= nil end
addon.quests:Invalidate()
assert(#addon.quests:OnMap(10) == 0)
issecrettable = function() return false end
local protectedID = {}
local checkedProtectedID = false
issecretvalue = function(value)
  if rawequal(value, protectedID) then checkedProtectedID = true; return true end
  return false
end
C_QuestLog.GetQuestsOnMap = function()
  return {{questID=501, mapID=10, x=.2, y=.3}}
end
C_QuestLog.GetInfo = function()
  return {questID=protectedID, title="Hidden", isHeader=false}
end
addon.quests:Invalidate()
assert(#addon.quests:OnMap(10) == 0 and checkedProtectedID,
  "check a protected quest-log ID before comparing it to a POI")
C_QuestLog = nil
addon.quests:Invalidate()
assert(#addon.quests:OnMap(10) == 0 and not addon.quests:Add(501, 10))
print("active quest and physical distance tests passed")
