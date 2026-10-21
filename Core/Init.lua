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
local function validWorldSize(width, height)
  return type(width)=='number' and type(height)=='number' and
    width==width and height==height and width>0 and height>0 and
    width<=10000000 and height<=10000000
end
function addon:MapWorldSize(mapID)
  if not safe(mapID) or type(mapID) ~= 'number' then return end
  if safe(C_Map) then
    local available, method = pcall(function() return C_Map.GetMapWorldSize end)
    if available and safe(method) and type(method) == 'function' then
      local ok, width, height = pcall(method, mapID)
      if ok and safe(width) and safe(height) and validWorldSize(width, height) then
        return width, height
      end
    end
  end
  -- Some clients have no native size API. Two guarded world projections
  -- establish yard scale only when they share the same instance and axes.
  if not self.navigation or type(self.navigation.WorldPosition) ~= 'function' then return end
  local ok0, instance0, north0, west0 = pcall(self.navigation.WorldPosition,
    self.navigation, mapID, 0, 0)
  local ok1, instance1, north1, west1 = pcall(self.navigation.WorldPosition,
    self.navigation, mapID, .5, .5)
  if not ok0 or not ok1 or not safe(instance0) or not safe(instance1) or
      type(instance0) ~= 'number' or instance0 < 0 or instance0 ~= instance1 or
      not safe(north0) or not safe(north1) or not safe(west0) or not safe(west1) or
      type(north0) ~= 'number' or type(north1) ~= 'number' or
      type(west0) ~= 'number' or type(west1) ~= 'number' then return end
  local width, height = 2*(west0-west1), 2*(north0-north1)
  if validWorldSize(width, height) then return width, height end
