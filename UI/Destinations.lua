local _, addon = ...
addon.destinations = {}
local destinations = addon.destinations
local ROWS, MAX_ITEMS = 6, 200

local function safe(value)
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret then return false end
  end
  if type(value) == "table" and type(issecrettable) == "function" then
    local ok, secret = pcall(issecrettable, value)
    if not ok or secret then return false end
  end
  return true
end

local function number(value, low, high)
  return safe(value) and type(value) == "number" and value == value and
    value >= low and value <= high
end

local function validID(id)
  return number(id, 1, 1000000000) or
    (safe(id) and type(id) == "string" and #id > 0 and #id <= 128)
end

local function title(value, limit)
  if not safe(value) or type(value) ~= "string" then return "Unnamed" end
  value = value:gsub("|", "/"):gsub("[%c]", " ")
  limit = limit or 28
  if #value <= limit then return value end
  local cut = limit - 3
  while cut > 0 do
    local byte = value:byte(cut + 1)
    if not byte or byte < 128 or byte > 191 then break end
    cut = cut - 1
  end
  return value:sub(1, cut) .. "..."
end

local function entry(item, kind, index, activeID, nextID)
  if type(item) ~= "table" or not safe(item) then return end
  local ok, id, name, map, x, y, yards, walkYards, status, completed,
    nearby, flight, favorite = pcall(function()
      return item.id, item.name, item.mapID, item.x, item.y,
        item.directYards, item.walkYards, item.walkStatus, item.completed,
        item.nearbyZoneCandidate, item.taxiFlightNode, item.favorite
    end)
  if not ok or not safe(id) or not safe(name) or not safe(map) or
      not safe(x) or not safe(y) or not safe(yards) or not safe(walkYards) or
      not safe(status) or not safe(completed) or not safe(nearby) or
      not safe(flight) or not safe(favorite) then return end
  if id ~= nil and not validID(id) then return end
  local label = kind == "done" and "Done" or
    (id and id == activeID and "Current" or
      (kind == "deferred" and (status == "unknown-route" and "Unknown path" or "Deferred") or
        (id and id == nextID and "Next" or "Stop")))
  local prefix = kind == "ordered" and (index .. ". " .. label .. ": ") or (label .. ": ")
  local location = "location unknown"
  if number(x, 0, 1) and number(y, 0, 1) then
    location = string.format("%.1f, %.1f", x * 100, y * 100)
  elseif number(map, 1, 10000000) then
    location = string.format("map %.0f; location unknown", map)
  end
  local evidence
  if kind == "done" then
    evidence = "Completed; " .. location
  elseif kind == "deferred" then
    evidence = location .. "; route unknown"
    if type(nearby) == "table" then
      local read, nearbyName, zone, distance = pcall(function()
        return nearby.name, nearby.zoneName, nearby.directYards
      end)
      if read and safe(nearbyName) and safe(zone) and number(distance, 0, 10000000) then
        evidence = title(zone, 14) ..
          string.format(" ~%.0f yd direct; route unknown", distance)
      end
    end
    if type(flight) == "string" and #flight <= 80 then
      evidence = "Fly: " .. title(flight, 20) .. "; walk unknown"
    end
  elseif status == "known-route" and number(walkYards, 0, 10000000) then
    evidence = location .. string.format("; %.0f yd observed path", walkYards)
  elseif status == "partial-route" and number(walkYards, 0, 10000000) then
    evidence = location .. string.format("; %.0f yd observed; connector unknown", walkYards)
  elseif number(yards, 0, 10000000) then
    evidence = location .. string.format("; ~%.0f yd direct estimate", yards)
  else
    evidence = location .. "; route unknown"
  end
  return {id=id, completed=kind == "done" or completed == true,
    favorite=favorite == true,
    text=prefix .. (favorite == true and "[Fav] " or "") .. title(name, 29) .. "\n" .. evidence}
end

local function append(list, entries, kind, seen, activeID, nextID)
  if type(entries) ~= "table" or not safe(entries) then return end
  for i = 1, MAX_ITEMS do
    local ok, item = pcall(function() return entries[i] end)
    if not ok or item == nil then break end
    local row = entry(item, kind, i, activeID, nextID)
    if row and (not row.id or not seen[row.id]) then
      list[#list+1] = row
      if row.id then seen[row.id] = true end
    end
  end
end

function destinations:Change(action, rowIndex)
  local visible = self.visible and self.visible[rowIndex]
  local id = visible and visible.id
  if not id or not addon.errands or type(addon.errands.Get) ~= "function" then return end
  local ok, item = pcall(addon.errands.Get, addon.errands, id)
  if not ok or not item then return end
  if action == "activate" then
    if type(addon.ActivateTarget) == "function" then
      pcall(addon.ActivateTarget, addon, id) -- Parent refreshes and updates navigation.
    end
    return
  end
  local changed = pcall(function()
    if action == "done" then
      addon.errands:Complete(id, not item.completed)
    elseif action == "favorite" then
      addon.errands:Update(id, {favorite=not (item.favorite == true)})
    elseif action == "remove" then
      addon.errands:Delete(id)
    elseif action == "up" or action == "down" then
      local all = addon.errands:All()
      for i, other in ipairs(all) do
        if other.id == id then
          local target = i + (action == "up" and -1 or 1)
          if target < 1 or target > #all then return end
          addon.errands:Reorder(id, target)
          addon.db.data.settings.optimize = false
          return
        end
      end
      return
    else return end
  end)
  if changed and type(addon.Refresh) == "function" then addon:Refresh() end
end

function destinations:Create()
  if self.frame then return self.frame end
  local panel = CreateFrame("Frame", "ErrandMasterDestinations", UIParent, "BasicFrameTemplateWithInset")
  panel:SetSize(328, 390)
  panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -130)
  if addon.windowPosition then addon.windowPosition:Restore(panel, "targets") end
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetClampedToScreen(true)
  panel:SetScript("OnDragStart", function(frame)
    frame:StartMoving()
    frame.errandMoving = true
  end)
  panel:SetScript("OnDragStop", function(frame)
    if not frame.errandMoving then return end
    frame:StopMovingOrSizing()
    frame.errandMoving = nil
    if addon.windowPosition then addon.windowPosition:Save(frame, "targets") end
  end)
  panel:SetScript("OnHide", function(frame)
    if frame.errandMoving then
      frame:StopMovingOrSizing(); frame.errandMoving = nil
      if addon.windowPosition then addon.windowPosition:Save(frame, "targets") end
    end
  end)
  local closeButton=panel.CloseButton
  if (type(closeButton)=="table" or type(closeButton)=="userdata") and
      type(closeButton.HookScript)=="function" then
    closeButton:HookScript("OnClick", function()
      if addon.db and addon.db.data then
        addon.db.data.settings.showDestinations = false
      end
    end)
  end
  panel.TitleText:SetText("ErrandMaster targets")
  local icon = panel:CreateTexture(nil, "ARTWORK")
  icon:SetSize(24, 24)
  icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -3)
  icon:SetTexture("Interface\\AddOns\\ErrandMaster\\Textures\\PackLogo.blp")
  local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -31)
  heading:SetText("Order and evidence (not a walking route)")
  self.rows, self.controls, self.visible = {}, {}, {}
  local labels = {{"Go", "activate", 46}, {"Done", "done", 52},
    {"Remove", "remove", 54}, {"Up", "up", 35}, {"Down", "down", 43},
    {"Fav", "favorite", 44}}
  for i = 1, ROWS do
    local top = -51 - (i-1)*49
    local row = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, top)
    row:SetWidth(292)
    row:SetHeight(28)
    row:SetJustifyH("LEFT")
    row:SetJustifyV("TOP")
    self.rows[i], self.controls[i] = row, {}
    local x = 17
    for _, spec in ipairs(labels) do
      local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
      button:SetSize(spec[3], 19)
      button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, top-27)
      button:SetText(spec[1])
      local action = spec[2]
      if action == "activate" then
        local waypoint = button:CreateTexture(nil, "ARTWORK")
        waypoint:SetSize(14, 14)
        waypoint:SetPoint("LEFT", button, "LEFT", 2, 0)
        waypoint:SetTexture("Interface\\AddOns\\ErrandMaster\\Textures\\PackWaypoint.blp")
        button.icon = waypoint
      end
      button:SetScript("OnClick", function() self:Change(action, i) end)
      self.controls[i][action] = button
      x = x + spec[3] + 4
    end
  end
  local prev = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  prev:SetSize(82, 22)
  prev:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 13)
  prev:SetText("< Previous")
  prev:SetScript("OnClick", function() self.page = math.max(1, self.page - 1); self:Render() end)
  local nextButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  nextButton:SetSize(82, 22)
  nextButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 13)
  nextButton:SetText("Next >")
  nextButton:SetScript("OnClick", function()
    self.page = math.min(math.max(1, math.ceil(#self.entries / ROWS)), self.page + 1)
    self:Render()
  end)
  self.prevButton, self.nextButton = prev, nextButton
  self.frame, self.page, self.lines, self.entries = panel, 1, {}, {}
  panel:Hide()
  return panel
end

function destinations:Render()
  if not self.frame then return end
  local pages = math.max(1, math.ceil(#self.entries / ROWS))
  self.page = math.min(math.max(self.page, 1), pages)
  local positions, count = {}, 0
  if addon.errands and type(addon.errands.All) == "function" then
    local ok, all = pcall(addon.errands.All, addon.errands)
    if ok and type(all) == "table" and safe(all) then
      for i, item in ipairs(all) do
        if safe(item) and type(item) == "table" then
          local read, id = pcall(function() return item.id end)
          if read and safe(id) and id ~= nil then positions[id] = i end
        end
      end
      count = #all
    end
  end
  for i, row in ipairs(self.rows) do
    local item = self.entries[(self.page-1)*ROWS+i]
    self.visible[i] = item
    local controls = self.controls[i]
    if item then
      row:SetText(item.text); row:Show()
      for action, button in pairs(controls) do
        if not item.id or
            (action == "activate" and item.completed) or
            (action == "up" and (not positions[item.id] or positions[item.id] <= 1)) or
            (action == "down" and (not positions[item.id] or positions[item.id] >= count)) then
          button:Hide()
        else
          if action == "done" then button:SetText(item.completed and "Reopen" or "Done") end
          if action == "favorite" then button:SetText(item.favorite and "Unfav" or "Fav") end
          button:Show()
        end
      end
    else
      row:SetText(""); row:Hide()
      for _, button in pairs(controls) do button:Hide() end
    end
  end
  if self.page > 1 then self.prevButton:Show() else self.prevButton:Hide() end
  if self.page < pages then self.nextButton:Show() else self.nextButton:Hide() end
end

function destinations:Refresh()
  if not self.frame then return false end
  local entries, seen = {}, {}
  if type(addon.Plan) == "function" then
    local ok, ordered, deferred = pcall(addon.Plan, addon)
    if ok then
      local activeID, nextID
      if type(addon.ActiveTarget) == "function" then
        local found, active = pcall(addon.ActiveTarget, addon, ordered, deferred)
        if found and safe(active) and type(active) == "table" then
          local read, id = pcall(function() return active.id end)
          if read and validID(id) then activeID = id end
        end
      end
      if type(ordered) == "table" and safe(ordered) then
        local foundInOrder = false
        for i = 1, math.min(#ordered, MAX_ITEMS) do
          local item = ordered[i]
          if type(item) == "table" and safe(item) then
            local read, id = pcall(function() return item.id end)
            if read and safe(id) and id == activeID then
              foundInOrder = true
              local following = ordered[i+1]
              if type(following) == "table" and safe(following) then
                local nextOK, followingID = pcall(function() return following.id end)
                if nextOK and validID(followingID) then nextID = followingID end
              end
              break
            end
          end
        end
        if not foundInOrder and activeID and type(ordered[1]) == "table" and safe(ordered[1]) then
          local read, firstID = pcall(function() return ordered[1].id end)
          if read and validID(firstID) and firstID ~= activeID then nextID = firstID end
        end
      end
      append(entries, ordered, "ordered", seen, activeID, nextID)
      append(entries, deferred, "deferred", seen, activeID, nextID)
    end
  end
  if addon.errands and type(addon.errands.All) == "function" then
    local ok, all = pcall(addon.errands.All, addon.errands)
    if ok and type(all) == "table" and safe(all) then
      local completed = {}
      for _, item in ipairs(all) do
        if safe(item) and type(item) == "table" then
          local read, done = pcall(function() return item.completed end)
          if read and safe(done) and done == true then completed[#completed+1] = item end
        end
      end
      append(entries, completed, "done", seen)
    end
  end
  if #entries == 0 then entries[1] = {text="No targets to show."} end
  self.entries, self.lines = entries, {}
  for i, item in ipairs(entries) do self.lines[i] = item.text end
  self:Render()
  return true
end

function destinations:Open()
  self:Create()
  self:Refresh()
  self.frame:Show()
  if addon.db and addon.db.data then addon.db.data.settings.showDestinations = true end
  return true
end

function destinations:Toggle()
  if self.frame and self.frame:IsShown() then
    self.frame:Hide()
    if addon.db and addon.db.data then addon.db.data.settings.showDestinations = false end
    return false
  end
  return self:Open()
end
function destinations:Restore()
  if addon.db and addon.db.data and
      addon.db.data.settings.showDestinations == false then return false end
  return self:Open()
end