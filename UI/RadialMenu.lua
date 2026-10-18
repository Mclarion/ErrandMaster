local _, addon = ...
addon.radial = {}
local wheel = addon.radial
local geometry = addon.wheelGeometry
local ACTION = "ERRANDMASTER_WHEEL"

local categories = {"Bank", "Auction House", "Repair", "Vendor", "Mailbox",
  "Trainer", "Travel", "Custom", "Quests", "Skills", "Items"}
local menus = {
  Bank={"Personal Bank", "Guild Bank", "Back"},
  Vendor={"Food", "Reagents", "Ammo", "Profession Vendor", "General Goods", "Back"},
  ["Profession Vendor"]={"Back"},
  ["Profession Supplies"]={"Back"},
  Mailbox={"Inbox", "Back"},
  Trainer={"Class Trainer", "Profession Trainer", "Weapon Trainer", "Back"},
  Travel={"Flight Master", "Portal", "Boat", "Hearthstone", "Waypoint", "Favorites", "Back"},
  Waypoint={"Pin", "Back"},
  Favorites={"Add Coordinates", "Current Favorites", "Remove Favorite", "Back"},
  Custom={"New Errand", "Saved Errands", "Settings", "Back"},
  Settings={"Edit Wheel", "AddOns Settings", "Back"},
  Quests={"Back"},
}
local quickServices = {Repair=true, Bank=true, ["Auction House"]=true,
  Mailbox=true, Vendor=true, ["Class Trainer"]=true,
  ["Profession Trainer"]=true, ["Pet Trainer"]=true, ["Ammo Vendor"]=true,
  ["Reagent Vendor"]=true, ["Food Vendor"]=true, ["Profession Vendor"]=true,
  ["Flight Master"]=true}
local assetRoot = "Interface\\AddOns\\ErrandMaster\\Textures\\"
local icon = assetRoot .. "PackLogo.blp"
local classes = {DEATHKNIGHT="Death Knight", DEMONHUNTER="Demon Hunter",
  DRUID="Druid", EVOKER="Evoker", HUNTER="Hunter", MAGE="Mage",
  MONK="Monk", PALADIN="Paladin", PRIEST="Priest", ROGUE="Rogue",
  SHAMAN="Shaman", WARLOCK="Warlock", WARRIOR="Warrior"}
local primaryProfessions = {"Alchemy", "Blacksmithing", "Enchanting", "Engineering",
  "Herbalism", "Leatherworking", "Mining", "Skinning", "Tailoring"}
local commonProfessions = {"Cooking", "First Aid", "Fishing"}
local palettes = {Azure={.42, .76, 1}, Ember={1, .48, .24},
  Violet={.78, .55, 1}, Slate={.75, .83, .85}}
local swatchRGB = {Black={.055,.065,.08}, Copper={1,.55,.22}, Amber={1,.68,.08}, Green={.08,.94,.55},
  Blue={.22,.58,1}, Teal={.08,.91,1}, Violet={.78,.32,1},
  Rose={1,.55,.76}, Slate={.78,.86,.94}, Red={1,.27,.30},
  Gold={1,.86,.20}, Magenta={1,.23,.65}, White={1,.92,.72}}
local medallionColors = {Black="White", Red="Red", Blue="Blue", Violet="Purple",
  Amber="Orange", Gold="Yellow", Green="Green", Copper="Orange",
  Magenta="Pink", Rose="Pink", Teal="Cyan", Slate="White", White="White"}
local function medallionPath(color, active)
  local artwork=medallionColors[color] or "Green"
  return assetRoot .. "Medallion" .. artwork ..
    (active and "Active" or "Inactive") .. ".blp"
end
local function colorKey(entry)
  if not entry then return end
  if entry.type == "category" then return entry.category end
  if entry.type == "folder" then return "Folder" end
  if entry.type == "quest" or entry.type == "questZone" then return "Quests" end
  if entry.type == "favorite" or entry.type == "removeFavorite" then return "Favorites" end
  if wheel.submenu == "Skills" or wheel.submenu == "Items" then return wheel.submenu end
  return "Preview"
