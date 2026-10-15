local _, addon = ...
addon.worldMap = {}
local overlay = addon.worldMap
local ROWS = 6
local MAX_PINS = 120

local function callable(object, name)
  local ok, value = pcall(function() return object[name] end)
  return ok and type(value) == "function" and value or nil
end

local function available(value)
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

local function inCombat()
  if type(InCombatLockdown) ~= "function" then return false end
  local ok, locked = pcall(InCombatLockdown)
  return not ok or not available(locked) or locked ~= false and locked ~= nil
end

local function normalized(n)
  return type(n) == "number" and available(n) and n == n and n >= 0 and n <= 1
end

local function mapID(n)
  return type(n) == "number" and available(n) and n >= 1 and n % 1 == 0
end

local function safeMap()
  local ok, map = pcall(function() return WorldMapFrame end)
  if not ok or not available(map) then return nil end
  if not map or not callable(map, "AddDataProvider") or
    not callable(map, "GetCanvas") or not callable(map, "GetMapID") or
    not callable(map, "AddCanvasClickHandler") then return nil end
  return map
end

local function hidePins(self)
  for _, pin in ipairs(self.pins or {}) do pin:Hide() end
end

function overlay:OnAdded(map)
  self.map = map
  self:Refresh()
end

function overlay:OnRemoved(map)
  if self.map == map then
    hidePins(self)
    if self.questPanel then self.questPanel:Hide() end
    self.map = nil
  end
end

function overlay:RemoveAllData()
  hidePins(self)
  if self.questPanel then self.questPanel:Hide() end
end
function overlay:RefreshAllData() self:Refresh() end
function overlay:OnMapChanged() self:Refresh() end
function overlay:OnCanvasSizeChanged() self:Refresh() end
function overlay:OnCanvasScaleChanged() end -- Canvas children scale with their parent.
function overlay:OnCanvasPanChanged() end
function overlay:OnMapInsetSizeChanged() end
function overlay:OnMapInsetScaleChanged() end
function overlay:OnMapInsetPanChanged() end
function overlay:OnMapInsetMouseEnter() end
function overlay:OnMapInsetMouseLeave() end
function overlay:OnGlobalAlphaChanged() end
function overlay:OnShow() self:Refresh() end
function overlay:OnHide() end
function overlay:SignalEvent() end

local function newPin(canvas)
  local pin = CreateFrame("Frame", nil, canvas)
  pin:SetSize(14, 14)
  if callable(pin, "EnableMouse") then pin:EnableMouse(false) end
  local icon = pin:CreateTexture(nil, "OVERLAY")
  icon:SetAllPoints(pin)
  pin.icon = icon
  local label = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("TOP", pin, "BOTTOM", 0, -2)
  pin.label = label
  return pin
end
local function shortName(name)
  if type(name) ~= "string" or not available(name) then return end
  if #name <= 24 then return name end
  local cut = 24
  while cut > 0 do
    local nextByte = name:byte(cut + 1)
    if not nextByte or nextByte < 128 or nextByte > 191 then break end
    cut = cut - 1
  end
  return name:sub(1, cut) .. "..."
end

local function addPin(self, canvas, index, entry, kind, width, height)
  if index >= MAX_PINS then return index end
  local ok, id, x, y, name, yards = pcall(function()
    local point = entry.item or entry.errand or entry.location or entry
    if not available(point) or type(point) ~= "table" then return end
    return point.mapID or entry.mapID, point.x or entry.x, point.y or entry.y,
      point.name, point.directYards
  end)
  if not ok or not mapID(id) or id ~= self.currentMapID or
    not normalized(x) or not normalized(y) then return index end
  index = index + 1
  local pin = self.pins[index]
  if not pin then
    pin = newPin(canvas)
    self.pins[index] = pin
  elseif pin.canvas ~= canvas then
    if callable(pin, "SetParent") then pin:SetParent(canvas)
    else pin:Hide(); pin = newPin(canvas); self.pins[index] = pin end
  end
  pin.canvas = canvas
  pin:ClearAllPoints()
  pin:SetPoint("CENTER", canvas, "TOPLEFT", x * width, -y * height)
  if kind == "service" then pin.icon:SetColorTexture(.2, .75, 1, .9)
  else pin.icon:SetColorTexture(1, .7, .1, .95) end
  local title = shortName(name) or kind
  local description = kind == "service" and ("Observed: " .. title) or
    (index .. ". " .. title)
  if kind == "route" and type(yards) == "number" and available(yards) and
      yards == yards and yards >= 0 and yards <= 10000000 then
    description = description .. string.format(" ~%.0f yd direct", yards)
  end
  pin.label:SetText(description)
  pin:Show()
  return index
