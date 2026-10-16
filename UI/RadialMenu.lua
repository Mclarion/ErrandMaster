local _, addon = ...
addon.radial = {}
local wheel = addon.radial
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
  Quests={"Active Quests", "Back"},
}
local quickServices = {Repair=true, Bank=true, ["Auction House"]=true,
  Mailbox=true, Vendor=true, ["Class Trainer"]=true,
  ["Profession Trainer"]=true, ["Ammo Vendor"]=true,
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
local swatches = {"Red", "Amber", "Green", "Blue", "Gold", "Violet", "Magenta",
  "Teal", "Copper", "Rose", "Slate"}
local swatchRGB = {Copper={.68,.47,.27}, Amber={.95,.63,.27}, Green={.30,.77,.43},
  Blue={.35,.55,.89}, Teal={.29,.75,.84}, Violet={.68,.45,.84},
  Rose={1,.50,.68}, Slate={.68,.77,.82}, Red={.84,.27,.28},
  Gold={.95,.75,.29}, Magenta={.77,.34,.73}}
local function colorKey(entry)
  if not entry then return end
  if entry.type == "category" then return entry.category end
  if entry.type == "folder" then return "Folder" end
  if entry.type == "quest" then return "Quests" end
  if entry.type == "favorite" or entry.type == "removeFavorite" then return "Favorites" end
  if wheel.submenu == "Skills" or wheel.submenu == "Items" then return wheel.submenu end
  return "Preview"
end
local function entryColor(entry)
  if not entry then return "Slate" end
  local category = colorKey(entry)
  local overrides = addon.db.data.settings.wheelCategoryColors
  if type(overrides) == "table" and overrides[category] then return overrides[category] end
  if category == "Folder" then return "Blue" end
  if category == "Preview" then return "Rose" end
  if category == "Food" then return "Red" end
  if category == "Reagents" then return "Violet" end
  if category == "Ammo" then return "Copper" end
  if category == "Blacksmithing Vendor" then return "Amber" end
  if category:find("Vendor", 1, true) or category == "Profession Supplies" or
      category == "General Goods" then return "Green" end
  if category:find("Trainer", 1, true) or category == "Trainer" then return "Blue" end
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
local function safeLabel(value)
  return usable(value) and type(value) == "string" and #value > 0 and
    #value <= 80 and not value:find("[%c|]")
end
local function numeric(text, max)
  if not usable(text) or type(text) ~= "string" or not text:match("^%d+$") then return end
  local value = tonumber(text)
  if value and value >= 1 and value <= max and value % 1 == 0 then return value end
end
local function submenuEntries()
  local selected = wheel.submenu
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
  if selected == "Active Quests" then
    local result = {}
    if addon.quests and type(addon.quests.OnMap) == "function" and
        type(addon.Position) == "function" then
      local positionOK, map = pcall(addon.Position, addon)
      if positionOK and type(map) == "number" then
        local ok, available = pcall(addon.quests.OnMap, addon.quests, map)
        if ok and type(available) == "table" then
          for _,quest in ipairs(available) do
            if type(quest) == "table" and type(quest.questID) == "number" and
                safeLabel(quest.title) and #quest.title <= 80 and #result < 23 then
              result[#result+1] = {type="quest", id=quest.questID,
                mapID=map, name=quest.title}
            end
          end
        end
      end
    end
    result[#result+1] = {type="category", category="Back"}
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
    local result, seen, known = {}, {}, {}
    if type(addon.ProfessionFilters) == "function" then
      local ok, names = pcall(addon.ProfessionFilters, addon)
      if ok and usable(names) and type(names) == "table" then known = names end
    end
    local allowed, primary = {}, {}
    for _, name in ipairs(primaryProfessions) do allowed[name] = true; primary[name] = true end
    for _, name in ipairs(commonProfessions) do allowed[name] = true end
    local function add(name)
      if allowed[name] and not seen[name] then
        result[#result+1] = {type="category", category=name ..
          (selected == "Profession Trainer" and " Trainer" or " Vendor")}
        seen[name] = true
      end
    end
    for i=1,math.min(#known, 24) do
      local name=known[i]
      if usable(name) and type(name)=="string" then add(name) end
    end
    local hasPrimary=false
    for name in pairs(primary) do
      if seen[name] then hasPrimary=true; break end
    end
    if not hasPrimary then for _, name in ipairs(primaryProfessions) do add(name) end end
    for _, name in ipairs(commonProfessions) do add(name) end
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
    local folder = addon.db.data.settings.wheelSlots[wheel.folderIndex]
    if index == #folder.entries + 1 then return {type="category", category="Back"} end
  end
  local ok, entry = pcall(function()
    local slots = addon.db.data.settings.wheelSlots
    if not usable(slots) or type(slots) ~= "table" then return end
    local item
    if wheel.submenu == "folder" then item = slots[wheel.folderIndex].entries[index]
    else item = slots[index] end
    if type(item) ~= "table" or not usable(item) then return end
    local kind = item.type
    if not usable(kind) then return end
    if kind == "category" and safeLabel(item.category) and #item.category <= 40 then
      return {type="category", category=item.category}
    end
    if (kind == "spell" or kind == "macro") and usable(item.id) and
        type(item.id) == "number" and item.id >= 1 and item.id <= 2147483647 and
        item.id % 1 == 0 then return {type=kind, id=item.id} end
    if kind == "item" and usable(item.id) and type(item.id) == "number" and
        item.id >= 1 and item.id <= 2147483647 and item.id % 1 == 0 then
      return {type="item", id=item.id}
    end
    if (kind == "folder" or kind == "addon") and safeLabel(item.name) then
      return {type=kind, name=item.name}
    end
  end)
  return ok and entry or (not wheel.submenu and index <= #categories and
    {type="category", category=categories[index]} or nil)
end
local function display(entry)
  if not entry then return "", icon end
  if entry.type == "quest" then return entry.name, assetRoot .. "ServiceQuests.blp" end
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
    elseif entry.category == "Profession Vendor" or entry.category == "Profession Supplies" then
      return entry.category, assetRoot .. "PackProfessionVendor.blp"
    elseif entry.category == "Herbalism Vendor" then
      return entry.category, assetRoot .. "PackHerbalismVendor.blp"
    elseif entry.category == "Herbalism Trainer" then
      return entry.category, assetRoot .. "PackHerbalismTrainer.blp"
    elseif entry.category == "Fishing Trainer" then
      return entry.category, assetRoot .. "PackFishingTrainer.blp"
    elseif entry.category == "Fishing Vendor" then
      return entry.category, assetRoot .. "PackFishing.blp"
    elseif entry.category == "Alchemy Trainer" then
      return entry.category, assetRoot .. "PackAlchemyTrainer.blp"
    elseif entry.category == "Alchemy Vendor" then
      return entry.category, assetRoot .. "PackAlchemyVendor.blp"
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
    local service = ({Repair="Repair", ["Auction House"]="Auction",
      Mailbox="Mail", Inbox="Mail", Custom="Custom", Settings="Custom",
      ["New Errand"]="Custom", ["Saved Errands"]="Custom",
      Favorites="Favorites", Trainer="Trainer", Travel="Travel",
      Quests="Quests", ["Active Quests"]="Quests", Skills="Skills",
      Items="Items", ["Flight Master"]="Flight", Portal="Portal",
      Boat="Boat", Hearthstone="Hearthstone", ["General Goods"]="Vendor",
      Food="Vendor", Reagents="Vendor", Ammo="Vendor",
      ["Profession Supplies"]="Vendor"})[entry.category]
    if not service and entry.category:find("Vendor", 1, true) then service="Vendor" end
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
  name = name:match("^[^\n]+") or ""
  if name == "Auction House" then return "Auction" end
  if name == "Class Trainer" then return "Trainer" end
  if #name <= 11 then return name end
  local cut = 9
  while cut > 1 and name:byte(cut + 1) >= 128 and
      name:byte(cut + 1) <= 191 do cut = cut - 1 end
  return name:sub(1, cut) .. "..."
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

function wheel:ChildCenter(parent, outer)
  local direction = parent.vector or {1, 0}
  local distance = parent.outer * .65 + outer + 24
  local turns = {0, math.pi/4, -math.pi/4, math.pi/2,
    -math.pi/2, 3*math.pi/4, -3*math.pi/4, math.pi}
  local bestX, bestY, bestScore
  for _, turn in ipairs(turns) do
    local x = parent.x + distance *
      (direction[1]*math.cos(turn) - direction[2]*math.sin(turn))
    local y = parent.y + distance *
      (direction[1]*math.sin(turn) + direction[2]*math.cos(turn))
    local margin = outer + 64
    local outside = math.max(0, margin-x, x-(self.screenWidth-margin),
      margin-y, y-(self.screenHeight-margin))
    local score = outside * 30 + math.abs(turn) * 35
    for _, older in ipairs(self.history) do
      if older ~= parent then
        local separation = math.sqrt((x-older.x)^2 + (y-older.y)^2)
        score = score + math.max(0, older.outer*.65 + outer + 16 - separation) * 20
      end
    end
    if not bestScore or score < bestScore then bestX,bestY,bestScore=x,y,score end
  end
  return bestX, bestY
end

function wheel:Enter(menu, index, folder)
  local parent = {menu=self.submenu, parent=self.submenuParent,
    folder=self.folderIndex, x=self.centerX, y=self.centerY,
    radius=self.radius, outer=self.outerRadius, count=self.count,
    vector=self.vectors[index], entries={}}
  for i=1,self.count do
    local entry = entryAt(i)
    local name, texture = display(entry)
    local base = type(texture) == "string" and
      texture:sub(1,#assetRoot) == assetRoot and
      texture:sub(#assetRoot+1):match("^([%w_]+)%.blp$")
    local blurred = base and (base:match("^Pack") or
      base:match("^Class") or base:match("^Service")) and
      assetRoot .. "Soft" .. base .. ".blp"
    parent.entries[i] = {name=wheelLabel(name), texture=blurred or texture,
      color=swatchRGB[entryColor(entry)] or swatchRGB.Slate}
  end
  self.history[#self.history+1] = parent
  self.submenuParent, self.submenu, self.folderIndex = self.submenu, menu, folder
  local entries = menu == "folder" and
    addon.db.data.settings.wheelSlots[folder].entries or submenuEntries()
  local count = #entries + (menu == "folder" and 1 or 0)
  local radius, icon = outerSize(math.max(1,count), #self.history, self)
  self.layoutX, self.layoutY = self:ChildCenter(parent, radius + icon*.9)
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
  self.layoutX, self.layoutY = parent.x, parent.y
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
      view = {icons={}, labels={}, rim=self.frame:CreateTexture(nil,"BORDER"),
        hub=self.frame:CreateTexture(nil,"ARTWORK"),
        tag=self.frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")}
      self.historyViews[depth] = view
    end
    local extent = parent.outer * .65
    view.rim:SetTexture(assetRoot .. string.format("WheelTrim%02d.blp", parent.count))
    view.rim:SetSize(extent*2, extent*2)
    view.rim:ClearAllPoints()
    view.rim:SetPoint("CENTER", UIParent, "BOTTOMLEFT", parent.x, parent.y)
    view.rim:SetAlpha(.35); view.rim:Show()
    view.hub:SetTexture(assetRoot .. "WheelCenter.blp")
    view.hub:SetSize(extent*.62, extent*.62)
    view.hub:ClearAllPoints()
    view.hub:SetPoint("CENTER", UIParent, "BOTTOMLEFT", parent.x, parent.y)
    view.hub:SetAlpha(.28); view.hub:Show()
    view.tag:SetText(parent.menu or "MAIN")
    view.tag:ClearAllPoints()
    view.tag:SetPoint("CENTER", UIParent, "BOTTOMLEFT", parent.x, parent.y)
    view.tag:SetAlpha(.58); view.tag:Show()
    for i, item in ipairs(parent.entries) do
      if not view.icons[i] then
        view.icons[i] = self.frame:CreateTexture(nil,"OVERLAY")
        view.labels[i] = self.frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
      end
      local angle = math.pi/2 - (i-1)*2*math.pi/parent.count
      local x = parent.x + math.cos(angle)*parent.radius*.65
      local y = parent.y + math.sin(angle)*parent.radius*.65
      local image = view.icons[i]
      image:SetTexture(item.texture)
      image:SetSize(math.min(28,extent*.32), math.min(28,extent*.32))
      image:ClearAllPoints()
      image:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
      if type(image.SetDesaturated)=="function" then
        pcall(image.SetDesaturated,image,true)
      end
      image:SetAlpha(.38); image:Show()
      local label = view.labels[i]
      label:SetText(item.name)
      label:ClearAllPoints()
      label:SetPoint("TOP", image, "BOTTOM", 0, -1)
      label:SetAlpha(.35)
      if parent.count <= 6 then label:Show() else label:Hide() end
    end
    for i=#parent.entries+1,#view.icons do
      view.icons[i]:Hide(); view.labels[i]:Hide()
    end
    local nextTier = self.history[depth+1]
    local toX, toY = nextTier and nextTier.x or self.centerX,
      nextTier and nextTier.y or self.centerY
    local dx, dy = toX-parent.x, toY-parent.y
    local distance = math.sqrt(dx*dx+dy*dy)
    local line = self.layerLinks[depth]
    if not line then
      line = self.frame:CreateTexture(nil,"BACKGROUND")
      line:SetTexture("Interface\\Buttons\\WHITE8X8")
      line:SetVertexColor(.93,.69,.36)
      self.layerLinks[depth] = line
    end
    local endRadius = nextTier and nextTier.outer*.65 or self.outerRadius
    if distance < 1 then
      line:Hide()
      if self.layerLinksVertical[depth] then self.layerLinksVertical[depth]:Hide() end
    else
      local fromX, fromY = parent.x+dx*extent/distance, parent.y+dy*extent/distance
      local endX, endY = toX-dx*endRadius/distance, toY-dy*endRadius/distance
      local length = math.max(1, distance-extent-endRadius)
      line:SetSize(length, 3)
      line:ClearAllPoints()
      line:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
        (fromX+endX)/2, (fromY+endY)/2)
      line:SetAlpha(.55)
      local angle = dx == 0 and (dy >= 0 and math.pi/2 or -math.pi/2) or
        math.atan(dy/dx) + (dx < 0 and math.pi or 0)
      if type(line.SetRotation)=="function" and pcall(line.SetRotation,line,angle) then
        line:Show()
        if self.layerLinksVertical[depth] then self.layerLinksVertical[depth]:Hide() end
      else
        -- Rotation may be unavailable: join the tiers with two straight segments.
        line:SetSize(math.max(1,math.abs(endX-fromX)),3)
        line:ClearAllPoints()
        line:SetPoint("CENTER",UIParent,"BOTTOMLEFT",(fromX+endX)/2,fromY)
        line:Show()
        local vertical=self.layerLinksVertical[depth]
        if not vertical then
          vertical=self.frame:CreateTexture(nil,"BACKGROUND")
          vertical:SetTexture("Interface\\Buttons\\WHITE8X8")
          vertical:SetVertexColor(.93,.69,.36)
          self.layerLinksVertical[depth]=vertical
        end
        vertical:SetSize(3,math.max(1,math.abs(endY-fromY)))
        vertical:ClearAllPoints()
        vertical:SetPoint("CENTER",UIParent,"BOTTOMLEFT",endX,(fromY+endY)/2)
        vertical:SetAlpha(.55); vertical:Show()
      end
    end
  end
  for i=#self.history+1,#self.historyViews do
    local view=self.historyViews[i]
    view.rim:Hide(); view.hub:Hide(); view.tag:Hide()
    for _, image in ipairs(view.icons) do image:Hide() end
    for _, label in ipairs(view.labels) do label:Hide() end
  end
  for i=#self.history+1,#self.layerLinks do self.layerLinks[i]:Hide() end
  for i=#self.history+1,#self.layerLinksVertical do self.layerLinksVertical[i]:Hide() end
end

function wheel:Create()
  if self.frame then return end
  local frame = CreateFrame("Frame", "ErrandMasterWheel", UIParent)
  frame:SetSize(340, 340) -- Only the wheel intercepts clicks; pinned bags stay usable.
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:SetScript("OnEvent", function() wheel:Close() end)
  frame:SetScript("OnUpdate", function()
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
  end)
  frame:SetScript("OnMouseDown", function(_, mouse)
    if mouse ~= "LeftButton" and mouse ~= "RightButton" then return end
    wheel:UpdateHighlight()
    local index = wheel.selected
    local settings = addon.db.data.settings
    if mouse == "LeftButton" and wheel.submenu and index and
        entryAt(index) and entryAt(index).category == "Back" then
      wheel:GoBack()
      return
    end
    if settings.wheelUnlocked then
      if mouse == "LeftButton" and index and not wheel.submenu then
        local selectedEntry = entryAt(index)
        local category = selectedEntry and selectedEntry.type == "category" and
          selectedEntry.category
        if category == "Skills" or category == "Items" then
          wheel:Enter(category, index)
          return
        end
      end
      if index and index > 0 and not wheel.submenu then
        wheel.editorIndex = index
        if mouse == "RightButton" then wheel:ChangeColor(false); wheel:RefreshAppearance()
        else wheel:Notice("Drag to move, drag out to remove, or drop a bag item.") end
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
          if category == "Quests" and not addon.quests then
            wheel:Notice("Active quest locations unavailable."); return
          end
          wheel:Enter(category, index)
          return
        elseif ((category == "Profession Vendor" or category == "Profession Supplies") and
            wheel.submenu == "Vendor") or
            (category == "Profession Trainer" and wheel.submenu == "Trainer") then
          wheel:Enter(category, index)
          return
        elseif category == "Active Quests" and wheel.submenu == "Quests" then
          wheel.submenu = category
          local empty = #submenuEntries() == 1
          wheel.submenu = "Quests"
          if empty then
            wheel:Notice("No active quest POIs on this map.")
            return
          end
          wheel:Enter(category, index)
          return
        elseif (category == "Waypoint" or category == "Favorites") and
            wheel.submenu == "Travel" or
            (category == "Current Favorites" or category == "Remove Favorite") and
            wheel.submenu == "Favorites" then
          wheel:Enter(category, index)
          if wheel.count==1 then wheel:Notice("No open favorites. Add coordinates or mark a target Fav.") end
          return
        end
        if not settings.wheelPinned then wheel:Close() end
        wheel:SelectCategory(category)
      elseif entry.type == "folder" then
        wheel:Enter("folder", index, index)
      elseif entry.type == "quest" then
        if not settings.wheelPinned then wheel:Close() end
        local ok, added, reason = pcall(addon.quests.Add, addon.quests, entry.id, entry.mapID)
        if ok and added then
          addon:Refresh(); addon:Print("Queued active quest: " .. entry.name .. ".")
        else addon:Print(type(reason)=="string" and reason or "Quest waypoint unavailable.") end
      elseif entry.type == "favorite" then
        if not settings.wheelPinned then wheel:Close() end
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
        if not settings.wheelPinned then wheel:Close() end
        local name = display(entry)
        addon:Print(name .. " selected; not executed." ..
          (entry.type == "addon" and " Open its own settings using that addon's controls." or ""))
      end
    elseif not settings.wheelPinned then wheel:Close()
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
    local selected = wheel:IndexAtCursor()
    if wheel.submenu and selected == wheel.count then selected = nil end
    if not selected then
      local x, y = cursorPosition()
      if x and y and (x-wheel.centerX)^2 + (y-wheel.centerY)^2 <
          (wheel.radius * .43)^2 then wheel:BeginCenterDrag() end
      return
    end
    if wheel.submenu and wheel.submenu ~= "Skills" and wheel.submenu ~= "Items" then return end
    wheel.dragIndex = selected
  end)
  frame:SetScript("OnDragStop", function()
    if wheel.dragCenter then wheel:EndCenterDrag(); return end
    local source = wheel.dragIndex
    wheel.dragIndex = nil
    if not source or not outOfCombat() then return end
    local target, outside = wheel:IndexAtCursor(true)
    local changed
    if wheel.submenu == "Skills" or wheel.submenu == "Items" then
      local kind = wheel.submenu == "Skills" and "spell" or "item"
      if outside then changed = addon.db:WheelCollectionRemove(kind, source)
      elseif target and target < wheel.count then
        changed = addon.db:WheelCollectionMove(kind, source, target) end
    elseif outside then changed = addon.db:WheelRemove(source)
    elseif target then changed = addon.db:WheelMove(source, target) end
    if changed then
      wheel.editorIndex = nil
      wheel:Layout(); wheel:RefreshAppearance()
      wheel:Notice(outside and "Removed entry." or "Wheel order changed.")
    end
  end)
  frame:SetScript("OnHide", function()
    wheel.dragIndex = nil
    wheel.dragCenter = nil
    wheel:RestoreCursor()
  end)
  self.frame = frame
  self.slots = {}
  self.history, self.historyViews, self.layerLinks, self.layerLinksVertical = {}, {}, {}, {}
  self.trim = frame:CreateTexture(nil, "ARTWORK")
  self.centerArt = frame:CreateTexture(nil, "ARTWORK")
  self.centerArt:SetTexture(assetRoot .. "WheelCenter.blp")
  local center = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  center:SetText("Wheel")
  self.centerLabel = center
  local centerClose = CreateFrame("Button", nil, frame)
  centerClose:EnableMouse(true)
  centerClose:RegisterForDrag("LeftButton")
  centerClose:SetScript("OnMouseDown", function() wheel.suppressCenterClick=nil end)
  centerClose:SetScript("OnDragStart", function() wheel:BeginCenterDrag() end)
  centerClose:SetScript("OnDragStop", function()
    if wheel:EndCenterDrag() then wheel.suppressCenterClick=true end
  end)
  centerClose:SetScript("OnClick", function()
    if wheel.suppressCenterClick then wheel.suppressCenterClick=nil; return end
    wheel:Close()
  end)
  local closeIcon = centerClose:CreateTexture(nil, "OVERLAY")
  closeIcon:SetAllPoints(centerClose)
  closeIcon:SetTexture(assetRoot .. "PackCross.blp")
  centerClose.icon = closeIcon
  self.centerClose = centerClose
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
    if settings.wheelUnlocked then settings.wheelPinned = true end
    wheel:RefreshAppearance()
  end)
  self.lockIcon = self.lockButton:CreateTexture(nil, "ARTWORK")
  self.lockIcon:SetSize(17, 17)
  self.lockIcon:SetPoint("LEFT", self.lockButton, "LEFT", 2, 0)
  self.pinButton = tool("Pin", function()
    local settings = addon.db.data.settings
    settings.wheelPinned = not settings.wheelPinned
    wheel:RefreshAppearance()
  end)
  self.colorButton = tool("Color", function()
    if not addon.db.data.settings.wheelUnlocked or not wheel.selected or
        wheel.selected == 0 or wheel.submenu then return end
    wheel.editorIndex = wheel.selected
    wheel:ChangeColor(false)
    wheel:RefreshAppearance()
  end)
  self.closeButton = tool("Close", function() wheel:Close() end)
  frame:Hide()
  if UISpecialFrames then table.insert(UISpecialFrames, "ErrandMasterWheel") end
end
function wheel:EnsureSlots(count)
  local frame = self.frame
  for i = #self.slots+1, count do
    local sector = frame:CreateTexture(nil, "BACKGROUND")
    local glow = frame:CreateTexture(nil, "BORDER")
    glow:SetBlendMode("ADD")
    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetTexture(icon)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local badge = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badge:SetPoint("TOPRIGHT", texture, "TOPRIGHT", 4, 4)
    self.slots[i] = {sector=sector, glow=glow, texture=texture, label=text, badge=badge}
  end
  for i = count+1, #self.slots do
    self.slots[i].sector:Hide()
    self.slots[i].glow:Hide()
    self.slots[i].texture:Hide()
    self.slots[i].label:Hide()
    self.slots[i].badge:Hide()
  end
end
function wheel:SelectCategory(category)
  category = ({["Personal Bank"]="Bank", Food="Food Vendor", Reagents="Reagent Vendor", Ammo="Ammo Vendor",
    ["General Goods"]="Vendor", Inbox="Mailbox"})[category] or category
  if category == "Settings" and addon.addonSettings then
    addon.addonSettings:Open(); return
  elseif category == "New Errand" then
    addon.ui:OpenCategory("Custom"); return
  elseif category == "Saved Errands" and addon.ui and addon.ui.frame then
    addon.ui:Refresh(); addon.ui.frame:Show(); return
  elseif category == "Pin" then
    wheel:Close()
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
    wheel:Close()
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
function wheel:Layout()
  if not self.frame then return end
  local settings = addon.db.data.settings
  self.menuEntries = self.submenu and self.submenu ~= "folder" and submenuEntries() or nil
  local count = self.menuEntries and #self.menuEntries or
    self.submenu == "folder" and #(settings.wheelSlots[self.folderIndex].entries)+1 or
    (settings.wheelSlots and #settings.wheelSlots or #categories)
  self:EnsureSlots(count)
  local radius, iconSize = outerSize(count, #self.history, self)
  local outerRadius = radius + iconSize * .9
  self.centerX = math.max(outerRadius + 64,
    math.min(self.screenWidth - outerRadius - 64, self.layoutX or self.cursorX))
  self.centerY = math.max(outerRadius + 64,
    math.min(self.screenHeight - outerRadius - 64, self.layoutY or self.cursorY))
  self.frame:SetSize((outerRadius + 64) * 2, (outerRadius + 64) * 2)
  self.frame:ClearAllPoints()
  self.frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX, self.centerY)
  self.radius, self.count = radius, count
  self.outerRadius = outerRadius
  self.trim:SetTexture(assetRoot .. string.format("WheelTrim%02d.blp", count))
  self.trim:Show()
  self.trim:SetSize(outerRadius * 2, outerRadius * 2)
  self.trim:ClearAllPoints()
  self.trim:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX, self.centerY)
  self.centerArt:SetSize(outerRadius * .63, outerRadius * .63)
  local theme = palettes[settings.wheelTheme] or palettes.Azure
  self.centerArt:SetVertexColor(.65 + theme[1]*.35,
    .65 + theme[2]*.35, .65 + theme[3]*.35)
  self.centerArt:ClearAllPoints()
  self.centerArt:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX, self.centerY)
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
  self.centerLabel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX, self.centerY - 28)
  self.centerLabel:SetText(addon.db.data.settings.wheelUnlocked and "EDIT" or "WHEEL")
  self.centerClose:SetSize(math.min(44, outerRadius * .29), math.min(44, outerRadius * .29))
  self.centerClose:ClearAllPoints()
  self.centerClose:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX, self.centerY + 8)
  local rail = {self.lockButton, self.pinButton, self.colorButton, self.closeButton}
  for i, button in ipairs(rail) do
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
      self.centerX - 142 + (i-1)*72, self.centerY + outerRadius + 50)
  end
  local detailsX = self.centerX + outerRadius + 18
  if detailsX + 208 > self.screenWidth - 8 then
    detailsX = self.centerX - outerRadius - 226
  end
  self.detailText:ClearAllPoints()
  self.detailText:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", detailsX,
    self.centerY + 45)
  self.hintText:ClearAllPoints()
  self.hintText:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", detailsX,
    self.centerY - 50)
  for i = 1, count do
    local slot = self.slots[i]
    slot.texture:Show(); slot.badge:Show()
    slot.badge:SetText(self.activeIndex == i and ("A" .. i) or tostring(i))
    slot.badge:SetTextColor(self.activeIndex == i and 1 or .95,
      self.activeIndex == i and .82 or .95, self.activeIndex == i and .25 or .95)
    local entry=entryAt(i)
    local name, texture = display(entry)

    if map and entry and entry.type=="category" then
      local category=entry.category
      if previewCache[category]==nil then
        previewCache[category]=nearestPreview(category,map,px,py,width,height) or false
      end
      local preview=previewCache[category]
      if preview then self.previews[i]=preview end
    end
    slot.label:SetText(wheelLabel(name))
    slot.label:SetWidth(math.max(34, math.min(88, radius * 2 * math.pi / count * .8)))
    slot.label:SetHeight(17)
    slot.label:SetJustifyH("CENTER")
    if count <= 14 then slot.label:Show() else slot.label:Hide() end
    slot.texture:SetTexture(texture)
    local angle = math.pi / 2 - (i - 1) * 2 * math.pi / count
    local vector = {math.cos(angle), math.sin(angle)}
    self.vectors[i] = vector
    local art = assetRoot .. string.format("WheelSector%02d.blp", count)
    local glow = assetRoot .. string.format("WheelGlow%02d.blp", count)
    slot.sector:SetTexture(art)
    slot.glow:SetTexture(glow)
    for _, region in ipairs({slot.sector, slot.glow}) do
      region:SetSize(outerRadius * 2, outerRadius * 2)
      region:ClearAllPoints()
      region:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX, self.centerY)
      if i > 1 then
        local ok = type(region.SetRotation) == "function" and
          pcall(region.SetRotation, region,
            (addon.db.data.settings.wheelArtReversed and 1 or -1) *
            (i-1) * 2 * math.pi / count)
        if not ok then artSupported = false end
      end
      region:Show()
    end
    slot.texture:SetSize(iconSize, iconSize)
    slot.texture:ClearAllPoints()
    slot.texture:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
      self.centerX + vector[1]*radius*(count <= 3 and .76 or 1),
      self.centerY + vector[2]*radius*(count <= 3 and .76 or 1))
    slot.label:ClearAllPoints()
    slot.label:SetPoint("TOP", slot.texture, "BOTTOM", 0, -2)
  end
  if not artSupported then
    -- Unknown client texture rotation: keep the usable icon wheel, not piled-up pie art.
    for i = 1, count do self.slots[i].sector:Hide(); self.slots[i].glow:Hide() end
    self.trim:Hide()
  end
  self:RenderHistory()
