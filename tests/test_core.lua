-- Run from the addon project root with Lua 5.1 or newer.
local addon = {}
local function loadModule(path)
  local chunk = assert(loadfile(path))
  if setfenv then setfenv(chunk, _G) end
  chunk("ErrandMaster", addon)
end
loadModule("Core/Database.lua")
loadModule("Core/Errands.lua")
loadModule("Data/ServiceLocations.lua")
loadModule("Routing/RoutePlanner.lua")
loadModule("Routing/Navigation.lua")
local function fails(fn) assert(not pcall(fn), "expected invalid input to fail") end
ErrandMasterDB = nil
addon.db:Initialize("Test-Realm")
assert(ErrandMasterDB.schema == 3 and ErrandMasterDB.settings.discoverServices == false)
assert(#ErrandMasterDB.settings.wheelSlots == 7)
assert(ErrandMasterDB.settings.wheelSlots[1].category == "Repair")
assert(ErrandMasterDB.settings.wheelSlots[7].category == "Custom")
ErrandMasterDB.settings.wheelSlots[2] = {type="spell", id=12345}
addon.db:Initialize("Other-Realm")
assert(ErrandMasterDB.settings.wheelSlots[2].id == 12345, "wheel slots are account-wide")
addon.db:Initialize("Test-Realm")
local legacy = {schema=2, nextId=1, nextLocationId=1, account={}, characters={},
  locations={}, settings={wheelRadius=110, wheelIconSize=46}}
ErrandMasterDB = legacy
addon.db:Initialize("Test-Realm")
assert(ErrandMasterDB == legacy and legacy.schema == 3 and #legacy.settings.wheelSlots == 7)
ErrandMasterDB.settings.wheelSlots[3] = {type="macro", id=42}
addon.db:Initialize("Test-Realm")
assert(ErrandMasterDB.settings.wheelSlots[3].id == 42)
ErrandMasterDB.settings.wheelSlots[3] = {type="macro", id=0}
ErrandMasterDB.settings.wheelSlots[4] = {type="category", category="bad\nname"}
ErrandMasterDB.settings.wheelSlots[5] = {type="spell", id=999999999999999999}
ErrandMasterDB.settings.wheelSlots[6] = {type="macro", id=2, script="/cast x"}
ErrandMasterDB.settings.wheelSlots[8] = {type="spell", id=123}
local secret = {type="spell", id=777}
issecretvalue = function(value) return value == secret end
ErrandMasterDB.settings.wheelSlots[7] = secret
addon.db:Initialize("Test-Realm")
issecretvalue = nil
assert(#ErrandMasterDB.settings.wheelSlots == 7)
assert(ErrandMasterDB.settings.wheelSlots[3].category == "Auction House")
assert(ErrandMasterDB.settings.wheelSlots[4].category == "Mailbox")
assert(ErrandMasterDB.settings.wheelSlots[5].category == "Vendor")
assert(ErrandMasterDB.settings.wheelSlots[6].category == "Class Trainer")
assert(ErrandMasterDB.settings.wheelSlots[7].category == "Custom")
ErrandMasterDB.settings.wheelRadius = 0/0
ErrandMasterDB.settings.wheelIconSize = 0/0
addon.db:Initialize("Test-Realm")
assert(ErrandMasterDB.settings.wheelRadius == 110 and ErrandMasterDB.settings.wheelIconSize == 46)
local first = addon.errands:Add({name="Bank", mapID=10, x=0.2, y=0.2, scope="character"})
local second = addon.errands:Add({name="Mail", mapID=10, x=0.8, y=0.8, scope="account"})
assert(first.id ~= second.id and first.createdAt > 0)
assert(#addon.errands:All("Test-Realm") == 2)
assert(#addon.errands:All("Other-Realm") == 1)
local stored = ErrandMasterDB
addon.db:Initialize("Test-Realm")
assert(ErrandMasterDB == stored and addon.errands:Get(first.id) == first)
fails(function() addon.errands:Add({name="Bad", mapID=10, x=1.2, y=0.2}) end)
fails(function() addon.errands:Add({name="Bad", mapID=10, x=0/0, y=0.2}) end)
fails(function() addon.errands:Add({name="Bad", mapID=10, x=0.2}) end)
addon.errands:Update(first.id, {name="Bank visit", priority=2})
assert(addon.errands:Get(first.id).name == "Bank visit")
fails(function() addon.errands:Update(first.id, {x=1.4}) end)
assert(addon.errands:Get(first.id).x == 0.2)
addon.errands:Update(first.id, {clearLocation=true})
assert(addon.errands:Get(first.id).mapID == nil)
addon.errands:Update(first.id, {mapID=10, x=0.2, y=0.2})
addon.errands:Complete(first.id, true)
assert(addon.errands:Get(first.id).completed)
addon.errands:Complete(first.id, false)
assert(not addon.errands:Get(first.id).completed)
addon.errands:Reorder(second.id, 1)
assert(addon.errands:All("Test-Realm")[1].id == second.id)
addon.errands:Delete(first.id)
assert(not addon.errands:Get(first.id))
ErrandMasterDB = {schema=99, account={}, characters={}}
fails(function() addon.db:Initialize("Test-Realm") end)
assert(ErrandMasterDB.schema == 99)
ErrandMasterDB = nil
addon.db:Initialize("Test-Realm")
local a = addon.errands:Add({name="Near", mapID=10, x=0.2, y=0.2})
local b = addon.errands:Add({name="Far", mapID=10, x=0.9, y=0.9})
local c = addon.errands:Add({name="Other map", mapID=11, x=0.1, y=0.1})
local d = addon.errands:Add({name="Unlocated"})
local ordered, deferred = addon.route:Plan(addon.errands:All("Test-Realm"), 10, 0.1, 0.1, true)
assert(#ordered == 2 and ordered[1].id == a.id and ordered[2].id == b.id)
assert(#deferred == 2 and deferred[1].id == c.id and deferred[2].id == d.id)
addon.errands:Reorder(b.id, 1)
local manual = addon.route:Plan(addon.errands:All("Test-Realm"), 10, 0.1, 0.1, false)
assert(manual[1].id == b.id)
local unavailable = addon.route:Plan(addon.errands:All("Test-Realm"), nil, nil, nil, true)
assert(#unavailable == 0)
local added, removed = {}, {}
TomTom = {
  AddWaypoint = function(_, map, x, y, opts) local handle = {}; added[#added+1] = {handle, map, x, y, opts}; return handle end,
  RemoveWaypoint = function(_, handle) removed[#removed+1] = handle end,
}
addon.navigation:Next(a)
addon.navigation:Next(a)
assert(#added == 1 and #removed == 0)
assert(added[1][5].source == "ErrandMaster" and added[1][5].persistent == false)
addon.navigation:Next(b)
assert(#added == 2 and #removed == 1 and removed[1] == added[1][1])
addon.navigation:Next(nil)
assert(#removed == 2 and removed[2] == added[2][1])
TomTom = nil
assert(addon.navigation:Next(a) == false)
print("core tests passed")
