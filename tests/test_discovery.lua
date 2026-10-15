local addon = {}
local function loadModule(path) assert(loadfile(path))("ErrandMaster", addon) end
ErrandMasterDB = nil
loadModule("Core/Database.lua")
loadModule("Data/ServiceLocations.lua")
loadModule("Data/Discovery.lua")
addon.db:Initialize("Test-Realm")
addon.Position = function() return 10, .25, .3 end
addon.Refresh = function() end
InCombatLockdown = function() return false end
CanMerchantRepair = function() return true end
local discovery = addon.discovery
assert(not discovery:HandleEvent("MERCHANT_SHOW"))
assert(#addon.locations:All() == 0)
addon.db.data.settings.discoverServices = true
assert(discovery:HandleEvent("MERCHANT_SHOW"))
assert(#addon.locations:All() == 2) -- Vendor and verified repair capability.
assert(addon.locations:All()[2].category == "Repair")
assert(discovery:HandleEvent("MERCHANT_SHOW"))
assert(#addon.locations:All() == 2) -- repeated visit deduplicates.
assert(discovery:HandleEvent("MAIL_SHOW"))
assert(addon.locations:All()[3].category == "Mailbox")
assert(not discovery:HandleEvent("BANKFRAME_OPENED")) -- Unverified bank flavor contract.
assert(#addon.locations:All() == 3)
InCombatLockdown = function() return true end
assert(not discovery:HandleEvent("AUCTION_HOUSE_SHOW"))
assert(#addon.locations:All() == 3)
InCombatLockdown = function() return false end
issecretvalue = function(value) return value == 99 end
addon.Position = function() return 99, .25, .3 end
assert(not discovery:HandleEvent("MAIL_SHOW"))
addon.Position = function() return 10, .25, .3 end
C_GossipInfo = {GetPoiForUiMapID=function() return 7 end,
  GetPoiInfo=function() return {name="Guard marker", position={GetXY=function() return .8,.7 end}} end}
addon.db.data.settings.discoverServices = false -- Explicit action needs no passive opt-in.
local poi = assert(discovery:SaveGossipPoi("Repair"))
assert(poi.source == "gossip-poi" and poi.x == .8 and poi.y == .7)
assert(#addon.locations:All() == 4)
C_GossipInfo.GetPoiForUiMapID = function() return 99 end
assert(not discovery:SaveGossipPoi("Repair"))
assert(#addon.locations:All() == 4)
C_GossipInfo.GetPoiForUiMapID = function() return 7 end
issecrettable = function(tableValue) return type(tableValue) == "table" and tableValue.secret end
C_GossipInfo.GetPoiInfo = function() return {secret=true} end
assert(not discovery:SaveGossipPoi("Repair"))
assert(#addon.locations:All() == 4)
issecrettable = nil
C_GossipInfo.GetPoiInfo = function()
  return setmetatable({}, {__index=function() error("protected POI field") end})
end
local guarded, message = discovery:SaveGossipPoi("Bank")
assert(guarded == nil and message and #addon.locations:All() == 4)
C_GossipInfo = setmetatable({}, {__index=function() error("protected gossip namespace") end})
guarded, message = discovery:SaveGossipPoi("Bank")
assert(guarded == nil and message and #addon.locations:All() == 4)
print("discovery API tests passed")