end
function wheel:SetSelection(index)
  if self.selected == index then return end
  self.selected = index
  for i = 1, self.count or 0 do
    local slot = self.slots[i]
    local color = swatchRGB[entryColor(entryAt(i))] or swatchRGB.Slate
    slot.sector:SetVertexColor(color[1], color[2], color[3])
    slot.sector:SetAlpha(i == index and .88 or .57)
    slot.glow:SetVertexColor(color[1], color[2], color[3])
    slot.glow:SetAlpha(i == index and .85 or .025)
    if i == index then
      slot.texture:SetVertexColor(1, 1, 1)
      slot.texture:SetAlpha(1)
      slot.label:SetTextColor(.98, .94, .84)
    else
      slot.texture:SetVertexColor(1, 1, 1)
      slot.texture:SetAlpha(.92)
      slot.label:SetTextColor(.78, .82, .85)
    end
  end
  self.centerLabel:SetText(index and index > 0 and
    string.format("%d / %d", index, self.count) or
    (addon.db.data.settings.wheelUnlocked and "EDIT" or "WHEEL"))
  local entry = index and index > 0 and entryAt(index)
  local name = entry and display(entry)
  if name then name = name:gsub("|", "/"):gsub("[%c]", " ") end
  local location=entry and entry.mapID and entry.x and entry.y and
    string.format("\nMap %d: %.1f, %.1f",entry.mapID,entry.x*100,entry.y*100) or ""
  local action=entry and ((entry.type=="favorite" and "Click to activate target") or
    (entry.type=="removeFavorite" and "Click to unstar; target retained") or
    (entry.type=="category" and ({Back="Return one tier",Pin="Open map, then click to pin",
      ["Select Current"]="Activate the saved map point",
      ["Add Coordinates"]="Enter Name; map ID; X; Y"})[entry.category]) or
    (entry.type=="folder" and "Open folder") or
    (entry.type=="category" and "Click to queue") or "Preview only")
  self.detailText:SetText(name and (name .. location ..
    (self.previews[index] and "\n" .. self.previews[index] or "") ..
    "\n" .. (addon.db.data.settings.wheelUnlocked and
      ("Color: " .. entryColor(entry) .. "   •   Preview only") or
      action)) or
    (addon.db.data.settings.wheelUnlocked and
      "EDIT WHEEL\nDrag center to move; drag slots to reorder. Drop bag items." or
      "Choose a service\nTomTom follows the active target."))
