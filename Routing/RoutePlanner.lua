local _, addon = ...
addon.route = {}
local route = addon.route
local function distance(x1,y1,x2,y2,width,height)
  local dx, dy = (x1-x2)*width, (y1-y2)*height
  return dx*dx + dy*dy
end
local function validSize(n)
  return type(n) == "number" and n == n and n > 0 and n <= 10000000
end
local function copy(item)
  local result = {}
  for key, value in pairs(item) do result[key] = value end
  return result
end
local function usePlace(item, place)
  item.mapID, item.x, item.y = place.mapID, place.x, place.y
  item.locationID, item.locationSource = place.id, place.source
  item.approximate = place.precision == "approximate"
  item.npcID, item.phaseUnverified = place.npcID, place.phaseUnverified
  if item.origin == "suggested" and type(place.name) == "string" and
      #place.name <= 80 and not place.name:find("[%c|]") then
    item.name = place.name
  end
  return item
end

-- Same-map distance is a straight line. World dimensions, when known, are yards.
function route:Plan(errands, mapID, x, y, optimize, locations, questPOIs, width, height, walkContext)
  local eligible, deferred, output = {}, {}, {}
  local canLocate = type(x) == "number" and type(y) == "number" and x == x and y == y and
    x >= 0 and x <= 1 and y >= 0 and y <= 1
  local worldSize = validSize(width) and validSize(height)
  local dx, dy = worldSize and width or 1, worldSize and height or 1
  local questByID = {}
  for _, poi in ipairs(questPOIs or {}) do
    if poi.mapID == mapID and validSize(poi.questID) and type(poi.x) == "number" and
        type(poi.y) == "number" and poi.x >= 0 and poi.x <= 1 and
        poi.y >= 0 and poi.y <= 1 then questByID[poi.questID] = poi end
  end
  for _, item in ipairs(errands) do
    if not item.completed then
      if item.questID then
        local poi = questByID[item.questID]
        if poi then
          local resolved = copy(item)
          resolved.mapID, resolved.x, resolved.y = poi.mapID, poi.x, poi.y
          resolved.questLocationSource = poi.source
          resolved.projectedWaypoint = poi.projected == true
          eligible[#eligible+1] = resolved
        else deferred[#deferred+1] = item end
      elseif mapID and item.mapID == mapID and type(item.x) == "number" and
          type(item.y) == "number" and item.x == item.x and item.y == item.y and
          item.x >= 0 and item.x <= 1 and item.y >= 0 and item.y <= 1 then
        eligible[#eligible+1] = copy(item)
      else
        local nearest, score, matches = nil, nil, {}
        local wanted = item.category
        if wanted == "Class Trainer" then
          local class = addon.discovery and addon.discovery:PlayerClass()
          wanted = class and class .. " Trainer"
        end
        if canLocate and mapID and not item.mapID and type(wanted) == "string" and locations then
          for _, place in ipairs(locations) do
            if place.mapID == mapID and type(place.category) == "string" and
                (not item.npcID or place.npcID == item.npcID) and wanted and
                  (place.category:lower() == wanted:lower() or
                    (place.specialty and place.specialty:lower() == wanted:lower()) or
                    (place.trainerGroup and place.trainerGroup:lower() == wanted:lower()) or
                    (place.vendorGroup and place.vendorGroup:lower() == wanted:lower()) or
                    (wanted == "Vendor" and place.category:sub(-7) == " Vendor")) and
                type(place.x) == "number" and type(place.y) == "number" and
                place.x >= 0 and place.x <= 1 and place.y >= 0 and place.y <= 1 then
              local current = distance(x, y, place.x, place.y, dx, dy)
              local named = type(place.name) == "string" and place.name:sub(1, 9) ~= "Observed "
              local priorAnonymous = nearest and type(nearest.name) == "string" and
                nearest.name:sub(1, 9) == "Observed "
              if not score or current < score or
                  (current == score and named and priorAnonymous) then
                nearest, score = place, current
              end
              matches[#matches+1] = place
            end
          end
        end
        if nearest then
          local resolved = copy(item)
          if walkContext and walkContext.mode == "observed" then
            resolved.locationCandidates = matches
          else usePlace(resolved, nearest) end
          eligible[#eligible+1] = resolved
        else
          deferred[#deferred+1] = item
        end
      end
    end
  end
  if walkContext and walkContext.mode == "observed" then
    local cx, cy = x, y
    local floor = walkContext.floor or 0
    local originWorld, originZ = walkContext.worldMapID, walkContext.wz
    local cumulative = 0
    local built = addon.walkGraph and addon.walkGraph:Build(walkContext.nodes,
      walkContext.edges,walkContext.playerLevel)
    while #eligible > 0 do
      local best, score, bestPath, bestPriority, bestTo, bestPlace, prepared
      if canLocate and addon.walkGraph then
        local from = {uiMapID=mapID,floor=floor,x=cx,y=cy,
          worldMapID=originWorld,wz=originZ}
        prepared = addon.walkGraph:PrepareBuilt(built,from)
        local assessed = {}
        for i, item in ipairs(eligible) do
          for _, place in ipairs(item.locationCandidates or {item}) do
            local known = place.id and assessed[place.id]
            local to, path
            if known then to, path = known.to, known.path
            else
              to = {uiMapID=place.mapID,floor=place.floor or floor,x=place.x,y=place.y,
                worldMapID=place.worldMapID,wz=place.wz}
              path = addon.walkGraph:Assess(prepared,to)
              if place.id then assessed[place.id] = {to=to,path=path} end
            end
            local priority = path.status == "known-route" and 0 or 1
            local eligiblePath = path.status == "known-route" or
              (path.status == "partial-route" and path.hasSegment)
            local better = eligiblePath and (not best or (not optimize and
              (i < best or (i == best and (priority < bestPriority or
                (priority == bestPriority and path.weightedCost < score))))) or
              (optimize and (priority < bestPriority or
                (priority == bestPriority and path.weightedCost < score))))
            if better then
              best, score, bestPath, bestPriority, bestTo, bestPlace =
                i, path.weightedCost, path, priority, to,
                item.locationCandidates and place or nil
            end
          end
        end
      end
      if not best then
        for _, item in ipairs(eligible) do
          item.walkStatus = "unknown-route"
          deferred[#deferred+1] = item
        end
        break
      end
      local selected = table.remove(eligible,best)
      if bestPlace then usePlace(selected,bestPlace); selected.locationCandidates=nil end
      bestPath = addon.walkGraph:FromPrepared(prepared, bestTo)
      selected.walkStatus = bestPath.status
      selected.walkYards = bestPath.yards
      selected.walkWaypoints = bestPath.waypoints
      selected.walkWarning = bestPath.warning
      selected.unknownStart = bestPath.unknownStart
      selected.unknownEnd = bestPath.unknownEnd
      cumulative = cumulative + bestPath.yards
      selected.cumulativeWalkYards = cumulative
      output[#output+1] = selected
      -- One catalog candidate can satisfy several errands at the same stop.
      -- Keep every errand, but do not plan an extra leg from an uncertain end.
      if bestPlace then
        local j=1
        while j<=#eligible do
          local item = eligible[j]
          local shared=false
          for _, candidate in ipairs(item.locationCandidates or {}) do
            if candidate == bestPlace then
              usePlace(item,bestPlace)
              item.locationCandidates = nil
              item.walkStatus, item.walkYards = bestPath.status, 0
              item.walkWaypoints, item.walkWarning = bestPath.waypoints, bestPath.warning
              item.unknownStart, item.unknownEnd = bestPath.unknownStart, bestPath.unknownEnd
              item.cumulativeWalkYards = cumulative
              output[#output+1] = item
              table.remove(eligible,j)
              shared=true
              break
            end
          end
          if not shared then j=j+1 end
        end
      end
      cx, cy, floor = selected.x, selected.y, selected.floor or floor
      local lastNode = bestPath.waypoints[#bestPath.waypoints]
      originWorld, originZ = lastNode.worldMapID, lastNode.wz
      if bestPath.status == "partial-route" then
        for _, item in ipairs(eligible) do
          item.walkStatus = "unknown-route"
          deferred[#deferred+1] = item
        end
        break -- The unobserved endpoint cannot become the next verified origin.
      end
    end
  elseif optimize and canLocate then
    local cx, cy = x, y
    while #eligible > 0 do
      local best, score = 1, math.huge
      for i, item in ipairs(eligible) do
        local current = distance(cx, cy, item.x, item.y, dx, dy)
        if current < score then best, score = i, current end
      end
      local selected = table.remove(eligible, best)
      output[#output+1] = selected
      cx, cy = selected.x, selected.y
    end
  else output = eligible end
  if worldSize and canLocate then
    local cx, cy, cumulative = x, y, 0
    for _, item in ipairs(output) do
      item.directYards = math.sqrt(distance(cx, cy, item.x, item.y, width, height))
      cumulative = cumulative + item.directYards
      item.cumulativeYards = cumulative
      cx, cy = item.x, item.y
    end
  end
  return output, deferred
end
