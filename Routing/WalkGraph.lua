-- Only explicitly observed traversable edges are route evidence.
-- No inferred navmesh, terrain clearance or NPC catalog.
local _, addon = ...
addon.walkGraph = {}
local graph = addon.walkGraph
local function plain(value)
  local ok, safe = pcall(function()
    if type(issecretvalue) == "function" and issecretvalue(value) then return false end
    if type(value) == "table" and type(issecrettable) == "function" and issecrettable(value) then return false end
    return true
  end)
  return ok and safe
end
local function number(value, low, high)
  return plain(value) and type(value) == "number" and value == value and
    value >= low and value <= high
end
local function integer(value, low, high)
  return number(value, low, high) and value % 1 == 0
end
local function validPoint(point)
  local ok, map, floor, x, y, world, z = pcall(function()
    if not plain(point) or type(point) ~= "table" then return end
    return point.uiMapID, point.floor, point.x, point.y,
      point.worldMapID, point.wz
  end)
  local worldOK = plain(world) and plain(z) and
    ((world == nil and z == nil) or
      (integer(world, 1, 10000000) and number(z, -10000000, 10000000)))
  return ok and worldOK and integer(map, 1, 10000000) and integer(floor, 0, 50) and
    number(x, 0, 1) and number(y, 0, 1), map, floor, x, y, world, z
end
local function unknown()
  return {status="unknown-route", waypoints={}}
end
local function heapPush(heap, id, score)
  local i = #heap + 1
  while i > 1 do
    local parent = math.floor(i/2)
    if heap[parent].score <= score then break end
    heap[i], i = heap[parent], parent
  end
  heap[i] = {id=id, score=score}
end
local function heapPop(heap)
  local first, last = heap[1], table.remove(heap)
  if #heap > 0 then
    local i = 1
    while i*2 <= #heap do
      local child = i*2
      if child < #heap and heap[child+1].score < heap[child].score then
        child = child + 1
      end
      if heap[child].score >= last.score then break end
      heap[i], i = heap[child], child
    end
    heap[i] = last
  end
  return first.id, first.score
end
local function snap(index, point, reachable)
  local valid, map, floor, x, y, world, z = validPoint(point)
  if not valid then return end
  local best, squared = nil, .001*.001
  local reachableBest, reachableSquared = nil, .001*.001
  local ambiguous, layerWorld, layerZ = false, nil, nil
  for id, node in pairs(index) do
    if node.uiMapID == map and node.floor == floor then
      local layer = floor ~= 0 or (node.worldMapID and node.wz)
      if layer and (not world or node.worldMapID == world) and
          (not z or (node.wz and math.abs(node.wz-z) <= 2)) then
        local dx, dy = node.x - x, node.y - y
        local current = dx*dx + dy*dy
        if current <= .001*.001 then
          if floor == 0 and not z then
            if layerWorld and (node.worldMapID ~= layerWorld or
                math.abs(node.wz-layerZ) > 2) then ambiguous = true
            else layerWorld, layerZ = node.worldMapID, node.wz end
          end
          if not best or current < squared or
              (current == squared and id < best) then
            best, squared = id, current
          end
          if reachable and reachable[id] ~= nil and
              (not reachableBest or current < reachableSquared or
                (current == reachableSquared and id < reachableBest)) then
            reachableBest, reachableSquared = id, current
          end
        end
      end
    end
  end
  if ambiguous then return end
  if reachable and best and reachable[best] == nil and
      squared > .00001*.00001 then
    return reachableBest, reachableSquared
  end
  return best, squared
end

