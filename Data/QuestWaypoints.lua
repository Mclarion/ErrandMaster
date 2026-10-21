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
-- A map POI is the game's quest pin, not an exact objective/spawn location.
-- C_AreaPoiInfo records are unrelated area features: never match by name/ID.
function waypoints:ForQuest(questID, requestedMap)
  if not integer(questID) or (requestedMap ~= nil and not integer(requestedMap)) then return end
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
  local x, y, mapID, projected
  local getNext = method("GetNextWaypoint")
  if getNext then
    local resolved, map, nextX, nextY = pcall(getNext, questID)
    if resolved and integer(map) and (requestedMap == nil or map == requestedMap) and
        coordinate(nextX) and coordinate(nextY) then
      mapID, x, y = map, nextX, nextY
    end
  end
  if not x and requestedMap then
    local onMap = method("GetNextWaypointForMap")
    if onMap then
      local resolved, nextX, nextY = pcall(onMap, questID, requestedMap)
      if resolved and coordinate(nextX) and coordinate(nextY) then
        mapID, x, y, projected = requestedMap, nextX, nextY, true
      end
    end
  end
  if x then
    local text
    local getText = method("GetNextWaypointText")
    if getText then
      local succeeded, value = pcall(getText, questID)
      if succeeded and validText(value) then text = value end
    end
    return {questID=questID,title=title,mapID=mapID,x=x,y=y,
      text=text,source="game-next-waypoint",projected=projected == true}
  end
  if not requestedMap then return end
  local getPOIs = method("GetQuestsOnMap")
  if not getPOIs then return end
  local succeeded, rows = pcall(getPOIs, requestedMap)
  if not succeeded or not plain(rows) or type(rows) ~= "table" then return end
  local counted, size = pcall(function() return #rows end)
  if not counted or not plain(size) or type(size) ~= "number" then return end
  for i = 1, math.min(size, 100) do
    local read, id, map, px, py, isStart = pcall(function()
      local row = rows[i]
      if not plain(row) or type(row) ~= "table" then return end
      return row.questID, row.mapID, row.x, row.y, row.isQuestStart
    end)
    if read and plain(id) and id == questID and plain(map) and map == requestedMap and
        coordinate(px) and coordinate(py) and plain(isStart) and isStart ~= true then
      return {questID=questID,title=title,mapID=requestedMap,x=px,y=py,
        source="active-quest-poi",areaTarget=true,projected=false}
    end
  end
end