end
function wheel:IndexAtCursor(allowOutside)
  local x, y = cursorPosition()
  if not x or not self.centerX or not self.radius then return end
  local dx, dy = x-self.centerX, y-self.centerY
  local distance = dx*dx + dy*dy
  if distance > (self.outerRadius + 26)^2 then return nil, allowOutside and true end
  if distance < (self.radius * .43)^2 then return end
  local best, score = nil, -math.huge
  for i, vector in ipairs(self.vectors or {}) do
    local dot = dx*vector[1] + dy*vector[2]
    if dot > score then best, score = i, dot end
  end
  return best
end
function wheel:RefreshAppearance()
  if not self.frame then return end
  local settings = addon.db.data.settings
  self.lockButton:SetText(settings.wheelUnlocked and "Lock" or "Edit")
  self.lockIcon:SetTexture(assetRoot .. (settings.wheelUnlocked and
    "PackPadlockLocked.blp" or "PackPadlockUnlocked.blp"))
  self.centerClose:Show()
  self.pinButton:SetText(settings.wheelPinned and "Unpin" or "Pin")
  if settings.wheelUnlocked then self.colorButton:Show()
  else self.colorButton:Hide() end
  self.hintText:SetText(settings.wheelUnlocked and
    "Drag center: move   Right-click: color\nDrag out: remove   Drop bag item: add preview" or
    (settings.wheelPinned and "Pinned: click to queue; Esc closes" or
      "Click to queue    Unlock to edit"))
  local selected = self.selected
  self.selected = 0
  self:SetSelection(selected)
