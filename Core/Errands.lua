local _, addon = ...
addon.errands = {}
local errands = addon.errands
local db = addon.db
local MAX_ERRANDS = 200
local fields = {name=true, description=true, category=true, priority=true, mapID=true,
  x=true, y=true, npcID=true, target=true, origin=true, scope=true}
local function coordinate(n)
  return type(n) == "number" and n == n and n >= 0 and n <= 1
end
local function positiveInteger(n)
  return type(n) == "number" and n == n and n >= 1 and n % 1 == 0
end
local function validate(item)
  assert(type(item.name) == "string" and item.name:match("%S") and #item.name <= 80, "name must be 1-80 characters")
  assert(item.scope == "account" or item.scope == "character", "invalid scope")
  assert(item.description == nil or (type(item.description) == "string" and #item.description <= 500), "invalid description")
  assert(item.category == nil or (type(item.category) == "string" and #item.category <= 40), "invalid category")
  assert(item.priority == nil or (positiveInteger(item.priority) and item.priority <= 5), "priority must be 1-5")
  assert(item.origin == "manual" or item.origin == "suggested", "invalid origin")
  assert(item.target == nil or (type(item.target) == "string" and #item.target <= 120), "invalid target")
  assert(item.npcID == nil or positiveInteger(item.npcID), "invalid NPC ID")
  assert((item.mapID == nil and item.x == nil and item.y == nil) or
    (positiveInteger(item.mapID) and coordinate(item.x) and coordinate(item.y)),
    "map ID and normalized X/Y coordinates must be supplied together")
end
local function position(list, id)
  for i, item in ipairs(list) do if item.id == id then return i, item end end
end
function errands:All(character)
  local result = {}
  for _, item in ipairs(db:Bucket("account")) do result[#result+1] = item end
  for _, item in ipairs(db:Bucket("character", character)) do result[#result+1] = item end
  table.sort(result, function(a,b)
    if a.order == b.order then return a.id < b.id end
    return a.order < b.order
  end)
  return result
end
function errands:Get(id)
  for _, item in ipairs(self:All()) do if item.id == id then return item end end
end
function errands:Add(input)
  assert(type(input) == "table", "errand details required")
  assert(#self:All() < MAX_ERRANDS, "maximum of 200 visible errands reached")
  local item = {}
  for field in pairs(fields) do item[field] = input[field] end
  item.scope = item.scope or db.data.settings.defaultScope
  item.origin = item.origin or "manual"
  item.category = item.category or "Custom"
  item.priority = item.priority or 3
  validate(item)
  item.id = db:NextID()
  item.createdAt = (time and time()) or os.time()
  item.completed = false
  item.order = db.data.nextId
  table.insert(db:Bucket(item.scope), item)
  return item
end
function errands:Update(id, changes)
  assert(type(changes) == "table", "changes required")
  local item = assert(self:Get(id), "errand not found")
  local candidate = {}
  for key, value in pairs(item) do candidate[key] = value end
  for key, value in pairs(changes) do
    assert(fields[key] or key == "clearLocation", "field cannot be edited: " .. tostring(key))
    if fields[key] then candidate[key] = value end
  end
  if changes.clearLocation then candidate.mapID, candidate.x, candidate.y = nil, nil, nil end
  validate(candidate)
  if candidate.scope ~= item.scope then
    local old = db:Bucket(item.scope)
    local index = assert(position(old, id))
    table.remove(old, index)
    table.insert(db:Bucket(candidate.scope), item)
  end
  for key in pairs(fields) do item[key] = candidate[key] end
  return item
end
function errands:Delete(id)
  local item = assert(self:Get(id), "errand not found")
  local list = db:Bucket(item.scope)
  table.remove(list, assert(position(list, id)))
end
function errands:Complete(id, completed)
  local item = assert(self:Get(id), "errand not found")
  item.completed = completed ~= false
  return item
end
function errands:Reorder(id, target)
  local items = self:All()
  local index = assert(position(items, id), "errand not found")
  assert(positiveInteger(target) and target <= #items, "invalid position")
  local moved = table.remove(items, index)
  table.insert(items, target, moved)
  for i, item in ipairs(items) do item.order = i end
end
