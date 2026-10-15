local _, addon = ...
addon.discovery = {}
local discovery = addon.discovery

local function safe(value)
  return value ~= nil and (not issecretvalue or not issecretvalue(value))
end
local function safeTable(value)
  return safe(value) and type(value) == "table" and
    (not issecrettable or not issecrettable(value))
end
local function available()
  if not safe(InCombatLockdown) or type(InCombatLockdown) ~= "function" then return false end
  local ok, combat = pcall(InCombatLockdown)
  return ok and safe(combat) and combat == false
end
local function position()
  local mapID, x, y = addon:Position()
  if not safe(mapID) or not safe(x) or not safe(y) then return end
  if type(mapID) ~= "number" or mapID < 1 or mapID % 1 ~= 0 or
      type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y or
      x < 0 or x > 1 or y < 0 or y > 1 then return end
  return mapID, x, y
end
local function record(category, name, mapID, x, y, source)
  local before = #addon.locations:All()
  local ok, item = pcall(addon.locations.Add, addon.locations, category, name, mapID, x, y, source)
  if not ok then return nil, tostring(item) end
  if #addon.locations:All() > before then addon:Refresh() end
  return item
end

-- Event locations are where the player opened a service, not verified NPC coordinates.
function discovery:HandleEvent(event)
  if not addon.db.data.settings.discoverServices or not available() then return false end
  local category, label
  if event == "MERCHANT_SHOW" then
    category, label = "Vendor", "Observed merchant access"
  elseif event == "MAIL_SHOW" then
    category, label = "Mailbox", "Observed mailbox access"
  elseif event == "AUCTION_HOUSE_SHOW" then
    category, label = "Auction House", "Observed auction access"
  else return false end
  local mapID, x, y = position()
  if not mapID then return false end
  local repair = false
  if event == "MERCHANT_SHOW" and safe(CanMerchantRepair) and
      type(CanMerchantRepair) == "function" then
    local ok, value = pcall(CanMerchantRepair)
    if not ok or not safe(value) then return false end
    repair = value == true
  end
  local item = record(category, label, mapID, x, y, "service-event")
  if not item then return false end
  if repair then record("Repair", "Observed repair access", mapID, x, y, "service-event") end
  return true
end

-- A player explicitly assigns the category. The POI API supplies coordinates,
-- but it does not prove that the name represents a service or NPC of that type.
function discovery:SaveGossipPoi(category)
  if not available() then return nil, "Unavailable in combat or combat state unknown." end
  if not safeTable(C_GossipInfo) then return nil, "Gossip POI API unavailable." end
  local readable, getID, getInfo = pcall(function()
    return C_GossipInfo.GetPoiForUiMapID, C_GossipInfo.GetPoiInfo
  end)
  if not readable or not safe(getID) or not safe(getInfo) or
      type(getID) ~= "function" or type(getInfo) ~= "function" then
    return nil, "Gossip POI API unavailable."
  end
  local mapID = position()
  if not mapID then return nil, "Player map position unavailable." end
  local ok, poiID = pcall(getID, mapID)
  if not ok or not safe(poiID) or type(poiID) ~= "number" or
      poiID < 1 or poiID % 1 ~= 0 then return nil, "No usable gossip POI on this map." end
  local success, info = pcall(getInfo, mapID, poiID)
  if not success or not safeTable(info) then return nil, "POI details unavailable." end
  local valid, name, x, y = pcall(function()
    local label, vector = info.name, info.position
    if not safe(label) or not safeTable(vector) or
        type(label) ~= "string" or not label:match("%S") then return nil end
    local px, py = vector:GetXY()
    if not safe(px) or not safe(py) then return nil end
    return label, px, py
  end)
  if not valid or not name then return nil, "POI details protected or invalid." end
  return record(category, name, mapID, x, y, "gossip-poi")
end
