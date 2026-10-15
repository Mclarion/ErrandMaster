local _, addon = ...
addon.db = {}
local db = addon.db
local SCHEMA = 2

local function fresh()
  return {schema = SCHEMA, nextId = 1, nextLocationId = 1,
    account = {}, characters = {}, locations = {}, settings = {
    optimize = true, useTomTom = true, defaultScope = "character", discoverServices = false,
    wheelRadius = 110, wheelIconSize = 46,
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