end
function wheel:UpdateHighlight()
  if not self.frame or not self.frame:IsShown() then return end
  local x, y = cursorPosition()
  if not x then self:SetSelection(nil); return end
  local dx, dy = x - self.centerX, y - self.centerY
  if self.cursorX and (x-self.cursorX)^2+(y-self.cursorY)^2 < 24^2 then
    self:SetSelection(nil); return
  end
  local deadZone = math.max(28, self.radius * .28)
  if dx*dx + dy*dy < deadZone*deadZone then self:SetSelection(nil); return end
  if dx*dx + dy*dy > (self.outerRadius+24)^2 then
    self:SetSelection(nil); return
  end
  local best, score = nil, -math.huge
  for i, vector in ipairs(self.vectors or {}) do
    local dot = dx*vector[1] + dy*vector[2]
    if dot > score then best, score = i, dot end
  end
  self:SetSelection(best)
end
function wheel:RestoreCursor()
  if self.cursorAttempted and type(SetCursor) == "function" then pcall(SetCursor, nil) end
  self.cursorAttempted = nil
end
function wheel:Close()
  if self.frame and self.frame:IsShown() then self.frame:Hide() end
  self:RestoreCursor()
  self.suppressCenterClick = nil
  self.history = {}
  if self.historyViews then self:RenderHistory() end
  self.layoutX, self.layoutY = nil, nil
  self.selected = nil
  self.submenu = nil
  self.submenuParent = nil
  self.menuEntries = nil
  self.folderIndex = nil
