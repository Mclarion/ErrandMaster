local addonName, addon = ...
BINDING_HEADER_ERRANDMASTER = "ErrandMaster"
BINDING_NAME_ERRANDMASTER_WHEEL = "Open ErrandMaster selection wheel"
function ErrandMaster_OpenWheel()
  if addon.db.data then return addon.radial:Open() end
  return false
end
local function safe(value)
  if value == nil then return false end
  local ok, allowed = pcall(function()
    if issecretvalue and issecretvalue(value) then return false end
    if type(value) == "table" and issecrettable and issecrettable(value) then return false end
    return true
  end)
  return ok and allowed
end
function addon:Print(message)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff66cceeErrandMaster:|r " .. tostring(message)) end
end
function addon:Position()
  if not safe(C_Map) then return nil end
  local available, getMap, getPosition = pcall(function()
    return C_Map.GetBestMapForUnit, C_Map.GetPlayerMapPosition
  end)
  if not available or not safe(getMap) or not safe(getPosition) or
      type(getMap) ~= "function" or type(getPosition) ~= "function" then return nil end
  local ok, map = pcall(getMap, "player")
  if not ok or not safe(map) or type(map) ~= "number" then return nil end
  local success, position = pcall(getPosition, map, "player")
  if not success or not safe(position) or not position then return map end
  local valid, x, y = pcall(function() return position:GetXY() end)
  if not valid or not safe(x) or not safe(y) or type(x) ~= "number" or
      type(y) ~= "number" or x ~= x or y ~= y or x < 0 or x > 1 or
      y < 0 or y > 1 then return map end
  return map, x, y
end
function addon:MapWorldSize(mapID)
  if not safe(mapID) or type(mapID) ~= "number" or not safe(C_Map) then return end
  local available, method = pcall(function() return C_Map.GetMapWorldSize end)
  if not available or not safe(method) or type(method) ~= "function" then return end
  local ok, width, height = pcall(method, mapID)
  if not ok or not safe(width) or not safe(height) or
      type(width) ~= "number" or type(height) ~= "number" or
      width ~= width or height ~= height or width <= 0 or height <= 0 or
      width > 10000000 or height > 10000000 then return end
  return width, height
end
function addon:Plan(displayMap)
  local map, x, y = self:Position()
  if displayMap ~= nil then
    if not safe(displayMap) or type(displayMap) ~= "number" or
        displayMap < 1 or displayMap % 1 ~= 0 then return {}, {}, nil end
    if map ~= displayMap then x, y = nil, nil end
    map = displayMap
  end
  local width, height = self:MapWorldSize(map)
  local ordered, deferred = self.route:Plan(self.errands:All(), map, x, y,
    self.db.data.settings.optimize, self.locations:All(), self.quests:OnMap(map), width, height)
  return ordered, deferred, map, x, y
end
function addon:Refresh()
  if self.ui then self.ui:Refresh() end
  if self.worldMap then self.worldMap:Refresh() end
  -- Never delete user waypoints: only clear an existing ErrandMaster handle.
  if self.navigation.handle then
    local route = self:Plan()
    self.navigation:Next(route[1])
  end
end
function addon:NavigateNext()
  local route = self:Plan()
  local nextItem = route[1]
  if not nextItem then self:Print("No positioned errands on your current map."); return end
  local used = self.navigation:Next(nextItem)
  self:Print(string.format("Next: %s (map %d, %.1f, %.1f%s). %s", nextItem.name,
    nextItem.mapID, nextItem.x*100, nextItem.y*100,
    nextItem.approximate and "; approximate player position" or "",
    used and "TomTom waypoint set." or "Use the displayed coordinates; no compatible TomTom waypoint."))
  if nextItem.directYards then
    self:Print(string.format("Approximately %.0f yd straight-line; actual travel may be longer.",
      nextItem.directYards))
  end
end
local function identity()
  local name, realm
  if UnitFullName then name, realm = UnitFullName("player") end
  if not name and UnitName then name = UnitName("player") end
  if not realm or realm == "" then realm = GetRealmName and GetRealmName() end
  if not name or not realm then return nil end
  return name .. "-" .. realm
