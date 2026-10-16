local _, addon = ...
addon.quests = {}
local quests = addon.quests

local function plain(value)
  local ok, allowed = pcall(function()
    if issecretvalue and issecretvalue(value) then return false end
    if type(value) == "table" and issecrettable and issecrettable(value) then return false end
    return true
  end)
  return ok and allowed
end
local function integer(value)
  return plain(value) and type(value) == "number" and value == value and
    value >= 1 and value <= 1000000000 and value % 1 == 0
end
local function coordinate(value)
  return plain(value) and type(value) == "number" and value == value and
    value >= 0 and value <= 1
end

function quests:Invalidate()
  self.mapID, self.list = nil, nil
end

-- Include a saved active quest's next native waypoint when it has no map POI.
function quests:AppendSavedWaypoints(mapID, list)
  if not addon.questWaypoints or type(addon.questWaypoints.ForQuest) ~= "function" or
      not addon.errands or type(addon.errands.All) ~= "function" then return list end
  local ok, errands = pcall(addon.errands.All, addon.errands)
  if not ok or not plain(errands) or type(errands) ~= "table" then return list end
  local seen = {}
  for _, point in ipairs(list) do seen[point.questID] = true end
  for i = 1, 200 do
    local read, item = pcall(function() return errands[i] end)
    if not read or item == nil then break end
    local fetched, id = pcall(function() return item.questID end)
    if fetched and integer(id) and not seen[id] then
      local resolved, point = pcall(addon.questWaypoints.ForQuest,
        addon.questWaypoints, id, mapID)
      if resolved and plain(point) and type(point) == "table" and
          coordinate(point.x) and coordinate(point.y) then
        list[#list+1] = point
        seen[id] = true
      end
    end
  end
  return list
end

-- Native map POIs are only candidates; the quest must also be in this character's log.
function quests:OnMap(mapID)
  if not integer(mapID) then return {} end
  if self.mapID == mapID and self.list then return self.list end
  local list = {}
  self.mapID, self.list = mapID, list
  if not plain(C_QuestLog) or type(C_QuestLog) ~= "table" then
    return self:AppendSavedWaypoints(mapID, list)
  end
  local ok, getPOIs, getIndex, getInfo = pcall(function()
    return C_QuestLog.GetQuestsOnMap, C_QuestLog.GetLogIndexForQuestID, C_QuestLog.GetInfo
  end)
  if not ok or not plain(getPOIs) or not plain(getIndex) or not plain(getInfo) or
      type(getPOIs) ~= "function" or type(getIndex) ~= "function" or
      type(getInfo) ~= "function" then return self:AppendSavedWaypoints(mapID, list) end
  local success, rows = pcall(getPOIs, mapID)
  if not success or not plain(rows) or type(rows) ~= "table" then
    return self:AppendSavedWaypoints(mapID, list)
  end
  local lengthOK, count = pcall(function() return #rows end)
  if not lengthOK or not plain(count) or type(count) ~= "number" then
    return self:AppendSavedWaypoints(mapID, list)
  end
  local seen = {}
  for i = 1, math.min(count, 100) do
    local read, id, place, x, y = pcall(function()
      local row = rows[i]
      if not plain(row) or type(row) ~= "table" then return end
      return row.questID, row.mapID, row.x, row.y
    end)
    if read and integer(id) and plain(place) and place == mapID and coordinate(x) and
        coordinate(y) and not seen[id] then
      local indexed, index = pcall(getIndex, id)
      if indexed and integer(index) then
        local infoOK, info = pcall(getInfo, index)
        local titleOK, title, infoID, header = pcall(function()
          if not plain(info) or type(info) ~= "table" then return end
          return info.title, info.questID, info.isHeader
        end)
        if infoOK and titleOK and plain(title) and type(title) == "string" and
            #title <= 80 and title:match("%S") and plain(infoID) and infoID == id and
            plain(header) and header == false then
          list[#list+1] = {questID=id, title=title, mapID=mapID, x=x, y=y,
            source="active-quest-poi"}
          seen[id] = true
        end
      end
    end
  end
  return self:AppendSavedWaypoints(mapID, list)
end

function quests:Add(questID, mapID)
  if not integer(questID) or not integer(mapID) then
    return nil, "Specify a valid quest ID and map ID."
  end
  local selected
  for _, item in ipairs(self:OnMap(mapID)) do
    if item.questID == questID then selected = item; break end
  end
  if not selected and addon.questWaypoints then
    selected = addon.questWaypoints:ForQuest(questID, mapID)
  end
  if not selected then return nil, "No active quest POI or next waypoint on that map." end
  for _, item in ipairs(addon.errands:All()) do
    if item.questID == questID then return nil, "Quest already in errands." end
  end
  local ok, added = pcall(addon.errands.Add, addon.errands, {
    name=selected.title, category="Quest", origin="manual", scope="character",
    questID=questID, mapID=mapID, x=selected.x, y=selected.y,
  })
  if not ok then return nil, "Could not add quest errand." end
  self:Invalidate()
  return added
end