end

local function createPanel(self, map)
  if self.questPanel then
    if self.questPanelMap ~= map then
      self.questPanel:Hide()
      self.questPanel:SetParent(map)
      self.questPanel:ClearAllPoints()
      self.questPanel:SetPoint("TOPRIGHT", map, "TOPRIGHT", -35, -95)
      self.questPanelMap = map
    end
    return
  end
  local panel = CreateFrame("Frame", nil, map)
  panel:SetSize(202, 182)
  panel:SetPoint("TOPRIGHT", map, "TOPRIGHT", -35, -95)
  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
  title:SetText("ErrandMaster: map quests")
  self.questPanel = panel
  self.questPanelMap = map
  self.questRows = {}
  for i = 1, ROWS do
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(192, 21)
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -6 - i * 22)
    button:SetScript("OnClick", function(row)
      if inCombat() or not self.map or not self.currentMapID or
        not addon.quests or
        (not callable(addon.quests, "Add") and type(ChatFrame_OpenChat) ~= "function") then return end
      if row.mapID ~= self.currentMapID then return end
      local ok, activeID = pcall(function() return self.map:GetMapID() end)
      if not ok or not mapID(activeID) or activeID ~= row.mapID then return end
      if addon.quests and callable(addon.quests, "Add") then
        local added, result = pcall(addon.quests.Add, addon.quests, row.questID, row.mapID)
        if added and result and callable(addon, "Refresh") then pcall(addon.Refresh, addon) end
      elseif type(ChatFrame_OpenChat) == "function" then
        pcall(ChatFrame_OpenChat, "/em quest " .. row.questID)
      end
    end)
    self.questRows[i] = button
  end
  local prev = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  prev:SetSize(76, 21)
  prev:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, 2)
  prev:SetText("< Previous")
  prev:SetScript("OnClick", function()
    self.questPage = math.max(1, (self.questPage or 1) - 1)
    self:Refresh()
  end)
  local nextButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  nextButton:SetSize(76, 21)
  nextButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 2)
  nextButton:SetText("Next >")
  nextButton:SetScript("OnClick", function()
    self.questPage = (self.questPage or 1) + 1
    self:Refresh()
  end)
  self.questPrev, self.questNext = prev, nextButton
end