end
function addon:Command(message)
  local command = (message or ""):match("^%s*(%S*)")
  command = command:lower()
  local argument = (message or ""):match("^%s*%S+%s+(.+)")
  if argument then argument = argument:match("^%s*(.-)%s*$") end
  if command == "" then self.ui:Toggle()
  elseif command == "add" then
    self.ui.frame:Show(); self.ui.name:SetFocus()
  elseif command == "settings" then
    self.ui.frame:Show()
    self:Print("Use the order, scope, TomTom, discovery and Wheel settings controls in the window.")
  elseif command == "route" then
    local ordered, deferred = self:Plan()
    self:Print(string.format("%d same-map stops; %d unrouted (other map or no position).", #ordered, #deferred))
    for i = 1, math.min(#ordered, 10) do
      local item = ordered[i]
      self:Print(string.format("%d. %s (%.1f, %.1f%s)%s", i, item.name,
        item.x*100, item.y*100, item.approximate and " approximate" or "",
        item.directYards and string.format(" ~%.0f yd direct", item.directYards) or ""))
    end
    if #ordered > 10 then self:Print(string.format("...%d more stops in the window.", #ordered-10)) end
  elseif command == "optimize" then
    self.db.data.settings.optimize = true; self:Refresh(); self:Print("Same-map route optimized.")
  elseif command == "next" then self:NavigateNext()
  elseif command == "map" then
    if not self.worldMap or not self.worldMap:Open() then
      self:Print("Native world-map overlay unavailable; use /em route for coordinates.")
    end
  elseif command == "quests" then
    local map = self:Position()
    local list = self.quests:OnMap(map)
    self:Print(string.format("%d active quests with a POI on your current map (first 10):", #list))
    for i = 1, math.min(#list, 10) do
      self:Print(string.format("%d: %s (%.1f, %.1f)", list[i].questID,
        list[i].title, list[i].x*100, list[i].y*100))
    end
  elseif command == "quest" then
    local map = self:Position()
    local id = argument and argument:match("^%d+$") and tonumber(argument)
    if not map or not id then self:Print("Use /em quest <id> on the quest's current map.")
    else
      local item, reason = self.quests:Add(id, map)
      if item then self:Refresh(); self:Print("Quest destination added: " .. item.name .. ".")
      else self:Print(reason or "Quest POI unavailable.") end
    end
  elseif command == "pin" then
    local map, x, y = self:Position()
    if not map or not x then self:Print("Current map position unavailable; use the main form.")
    else
      local name = argument and argument:match("^%s*(.-)%s*$")
      if not name or name == "" then name = "My pin" end
      local ok, result = pcall(self.errands.Add, self.errands, {
        name=name, category="Pin", mapID=map, x=x, y=y, scope="character",
      })
      if ok then self:Refresh(); self:Print("Personal destination added: " .. result.name .. ".")
      else self:Print("Could not add pin; name must be at most 80 characters.") end
    end
  elseif command == "wheel" then
    if argument == "settings" then self.radial:ShowSettings()
    elseif not self.radial:Open() then self:Print("Wheel unavailable in combat or without cursor position.") end
  elseif command == "discover" then
    local value = argument and argument:lower()
    if value ~= "on" and value ~= "off" then
      self:Print("Use /em discover on or /em discover off. Recording is character-only.")
    else
      self.db.data.settings.discoverServices = value == "on"
      self:Refresh()
      self:Print("Passive service discovery " .. value .. ".")
    end
  elseif command == "poi" then
    local category = argument and argument:match("^%s*(.-)%s*$")
    if not category or category == "" then
      self:Print("Use /em poi <category> after selecting an in-game guard POI.")
    else
      local labels = {repair="Repair", bank="Bank", auction="Auction House",
        ["auction house"]="Auction House", mail="Mailbox", mailbox="Mailbox", vendor="Vendor"}
      category = labels[category:lower()] or category
      local item, err = self.discovery:SaveGossipPoi(category)
      if item then self:Print(string.format("Saved %s POI for %s at %.1f, %.1f. Category chosen by you.",
        item.name, category, item.x*100, item.y*100))
      else self:Print(err or "POI unavailable.") end
    end
  elseif command == "locations" then
    local list = self.locations:All()
    self:Print(string.format("%d character-scoped observed locations (first 10):", #list))
    for i = 1, math.min(#list, 10) do
      local item = list[i]
      self:Print(string.format("%s %s: %s (map %d, %.1f, %.1f; %s)", item.id,
        item.category, item.name, item.mapID, item.x*100, item.y*100, item.precision))
    end
  elseif command == "forget" then
    if not argument or not argument:match("^loc%-%d+$") then
      self:Print("Use /em forget loc-<number> (see /em locations).")
    elseif self.locations:Delete(argument) then self:Refresh(); self:Print("Location removed.")
    else self:Print("Location not found for this character.") end
  elseif command == "debug" then
    self.db.data.settings.debug = not self.db.data.settings.debug
    self:Print("Debug logging " .. (self.db.data.settings.debug and "on" or "off") .. ".")
  elseif command == "help" then
    self:Print("/em, add, map, pin <name>, quests, quest <id>, route, optimize, next, settings, wheel, wheel settings, discover on|off, poi <category>, locations, forget <id>, debug, help")
  else self:Print("Unknown command. Type /em help.") end
end
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
local function initialize()
  local character = identity()
  if not character then return end -- UnitFullName may not be ready at ADDON_LOADED.
  local ok, err = pcall(function()
    addon.db:Initialize(character)
    addon.ui:Create()
    if addon.worldMap then addon.worldMap:Attach() end
    SLASH_ERRANDMASTER1 = "/em"
    SlashCmdList.ERRANDMASTER = function(message) addon:Command(message) end
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    pcall(events.RegisterEvent, events, "QUEST_LOG_UPDATE")
    for _, event in ipairs({"MERCHANT_SHOW", "MAIL_SHOW", "AUCTION_HOUSE_SHOW"}) do
      pcall(events.RegisterEvent, events, event) -- Optional service events must not block startup.
    end
  end)
  if not ok then addon:Print("Initialization failed: " .. tostring(err)); return end
  events:UnregisterEvent("PLAYER_LOGIN")
end
events:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == addonName then
    addon.loaded = true
    initialize()
  elseif event == "ADDON_LOADED" and name == "Blizzard_WorldMap" and addon.db.data then
    if addon.worldMap then addon.worldMap:Attach() end
  elseif event == "PLAYER_LOGIN" and addon.loaded and not addon.ui.frame then
    initialize()
  elseif addon.db.data and (event == "MERCHANT_SHOW" or event == "MAIL_SHOW" or
      event == "AUCTION_HOUSE_SHOW") then
    local ok, err = pcall(addon.discovery.HandleEvent, addon.discovery, event)
    if not ok and addon.db.data.settings.debug then addon:Print("Discovery: " .. tostring(err)) end
  elseif addon.db.data and (event == "ZONE_CHANGED_NEW_AREA" or
      event == "PLAYER_ENTERING_WORLD" or event == "QUEST_LOG_UPDATE") then
    addon.quests:Invalidate()
    addon:Refresh()
  elseif event == "PLAYER_REGEN_ENABLED" and addon.db.data and addon.worldMap then
    addon.worldMap:Refresh()
  end
end)
