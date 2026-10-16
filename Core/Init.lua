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
function addon:ProfessionFilters()
  local manual=self.db:ProfessionOverrides()
  if #manual>0 then return manual,"manual" end
  if not safe(GetProfessions) or type(GetProfessions)~="function" or
      not safe(GetProfessionInfo) or type(GetProfessionInfo)~="function" then
    return {},"unavailable"
  end
  local call={pcall(GetProfessions)}
  if not call[1] then return {},"unavailable" end
  local result,seen={},{}
  for i=2,7 do
    local index=call[i]
    if safe(index) and type(index)=="number" and index>=1 and index%1==0 then
      local ok,name=pcall(GetProfessionInfo,index)
      if ok and safe(name) and type(name)=="string" and #name>=2 and
          #name<=40 and not name:find("[%c|]") and not seen[name:lower()] then
        result[#result+1]=name; seen[name:lower()]=true
      end
    end
  end
  return result,#result>0 and "auto" or "unavailable"
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
  local settings = self.db.data.settings
  local walkContext
  if settings.routeMode == "observed" then
    local sample = self.trails and self.trails:NativeSample()
    if not sample or sample.uiMapID ~= map then sample = nil end
    local level
    if type(UnitLevel) == "function" then
      local ok, result = pcall(UnitLevel, "player")
      if ok and safe(result) and type(result) == "number" then level = result end
    end
    walkContext = {nodes=self.trails and self.trails.nodes or {},
      edges=self.trails and self.trails.edges or {},
      playerLevel=level, mode="observed", floor=0,
      worldMapID=sample and sample.worldMapID,
      wz=sample and sample.wz}
  end
  local locations = {}
  for _, place in ipairs(self.locations:All()) do locations[#locations+1] = place end
  if map and self.npcs and self.npcs:IsReady() then
    for _, place in ipairs(self.npcs:LocationsOnMap(map)) do
      locations[#locations+1] = place
    end
  end
  local ordered, deferred = self.route:Plan(self.errands:All(), map, x, y,
    settings.optimize, locations, self.quests:OnMap(map), width, height,
    walkContext)
  if self.taxiAdvice and self.taxiAdvice.open then
    for i,item in ipairs(deferred) do
      if item.mapID and item.mapID~=map then
        local node=self.taxiAdvice:ForMap(item.mapID)
        if node then
          local hint={}
          for key,value in pairs(item) do hint[key]=value end
          hint.taxiFlightNode=node
          deferred[i]=hint
        end
      end
    end
  end
  if map and x and y and self.zoneSearch and self.npcs and
      self.npcs:IsReady() and #deferred>0 then
    local cache={}
    for i,item in ipairs(deferred) do
      if not item.mapID and not item.npcID and type(item.category)=="string" then
        local wanted=item.category
        if wanted=="Class Trainer" then
          local class=self.discovery:PlayerClass()
          wanted=class and class.." Trainer"
        end
        if wanted and cache[wanted]==nil then
          local filters={wanted}
          if wanted=="Profession Trainer" then
            local names=self:ProfessionFilters()
            if #names>0 then
              filters={}
              for _,name in ipairs(names) do
                filters[#filters+1]=name.." Trainer"
              end
            end
          end
          local best
          for _,filter in ipairs(filters) do
            local ok,matches=pcall(self.zoneSearch.Nearby,self.zoneSearch,
              map,x,y,filter,2000,1)
            local candidate=ok and matches and matches[1]
            if candidate and (not best or
                candidate.directYards<best.directYards) then best=candidate end
          end
          cache[wanted]=best or false
        end
        if wanted and cache[wanted] then
          local hint={}
          for key,value in pairs(item) do hint[key]=value end
          hint.nearbyZoneCandidate=cache[wanted]
          deferred[i]=hint
        end
      end
    end
  end
  return ordered, deferred, map, x, y
end
function addon:Refresh()
  if self.ui then self.ui:Refresh() end
  if self.worldMap then self.worldMap:Refresh() end
  if self.destinations then self.destinations:Refresh() end
  self:RevalidateNavigation()
end
function addon:MovementTick()
  local taxiKnown, taxi = false, false
  if safe(UnitOnTaxi) and type(UnitOnTaxi) == "function" then
    local ok, value = pcall(UnitOnTaxi, "player")
    if ok and safe(value) and type(value) == "boolean" then
      taxiKnown, taxi = true, value
    end
  end
  if taxiKnown and taxi then
    self.movementTaxi = true
    self.movementOrigin = nil
    return false
  end
  if self.movementTaxi then
    if not taxiKnown then return false end
    local map, x, y = self:Position()
    if not map or not x or not y then return false end
    self.movementTaxi = false
    self.movementOrigin = {map=map,x=x,y=y}
    self:Refresh() -- A landing may move the player even without a zone event.
    return true
  end
  local map, x, y = self:Position()
  if not map or not x or not y then
    self.movementOrigin = nil
    return false
  end
  local prior = self.movementOrigin
  self.movementOrigin = prior or {map=map, x=x, y=y}
  if not prior then return false end
  if prior.map ~= map then
    self.movementOrigin = {map=map, x=x, y=y}
    self:Refresh()
    return true
  end
  local width, height = self:MapWorldSize(map)
  if not width then return false end -- No yard scale means no honest 50-yard test.
  local dx, dy = (x-prior.x)*width, (y-prior.y)*height
  if dx*dx + dy*dy < 2500 then return false end
  self.movementOrigin = {map=map, x=x, y=y}
  self:Refresh()
  return true
end
function addon:RevalidateNavigation(ordered)
  -- Recheck only the waypoint owned by ErrandMaster; other TomTom pins are untouched.
  if not self.navigation or not self.navigation.handle then return end
  if not ordered then
    local ok, result = pcall(self.Plan, self)
    if not ok or not safe(result) or type(result) ~= "table" then
      self.navigation:Clear(); return
    end
    ordered = result
  end
  local nextItem = ordered[1]
  self.navigation:Next(nextItem and
    (self.db.data.settings.routeMode ~= "observed" or
      nextItem.walkStatus == "known-route") and nextItem or nil)
end
function addon:NavigateNext()
  local route = self:Plan()
  local nextItem = route[1]
  if not nextItem then
    if not self.navigation:Clear() then
      self:Print("Old ErrandMaster TomTom pin could not be removed; clear it in TomTom.")
    end
    self:Print(self.db.data.settings.routeMode == "observed" and
      "No verified walking route to a stop on this map. Try /em trails on or /em walking off for direct estimates." or
      "No positioned errands on this map.")
    return
  end
  if self.db.data.settings.routeMode == "observed" and
      nextItem.walkStatus ~= "known-route" then
    local cleared = self.navigation:Clear()
    self:Print(string.format("Partial observed segment toward %s (%.0f yd recorded); connector unverified. %s",
      nextItem.name, nextItem.walkYards or 0,
      cleared and "No waypoint set." or "Old TomTom pin could not be removed."))
    return
  end
  local used = self.navigation:Next(nextItem)
  self:Print(string.format("Next: %s (map %d, %.1f, %.1f%s). %s", nextItem.name,
    nextItem.mapID, nextItem.x*100, nextItem.y*100,
    nextItem.approximate and "; approximate player position" or "",
    used and "TomTom waypoint set." or (self.navigation.handle and
      "Old ErrandMaster pin could not be removed; no new pin set." or
      "Use the displayed coordinates; no compatible TomTom waypoint.")))
  if nextItem.directYards then
    self:Print(string.format("Approximately %.0f yd straight-line; actual travel may be longer.",
      nextItem.directYards))
  end
  if nextItem.walkYards then
    self:Print(string.format("%.0f yd on observed segments; terrain and safety may have changed.", nextItem.walkYards))
  end
  if nextItem.locationSource == "questiedb-forever" or nextItem.npcID then
    self:Print("NPC position is a QuestieDB Forever candidate spawn, not confirmed on this build or a walking path.")
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
local function seconds()
  if not safe(GetTime) or type(GetTime) ~= "function" then return end
  local ok, now = pcall(GetTime)
  if ok and safe(now) and type(now) == "number" and now == now and
      now >= 0 and now < 100000000 then return now end
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
    self:Print("Window settings plus /em trails on/off and /em walking on/off.")
  elseif command == "route" then
    local ordered, deferred = self:Plan()
    local observed = self.db.data.settings.routeMode == "observed"
    self:Print(string.format("%d %s stops; %d deferred or with unknown walking path.",
      #ordered, observed and "observed-walk" or "direct-estimate", #deferred))
    for i = 1, math.min(#ordered, 10) do
      local item = ordered[i]
      self:Print(string.format("%d. %s (%.1f, %.1f%s)%s%s", i, item.name,
        item.x*100, item.y*100, item.approximate and " approximate" or "",
        item.walkYards and string.format(" %.0f yd observed", item.walkYards) or
        (item.directYards and string.format(" ~%.0f yd direct", item.directYards) or ""),
        item.walkStatus == "partial-route" and " (unverified connector)" or ""))
    end
    if #ordered > 10 then self:Print(string.format("...%d more stops in the window.", #ordered-10)) end
  elseif command == "optimize" then
    self.db.data.settings.optimize = true; self:Refresh()
    self:Print("Nearest-stop ordering enabled within selected walking/direct mode.")
  elseif command == "walking" then
    if argument == "status" then
      self:Print(self.db.data.settings.routeMode == "observed" and
        "Observed-walk routing on; unknown paths stay unknown." or
        "Direct-distance estimates on; these are not walkable routes.")
    elseif argument ~= "on" and argument ~= "off" then
      self:Print("Use /em walking status, on, or off. Off enables direct estimates, not walking directions.")
    else
      self.db.data.settings.routeMode = argument == "on" and "observed" or "direct"
      self:Refresh()
      self:Print(argument == "on" and "Observed-walk routing on; unknown paths stay unknown." or
        "Direct-distance estimates on; these are not walkable routes.")
    end
  elseif command == "trails" then
    if argument == "status" then
      local nodes, edges, enabled = self.trails:Status()
      self:Print(string.format("Trail evidence for this character: %d/400 nodes, %d/1200 directed edges; recording %s.",
        nodes, edges, enabled and "on" or "off"))
    elseif argument == "clear" then
      local now = seconds()
      if not now then self:Print("Cannot arm trail deletion: game clock unavailable.")
      else
        self.trails.pendingClear = {character=self.db.character, expires=now + 30}
        self:Print("No data deleted. Type /em trails confirm within 30 seconds to clear only this character's trails and stop recording.")
      end
    elseif argument == "confirm" then
      local pending, now = self.trails.pendingClear, seconds()
      self.trails.pendingClear = nil
      if pending and now and pending.character == self.db.character and now <= pending.expires and
          self.trails:Clear() then
        self:Refresh(); self:Print("This character's trail evidence cleared; recording off.")
      else self:Print("No active trail deletion request. Use /em trails clear first.") end
    elseif argument == "on" or argument == "off" then
      if not self.trails:SetEnabled(argument == "on") then
        if argument == "on" and self.trails.bucket and
            (#self.trails.nodes >= 400 or #self.trails.edges >= 1200) then
          self:Print("Trail storage full; recording remains off. Use /em trails status or /em trails clear to review/reset.")
        else self:Print("Trail storage unavailable; setting was not changed.") end
      else
        self:Print("Ground-movement observation " .. argument .. ".")
      end
    else self:Print("Use /em trails status, on, off, clear, or confirm. Recording is per character and off by default.") end
  elseif command == "next" then self:NavigateNext()
  elseif command == "map" then
    if not self.worldMap or not self.worldMap:Open() then
      self:Print("Native world-map overlay unavailable; use /em route for coordinates.")
    end
  elseif command == "list" then
    self.destinations:Toggle()
  elseif command == "quests" then
    local map = self:Position()
    local list = self.quests:OnMap(map)
    self:Print(string.format("%d active quest map destinations (POIs or saved next waypoints; first 10):", #list))
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
      else self:Print(reason or "Quest map destination unavailable.") end
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
  elseif command == "npcs" then
    local status = self.npcs:Status()
    if argument == "status" or not self.npcs:IsReady() then
      self:Print(string.format("QuestieDB Forever NPC catalog: %s (%d/%d IDs)%s.",
        status.state, status.processed, status.total,
        status.reason and "; " .. status.reason or ""))
    else
      local map,x,y=self:Position()
      local query=argument and argument:match("^find%s+(.+)$")
      if query then
        local width,height=self:MapWorldSize(map)
        local matches=self.npcs:Find(query,map,x,y,width,height)
        self:Print(string.format("%d NPC name, subtitle or specialty matches on this map (nearest first when position is known; first 20):",#matches))
        for _,entry in ipairs(matches) do
          self:Print(string.format("NPC %d: %s [%s] (%.1f, %.1f)%s%s",entry.id,
            entry.name,entry.category,entry.x*100,entry.y*100,
            x and string.format(" ~%.0f yd direct",math.sqrt(entry.score)) or "",
            entry.phaseUnverified and " phase unverified" or ""))
        end
      else
        local filters={bank="Bank",repair="Repair",vendor="Vendor",
          trainer="Trainer",auction="Auction House",["auction house"]="Auction House",
          flight="Flight Master",innkeeper="Innkeeper",class="Class Trainer",
          profession="Profession Trainer"}
        local nearest=argument and argument:match("^near%s+(.+)$")
        local filter=nearest or argument
        local wanted=filter and filters[filter:lower()]
        local group,specialty
        if filter then
          group,specialty=filter:match("^(class)%s+(.+)$")
          if not group then group,specialty=filter:match("^(profession)%s+(.+)$") end
        end
        if group and specialty and #specialty<=40 then wanted=specialty.." Trainer" end
        if wanted=="Class Trainer" then
          local class=self.discovery:PlayerClass()
          wanted=class and class.." Trainer" or nil
        end
        if argument and argument~="" and argument~="all" and not wanted then
          self:Print("NPCs: /em npcs bank, repair, vendor, trainer, auction, flight, innkeeper")
          self:Print("NPCs: /em npcs class <name>, profession <name>, near <service>")
          self:Print("NPCs: /em npcs find <text>, status, all; add: /em npc add <id>")
        elseif nearest and not x then
          self:Print("Nearest NPCs need a readable current-map position.")
        else
          local all=self.npcs:LocationsOnMap(map,wanted)
          local width,height=self:MapWorldSize(map)
          local list=x and self.npcs:Nearest(map,x,y,wanted,width,height,10) or all
          self:Print(string.format("%d QuestieDB %s candidate spawns on this map (first 10):",
            #all,wanted or "service NPC"))
          for i=1,math.min(#list,10) do
            local place=list[i]
            self:Print(string.format("%d: NPC %d %s [%s] (%.1f, %.1f)%s%s",i,
              place.npcID,place.name,place.category,place.x*100,place.y*100,
              place.directYards and string.format(" ~%.0f yd direct",place.directYards) or "",
              place.phaseUnverified and " phase unverified" or ""))
          end
          self:Print("Filter with /em npcs class <name> or profession <name>.")
          self:Print("Search names/subtitles with /em npcs find <text>.")
        end
      end
    end
  elseif command == "npc" then
    if not self.npcs:IsReady() then
      self:Print("QuestieDB NPC catalog is not ready; use /em npcs status.")
    else
      local addID=argument and argument:match("^add%s+(%d+)$")
      local lookup=addID or (argument and argument:match("^(%d+)$"))
      if not lookup then self:Print("Use /em npc <id> to inspect or /em npc add <id> to queue a database NPC.")
      else
        local id=tonumber(lookup)
        local places={}
        local map=self:Position()
        for _, place in ipairs(self.npcs:LocationsOnMap(map)) do
          if place.npcID==id then places[#places+1]=place end
        end
        if #places==0 then self:Print("No accessible QuestieDB service spawn for that NPC on this map.")
        elseif addID then
          local place=places[1]
          local ok, err=pcall(self.errands.Add,self.errands,{name=place.name:sub(1,80),
            category=place.category,npcID=id,scope="character"})
          if ok then self:Refresh(); self:Print("NPC "..id.." queued from QuestieDB; spawn and route remain candidates.")
          else self:Print("Could not queue NPC: "..tostring(err)) end
        else
          self:Print(string.format("NPC %d %s: %d category/spawn candidates here (first 10):",
            id,places[1].name,#places))
          for i=1,math.min(#places,10) do
            local place=places[i]
            self:Print(string.format("%d: [%s] %.1f, %.1f%s",i,place.category,
              place.x*100,place.y*100,place.phaseUnverified and " phase uncertain" or ""))
          end
        end
      end
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
    self:Print("/em, add, map, list, pin <name>, quests, quest <id>, route, optimize, next")
    self:Print("walking on/off, trails on/off, discover on/off, settings, wheel")
    self:Print("wheel settings, poi <category>, locations, forget <id>, debug, help")
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
    if addon.npcs and not addon.npcs:Initialize() then
      addon:Print("NPC catalog unavailable: " .. tostring(addon.npcs:Status().reason) ..
        ". Install a compatible QuestieDB Forever provider; NPCs were not guessed.")
    end
    if addon.trails and not addon.trails:Bind() then
      addon:Print("Trail storage is unavailable; its saved data was preserved. Other features remain available.")
    end
    addon.ui:Create()
    if addon.destinations then addon.destinations:Restore() end
    if addon.minimap then addon.minimap:Attach() end
    if addon.worldMap then addon.worldMap:Attach() end
    SLASH_ERRANDMASTER1 = "/em"
    SlashCmdList.ERRANDMASTER = function(message) addon:Command(message) end
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    for _,event in ipairs({"TAXIMAP_OPENED","TAXIMAP_CLOSED",
        "TAXI_NODE_STATUS_CHANGED"}) do
      pcall(events.RegisterEvent,events,event)
    end
    pcall(events.RegisterEvent, events, "QUEST_LOG_UPDATE")
    pcall(events.RegisterEvent, events, "QUEST_POI_UPDATE")
    pcall(events.RegisterEvent, events, "QUEST_WATCH_UPDATE")
    for _, event in ipairs({"MERCHANT_SHOW", "MAIL_SHOW", "AUCTION_HOUSE_SHOW",
        "BANKFRAME_OPENED", "TRAINER_SHOW"}) do
      pcall(events.RegisterEvent, events, event) -- Optional service events must not block startup.
    end
    local elapsed, movementElapsed = 0, 0
    events:SetScript("OnUpdate", function(_, dt)
      if not addon.db.data then elapsed = 0; return end
      if addon.npcs and addon.npcs.state == "indexing" then
        local ok, done = pcall(addon.npcs.Step, addon.npcs, 80)
        if not ok then
          addon.npcs.state, addon.npcs.reason = "unavailable", "NPC index could not be read"
          addon:Print(addon.npcs.reason)
        elseif done then addon:Refresh() end
      end
      if type(dt) ~= "number" or dt ~= dt or dt < 0 or dt > 10 then return end
      movementElapsed = movementElapsed + dt
      if movementElapsed >= .5 then
        movementElapsed = 0
        if #addon.errands:All() > 0 then
          local ok, err = pcall(addon.MovementTick, addon)
          if not ok and addon.db.data.settings.debug then addon:Print("Movement: " .. tostring(err)) end
        else addon.movementOrigin = nil end
      end
      local recording = addon.trails and addon.trails:IsEnabled()
      if not recording and not addon.navigation.handle then
        elapsed = 0; return
      end
      elapsed = elapsed + dt
      if elapsed >= 2 then
        elapsed = 0
        if recording then
          local observed, errorText = pcall(addon.trails.ObserveNative, addon.trails)
          if not observed and addon.db.data.settings.debug then
            addon:Print("Trail sample: " .. tostring(errorText))
          end
        end
        addon:RevalidateNavigation()
      end
    end)
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
  elseif addon.db.data and (event=="TAXIMAP_OPENED" or
      event=="TAXI_NODE_STATUS_CHANGED") and addon.taxiAdvice then
    local ok=pcall(addon.taxiAdvice.Capture,addon.taxiAdvice)
    if not ok then addon.taxiAdvice:Clear() end
    addon:Refresh()
  elseif addon.db.data and event=="TAXIMAP_CLOSED" and addon.taxiAdvice then
    addon.taxiAdvice:Clear()
    addon:Refresh()
  elseif addon.db.data and (event == "MERCHANT_SHOW" or event == "MAIL_SHOW" or
      event == "AUCTION_HOUSE_SHOW" or event == "BANKFRAME_OPENED" or
      event == "TRAINER_SHOW") then
    local ok, err = pcall(addon.discovery.HandleEvent, addon.discovery, event)
    if not ok and addon.db.data.settings.debug then addon:Print("Discovery: " .. tostring(err)) end
  elseif addon.db.data and (event == "ZONE_CHANGED_NEW_AREA" or
      event == "PLAYER_ENTERING_WORLD" or event == "QUEST_LOG_UPDATE" or
      event == "QUEST_POI_UPDATE" or event == "QUEST_WATCH_UPDATE") then
    if event=="PLAYER_ENTERING_WORLD" and addon.taxiAdvice then
      addon.taxiAdvice:Clear()
    end
    addon.quests:Invalidate()
    addon:Refresh()
  elseif event == "PLAYER_REGEN_ENABLED" and addon.db.data and addon.worldMap then
    addon.worldMap:Refresh()
  end
end)
