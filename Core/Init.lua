local addonName, addon = ...
BINDING_HEADER_ERRANDMASTER = "ErrandMaster"
BINDING_NAME_ERRANDMASTER_WHEEL = "Open ErrandMaster selection wheel"
function ErrandMaster_OpenWheel()
  if addon.db.data then return addon.radial:Open() end
  return false
end
local function safe(value)
  return value ~= nil and (not issecretvalue or not issecretvalue(value))
end
function addon:Print(message)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff66cceeErrandMaster:|r " .. tostring(message)) end
end
function addon:Position()
  if not safe(C_Map) or (issecrettable and issecrettable(C_Map)) then return nil end
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
function addon:Refresh()
  if self.ui then self.ui:Refresh() end
  -- Never delete user waypoints: only clear an existing ErrandMaster handle.
  if self.navigation.handle then
    local map, x, y = self:Position()
    local route = self.route:Plan(self.errands:All(), map, x, y,
      self.db.data.settings.optimize, self.locations:All())
    self.navigation:Next(route[1])
  end
end
function addon:NavigateNext()
  local map, x, y = self:Position()
  local route = self.route:Plan(self.errands:All(), map, x, y,
    self.db.data.settings.optimize, self.locations:All())
  local nextItem = route[1]
  if not nextItem then self:Print("No positioned errands on your current map."); return end
  local used = self.navigation:Next(nextItem)
  self:Print(string.format("Next: %s (map %d, %.1f, %.1f%s). %s", nextItem.name,
    nextItem.mapID, nextItem.x*100, nextItem.y*100,
    nextItem.approximate and "; approximate player position" or "",
    used and "TomTom waypoint set." or "Use the displayed coordinates; no compatible TomTom waypoint."))
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
    local map, x, y = self:Position()
    local ordered, deferred = self.route:Plan(self.errands:All(), map, x, y,
      self.db.data.settings.optimize, self.locations:All())
    self:Print(string.format("%d same-map stops; %d unrouted (other map or no position).", #ordered, #deferred))
    for i = 1, math.min(#ordered, 10) do
      local item = ordered[i]
      self:Print(string.format("%d. %s (%.1f, %.1f%s)", i, item.name,
        item.x*100, item.y*100, item.approximate and " approximate" or ""))
    end
    if #ordered > 10 then self:Print(string.format("...%d more stops in the window.", #ordered-10)) end
  elseif command == "optimize" then
    self.db.data.settings.optimize = true; self:Refresh(); self:Print("Same-map route optimized.")
  elseif command == "next" then self:NavigateNext()
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
    self:Print("/em, add, route, optimize, next, settings, wheel, wheel settings, discover on|off, poi <category>, locations, forget <id>, debug, help")
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
    SLASH_ERRANDMASTER1 = "/em"
    SlashCmdList.ERRANDMASTER = function(message) addon:Command(message) end
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    for _, event in ipairs({"MERCHANT_SHOW", "MAIL_SHOW", "AUCTION_HOUSE_SHOW"}) do
      pcall(events.RegisterEvent, events, event) -- Optional service events must not block startup.
    end
  end)
  if not ok then addon:Print("Initialization failed: " .. tostring(err)); return end
  events:UnregisterEvent("ADDON_LOADED")
  events:UnregisterEvent("PLAYER_LOGIN")
end
events:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == addonName then
    addon.loaded = true
    initialize()
  elseif event == "PLAYER_LOGIN" and addon.loaded and not addon.ui.frame then
    initialize()
  elseif addon.db.data and (event == "MERCHANT_SHOW" or event == "MAIL_SHOW" or
      event == "AUCTION_HOUSE_SHOW") then
    local ok, err = pcall(addon.discovery.HandleEvent, addon.discovery, event)
    if not ok and addon.db.data.settings.debug then addon:Print("Discovery: " .. tostring(err)) end
  elseif addon.db.data then addon:Refresh() end
end)
