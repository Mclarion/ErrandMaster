local _, addon = ...
addon.db = {}
local db = addon.db
local SCHEMA = 3
local wheelCategories = {"Repair", "Bank", "Auction House", "Mailbox", "Vendor",
  "Class Trainer", "Custom"}
local function plain(value)
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret then return false end
  end
  if type(value) == "table" and type(issecrettable) == "function" then
    local ok, secret = pcall(issecrettable, value)
    if not ok or secret then return false end
  end
  return true
end
local function validID(value)
  return plain(value) and type(value) == "number" and value >= 1 and
    value <= 2147483647 and value % 1 == 0
end
local function validCategory(value)
  return plain(value) and type(value) == "string" and #value >= 1 and
    #value <= 40 and not value:find("[%c|]")
end
local function safeEntry(entry)
  if not plain(entry) or type(entry) ~= "table" or getmetatable(entry) then return nil end
  local kind = entry.type
  if not plain(kind) then return nil end
  for key in pairs(entry) do
    if not plain(key) or (key ~= "type" and key ~= "id" and key ~= "category") then return nil end
  end
  if kind == "category" and entry.id == nil and validCategory(entry.category) then
    return {type="category", category=entry.category}
  end
  if (kind == "spell" or kind == "macro") and entry.category == nil and validID(entry.id) then
    return {type=kind, id=entry.id}
  end
end
local function normalizeSlots(slots)
  local result = {}
  local safe = pcall(function()
    assert(plain(slots) and type(slots) == "table" and not getmetatable(slots))
  end)
  for i, category in ipairs(wheelCategories) do
    local entry
    if safe then
      local ok, value = pcall(function() return safeEntry(slots[i]) end)
      if ok then entry = value end
    end
    result[i] = entry or {type="category", category=category}
  end
  return result
end

local function fresh()
  return {schema = SCHEMA, nextId = 1, nextLocationId = 1,
    account = {}, characters = {}, locations = {}, settings = {
    optimize = true, useTomTom = true, defaultScope = "character", discoverServices = false,
    wheelRadius = 110, wheelIconSize = 46, wheelSlots = normalizeSlots(),
  }}
end

local migrations = {
  [0] = function(old)
    old.schema = 1
    old.nextId = old.nextId or 1
    old.account = old.account or {}
    old.characters = old.characters or {}
    old.settings = old.settings or {}
    return old
  end,
  [1] = function(old)
    assert(type(old.account) == "table" and type(old.characters) == "table" and
      type(old.settings) == "table", "SavedVariables are corrupt; data left untouched")
    old.locations = old.locations or {}
    old.nextLocationId = old.nextLocationId or 1
    old.settings.discoverServices = false -- Never turn passive observation on during migration.
    old.schema = 2
    return old
  end,
  [2] = function(old)
    assert(type(old.settings) == "table", "SavedVariables are corrupt; data left untouched")
    old.settings.wheelSlots = normalizeSlots(old.settings.wheelSlots)
    old.schema = 3
    return old
  end,
}

function db:Initialize(character)
  assert(type(character) == "string" and character ~= "", "character identity unavailable")
  if ErrandMasterDB == nil then ErrandMasterDB = fresh() end
  local data = ErrandMasterDB
  assert(type(data) == "table", "SavedVariables have an invalid format")
  assert(type(data.schema) == "number" and data.schema >= 0 and data.schema <= SCHEMA
    and data.schema % 1 == 0, "unsupported ErrandMaster schema; data left untouched")
  while data.schema < SCHEMA do data = assert(migrations[data.schema])(data) end
  assert(type(data.account) == "table" and type(data.characters) == "table"
    and type(data.nextId) == "number" and data.nextId >= 1
    and data.nextId % 1 == 0 and type(data.locations) == "table"
    and type(data.nextLocationId) == "number" and data.nextLocationId >= 1
    and data.nextLocationId % 1 == 0, "SavedVariables are corrupt; data left untouched")
  data.settings = data.settings or {}
  data.settings.wheelSlots = normalizeSlots(data.settings.wheelSlots)
  if data.settings.optimize == nil then data.settings.optimize = true end
  if data.settings.useTomTom == nil then data.settings.useTomTom = true end
  if type(data.settings.discoverServices) ~= "boolean" then data.settings.discoverServices = false end
  if type(data.settings.wheelRadius) ~= "number" or data.settings.wheelRadius < 80 or
      data.settings.wheelRadius > 200 or
      data.settings.wheelRadius % 1 ~= 0 then data.settings.wheelRadius = 110 end
  if type(data.settings.wheelIconSize) ~= "number" or data.settings.wheelIconSize < 32 or
      data.settings.wheelIconSize > 72 or
      data.settings.wheelIconSize % 1 ~= 0 then data.settings.wheelIconSize = 46 end
  if data.settings.defaultScope ~= "account" then data.settings.defaultScope = "character" end
  data.characters[character] = data.characters[character] or {}
  self.character = character
  self.data = data
end

function db:Bucket(scope, character)
  assert(self.data, "ErrandMaster is not initialized")
  if scope == "account" then return self.data.account end
  assert(scope == "character", "invalid errand scope")
  local key = character or self.character
  self.data.characters[key] = self.data.characters[key] or {}
  return self.data.characters[key]
end

function db:LocationBucket(character)
  assert(self.data, "ErrandMaster is not initialized")
  local key = character or self.character
  self.data.locations[key] = self.data.locations[key] or {}
  return self.data.locations[key]
end

function db:NextID()
  local id = "em-" .. self.data.nextId
  self.data.nextId = self.data.nextId + 1
  return id
end