end
local function entryColor(entry)
  if not entry then return "Slate" end
  local category = colorKey(entry)
  if category=="Back" or category=="Exit" or category=="Close" then return "White" end
  local parent=wheel.history and wheel.history[#wheel.history]
  if parent and parent.entries[parent.selected] then
    return parent.entries[parent.selected].medallionColor
  end
  -- Fixed semantic palette; legacy category color settings are ignored.
  if category == "Folder" then return "Black" end
  if category == "Preview" then return "Rose" end
  if category == "Food" then return "Red" end
  if category == "Reagents" then return "Violet" end
  if category == "Ammo" then return "Copper" end
  if category == "Blacksmithing Vendor" then return "Amber" end
  if category:find("Vendor", 1, true) or category == "Profession Supplies" or
      category == "General Goods" then return "Green" end
  if category:find("Trainer", 1, true) or category == "Trainer" then return "Teal" end
  if category == "Repair" then return "Red" end
  if category == "Mailbox" or category == "Inbox" then return "Amber" end
  if category == "Auction House" then return "Violet" end
  if category == "Travel" or category == "Quests" or category == "Flight Master" or
      category == "Portal" or category == "Boat" or category == "Hearthstone" or
      category == "Waypoint" or category == "Pin" or category == "Select Current" then return "Gold" end
  if category == "Custom" or category == "New Errand" or category == "Saved Errands" or
      category == "Favorites" or category == "Settings" then return "Magenta" end
  if category == "Skills" then return "Teal" end
  if category == "Items" then return "Copper" end
  if category == "Bank" or category == "Personal Bank" or
      category == "Guild Bank" then return "Blue" end
  if category == "Back" then return "Slate" end
  return "Blue"
end

local function usable(value)
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret then return false end
  end
  if value == nil then return false end
  if type(value) == "table" and type(issecrettable) == "function" then
    local ok, secret = pcall(issecrettable, value)
    if not ok or secret then return false end
  end
  return true
end
local function apiMethod(namespace, name)
  if not usable(namespace) or type(namespace) ~= "table" then return end
  local ok, method = pcall(function() return namespace[name] end)
  if ok and usable(method) and type(method) == "function" then return method end
end
local function questLabel(value)
  return usable(value) and type(value)=="string" and #value>0 and
    #value<=160 and value:match("%S") and not value:find("[%c|]")
end
local function safeLabel(value)
  return usable(value) and type(value) == "string" and #value > 0 and
    #value <= 80 and not value:find("[%c|]")
end
local function numeric(text, max)
  if not usable(text) or type(text) ~= "string" or not text:match("^%d+$") then return end
  local value = tonumber(text)
  if value and value >= 1 and value <= max and value % 1 == 0 then return value end
end
local cursorEntry -- Read-only native cursor decoding is defined below.
local function submenuEntries()
  local selected = wheel.submenu
  if selected == "Settings" then
    local settings=addon.db.data.settings
    return {{type="category",category=settings.wheelUnlocked and "Lock Wheel" or "Edit Wheel"},
      {type="category",category="AddOns Settings"},
      {type="category",category="Back"}}
  end
  if selected == "Trainer" and usable(UnitClass) and type(UnitClass)=="function" then
    local ok,_,class=pcall(UnitClass,"player")
    if ok and class=="HUNTER" then
      return {{type="category",category="Class Trainer"},
        {type="category",category="Pet Trainer"},
        {type="category",category="Profession Trainer"},
        {type="category",category="Weapon Trainer"},
        {type="category",category="Back"}}
    end
  end
  if selected == "Waypoint" then
    local result={{type="category",category="Pin"}}
    if addon.travelPoints and type(addon.travelPoints.CurrentWaypoint)=="function" then
      local ok, point=pcall(addon.travelPoints.CurrentWaypoint,addon.travelPoints)
      if ok and usable(point) and type(point)=="table" then
        result[#result+1]={type="category",category="Select Current"}
      end
    end
    result[#result+1]={type="category",category="Back"}
    return result
  end
  if selected == "Current Favorites" or selected == "Remove Favorite" then
    local result = {}
    if addon.travelPoints and type(addon.travelPoints.Favorites)=="function" then
      local ok, errands=pcall(addon.travelPoints.Favorites,addon.travelPoints)
      if ok and usable(errands) and type(errands) == "table" then
        for _, item in ipairs(errands) do
          if usable(item) and type(item) == "table" then
            local valid, id, name, favorite, completed, map, x, y = pcall(function()
              return item.id, item.name, item.favorite, item.completed,
                item.mapID, item.x, item.y
            end)
            if valid and usable(id) and ((type(id)=="string" and
                id:match("^em%-%d+$")) or (type(id)=="number" and id>=1 and
                id%1==0)) and safeLabel(name) and #name <= 80 and
                usable(favorite) and usable(completed) and favorite == true and
                completed ~= true and #result < 23 then
              local entry={type=selected=="Remove Favorite" and
                "removeFavorite" or "favorite", id=id, name=name}
              if usable(map) and usable(x) and usable(y) and type(map)=="number" and
                  map>=1 and map<=1000000 and map%1==0 and type(x)=="number" and
                  type(y)=="number" and x==x and y==y and x>=0 and x<=1 and
                  y>=0 and y<=1 then entry.mapID,entry.x,entry.y=map,x,y end
              result[#result+1]=entry
            end
          end
        end
      end
    end
    result[#result+1] = {type="category", category="Back"}
    return result
  end
  if selected == "Quests" or selected == "Quest Zone" then
    local result, groups, complete = {}, {}, false
    local inventory = addon.quests and apiMethod(addon.quests, "ZoneInventory")
    if inventory then
      local ok, found, all = pcall(inventory, addon.quests)
      if ok and usable(found) and type(found)=="table" then
        groups, complete = found, all == true
      end
    end
    wheel.questInventoryAvailable = inventory ~= nil and complete
    local source = groups
    if selected == "Quest Zone" then
      local group = groups[wheel.questZone]
      source = usable(group) and type(group)=="table" and
        group.name==wheel.questZoneName and group.quests or {}
      if not usable(source) or type(source) ~= "table" then source = {} end
    end
    -- First page has 22 rows + Back + Next; later pages reserve Previous.
    local page = wheel.questPage or 1
    local start = page == 1 and 1 or 23+(page-2)*21
    if start > #source and page > 1 then
      page, start = 1, 1
      wheel.questPage = 1
    end
    local size = page == 1 and 22 or 21
    for i=start,math.min(#source,start+size-1) do
      local row=source[i]
      if usable(row) and type(row)=="table" then
        if selected == "Quests" and questLabel(row.name) then
          result[#result+1]={type="questZone",index=i,name=row.name}
        elseif selected == "Quest Zone" and questLabel(row.title) and
            usable(row.questID) and type(row.questID)=="number" and
            row.questID>=1 and row.questID%1==0 then
          result[#result+1]={type="quest",id=row.questID,name=row.title}
        end
      end
    end
    result[#result+1]={type="category",category="Back"}
    if page>1 then result[#result+1]={type="category",category="Previous"} end
    if start+size<=#source then result[#result+1]={type="category",category="Next"} end
    return result
  end
  if selected == "Skills" or selected == "Items" then
    local settings = addon.db.data.settings
    local entries = settings[selected == "Skills" and "wheelSkills" or "wheelItems"] or {}
    local result = {}
    for i = 1, math.min(#entries, 23) do result[i] = entries[i] end
    result[#result+1] = {type="category", category="Back"}
    return result
  end
  if selected == "Profession Vendor" or selected == "Profession Supplies" or
      selected == "Profession Trainer" then
    local result, known = {}, {}
    if type(addon.db.GetWheelProfessions) == "function" then
      local ok, names = pcall(addon.db.GetWheelProfessions,addon.db)
      if ok and type(names) == "table" then known=names end
    elseif type(addon.ProfessionFilters) == "function" then
      local ok, names = pcall(addon.ProfessionFilters,addon)
      if ok and usable(names) and type(names) == "table" then known=names end
      if #known == 0 then
        for _,name in ipairs(primaryProfessions) do known[#known+1]=name end
        for _,name in ipairs(commonProfessions) do known[#known+1]=name end
      end
    end
    local allowed, seen = {}, {}
    for _, name in ipairs(primaryProfessions) do allowed[name]=true end
    for _, name in ipairs(commonProfessions) do allowed[name]=true end
    for i=1,math.min(#known,24) do
      local name=known[i]
      if usable(name) and allowed[name] and not seen[name] then
        result[#result+1]={type="category",category=name ..
          (selected == "Profession Trainer" and " Trainer" or " Vendor")}
        seen[name]=true
      end
    end
    result[#result+1] = {type="category", category="Back"}
    return result
  end
  local options = menus[selected]
  if not options then return end
  local result = {}
  for i, name in ipairs(options) do result[i] = {type="category", category=name} end
  return result
end
local function entryAt(index)
  if wheel.submenu and wheel.submenu ~= "folder" then
    return (wheel.menuEntries or submenuEntries())[index]
  end
  if wheel.submenu == "folder" then
    local folder = wheel.folderRef or addon.db.data.settings.wheelSlots[wheel.folderIndex]
    if index == #folder.entries + 1 then return {type="category", category="Back"} end
  end
  local ok, entry = pcall(function()
    local slots = addon.db.data.settings.wheelSlots
    if not usable(slots) or type(slots) ~= "table" then return end
    local item
    if wheel.submenu == "folder" then item = (wheel.folderRef or slots[wheel.folderIndex]).entries[index]
    else item = slots[index] end
    if type(item) ~= "table" or not usable(item) then return end
    local kind = item.type
    if not usable(kind) then return end
    if kind == "category" and safeLabel(item.category) and #item.category <= 40 then
      return {type="category", category=item.category, icon=item.icon}
    end
    if (kind == "spell" or kind == "macro") and usable(item.id) and
        type(item.id) == "number" and item.id >= 1 and item.id <= 2147483647 and
        item.id % 1 == 0 then return {type=kind, id=item.id} end
    if kind == "item" and usable(item.id) and type(item.id) == "number" and
        item.id >= 1 and item.id <= 2147483647 and item.id % 1 == 0 then
      return {type="item", id=item.id}
    end
    if (kind == "folder" or kind == "addon") and safeLabel(item.name) then
      return {type=kind, name=item.name, icon=item.icon}
    end
  end)
  return ok and entry or (not wheel.submenu and index <= #categories and
    {type="category", category=categories[index]} or nil)
end
-- A one-time full-layout migration cannot append Quests. Expose a built-in
-- hub shortcut only while that exact capacity condition still applies; do not
-- reinstate a category the player deliberately removed from another layout.
local function fullRootNeedsQuests()
  local settings=addon.db.data.settings
  local slots=settings.wheelSlots
  if settings.wheelQuestMigrationStatus~="full" or not usable(slots) or
      type(slots)~="table" or #slots~=24 then return false end
  for _,entry in ipairs(slots) do
    if entry.type=="category" and entry.category=="Quests" then return false end
    if entry.type=="folder" then
      for _,child in ipairs(entry.entries) do
        if child.type=="category" and child.category=="Quests" then return false end
      end
    end
  end
  return true
end
local function display(entry)
  if not entry then return "", icon end
  if entry.type == "quest" or entry.type == "questZone" then
    return entry.name, assetRoot .. "ServiceQuests.blp"
  end
  if entry.type == "favorite" or entry.type == "removeFavorite" then
    return entry.name, assetRoot .. "PackFavourites.blp"
  end
  if entry.type == "category" then
    if entry.category == "Back" then
      return "Back", assetRoot .. "PackBack.blp"
    elseif entry.category == "Mailbox" or entry.category == "Inbox" then
      return entry.category, assetRoot .. "PackMailbox.blp"
    elseif entry.category == "Profession Trainer" then
      return entry.category, assetRoot .. "PackProfessionTrainer.blp"
    elseif entry.category == "General Goods" then
      return entry.category, assetRoot .. "PackGeneral.blp"
    elseif entry.category == "Vendor" or entry.category == "Profession Vendor" or
        entry.category == "Profession Supplies" then
      return entry.category, assetRoot .. "PackProfessionVendor.blp"
    elseif entry.category == "Herbalism Vendor" then
      return entry.category, assetRoot .. "PackHerbalismVendor.blp"
    elseif entry.category == "Herbalism Trainer" then
      return entry.category, assetRoot .. "PackHerbalismTrainer.blp"
    elseif entry.category == "Fishing Trainer" then
      return entry.category, assetRoot .. "PackFishingTrainer.blp"
    elseif entry.category == "Fishing Vendor" then
      return entry.category, assetRoot .. "PackFishingVendor.blp"
    elseif entry.category == "Alchemy Trainer" then
      return entry.category, assetRoot .. "PackAlchemyTrainer.blp"
    elseif entry.category == "Alchemy Vendor" then
      return entry.category, assetRoot .. "PackAlchemyVendor.blp"
    elseif entry.category == "Cooking Vendor" then
      return entry.category, assetRoot .. "PackCookingVendor.blp"
    elseif entry.category == "First Aid Vendor" then
      return entry.category, assetRoot .. "PackFirstAidVendor.blp"
    elseif entry.category == "Enchanting Vendor" then
      return entry.category, assetRoot .. "PackEnchantmentVendor.blp"
    elseif entry.category == "Engineering Vendor" then
      return entry.category, assetRoot .. "PackEngineeringVendor.blp"
    elseif entry.category == "Leatherworking Vendor" then
      return entry.category, assetRoot .. "PackLeatherworkingVendor.blp"
    elseif entry.category == "Mining Vendor" then
      return entry.category, assetRoot .. "PackMiningVendor.blp"
    elseif entry.category == "Tailoring Vendor" then
      return entry.category, assetRoot .. "PackTailoringVendor.blp"
    elseif entry.category == "Blacksmithing Trainer" then
      return entry.category, assetRoot .. "PackBlacksmithingTrainer.blp"
    elseif entry.category == "Cooking Trainer" then
      return entry.category, assetRoot .. "PackCookingTrainer.blp"
    elseif entry.category == "First Aid Trainer" then
      return entry.category, assetRoot .. "PackFirstAidTrainer.blp"
    elseif entry.category == "Enchanting Trainer" then
      return entry.category, assetRoot .. "PackEnchantmentTrainer.blp"
    elseif entry.category == "Engineering Trainer" then
      return entry.category, assetRoot .. "PackEngineeringTrainer.blp"
    elseif entry.category == "Leatherworking Trainer" then
      return entry.category, assetRoot .. "PackLeatherworkingTrainer.blp"
    elseif entry.category == "Mining Trainer" then
      return entry.category, assetRoot .. "PackMiningTrainer.blp"
    elseif entry.category == "Tailoring Trainer" then
      return entry.category, assetRoot .. "PackTailoringTrainer.blp"
    elseif entry.category == "Favorites" or entry.category == "Current Favorites" or
        entry.category == "Remove Favorite" then
      return entry.category, assetRoot .. "PackFavourites.blp"
    elseif entry.category ~= "Class Trainer" and entry.category:find(" Trainer$") then
      return entry.category, assetRoot .. "PackProfessionTrainer.blp"
    elseif entry.category == "Travel" then
      return entry.category, assetRoot .. "PackTravel.blp"
    elseif entry.category == "Flight Master" then
      return entry.category, assetRoot .. "PackFlightMaster.blp"
    elseif entry.category == "Portal" then
      return entry.category, assetRoot .. "PackPortal.blp"
    elseif entry.category == "Boat" then
      return entry.category, assetRoot .. "PackBoat.blp"
    elseif entry.category == "Hearthstone" then
      return entry.category, assetRoot .. "PackHearthstone.blp"
    elseif entry.category == "Waypoint" or entry.category == "Pin" or
        entry.category == "Select Current" or entry.category == "Add Coordinates" then
      return entry.category, assetRoot .. "PackWaypoint.blp"
    elseif entry.category == "Quests" then
      return entry.category, assetRoot .. "PackQuestmark.blp"
    elseif entry.category == "Active Quests" then
      return entry.category, assetRoot .. "PackQuestionQuestmark.blp"
    elseif entry.category == "Settings" then
      return entry.category, assetRoot .. "PackSettings.blp"
    elseif entry.category == "Edit Wheel" or entry.category == "Lock Wheel" then
      return entry.category,assetRoot..(entry.category=="Edit Wheel" and
        "PackPadlockUnlocked.blp" or "PackPadlockLocked.blp")
    elseif entry.category == "Pet Trainer" then
      return entry.category,assetRoot.."PackClassTrainer.blp"
    elseif entry.category == "AddOns Settings" then
      return entry.category,assetRoot.."PackSettings.blp"
    end
    if entry.category == "Bank" or entry.category == "Personal Bank" then
      return entry.category, assetRoot .. "PackBank.blp"
    elseif entry.category == "Guild Bank" then
      return "Guild Bank", assetRoot .. "PackGuild.blp"
    elseif entry.category == "Repair" then
      return "Repair", assetRoot .. "PackRepair.blp"
    elseif entry.category == "Auction House" then
      return "Auction House", assetRoot .. "PackAuctionHouse.blp"
    elseif entry.category == "Food" then
      return "Food", assetRoot .. "PackFood.blp"
    elseif entry.category == "Reagents" then
      return "Reagents", assetRoot .. "PackReagents.blp"
    elseif entry.category == "Ammo" then
      return "Ammo", assetRoot .. "PackAmmo.blp"
    elseif entry.category == "Blacksmithing Vendor" then
      return "Blacksmithing Vendor", assetRoot .. "PackBlacksmithingVendor.blp"
    elseif entry.category == "Profession Vendor" or entry.category == "Profession Supplies" or
        entry.category:find(" Vendor", 1, true) and
        entry.category ~= "Food Vendor" and entry.category ~= "Reagent Vendor" and
        entry.category ~= "Ammo Vendor" then
      return entry.category, assetRoot .. "PackProfessionVendor.blp"
    end
    if entry.category == "Class Trainer" and usable(UnitClass) and
        type(UnitClass) == "function" then
      local ok, _, token = pcall(UnitClass, "player")
      if ok and usable(token) and type(token) == "string" and classes[token] then
        return classes[token] .. " Trainer", assetRoot .. "Class" .. classes[token]:gsub(" ", "") .. ".blp"
      end
    end
    if entry.category=="Class Trainer" then
      return entry.category,assetRoot.."PackClassTrainer.blp"
    end
    local service = ({Repair="Repair", ["Auction House"]="Auction",
      Mailbox="Mail", Inbox="Mail", Custom="Custom", Settings="Custom",
      ["New Errand"]="Custom", ["Saved Errands"]="Custom",
      Favorites="Favorites", Travel="Travel",
      Quests="Quests", ["Active Quests"]="Quests", Skills="Skills",
      Items="Items", ["Flight Master"]="Flight", Portal="Portal",
      Boat="Boat", Hearthstone="Hearthstone", ["General Goods"]="Vendor",
      Food="Vendor", Reagents="Vendor", Ammo="Vendor",
      ["Profession Supplies"]="Vendor"})[entry.category]
    if not service and entry.category:find("Vendor", 1, true) then service="Vendor" end
    if entry.category=="Trainer" then
      return entry.category,assetRoot.."PackClassTrainer.blp"
    end
    if not service and entry.category:find("Trainer", 1, true) then service="Trainer" end
    if service then return entry.category, assetRoot .. "Service" .. service .. ".blp" end
    return entry.category, icon
  end
  if entry.type == "folder" then return entry.name, "Interface\\Icons\\INV_Misc_Bag_08" end
  if entry.type == "addon" then return entry.name, "Interface\\Icons\\INV_Misc_Gear_01" end
  local label = ({spell="Spell #", macro="Macro #", item="Item #"})[entry.type] .. entry.id
  local spellInfo = entry.type == "spell" and apiMethod(C_Spell, "GetSpellInfo")
  local macroName = entry.type == "macro" and apiMethod(C_Macro, "GetMacroName")
  if spellInfo then
    local ok, info = pcall(spellInfo, entry.id)
    if ok and usable(info) and type(info) == "table" then
      local nameOK, name, image = pcall(function() return info.name, info.iconID end)
      if nameOK then
        if safeLabel(name) then label = name end
        if usable(image) and type(image) == "number" and image > 0 and
            image <= 2147483647 and image % 1 == 0 then return label, image end
      end
    end
  elseif macroName then
    local ok, name = pcall(macroName, entry.id)
    if ok and safeLabel(name) then label = name end
  end
  if entry.type == "item" and usable(GetItemInfo) and type(GetItemInfo) == "function" then
    local ok, name, _, _, _, _, _, _, _, image = pcall(GetItemInfo, entry.id)
    if ok then
      if safeLabel(name) then label = name end
      if usable(image) and type(image) == "number" then return label, image end
    end
  end
  return label, icon
end
local function entryVisual(entry)
  local name, texture=display(entry)
  if entry and usable(entry.icon) and type(entry.icon)=="number" and
      entry.icon>=1 and entry.icon<=2147483647 and entry.icon%1==0 then
    texture=entry.icon
  end
  return name,texture
end
local function outOfCombat()
  if not usable(InCombatLockdown) or type(InCombatLockdown) ~= "function" then return false end
  local ok, result = pcall(InCombatLockdown)
  return ok and usable(result) and result == false
end
local function cursorPosition()
  if not usable(GetCursorPosition) or type(GetCursorPosition) ~= "function" then return end
  local ok, x, y = pcall(GetCursorPosition)
  if not ok or not usable(x) or not usable(y) or
      type(x) ~= "number" or type(y) ~= "number" then return end
  local valid, scale, width, height = pcall(function()
    return UIParent:GetEffectiveScale(), UIParent:GetWidth(), UIParent:GetHeight()
  end)
  if not valid or not usable(scale) or not usable(width) or not usable(height) or
      type(scale) ~= "number" or type(width) ~= "number" or type(height) ~= "number" or
      scale <= 0 or width <= 0 or height <= 0 then return end
  return x / scale, y / scale, width, height
end
local function control(parent, title, x, y, width, action)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 24)
  b:SetPoint("TOPLEFT", x, y)
  b:SetText(title)
  b:SetScript("OnClick", action)
  return b
end
local function caption(parent, title, x, y)
  local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f:SetPoint("TOPLEFT", x, y)
  f:SetText(title)
  return f
end
local function edit(parent, title, x, y, width, limit)
  caption(parent, title, x, y)
  local field = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  field:SetSize(width, 22)
  field:SetPoint("TOPLEFT", x + 7, y - 17)
  field:SetAutoFocus(false)
  field:SetMaxLetters(limit)
  field:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  field:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  return field
end
local function animate(frame)
  if not frame or type(frame.CreateAnimationGroup) ~= "function" then return end
  local ok, animation = pcall(function()
    local group = frame.intro
    if not group then
      group = frame:CreateAnimationGroup()
      local fade = group:CreateAnimation("Alpha")
      fade:SetFromAlpha(0)
      fade:SetToAlpha(1)
      fade:SetDuration(.18)
      frame.intro = group
    end
    group:Stop()
    group:Play()
  end)
  return ok and animation
end
local function wheelLabel(name)
  if type(name) ~= "string" then return "" end
  return (name:match("^[^\n]+") or ""):gsub("|", "/")
end

-- Every tier shares a center. Two choices occupy one quarter of a circle;
-- larger lists grow around their selected parent without making another wheel.
local function tierSweep(count, depth)
  if depth == 1 then return 2 * math.pi end
  return math.min(5.5, math.max(math.pi / 2, count * .42))
end

local function tierAngle(tier, index)
  if tier.depth == 1 then return math.pi/2 - (index-1)*tier.sweep/tier.count end
  return tier.centerAngle + tier.sweep/2 - (index-.5)*tier.sweep/tier.count
end

local function slotPositions(tier,angle)
  local x,y=math.cos(angle)*tier.radius,math.sin(angle)*tier.radius
  return x,y,x,y,tier.iconSize
end

local function rotateArt(region, diameter, angle)
  -- Rotate sampling about the source center, without SetRotation's implicit
  -- scale. Every recycled texture receives all eight coordinates on redraw.
  region:SetSize(diameter,diameter)
  return type(region.SetTexCoord)=="function" and
    pcall(region.SetTexCoord,region,geometry.texCoords(angle))
end
local function placeMedallion(region, tier, angle, centerX, centerY, fit)
  -- Source art points up; rotate a long point toward the hub at the rim.
  local size=math.max(14,math.min(34*fit,
    tier.outerRadius*tier.sweep/tier.count*.38))
  local radius=tier.outerRadius
  region:ClearAllPoints()
  region:SetPoint("CENTER",UIParent,"BOTTOMLEFT",
    centerX+math.cos(angle)*radius,centerY+math.sin(angle)*radius)
  region:SetVertexColor(1,1,1)
  local rotation=angle+math.pi/2 -- Source's longer upward point faces the hub.
  if rotateArt(region,size/.70,rotation) then
    region:Show()
  else region:Hide() end
end
local function outerSize(count, depth, wheel)
  local settings = addon.db.data.settings
  local scale = settings.wheelScale or 1
  if depth > 0 then
    scale = scale * math.min(.86,
      math.min(wheel.screenWidth / 1280, wheel.screenHeight / 900))
  end
  local icon = settings.wheelIconSize * scale
  local radius = math.max(settings.wheelRadius,
    count * settings.wheelIconSize * 1.6 / (2 * math.pi)) * scale
  local fit = math.min(1, math.max(80,
    math.min(wheel.screenWidth, wheel.screenHeight) / 2 - 78) /
    (radius + icon * 1.6))
  radius, icon = radius * fit, icon * fit
  return radius, math.min(icon, radius * 2 * math.pi / count * .72)
end

function wheel:Enter(menu, index, folder)
  local parent = {menu=self.submenu, parent=self.submenuParent,
    folder=self.folderIndex, folderRef=self.folderRef, x=self.centerX, y=self.centerY,
    radius=self.radius, outer=self.outerRadius, count=self.count,
    selected=index, entries={}, questPage=self.questPage, questZone=self.questZone,
    questZoneName=self.questZoneName}
  for i=1,self.count do
    local entry = entryAt(i)
    local name, texture = entryVisual(entry)
    parent.entries[i] = {name=wheelLabel(name), texture=texture,
      color=swatchRGB[entryColor(entry)] or swatchRGB.Slate,
      medallionColor=entryColor(entry)}
  end
  self.history[#self.history+1] = parent
  self.submenuParent, self.submenu, self.folderIndex = self.submenu, menu, folder
  self.folderRef=menu=="folder" and (self.folderRef and self.folderRef.entries[index] or
    addon.db.data.settings.wheelSlots[index]) or nil
  if menu=="Quests" or menu=="Quest Zone" then self.questPage=1 end
  self:Layout(); self:SetSelection(nil)
  self:RefreshAppearance()
  animate(self.trim)
  animate(self.centerArt)
  for i=1,self.count do animate(self.slots[i].texture) end
end

function wheel:GoBack()
  local parent = table.remove(self.history)
  if not parent then return end
  self.submenu, self.submenuParent, self.folderIndex =
    parent.menu, parent.parent, parent.folder
  self.folderRef=parent.folderRef
  self.questPage, self.questZone, self.questZoneName =
    parent.questPage, parent.questZone, parent.questZoneName
  self:Layout(); self:SetSelection(nil)
  self:RefreshAppearance()
  animate(self.trim)
end

function wheel:BeginCenterDrag()
  if not addon.db.data.settings.wheelUnlocked or not outOfCombat() then return false end
  local x, y = cursorPosition()
  if not x or not y then return false end
  self.dragCenter = {x=x-self.centerX, y=y-self.centerY}
  self:Notice("Move wheel; release to save position.")
  return true
end

function wheel:EndCenterDrag()
  local drag = self.dragCenter
  if not drag then return false end
  if drag.moved and not self.submenu and self.screenWidth and self.screenHeight then
    addon.db.data.settings.wheelCenter = {
      x=self.centerX/self.screenWidth, y=self.centerY/self.screenHeight}
  end
  self.dragCenter = nil
  return drag.moved == true
end

function wheel:RenderHistory()
  for depth, parent in ipairs(self.history) do
    local view = self.historyViews[depth]
    if not view then
      view = {icons={}, iconGlows={}, medallionGlows={}, labels={}, sectors={}, borders={}, medallions={},
        shadows={},reliefs={},halos={}}
      self.historyViews[depth] = view
    end
    local tier = self.tiers[depth]
    for i, item in ipairs(parent.entries) do
      if not view.icons[i] then
        view.icons[i] = self.frame:CreateTexture(nil,"ARTWORK",nil,1)
        view.iconGlows[i] = self.frame:CreateTexture(nil,"BORDER",nil,2)
        view.iconGlows[i]:SetBlendMode("ADD")
        view.medallionGlows[i] = self.frame:CreateTexture(nil,"BORDER",nil,3)
        view.medallionGlows[i]:SetBlendMode("ADD")
        view.labels[i] = self.frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        view.shadows[i] = self.frame:CreateTexture(nil,"BACKGROUND",nil,0)
        view.sectors[i] = self.frame:CreateTexture(nil,"BACKGROUND",nil,1)
        view.reliefs[i] = self.frame:CreateTexture(nil,"BORDER",nil,0)
        view.borders[i] = self.frame:CreateTexture(nil,"BORDER",nil,1)
        view.halos[i] = self.frame:CreateTexture(nil,"OVERLAY",nil,1)
        view.halos[i]:SetBlendMode("ADD")
        view.medallions[i] = self.frame:CreateTexture(nil,"OVERLAY",nil,6)
      end
      local angle = tier.angles[i]
      local ix,iy,lx,ly,width=slotPositions(tier,angle)
      for _, layer in ipairs({{view.shadows[i],"Shadow"},{view.sectors[i],"Pattern"},
          {view.reliefs[i],"Relief"},{view.borders[i],"Border"},{view.halos[i],"Halo"}}) do
        local region, kind = layer[1], layer[2]
        region:SetTexture(assetRoot .. string.format("Wheel%sT%dN%02d.blp",
          kind,math.min(depth-1,2),tier.count))
        region:ClearAllPoints()
        region:SetPoint("CENTER",UIParent,"BOTTOMLEFT",self.centerX,
          self.centerY-(kind=="Shadow" and 3*self.artFit or 0))
        local rotation=angle-math.pi/2
        if rotateArt(region,geometry.artDiameter(tier.outerRadius),rotation) then
          region:Show()
        else region:Hide() end
      end
      local color=item.color
      view.sectors[i]:SetVertexColor(color[1],color[2],color[3])
      view.sectors[i]:SetAlpha(i==parent.selected and 1 or .94)
      view.borders[i]:SetVertexColor(1,1,1)
      view.borders[i]:SetAlpha(i==parent.selected and 1 or .85)
      view.shadows[i]:SetAlpha(.72)
      local shade=i==parent.selected and (view.shadowTint or 0)*.30 or 0
      view.shadows[i]:SetVertexColor(color[1]*shade,color[2]*shade,color[3]*shade)
      view.reliefs[i]:SetAlpha(i==parent.selected and .55 or .30)
      view.halos[i]:SetVertexColor(color[1],color[2],color[3])
      view.halos[i]:SetAlpha(i==parent.selected and .68 or 0)
      local medallion=view.medallions[i]
      medallion:SetTexture(medallionPath(item.medallionColor,i==parent.selected))
      medallion:SetDesaturated(item.medallionColor=="White")
      placeMedallion(medallion,tier,angle,self.centerX,self.centerY,self.artFit)
      local jewelGlow=view.medallionGlows[i]
      jewelGlow:SetTexture(medallionPath(item.medallionColor,true))
      placeMedallion(jewelGlow,tier,angle,self.centerX,self.centerY,self.artFit)
      jewelGlow:SetAlpha(i==parent.selected and .38 or .12)
      local image = view.icons[i]
      image:SetTexture(item.texture)
      image:SetTexCoord(0,1,0,1)
      image:SetSize(tier.iconSize,tier.iconSize)
      image:ClearAllPoints()
      image:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX+ix, self.centerY+iy)
      image:SetVertexColor(1,1,1)
      image:SetDesaturated(false)
      image:SetAlpha(1); image:Show()
      local light=view.iconGlows[i]
      light:SetTexture(medallionPath(item.medallionColor,true))
      light:SetSize(tier.iconSize*1.5,tier.iconSize*1.5)
      light:ClearAllPoints()
      light:SetPoint("CENTER",UIParent,"BOTTOMLEFT",self.centerX+ix,self.centerY+iy)
      light:SetAlpha(i==parent.selected and .34 or .10)
      light:Show()
      local label=view.labels[i]
      label:Hide()
    end
    for i=#parent.entries+1,#view.icons do
      view.icons[i]:Hide(); view.labels[i]:Hide()
      view.iconGlows[i]:Hide(); view.medallionGlows[i]:Hide()
      view.sectors[i]:Hide(); view.borders[i]:Hide()
      view.medallions[i]:Hide()
      view.shadows[i]:Hide();view.reliefs[i]:Hide();view.halos[i]:Hide()
    end
  end
  for i=#self.history+1,#self.historyViews do
    local view=self.historyViews[i]
    view.shadowTint=0
    for _, image in ipairs(view.icons) do image:Hide() end
    for _, image in ipairs(view.iconGlows) do image:Hide() end
    for _, image in ipairs(view.medallionGlows) do image:Hide() end
    for _, label in ipairs(view.labels) do label:Hide() end
    for _, region in ipairs(view.sectors) do region:Hide() end
    for _, region in ipairs(view.borders) do region:Hide() end
    for _, region in ipairs(view.medallions) do region:Hide() end
    for _, region in ipairs(view.shadows) do region:Hide() end
    for _, region in ipairs(view.reliefs) do region:Hide() end
    for _, region in ipairs(view.halos) do region:Hide() end
  end
end

function wheel:CancelWheelDrag()
  if self.dragGhost then self.dragGhost:Hide() end
  if self.dragIndex and self.dragTier==#self.tiers and self.slots and self.slots[self.dragIndex] then
    self.slots[self.dragIndex].texture:SetAlpha(1)
  elseif self.dragIndex and self.historyViews and self.historyViews[self.dragTier] then
    local image=self.historyViews[self.dragTier].icons[self.dragIndex]
    if image then image:SetAlpha(1) end
  end
  self.dragIndex,self.dragSource,self.dragTarget,self.dragMode=nil,nil,nil,nil
  self.dragEntryRef,self.dragTier,self.dragTargetLevel=nil,nil,nil
  self.dragHoverStart=nil
  self.hoverIndex,self.hoverStart,self.hoverRemove=nil,nil,nil
  if self.frame and self.frame:IsShown() then self:Layout(); self:SetSelection(nil) end
end
function wheel:TierEntry(index,level)
  local parent=level==#self.tiers and self.folderRef or
    self.history[level] and self.history[level].folderRef
  local entries=parent and parent.entries or addon.db.data.settings.wheelSlots
  return entries[index],entries
end
function wheel:TransferTarget(index,level,mode)
  local entry,entries=self:TierEntry(index,level)
  local db=addon.db
  if entry then return db:WheelFindPath(entry) end
  if mode=="insert" and level==#self.tiers and self.submenu=="folder" and
      index==#entries+1 then
    local parent=db:WheelFindPath(self.folderRef)
    if parent then parent[#parent+1]=#entries+1;return parent end
  end
end
function wheel:OverIcon(index,level)
  if not index or not self.tiers then return false end
  local x,y=cursorPosition()
  if not x then return false end
  local tier=self.nativeBaseModel and self.nativeBaseModel.tiers[level or #self.nativeBaseModel.tiers] or
    self.tiers[level or #self.tiers]
  if not tier.angles[index] then return false end
  local ix,iy=geometry.icon(tier,index)
  local dx,dy=x-self.centerX-ix,y-self.centerY-iy
  return dx*dx+dy*dy<(tier.iconSize*.55)^2
end
function wheel:UpdateDragPreview(elapsed)
  local source=self.dragIndex
  if not source or not self.frame or not self.frame:IsShown() then return end
  local x,y=cursorPosition()
  if not x then self:CancelWheelDrag(); return end
  self.dragGhost:ClearAllPoints()
  self.dragGhost:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y)
  local target,_,level=self:IndexAtCursor(true)
  if self.submenu~="folder" and level~=#self.tiers then target=nil end
  if target==self.count and level==#self.tiers and self.submenu then
    if self.submenu~="folder" then target=nil end
  end
  self.dragTargetLevel=level
  if target~=self.dragTarget or level~=self.lastDragLevel then
    self.lastDragLevel=level
    self.dragTarget,self.dragHoverStart=target,nil
    if target and type(GetTime)=="function" then
      local ok,now=pcall(GetTime)
      if ok and usable(now) then self.dragHoverStart=now end
    end
  end
  -- Dwell only counts uninterrupted time inside the icon, not the whole wedge.
  if not self:OverIcon(target,level) then self.dragHoverStart=nil
  elseif target and not self.dragHoverStart and type(GetTime)=="function" then
    local ok,now=pcall(GetTime)
    if ok and usable(now) then self.dragHoverStart=now end
  end
  local mode="insert"
  if target and (target~=source or level~=self.dragTier) and
      (not self.submenu or self.submenu=="folder") and
      self:TierEntry(target,level) then
    local targetTier=self.tiers[level]
    local tx,ty=geometry.icon(targetTier,target)
    local dx,dy=x-self.centerX-tx,y-self.centerY-ty
    local duration=0
    if self.dragHoverStart and type(GetTime)=="function" then
      local ok,now=pcall(GetTime)
      if ok and usable(now) then duration=now-self.dragHoverStart end
    end
    if dx*dx+dy*dy<(targetTier.iconSize*.55)^2 and duration>=.45 then
      mode="folder"
    end
  end
  self.dragMode=mode
  if target and target~=source and level==#self.tiers then
    self.slots[target].glowTarget=mode=="folder" and 1 or .45
  elseif target and level<#self.tiers then
    local view=self.historyViews[level]
    if view and view.halos[target] then view.halos[target]:SetAlpha(.68) end
  end
  local tier=self.tiers[#self.tiers]
  for i=1,self.count do
    local slot=self.slots[i]
    if (i~=source or self.dragTier~=#self.tiers) and slot.texture:IsShown() then
      local destination=i
      if target and mode=="insert" and level==#self.tiers and
          self.dragTier==level then
        if source<target and i>source and i<=target then destination=i-1 end
        if source>target and i>=target and i<source then destination=i+1 end
      end
      local tx,ty=geometry.icon(tier,destination)
      local old=slot.previewX or (self.centerX+geometry.icon(tier,i))
      local oldY=slot.previewY or (self.centerY+math.sin(tier.angles[i])*tier.radius)
      local mix=math.min(1,elapsed*12)
      slot.previewX=old+(self.centerX+tx-old)*mix
      slot.previewY=oldY+(self.centerY+ty-oldY)*mix
      slot.texture:ClearAllPoints()
      slot.texture:SetPoint("CENTER",UIParent,"BOTTOMLEFT",slot.previewX,slot.previewY)
      slot.texture:SetAlpha(mode=="folder" and level==#self.tiers and i==target and .55 or 1)
    end
  end
  self.dragGhost:SetAlpha(mode=="folder" and .75 or 1)
end
function wheel:UpdateNativePreview(elapsed)
  if self.dragIndex or not addon.db.data.settings.wheelUnlocked or not cursorEntry then return end
  local entry=cursorEntry()
  if not entry then
    if self.nativePreview then
      self.nativePreview,self.nativeTarget,self.nativeBaseModel=nil,nil,nil
      self.previewInsert,self.previewPayload=nil,nil
      self.dragGhost:Hide();self:Layout()
    end
    return
  end
  self.nativePreview=true
  local x,y=cursorPosition()
  if not x then return end
  local _,texture=entryVisual(entry)
  self.dragGhost:SetTexture(texture)
  self.dragGhost:SetSize(self.tiers[#self.tiers].iconSize,self.tiers[#self.tiers].iconSize)
  self.dragGhost:ClearAllPoints()
  self.dragGhost:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y)
  self.dragGhost:SetAlpha(.65);self.dragGhost:Show()
  local target,_,level=self:IndexAtCursor()
  local allowed=not self.submenu or self.submenu=="folder" or
    self.submenu=="Skills" or self.submenu=="Items"
  if level~=#self.tiers or not allowed then target=nil end
  local actual=self.submenu=="folder" and #(self.folderRef.entries) or
    self.submenu=="Skills" and #addon.db.data.settings.wheelSkills or
    self.submenu=="Items" and #addon.db.data.settings.wheelItems or
    #addon.db.data.settings.wheelSlots
  local grouping=target and target<=actual and self:OverIcon(target)
  local capacity=self.submenu=="folder" and 8 or self.submenu and 23 or 24
  local proposed=target and not grouping and actual<capacity and target or nil
  if proposed~=self.previewInsert or target~=self.nativeTarget then
    local old={}
    for i=1,self.count do
      local slot=self.slots[i]
      old[i]={slot.previewX or (slot.texture.point and slot.texture.point[4]),
        slot.previewY or (slot.texture.point and slot.texture.point[5])}
    end
    if not self.nativeBaseModel then self.nativeBaseModel=self.model end
    self.nativeTarget,self.previewInsert,self.previewPayload=target,proposed,entry
    self:Layout()
    for i=1,self.count do
      local from=proposed and i>proposed and i-1 or i
      local prior=old[from]
      if prior and prior[1] and prior[2] then
        self.slots[i].previewX,self.slots[i].previewY=prior[1],prior[2]
      end
    end
  end
  local tier=self.tiers[#self.tiers]
  for i=1,self.count do
    local slot=self.slots[i]
    local tx,ty=geometry.icon(tier,i)
    local oldX,oldY=slot.previewX or self.centerX+tx,slot.previewY or self.centerY+ty
    local mix=math.min(1,(elapsed or .016)*12)
    slot.previewX=oldX+(self.centerX+tx-oldX)*mix
    slot.previewY=oldY+(self.centerY+ty-oldY)*mix
    slot.texture:ClearAllPoints()
    slot.texture:SetPoint("CENTER",UIParent,"BOTTOMLEFT",slot.previewX,slot.previewY)
  end
  if target and self.slots[target] then self.slots[target].glowTarget=grouping and 1 or .45 end
end
function wheel:FinishWheelDrag()
  local source,target,mode,collection=self.dragIndex,self.dragTarget,self.dragMode,self.dragSource
  local sourceRef,level=self.dragEntryRef,self.dragTargetLevel
  local sourcePath=sourceRef and addon.db:WheelFindPath(sourceRef)
  local targetPath=target and level and self:TransferTarget(target,level,mode)
  if mode=="insert" and sourcePath and targetPath and
      #sourcePath==#targetPath and sourcePath[#sourcePath]<targetPath[#targetPath] then
    local same=true
    for i=1,#sourcePath-1 do
      if sourcePath[i]~=targetPath[i] then same=false;break end
    end
    if same then targetPath[#targetPath]=targetPath[#targetPath]+1 end
  end
  self:CancelWheelDrag()
  if not source or not target or not outOfCombat() then return false end
  local db=addon.db
  local changed=false
  if collection=="Skills" or collection=="Items" then
    local kind=collection=="Skills" and "spell" or "item"
    changed=db:WheelCollectionMove(kind,source,target)
  elseif sourcePath and targetPath then
    changed=db:WheelTransfer(sourcePath,targetPath,mode=="folder" and "group" or mode,"New folder")
  end
  if changed then
    self:Layout(); self:RefreshAppearance()
    self:Notice(mode=="folder" and "Folder created." or "Wheel order changed.")
  end
  return changed
end
function wheel:Create()
  if self.frame then return end
  local frame = CreateFrame("Frame", "ErrandMasterWheel", UIParent)
  frame:Hide() -- Construction must not leave a visible/active partial frame.
  self.buildingFrame=frame
  frame:SetSize(340, 340) -- Only the wheel intercepts clicks; pinned bags stay usable.
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:EnableMouse(true)
  frame:EnableKeyboard(true)
  frame:SetPropagateKeyboardInput(true) -- Never swallow A/D, arrows or bound movement.
  frame:RegisterForDrag("LeftButton")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
  frame:RegisterEvent("UI_SCALE_CHANGED")
  frame:RegisterEvent("QUEST_LOG_UPDATE")
  frame:SetScript("OnEvent", function(_,event)
    if event=="PLAYER_REGEN_DISABLED" then wheel:Close(); return end
    if event=="QUEST_LOG_UPDATE" then
      if wheel.frame and wheel.frame:IsShown() and
          (wheel.submenu=="Quests" or wheel.submenu=="Quest Zone") then
        wheel:Layout(); wheel:RefreshAppearance()
      end
      return
    end
    local x,y,w,h=cursorPosition()
    if w and wheel.frame:IsShown() then
      local oldWidth,oldHeight=wheel.screenWidth,wheel.screenHeight
      wheel.screenWidth,wheel.screenHeight=w,h
      local saved=addon.db.data.settings.wheelCenter
      if saved and not wheel.dragCenter and not wheel.submenu then
        wheel.cursorX,wheel.cursorY=saved.x*w,saved.y*h
      elseif wheel.submenu and oldWidth and oldHeight then
        wheel.layoutX,wheel.layoutY=wheel.centerX/oldWidth*w,
          wheel.centerY/oldHeight*h
      end
      wheel:Layout(); wheel:RefreshAppearance()
    end
  end)
  local function update(_,elapsed)
    if wheel.dragCenter then
      local x, y = cursorPosition()
      if x and y then
        local targetX, targetY = x - wheel.dragCenter.x, y - wheel.dragCenter.y
        if math.abs(targetX-wheel.centerX)>3 or math.abs(targetY-wheel.centerY)>3 then
          wheel.dragCenter.moved = true
        end
        if wheel.submenu then
          wheel.layoutX, wheel.layoutY = targetX, targetY
        else
          wheel.cursorX, wheel.cursorY = targetX, targetY
        end
        wheel:Layout()
        wheel:RefreshAppearance()
      end
    end
    wheel:UpdateHighlight()
    if addon.db.data.settings.wheelUnlocked and not wheel.dragIndex then
      local target=wheel:IndexAtCursor()
      if not wheel:OverIcon(target) then target=nil end
      if target~=wheel.hoverIndex then
        wheel.hoverIndex=target
        local ok,now=pcall(function() return GetTime and GetTime() end)
        wheel.hoverStart=ok and usable(now) and type(now)=="number" and now or nil
      end
    end
    wheel:UpdateDragPreview(elapsed or .016)
    wheel:UpdateNativePreview(elapsed or .016)
    wheel.materialTime=(wheel.materialTime or 0)+math.min(elapsed or .016,.1)
    local shimmer=.88+.12*math.sin(wheel.materialTime*2.5)
    for i=1,wheel.count or 0 do
      local slot=wheel.slots[i]
      local alpha=slot.glowAlpha or 0
      local target=slot.glowTarget or 0
      if alpha~=target then
        local step=math.min(1,(elapsed or .016)*9)
        alpha=alpha+(target-alpha)*step
        if math.abs(alpha-target)<.004 then alpha=target end
        slot.glowAlpha=alpha
        slot.activeMedallion:SetAlpha(alpha)
        slot.sector:SetAlpha(.94+alpha*.06)
      end
      slot.borderGlow:SetAlpha(alpha*.85*shimmer)
      slot.iconGlow:SetAlpha(.10+alpha*.22*shimmer)
      slot.medallionGlow:SetAlpha(.10+alpha*.28*shimmer)
      local shade=slot.shadowTint or 0
      local desired=slot.shadowTarget or 0
      shade=shade+(desired-shade)*math.min(1,(elapsed or .016)*7)
      slot.shadowTint=shade
      local color=slot.shadowColor or {0,0,0}
      slot.shadow:SetVertexColor(color[1]*shade*.30,color[2]*shade*.30,color[3]*shade*.30)
      slot.relief:SetAlpha(.30+alpha*.25)
    end
    for depth,parent in ipairs(wheel.history) do
      local view=wheel.historyViews[depth]
      if view and view.halos[parent.selected] then
        view.halos[parent.selected]:SetAlpha(.68*shimmer)
      end
      if view then
        view.shadowTint=math.min(1,(view.shadowTint or 0)+math.min(1,(elapsed or .016)*7))
        for i,item in ipairs(parent.entries) do
          local shade=i==parent.selected and view.shadowTint*.30 or 0
          view.shadows[i]:SetVertexColor(item.color[1]*shade,item.color[2]*shade,item.color[3]*shade)
        end
      end
    end
  end
  frame:SetScript("OnUpdate",function(_,elapsed)
    local ok,message=pcall(update,frame,elapsed)
    if not ok then wheel:Fail(message) end
  end)
  frame:SetScript("OnMouseDown", function(_, mouse)
    if mouse ~= "LeftButton" and mouse ~= "RightButton" then return end
    local hit, _, tier = wheel:IndexAtCursor()
    if mouse=="LeftButton" and hit and tier and tier<#wheel.tiers then
      while #wheel.tiers>tier do wheel:GoBack() end
    end
    wheel:UpdateHighlight()
    local index = wheel.selected
    local settings = addon.db.data.settings
    if not index and mouse=="LeftButton" and not settings.wheelUnlocked then
      wheel:Close(); return
    end
    if mouse == "LeftButton" and wheel.submenu and index and
        entryAt(index) and entryAt(index).category == "Back" then
      wheel:GoBack()
      return
    end
    if settings.wheelUnlocked then
      if mouse=="LeftButton" and index then
        local selectedEntry=entryAt(index)
        if selectedEntry and selectedEntry.type=="folder" then
          if #wheel.history>=2 then wheel:Notice("Folder depth limit: three visual tiers.");return end
          wheel:Enter("folder",index,index); return
        end
      end
      if mouse=="LeftButton" and wheel.submenu=="Settings" and index then
        local selectedEntry=entryAt(index)
        if selectedEntry then wheel:SelectCategory(selectedEntry.category) end
        return
      end
      if mouse=="LeftButton" and wheel.submenu=="Custom" and index then
        local selectedEntry=entryAt(index)
        if selectedEntry and selectedEntry.category=="Settings" then
          wheel:Enter("Settings",index)
          return
        end
      end
      if mouse == "LeftButton" and index and not wheel.submenu then
        local selectedEntry = entryAt(index)
        local category = selectedEntry and selectedEntry.type == "category" and
          selectedEntry.category
        if category == "Skills" or category == "Items" or category == "Custom" or
            category == "Settings" then
          wheel:Enter(category, index)
          return
        end
      end
      if index and index > 0 and not wheel.submenu then
        wheel.editorIndex = index
        if mouse == "RightButton" then
          wheel:ShowAddMenu(index)
        else wheel:Notice("Drag to insert; hover a slot to create a folder.") end
      end
      return
    end
    if mouse ~= "LeftButton" then return end
    if wheel.activeIndex and not wheel.submenu then
      wheel:Close()
      if index and addon.db:WheelMove(wheel.activeIndex, index) then
        wheel:Notice("Moved active entry to slot " .. index .. ".")
        wheel.activeIndex = nil
        wheel:RefreshEditor()
      end
      return
    end
    local entry = index and entryAt(index)
    if entry then
      if entry.type == "category" then
        local category = entry.category
        if (menus[category] or category == "Skills" or category == "Items") and
            not wheel.submenu then
          wheel:Enter(category, index)
          if category=="Quests" and not wheel.questInventoryAvailable then
            wheel:Notice("Quest log inventory unavailable or incomplete; some zones may be missing.")
          end
          return
        elseif (category=="Settings" and wheel.submenu=="Custom") or
            ((category == "Profession Vendor" or category == "Profession Supplies") and
            wheel.submenu == "Vendor") or
            (category == "Profession Trainer" and wheel.submenu == "Trainer") then
          wheel:Enter(category, index)
          return
        elseif (category=="Next" or category=="Previous") and
            (wheel.submenu=="Quests" or wheel.submenu=="Quest Zone") then
          wheel.questPage=math.max(1,(wheel.questPage or 1)+(category=="Next" and 1 or -1))
          wheel:Layout(); wheel:RefreshAppearance()
          return
        elseif (category == "Waypoint" or category == "Favorites") and
            wheel.submenu == "Travel" or
            (category == "Current Favorites" or category == "Remove Favorite") and
            wheel.submenu == "Favorites" then
          wheel:Enter(category, index)
          if wheel.count==1 then wheel:Notice("No open favorites. Add coordinates or mark a target Fav.") end
          return
        end
        local wheelSetting=wheel.submenu=="Settings" and
          (category=="Edit Wheel" or category=="Lock Wheel")
        if not settings.wheelUnlocked and not wheelSetting then wheel:Close() end
        wheel:SelectCategory(category)
      elseif entry.type == "folder" then
        if #wheel.history>=2 then wheel:Notice("Folder depth limit: three visual tiers.")
        else wheel:Enter("folder", index, index) end
      elseif entry.type == "questZone" then
        local inventory=addon.quests and apiMethod(addon.quests,"ZoneInventory")
        local ok,groups=false,nil
        if inventory then ok,groups=pcall(inventory,addon.quests) end
        local group=ok and usable(groups) and type(groups)=="table" and groups[entry.index]
        if not usable(group) or type(group)~="table" or group.name~=entry.name then
          wheel:Notice("Quest zone changed; reopen Quests to refresh the log.")
          wheel:Layout();return
        end
        wheel.questZone, wheel.questZoneName = entry.index, entry.name
        wheel:Enter("Quest Zone",index)
      elseif entry.type == "quest" then
        -- The live log may change while a ring is open. Revalidate before using
        -- coordinates; a missing waypoint must never queue a guessed location.
        local inventory=addon.quests and apiMethod(addon.quests,"ZoneInventory")
        local ok,groups=false,nil
        if inventory then ok,groups=pcall(inventory,addon.quests) end
        local zone=ok and usable(groups) and type(groups)=="table" and
          groups[wheel.questZone]
        local active
        if usable(zone) and type(zone)=="table" and zone.name==wheel.questZoneName and
            usable(zone.quests) and type(zone.quests)=="table" then
          for _,row in ipairs(zone.quests) do
            if usable(row) and type(row)=="table" and row.questID==entry.id then
              active=row;break
            end
          end
        end
        if not active then
          wheel:Notice("Quest is no longer in this zone's log; reopen Quests.")
          wheel:Layout();wheel:RefreshAppearance();return
        end
        local map,x,y=active.mapID,active.x,active.y
        if active.hasLocation~=true or not usable(map) or type(map)~="number" or
            map<1 or map>1000000000 or map%1~=0 or
            not usable(x) or type(x)~="number" or x~=x or x<0 or x>1 or
            not usable(y) or type(y)~="number" or y~=y or y<0 or y>1 then
          wheel:Notice("Quest location unavailable; open the quest log or map for guidance.")
          return
        end
        if not settings.wheelUnlocked then wheel:Close() end
        local add=apiMethod(addon.quests,"Add")
        local addedOK,added,reason=false,nil,nil
        if add then addedOK,added,reason=pcall(add,addon.quests,entry.id,map) end
        if addedOK and added then
          addon:Refresh(); addon:Print("Queued active quest: " .. entry.name .. ".")
        else addon:Print(type(reason)=="string" and reason or "Quest waypoint unavailable.") end
      elseif entry.type == "favorite" then
        if not settings.wheelUnlocked then wheel:Close() end
        local ok, selected=pcall(addon.ActivateTarget,addon,entry.id)
        if ok and selected then
          if addon.destinations then addon.destinations:Open() end
          addon:Print("Selected favorite target: " .. entry.name .. ". Route evidence is in Targets.")
        else addon:Print("Favorite is no longer an open target.") end
      elseif entry.type == "removeFavorite" then
        local ok, removed=pcall(addon.travelPoints.RemoveFavorite,addon.travelPoints,entry.id)
        if ok and removed then
          addon:Print("Removed "..entry.name.." from Favorites; target retained.")
          if wheel.frame:IsShown() then wheel:Layout(); wheel:RefreshAppearance() end
        else addon:Print("Favorite could not be removed.") end
      else
        if not settings.wheelUnlocked then wheel:Close() end
        local name = display(entry)
        addon:Print(name .. " selected; not executed." ..
          (entry.type == "addon" and " Open its own settings using that addon's controls." or ""))
      end
    elseif not settings.wheelUnlocked then wheel:Close()
    end
  end)
  frame:SetScript("OnKeyDown", function(_, key)
    if key == "ESCAPE" then wheel:Close() end
  end)
  frame:SetScript("OnReceiveDrag", function()
    if not addon.db.data.settings.wheelUnlocked or wheel.dragIndex then return end
    local index = wheel:IndexAtCursor()
    if wheel:DropNative(index) then
      wheel:Layout(); wheel:RefreshAppearance()
      wheel:Notice("Added preview; game cursor payload was not consumed.")
    end
  end)
  frame:SetScript("OnDragStart", function()
    if not addon.db.data.settings.wheelUnlocked or not outOfCombat() then return end
    wheel.dragIndex = nil
    local selected,_,tier = wheel:IndexAtCursor()
    if wheel.submenu and tier==#wheel.tiers and selected==wheel.count then selected = nil end
    if not selected then
      local x, y = cursorPosition()
      if x and y and (x-wheel.centerX)^2 + (y-wheel.centerY)^2 <
          wheel.tiers[1].innerRadius^2 then wheel:BeginCenterDrag() end
      return
    end
    if wheel.submenu and wheel.submenu ~= "Skills" and wheel.submenu ~= "Items" and
        wheel.submenu ~= "folder" then return end
    local ref=tier and (wheel.submenu=="Skills" and addon.db.data.settings.wheelSkills[selected] or
      wheel.submenu=="Items" and addon.db.data.settings.wheelItems[selected] or
      wheel:TierEntry(selected,tier))
    if not ref then return end
    wheel.dragIndex, wheel.dragTier, wheel.dragEntryRef = selected,tier,ref
    wheel.dragSource=tier==#wheel.tiers and wheel.submenu or nil
    local entry=tier==#wheel.tiers and entryAt(selected) or ref
    if entry then
      local _,texture=entryVisual(entry)
      wheel.dragGhost:SetTexture(texture)
      wheel.dragGhost:SetSize(wheel.tiers[#wheel.tiers].iconSize*1.2,
        wheel.tiers[#wheel.tiers].iconSize*1.2)
      wheel.dragGhost:Show()
      if tier==#wheel.tiers then wheel.slots[selected].texture:SetAlpha(.25)
      else
        local view=wheel.historyViews[tier]
        if view and view.icons[selected] then view.icons[selected]:SetAlpha(.25) end
      end
    end
  end)
  frame:SetScript("OnDragStop", function()
    if wheel.dragCenter then wheel:EndCenterDrag(); return end
    wheel:FinishWheelDrag()
  end)
  frame:SetScript("OnHide", function()
    wheel:StopCapture()
    wheel:CancelWheelDrag()
    wheel.dragCenter = nil
    wheel.hoverIndex,wheel.hoverStart,wheel.hoverRemove=nil,nil,nil
    wheel:RestoreCursor()
  end)
  self.frame = frame
  self.slots = {}
  self.history, self.historyViews, self.layerLinks, self.layerLinksVertical = {}, {}, {}, {}
  self.trim = frame:CreateTexture(nil, "ARTWORK")
  self.centerShadow = frame:CreateTexture(nil, "BACKGROUND",nil,-1)
  self.centerShadow:SetTexture(assetRoot .. "WheelCenter.blp")
  self.centerShadow:SetVertexColor(0,0,0)
  self.centerShadow:SetAlpha(.42)
  self.centerPlate = frame:CreateTexture(nil, "ARTWORK")
  self.centerPlate:SetTexture(assetRoot .. "WheelCenterHover.blp")
  self.centerPlate:Hide()
  self.centerArt = frame:CreateTexture(nil, "ARTWORK")
  self.centerArt:SetTexture(assetRoot .. "WheelCenter.blp")
  local center = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  center:SetText("Wheel")
  self.centerLabel = center
  local centerClose = CreateFrame("Button", nil, frame)
  centerClose:EnableMouse(true)
  centerClose:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  centerClose:RegisterForDrag("LeftButton")
  centerClose:SetScript("OnMouseDown", function() wheel.suppressCenterClick=nil end)
  centerClose:SetScript("OnDragStart", function() wheel:BeginCenterDrag() end)
  centerClose:SetScript("OnDragStop", function()
    if wheel:EndCenterDrag() then wheel.suppressCenterClick=true end
  end)
  centerClose:SetScript("OnClick", function(_,mouse)
    if wheel.suppressCenterClick then wheel.suppressCenterClick=nil; return end
    if mouse=="RightButton" and not wheel.submenu and fullRootNeedsQuests() then
      wheel:Enter("Quests")
      if not wheel.questInventoryAvailable then
        wheel:Notice("Quest log inventory unavailable or incomplete; some zones may be missing.")
      end
      return
    end
    wheel:Close()
  end)
  local closeIcon = centerClose:CreateTexture(nil, "OVERLAY")
  closeIcon:SetAllPoints(centerClose)
  closeIcon:SetTexture(assetRoot .. "PackCross.blp")
  closeIcon:Hide() -- Keep the illustrated hub intact; center still closes/drags.
  centerClose.icon = closeIcon
  self.centerClose = centerClose
  self.dragGhost=frame:CreateTexture(nil,"OVERLAY")
  self.dragGhost:Hide()
  local details = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  details:SetWidth(204); details:SetHeight(92)
  details:SetJustifyH("LEFT"); details:SetJustifyV("TOP")
  self.detailText = details
  local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetWidth(204); hint:SetHeight(34)
  hint:SetJustifyH("LEFT")
  self.hintText = hint
  local function tool(label, action)
    local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    button:SetSize(68, 24)
    button:SetText(label)
    button:SetScript("OnClick", action)
    return button
  end
  self.lockButton = tool("Unlock", function()
    if not outOfCombat() then wheel:Notice("Edit the wheel out of combat."); return end
    local settings = addon.db.data.settings
    settings.wheelUnlocked = not settings.wheelUnlocked
    settings.wheelPinned=nil
    wheel:RefreshAppearance()
  end)
  self.lockIcon = self.lockButton:CreateTexture(nil, "ARTWORK")
  self.lockIcon:SetSize(17, 17)
  self.lockIcon:SetPoint("LEFT", self.lockButton, "LEFT", 2, 0)

  self.closeButton = tool("Close", function() wheel:Close() end)
  local addMenu=CreateFrame("Frame", nil, frame)
  addMenu:SetSize(112,105)
  addMenu:SetFrameStrata("TOOLTIP")
  self.addMenu=addMenu
  self.addButton=tool("+ Add",function() wheel:ShowAddMenu() end)
  local function addAction(text,y,callback)
    local button=CreateFrame("Button",nil,addMenu,"UIPanelButtonTemplate")
    button:SetSize(108,25); button:SetPoint("TOPLEFT",2,y)
    button:SetText(text)
    button:SetScript("OnClick",function()
      addMenu:Hide()
      callback()
    end)
  end
  addAction("+ Folder",-2,function()
    if outOfCombat() and addon.db:WheelInsert({type="folder",name="New folder",entries={}},wheel.editorIndex) then
      wheel:Layout(); wheel:RefreshAppearance()
    end
  end)
  addAction("+ Entry",-29,function() wheel:ShowSettings() end)
  addAction("Icon / Edit",-56,function() wheel:ShowSettings() end)
  addMenu:Hide()
  local outside=CreateFrame("Button",nil,UIParent)
  outside:SetAllPoints(UIParent)
  outside:SetFrameStrata("DIALOG")
  outside:EnableMouse(true)
  outside:SetScript("OnClick",function()
    if not addon.db.data.settings.wheelUnlocked then wheel:Close() end
  end)
  outside:Hide()
  self.outside=outside
  frame:Hide()
  self.buildingFrame=nil
  if UISpecialFrames then table.insert(UISpecialFrames, "ErrandMasterWheel") end
end
function wheel:EnsureSlots(count)
  local frame = self.frame
  for i = #self.slots+1, count do
    local shadow = frame:CreateTexture(nil, "BACKGROUND",nil,0)
    local sector = frame:CreateTexture(nil, "BACKGROUND",nil,1)
    local relief = frame:CreateTexture(nil, "BORDER",nil,0)
    local glow = frame:CreateTexture(nil, "BORDER",nil,1)
    local iconGlow = frame:CreateTexture(nil, "BORDER",nil,2)
    iconGlow:SetBlendMode("ADD")
    local medallionGlow = frame:CreateTexture(nil, "BORDER",nil,3)
    medallionGlow:SetBlendMode("ADD")
    local medallion = frame:CreateTexture(nil, "OVERLAY",nil,6)
    local activeMedallion = frame:CreateTexture(nil, "OVERLAY",nil,7)
    activeMedallion:SetAlpha(0)
    local borderGlow = frame:CreateTexture(nil, "OVERLAY",nil,1)
    borderGlow:SetBlendMode("ADD")
    borderGlow:SetAlpha(0)

    local texture = frame:CreateTexture(nil, "ARTWORK",nil,1)
    texture:SetTexture(icon)
    texture:SetTexCoord(0, 1, 0, 1) -- Never crop the player's icon artwork.
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local badge = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badge:SetPoint("TOPRIGHT", texture, "TOPRIGHT", 4, 4)
    self.slots[i] = {shadow=shadow,relief=relief,sector=sector, glow=glow,
      iconGlow=iconGlow,medallionGlow=medallionGlow,medallion=medallion,
      activeMedallion=activeMedallion,borderGlow=borderGlow,glowAlpha=0,
      texture=texture, label=text, badge=badge}
  end
  for i = count+1, #self.slots do
    self.slots[i].shadow:Hide()
    self.slots[i].iconGlow:Hide()
    self.slots[i].medallionGlow:Hide()
    self.slots[i].relief:Hide()
    self.slots[i].sector:Hide()
    self.slots[i].glow:Hide()
    self.slots[i].medallion:Hide()
    self.slots[i].activeMedallion:Hide()
    self.slots[i].borderGlow:Hide()
    self.slots[i].texture:Hide()
    self.slots[i].label:Hide()
    self.slots[i].badge:Hide()
  end
end
function wheel:SetEditing(enabled)
  if not outOfCombat() then return false end
  local settings=addon.db.data.settings
  settings.wheelUnlocked=not not enabled
  settings.wheelPinned=nil
  if enabled and (not self.frame or not self.frame:IsShown()) then
    local opened=self:Open()
    if not opened then settings.wheelUnlocked=false end
    return opened
  end
  if self.frame and self.frame:IsShown() then
    self:Layout(); self:RefreshAppearance()
  end
  return true
end
function wheel:ToggleUnlock()
  return self:SetEditing(not addon.db.data.settings.wheelUnlocked)
end
function wheel:ShowAddMenu(index)
  if not addon.db.data.settings.wheelUnlocked then return end
  self.editorIndex=index
  if self.addMenu then
    if self.addMenu:IsShown() then self.addMenu:Hide() else self.addMenu:Show() end
  end
end
function wheel:SelectCategory(category)
  if category=="Edit Wheel" or category=="Lock Wheel" then
    if not outOfCombat() then self:Notice("Edit the wheel out of combat."); return end
    self:ToggleUnlock()
    return
  end
  category = ({["Personal Bank"]="Bank", Food="Food Vendor", Reagents="Reagent Vendor", Ammo="Ammo Vendor",
    ["General Goods"]="Vendor", Inbox="Mailbox"})[category] or category
  if (category == "AddOns Settings" or category=="Settings") and addon.addonSettings then
    if not addon.db.data.settings.wheelUnlocked then self:Close() end
    addon.addonSettings:Open(); return
  elseif category == "New Errand" then
    addon.ui:OpenCategory("Custom"); return
  elseif category == "Saved Errands" and addon.ui and addon.ui.frame then
    addon.ui:Refresh(); addon.ui.frame:Show(); return
  elseif category == "Pin" then
    if not addon.db.data.settings.wheelUnlocked then self:Close() end
    if addon.worldMap and type(addon.worldMap.Open)=="function" then
      local ok, opened=pcall(addon.worldMap.Open,addon.worldMap)
      if ok and opened then
        addon.worldMap.pinMode=true
        addon:Print("Waypoint: left-click the displayed map to place your pin; close the map to cancel.")
        return
      end
    end
    addon:Print("Map unavailable; could not start waypoint pinning."); return
  elseif category == "Select Current" then
    local ok,selected,message=pcall(addon.travelPoints.SelectCurrent,addon.travelPoints)
    addon:Print(ok and selected and "Selected saved map waypoint; route evidence is in Targets." or
      (ok and message or "Could not select the saved waypoint.")); return
  elseif category == "Add Coordinates" then
    if not addon.db.data.settings.wheelUnlocked then self:Close() end
    local ok,opened=pcall(addon.travelPoints.OpenFavoriteForm,addon.travelPoints)
    if not ok or not opened then addon:Print("Could not open favorite coordinate form.") end
    return
  elseif category == "Active Quests" then
    addon.ui:OpenCategory("Quest"); return
  elseif category == "Portal" or category == "Boat" then
    addon:Print(category .. " routes need verified destination data; no route was queued."); return
  elseif category == "Hearthstone" then
    addon:Print("Hearthstone use needs an in-client secure action; the wheel does not cast items."); return
  end
  if not quickServices[category] and not category:match(" Vendor$") and
      not category:match(" Trainer$") or not addon.errands then
    addon.ui:OpenCategory(category)
    return
  end
  for _, task in ipairs(addon.errands:All()) do
    if task.category == category and task.origin == "suggested" and not task.completed then
      addon:Print("Already queued: " .. task.name .. ".")
      return
    end
  end
  local ok, task = pcall(addon.errands.Add, addon.errands, {
    name="Nearest " .. category, category=category, origin="suggested", scope="character"})
  if not ok then addon:Print("Could not queue " .. category .. "."); return end
  addon:Refresh()
  addon:Print("Queued " .. category .. "; route recalculated from current NPC candidates and observed evidence. Direct proximity is not a walking path.")
  return task
end
local function nearestPreview(category, map, x, y, width, height)
  if not quickServices[category] or not addon.npcs or
      not addon.npcs:IsReady() then return end
  local searches={category}
  if category == "Class Trainer" then
    local class = addon.discovery and addon.discovery:PlayerClass()
    if not safeLabel(class) then return end
    searches={class .. " Trainer"}
  elseif category == "Profession Trainer" and addon.ProfessionFilters then
    local names=addon:ProfessionFilters()
    if #names>0 then
      searches={}
      for _,name in ipairs(names) do searches[#searches+1]=name.." Trainer" end
    end
  end
  local nearest
  for _,wanted in ipairs(searches) do
    local ok, matches = pcall(addon.npcs.Nearest,addon.npcs,
      map,x,y,wanted,width,height,1)
    if ok and usable(matches) and type(matches)=="table" and
        usable(matches[1]) and type(matches[1])=="table" then
      local candidate=matches[1]
      if not nearest or (type(candidate.directYards)=="number" and
          (type(nearest.directYards)~="number" or
           candidate.directYards<nearest.directYards)) then nearest=candidate end
    end
  end
  if not nearest then return end
  local name, yards = nearest.name, nearest.directYards
  if not safeLabel(name) then return end
  local label=name:sub(1,20)
  if #name>20 then label=label.."..." end
  local distance=usable(yards) and type(yards)=="number" and yards>=0 and
    yards<10000000 and string.format("~%.0f yd direct",yards) or "map proximity only"
  return label.." ("..distance..")"
end
local function previewEntryAt(index)
  local proposed=wheel.previewInsert
  if proposed then
    if index==proposed then return wheel.previewPayload end
    if index>proposed then index=index-1 end
  end
  return entryAt(index)
end
function wheel:Layout()
  if not self.frame then return end
  local settings = addon.db.data.settings
  self.menuEntries = self.submenu and self.submenu ~= "folder" and submenuEntries() or nil
  local count = self.menuEntries and #self.menuEntries or
    self.submenu == "folder" and #((self.folderRef or settings.wheelSlots[self.folderIndex]).entries)+1 or
    (settings.wheelSlots and #settings.wheelSlots or #categories)
  local actualCount=count
  if self.previewInsert then count=count+1 end -- visual-only proposed slot
  self:EnsureSlots(count)
  local depth = #self.history+1
  local counts, parents = {}, {}
  for i,parent in ipairs(self.history) do
    counts[i],parents[i]=parent.count,parent.selected
  end
  counts[depth]=count
  local model=geometry.layout(counts,parents,settings.wheelRadius,
    settings.wheelIconSize,settings.wheelScale,self.screenWidth,self.screenHeight,
    self.layoutX or self.cursorX,self.layoutY or self.cursorY)
  self.model,self.tiers=model,model.tiers
  self.artFit=model.fit
  local rootOuter=self.tiers[1].outerRadius
  local rootCount=self.tiers[1].count
  local fit=model.fit
  local active=self.tiers[depth]
  local outerRadius=active.outerRadius
  self.centerX,self.centerY=model.x,model.y
  local margin=model.extent
  self.frame:SetSize(margin*2,margin*2)
  self.frame:ClearAllPoints()
  self.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX, self.centerY)
  self.radius,self.count=active.radius,count
  self.outerRadius=outerRadius
  self.trim:SetTexture(assetRoot .. string.format("WheelTrim%02d.blp",rootCount))
  self.trim:SetSize(rootOuter*2,rootOuter*2)
  self.trim:ClearAllPoints()
  self.trim:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX, self.centerY)
  self.trim:Hide() -- Wedge borders, not a colored disk, define the outline.
  local hubDiameter=self.tiers[1].innerRadius*2
  self.centerShadow:SetSize(hubDiameter*1.02,hubDiameter*1.02)
  self.centerShadow:ClearAllPoints()
  self.centerShadow:SetPoint("CENTER",UIParent,"BOTTOMLEFT",self.centerX,self.centerY-3*fit)
  self.centerShadow:Show()
  -- Source has a transparent fringe; the visible hub must stay within the aperture.
  self.centerArt:SetSize(hubDiameter*.92,hubDiameter*.92)
  self.centerArt:SetVertexColor(1,1,1)
  self.centerArt:ClearAllPoints()
  -- Supplied rim center is (255.11,245.57) on its 512px canvas.
  -- Align the rim rather than the canvas; preserve source pixels and hit geometry.
  local hubArtSize=hubDiameter*.92
  self.centerArt:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
    self.centerX+hubArtSize*.00075, self.centerY-hubArtSize*.0194)
  self.centerPlate:SetSize(hubDiameter*.92,hubDiameter*.92)
  self.centerPlate:ClearAllPoints()
  self.centerPlate:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX, self.centerY)
  self.vectors = {}
  self.previews = {}
  local artSupported = true
  local map, px, py, width, height
  if addon.npcs and type(addon.Position)=="function" then
    local ok, id, x, y = pcall(addon.Position,addon)
    if ok and usable(id) and usable(x) and usable(y) and
        type(id)=="number" and type(x)=="number" and type(y)=="number" and
        x>=0 and x<=1 and y>=0 and y<=1 then map,px,py=id,x,y end
    if map and type(addon.MapWorldSize)=="function" then
      local valid, w, h=pcall(addon.MapWorldSize,addon,map)
      if valid then width,height=w,h end
    end
  end
  local previewCache={}
  self.centerLabel:ClearAllPoints()
  self.centerLabel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX, self.centerY)
  self.centerLabel:SetWidth(hubDiameter*.86)
  self.centerLabel:SetHeight(hubDiameter*.70)
  self.centerLabel:SetTextHeight(12)
  self.centerLabel:SetWordWrap(true)
  self.centerLabel:SetNonSpaceWrap(true)
  self.centerLabel:SetText(settings.wheelUnlocked and "EDIT MODE" or "")
  self.centerPlate:Hide(); self.centerArt:Show()
  self.centerLabel:Show()
  self.centerClose:SetSize(hubDiameter,hubDiameter)
  self.centerClose:ClearAllPoints()
  self.centerClose:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX, self.centerY)
  for _, button in ipairs({self.lockButton,self.closeButton}) do
    button:Hide()
  end
  self.addButton:ClearAllPoints()
  self.addButton:SetPoint("CENTER",UIParent,"BOTTOMLEFT",self.centerX+rootOuter*.7,self.centerY+rootOuter*.7)
  if settings.wheelUnlocked and not self.submenu then self.addButton:Show()
  else self.addButton:Hide(); self.addMenu:Hide() end
  self.addMenu:ClearAllPoints()
  self.addMenu:SetPoint("TOPLEFT",self.addButton,"BOTTOMLEFT",0,-3)
  local detailsX = self.centerX + outerRadius + 18
  if detailsX+208>self.screenWidth-8 then detailsX=self.centerX-outerRadius-226 end
  detailsX=math.max(8,math.min(self.screenWidth-212,detailsX))
  self.detailText:Hide()
  self.hintText:ClearAllPoints()
  self.hintText:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", detailsX,
    self.centerY - 50)
  for i = 1, count do
    local slot = self.slots[i]
    slot.previewX,slot.previewY=nil,nil
    slot.texture:Show(); slot.badge:Hide()
    slot.badge:SetText(self.activeIndex == i and ("A" .. i) or tostring(i))
    slot.badge:SetTextColor(self.activeIndex == i and 1 or .95,
      self.activeIndex == i and .82 or .95, self.activeIndex == i and .25 or .95)
    local entry=previewEntryAt(i)
    local name, texture = entryVisual(entry)
    if map and entry and entry.type=="category" then
      local category=entry.category
      if previewCache[category]==nil then
        previewCache[category]=nearestPreview(category,map,px,py,width,height) or false
      end
      local preview=previewCache[category]
      if preview then self.previews[i]=preview end
    end
    slot.label:SetText(wheelLabel(name))
    slot.label:Hide()
    local ix,iy=geometry.icon(active,i)
    slot.texture:SetTexture(texture)
    slot.texture:SetDesaturated(false)
    local angle = active.angles[i]
    local vector = {math.cos(angle), math.sin(angle)}
    self.vectors[i] = vector
    local tierAsset=math.min(depth-1,2)
    local art=assetRoot..string.format("WheelPatternT%dN%02d.blp",tierAsset,count)
    local glow=assetRoot..string.format("WheelBorderT%dN%02d.blp",tierAsset,count)
    slot.sector:SetTexture(art)
    slot.glow:SetTexture(glow)
    slot.medallion:SetTexture(medallionPath(entryColor(entry),false))
    slot.iconGlow:SetTexture(medallionPath(entryColor(entry),true))
    slot.iconGlow:SetSize(active.iconSize*1.5,active.iconSize*1.5)
    slot.iconGlow:ClearAllPoints()
    slot.iconGlow:SetPoint("CENTER",UIParent,"BOTTOMLEFT",self.centerX+ix,self.centerY+iy)
    slot.iconGlow:SetAlpha(.10);slot.iconGlow:Show()
    slot.medallionGlow:SetTexture(medallionPath(entryColor(entry),true))
    placeMedallion(slot.medallionGlow,active,angle,self.centerX,self.centerY,fit)
    slot.medallionGlow:SetAlpha(.10)
    slot.activeMedallion:SetTexture(medallionPath(entryColor(entry),true))
    slot.medallion:SetDesaturated(entryColor(entry)=="White")
    slot.activeMedallion:SetDesaturated(entryColor(entry)=="White")
    placeMedallion(slot.medallion,active,angle,self.centerX,self.centerY,fit)
    placeMedallion(slot.activeMedallion,active,angle,self.centerX,self.centerY,fit)
    slot.shadow:SetTexture(assetRoot..string.format("WheelShadowT%dN%02d.blp",tierAsset,count))
    slot.relief:SetTexture(assetRoot..string.format("WheelReliefT%dN%02d.blp",tierAsset,count))
    slot.borderGlow:SetTexture(assetRoot..string.format("WheelHaloT%dN%02d.blp",tierAsset,count))
    slot.shadow:SetAlpha(.72);slot.relief:SetAlpha(.30)
    local shade,color=(slot.shadowTint or 0)*.30,slot.shadowColor or {0,0,0}
    slot.shadow:SetVertexColor(color[1]*shade,color[2]*shade,color[3]*shade)
    for _, region in ipairs({slot.shadow,slot.sector,slot.relief,slot.glow,slot.borderGlow}) do
      region:ClearAllPoints()
      region:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX,
        self.centerY-(region==slot.shadow and 3*fit or 0))
      local rotation=angle-math.pi/2
      if not rotateArt(region,geometry.artDiameter(outerRadius),rotation) then artSupported=false end
      region:Show()
    end
    slot.texture:SetSize(active.iconSize,active.iconSize)
    slot.texture:ClearAllPoints()
    slot.texture:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
      self.centerX + ix,self.centerY + iy)
    slot.label:Hide()
  end
  if not artSupported then
    -- Unknown client texture rotation: keep the usable icon wheel, not piled-up pie art.
    for i = 1, count do
      self.slots[i].sector:Hide(); self.slots[i].glow:Hide()
      self.slots[i].shadow:Hide();self.slots[i].relief:Hide()
      self.slots[i].borderGlow:Hide()
    end
  end
  self:RenderHistory()
  if self.selected then
    local selected=self.selected
    self.selected=nil
    self:SetSelection(selected)
  end
end
function wheel:SetSelection(index)
  if self.selected == index then return end
  self.selected = index
  for i = 1, self.count or 0 do
    local slot = self.slots[i]
    local color = swatchRGB[entryColor(previewEntryAt(i))] or swatchRGB.Slate
    slot.sector:SetVertexColor(color[1], color[2], color[3])
    slot.sector:SetAlpha(.94 + (slot.glowAlpha or 0)*.06)
    slot.glow:SetVertexColor(1,1,1)
    slot.glow:SetAlpha(.86)
    slot.borderGlow:SetVertexColor(color[1],color[2],color[3])
    slot.glowTarget=i==index and 1 or 0
    slot.shadowColor=color
    slot.shadowTarget=i==index and 1 or 0
    if i == index then
      slot.texture:SetVertexColor(1, 1, 1)
      slot.texture:SetAlpha(1)
      slot.label:SetTextColor(.98, .94, .84)
    else
      slot.texture:SetVertexColor(1, 1, 1)
      slot.texture:SetAlpha(1)
      slot.label:SetTextColor(.78, .82, .85)
    end
  end
  local entry=index and index>0 and entryAt(index)
  local name=entry and entryVisual(entry)
  self.centerLabel:SetText(name and wheelLabel(name) or
    (addon.db.data.settings.wheelUnlocked and "EDIT MODE" or ""))
  if name then self.centerArt:Hide(); self.centerPlate:Show()
  else self.centerPlate:Hide(); self.centerArt:Show() end
  self.centerLabel:Show()
  self.detailText:Hide()
end
function wheel:IndexAtCursor(allowOutside)
  local x, y = cursorPosition()
  if not x or not self.centerX or not self.tiers then return end
  local index,level=geometry.hit(self.nativeBaseModel or self.model,x,y)
  if not index and allowOutside then
    local dx,dy=x-self.centerX,y-self.centerY
    return nil,dx*dx+dy*dy>(self.outerRadius+4)^2
  end
  return index,nil,level
end
function wheel:RefreshAppearance()
  if not self.frame then return end
  local settings = addon.db.data.settings
  self.lockButton:SetText(settings.wheelUnlocked and "Lock" or "Edit")
  self.lockIcon:SetTexture(assetRoot .. (settings.wheelUnlocked and
    "PackPadlockLocked.blp" or "PackPadlockUnlocked.blp"))
  self.centerClose:Show()


  if self.outside then
    if settings.wheelUnlocked then self.outside:Hide() else self.outside:Show() end
  end
  self.hintText:SetText(settings.wheelUnlocked and
    "Drag to insert; hover to group. Drop spells/items here." or
    "")
  local selected = self.selected
  self.selected = 0
  self:SetSelection(selected)
end
function wheel:UpdateHighlight()
  if not self.frame or not self.frame:IsShown() then return end
  local x, y = cursorPosition()
  if not x then self:SetSelection(nil); return end
  local index,_,level=self:IndexAtCursor()
  self:SetSelection(level==#self.tiers and index or nil)
end
function wheel:RestoreCursor()
  if self.cursorAttempted and type(SetCursor) == "function" then pcall(SetCursor, nil) end
  self.cursorAttempted = nil
end
function wheel:ResetMaterials()
  self.materialTime=0
  for _,slot in ipairs(self.slots or {}) do
    slot.glowAlpha,slot.glowTarget=0,0
    slot.shadowTint,slot.shadowTarget=0,0
    slot.shadow:SetVertexColor(0,0,0)
    slot.iconGlow:SetAlpha(.10)
    slot.medallionGlow:SetAlpha(.10)
    slot.activeMedallion:SetAlpha(0)
    slot.borderGlow:SetAlpha(0)
    slot.relief:SetAlpha(.30)
  end
end
function wheel:Close()
  -- A deliberate dismissal exits editing; never persist an invisible editor.
  addon.db.data.settings.wheelUnlocked=false
  self:StopCapture()
  self.nativePreview,self.nativeTarget,self.nativeBaseModel=nil,nil,nil
  self.previewInsert,self.previewPayload=nil,nil
  if self.dragGhost then self.dragGhost:Hide() end
  if self.outside then self.outside:Hide() end
  if self.addMenu then self.addMenu:Hide() end
  if self.frame and self.frame:IsShown() then self.frame:Hide() end
  self:RestoreCursor()
  self.suppressCenterClick = nil
  self:ResetMaterials()
  self.history = {}
  if self.historyViews then self:RenderHistory() end
  self.layoutX, self.layoutY = nil, nil
  self.selected = nil
  self.submenu = nil
  self.submenuParent = nil
  self.menuEntries = nil
  self.folderIndex,self.folderRef = nil,nil
end
function wheel:TryOpen()
  if not outOfCombat() then return false end
  self:Create()
  if self.frame:IsShown() then
    if addon.db.data.settings.wheelUnlocked then return true end
    self:Close(); return false
  end
  self:ResetMaterials() -- Also covers reopening after a direct hide.
  local x, y, width, height = cursorPosition()
  if not x then return false end
  self.cursorX, self.cursorY = x, y
  self.layoutX, self.layoutY = nil, nil
  self.screenWidth, self.screenHeight = width, height
  local saved = addon.db.data.settings.wheelCenter
  if saved then
    self.cursorX, self.cursorY = saved.x * width, saved.y * height
  end
  self:Layout()
  self:SetSelection(0) -- Force an initial unselected render.
  self:SetSelection(nil)
  self:RefreshAppearance()
  self.frame:Show()
  animate(self.frame)
  if fullRootNeedsQuests() then
    self:Notice("Wheel has 24 entries. Right-click the center for Quests; saved slots stay unchanged.")
  end
  return true
end

function wheel:Fail(message)
  self:StopCapture()
  local frame=self.frame or self.buildingFrame
  if frame then
    pcall(frame.SetScript,frame,"OnUpdate",nil)
    pcall(frame.SetScript,frame,"OnHide",nil)
    pcall(frame.UnregisterAllEvents,frame)
    pcall(frame.EnableKeyboard,frame,false)
    pcall(frame.EnableMouse,frame,false)
    pcall(frame.Hide,frame)
  end
  if self.outside then pcall(self.outside.Hide,self.outside) end
  pcall(self.RestoreCursor,self)
  self.frame,self.buildingFrame=nil,nil
  self.dragIndex,self.dragCenter,self.submenu=nil,nil,nil
  self.history={}
  local detail=usable(message) and type(message)=="string" and message or "unknown UI error"
  detail=detail:gsub("|","||"):sub(1,350)
  if self.lastFailure~=detail then
    self.lastFailure=detail
    if addon.Print then addon:Print("Wheel stopped safely: "..detail) end
  end
  self:Notice("Wheel stopped safely; see the error in chat.")
end
function wheel:Open()
  local ok,result=pcall(self.TryOpen,self)
  if not ok then self:Fail(result);return false end
  return result
end

function wheel:Notice(message)
  if addon.addonSettings and type(addon.addonSettings.Notice)=="function" then
    addon.addonSettings:Notice(message)
  end
  if self.status then self.status:SetText(message) end
  if self.frame and self.frame:IsShown() and self.hintText then
    self.hintText:SetText(message)
  end
end
function wheel:AssignSlot()
  if not outOfCombat() then self:Notice("Change wheel slots out of combat."); return false end
  local ok, slotText, kind, value = pcall(function()
    return self.slotNumber:GetText(), self.slotType:GetText(), self.slotValue:GetText()
  end)
  if not ok or not usable(kind) or not usable(value) then
    self:Notice("Invalid slot entry."); return false
  end
  local slot = numeric(slotText, 24)
  if not slot then self:Notice("Choose a slot from 1 to 24."); return false end
  local entry
  if kind == "category" and safeLabel(value) and #value <= 40 then
    entry = {type=kind, category=value}
  elseif kind == "addon" and safeLabel(value) and #value <= 40 then
    entry = {type=kind, name=value}
  elseif kind == "spell" or kind == "macro" or kind == "item" then
    local id = numeric(value, 2147483647)
    if id then
      local macroName = kind == "macro" and apiMethod(C_Macro, "GetMacroName")
      if macroName then
        local found, name = pcall(macroName, id)
        if not found or not safeLabel(name) then
          self:Notice("Macro ID not found; choose an existing macro."); return false
        end
      end
      entry = {type=kind, id=id}
    end
  end
  if not entry then self:Notice("Use a category/addon name or a positive spell/item/macro ID."); return false end
  local settings = addon.db.data.settings
  if type(settings.wheelSlots) ~= "table" or not usable(settings.wheelSlots) then
    settings.wheelSlots = {}
    for i, category in ipairs(categories) do
      settings.wheelSlots[i] = {type="category", category=category}
    end
  end
  if slot > #settings.wheelSlots + 1 then
    self:Notice("Add the next empty slot first."); return false
  end
  if addon.db.WheelReplace then
    local success = slot == #settings.wheelSlots + 1 and addon.db:WheelInsert(entry) or
      addon.db:WheelReplace(slot, entry)
    if not success then self:Notice("Entry rejected."); return false end
  else settings.wheelSlots[slot] = entry end
  self:RefreshEditor()
  self:Notice("Slot " .. slot .. " set to " .. display(entry) .. ".")
  return true
end
function wheel:StopCapture()
  if not self.capture then return end
  pcall(self.capture.EnableKeyboard, self.capture, false)
  pcall(self.capture.EnableMouse, self.capture, false)
  pcall(self.capture.Hide, self.capture)
end
function wheel:BindingText()
  if type(GetBindingKey) ~= "function" then return "Key: unavailable (use WoW Key Bindings)" end
  local ok, key = pcall(GetBindingKey, ACTION)
  if not ok or (key and not usable(key)) then return "Key: unavailable (use WoW Key Bindings)" end
  return "Key: " .. (key or "not set")
end
function wheel:EnsureCapture()
  if self.capture then return true end
  if type(CreateFrame) ~= "function" then return false end
  local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent)
  if not ok or not frame then return false end
  local ready = pcall(function()
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableKeyboard(false)
    frame:EnableMouse(false)
    frame:SetPropagateKeyboardInput(false)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:SetScript("OnEvent", function() wheel:StopCapture() end)
    frame:SetScript("OnHide", function()
      frame:EnableKeyboard(false)
      frame:EnableMouse(false)
    end)
    frame:SetScript("OnKeyDown", function(_, key) wheel:BindKey(key) end)
    frame:SetScript("OnMouseDown", function(_, button) wheel:BindMouse(button) end)
    frame:Hide()
  end)
  if not ready then return false end
  self.capture = frame
  return true
end
function wheel:StartCapture()
  if not outOfCombat() then self:Notice("Change bindings out of combat."); return false end
  if not self:EnsureCapture() then
    self:Notice("Key capture unavailable; use WoW Key Bindings."); return false
  end
  local ok = pcall(function()
    self.capture:EnableKeyboard(true)
    self.capture:EnableMouse(true)
    self.capture:SetPropagateKeyboardInput(false)
  end)
  if not ok then
    self:StopCapture()
    self:Notice("Key capture unavailable; use WoW Key Bindings.")
    return false
  end
  if not pcall(self.capture.Show, self.capture) then
    self:StopCapture()
    self:Notice("Key capture unavailable; use WoW Key Bindings.")
    return false
  end
  self:Notice("Press a free key or mouse button; Escape cancels.")
  return true
end
function wheel:BindMouse(button)
  if not usable(button) or type(button) ~= "string" then return end
  local primary = {LeftButton="BUTTON1", RightButton="BUTTON2", MiddleButton="BUTTON3"}
  local key = primary[button]
  if not key then
    local number = button:match("^Button(%d+)$")
    if number and tonumber(number) >= 1 and tonumber(number) <= 31 then
      key = "BUTTON" .. tonumber(number)
    end
  end
  if key then self:BindKey(key)
  else self:Notice("Mouse button not reported by the game; press another or Escape.") end
end
function wheel:BindKey(key)
  if not usable(key) or type(key) ~= "string" then
    self:StopCapture(); self:Notice("Key state unavailable; use WoW Key Bindings."); return
  end
  if key == "ESCAPE" then self:StopCapture(); self:Notice("Binding canceled."); return end
  if not outOfCombat() then self:StopCapture(); self:Notice("Change bindings out of combat."); return end
  if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or
      key == "LALT" or key == "RALT" then return end
  if not key:match("^[A-Z0-9]+$") then
    self:Notice("Key not reported by the game; press another or Escape."); return
  end
  local function modifierState(api)
    if not usable(api) or type(api) ~= "function" then return end
    local ok, held = pcall(api)
    if ok and usable(held) and type(held) == "boolean" then return held end
  end
  local shift = modifierState(IsShiftKeyDown)
  local control = modifierState(IsControlKeyDown)
  local alt = modifierState(IsAltKeyDown)
  if shift == nil or control == nil or alt == nil then
    self:StopCapture(); self:Notice("Modifier state unavailable; use WoW Key Bindings."); return
  end
  local modifiers = ""
  if shift then modifiers = modifiers .. "SHIFT-" end
  if control then modifiers = modifiers .. "CTRL-" end
  if alt then modifiers = modifiers .. "ALT-" end
  key = modifiers .. key
  if type(GetBindingAction) ~= "function" or type(SetBinding) ~= "function" or
      type(SaveBindings) ~= "function" or type(GetCurrentBindingSet) ~= "function" then
    self:StopCapture(); self:Notice("Binding API unavailable; use WoW Key Bindings."); return
  end
  local ok, action = pcall(GetBindingAction, key)
  if not ok or (action and not usable(action)) then
    self:StopCapture(); self:Notice("Binding lookup unavailable."); return
  end
  if action and action ~= "" and action ~= ACTION then
    self:Notice(key .. " is already bound. Press another key or Escape."); return
  end
  local oldOK, oldKey, secondKey = pcall(GetBindingKey, ACTION)
  if not oldOK or (oldKey and not usable(oldKey)) or
      (secondKey and not usable(secondKey)) then
    self:StopCapture(); self:Notice("Binding lookup unavailable."); return
  end
  if oldKey == key and not secondKey then
    self:StopCapture(); self:Notice("Already bound to " .. key .. "."); return
  end
  local modeOK, mode = pcall(GetCurrentBindingSet)
  if not modeOK or not usable(mode) or (mode ~= 1 and mode ~= 2) then
    self:StopCapture(); self:Notice("Binding set unavailable."); return
  end
  local bound, result = pcall(SetBinding, key, ACTION)
  if not bound or not result then
    self:StopCapture(); self:Notice("Binding rejected; use WoW Key Bindings."); return
  end
  local function rollback()
    pcall(SetBinding, key)
    if oldKey then pcall(SetBinding, oldKey, ACTION) end
    if secondKey then pcall(SetBinding, secondKey, ACTION) end
  end
  for i = 1, 2 do
    local prior = i == 1 and oldKey or secondKey
    if prior and prior ~= key then
      local removed, removal = pcall(SetBinding, prior)
      if not removed or not removal then
        rollback()
        self:StopCapture(); self:Notice("Could not replace existing key; use WoW Key Bindings.")
        return
      end
    end
  end
  local keysOK, first, second = pcall(GetBindingKey, ACTION)
  if not keysOK or (first ~= key and second ~= key) or
      (first and first ~= key) or (second and second ~= key) then
    rollback()
    self:StopCapture(); self:Notice("Binding replacement not confirmed; use WoW Key Bindings.")
    return
  end
  local saved, savedResult = pcall(SaveBindings, mode)
  local verified, newAction = pcall(GetBindingAction, key)
  if not saved or savedResult == false or not verified or
      not usable(newAction) or newAction ~= ACTION then
    rollback()
    self:StopCapture()
    self:Notice("Could not save binding; use WoW Key Bindings.")
    return
  end
  self:StopCapture()
  if self.bindingLabel then self.bindingLabel:SetText("Key: " .. key) end
  self:Notice("Wheel key set: " .. key .. ".")
end
cursorEntry = function()
  if not usable(GetCursorInfo) or type(GetCursorInfo) ~= "function" then return end
  local ok, kind, position, _, spellID = pcall(GetCursorInfo)
  if not ok or not usable(kind) then return end
  local id
  if kind == "spell" then id = spellID -- First cursor value is not a spell ID.
  elseif kind == "macro" then id = position
  elseif kind == "item" then
    local cursorItem, itemID = apiMethod(C_Cursor, "GetCursorItem"), apiMethod(C_Item, "GetItemID")
    if cursorItem and itemID then
      local found, location = pcall(cursorItem)
      if found and usable(location) then
        local resolved, value = pcall(itemID, location)
        if resolved then id = value end
      end
    end
  else return end
  if not usable(id) or
      type(id) ~= "number" or id % 1 ~= 0 or id < 1 or id > 2147483647 then return end
  -- A cursor is inspected only: never pick up, use, cast or clear its payload.
  return {type=kind, id=id}
end
function wheel:RefreshEditor()
  if not self.editorRows then return end
  local slots = addon.db.data.settings.wheelSlots
  if not slots then return end
  local pageCount = math.max(1, math.ceil(#slots / #self.editorRows))
  self.editorPage = math.min(math.max(1, self.editorPage or 1), pageCount)
  for rowIndex, button in ipairs(self.editorRows) do
    local index = (self.editorPage-1)*#self.editorRows + rowIndex
    local entry = slots[index]
    button.slotIndex = entry and index or nil
    if entry then
      local name = display(entry)
      button:SetText(string.format("%s %d. %s%s", self.activeIndex == index and "Active" or "   ",
        index, name, entry.type == "folder" and " [folder]" or ""))
      button:Show()
    else button:Hide() end
  end
  if self.editorLabel then
    local selection = self.editorIndex and slots[self.editorIndex]
    self.editorLabel:SetText(string.format("%d/24 entries - page %d/%d - %s", #slots,
      self.editorPage, pageCount,
      selection and ("Selected #" .. self.editorIndex .. ": " .. display(selection)) or "Select an entry"))
  end
  if self.folderLabel then
    local folder = self.editorIndex and slots[self.editorIndex]
    self.folderLabel:SetText(folder and folder.type == "folder" and
      ("Folder: " .. folder.name .. " - " .. #folder.entries .. "/8 items") or
      "Hold over an entry while dragging to make a folder.")
    for i, button in ipairs(self.folderRows or {}) do
      local item = folder and folder.type == "folder" and folder.entries[i]
      if item then button:SetText(i .. ". " .. display(item)); button:Show()
      else button:Hide() end
    end
  end
end
function wheel:Choose(index)
  local slots = addon.db.data.settings.wheelSlots
  if not slots or not slots[index] then return end
  self.editorIndex = index
  self.slotNumber:SetText(tostring(index))
  local entry = slots[index]
  self.slotType:SetText(entry.type)
  self.slotValue:SetText(entry.category or entry.name or (entry.id and tostring(entry.id)) or "")
  self:RefreshEditor()
end
function wheel:DropEntry(entry, target, hovered)
  if not outOfCombat() then self:Notice("Edit the wheel out of combat."); return false end
  if self.submenu == "folder" then
    local folder=self.folderRef or addon.db.data.settings.wheelSlots[self.folderIndex]
    local parent=folder and addon.db:WheelFindPath(folder)
    if parent and target and target>=1 and target<=#folder.entries+1 then
      parent[#parent+1]=target
      if addon.db:WheelAddEntry(parent,entry,"insert") then
        self:Layout(); self:RefreshAppearance(); self:Notice("Added to folder (preview only).")
        return true
      end
    end
    return false
  end
  if self.submenu and self.submenu ~= "folder" then
    if self.submenu ~= "Skills" and self.submenu ~= "Items" then
      self:Notice("Drop onto the top wheel or into Skills / Items."); return false
    end
    local kind = self.submenu == "Skills" and "spell" or "item"
    if addon.db:WheelCollectionAdd(kind, entry) then
      self:Layout(); self:RefreshAppearance()
      self:Notice("Added to " .. self.submenu .. "; preview only.")
      return true
    end
    self:Notice("Drop a " .. kind .. " into " .. self.submenu .. " (up to 23).")
    return false
  end
  local slots = addon.db.data.settings.wheelSlots
  if target and not slots[target] then return false end
  local db = addon.db
  local success
  if target and hovered and hovered >= .45 and self:OverIcon(target) then
    local raw = self.folderName and self.folderName:GetText()
    local name = usable(raw) and safeLabel(raw) and #raw <= 40 and raw or "New folder"
    success=db:WheelAddEntry({target},entry,"group",name)
  else success = db:WheelAddEntry({target or #slots+1},entry,"insert") end
  if success then
    self.activeIndex = nil
    self:Notice("Entry added. Selection previews only; no spell or macro executed.")
    self:RefreshEditor()
    animate(self.settingsFrame)
  else self:Notice("Drop rejected (invalid entry or wheel/folder full).") end
  return success
end
function wheel:DropNative(target)
  local entry = cursorEntry()
  local success=false
  local emptyContainer=self.count==1 and
    (self.submenu=="folder" or self.submenu=="Skills" or self.submenu=="Items")
  if not entry then
    self:Notice("Drop a spell, item, or macro from a game panel.")
  elseif not target or target<1 or not entryAt(target) or
      (entryAt(target).category=="Back" and self.submenu~="folder" and not emptyContainer) then
    self:Notice("Drop on the ring, not the center or outside it.")
  else
    -- Preview and commit both classify the occupied icon by position, not dwell.
    success=self:DropEntry(entry,target,self:OverIcon(target) and 1 or 0)
  end
  self.nativePreview,self.nativeTarget,self.nativeBaseModel=nil,nil,nil
  self.previewInsert,self.previewPayload=nil,nil
  if self.dragGhost then self.dragGhost:Hide() end
  for _,slot in ipairs(self.slots or {}) do slot.previewX,slot.previewY=nil,nil end
  if self.frame and self.frame:IsShown() then self:Layout();self:RefreshAppearance() end
  -- No ClearCursor/SetCursor: only our preview is owned by the addon.
  return success
end
function wheel:FinishDrag()
  local source, target = self.dragIndex, self.hoverIndex
  local hoverStart, remove = self.hoverStart, self.hoverRemove
  self.dragIndex, self.hoverIndex, self.hoverStart, self.hoverRemove = nil, nil, nil, nil
  if not source or not outOfCombat() then return end
  if remove then
    if addon.db:WheelRemove(source) then
      self.activeIndex, self.editorIndex = nil, nil
      self:Notice("Entry removed."); self:RefreshEditor(); animate(self.settingsFrame)
    end
    return
  end
  if not target or target == source then return end
  local elapsed = 0
  if hoverStart and type(GetTime) == "function" then
    local ok, now = pcall(GetTime)
    if ok and usable(now) and type(now) == "number" then elapsed = now - hoverStart end
  end
  local success
  if elapsed >= .45 then
    local name = self.folderName:GetText()
    success = addon.db:WheelFolder(source, target, name ~= "" and name or "New folder")
  else success = addon.db:WheelMove(source, target) end
  if success then
    self.editorIndex, self.activeIndex = nil, nil
    self:Notice(elapsed >= .45 and "Folder created. Name it in the editor." or "Wheel reordered.")
    self:RefreshEditor()
    animate(self.settingsFrame)
  end
end
function wheel:AddNamedEntry()
  if not outOfCombat() then return false end
  local kind, value = self.slotType:GetText(), self.slotValue:GetText()
  if not usable(kind) or not usable(value) then return false end
  local entry
  if kind == "category" and safeLabel(value) and #value <= 40 then
    entry = {type=kind, category=value}
  elseif kind == "addon" and safeLabel(value) and #value <= 40 then
    entry = {type=kind, name=value}
  elseif kind == "spell" or kind == "macro" or kind == "item" then
    local id = numeric(value, 2147483647)
    if id then entry = {type=kind, id=id} end
  end
  if not entry then self:Notice("Enter category, addon, spell, item or macro with a valid value."); return false end
  return self:DropEntry(entry)
end
function wheel:BrowseAddOn()
  -- Add-ons do not supply a standard draggable cursor payload. Browse installed names instead.
  local method = apiMethod(C_AddOns, "GetAddOnName")
  local countMethod = apiMethod(C_AddOns, "GetNumAddOns")
  if not method and usable(GetAddOnInfo) and type(GetAddOnInfo) == "function" then method = GetAddOnInfo end
  if not countMethod and usable(GetNumAddOns) and type(GetNumAddOns) == "function" then countMethod = GetNumAddOns end
  if not method or not countMethod then self:Notice("Add-on listing unavailable; enter its name manually."); return end
  local ok, count = pcall(countMethod)
  if not ok or not usable(count) or type(count) ~= "number" or count < 1 or count > 1000 then return end
  for _ = 1, count do
    self.addonCursor = (self.addonCursor or 0) % count + 1
    local found, name = pcall(method, self.addonCursor)
    if found and safeLabel(name) and #name <= 40 then
      self.slotType:SetText("addon"); self.slotValue:SetText(name)
      self:Notice("Add-on " .. self.addonCursor .. "/" .. count .. ": " .. name .. ". Click Add entry.")
      return
    end
  end
end
function wheel:RefreshSettings()
  if not self.settingsFrame then return end
  local settings = addon.db.data.settings
  self.sizeLabel:SetText(string.format("Radius %d  -  Icon %d  -  Scale %.2f  -  Theme %s",
    settings.wheelRadius, settings.wheelIconSize, settings.wheelScale or 1,
    settings.wheelTheme or "Azure"))
  self.bindingLabel:SetText(self:BindingText())
  if self.professionStatus and addon.ProfessionFilters then
    local names,source=addon:ProfessionFilters()
    local label=#names>0 and table.concat(names, ", ") or "not detected; add manually"
    if #label>48 then label=label:sub(1,45).."..." end
    self.professionStatus:SetText("Professions ("..source.."): "..label)
  end
  self:RefreshEditor()
  self:RefreshColor()
end
function wheel:ChangeProfession(mode)
  if not outOfCombat() then self:Notice("Change professions out of combat."); return end
  if mode=="auto" then addon.db:ClearProfessions()
  else
    local ok,name=pcall(self.professionInput.GetText,self.professionInput)
    if not ok or not safeLabel(name) then
      self:Notice("Enter a profession name first."); return
    end
    local changed=mode=="add" and addon.db:AddProfession(name) or
      addon.db:RemoveProfession(name)
    if not changed then self:Notice("Profession unchanged; check name or duplicate."); return end
  end
  self:RefreshSettings()
  addon:Refresh()
end
function wheel:FitSettings()
  if not self.settingsFrame then return end
  local ok, width, height = pcall(function() return UIParent:GetWidth(), UIParent:GetHeight() end)
  if not ok or not usable(width) or not usable(height) or
      type(width) ~= "number" or type(height) ~= "number" or
      width ~= width or height ~= height or width <= 0 or height <= 0 then return end
  local scale = math.min(1, (width - 32) / 745, (height - 32) / 755)
  if scale > .2 then pcall(self.settingsFrame.SetScale, self.settingsFrame, scale) end
end
function wheel:ShowSettings()
  if addon.addonSettings then addon.addonSettings:Open('layout') end
end