local function updateQuests(self, map)
  if not addon.quests or not callable(addon.quests, "OnMap") or
    (not callable(addon.quests, "Add") and type(ChatFrame_OpenChat) ~= "function") then
    if self.questPanel then self.questPanel:Hide() end
    return
  end
  local ok, list = pcall(addon.quests.OnMap, addon.quests, self.currentMapID)
  if not ok or type(list) ~= "table" or not available(list) then
    if self.questPanel then self.questPanel:Hide() end
    return
  end
  local quests = {}
  for _, quest in ipairs(list) do
    local valid, id, title, idMap = pcall(function() return quest.questID, quest.title, quest.mapID end)
    if valid and mapID(id) and mapID(idMap) and idMap == self.currentMapID and
      type(title) == "string" and available(title) then
      quests[#quests+1] = {questID=id, mapID=idMap, title=title}
    end
  end
  if #quests == 0 then
    if self.questPanel then self.questPanel:Hide() end
    return
  end
  createPanel(self, map)
  local pageCount = math.ceil(#quests / ROWS)
  self.questPage = math.min(self.questPage or 1, pageCount)
  for i, row in ipairs(self.questRows) do
    local quest = quests[(self.questPage-1) * ROWS + i]
    if quest then
      row.questID, row.mapID = quest.questID, quest.mapID
      row:SetText(quest.title)
      row:Show()
    else
      row.questID, row.mapID = nil, nil
      row:Hide()
    end
  end
  if self.questPage > 1 then self.questPrev:Show() else self.questPrev:Hide() end
  if self.questPage < pageCount then self.questNext:Show() else self.questNext:Hide() end
  self.questPanel:Show()
end

function overlay:Refresh()
  local map = self.map
  if not map or inCombat() or not available(map) then
    self:RemoveAllData()
    return false
  end
  local ok, canvas, id = pcall(function() return map:GetCanvas(), map:GetMapID() end)
  if not ok or not available(canvas) or not mapID(id) then
    self:RemoveAllData()
    return false
  end
  local sizeOK, width, height = pcall(function() return canvas:GetWidth(), canvas:GetHeight() end)
  if not sizeOK or type(width) ~= "number" or type(height) ~= "number" or
    not available(width) or not available(height) or width ~= width or height ~= height or
    width <= 0 or height <= 0 or width > 10000000 or height > 10000000 then
    self:RemoveAllData()
    return false
  end
  if id ~= self.currentMapID then self.questPage = 1 end
  self.currentMapID = id
  self.pins = self.pins or {}
  local used = 0
  if callable(addon, "Plan") then
    local planned, entries = pcall(addon.Plan, addon, self.currentMapID)
    if planned and type(entries) == "table" and available(entries) then
      for _, entry in ipairs(entries) do
        used = addPin(self, canvas, used, entry, "route", width, height)
      end
    end
  end
  if addon.locations and callable(addon.locations, "All") then
    local observed, entries = pcall(addon.locations.All, addon.locations)
    if observed and type(entries) == "table" and available(entries) then
      for _, entry in ipairs(entries) do
        used = addPin(self, canvas, used, entry, "service", width, height)
      end
    end
  end
  for i = used+1, #self.pins do self.pins[i]:Hide() end
  updateQuests(self, map)
  return true
end

function overlay:OnCanvasClick(map, button, x, y)
  if map ~= self.map or button ~= "LeftButton" or inCombat() or
    not normalized(x) or not normalized(y) or
    not addon.errands or not callable(addon.errands, "Add") or
    type(IsShiftKeyDown) ~= "function" then return false end
  local shifted, isDown = pcall(IsShiftKeyDown)
  if not shifted or not available(isDown) or isDown ~= true then return false end
  local ok, id = pcall(function() return map:GetMapID() end)
  if not ok or not mapID(id) then return false end
  local added, item = pcall(addon.errands.Add, addon.errands,
    {name="Map errand", category="Custom", scope="character", origin="manual", mapID=id, x=x, y=y})
  if not added or not item then return false end
  if callable(addon, "Refresh") then pcall(addon.Refresh, addon) end
  self:Refresh()
  return true
end

function overlay:Attach()
  if inCombat() then return false end
  local map = safeMap()
  if not map then return false end
  self.providerMaps = self.providerMaps or setmetatable({}, {__mode="k"})
  self.clickMaps = self.clickMaps or setmetatable({}, {__mode="k"})
  if self.map == map and self.clickMaps[map] then return true end
  if self.clickMaps[map] then
    self.map = map
    self:Refresh()
    return true
  end
  if not self.providerMaps[map] then
    local ok = pcall(map.AddDataProvider, map, self)
    if not ok then return false end
    self.providerMaps[map] = true
  end
  self.map = map
  if not self.clickHandler then
    self.clickHandler = function(canvasMap, button, x, y)
      return self:OnCanvasClick(canvasMap, button, x, y)
    end
  end
  local clicked = pcall(map.AddCanvasClickHandler, map, self.clickHandler)
  if clicked then self.clickMaps[map] = true end
  self:Refresh()
  return clicked
end

function overlay:Open()
  if inCombat() then return false end
  -- The native map may be load-on-demand; opening it can create WorldMapFrame.
  if not safeMap() then
    if type(OpenWorldMap) == "function" and pcall(OpenWorldMap) then
      self:Attach() -- ADDON_LOADED can attach later if creation is asynchronous.
      return true
    end
    if type(ToggleWorldMap) == "function" and pcall(ToggleWorldMap) then
      self:Attach()
      return true
    end
    return false
  end
  if not self:Attach() then return false end
  local map = self.map
  local showing, shown = pcall(function() return map:IsShown() end)
  if showing and shown then return true end
  if type(OpenWorldMap) == "function" then
    if pcall(OpenWorldMap) then self:Refresh(); return true end
  end
  if type(ToggleWorldMap) == "function" then
    if pcall(ToggleWorldMap) then self:Refresh(); return true end
  end
  if callable(map, "Show") and pcall(map.Show, map) then
    self:Refresh()
    return true
  end
  return false
end
