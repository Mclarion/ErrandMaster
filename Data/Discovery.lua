local _, addon = ...
addon.discovery = {}
local discovery = addon.discovery
local classNames = {DEATHKNIGHT="Death Knight", DEMONHUNTER="Demon Hunter",
  DRUID="Druid", EVOKER="Evoker", HUNTER="Hunter", MAGE="Mage",
  MONK="Monk", PALADIN="Paladin", PRIEST="Priest", ROGUE="Rogue",
  SHAMAN="Shaman", WARLOCK="Warlock", WARRIOR="Warrior"}

local function safe(value)
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret then return false end
  end
  return value ~= nil
end
local function safeTable(value)
  return safe(value) and type(value) == "table" and
    (not issecrettable or not issecrettable(value))
end
local function available()
  if not safe(InCombatLockdown) or type(InCombatLockdown) ~= "function" then return false end
  local ok, combat = pcall(InCombatLockdown)
  return ok and safe(combat) and combat == false
end
local function position()
  local mapID, x, y = addon:Position()
  if not safe(mapID) or not safe(x) or not safe(y) then return end
  if type(mapID) ~= "number" or mapID < 1 or mapID % 1 ~= 0 or
      type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y or
      x < 0 or x > 1 or y < 0 or y > 1 then return end
  return mapID, x, y
end
function discovery:PlayerClass()
  if not safe(UnitClass) or type(UnitClass) ~= "function" then return end
  local ok, _, token = pcall(UnitClass, "player")
  if ok and safe(token) and type(token) == "string" then return classNames[token] end
end
local function serviceLabel(category, fallback)
  local name
  if safe(UnitName) and type(UnitName) == "function" then
    local ok, value = pcall(UnitName, "npc")
    if ok and safe(value) and type(value) == "string" and
        value:match("%S") and not value:find("[%c|]") then name = value end
  end
  local label = (name or fallback) .. " — " .. category
  if #label <= 80 then return label end
  return fallback .. " — " .. category
end
local function merchantSpecialties()
  local found, issues = {}, {}
  local function issue(code) issues[code]=(issues[code] or 0)+1 end
  local function classification(value)
    return safe(value) and type(value)=='number' and value==value and
      value>=0 and value<=255 and value%1==0
  end
  if not safe(GetMerchantNumItems) or type(GetMerchantNumItems) ~= "function" or
      not safe(GetMerchantItemLink) or type(GetMerchantItemLink) ~= "function" or
      not safe(GetItemInfoInstant) or type(GetItemInfoInstant) ~= "function" then
    issue('api'); return found,issues
  end
  local ok, count = pcall(GetMerchantNumItems)
  if not ok or not safe(count) or type(count) ~= "number" or
      count ~= count or count < 0 or count > 10000 or count%1~=0 then
    issue('item-count'); return found,issues
  end
  if count>200 then issue('scan-cap') end
  for index = 1, math.min(count, 200) do
    local linked, link = pcall(GetMerchantItemLink, index)
    if linked and safe(link) and type(link) == "string" then
      local textID = link:match("item:(%d+)")
      local id = textID and tonumber(textID)
      if id and id >= 1 and id <= 2147483647 then
        local info, _, _, _, _, _, itemClass, itemSubclass = pcall(GetItemInfoInstant, id)
        if info and classification(itemClass) and (itemClass~=0 or classification(itemSubclass)) then
          if itemClass == 6 then found["Ammo Vendor"] = true
          elseif itemClass == 5 then found["Reagent Vendor"] = true
          elseif itemClass == 0 and safe(itemSubclass) and itemSubclass == 5 then
            found["Food Vendor"] = true
          end
        else
          issue('item-info')
        end
      else
        issue('item-link')
      end
    else
      issue('item-link')
    end
  end
  return found,issues
end
local function record(category, name, mapID, x, y, source)
  local before = #addon.locations:All()
  local ok, item = pcall(addon.locations.Add, addon.locations, category, name, mapID, x, y, source)
  if not ok then return nil, tostring(item) end
  if #addon.locations:All() > before then addon:Refresh() end
  return item
end

