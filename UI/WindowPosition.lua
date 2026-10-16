local _, addon = ...
addon.windowPosition = {}
local position = addon.windowPosition

local function valid(value)
  return type(value) == "number" and value == value and value >= 0 and value <= 1
end

function position:Restore(frame, key)
  local settings = addon.db.data and addon.db.data.settings
  local saved = settings and settings.windowPositions and settings.windowPositions[key]
  if type(saved) ~= "table" or not valid(saved.x) or not valid(saved.y) then return false end
  local ok, width, height = pcall(function() return UIParent:GetWidth(), UIParent:GetHeight() end)
  if not ok or type(width) ~= "number" or type(height) ~= "number" or
      width <= 0 or height <= 0 then return false end
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", width*saved.x, height*saved.y)
  return true
end

function position:Save(frame, key)
  local settings = addon.db.data and addon.db.data.settings
  if not settings then return false end
  local ok, x, y, left, bottom, width, height = pcall(function()
    local x, y = frame:GetCenter()
    return x, y, UIParent:GetLeft(), UIParent:GetBottom(), UIParent:GetWidth(), UIParent:GetHeight()
  end)
  if not ok or type(width) ~= "number" or type(height) ~= "number" or
      width <= 0 or height <= 0 or type(x) ~= "number" or type(y) ~= "number" or
      type(left) ~= "number" or type(bottom) ~= "number" then return false end
  local nx, ny = (x-left)/width, (y-bottom)/height
  if not valid(nx) or not valid(ny) then return false end
  settings.windowPositions = settings.windowPositions or {}
  settings.windowPositions[key] = {x=nx, y=ny}
  return true
end
