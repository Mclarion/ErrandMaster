local _, addon = ...
addon.db = {}
local db = addon.db
local SCHEMA = 5
local MAX_WHEEL, MAX_FOLDER = 24, 8
local wheelColors = {Copper=true, Amber=true, Green=true, Blue=true,
  Teal=true, Violet=true, Rose=true, Slate=true, Red=true, Gold=true, Magenta=true}
local wheelCategories = {"Bank", "Auction House", "Repair", "Vendor", "Mailbox",
  "Trainer", "Travel", "Custom", "Quests", "Skills", "Items"}
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
    #value <= 40 and not value:find("[%c|]") and not value:find("^%s*$")
end
local function validName(value)
  return validCategory(value) and not value:find("^%s*$")
end
local function professionName(value)
  if not validName(value) then return end
  local name=value:match("^%s*(.-)%s*$")
  if #name>=2 then return name end
end
local function safeEntry(entry, child)
  if not plain(entry) or type(entry) ~= "table" or getmetatable(entry) then return nil end
  local kind = entry.type
  if not plain(kind) then return nil end
  for key in pairs(entry) do
    if not plain(key) or (key ~= "type" and key ~= "id" and key ~= "category" and
        key ~= "name" and key ~= "entries" and key ~= "icon") then return nil end
  end
  if entry.icon ~= nil and not validID(entry.icon) then return nil end
  if kind == "category" and entry.id == nil and entry.name == nil and
      entry.entries == nil and validCategory(entry.category) then
    return {type="category", category=entry.category, icon=entry.icon}
  end
  if (kind == "spell" or kind == "macro" or kind == "item") and
      entry.category == nil and entry.name == nil and entry.entries == nil and validID(entry.id) then
    return {type=kind, id=entry.id, icon=entry.icon}
  end
  if kind == "addon" and entry.category == nil and entry.id == nil and
      entry.entries == nil and validName(entry.name) then
    return {type=kind, name=entry.name, icon=entry.icon}
  end
  if kind == "folder" and (not child or child == 1) and entry.category == nil and entry.id == nil and
      validName(entry.name) and plain(entry.entries) and
      type(entry.entries) == "table" and not getmetatable(entry.entries) then
    local contents = {}
    for i = 1, MAX_FOLDER do
      local nested = entry.entries[i]
      if nested == nil then break end
      local copy = safeEntry(nested, child and 2 or 1)
      if not copy then return nil end
      contents[#contents+1] = copy
    end
    if entry.entries[#contents+1] == nil then
      return {type="folder", name=entry.name, entries=contents, icon=entry.icon}
    end
  end
end
local function normalizeSlots(slots)
  local result = {}
  if slots == nil then
    for i, category in ipairs(wheelCategories) do
      result[i] = {type="category", category=category}
    end
    return result
  end
  local safe = pcall(function()
    assert(plain(slots) and type(slots) == "table" and not getmetatable(slots))
  end)
  if not safe then
    for i, category in ipairs(wheelCategories) do
      result[i] = {type="category", category=category}
    end
    return result
  end
  for i = 1, MAX_WHEEL do
    local present, source = pcall(function() return slots[i] end)
    if present and source == nil then break end
    local ok, value = pcall(function() return safeEntry(source) end)
    if ok and value then result[#result+1] = value
    elseif i <= #wheelCategories then
      result[#result+1] = {type="category", category=wheelCategories[i]}
    elseif not ok then break end
  end
  return result
end

local function normalizeCollection(items, kind)
  local result = {}
  if not plain(items) or type(items) ~= "table" or getmetatable(items) then return result end
  for i = 1, MAX_WHEEL-1 do
    local ok, copy = pcall(function() return safeEntry(items[i], true) end)
    if not ok or not copy then break end
    if copy.type == kind then result[#result+1] = copy end
  end
  return result
end

local function fresh()
  return {schema = SCHEMA, nextId = 1, nextLocationId = 1,
    account = {}, characters = {}, locations = {}, trails = {}, settings = {
    optimize = true, useTomTom = true, defaultScope = "character", discoverServices = false,
    wheelRadius = 100, wheelIconSize = 40, wheelSlots = normalizeSlots(),
    wheelScale = 1, wheelTheme = "Azure", wheelCategoryColors = {},
    wheelSkills = {}, wheelItems = {}, wheelQuestMigrationStatus = "present",
    wheelArtReversed = false, wheelUnlocked = false,
    windowPositions = {},
    trailRecording = false,
    routeMode = "observed", showDestinations = true,
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
  [3] = function(old)
    assert(type(old.settings) == "table", "SavedVariables are corrupt; data left untouched")
    old.settings.wheelSlots = normalizeSlots(old.settings.wheelSlots)
    old.settings.wheelScale = 1
    old.settings.wheelTheme = "Azure"
    old.schema = 4
    return old
  end,
  [4] = function(old)
    assert(type(old.settings) == "table", "SavedVariables are corrupt; data left untouched")
    old.trails = old.trails or {}
    old.settings.trailRecording = false -- Migration never enables movement observation.
    old.settings.routeMode = "observed"
    old.schema = 5
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
    and data.nextLocationId % 1 == 0,
    "SavedVariables are corrupt; data left untouched")
  self.trailStoreUnavailable = type(data.trails) ~= "table"
  data.settings = data.settings or {}
  data.settings.wheelSlots = normalizeSlots(data.settings.wheelSlots)
  -- Run once on old layouts only. A later user removal must remain removed.
  -- Empty custom layouts are intentionally empty, not missing defaults.
  if data.settings.wheelQuestMigrationStatus == nil then
    local slots = data.settings.wheelSlots
    local found = false
    for _,entry in ipairs(slots) do
      if entry.type == "category" and entry.category == "Quests" then found = true end
      if entry.type == "folder" then
        for _,child in ipairs(entry.entries) do
          if child.type == "category" and child.category == "Quests" then found = true end
        end
      end
    end
    if found or #slots == 0 then
      data.settings.wheelQuestMigrationStatus = "present"
    elseif #slots >= MAX_WHEEL then
      data.settings.wheelQuestMigrationStatus = "full"
    else
      slots[#slots+1] = {type="category",category="Quests"}
      data.settings.wheelQuestMigrationStatus = "added"
    end
  end
  data.settings.wheelSkills = normalizeCollection(data.settings.wheelSkills, "spell")
  data.settings.wheelItems = normalizeCollection(data.settings.wheelItems, "item")
  local colors, normalizedColors = data.settings.wheelCategoryColors, {}
  if plain(colors) and type(colors) == "table" and not getmetatable(colors) then
    local count = 0
    for key, color in pairs(colors) do
      if validCategory(key) and plain(color) and wheelColors[color] and count < MAX_WHEEL then
        normalizedColors[key] = color
        count = count + 1
      end
    end
  end
  data.settings.wheelCategoryColors = normalizedColors
  if type(data.settings.wheelArtReversed) ~= "boolean" then
    data.settings.wheelArtReversed = false
  end
  if type(data.settings.wheelUnlocked) ~= "boolean" then data.settings.wheelUnlocked = false end
  data.settings.wheelPinned = nil -- Legacy pin state must not change wheel behavior.
  local center = data.settings.wheelCenter
  if not plain(center) or type(center) ~= "table" or getmetatable(center) or
      not plain(center.x) or not plain(center.y) or type(center.x) ~= "number" or
      type(center.y) ~= "number" or center.x ~= center.x or center.y ~= center.y or
      center.x < 0 or center.x > 1 or center.y < 0 or center.y > 1 then
    data.settings.wheelCenter = nil
  else
    data.settings.wheelCenter = {x=center.x, y=center.y}
  end
  local positions = data.settings.windowPositions
  local clean = {}
  if plain(positions) and type(positions) == "table" and not getmetatable(positions) then
    for _, key in ipairs({"main", "targets", "wheelSettings"}) do
      local saved = positions[key]
      if plain(saved) and type(saved) == "table" and not getmetatable(saved) and
          plain(saved.x) and plain(saved.y) and type(saved.x) == "number" and
          type(saved.y) == "number" and saved.x == saved.x and saved.y == saved.y and
          saved.x >= 0 and saved.x <= 1 and saved.y >= 0 and saved.y <= 1 then
        clean[key] = {x=saved.x, y=saved.y}
      end
    end
  end
  data.settings.windowPositions = clean
  if not plain(data.settings.wheelScale) or type(data.settings.wheelScale) ~= "number" or
      data.settings.wheelScale ~= data.settings.wheelScale or
      data.settings.wheelScale < .5 or data.settings.wheelScale > 1.5 then
    data.settings.wheelScale = 1
  end
  if not plain(data.settings.wheelTheme) or
      not ({Azure=true, Ember=true, Violet=true, Slate=true})[data.settings.wheelTheme] then
    data.settings.wheelTheme = "Azure"
  end
  if data.settings.optimize == nil then data.settings.optimize = true end
  if data.settings.useTomTom == nil then data.settings.useTomTom = true end
  if type(data.settings.showDestinations) ~= "boolean" then
    data.settings.showDestinations = true
  end
  if type(data.settings.discoverServices) ~= "boolean" then data.settings.discoverServices = false end
  data.settings.trailRecording = false -- Obsolete account-wide flag cannot grant consent.
  if data.settings.routeMode ~= "observed" and data.settings.routeMode ~= "direct" then
    data.settings.routeMode = "observed"
  end
  if type(data.settings.wheelRadius) ~= "number" or data.settings.wheelRadius < 40 or
      data.settings.wheelRadius > 220 or
      data.settings.wheelRadius % 1 ~= 0 then data.settings.wheelRadius = 100 end
  if type(data.settings.wheelIconSize) ~= "number" or data.settings.wheelIconSize < 20 or
      data.settings.wheelIconSize > 72 or
      data.settings.wheelIconSize % 1 ~= 0 then data.settings.wheelIconSize = 40 end
  if data.settings.defaultScope ~= "account" then data.settings.defaultScope = "character" end
  data.characters[character] = data.characters[character] or {}
  local characterData=data.characters[character]
  -- Optional manual anchors survive reload; reject malformed ranks without
  -- changing unrelated errands, character state, or another character's queue.
  for _,bucket in ipairs({data.account,characterData}) do
    for _,item in ipairs(bucket) do
      if type(item)=="table" then
        local rank=item.manualPosition
        if rank~=nil and (not plain(rank) or type(rank)~="number" or rank~=rank or
            rank%1~=0 or rank<1 or rank>200) then item.manualPosition=nil end
      end
    end
  end
  local normalized,seen={},{}
  local saved=characterData.professionOverrides
  if plain(saved) and type(saved)=="table" and not getmetatable(saved) then
    for i=1,math.min(#saved,8) do
      local name=professionName(saved[i])
      if name and not seen[name:lower()] then
        normalized[#normalized+1]=name; seen[name:lower()]=true
      end
    end
  end
  characterData.professionOverrides=normalized
  if type(characterData.activeErrandId) ~= "string" or
      #characterData.activeErrandId > 40 or
      not characterData.activeErrandId:match("^em%-%d+$") then
    characterData.activeErrandId = nil
  end
  self.character = character
  self.data = data
end

function db:ProfessionOverrides()
  local names=self.data.characters[self.character].professionOverrides
  local output={}
  for _,name in ipairs(names) do output[#output+1]=name end
  return output
end
function db:AddProfession(value)
  local name=professionName(value)
  if not name then return false end
  local names=self.data.characters[self.character].professionOverrides
  if #names>=8 then return false end
  for _,existing in ipairs(names) do
    if existing:lower()==name:lower() then return false end
  end
  names[#names+1]=name
  return true
end
function db:RemoveProfession(value)
  local name=professionName(value)
  if not name then return false end
  local names=self.data.characters[self.character].professionOverrides
  for i,existing in ipairs(names) do
    if existing:lower()==name:lower() then table.remove(names,i); return true end
  end
  return false
end
function db:ClearProfessions()
  self.data.characters[self.character].professionOverrides={}
end

local primaryTrades = {"Alchemy", "Blacksmithing", "Enchanting", "Engineering",
  "Herbalism", "Leatherworking", "Mining", "Skinning", "Tailoring"}
local commonTrades = {"Cooking", "Fishing", "First Aid"}
local function member(list, value)
  for _, name in ipairs(list) do if value == name then return true end end
  return false
end
function db:ProfessionPreferences()
  local character = self.data.characters[self.character]
  local source = character.wheelProfessions
  local clean = {picks={}, common={}}
  if plain(source) and type(source)=="table" and not getmetatable(source) then
    if plain(source.picks) and type(source.picks)=="table" and not getmetatable(source.picks) then
      for i=1,2 do
        if plain(source.picks[i]) and member(primaryTrades,source.picks[i]) then
          clean.picks[i]=source.picks[i]
        end
      end
    end
    if plain(source.common) and type(source.common)=="table" and not getmetatable(source.common) then
      for _,name in ipairs(commonTrades) do clean.common[name]=source.common[name]~=false end
    end
  else
    -- Preserve up to two legacy chosen primaries, but an absent picker means all.
    for _,name in ipairs(self:ProfessionOverrides()) do
      for _,canonical in ipairs(primaryTrades) do
        if name:lower()==canonical:lower() and #clean.picks<2 then
          clean.picks[#clean.picks+1]=canonical;break
        end
      end
    end
  end
  for _,name in ipairs(commonTrades) do
    if clean.common[name]==nil then clean.common[name]=true end
  end
  if clean.picks[1] and clean.picks[1]==clean.picks[2] then clean.picks[2]=nil end
  character.wheelProfessions=clean
  return clean
end
function db:GetWheelProfessions()
  local preferences=self:ProfessionPreferences()
  local result={}
  local selected=preferences.picks[1] and preferences.picks[2] and preferences.picks or primaryTrades
  for _,name in ipairs(selected) do result[#result+1]=name end
  for _,name in ipairs(commonTrades) do
    if preferences.common[name] then result[#result+1]=name end
  end
  return result
end
function db:SetProfessionPick(slot, name)
  if slot~=1 and slot~=2 then return false end
  if name~=nil and (not plain(name) or not member(primaryTrades,name)) then return false end
  local preferences=self:ProfessionPreferences()
  preferences.picks[slot]=name
  if name and preferences.picks[3-slot]==name then preferences.picks[3-slot]=nil end
  return true
end
function db:SetCommonProfession(name, enabled)
  if not plain(name) or not member(commonTrades,name) or type(enabled)~="boolean" then return false end
  self:ProfessionPreferences().common[name]=enabled
  return true
end
function db:SetWheelMetric(key, value)
  local ranges={wheelRadius={40,220},wheelIconSize={20,72},wheelScale={.5,1.5}}
  local range=ranges[key]
  if not range or not plain(value) or type(value)~="number" or value~=value or
      value<range[1] or value>range[2] or (key~="wheelScale" and value%1~=0) then return false end
  self.data.settings[key]=value
  return true
end
function db:WheelSetIcon(index, value)
  local slots=self.data.settings.wheelSlots
  if type(index)~="number" or index%1~=0 or index<1 or index>#slots or
      (value~=nil and not validID(value)) then return false end
  slots[index].icon=value
  return true
end

local function validIndex(index, limit)
  return plain(index) and type(index) == "number" and index % 1 == 0 and
    index >= 1 and index <= limit
end
local function resolveQuestAddition(db, entry)
  if db.data.settings.wheelQuestMigrationStatus ~= "full" then return end
  local function hasQuests(value)
    if value.type == "category" and value.category == "Quests" then return true end
    if value.type == "folder" then
      for _, child in ipairs(value.entries) do
        if hasQuests(child) then return true end
      end
    end
    return false
  end
  if hasQuests(entry) then db.data.settings.wheelQuestMigrationStatus = "present" end
end
function db:WheelInsert(entry, index)
  local ok, copy = pcall(safeEntry, entry)
  if not ok or not copy then return false end
  local slots = self.data.settings.wheelSlots
  if #slots >= MAX_WHEEL then return false end
  index = index or #slots+1
  if not validIndex(index, #slots+1) then return false end
  table.insert(slots, index, copy)
  resolveQuestAddition(self, copy)
  return true
end
function db:WheelAddMissingDefaults()
  local present, slots = {}, self.data.settings.wheelSlots
  for _,entry in ipairs(slots) do
    if entry.type == "category" then present[entry.category] = true end
  end
  if present["Class Trainer"] then present.Trainer = true end
  local added = 0
  for _,category in ipairs(wheelCategories) do
    if not present[category] and #slots < MAX_WHEEL and
        self:WheelInsert({type="category", category=category}) then
      present[category], added = true, added+1
    end
  end
  return added
end
function db:WheelCollectionAdd(kind, entry)
  if kind ~= "spell" and kind ~= "item" then return false end
  local ok, copy = pcall(safeEntry, entry, true)
  local collection = self.data.settings[kind == "spell" and "wheelSkills" or "wheelItems"]
  if not ok or not copy or copy.type ~= kind or #collection >= MAX_WHEEL-1 then return false end
  collection[#collection+1] = copy
  return true
end
function db:WheelCollectionRemove(kind, index)
  if kind ~= "spell" and kind ~= "item" then return false end
  local collection = self.data.settings[kind == "spell" and "wheelSkills" or "wheelItems"]
  if not validIndex(index, #collection) then return false end
  table.remove(collection, index)
  return true
end
function db:WheelCollectionMove(kind, from, to)
  if kind ~= "spell" and kind ~= "item" then return false end
  local collection = self.data.settings[kind == "spell" and "wheelSkills" or "wheelItems"]
  if not validIndex(from, #collection) or not validIndex(to, #collection) then return false end
  table.insert(collection, to, table.remove(collection, from))
  return true
end
function db:WheelReplace(index, entry)
  local slots = self.data.settings.wheelSlots
  if not validIndex(index, #slots) then return false end
  local ok, copy = pcall(safeEntry, entry)
  if not ok or not copy then return false end
  slots[index] = copy
  resolveQuestAddition(self, copy)
  return true
end
function db:WheelRemove(index, child)
  local slots = self.data.settings.wheelSlots
  if not validIndex(index, #slots) then return false end
  if child ~= nil then
    local folder = slots[index]
    if folder.type ~= "folder" or not validIndex(child, #folder.entries) then return false end
    table.remove(folder.entries, child)
    if #folder.entries == 1 then slots[index] = folder.entries[1]
    elseif #folder.entries == 0 then table.remove(slots, index) end
  else table.remove(slots, index) end
  return true
end
function db:WheelMove(from, target)
  local slots = self.data.settings.wheelSlots
  if not validIndex(from, #slots) or not validIndex(target, #slots) then return false end
  if from == target then return true end
  local entry = table.remove(slots, from)
  table.insert(slots, target, entry)
  return true
end
function db:WheelFolder(from, target, name)
  local slots = self.data.settings.wheelSlots
  if not validIndex(from, #slots) or not validIndex(target, #slots) or
      from == target or slots[from].type == "folder" then return false end
  local existing = slots[target]
  if existing.type == "folder" then
    if #existing.entries >= MAX_FOLDER then return false end
  elseif not validName(name) then return false end
  local entry = table.remove(slots, from)
  if from < target then target = target - 1 end
  existing = slots[target]
  if existing.type == "folder" then
    table.insert(existing.entries, entry)
  else slots[target] = {type="folder", name=name, entries={entry, existing}} end
  return true
end
function db:WheelAddToFolder(index, entry)
  local slots = self.data.settings.wheelSlots
  if not validIndex(index, #slots) or slots[index].type ~= "folder" or
      #slots[index].entries >= MAX_FOLDER then return false end
  local ok, copy = pcall(safeEntry, entry, true)
  if not ok or not copy then return false end
  table.insert(slots[index].entries, copy)
  resolveQuestAddition(self, copy)
  return true
end
-- Paths are root-to-entry indices. A folder may contain one further folder,
-- giving at most three rendered tiers (root, folder, nested folder).
local function wheelParent(slots, path, insert)
  if type(path)~="table" or getmetatable(path) or #path<1 or #path>3 then return end
  local entries=slots
  for depth=1,#path-1 do
    local index=path[depth]
    if not validIndex(index,#entries) then return end
    local folder=entries[index]
    if folder.type~="folder" then return end
    entries=folder.entries
  end
  local index=path[#path]
  if not validIndex(index,#entries+(insert and 1 or 0)) then return end
  return entries,index
end
function db:WheelFindPath(wanted)
  local function visit(entries, prefix)
    for i,entry in ipairs(entries) do
      local path={unpack(prefix)}
      path[#path+1]=i
      if entry==wanted then return path end
      if entry.type=="folder" and #path<3 then
        local found=visit(entry.entries,path)
        if found then return found end
      end
    end
  end
  return visit(self.data.settings.wheelSlots,{})
end
function db:WheelTransfer(sourcePath, targetPath, mode, name)
  if mode~="insert" and mode~="group" then return false end
  local slots=self.data.settings.wheelSlots
  local source,si=wheelParent(slots,sourcePath)
  local destination,di=wheelParent(slots,targetPath,mode=="insert")
  if not source or not destination or (mode=="group" and not destination[di]) then return false end
  local entry,target=source[si],destination[di]
  if not entry then return false end
  local function contains(folder, wanted)
    if folder==wanted then return true end
    if folder.type=="folder" then
      for _,child in ipairs(folder.entries) do
        if contains(child,wanted) then return true end
      end
    end
    return false
  end
  if entry.type=="folder" and destination~=source and
      (mode=="group" and contains(entry,target) or
       #targetPath>1 and contains(entry,slots[targetPath[1]])) then return false end
  if mode=="group" and (entry==target or contains(entry,target)) then return false end
  local destDepth=#targetPath-1
  local entryFolders=entry.type=="folder" and 1 or 0
  if entryFolders==1 then
    for _,child in ipairs(entry.entries) do
      if child.type=="folder" then entryFolders=2;break end
    end
  end
  local capacity=destination==slots and MAX_WHEEL or MAX_FOLDER
  if mode=="insert" then
    if destDepth+entryFolders>2 or
        (source~=destination and #destination>=capacity) then return false end
  elseif target.type=="folder" then
    if destDepth+1+entryFolders>2 or #target.entries>=MAX_FOLDER then return false end
  else
    if destDepth+1+entryFolders>2 or not validName(name) then return false end
  end
  -- All validation precedes the first write; identity and unrelated order survive.
  table.remove(source,si)
  if source==destination and si<di then di=di-1 end
  if mode=="insert" then
    table.insert(destination,di,entry)
  else
    target=destination[di]
    if target.type=="folder" then table.insert(target.entries,entry)
    else destination[di]={type="folder",name=name,entries={entry,target}} end
  end
  return true
end
function db:WheelAddEntry(path,entry,mode,name)
  if mode~="insert" and mode~="group" then return false end
  local slots=self.data.settings.wheelSlots
  local destination,index=wheelParent(slots,path,mode=="insert")
  if not destination then return false end
  local depth=#path-1
  local ok,copy=pcall(safeEntry,entry,depth==0 and nil or depth)
  if not ok or not copy then return false end
  local capacity=destination==slots and MAX_WHEEL or MAX_FOLDER
  if mode=="insert" then
    if #destination>=capacity then return false end
    table.insert(destination,index,copy)
  else
    local existing=destination[index]
    if not existing then return false end
    if existing.type=="folder" then
      if depth>=2 or #existing.entries>=MAX_FOLDER or copy.type=="folder" and depth>=1 then return false end
      table.insert(existing.entries,copy)
    else
      if depth>=2 or not validName(name) or copy.type=="folder" and depth>=1 then return false end
      destination[index]={type="folder",name=name,entries={copy,existing}}
    end
  end
  resolveQuestAddition(self, copy)
  return true
end
function db:WheelRename(index, name)
  local slots = self.data.settings.wheelSlots
  if not validIndex(index, #slots) or slots[index].type ~= "folder" or
      not validName(name) then return false end
  slots[index].name = name
  return true
end
function db:SetWheelAppearance(scale, theme)
  if not plain(scale) or type(scale) ~= "number" or scale ~= scale or
      scale < .5 or scale > 1.5 or
      not plain(theme) or type(theme) ~= "string" or
      not ({Azure=true, Ember=true, Violet=true, Slate=true})[theme] then return false end
  self.data.settings.wheelScale = scale
  self.data.settings.wheelTheme = theme
  return true
end
function db:SetWheelColor(category, color)
  if not validCategory(category) or (color ~= nil and
      (not plain(color) or not wheelColors[color])) then return false end
  local colors = self.data.settings.wheelCategoryColors
  if color and not colors[category] then
    local count = 0
    for _ in pairs(colors) do count = count + 1 end
    if count >= MAX_WHEEL then return false end
  end
  colors[category] = color
  return true
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

local function denseTrailArray(entries, limit)
  if not plain(entries) or type(entries) ~= "table" or getmetatable(entries) then
    return false
  end
  local count = 0
  for key, value in pairs(entries) do
    if not plain(key) or not plain(value) or type(key) ~= "number" or
        key < 1 or key > limit or key % 1 ~= 0 then return false end
    count = count + 1
    if count > limit then return false end
  end
  for i=1,count do if rawget(entries, i) == nil then return false end end
  return true
end
function db:TrailBucket(character)
  assert(self.data, "ErrandMaster is not initialized")
  assert(type(self.data.trails) == "table", "Trail data invalid; left untouched")
  local key = character or self.character
  local bucket = self.data.trails[key]
  if bucket == nil then
    bucket = {nodes={}, edges={}, enabled=false}
    self.data.trails[key] = bucket
  end
  local valid, safe = pcall(function()
    return plain(bucket) and type(bucket) == "table" and not getmetatable(bucket) and
      denseTrailArray(bucket.nodes, 400) and denseTrailArray(bucket.edges, 1200)
  end)
  assert(valid and safe, "Stored trail is corrupt or exceeds bounds")
  if type(bucket.enabled) ~= "boolean" then bucket.enabled = false end
  return bucket
end

function db:NextID()
  local id = "em-" .. self.data.nextId
  self.data.nextId = self.data.nextId + 1
  return id
end