end
function addon:ProfessionFilters()
  if self.db and type(self.db.GetWheelProfessions)=='function' then
    local ok, configured=pcall(self.db.GetWheelProfessions,self.db)
    if ok and type(configured)=='table' then return configured,'configured' end
  end
  -- Minimal/older database mocks retain the legacy profession path.
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
  local cacheKey=displayMap or false
  local cached=self.refreshPlans and self.refreshPlans[cacheKey]
  if cached then return unpack(cached,1,5) end
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
  local sequential=map and x and y and self.zoneSearch and self.zoneSearch.RouteContext
  if not sequential and map and self.npcs and self.npcs:IsReady() then
    for _, place in ipairs(self.npcs:LocationsOnMap(map)) do
      locations[#locations+1] = place
    end
  end
  local ordered,deferred
  local requests=self.errands:All()
  local questPOIs,questMaps,questRanks={}, {}, {}
  local function addQuestPOI(poi)
    if type(poi)~='table' or type(poi.questID)~='number' then return end
    local rank=poi.source=='game-next-waypoint' and 2 or poi.areaTarget and 0 or 1
    local old=questRanks[poi.questID]
    if old and old.rank>=rank then return end
    if old then questPOIs[old.index]=poi; old.rank=rank
    else
      questPOIs[#questPOIs+1]=poi
      questRanks[poi.questID]={index=#questPOIs,rank=rank}
    end
  end
  local function includeQuests(questMap)
    if not questMap or questMaps[questMap] then return end
    questMaps[questMap]=true
    for _,poi in ipairs(self.quests:OnMap(questMap)) do addQuestPOI(poi) end
  end
  includeQuests(map)
  if sequential then
    for _,request in ipairs(requests) do
      if request.questID and not request.completed and type(request.mapID)=='number' and
          request.mapID>=1 and request.mapID%1==0 then includeQuests(request.mapID) end
    end
  end
  if self.quests.QueuedWaypoints then
    for _,poi in ipairs(self.quests:QueuedWaypoints()) do addQuestPOI(poi) end
  end
  if sequential then
    local origin={mapID=map,x=x,y=y,floor=walkContext and walkContext.floor,
      worldMapID=walkContext and walkContext.worldMapID,wz=walkContext and walkContext.wz}
    ordered,deferred=self.route:Sequence(requests,origin,settings.optimize,
      questPOIs,self.zoneSearch:RouteContext(locations,walkContext))
  else
    ordered,deferred=self.route:Plan(requests,map,x,y,settings.optimize,
      locations,questPOIs,width,height,walkContext)
  end
  if self.taxiAdvice and self.taxiAdvice.open then
    for _,group in ipairs({ordered,deferred}) do
      for i,item in ipairs(group) do
        if item.mapID and item.mapID~=map then
          local node=self.taxiAdvice:ForMap(item.mapID)
          if node then
            local hint={}
            for key,value in pairs(item) do hint[key]=value end
            hint.taxiFlightNode=node
            group[i]=hint
          end
        end
      end
    end
  end
  if not sequential and map and x and y and self.zoneSearch and self.npcs and
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
              map,x,y,filter,wanted=="Auction House" and 10000 or 2000,1)
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
  -- Transient stages belong to individual legs in display order; they never
  -- enter the persisted queue. The first leg begins at the player, later ones
  -- at the preceding planned destination (not the player's old position).
  if displayMap==nil and (self.taxiAdvice or self.boatTrips) and map and x and y and
      not (self.boatTrips and self.boatTrips.pending) and
      self.navigation and type(self.navigation.WorldPosition)=='function' then
    local display=self.route:DisplayOrder(ordered,deferred)
    local fromMap,fromX,fromY=map,x,y
    local projectionCache,projectionCount={},0
    local function project(m,a,b)
      local key=tostring(m)..':'..tostring(a)..':'..tostring(b)
      local cached=projectionCache[key]
      if cached then return unpack(cached) end
      local instance,north,west=self.navigation:WorldPosition(m,a,b)
      if projectionCount<512 and instance~=nil and north~=nil and west~=nil then
        projectionCache[key]={instance,north,west}
        projectionCount=projectionCount+1
      end
      return instance,north,west
    end
    local inserted=0
    -- Errands are capped at 200; do not expand an unbounded route supplied by
    -- a malformed caller. Existing Refresh/CachedPlan handles repeated draws.
    for rank=1,math.min(#display,200) do
      local target=display[rank]
      local saved=target.id and self.errands:Get(target.id)
      local done=self.taxiStageDone and saved and self.taxiStageDone[target.id]==saved
      if saved and not done and fromMap and fromX and fromY then
        local flight=self.taxiAdvice and self.taxiAdvice:Recommend(fromMap,fromX,fromY,target,project)
        local boat=self:BoatBound() and self.boatTrips:Recommend(fromMap,fromX,fromY,target,project)
        -- Cross-world savedYards is unknown, not zero or a claimed improvement.
        local advice=flight
        if boat and (not flight or (boat.savedYards and flight.savedYards and
            boat.savedYards>flight.savedYards)) then advice=boat end
        if advice then
          local isBoat=advice.kind=='boat'
          local stage={id=(isBoat and '!boat:' or '!taxi:')..tostring(target.id),
            transitForId=target.id,transitSource=advice.source,
            name=isBoat and 'Observed boat boarding' or
              ((advice.connectionStatus=='unconfirmed' and 'Possible flight via ' or
                'Flight Master: ')..advice.originNode),
            category=isBoat and 'Boat' or 'Flight Master',
            mapID=advice.mapID,x=advice.x,y=advice.y,
            boatAdvice=isBoat and advice or nil,taxiAdvice=not isBoat and advice or nil,
            manualPosition=target.manualPosition or rank+inserted,
            sequenceRank=target.sequenceRank and target.sequenceRank-.5}
          -- Keep the intermediary adjacent to its destination in both planner
          -- groups; its distinct ID prevents row deduplication with the errand.
          local group,index
          for _,candidate in ipairs({ordered,deferred}) do
            for i,item in ipairs(candidate) do
              if item==target then group,index=candidate,i;break end
            end
            if group then break end
          end
          if group then
            if group==deferred then
              ordered[#ordered+1]=stage
            else
              table.insert(group,index,stage)
            end
            inserted=inserted+1
          end
        end
      end
      fromMap,fromX,fromY=target.mapID,target.x,target.y
    end
  end
  local result={ordered,deferred,map,x,y}
  if self.refreshPlans then self.refreshPlans[cacheKey]=result end
  if displayMap==nil then
    result.revision=self.errands.revision or 0
    result.character=self.db.character
    result.planner=self.Plan
    self.planSnapshot=result
  end
  return unpack(result,1,5)
end
function addon:CachedPlan()
  local snapshot=self.planSnapshot
  local map=self:Position()
  if snapshot and snapshot.revision==(self.errands.revision or 0) and
      snapshot.character==self.db.character and snapshot.planner==self.Plan and
      snapshot[3]==map then return unpack(snapshot,1,5) end
  return self:Plan()
end
function addon:Refresh()
  self.planSnapshot=nil
  self.refreshPlans={}
  local ok,err=pcall(function()
    if self.ui then self.ui:Refresh() end
    if self.worldMap then self.worldMap:Refresh() end
    if self.destinations then self.destinations:Refresh() end
    self:RevalidateNavigation()
    if self.minimap and self.minimap.RefreshFromCachedPlan then
      self.minimap:RefreshFromCachedPlan()
    end
  end)
  self.refreshPlans=nil
  if not ok then error(err) end
end
function addon:ActivateTarget(id)
  local bucket = self.db.data.characters[self.db.character]
  if id ~= nil then
    local item = self.errands:Get(id)
    if not item or item.completed then return false end
    self.errands:Reorder(id,1)
  end
  bucket.activeErrandId = id
  if self.navigation then self.navigation.paused = nil end
  self.waypointUIExplicit = true
  self:Refresh()
  return true
end
function addon:ActiveTarget(ordered, deferred)
  local bucket = self.db.data.characters[self.db.character]
  -- The display order is authoritative, including old persisted selections.
  -- Explicit activation moves an item to slot one rather than hiding a second
  -- navigation order behind the sidebar. Unlocated first rows remain honest.
  bucket.activeErrandId = nil
  for _, item in ipairs(self.route:DisplayOrder(ordered, deferred)) do
    if item.transitForId then
      local original=self.errands:Get(item.transitForId)
      if original and not original.completed then
        bucket.activeErrandId=item.transitForId
        return item
      end
    else
      local saved = item.id and self.errands:Get(item.id)
      if saved and not saved.completed then
        bucket.activeErrandId = item.id
        return item
      end
    end
  end
end
-- Arrival consumes only the queue entry, not evidence of service or quest completion.
function addon:CheckArrival(map, x, y)
  if self.boatTrips and self.boatTrips.pending then return false end
  if not map or not x or not y or type(UnitOnTaxi) ~= 'function' then return false end
  local taxiOK, taxi = pcall(UnitOnTaxi, 'player')
  if not taxiOK or not safe(taxi) or taxi ~= false then return false end
  local width, height = self:MapWorldSize(map)
  if not width or not height then return false end
  local ok, ordered, deferred = pcall(self.CachedPlan, self)
  if not ok or type(ordered) ~= 'table' then return false end
  local target = self:ActiveTarget(ordered, deferred)
  if not target or not target.id or target.mapID ~= map or
      target.approximate or target.projectedWaypoint or
      type(target.x) ~= 'number' or type(target.y) ~= 'number' or
      not safe(target.x) or not safe(target.y) or
      target.x ~= target.x or target.y ~= target.y or
      target.x < 0 or target.x > 1 or target.y < 0 or target.y > 1 then return false end
  if target.floor ~= nil then
    -- TrailRecorder reports floor=0 when the native API cannot identify a floor.
    -- Zero is not evidence that the player is on floor zero.
    if type(target.floor) ~= 'number' or target.floor < 1 or
        target.floor > 50 or target.floor % 1 ~= 0 then return false end
    local sampleOK, sample = pcall(function() return self.trails:NativeSample() end)
    if not sampleOK or not sample or sample.uiMapID ~= map or
        sample.floor ~= target.floor then return false end
  else
    -- Only an identified, ungrouped outdoor zone can use 2D coordinates alone.
    -- Missing map metadata, grouped floors and dungeon/micro maps are ambiguous.
    local ok, outdoor = pcall(function()
      if not C_Map or type(C_Map.GetMapInfo) ~= 'function' or
          type(C_Map.GetMapGroupID) ~= 'function' then return false end
      local info = C_Map.GetMapInfo(map)
      return info and info.mapType == 3 and C_Map.GetMapGroupID(map) == nil
    end)
    if not ok or not outdoor then return false end
  end
  local dx, dy = (x-target.x)*width, (y-target.y)*height
  -- Tolerate floating-point representation at exactly two yards only.
  if math.sqrt(dx*dx + dy*dy) > 2 + 0.000001 then return false end
  if target.transitForId then
    if not self.errands:Get(target.transitForId) then return false end
    self.taxiStageDone=self.taxiStageDone or {}
    self.taxiStageDone[target.transitForId]=self.errands:Get(target.transitForId)
    self.movementOrigin={map=map,x=x,y=y}
    self:Refresh()
    return true
  end
  local saved = self.errands:Get(target.id)
  if not saved or saved.completed then return false end
  self.errands:Delete(saved.id)
  local bucket = self.db.data.characters[self.db.character]
  if bucket.activeErrandId == saved.id then bucket.activeErrandId = nil end
  self.movementOrigin = {map=map,x=x,y=y}
  self:Refresh()
  return true
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
    if not self.movementTaxi then
      if self.taxiAdvice then self.taxiAdvice:Depart() end
      self.movementTaxi=true
      local snapshot=self.planSnapshot
      if snapshot and snapshot[1] then
        for _,item in ipairs(snapshot[1]) do
          if item.transitForId then
            self.planSnapshot=nil
            self:Refresh() -- Drop cached takeoff stages immediately on boarding.
            break
          end
        end
      end
    end
    if self.taxiAdvice and self.taxiAdvice.pending then
      local map,x,y=self:Position()
      self.taxiAdvice:Sample(map,x,y,function(m,a,b)
        if self.navigation and self.navigation.WorldPosition then
          return self.navigation:WorldPosition(m,a,b)
        end
      end)
    end
    self.movementTaxi = true
    self.movementOrigin = nil
    return false
  end
  if self.movementTaxi then
    if not taxiKnown then return false end
    local map, x, y = self:Position()
    if not map or not x or not y then
      if self.taxiAdvice then self.taxiAdvice.pending=nil end
      self.movementOrigin=nil
      return false
    end
    self.movementTaxi = false
    if self.taxiAdvice then self.taxiAdvice:Landed(map,x,y) end
    self.movementOrigin = {map=map,x=x,y=y}
    if self:CheckArrival(map, x, y) then return true end
    self:Refresh() -- A landing may move the player even without a zone event.
    return true
  end
  local map, x, y = self:Position()
  if self.boatTrips and self.boatTrips.pending then
    -- User-confirmed ride has no automatic landing detector or endpoint sample.
    self.movementOrigin=nil
    return false
  end
  if not map or not x or not y then
    self.movementOrigin = nil
    return false
  end
  if self:CheckArrival(map, x, y) then return true end
  local prior = self.movementOrigin
  self.movementOrigin = prior or {map=map, x=x, y=y}
  if not prior then return false end
  if prior.map ~= map then
    self.movementOrigin = {map=map, x=x, y=y}
    self:Refresh()
    return true
  end
  local width, height = self:MapWorldSize(map)
  if not width then return false end -- No yard scale means no honest 10-yard test.
  local dx, dy = (x-prior.x)*width, (y-prior.y)*height
  if dx*dx + dy*dy < 100 then return false end
  self.movementOrigin = {map=map, x=x, y=y}
  self:Refresh()
  return true
end
function addon:PublishWaypointUI(target, explicit)
  if self.waypointUI then pcall(self.waypointUI.Update,self.waypointUI,target,explicit) end
end
function addon:RevalidateNavigation(ordered, deferred)
  local explicit=self.waypointUIExplicit
  self.waypointUIExplicit=nil
  -- Recheck only the waypoint owned by ErrandMaster; other TomTom pins are untouched.
  if not self.navigation then return end
  if not ordered then
    local ok, result, pending = pcall(self.CachedPlan, self)
    if not ok or not safe(result) or type(result) ~= "table" then
      self.navigation:Clear()
      self:PublishWaypointUI(nil)
      if self.navigationArrow then self.navigationArrow:Refresh() end
      return
    end
    ordered, deferred = result, pending
  end
  local target = self:ActiveTarget(ordered, deferred)
  self:PublishWaypointUI(target,explicit)
  local map = self:Position()
  self.navigation:Next(target and target.mapID == map and target or nil)
  if target and target.mapID ~= map then self.navigation.target = target end
  if self.navigationArrow then self.navigationArrow:Refresh() end
end
function addon:NavigateNext()
  self.navigation.paused = nil -- Explicit navigation resumes after a manual Clear pin.
  local route, deferred = self:Plan()
  local nextItem = self:ActiveTarget(route, deferred)
  self:PublishWaypointUI(nextItem,true)
  if not nextItem then
    if not self.navigation:Clear() then
      self:Print('Old ErrandMaster TomTom pin could not be removed; clear it in TomTom.')
    end
    if self.navigationArrow then self.navigationArrow:Refresh() end
    self:Print('No active target with a usable position on this map.')
    return
  end
  local map = self:Position()
  local used, status = self.navigation:Next(nextItem.mapID == map and nextItem or nil)
  if nextItem.mapID ~= map then self.navigation.target = nextItem end
  if self.navigationArrow then self.navigationArrow:Refresh() end
  if not nextItem.mapID or nextItem.mapID ~= map or not nextItem.x then
    self:Print('Active target has no same-map coordinates. Direction unknown.')
    local nearby = nextItem.nearbyZoneCandidate
    if type(nearby) == "table" and safe(nearby) then
      local ok, zone, distance = pcall(function()
        return nearby.zoneName, nearby.directYards
      end)
      if ok and safe(zone) and safe(distance) and type(zone) == "string" and
          #zone > 0 and #zone <= 80 and not zone:find("[%c|]") and
          type(distance) == "number" and distance == distance and
          distance >= 0 and distance <= 10000 then
        self:Print(string.format("Projected candidate in %s, ~%.0f yd straight-line; route unknown.",
          zone, distance))
      end
    end
    return
  end
  self:Print(string.format('Next: %s (map %d, %.1f, %.1f%s). %s',
    nextItem.name, nextItem.mapID, nextItem.x*100, nextItem.y*100,
    nextItem.approximate and '; approximate position' or '',
    used and (status == 'observed-route' and
      'Following observed connectors only; unobserved links remain unknown.' or
      'Native direct-bearing (DIRECT); route unknown.') or
      (status == 'old-pin' and 'Old owned pin could not be removed.' or
      'Native direction unavailable.')))
  if nextItem.taxiAdvice then
    local flight=nextItem.taxiAdvice
    if flight.connectionStatus=='unconfirmed' then
      self:Print(string.format('Possible flight via %s → %s; ~%.0f yd less straight-line ground distance. Connection and unlock status unconfirmed; verify at the flight master. No faster ETA or walkable path implied.',
        flight.originNode,flight.nodeName,flight.savedYards))
    else
      self:Print(string.format('Observed flight %s → %s; ~%.0f yd estimated walking-distance reduction (straight-line only, not faster ETA or walkability). Board manually; current unlock status unverified.',
        flight.originNode,flight.nodeName,flight.savedYards))
    end
  elseif nextItem.boatAdvice then
    local hint=nextItem.boatAdvice
    if hint.savedYards then
      self:Print(string.format('User-confirmed boat to recorded landing; ~%.0f yd estimated walking-distance reduction (straight-line only, not faster ETA or walkability). Board manually; /em boat start when boarded, /em boat arrive when disembarked.',hint.savedYards))
    else
      self:Print('User-confirmed boat connection to recorded landing across worlds; walking improvement unknown. Board manually; /em boat start when boarded, /em boat arrive when disembarked. No boarding detection or ETA.')
    end
  end
  if nextItem.walkStatus ~= 'known-route' then
    self:Print('Walking path unknown; coordinates indicate a point, not a proven route.')
  end
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
function addon:FinishTargetOnInteraction(event, questID)
  -- UI interactions are neither arrival evidence nor proof a task was done.
  -- Only CheckArrival consumes a queue entry; it never sets completed.
  return false
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
    if self.addonSettings then self.addonSettings:Open() end
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
        if self.taxiAdvice then self:Refresh() end -- consent changes invalidate flight stages
        self:Print("Ground-movement observation " .. argument .. ".")
      end
    else self:Print("Use /em trails status, on, off, clear, or confirm. Recording is per character and off by default.") end
  elseif command == "transport" then
    local taxi=self.taxiAdvice
    if argument == "status" then
      self:Print(string.format("Flight learning for this character: %s; %d/64 observed legs (client build scoped). Ground trails are independent.",
        taxi and taxi:IsEnabled() and "on" or "off",taxi and taxi.legCount or 0))
    elseif argument == "clear" then
      local now=seconds()
      if now and taxi then
        taxi.pendingClear={character=self.db.character,expires=now+30}
        self:Print("No flight data deleted. Type /em transport confirm within 30 seconds to reset this character's learned flights.")
      else self:Print("Cannot arm flight reset: game clock unavailable.") end
    elseif argument == "confirm" then
      local pending,now=taxi and taxi.pendingClear,seconds()
      if taxi then taxi.pendingClear=nil end
      if pending and now and pending.character==self.db.character and now<=pending.expires and
          taxi:ClearLearned() then
        self:Refresh();self:Print("This character's learned flights cleared. Flight learning setting unchanged.")
      else self:Print("No active flight reset request. Use /em transport clear first.") end
    elseif argument == "on" or argument == "off" then
      if taxi and taxi:SetEnabled(argument=="on") then
        self:Refresh();self:Print("Flight learning "..argument.."; ground trails unchanged.")
      else self:Print("Transport storage unavailable; setting was not changed.") end
    else self:Print("Use /em transport status, on, off, clear, or confirm.") end
  elseif command == "boat" then
    local boat=self.boatTrips
    local bound=self:BoatBound()
    if argument=='status' then
      self:Print(bound and string.format('Boat recording %s; %d/64 user-confirmed directed legs; %s. Start means boarded, arrive means disembarked; no automatic boat detection.',
        boat.bucket.enabled and 'on' or 'off',#boat.bucket.legs,
        boat.pending and 'trip pending' or 'no trip pending') or
        'Boat storage or build scope unavailable; existing data preserved.')
    elseif not bound then
      self:Print('Boat storage or build scope unavailable; existing data preserved.')
    elseif argument=='start' then
      local map,x,y=self:Position()
      if boat:Begin(map,x,y) then
        self.movementOrigin=nil;self:Refresh()
        self:Print('Boat boarded at actual current position; recording ride only. /em boat arrive when disembarked, or /em boat cancel. No automatic boat detection.')
      else self:Print('Cannot start boat ride: recording off, position or clock unavailable.') end
    elseif argument=='arrive' then
      local map,x,y=self:Position()
      if boat:Arrive(map,x,y) then
        self.movementOrigin={map=map,x=x,y=y}
        self:Refresh()
        self:Print('Boat disembarked at actual current position; directed journey saved. Onward target recalculated; no automatic boat detection or ETA.')
      else
        -- Failed arrival consumes the ticket; drop any stale transient plan.
        self:Refresh()
        self:Print('Boat arrival not saved: no pending ride, invalid position/time, or storage full.')
      end
    elseif argument=='cancel' then
      boat:Cancel();self:Refresh()
      self:Print('Pending boat journey canceled; no leg saved.')
    elseif argument=='on' or argument=='off' then
      boat:Cancel() -- Toggling consent invalidates even an in-progress ticket.
      boat.bucket.enabled=argument=='on'
      boat.pendingClear=nil
      self:Refresh()
      self:Print('Boat recording '..argument..'; any pending journey canceled. Ground trails and flights unchanged.')
    elseif argument=='clear' then
      local now=seconds()
      if now then
        boat.pendingClear={character=self.db.character,scope=boat.scope,expires=now+30}
        self:Print('No boat evidence deleted. Type /em boat confirm within 30 seconds to clear only this character\'s boat legs.')
      else self:Print('Cannot arm boat reset: game clock unavailable.') end
    elseif argument=='confirm' then
      local pending,now=boat.pendingClear,seconds()
      boat.pendingClear=nil
      if pending and now and pending.character==self.db.character and
          pending.scope==boat.scope and now<=pending.expires then
        boat:Cancel();boat.bucket.legs={};boat.bucket.build=boat.scope
        boat.bucket.character=self.db.character
        self.taxiStageDone=nil
        self:Refresh()
        self:Print('This character\'s boat legs cleared; boat recording setting unchanged.')
      else self:Print('No active boat reset request. Use /em boat clear first.') end
    else self:Print('Use /em boat start, arrive, cancel, status, on, off, clear, or confirm. Start=boarded; arrive=disembarked.') end
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
    if argument == "settings" then
      if self.addonSettings then self.addonSettings:Open() end
    elseif self.radial then
      local frame=self.radial.frame
      local wasShown=frame and frame.IsShown and frame:IsShown()
      if not self.radial:Open() and not wasShown then
        self:Print("Wheel unavailable in combat or without cursor position.")
      end
    end
  elseif command == "discover" then
    local value = argument and argument:lower()
    if value == "status" then
      self:Print("Passive service discovery "..(self.db.data.settings.discoverServices and 'on' or 'off')..".")
      local report=self.discovery.lastReport
      if not report then self:Print("No service observation report this session.")
      else
        local saved,failed={},{}
        for category in pairs(report.saved) do saved[#saved+1]=category end
        for category,reason in pairs(report.failures) do failed[#failed+1]=category..'='..reason end
        table.sort(saved); table.sort(failed)
        self:Print("Last observation saved: "..(#saved>0 and table.concat(saved,', ') or 'none'))
        if #failed>0 then self:Print("Partial observation: "..table.concat(failed,', ')) end
      end
    elseif value ~= "on" and value ~= "off" then
      self:Print("Use /em discover on, off or status. Recording is character-only.")
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
    local explain=argument and argument:match("^explain%s+(.+)$")
    if explain and #explain<=80 then
      local map=self:Position()
      local report=self.npcs:Diagnostics(map,explain)
      self:Print(string.format("NPC coverage map %s [%s]: %s; %d candidate spawns; %d faction-excluded; inventory %s%s.",
        tostring(map or 'unknown'),explain,report.state,report.candidates,report.factionExcluded,
        report.inventoryEvidence,report.mapLimited and '; map incomplete' or ''))
      if report.limited then self:Print("Provider coverage limited: "..(report.reason or 'incomplete records')) end
      self:Print("No inventory evidence means unknown coverage, not proof that no seller exists. Candidate evidence is not live stock or a walking route.")
      local failures={}
      for code,count in pairs(report.issues) do failures[#failures+1]=code..'='..count end
      table.sort(failures)
      if #failures>0 then self:Print("Catalog-wide issues: "..table.concat(failures,', ')) end
      local mapFailures={}
      for code,count in pairs(report.mapIssues or {}) do mapFailures[#mapFailures+1]=code..'='..count end
      table.sort(mapFailures)
      if #mapFailures>0 then self:Print("Map issues: "..table.concat(mapFailures,', ')) end
    elseif status.normalizing then
      self:Print(string.format("QuestieDB Forever: normalizing provider IDs (%d entries inspected); record totals pending.",
        status.normalizedEntries))
    elseif argument == "status" or not self.npcs:IsReady() then
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
          self:Print("NPCs: /em npcs find <text>, explain <service>, status, all; add: /em npc add <id>")
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
    self:Print("walking on/off, trails on/off, transport on/off, discover on/off, settings, wheel")
    self:Print("wheel settings, poi <category>, locations, forget <id>, debug, help")
  else self:Print("Unknown command. Type /em help.") end
end
function addon:BindBoat()
  local boat,taxi=self.boatTrips,self.taxiAdvice
  if not boat or not taxi or not self.db or not self.db.data then return false end
  local scope=taxi.scope
  -- Unknown project/build is not a durable identity for recorded endpoints.
  if type(scope)~='string' or #scope>80 then return false end
  local project,build,interface=scope:match('^(%d+):(%d+):(%d+)$')
  if not project or tonumber(project)==0 or tonumber(build)==0 or
      tonumber(interface)==0 then return false end
  local ok,bucket=pcall(self.db.BoatBucket,self.db)
  if not ok or not bucket then return false end
  return boat:Bind(bucket,self.db.character,scope)
end
function addon:BoatBound()
  local boat=self.boatTrips
  return boat and boat.bucket and boat.character==self.db.character and
    self.db.data.characters[self.db.character].boat==boat.bucket and
    (boat.bucket.build==nil or boat.bucket.build==boat.scope) and
    (boat.bucket.character==nil or boat.bucket.character==self.db.character) and
    self.taxiAdvice and boat.scope==self.taxiAdvice.scope
end
local events = CreateFrame("Frame")
-- TakeTaxiNode(index) is the documented native selection API. Observe it only
-- when the legacy indexed taxi-node snapshot actually identifies that index.
function addon:InstallTaxiHook()
  if self.taxiHookInstalled or not self.taxiAdvice or
      type(hooksecurefunc)~='function' or type(TakeTaxiNode)~='function' then return false end
  local ok=pcall(hooksecurefunc,'TakeTaxiNode',function(index)
    local map,x,y=self:Position()
    self.taxiAdvice:SelectedNode(index,map,x,y)
  end)
  if ok then self.taxiHookInstalled=true end
  return ok
end
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
    if addon.objects then addon.objects:Initialize() end
    if addon.trails and not addon.trails:Bind() then
      addon:Print("Trail storage is unavailable; its saved data was preserved. Other features remain available.")
    end
    if addon.taxiAdvice and addon.taxiAdvice.Bind and not addon.taxiAdvice:Bind() then
      addon:Print("Transport storage is unavailable; its saved data was preserved. Flight learning is off.")
    end
    if addon.boatTrips and not addon:BindBoat() then
      addon:Print("Boat storage or client build scope unavailable; saved boat data preserved. Boat recording and advice disabled.")
    end
    addon:InstallTaxiHook()
    addon.ui:Create()
    if addon.addonSettings then addon.addonSettings:Register() end
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
        "BANKFRAME_OPENED", "TRAINER_SHOW", "GOSSIP_SHOW", "QUEST_TURNED_IN"}) do
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
      if addon.objects and addon.objects.state=='indexing' then
        local ok,done=pcall(addon.objects.Step,addon.objects,40)
        if not ok then
          addon.objects.state,addon.objects.reason='unavailable','Object index could not be read'
        elseif done then addon:Refresh() end
      end
      if type(dt) ~= "number" or dt ~= dt or dt < 0 or dt > 10 then return end
      movementElapsed = movementElapsed + dt
      if movementElapsed >= .5 then
        movementElapsed = 0
        if #addon.errands:All() > 0 or (addon.taxiAdvice and
            (addon.taxiAdvice.selection or addon.taxiAdvice.pending or addon.movementTaxi)) then
          local ok, err = pcall(addon.MovementTick, addon)
          if not ok and addon.db.data.settings.debug then addon:Print("Movement: " .. tostring(err)) end
        else addon.movementOrigin = nil end
      end
      local recording = addon.trails and addon.trails:IsEnabled()
      local activeNavigation = addon.navigation and addon.navigation.target and
        not addon.navigation.paused
      if not recording and not addon.navigation.handle and not activeNavigation then
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
  if addon.transportCatalog then addon.transportCatalog:OnEvent(event) end
  if event == "ADDON_LOADED" and name == addonName then
    addon.loaded = true
    initialize()
  elseif event == "ADDON_LOADED" and name == "WaypointUI" and addon.db.data then
    addon:RevalidateNavigation() -- Optional provider may initialize after us.
  elseif event == "ADDON_LOADED" and name == "Blizzard_WorldMap" and addon.db.data then
    if addon.worldMap then addon.worldMap:Attach() end
  elseif event == "PLAYER_LOGIN" and addon.loaded and not addon.ui.frame then
    initialize()
  elseif addon.db.data and (event=="TAXIMAP_OPENED" or
      event=="TAXI_NODE_STATUS_CHANGED") and addon.taxiAdvice then
    addon:InstallTaxiHook()
    local ok=pcall(addon.taxiAdvice.Capture,addon.taxiAdvice)
    if not ok then addon.taxiAdvice:Clear()
    else
      local map,x,y=addon:Position()
      addon.taxiAdvice:CaptureOrigin(map,x,y)
    end
    addon:Refresh()
  elseif addon.db.data and event=="TAXIMAP_CLOSED" and addon.taxiAdvice then
    addon.taxiAdvice:Clear()
    addon:Refresh()
  elseif addon.db.data and (event == "MERCHANT_SHOW" or event == "MAIL_SHOW" or
      event == "AUCTION_HOUSE_SHOW" or event == "BANKFRAME_OPENED" or
      event == "TRAINER_SHOW") then
    local ok, err = pcall(addon.discovery.HandleEvent, addon.discovery, event)
    if not ok and addon.db.data.settings.debug then addon:Print("Discovery: " .. tostring(err)) end
    if ok and err then addon:Refresh() end -- Newly observed services invalidate cached choices.

  elseif addon.db.data and (event == "GOSSIP_SHOW" or event == "QUEST_TURNED_IN") then
    -- No implicit completion on gossip or quest/service UI events.
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
