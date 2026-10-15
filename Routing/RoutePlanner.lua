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

-- Same-map distance is a straight line. World dimensions, when known, are yards.
function route:Plan(errands, mapID, x, y, optimize, locations, questPOIs, width, height)
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
          eligible[#eligible+1] = resolved
        else deferred[#deferred+1] = item end
      elseif mapID and item.mapID == mapID and type(item.x) == "number" and
          type(item.y) == "number" and item.x == item.x and item.y == item.y and
          item.x >= 0 and item.x <= 1 and item.y >= 0 and item.y <= 1 then
        eligible[#eligible+1] = copy(item)
      else
        local nearest, score
        if canLocate and mapID and not item.mapID and type(item.category) == "string" and locations then
          for _, place in ipairs(locations) do
            if place.mapID == mapID and type(place.category) == "string" and
                place.category:lower() == item.category:lower() and
                type(place.x) == "number" and type(place.y) == "number" and
                place.x >= 0 and place.x <= 1 and place.y >= 0 and place.y <= 1 then
              local current = distance(x, y, place.x, place.y, dx, dy)
              if not score or current < score then nearest, score = place, current end
            end
          end
        end
        if nearest then
          eligible[#eligible+1] = {id=item.id, name=item.name, category=item.category,
            mapID=nearest.mapID, x=nearest.x, y=nearest.y,
            locationID=nearest.id, locationSource=nearest.source,
            approximate=nearest.precision == "approximate"}
        else
          deferred[#deferred+1] = item
        end
      end
    end
  end
  if optimize and canLocate then
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
