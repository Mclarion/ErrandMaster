local addon = {}
local function loadModule(path) assert(loadfile(path))("ErrandMaster", addon) end
ErrandMasterDB = {schema=1, nextId=4, account={}, characters={
  ["Test-Realm"]={{id="em-3", name="Legacy errand", category="Repair", scope="character", origin="manual", priority=3, order=3, completed=false}}
}, settings={optimize=true}}
loadModule("Core/Database.lua")
loadModule("Core/Errands.lua")
loadModule("Data/ServiceLocations.lua")
loadModule("Routing/RoutePlanner.lua")
addon.db:Initialize("Test-Realm")
assert(ErrandMasterDB.schema == 3 and ErrandMasterDB.characters["Test-Realm"][1].id == "em-3")
assert(ErrandMasterDB.settings.discoverServices == false)
local locations = addon.locations
local near = locations:Add("Repair", "Repair-capable merchant", 10, .2, .2, "service-event")
assert(near.id and near.precision == "approximate" and near.npcID == nil)
assert(locations:Add("Repair", "Repair-capable merchant", 10, .201, .2, "service-event").id == near.id)
local far = locations:Add("Repair", "Guard-reported repair", 10, .85, .85, "gossip-poi")
assert(far.precision == "poi" and #locations:All() == 2)
assert(#locations:All("Other-Realm") == 0)
local otherMap = locations:Add("Mailbox", "Mailbox", 11, .1, .1, "service-event")
assert(otherMap.mapID == 11)
local invalid = function(fn) assert(not pcall(fn), "expected invalid location to fail") end
invalid(function() locations:Add("Repair", "bad", 10, 2, .1, "service-event") end)
invalid(function() locations:Add("Repair", "bad", 10, .3, .1, "unverified") end)
local legacy = addon.errands:All()[1]
local mail = addon.errands:Add({name="Mail packages",category="Mailbox"})
local route, deferred = addon.route:Plan(addon.errands:All(), 10, .15, .15, true, locations:All())
assert(#route == 1 and route[1].id == legacy.id and route[1].locationID == near.id)
assert(route[1].x == .2 and legacy.x == nil and #deferred == 1 and deferred[1].id == mail.id)
local fromFar = addon.route:Plan(addon.errands:All(), 10, .9, .9, true, locations:All())
assert(fromFar[1].locationID == far.id)
local fixed = addon.errands:Add({name="My exact stop", category="Repair", mapID=10,x=.4,y=.4})
local withFixed = addon.route:Plan(addon.errands:All(), 10, .4, .4, true, locations:All())
assert(withFixed[1].id == fixed.id and not withFixed[1].locationID)
assert(#addon.route:Plan(addon.errands:All(), nil, nil, nil, true, locations:All()) == 0)
print("locations and route tests passed")
