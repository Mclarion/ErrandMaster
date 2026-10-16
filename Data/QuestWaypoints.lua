-- v0.6 candidate: game-supplied next waypoint for an active quest only.
-- A waypoint is neither an NPC spawn point nor a traversable walking route.
local _, addon = ...
addon.questWaypoints = {}
local waypoints = addon.questWaypoints
local function plain(value)
  local ok, safe = pcall(function()
    if type(issecretvalue) == "function" and issecretvalue(value) then return false end
    if type(value) == "table" and type(issecrettable) == "function" and issecrettable(value) then return false end
    return true
  end)
  return ok and safe
end
local function integer(value)
  return plain(value) and type(value) == "number" and value == value and
    value >= 1 and value <= 1000000000 and value % 1 == 0
end
local function coordinate(value)
  return plain(value) and type(value) == "number" and value == value and value >= 0 and value <= 1
end
local function method(name)
  if not plain(C_QuestLog) or type(C_QuestLog) ~= "table" then return end
  local ok, value = pcall(function() return C_QuestLog[name] end)
  if ok and plain(value) and type(value) == "function" then return value end
end
local function validText(value)
  return plain(value) and type(value) == "string" and #value >= 1 and
    #value <= 80 and value:match("%S") and not value:find("[%c|]")
end
function waypoints:ForQuest(questID, requestedMap)
  if not integer(questID) or not integer(requestedMap) then return end
  local getIndex, getInfo = method("GetLogIndexForQuestID"), method("GetInfo")
  if not getIndex or not getInfo then return end
  local ok, index = pcall(getIndex, questID)
  if not ok or not integer(index) then return end
  local found, info = pcall(getInfo, index)
  if not found or not plain(info) or type(info) ~= "table" then return end
  local read, id, title, header = pcall(function()
    return info.questID, info.title, info.isHeader
  end)
  if not read or not plain(id) or id ~= questID or
      not validText(title) or not plain(header) or header ~= false then return end
  local x, y, projected
  local getNext = method("GetNextWaypoint")
  if getNext then
    local resolved, map, nextX, nextY = pcall(getNext, questID)
    if resolved and integer(map) and map == requestedMap and
        coordinate(nextX) and coordinate(nextY) then
      x, y = nextX, nextY
    end
  end
  if not x then
    local onMap = method("GetNextWaypointForMap")
    if not onMap then return end
    local resolved, nextX, nextY = pcall(onMap, questID, requestedMap)
    if not resolved or not coordinate(nextX) or not coordinate(nextY) then return end
    x, y, projected = nextX, nextY, true
  end
  local text
  local getText = method("GetNextWaypointText")
  if getText then
    local succeeded, value = pcall(getText, questID)
    if succeeded and validText(value) then text = value end
  end
  return {questID=questID,title=title,mapID=requestedMap,x=x,y=y,
    text=text,source="game-next-waypoint",projected=projected == true}
end
