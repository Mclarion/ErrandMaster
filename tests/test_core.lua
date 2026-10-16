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
assert(ErrandMasterDB.schema == 5 and ErrandMasterDB.settings.discoverServices == false)
assert(ErrandMasterDB.settings.showDestinations == true,
  'a new character starts with the separate target tracker visible')
assert(ErrandMasterDB.settings.trailRecording == false and
  ErrandMasterDB.settings.routeMode == "observed")
assert(#ErrandMasterDB.settings.wheelSlots == 7)
assert(ErrandMasterDB.settings.wheelSlots[1].category == "Repair")
assert(ErrandMasterDB.settings.wheelSlots[7].category == "Custom")
ErrandMasterDB.settings.wheelSlots[2] = {type="spell", id=12345}
ErrandMasterDB.settings.showDestinations = false
addon.db:Initialize("Other-Realm")
assert(ErrandMasterDB.settings.wheelSlots[2].id == 12345, "wheel slots are account-wide")
assert(ErrandMasterDB.settings.showDestinations == false,
  'an intentionally hidden tracker remains hidden after reinitialization')
assert(#addon.db:ProfessionOverrides()==0)
assert(addon.db:AddProfession('Alchemy') and addon.db:AddProfession('Mining'))
assert(not addon.db:AddProfession('Alchemy') and not addon.db:AddProfession('Bad|Name'))
assert(#addon.db:ProfessionOverrides()==2)
assert(addon.db:RemoveProfession('Mining') and #addon.db:ProfessionOverrides()==1)
addon.db:Initialize('Test-Realm')
assert(#addon.db:ProfessionOverrides()==0, 'profession overrides are character-scoped')
addon.db:Initialize('Other-Realm')
assert(addon.db:ProfessionOverrides()[1]=='Alchemy')
addon.db:ClearProfessions()
assert(#addon.db:ProfessionOverrides()==0)
addon.db:Initialize("Test-Realm")
local legacy = {schema=2, nextId=1, nextLocationId=1, account={}, characters={},
  locations={}, settings={wheelRadius=110, wheelIconSize=46}}
ErrandMasterDB = legacy
addon.db:Initialize("Test-Realm")
assert(ErrandMasterDB == legacy and legacy.schema == 5 and #legacy.settings.wheelSlots == 7)
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
assert(#ErrandMasterDB.settings.wheelSlots == 8 and ErrandMasterDB.settings.wheelSlots[8].id == 123)
assert(ErrandMasterDB.settings.wheelSlots[3].category == "Auction House")
assert(ErrandMasterDB.settings.wheelSlots[4].category == "Mailbox")
assert(ErrandMasterDB.settings.wheelSlots[5].category == "Vendor")
assert(ErrandMasterDB.settings.wheelSlots[6].category == "Class Trainer")
assert(ErrandMasterDB.settings.wheelSlots[7].category == "Custom")
ErrandMasterDB.settings.wheelRadius = 0/0
ErrandMasterDB.settings.wheelIconSize = 0/0
addon.db:Initialize("Test-Realm")
assert(ErrandMasterDB.settings.wheelRadius == 110 and ErrandMasterDB.settings.wheelIconSize == 46)
assert(ErrandMasterDB.settings.wheelScale == 1 and ErrandMasterDB.settings.wheelTheme == "Azure")
ErrandMasterDB.settings.wheelArtReversed='not-a-boolean'
addon.db:Initialize('Test-Realm')
assert(ErrandMasterDB.settings.wheelArtReversed==false)
assert(addon.db:SetWheelColor('Vendor','Amber') and
  ErrandMasterDB.settings.wheelCategoryColors.Vendor=='Amber')
assert(not addon.db:SetWheelColor('Vendor','bad') and
  not addon.db:SetWheelColor('bad|name','Green'))
ErrandMasterDB.settings.wheelCategoryColors['Bad|name']='Green'
ErrandMasterDB.settings.windowPositions={targets={x=.25,y=.4}, main={x=0/0,y=.4}}
addon.db:Initialize('Test-Realm')
assert(ErrandMasterDB.settings.wheelCategoryColors.Vendor=='Amber' and
  not ErrandMasterDB.settings.wheelCategoryColors['Bad|name'])
assert(ErrandMasterDB.settings.windowPositions.targets.x==.25 and
  not ErrandMasterDB.settings.windowPositions.main)
assert(addon.db:SetWheelColor('Vendor',nil) and
  not ErrandMasterDB.settings.wheelCategoryColors.Vendor)
assert(addon.db:WheelInsert({type="addon", name="ErrandMaster"}) and #ErrandMasterDB.settings.wheelSlots == 9)
assert(addon.db:WheelMove(9, 2) and ErrandMasterDB.settings.wheelSlots[2].name == "ErrandMaster")
assert(addon.db:WheelFolder(2, 3, "Useful") and #ErrandMasterDB.settings.wheelSlots == 8)
assert(ErrandMasterDB.settings.wheelSlots[2].type == "folder" and
  ErrandMasterDB.settings.wheelSlots[2].entries[1].name == "ErrandMaster")
assert(addon.db:WheelRemove(2, 1) and ErrandMasterDB.settings.wheelSlots[2].type == "category")
assert(addon.db:WheelRemove(2) and #ErrandMasterDB.settings.wheelSlots == 7)
local prior = ErrandMasterDB.settings.wheelSlots[1]
assert(not addon.db:WheelInsert({type="macro", id=1, script="/cast Bad"}))
assert(not addon.db:WheelInsert({type="addon", name="bad\naddon"}))
assert(not addon.db:WheelMove(1, 100) and ErrandMasterDB.settings.wheelSlots[1] == prior)
assert(addon.db:SetWheelAppearance(1.25, "Ember"))
assert(not addon.db:SetWheelAppearance(9, "Ember") and
  ErrandMasterDB.settings.wheelScale == 1.25 and ErrandMasterDB.settings.wheelTheme == "Ember")
ErrandMasterDB.settings.wheelSlots[1] = {type="folder", name="Saved", entries={
  {type="spell", id=456}, {type="item", id=789}}}
addon.db:Initialize("Test-Realm")
assert(ErrandMasterDB.settings.wheelSlots[1].entries[2].id == 789)
-- A deliberately shortened wheel must not regrow removed defaults at login.
while #ErrandMasterDB.settings.wheelSlots > 2 do addon.db:WheelRemove(3) end
addon.db:Initialize("Test-Realm")
assert(#ErrandMasterDB.settings.wheelSlots == 2)
addon.db:WheelRemove(2); addon.db:WheelRemove(1)
addon.db:Initialize("Test-Realm")
assert(#ErrandMasterDB.settings.wheelSlots == 0, "an intentionally empty wheel stays empty")
assert(addon.db:WheelInsert({type="category", category="Repair"}))
local trail=addon.db:TrailBucket()
assert(type(trail.nodes)=="table" and type(trail.edges)=="table")
trail.nodes[1]={id="trail-1"}
trail.enabled=true
addon.db:Initialize("Test-Realm")
assert(addon.db:TrailBucket().nodes[1].id=="trail-1", "observations survive reload")
addon.db:Initialize("Other-Realm")
assert(#addon.db:TrailBucket().nodes==0, "trails are character-scoped")
assert(addon.db:TrailBucket().enabled==false,
  "recording permission must not carry to another character")
local goodTrails=ErrandMasterDB.trails
ErrandMasterDB.trails="invalid but retained"
addon.db:Initialize("Test-Realm")
assert(addon.db.trailStoreUnavailable and ErrandMasterDB.trails=="invalid but retained",
  "corrupt trail data must be preserved while nontrail features still initialize")
fails(function() addon.db:TrailBucket() end)
ErrandMasterDB.trails=goodTrails
addon.db:Initialize("Test-Realm")
assert(not addon.db.trailStoreUnavailable)
local savedNodes=goodTrails['Test-Realm'].nodes
goodTrails['Test-Realm'].nodes={[1]={id='one'},[3]={id='hidden'}}
fails(function() addon.db:TrailBucket() end)
assert(goodTrails['Test-Realm'].nodes[3].id=='hidden',
  'sparse trail evidence is rejected without silently deleting saved data')
goodTrails['Test-Realm'].nodes=savedNodes
local savedEdges=goodTrails['Test-Realm'].edges
goodTrails['Test-Realm'].edges={unexpected={a='one',b='two'}}
fails(function() addon.db:TrailBucket() end)
goodTrails['Test-Realm'].edges=savedEdges
local retained=ErrandMasterDB
local older={schema=4,nextId=5,nextLocationId=3,account={},characters={},
  locations={},settings={wheelSlots={},wheelScale=1,wheelTheme="Azure",
    trailRecording=true}}
ErrandMasterDB=older
addon.db:Initialize("Test-Realm")
assert(ErrandMasterDB==older and older.schema==5 and older.nextId==5 and
  older.settings.trailRecording==false and older.settings.routeMode=="observed" and
  #older.settings.wheelSlots==0 and type(older.trails)=="table",
  "migration preserves saved wheel and counters, never opts into recording")
ErrandMasterDB=retained
addon.db:Initialize("Test-Realm")
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
TomTom.RemoveWaypoint=function() return false end
assert(not addon.navigation:Next(a) and #added==2 and
  addon.navigation.handle==added[2][1],
  'a failed removal cannot abandon an owned handle or create a duplicate pin')
TomTom.RemoveWaypoint=function(_, handle) removed[#removed+1] = handle end
addon.navigation:Next(nil)
assert(#removed == 2 and removed[2] == added[2][1])
TomTom = nil
assert(addon.navigation:Next(a) == false)
print("core tests passed")