end
function wheel:Open()
  if not outOfCombat() then return false end
  self:Create()
  if self.frame:IsShown() then self:Close(); return false end
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
  return true
end

function wheel:Notice(message)
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
  self.capture:Hide()
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
  self.capture:Show()
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
  self.bindingLabel:SetText("Key: " .. key)
  self:Notice("Wheel key set: " .. key .. ".")
end
local function cursorEntry()
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
  self:RefreshColor()
end
function wheel:RefreshColor()
  if not self.colorLabel then return end
  local slots = addon.db.data.settings.wheelSlots
  local entry = self.editorIndex and slots[self.editorIndex]
  if entry then
    local overrides = addon.db.data.settings.wheelCategoryColors or {}
    self.colorLabel:SetText("Color: " .. (overrides[colorKey(entry)] or "default"))
  else self.colorLabel:SetText("Color: select entry") end
end
function wheel:ChangeColor(reset)
  if not outOfCombat() then self:Notice("Change colors out of combat."); return end
  local slots = addon.db.data.settings.wheelSlots
  local entry = self.editorIndex and slots[self.editorIndex]
  if not entry then
    self:Notice("Select a row to color."); return
  end
  local nextColor
  if not reset then
    local current = entryColor(entry)
    for i, name in ipairs(swatches) do
      if name == current then nextColor = swatches[i % #swatches + 1]; break end
    end
  end
  local key = colorKey(entry)
  if addon.db:SetWheelColor(key, nextColor) then
    self:RefreshColor()
    self:Notice(nextColor and (key .. " color: " .. nextColor) or
      (key .. " color reset to default."))
  end
end
function wheel:DropEntry(entry, target, hovered)
  if not outOfCombat() then self:Notice("Edit the wheel out of combat."); return false end
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
  if target and hovered and hovered >= .45 then
    if slots[target].type == "folder" then success = db:WheelAddToFolder(target, entry)
    else
      local raw = self.folderName:GetText()
      local name = usable(raw) and safeLabel(raw) and #raw <= 40 and raw or "New folder"
      success = db:WheelInsert(entry, target)
      if success then
        success = db:WheelFolder(target, target+1, name)
        if not success then db:WheelRemove(target) end -- preserve the old wheel on failed grouping
      end
    end
  else success = db:WheelInsert(entry, target) end
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
  if not entry then self:Notice("Drop a spell, item, or macro from a game panel."); return false end
  local elapsed = 0
  if target and self.hoverIndex == target and self.hoverStart and type(GetTime) == "function" then
    local ok, now = pcall(GetTime)
    if ok and usable(now) and type(now) == "number" then elapsed = now - self.hoverStart end
  end
  return self:DropEntry(entry, target, elapsed)
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
  if self.artLabel then
    self.artLabel:SetText(settings.wheelArtReversed and "Art: reversed" or "Art: default")
  end
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
  if not self.settingsFrame then
    local frame = CreateFrame("Frame", "ErrandMasterWheelSettings", UIParent,
      "BasicFrameTemplateWithInset")
    frame:SetSize(745, 755)
    frame:SetPoint("CENTER")
    if addon.windowPosition then addon.windowPosition:Restore(frame, "wheelSettings") end
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
      self:StartMoving(); self.errandMoving = true
    end)
    frame:SetScript("OnDragStop", function(self)
      if not self.errandMoving then return end
      self:StopMovingOrSizing(); self.errandMoving = nil
      if addon.windowPosition then addon.windowPosition:Save(self, "wheelSettings") end
    end)
    frame:SetScript("OnHide", function()
      if frame.errandMoving then
        frame:StopMovingOrSizing(); frame.errandMoving = nil
        if addon.windowPosition then addon.windowPosition:Save(frame, "wheelSettings") end
      end
      wheel:StopCapture()
      wheel.dragIndex, wheel.hoverIndex, wheel.hoverStart, wheel.hoverRemove = nil, nil, nil, nil
    end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    frame:RegisterEvent("UI_SCALE_CHANGED")
    frame:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_REGEN_DISABLED" then wheel:StopCapture()
      else wheel:FitSettings() end
    end)
    frame:SetClampedToScreen(true)
    frame.TitleText:SetText("ErrandMaster - Wheel studio")
    self.settingsFrame = frame
    self.bindingLabel = caption(frame, "", 22, -43)
    self.bindButton = control(frame, "Bind wheel", 22, -66, 130,
      function() wheel:StartCapture() end)
    self.status = caption(frame, "Drag to reorder; spell/item/macro entries only preview.", 22, -710)
    self.sizeLabel = caption(frame, "", 22, -106)
    local function adjust(field, delta, minimum, maximum)
      local settings = addon.db.data.settings
      settings[field] = math.max(minimum, math.min(maximum, settings[field] + delta))
      wheel:RefreshSettings()
    end
    control(frame, "Radius -", 22, -128, 78,
      function() adjust("wheelRadius", -10, 80, 200) end)
    control(frame, "Radius +", 105, -128, 78,
      function() adjust("wheelRadius", 10, 80, 200) end)
    control(frame, "Icon -", 192, -128, 72,
      function() adjust("wheelIconSize", -4, 32, 72) end)
    control(frame, "Icon +", 269, -128, 72,
      function() adjust("wheelIconSize", 4, 32, 72) end)
    local function appearance(scale, theme)
      if addon.db:SetWheelAppearance(scale, theme) then wheel:RefreshSettings() end
    end
    control(frame, "Scale -", 22, -160, 78, function()
      local settings = addon.db.data.settings
      appearance(math.max(.75, math.floor((settings.wheelScale -.05)*10+.5)/10), settings.wheelTheme)
    end)
    control(frame, "Scale +", 105, -160, 78, function()
      local settings = addon.db.data.settings
      appearance(math.min(1.5, math.floor((settings.wheelScale +.15)*10+.5)/10), settings.wheelTheme)
    end)
    local themes = {"Azure", "Ember", "Violet", "Slate"}
    control(frame, "Theme", 192, -160, 148, function()
      local current = addon.db.data.settings.wheelTheme
      for i, theme in ipairs(themes) do
        if theme == current then
          appearance(addon.db.data.settings.wheelScale, themes[i % #themes + 1]); break
        end
      end
    end)
    self.colorLabel = caption(frame, "Color: select entry", 22, -191)
    control(frame, "Next color", 192, -186, 72, function() wheel:ChangeColor(false) end)
    control(frame, "Reset color", 269, -186, 72, function() wheel:ChangeColor(true) end)
    caption(frame, "Trainer filter (per character; manual overrides auto)", 383, -45)
    self.professionStatus = caption(frame, "", 383, -67)
    self.professionInput = edit(frame, "Profession name (e.g. Alchemy)", 383, -94, 176, 40)
    self.professionAddButton = control(frame, "Add", 577, -111, 84,
      function() wheel:ChangeProfession("add") end)
    self.professionRemoveButton = control(frame, "Remove", 577, -141, 84,
      function() wheel:ChangeProfession("remove") end)
    self.professionAutoButton = control(frame, "Use auto detection", 383, -164, 176,
      function() wheel:ChangeProfession("auto") end)
    control(frame, "Flip pie art", 383, -195, 176, function()
      if not outOfCombat() then wheel:Notice("Change wheel art out of combat."); return end
      local settings = addon.db.data.settings
      settings.wheelArtReversed = not settings.wheelArtReversed
      wheel:RefreshSettings()
      wheel:Notice("Pie art direction changed. Reopen the wheel to inspect alignment.")
    end)
    self.artLabel = caption(frame, "Art: default", 565, -201)
    self.editorLabel = caption(frame, "", 22, -231)
    caption(frame, "Click #2 for Move/Remove. Drag to reorder; hold 0.45s to folder.", 22, -253)
    self.editorRows = {}
    for i = 1, 12 do
      local row = control(frame, "", 22, -279 - (i-1)*27, 330, function(button)
        wheel:Choose(button.slotIndex)
      end)
      row:RegisterForDrag("LeftButton")
      row:SetScript("OnDragStart", function(button)
        wheel.hoverIndex, wheel.hoverStart, wheel.hoverRemove = nil, nil, nil
        if outOfCombat() then wheel.dragIndex = button.slotIndex end
      end)
      row:SetScript("OnEnter", function(button)
        wheel.hoverIndex = button.slotIndex
        local ok, now = pcall(function() return GetTime and GetTime() end)
        wheel.hoverStart = ok and usable(now) and type(now) == "number" and now or nil
      end)
      row:SetScript("OnLeave", function(button)
        if wheel.hoverIndex == button.slotIndex then
          wheel.hoverIndex, wheel.hoverStart = nil, nil
        end
      end)
      row:SetScript("OnReceiveDrag", function(button)
        if wheel.dragIndex then wheel.hoverIndex = button.slotIndex; wheel:FinishDrag()
        else wheel:DropNative(button.slotIndex) end
      end)
      row:SetScript("OnDragStop", function() wheel:FinishDrag() end)
      self.editorRows[i] = row
    end
    control(frame, "< Previous", 22, -607, 100, function()
      wheel.editorPage = math.max(1, (wheel.editorPage or 1)-1); wheel:RefreshEditor()
    end)
    control(frame, "Next >", 127, -607, 100, function()
      wheel.editorPage = (wheel.editorPage or 1)+1; wheel:RefreshEditor()
    end)
    local trash = control(frame, "Drag here to REMOVE", 22, -645, 330, function()
      if wheel.editorIndex and outOfCombat() and addon.db:WheelRemove(wheel.editorIndex) then
        wheel.activeIndex, wheel.editorIndex = nil, nil
        wheel:RefreshEditor()
      end
    end)
    trash:SetScript("OnEnter", function()
      wheel.hoverIndex, wheel.hoverStart = nil, nil
      if wheel.dragIndex then wheel.hoverRemove = true end
    end)
    trash:SetScript("OnLeave", function() wheel.hoverRemove = nil end)
    trash:SetScript("OnReceiveDrag", function()
      if wheel.dragIndex then wheel.hoverRemove = true; wheel:FinishDrag() end
    end)
    self.slotNumber = edit(frame, "Selected slot (1-24)", 383, -245, 60, 2)
    self.slotType = edit(frame, "Type: category / addon / spell / item / macro", 383, -296, 136, 8)
    self.slotValue = edit(frame, "Name or numeric ID", 383, -347, 278, 40)
    self.applySlotButton = control(frame, "Replace slot", 383, -399, 136,
      function() wheel:AssignSlot() end)
    control(frame, "Add entry", 526, -399, 136, function() wheel:AddNamedEntry() end)
    control(frame, "Browse addons", 383, -430, 136, function() wheel:BrowseAddOn() end)
    control(frame, "Drop entry here", 526, -430, 136, function() wheel:DropNative() end)
      :SetScript("OnReceiveDrag", function() wheel:DropNative() end)
    control(frame, "Set ACTIVE / Move", 383, -462, 136, function()
      if wheel.editorIndex and outOfCombat() then
        wheel.activeIndex = wheel.editorIndex
        wheel:Notice("Active #" .. wheel.activeIndex .. ": open wheel and choose its destination.")
        wheel:RefreshEditor()
      end
    end)
    control(frame, "Preview wheel", 526, -462, 136,
      function() wheel:Open() end)
    self.folderName = edit(frame, "Folder name (hover a slot while dragging)", 383, -500, 278, 40)
    control(frame, "Rename folder", 383, -553, 136, function()
      if wheel.editorIndex and outOfCombat() and
          addon.db:WheelRename(wheel.editorIndex, wheel.folderName:GetText()) then
        wheel:RefreshEditor()
      end
    end)
    self.folderLabel = caption(frame, "", 383, -588)
    self.folderRows = {}
    for i = 1, 8 do
      local child = control(frame, "", 383, -607 - (i-1)*17, 279, function(button)
        if wheel.editorIndex and outOfCombat() and
            addon.db:WheelRemove(wheel.editorIndex, button.childIndex) then
          wheel:Notice("Removed item from folder."); wheel:RefreshEditor()
        end
      end)
      child:SetSize(279, 16)
      child.childIndex = i
      self.folderRows[i] = child
    end
    self:EnsureCapture()
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "ErrandMasterWheelSettings") end
  end
  self:FitSettings()
  self:RefreshSettings()
  self.settingsFrame:Show()
  animate(self.settingsFrame)
end
