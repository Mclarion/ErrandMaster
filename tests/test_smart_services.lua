local addon = {}
local function load(path) assert(loadfile(path))("ErrandMaster", addon) end
ErrandMasterDB = nil
load("Core/Database.lua")
load("Core/Errands.lua")
load("Data/ServiceLocations.lua")
load("Data/Discovery.lua")
load("Routing/RoutePlanner.lua")
addon.db:Initialize("Hunter-Realm")
addon.Position = function() return 10, .25, .3 end
addon.Refresh = function() end
InCombatLockdown = function() return false end
UnitName = function(unit) return unit == "npc" and "Quartermaster" end
UnitClass = function(unit)
  if unit == "player" or unit == "npc" then return "Hunter", "HUNTER" end
end
GetNumTrainerServices = function() return 3 end
IsTradeskillTrainer = function() return false end
CanMerchantRepair = function() return true end
local discovery = addon.discovery
assert(not discovery:HandleEvent("TRAINER_SHOW")) -- consent stays off
addon.db.data.settings.discoverServices = true
assert(discovery:HandleEvent("MERCHANT_SHOW"))
local places = addon.locations:All()
assert(places[1].name == "Quartermaster — Vendor")
assert(places[2].name == "Quartermaster — Repair")
UnitName = function(unit) return unit == "npc" and "Huntmaster" end
assert(discovery:HandleEvent("TRAINER_SHOW"))
assert(places[3].category == "Hunter Trainer" and places[3].name == "Huntmaster — Hunter Trainer")
UnitClass = function(unit)
  if unit == "player" then return "Hunter", "HUNTER" end
  if unit == "npc" then return "Warrior", "WARRIOR" end
end
addon.Position = function() return 10, .8, .3 end
assert(not discovery:HandleEvent("TRAINER_SHOW")) -- Wrong class, even with trainer UI open.
assert(#places == 3)
UnitClass = function() return "Hunter", "HUNTER" end
GetNumTrainerServices = function() return 0 end
assert(not discovery:HandleEvent("TRAINER_SHOW")) -- No actual trainer services.
GetNumTrainerServices = function() return 3 end
addon.Position = function() return 10, .25, .3 end
IsTradeskillTrainer = function() return true end
assert(discovery:HandleEvent("TRAINER_SHOW"))
assert(places[4].category == "Profession Trainer")
UnitName = function() return nil end
addon.Position = function() return 10, .5, .5 end
assert(discovery:HandleEvent("MERCHANT_SHOW"))
assert(places[5].name == "Observed vendor access — Vendor")
UnitName = function(unit) return unit == "npc" and "Quartermaster" end
assert(discovery:HandleEvent("MERCHANT_SHOW"))
assert(#places == 8 and places[5].name == "Observed vendor access — Vendor" and
  places[6].name == "Observed repair access — Repair" and
  places[7].name == "Quartermaster — Vendor" and
  places[8].name == "Quartermaster — Repair")
local auto = addon.errands:Add({name="Nearest trainer", category="Class Trainer",
  scope="character", origin="suggested"})
local manual = addon.errands:Add({name="My vendor", category="Vendor",
  scope="character", origin="manual"})
local route = addon.route:Plan(addon.errands:All(), 10, .26, .3, true, places)
local byID = {}
for _, item in ipairs(route) do byID[item.id] = item end
assert(byID[auto.id].name == "Huntmaster — Hunter Trainer")
assert(byID[manual.id].name == "My vendor")
addon.errands:Update(auto.id, {name="My trainer"})
assert(auto.origin == "manual")
route = addon.route:Plan(addon.errands:All(), 10, .26, .3, true, places)
for _, item in ipairs(route) do if item.id == auto.id then assert(item.name == "My trainer") end end
local ammo = addon.locations:Add("Ammo Vendor", "Ammosmith — Ammo Vendor", 10, .26, .3, "service-event")
local ammoTask = addon.errands:Add({name="Nearest ammo", category="Ammo Vendor", origin="suggested"})
route = addon.route:Plan(addon.errands:All(), 10, .26, .3, true, places)
byID = {}
for _, item in ipairs(route) do byID[item.id] = item end
assert(byID[ammoTask.id].locationID == ammo.id)
assert(byID[manual.id].locationID == ammo.id) -- generic vendor picks nearest subtype
UnitClass = function() return "Mage", "MAGE" end
route = addon.route:Plan(addon.errands:All(), 10, .26, .3, true, places)
for _, item in ipairs(route) do assert(item.id ~= auto.id) end
GetMerchantNumItems = function() return 1 end
GetMerchantItemLink = function() return "|Hitem:234:0:0|h[Bullets]|h" end
GetItemInfoInstant = function() return 234, "Projectile", "Bullet", "", 1, 6, 2 end
UnitName = function(unit) return unit == "npc" and "Ammosmith" end
addon.Position = function() return 10, .8, .8 end
assert(discovery:HandleEvent("MERCHANT_SHOW"))
local observedAmmo
for _, place in ipairs(places) do if place.category == "Ammo Vendor" then observedAmmo = place end end
assert(observedAmmo and observedAmmo.x == .8 and
  observedAmmo.name == "Ammosmith — Ammo Vendor")
assert(not discovery:HandleEvent("BANKFRAME_OPENED")) -- API evidence required.
C_Bank = {AreAnyBankTypesViewable=function() return true end}
UnitName = function(unit) return unit == "npc" and "Bailor" end
assert(discovery:HandleEvent("BANKFRAME_OPENED"))
local observedBank
for _, place in ipairs(places) do if place.category == "Bank" then observedBank = place end end
assert(observedBank and observedBank.name == "Bailor — Bank")
print("smart service discovery tests passed")