function graph:Build(nodes, edges, playerLevel)
  if not plain(nodes) or type(nodes) ~= "table" or
      not plain(edges) or type(edges) ~= "table" then return end
  local valid, nodeCount, edgeCount = pcall(function() return #nodes, #edges end)
  if not valid or not integer(nodeCount, 0, 400) or
      not integer(edgeCount, 0, 1200) then return end
  local index, neighbors = {}, {}
  for i=1,nodeCount do
    local ok, id, point = pcall(function() return nodes[i].id, nodes[i] end)
    local good, map, floor, x, y, world, z = validPoint(point)
    if ok and good and plain(id) and type(id) == "string" and
        #id >= 1 and #id <= 64 and not id:find("[%c|]") and not index[id] and
        (floor ~= 0 or world ~= nil) then
      index[id] = {id=id, uiMapID=map, floor=floor, x=x, y=y,
        worldMapID=world, wz=z}
      neighbors[id] = {}
    end
  end
  for i=1,edgeCount do
    local ok, edge = pcall(function() return edges[i] end)
    if ok and plain(edge) and type(edge) == "table" then
      local read, a, b, yards, source, level, verified = pcall(function()
        return edge.a, edge.b, edge.yards, edge.source, edge.minLevel, edge.verified
      end)
      if read and plain(a) and plain(b) and plain(source) and plain(level) and
          plain(verified) and
          type(a) == "string" and type(b) == "string" and
          index[a] and index[b] and a ~= b and number(yards, .01, 100000) and
          (level == nil or integer(level, 1, 100)) then
        local sameLayer = index[a].uiMapID == index[b].uiMapID and
          index[a].floor == index[b].floor and
          (index[a].floor ~= 0 or (index[a].worldMapID == index[b].worldMapID and
            math.abs(index[a].wz-index[b].wz) <= 6))
        if (source == "observed-walk" and sameLayer) or
            (source == "observed-transition" and verified == true) then
          local cost = yards
          if level and integer(playerLevel, 1, 100) and playerLevel < level then
            cost = yards * 4
          end
          local risky = cost > yards
          neighbors[a][#neighbors[a]+1] = {to=b, yards=yards, cost=cost, risky=risky}
          -- A walked descent does not prove the reverse ascent is traversable.
        end
      end
    end
  end
  return {index=index,neighbors=neighbors,nodeCount=nodeCount}
end

function graph:PrepareBuilt(built, origin)
  if not built or not validPoint(origin) then return end
  local index, neighbors, nodeCount = built.index, built.neighbors, built.nodeCount
  local startID, startGap = snap(index, origin)
  local _, _, startFloor, _, _, startWorld = validPoint(origin)
  if not startID or (startFloor == 0 and not startWorld) then return end
  local distances, traversed, previous, risk, visited = {[startID]=0}, {[startID]=0}, {}, {}, {}
  local heap = {}
  heapPush(heap, startID, 0)
  while #heap > 0 do
    local current, best = heapPop(heap)
    if not visited[current] and best == distances[current] then
      visited[current] = true
      for _, neighbor in ipairs(neighbors[current]) do
        local proposed = best + neighbor.cost
        if not visited[neighbor.to] and
            (not distances[neighbor.to] or proposed < distances[neighbor.to]) then
          distances[neighbor.to] = proposed
          traversed[neighbor.to] = traversed[current] + neighbor.yards
          previous[neighbor.to] = current
          risk[neighbor.to] = risk[current] or neighbor.risky
          heapPush(heap, neighbor.to, proposed)
        end
      end
    end
  end
  return {index=index,distances=distances,traversed=traversed,previous=previous,
    risk=risk,startGap=startGap,nodeCount=nodeCount}
end

function graph:Prepare(nodes, edges, origin, playerLevel)
  return self:PrepareBuilt(self:Build(nodes, edges, playerLevel), origin)
end

function graph:Assess(prepared, destination)
  if not prepared or not validPoint(destination) then return unknown() end
  local endID, endGap = snap(prepared.index, destination, prepared.distances)
  local _, _, endFloor, _, _, endWorld = validPoint(destination)
  if not endID or not prepared.distances[endID] then return unknown() end
  local underlevel = prepared.risk[endID] == true
  local unknownStart = prepared.startGap > .00001*.00001
  local unknownEnd = endGap > .00001*.00001 or (endFloor == 0 and not endWorld)
  return {status=(unknownStart or unknownEnd) and "partial-route" or "known-route",
    yards=prepared.traversed[endID], weightedCost=prepared.distances[endID],
    hasSegment=prepared.previous[endID] ~= nil, endID=endID,
    unknownStart=unknownStart,unknownEnd=unknownEnd,
    warning=underlevel and "Coarse level preference only" or nil}
end

function graph:FromPrepared(prepared, destination)
  local result = self:Assess(prepared, destination)
  if result.status == "unknown-route" then return result end
  local reverse, id = {}, result.endID
  while id do
    reverse[#reverse+1] = prepared.index[id]
    id = prepared.previous[id]
    if #reverse > prepared.nodeCount then return unknown() end
  end
  for i=1,math.floor(#reverse/2) do
    local j=#reverse-i+1
    reverse[i],reverse[j] = reverse[j],reverse[i]
  end
  result.waypoints = reverse
  return result
end

function graph:Plan(nodes, edges, origin, destination, playerLevel)
  return self:FromPrepared(self:Prepare(nodes, edges, origin, playerLevel), destination)
end
