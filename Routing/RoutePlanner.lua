local _, addon = ...
addon.route = {}
local route = addon.route
local function distance(x1,y1,x2,y2)
  local dx, dy = x1-x2, y1-y2
  return dx*dx + dy*dy
end

-- Same-map normalized distances are approximate, not walking times.
function route:Plan(errands, mapID, x, y, optimize, locations)
  local eligible, deferred, output = {}, {}, {}
  local canLocate = type(x) == "number" and type(y) == "number" and x == x and y == y
  for _, item in ipairs(errands) do
    if not item.completed then
      if mapID and item.mapID == mapID and type(item.x) == "number" and
          type(item.y) == "number" and item.x == item.x and item.y == item.y and
          item.x >= 0 and item.x <= 1 and item.y >= 0 and item.y <= 1 then
        eligible[#eligible+1] = item
      else
        local nearest, score
        if canLocate and mapID and not item.mapID and locations then
          for _, place in ipairs(locations) do
            if place.mapID == mapID and type(place.category) == "string" and
                place.category:lower() == item.category:lower() and
                type(place.x) == "number" and type(place.y) == "number" and
                place.x >= 0 and place.x <= 1 and place.y >= 0 and place.y <= 1 then
              local current = distance(x, y, place.x, place.y)
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
  if not optimize or not canLocate then return eligible, deferred end
  local cx, cy = x, y
  while #eligible > 0 do
    local best, score = 1, math.huge
    for i, item in ipairs(eligible) do
      local current = distance(cx, cy, item.x, item.y)
      if current < score then best, score = i, current end
    end
    local selected = table.remove(eligible, best)
    output[#output+1] = selected
    cx, cy = selected.x, selected.y
  end
  return output, deferred
end