-- Event locations are where the player opened a service, not verified NPC coordinates.
function discovery:HandleEvent(event)
  if not addon.db.data.settings.discoverServices or not available() then return false end
  local category, label
  if event == "MERCHANT_SHOW" then
    category, label = "Vendor", "Observed vendor access"
  elseif event == "MAIL_SHOW" then
    category, label = "Mailbox", "Observed mailbox access"
  elseif event == "AUCTION_HOUSE_SHOW" then
    category, label = "Auction House", "Observed auction access"
  elseif event == "BANKFRAME_OPENED" then
    local readable, viewable = pcall(function()
      return safeTable(C_Bank) and C_Bank.AreAnyBankTypesViewable
    end)
    if not readable or not safe(viewable) or type(viewable) ~= "function" then return false end
    local ok, isOpen = pcall(viewable)
    if not ok or not safe(isOpen) or isOpen ~= true then return false end
    category, label = "Bank", "Observed bank access"
  elseif event == "TRAINER_SHOW" then
    if not safe(IsTradeskillTrainer) or type(IsTradeskillTrainer) ~= "function" then return false end
    local ok, profession = pcall(IsTradeskillTrainer)
    if not ok or not safe(profession) or type(profession) ~= "boolean" then return false end
    if profession then category, label = "Profession Trainer", "Observed profession trainer"
    else
      local class = self:PlayerClass()
      if not class or not safe(UnitClass) or type(UnitClass) ~= "function" or
          not safe(GetNumTrainerServices) or type(GetNumTrainerServices) ~= "function" then
        return false
      end
      local playerOK, _, playerToken = pcall(UnitClass, "player")
      local npcOK, _, npcToken = pcall(UnitClass, "npc")
      local countOK, count = pcall(GetNumTrainerServices)
      if not playerOK or not npcOK or not countOK or not safe(playerToken) or
          not safe(npcToken) or type(playerToken) ~= "string" or
          type(npcToken) ~= "string" or npcToken ~= playerToken or
          not safe(count) or type(count) ~= "number" or count ~= count or
          count < 1 or count > 10000 then return false end
      category, label = class .. " Trainer", "Observed class trainer"
    end
  else return false end
  local mapID, x, y = position()
  if not mapID then return false end
  local report = {partial=false, failures={}, saved={}}
  local function save(kind, fallback)
    local item = record(kind, serviceLabel(kind, fallback), mapID, x, y, "service-event")
    if item then report.saved[kind] = true
    else report.partial, report.failures[kind] = true, "not-saved" end
  end
  local repair = false
  if event == "MERCHANT_SHOW" then
    if not safe(CanMerchantRepair) or type(CanMerchantRepair) ~= "function" then
      report.partial, report.failures.Repair = true, "unavailable"
    else
      local ok, value = pcall(CanMerchantRepair)
      if not ok or not safe(value) or type(value) ~= "boolean" then
        report.partial, report.failures.Repair = true, "unavailable"
      else repair = value == true end
    end
  end
  save(category, label)
  if repair then save("Repair", "Observed repair access") end
  if event == "MERCHANT_SHOW" then
    local specialties,issues = merchantSpecialties()
    for code,count in pairs(issues) do
      report.partial=true
      report.failures['Inventory/'..code]=tostring(count)
    end
    for _, specialty in ipairs({"Ammo Vendor", "Reagent Vendor", "Food Vendor"}) do
      if specialties[specialty] then
        save(specialty, "Observed vendor access")
      end
    end
  end
  self.lastReport = report
  return next(report.saved) ~= nil, report
end

-- A player explicitly assigns the category. The POI API supplies coordinates,
-- but it does not prove that the name represents a service or NPC of that type.
function discovery:SaveGossipPoi(category)
  if not available() then return nil, "Unavailable in combat or combat state unknown." end
  if not safeTable(C_GossipInfo) then return nil, "Gossip POI API unavailable." end
  local readable, getID, getInfo = pcall(function()
    return C_GossipInfo.GetPoiForUiMapID, C_GossipInfo.GetPoiInfo
  end)
  if not readable or not safe(getID) or not safe(getInfo) or
      type(getID) ~= "function" or type(getInfo) ~= "function" then
    return nil, "Gossip POI API unavailable."
  end
  local mapID = position()
  if not mapID then return nil, "Player map position unavailable." end
  local ok, poiID = pcall(getID, mapID)
  if not ok or not safe(poiID) or type(poiID) ~= "number" or
      poiID < 1 or poiID % 1 ~= 0 then return nil, "No usable gossip POI on this map." end
  local success, info = pcall(getInfo, mapID, poiID)
  if not success or not safeTable(info) then return nil, "POI details unavailable." end
  local valid, name, x, y = pcall(function()
    local label, vector = info.name, info.position
    if not safe(label) or not safeTable(vector) or
        type(label) ~= "string" or not label:match("%S") then return nil end
    local px, py = vector:GetXY()
    if not safe(px) or not safe(py) then return nil end
    return label, px, py
  end)
  if not valid or not name then return nil, "POI details protected or invalid." end
  return record(category, name, mapID, x, y, "gossip-poi")
end
