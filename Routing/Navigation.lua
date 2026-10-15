local _, addon = ...
addon.navigation = {}
local navigation = addon.navigation

function navigation:Clear()
  if self.handle and self.provider and type(self.provider.RemoveWaypoint) == "function" then
    pcall(self.provider.RemoveWaypoint, self.provider, self.handle)
  end
  self.handle, self.key, self.provider = nil, nil, nil
end

function navigation:Next(item)
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
  self:Clear()
  local ok, handle = pcall(provider.AddWaypoint, provider, item.mapID, item.x, item.y,
    {title = "ErrandMaster: " .. item.name, source = "ErrandMaster", persistent = false, crazy = true})
  if ok and handle then
    self.handle, self.key, self.provider = handle, key, provider
    return true
  end
  return false
end
