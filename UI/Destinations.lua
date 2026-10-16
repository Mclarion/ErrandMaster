local _, addon = ...
addon.destinations = {}
local destinations = addon.destinations
local ROWS, MAX_ITEMS = 8, 200

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

local function title(value)
  if not safe(value) or type(value) ~= "string" then return "Unnamed" end
  if #value <= 38 then return value end
  local cut = 38
  while cut > 0 do
    local byte = value:byte(cut + 1)
    if not byte or byte < 128 or byte > 191 then break end
    cut = cut - 1
  end
  return value:sub(1, cut) .. "..."
end

local function append(list, entries, deferred)
  if type(entries) ~= "table" or not safe(entries) then return end
  for i = 1, MAX_ITEMS do
    local ok, item = pcall(function() return entries[i] end)
    if not ok or item == nil then break end
    if type(item) == "table" and safe(item) then
      local read, name, map, x, y, yards, walkYards, walkStatus = pcall(function()
        return item.name, item.mapID, item.x, item.y, item.directYards,
          item.walkYards, item.walkStatus
      end)
      if read and safe(name) and safe(map) and safe(x) and safe(y) and safe(yards) and
          safe(walkYards) and safe(walkStatus) then
        local line = deferred and (walkStatus == "unknown-route" and
          "Unknown walking path: " or "Deferred: ") .. title(name) or
          (i .. ". " .. title(name))
        if number(x, 0, 1) and number(y, 0, 1) then
          line = line .. string.format(" (%.1f, %.1f)", x * 100, y * 100)
          if not deferred and number(walkYards, 0, 10000000) then
            line = line .. string.format(" %.0f yd observed", walkYards)
            if walkStatus == "partial-route" then
              line = line .. " (unverified connector)"
            end
          elseif not deferred and number(yards, 0, 10000000) then
            line = line .. string.format(" ~%.0f yd direct", yards)
          end
        elseif deferred and number(map, 1, 10000000) then
          line = line .. string.format(" (map %.0f)", map)
        end
        list[#list+1] = line
      end
    end
  end
end

function destinations:Create()
  if self.frame then return self.frame end
  local panel = CreateFrame("Frame", "ErrandMasterDestinations", UIParent, "BasicFrameTemplateWithInset")
  panel:SetSize(460, 278)
  panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetClampedToScreen(true)
  panel:SetScript("OnDragStart", function(frame) frame:StartMoving() end)
  panel:SetScript("OnDragStop", function(frame) frame:StopMovingOrSizing() end)
  local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  heading:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -30)
  heading:SetText("ErrandMaster destinations (straight-line estimates)")
  self.rows = {}
  for i = 1, ROWS do
    local row = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -48 - (i-1)*22)
    self.rows[i] = row
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
    self.page = math.min(math.max(1, math.ceil(#self.lines / ROWS)), self.page + 1)
    self:Render()
  end)
  self.prevButton, self.nextButton = prev, nextButton
  self.frame, self.page, self.lines = panel, 1, {}
  panel:Hide()
  return panel
end

function destinations:Render()
  if not self.frame then return end
  local pages = math.max(1, math.ceil(#self.lines / ROWS))
  self.page = math.min(math.max(self.page, 1), pages)
  for i, row in ipairs(self.rows) do
    local text = self.lines[(self.page-1)*ROWS+i]
    if text then row:SetText(text); row:Show() else row:SetText(""); row:Hide() end
  end
  if self.page > 1 then self.prevButton:Show() else self.prevButton:Hide() end
  if self.page < pages then self.nextButton:Show() else self.nextButton:Hide() end
end

function destinations:Refresh()
  if not self.frame then return false end
  local lines = {}
  if type(addon.Plan) == "function" then
    local ok, ordered, deferred = pcall(addon.Plan, addon)
    if ok then
      append(lines, ordered, false)
      append(lines, deferred, true)
    end
  end
  if #lines == 0 then lines[1] = "No destinations on this map." end
  self.lines = lines
  self:Render()
  return true
end

function destinations:Open()
  self:Create()
  self:Refresh()
  self.frame:Show()
  return true
end

function destinations:Toggle()
  if self.frame and self.frame:IsShown() then self.frame:Hide(); return false end
  return self:Open()
end