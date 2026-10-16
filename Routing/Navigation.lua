local _, addon = ...
addon.navigation = {}
local navigation = addon.navigation

function navigation:Clear()
  if self.handle then
    if not self.provider or type(self.provider.RemoveWaypoint) ~= "function" then return false end
    local ok, result = pcall(self.provider.RemoveWaypoint, self.provider, self.handle)
    if not ok or result == false then return false end
  end
  self.handle, self.key, self.provider = nil, nil, nil
  return true
end

function navigation:Next(item)
  if self.paused then return false end
  local settings = addon.db.data and addon.db.data.settings
  local provider = settings and settings.useTomTom and TomTom
  local compatible = type(provider) == "table" and type(provider.AddWaypoint) == "function" and
    type(provider.RemoveWaypoint) == "function"
  local key = item and item.id .. ":" .. tostring(item.mapID) .. ":" ..
    tostring(item.x) .. ":" .. tostring(item.y) .. ":" .. item.name
  if not compatible or not item or not item.mapID or not item.x or not item.y then
    self:Clear()
    return false
  end
  if self.handle and self.provider == provider and self.key == key then return true end
  if not self:Clear() then return false end
  local name = item.name:gsub("|", "/"):gsub("[%c]", " "):sub(1, 80)
  local evidence = item.walkStatus == "known-route" and "observed destination" or
    "direct target; walking path unverified"
  local ok, handle = pcall(provider.AddWaypoint, provider, item.mapID, item.x, item.y,
    {title = "ErrandMaster: " .. name .. " (" .. evidence .. ")",
      source = "ErrandMaster", persistent = false, crazy = true})
  if ok and handle then
    self.handle, self.key, self.provider = handle, key, provider
    return true
  end
  return false
end
