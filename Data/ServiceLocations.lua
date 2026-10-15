local _, addon = ...
addon.locations = {}
local locations = addon.locations
local db = addon.db
local MAX_LOCATIONS = 200

local function normalized(value)
  return type(value) == "number" and value == value and value >= 0 and value <= 1
end
local function positiveInteger(value)
  return type(value) == "number" and value == value and value >= 1 and value % 1 == 0
end

function locations:All(character)
  return db:LocationBucket(character)
end

-- Locations are character-scoped observations, not a global NPC catalog.
function locations:Add(category, name, mapID, x, y, source)
  assert(type(category) == "string" and category:match("%S") and #category <= 40,
    "invalid service category")
  assert(type(name) == "string" and name:match("%S") and #name <= 80,
    "invalid location name")
  assert(positiveInteger(mapID) and normalized(x) and normalized(y), "invalid map coordinates")
  assert(source == "service-event" or source == "gossip-poi", "invalid location source")
  local list = self:All()
  local precision = source == "gossip-poi" and "poi" or "approximate"
  for _, known in ipairs(list) do
    if known.mapID == mapID and known.category == category and known.source == source then
      local dx, dy = known.x-x, known.y-y
      if dx*dx + dy*dy <= 0.003*0.003 then return known end
    end
  end
  assert(#list < MAX_LOCATIONS, "location limit reached (200 per character)")
  local result = {id="loc-" .. db.data.nextLocationId, category=category, name=name,
    mapID=mapID, x=x, y=y, source=source, precision=precision,
    observedAt=(time and time()) or os.time()}
  db.data.nextLocationId = db.data.nextLocationId + 1
  list[#list+1] = result
  return result
end

function locations:Delete(id)
  local list = self:All()
  for index, item in ipairs(list) do
    if item.id == id then table.remove(list, index); return true end
  end
  return false
end
