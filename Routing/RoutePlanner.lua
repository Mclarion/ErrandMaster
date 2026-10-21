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
local function located(point)
  return point and type(point.mapID)=='number' and point.mapID>=1 and
    type(point.x)=='number' and type(point.y)=='number' and
    point.x>=0 and point.x<=1 and point.y>=0 and point.y<=1
end
-- Unlocated requests are visible but cannot displace a known destination.
-- Walking evidence is independent of whether the destination is located.
function route:DisplayOrder(ordered, deferred)
  local all, unknown, anchors, free = {}, {}, {}, {}
  for _, group in ipairs({ordered or {}, deferred or {}}) do
    for _, item in ipairs(group) do
      if located(item) then all[#all+1] = item
      else unknown[#unknown+1] = item end
    end
  end
  local sequential=#all>0
  for _,item in ipairs(all) do
    if type(item.sequenceRank)~='number' then sequential=false; break end
  end
  if sequential then
    table.sort(all,function(a,b) return a.sequenceRank<b.sequenceRank end)
    for _,item in ipairs(unknown) do all[#all+1]=item end
    return all
  end
  for _, item in ipairs(all) do
    local rank = item.manualPosition
    if type(rank) == 'number' and rank == rank and rank % 1 == 0 and rank >= 1 then
      anchors[#anchors+1] = item
    else free[#free+1] = item end
  end
  table.sort(anchors, function(a,b)
    if a.manualPosition == b.manualPosition then return tostring(a.id) < tostring(b.id) end
    return a.manualPosition < b.manualPosition
  end)
  local result = {}
  for _, item in ipairs(anchors) do
    local slot = math.min(item.manualPosition, #all)
    while result[slot] and slot < #all do slot = slot + 1 end
    if result[slot] then slot=1; while result[slot] do slot=slot+1 end end
    result[slot] = item
  end
  local nextFree = 1
  for i=1,#all do
    if not result[i] then result[i],nextFree=free[nextFree],nextFree+1 end
  end
  for _,item in ipairs(unknown) do result[#result+1]=item end
  return result
end
local function usePlace(item, place)
  item.mapID, item.x, item.y, item.floor = place.mapID, place.x, place.y, place.floor
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
          resolved.mapID, resolved.x, resolved.y, resolved.floor = poi.mapID, poi.x, poi.y, poi.floor
          resolved.questLocationSource = poi.source
          resolved.projectedWaypoint = poi.projected == true
          resolved.areaTarget = poi.areaTarget == true
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
        local professions = wanted == "Profession Trainer" and
          addon.ProfessionFilters and addon:ProfessionFilters() or nil
        if canLocate and mapID and not item.mapID and type(wanted) == "string" and locations then
          for _, place in ipairs(locations) do
            local professionMatch=not professions or #professions==0
            if not professionMatch and type(place.specialty)=="string" then
              for _,profession in ipairs(professions) do
                if place.specialty:lower()==(profession.." Trainer"):lower() then
                  professionMatch=true; break
                end
              end
            end
            if place.mapID == mapID and type(place.category) == "string" and
                professionMatch and (not item.npcID or place.npcID == item.npcID) and wanted and
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
  -- Manual positions reserve only their own slots; the other stops remain
  -- optimizable. Filtered maps can leave gaps, which we clamp locally.
  local anchors, reserved, anchored = {}, {}, {}
  for _, item in ipairs(eligible) do
    if type(item.manualPosition) == 'number' and item.manualPosition == item.manualPosition and
        item.manualPosition % 1 == 0 and item.manualPosition >= 1 then
      anchored[#anchored+1] = item
    end
  end
  table.sort(anchored, function(a,b)
    if a.manualPosition == b.manualPosition then return tostring(a.id) < tostring(b.id) end
    return a.manualPosition < b.manualPosition
  end)
  for _, item in ipairs(anchored) do
    local slot = math.min(item.manualPosition, #eligible)
    while reserved[slot] and slot < #eligible do slot = slot + 1 end
    if reserved[slot] then
      slot = 1
      while reserved[slot] do slot = slot + 1 end
    end
    reserved[slot], anchors[item] = item, slot
  end
  if walkContext and walkContext.mode == "observed" then
    local cx, cy = x, y
    local floor = walkContext.floor or 0
    local originWorld, originZ = walkContext.worldMapID, walkContext.wz
    local cumulative = 0
    local evidenceLost = false
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
            local known = not evidenceLost and place.id and assessed[place.id]
            local to, path
            if known then to, path = known.to, known.path
            else
              to = {uiMapID=place.mapID,floor=place.floor or floor,x=place.x,y=place.y,
                worldMapID=place.worldMapID,wz=place.wz}
              path = evidenceLost and {status='unknown-route'} or
                addon.walkGraph:Assess(prepared,to)
              if place.id then assessed[place.id] = {to=to,path=path} end
            end
            local priority = path.status == 'known-route' and 0 or
              (path.status == 'partial-route' and path.hasSegment) and 1 or 2
            local cost = priority == 2 and
              (place.mapID == mapID and type(place.x)=='number' and type(place.y)=='number' and
                distance(cx,cy,place.x,place.y,dx,dy) or math.huge) or path.weightedCost
            local required = reserved[#output+1]
            local allowed = required and item == required or not required and not anchors[item]
            local better = allowed and (not best or (not optimize and
              (i < best or (i == best and (priority < bestPriority or
                (priority == bestPriority and cost < score))))) or
              (optimize and (priority < bestPriority or
                (priority == bestPriority and cost < score))))
            if better then
              best, score, bestPath, bestPriority, bestTo, bestPlace =
                i, cost, path, priority, to,
                item.locationCandidates and place or nil
            end
          end
        end
      end
      if not best then
        -- Coordinates unavailable; do not fabricate a walking leg.
        for _, item in ipairs(eligible) do
          if item.locationCandidates then
            usePlace(item,item.locationCandidates[1]); item.locationCandidates=nil
          end
          item.walkStatus='unknown-route'
          output[#output+1]=item
        end
        break
      else
      local selected = table.remove(eligible,best)
      if bestPlace then usePlace(selected,bestPlace); selected.locationCandidates=nil end
      bestPath = evidenceLost and {status='unknown-route'} or
        addon.walkGraph:FromPrepared(prepared, bestTo)
      selected.walkStatus = bestPath.status
      selected.walkYards = bestPath.yards
      selected.walkWaypoints = bestPath.status ~= 'unknown-route' and bestPath.waypoints or nil
      selected.walkWarning = bestPath.warning
      selected.unknownStart = bestPath.unknownStart
      selected.unknownEnd = bestPath.unknownEnd
      if bestPath.yards then
        cumulative = cumulative + bestPath.yards
        selected.cumulativeWalkYards = cumulative
      end
      output[#output+1] = selected
      -- One catalog candidate can satisfy several errands at the same stop.
      -- Keep every errand, but do not plan an extra leg from an uncertain end.
      if bestPlace then
        local j=1
        while j<=#eligible do
          local item = eligible[j]
          local shared=false
          for _, candidate in ipairs(item.locationCandidates or {}) do
            if candidate == bestPlace and not anchors[item] then
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
      if bestPath.status == 'known-route' then
        local lastNode = bestPath.waypoints[#bestPath.waypoints]
        originWorld, originZ = lastNode.worldMapID, lastNode.wz
      else
        evidenceLost = true -- An unobserved endpoint cannot become a verified origin.
      end
      end
    end
  elseif optimize and canLocate then
    local cx, cy = x, y
    while #eligible > 0 do
      local best, score = 1, math.huge
      local required = reserved[#output+1]
      for i, item in ipairs(eligible) do
        if (required and item == required) or (not required and not anchors[item]) then
          local current = distance(cx, cy, item.x, item.y, dx, dy)
          if current < score then best, score = i, current end
        end
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
  for i,item in ipairs(deferred) do
    deferred[i]=copy(item)
    if deferred[i].questID then
      deferred[i].mapID,deferred[i].x,deferred[i].y,deferred[i].floor=nil,nil,nil,nil
    end
    deferred[i].canOverride=located(deferred[i])
  end
  for _,item in ipairs(output) do item.canOverride=located(item) end
  return output, deferred
end

function route:Matches(item,place)
  if not located(place) or type(place.category)~='string' or
      (item.npcID and item.npcID~=place.npcID) then return false end
  local wanted=item.category
  if wanted=='Class Trainer' then
    local class=addon.discovery and addon.discovery:PlayerClass()
    wanted=class and class..' Trainer'
  end
  if type(wanted)~='string' then return false end
  if wanted=='Profession Trainer' and addon.ProfessionFilters then
    local professions=addon:ProfessionFilters()
    if #professions>0 then
      local matched=false
      for _,profession in ipairs(professions) do
        if type(place.specialty)=='string' and place.specialty:lower()==(profession..' Trainer'):lower() then
          matched=true; break
        end
      end
      if not matched then return false end
    end
  end
  for _,field in ipairs({'category','specialty','trainerGroup','vendorGroup'}) do
    if type(place[field])=='string' and place[field]:lower()==wanted:lower() then return true end
  end
  return wanted=='Vendor' and place.category:sub(-7)==' Vendor'
end

-- Greedy route through requested functions, resolving each destination from
-- the preceding stop. Explicit locations stay fixed; only unresolved services
-- change NPC. Direct estimates never manufacture walking connectivity.
function route:Sequence(errands,origin,optimize,questPOIs,context)
  local active,questByID={},{ }
  for _,poi in ipairs(questPOIs or {}) do questByID[poi.questID]=poi end
  for _,item in ipairs(errands) do
    if not item.completed then
      local entry=copy(item); entry.sequenceRank=nil
      active[#active+1]=entry
    end
  end
  local function resolve(item,from)
    if item.questID then
      local poi=questByID[item.questID]
      if located(poi) then
        local result=copy(item)
        result.mapID,result.x,result.y,result.floor=poi.mapID,poi.x,poi.y,poi.floor
        result.questLocationSource,result.projectedWaypoint=poi.source,poi.projected==true
        result.areaTarget=poi.areaTarget==true
        return result,from and context.distance(from,result)
      end
      return
    end
    if located(item) then return copy(item),from and context.distance(from,item) end
    if item.mapID or not from then return end
    local best,bestDistance
    for _,place in ipairs(context.candidates(from,item) or {}) do
      if self:Matches(item,place) then
        local distance=context.distance(from,place)
        if type(distance)=='number' and distance>=0 and distance<math.huge and
            (not bestDistance or distance<bestDistance or
              (distance==bestDistance and tostring(place.id)<tostring(best.id))) then
          best,bestDistance=place,distance
        end
      end
    end
    if best then return usePlace(copy(item),best),bestDistance end
  end
  -- Classify by location before applying anchors. A missing service cannot
  -- consume a slot or erase the origin for destinations that do resolve.
  local known, unlocated, requests = {}, {}, {}
  for _,item in ipairs(active) do
    local preview=resolve(item,origin)
    if preview then
      preview.manualPosition=item.manualPosition
      known[#known+1]=preview
      requests[preview]=item
    else
      item.canOverride=false
      item.walkStatus='unknown-route'
      if item.questID then item.mapID,item.x,item.y,item.floor=nil,nil,nil,nil end
      unlocated[#unlocated+1]=item
    end
  end
  for _,preview in ipairs(known) do
    local rank=preview.manualPosition
    if type(rank)=='number' and rank>=1 and rank%1==0 then
      for _,item in ipairs(unlocated) do
        if type(item.manualPosition)=='number' and item.manualPosition>=1 and
            item.manualPosition%1==0 and item.manualPosition<=rank then
          preview.manualPosition=preview.manualPosition-1
        end
      end
      preview.manualPosition=math.max(1,preview.manualPosition)
    end
  end
  local layout=self:DisplayOrder(known,{})
  local reserved,free={},{}
  for rank,preview in ipairs(layout) do
    local item=requests[preview]
    if type(preview.manualPosition)=='number' and preview.manualPosition>=1 and
        preview.manualPosition%1==0 then
      reserved[rank]=item
    else free[#free+1]=item end
  end
  local output,deferred={},unlocated
  local from,cumulative,evidenceLost=origin,0,false
  local walk=context.walk
  local graph=walk and addon.walkGraph and addon.walkGraph:Build(walk.nodes,walk.edges,walk.playerLevel)
  for rank=1,#layout do
    local request=reserved[rank]
    local selected,leg
    if request then selected,leg=resolve(request,from)
    else
      local bestIndex,bestCost
      for index,item in ipairs(free) do
        local result,cost=resolve(item,from)
        local score=result and (cost or math.huge) or math.huge
        if not bestIndex or (optimize and (score<bestCost or
            (score==bestCost and result and not selected))) then
          bestIndex,bestCost,selected,leg=index,score,result,cost
        end
        if not optimize then break end
      end
      request=table.remove(free,bestIndex)
    end
    if not selected then
      selected=copy(request); selected.sequenceRank=rank
      if selected.questID then selected.mapID,selected.x,selected.y,selected.floor=nil,nil,nil,nil end
      selected.canOverride=false
      selected.walkStatus='unknown-route'
      deferred[#deferred+1]=selected
    else
      selected.sequenceRank,selected.directYards=rank,leg
      selected.canOverride=true
      selected.walkStatus='unknown-route'
      if leg and cumulative then cumulative=cumulative+leg; selected.cumulativeYards=cumulative
      else cumulative=nil end
      if graph and from and not evidenceLost then
        local start={uiMapID=from.mapID,x=from.x,y=from.y,floor=from.floor or 0,
          worldMapID=from.worldMapID,wz=from.wz}
        local destination={uiMapID=selected.mapID,x=selected.x,y=selected.y,
          floor=selected.floor or 0,worldMapID=selected.worldMapID,wz=selected.wz}
        local prepared=addon.walkGraph:PrepareBuilt(graph,start)
        local path=addon.walkGraph:FromPrepared(prepared,destination)
        selected.walkStatus,selected.walkYards=path.status,path.yards
        selected.walkWaypoints=path.status~='unknown-route' and path.waypoints or nil
        selected.walkWarning=path.warning
        selected.unknownStart,selected.unknownEnd=path.unknownStart,path.unknownEnd
        if path.status~='known-route' then evidenceLost=true end
      else evidenceLost=true end
      output[#output+1]=selected
      from={mapID=selected.mapID,x=selected.x,y=selected.y,floor=selected.floor}
      if selected.walkStatus=='known-route' then
        local node=selected.walkWaypoints[#selected.walkWaypoints]
        from.worldMapID,from.wz,from.floor=node.worldMapID,node.wz,node.floor
      end
    end
  end
  return output,deferred
end
