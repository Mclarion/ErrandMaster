-- Passive, unprotected minimap control. Wire minimap:Attach() after db initialization.
local _, addon = ...
addon.minimap = {}
local control = addon.minimap
local DEFAULT_ANGLE = 45
local ICON = "Interface\\Icons\\INV_Misc_Map_01"

local function plain(value)
  local ok, safe = pcall(function()
    if type(issecretvalue) == "function" and issecretvalue(value) then return false end
    if type(value) == "table" and type(issecrettable) == "function" and issecrettable(value) then return false end
    return true
  end)
  return ok and safe
end

local function number(value, low, high)
  return plain(value) and type(value) == "number" and value == value and
    value >= low and value <= high
end

local function settings()
  local ok, value = pcall(function() return addon.db.data.settings end)
  if ok and plain(value) and type(value) == "table" then return value end
end

local function angle()
  local data = settings()
  local ok, value = pcall(function() return data and data.minimapAngle end)
  if ok and number(value, 0, 360) then return value end
  return DEFAULT_ANGLE
end

local function radius(map)
  local ok, width, height = pcall(function() return map:GetWidth(), map:GetHeight() end)
  if not ok or not number(width, 1, 10000) or not number(height, 1, 10000) then return end
  return math.max(width, height) / 2 + 10
end

local function place(button, map, degrees)
  local r = radius(map)
  if not r then return false end
  local radians = math.rad(degrees)
  local x, y = r * math.cos(radians), r * math.sin(radians)
  local ok = pcall(function()
    button:ClearAllPoints()
    button:SetPoint("CENTER", map, "CENTER", x, y)
  end)
  return ok
end

local function cursorAngle(map)
  local ok, getCursor = pcall(function() return GetCursorPosition end)
  if not ok or not plain(getCursor) or type(getCursor) ~= "function" then return end
  local valid, x, y = pcall(getCursor)
  if not valid or not number(x, -1000000, 1000000) or not number(y, -1000000, 1000000) then return end
  local centered, mx, my, scale = pcall(function()
    local centerX, centerY = map:GetCenter()
    return centerX, centerY, UIParent:GetEffectiveScale()
  end)
  if not centered or not number(mx, -1000000, 1000000) or
    not number(my, -1000000, 1000000) or not number(scale, .001, 100) then return end
  local dx, dy = x / scale - mx, y / scale - my
  local length = math.sqrt(dx * dx + dy * dy)
  if not number(length, .001, 2000000) then return end
  local degrees = math.deg(math.acos(math.max(-1, math.min(1, dx / length))))
  if dy < 0 then degrees = 360 - degrees end
  return degrees
end

function control:Attach()
  if self.button then return true end
  local ok, map, create = pcall(function() return Minimap, CreateFrame end)
  if not ok or not plain(map) or not map or not plain(create) or type(create) ~= "function" then return false end
  local ready, button = pcall(function()
    local item = create("Button", nil, map) -- no secure or minimap-button template
    item:SetSize(28, 28)
    if not place(item, map, angle()) then return end
    local icon = item:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(item)
    icon:SetTexture(ICON)
    item:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    item:RegisterForDrag("LeftButton")
    item:SetScript("OnMouseDown", function()
      -- If dragging did not generate a release click, do not swallow the next click.
      self.suppressClick = nil
    end)
    item:SetScript("OnClick", function(_, mouse)
      if self.suppressClick then self.suppressClick = nil; return end
      local target, method
      if mouse == "LeftButton" then target, method = addon.radial, "ShowSettings"
      elseif mouse == "RightButton" then target, method = addon.destinations, "Toggle" end
      local accessible, callback = pcall(function() return target and target[method] end)
      if accessible and plain(callback) and type(callback) == "function" then
        pcall(callback, target)
      end
    end)
    item:SetScript("OnDragStart", function()
      self.dragging = true
      self.moved = nil
    end)
    item:SetScript("OnUpdate", function()
      if not self.dragging then return end
      local degrees = cursorAngle(map)
      if degrees and place(item, map, degrees) then
        self.dragAngle = degrees
        self.moved = true
      end
    end)
    item:SetScript("OnDragStop", function()
      if not self.dragging then return end
      self.dragging = nil
      if not self.moved then return end
      self.suppressClick = true
      self.moved = nil
      local data = settings()
      if data and number(self.dragAngle, 0, 360) then
        pcall(function() data.minimapAngle = self.dragAngle end)
      end
    end)
    return item
  end)
  if not ready or not button then return false end
  self.button = button
  return true
end
