local _, addon = ...
addon.navigation = {}
local navigation = addon.navigation
local function finite(n)
  if type(n) ~= 'number' then return false end
  if type(issecretvalue) == 'function' then
    local ok, secret = pcall(issecretvalue, n)
    if not ok or secret then return false end
  end
  return n == n and n > -10000000 and n < 10000000
end
local function coordinate(n) return finite(n) and n >= 0 and n <= 1 end
local function readable(value)
  if value == nil then return false end
  if type(issecretvalue) == 'function' and issecretvalue(value) then return false end
  if type(value) == 'table' and type(issecrettable) == 'function' and
      issecrettable(value) then return false end
  return true
end
-- Native world coordinates increase north/west. Only equal instance IDs can
-- be compared; instance 0 is valid. No zone-size constants or terrain claims.
function navigation:WorldPosition(map,x,y)
  if not finite(map) or map<1 or map%1~=0 or not coordinate(x) or
      not coordinate(y) then return nil end
  local ok,instance,north,west=pcall(function()
    if not readable(C_Map) or not readable(CreateVector2D) or
        type(CreateVector2D)~='function' then return end
    local convert=C_Map.GetWorldPosFromMapPos
    if not readable(convert) or type(convert)~='function' then return end
    local vector=CreateVector2D(x,y)
    if not readable(vector) then return end
    local id,point=convert(map,vector)
    if not finite(id) or id<0 or id%1~=0 or not readable(point) then return end
    local get=point.GetXY
    if not readable(get) or type(get)~='function' then return end
    local n,w=get(point)
    if finite(n) and finite(w) then return id,n,w end
  end)
  if ok then return instance,north,west end
end
local function layer(point,sample,map)
  if not sample or sample.uiMapID~=map or point.uiMapID~=map or
      not coordinate(point.x) or not coordinate(point.y) then return false end
  if point.floor and point.floor~=0 then
    return finite(point.floor) and point.floor>=1 and sample.floor==point.floor
  end
  -- Floor zero is unknown: retain the recorded world/elevation layer.
  return finite(point.worldMapID) and finite(point.wz) and
    sample.worldMapID==point.worldMapID and finite(sample.wz) and
    math.abs(sample.wz-point.wz)<=2
end
local function yards(a,b,width,height)
  local dx,dy=(a.x-b.x)*width,(a.y-b.y)*height
  return math.sqrt(dx*dx+dy*dy)
end
local function corridor(p,a,b,width,height)
  local vx,vy=(b.x-a.x)*width,(b.y-a.y)*height
  local px,py=(p.x-a.x)*width,(p.y-a.y)*height
  local length=vx*vx+vy*vy
  if length==0 then return yards(p,a,width,height),0 end
  local t=math.max(0,math.min(1,(px*vx+py*vy)/length))
  local dx,dy=px-t*vx,py-t*vy
  return math.sqrt(dx*dx+dy*dy),t
end
local function segmentLayer(a,b,sample,map,t)
  if not sample or sample.uiMapID~=map or a.uiMapID~=map or
      b.uiMapID~=map or not coordinate(a.x) or not coordinate(a.y) or
      not coordinate(b.x) or not coordinate(b.y) or
      not finite(a.floor) or a.floor~=b.floor or
      sample.floor~=a.floor then return false end
  if a.floor==0 and (not finite(a.worldMapID) or
      a.worldMapID~=b.worldMapID or sample.worldMapID~=a.worldMapID) then
    return false
  end
  if a.floor~=0 and (a.worldMapID or b.worldMapID) and
      (a.worldMapID~=b.worldMapID or sample.worldMapID~=a.worldMapID) then
    return false
  end
  if a.floor==0 or a.wz~=nil or b.wz~=nil then
    return finite(a.wz) and finite(b.wz) and finite(sample.wz) and
      math.abs(sample.wz-(a.wz+t*(b.wz-a.wz)))<=2
  end
  return true
end
local function activeLeg(follower)
  local nodes=follower.item.walkWaypoints
  local a,b=nodes[follower.index-1],nodes[follower.index]
  if not a or not b then return false end
  local map,x,y=addon:Position()
  local width,height=addon:MapWorldSize(map)
  if map~=follower.item.mapID or not coordinate(x) or not coordinate(y) or
      not finite(width) or not finite(height) or width<=0 or height<=0 then return false end
  local ok,sample=pcall(function() return addon.trails:NativeSample() end)
  if not ok then return false end
  local here={x=x,y=y}
  local gap,t=corridor(here,a,b,width,height)
  return gap<=12 and segmentLayer(a,b,sample,map,t),here,width,height,sample,nodes,b
end
local function sameTarget(a,b)
  return a and b and a.id==b.id and a.mapID==b.mapID and
    a.x==b.x and a.y==b.y and a.floor==b.floor and
    a.locationID==b.locationID and a.npcID==b.npcID
end
-- Replans can allocate fresh tables. Match the active path and its directed
-- evidence, not the table identity; never treat an unobserved edge as a leg.
local function pathKey(item)
  local parts={tostring(item.id),tostring(item.mapID),tostring(item.x),
    tostring(item.y),tostring(item.floor),tostring(item.walkStatus),
    tostring(item.unknownStart),tostring(item.unknownEnd),tostring(item.walkYards)}
  local nodes=item.walkWaypoints
  if type(nodes)~='table' or #nodes<2 or #nodes>400 or
      (item.walkStatus~='known-route' and item.walkStatus~='partial-route') or
      item.unknownStart then return table.concat(parts,'|'),false end
  local wanted={}
  for i,node in ipairs(nodes) do
    if type(node)~='table' or type(node.id)~='string' or
        not finite(node.uiMapID) or not coordinate(node.x) or
        not coordinate(node.y) then return table.concat(parts,'|'),false end
    parts[#parts+1]=table.concat({node.id,node.uiMapID,node.floor or '',
      node.x,node.y,node.worldMapID or '',node.wz or ''},',')
    if i>1 then wanted[nodes[i-1].id..'\0'..node.id]=true end
  end
  local edges=addon.trails and addon.trails.edges
  if type(edges)~='table' or #edges>1200 then return table.concat(parts,'|'),false end
  local found={}
  for _,edge in ipairs(edges) do
    if type(edge)=='table' and type(edge.a)=='string' and type(edge.b)=='string' then
      local key=edge.a..'\0'..edge.b
      if wanted[key] and finite(edge.yards) and edge.yards>0 and
          (edge.source=='observed-walk' or
          (edge.source=='observed-transition' and edge.verified==true)) then
        found[key]=table.concat({edge.source,edge.yards,edge.minLevel or '',
          tostring(edge.verified)},',')
      end
    end
  end
  local verified=true
  for i=2,#nodes do
    local evidence=found[nodes[i-1].id..'\0'..nodes[i].id]
    if not evidence then verified=false; break end
    parts[#parts+1]=evidence
  end
  return table.concat(parts,'|'),verified
end
local function atan2(y,x)
  if math.atan2 then return math.atan2(y,x) end
  if x > 0 then return math.atan(y/x) end
  if x < 0 then return math.atan(y/x) + (y >= 0 and math.pi or -math.pi) end
  return y >= 0 and math.pi/2 or -math.pi/2
end

-- A direction is a bearing to a point, never a claim about a walkable route.
-- Nil fields mean that native evidence is insufficient, not an estimate.
function navigation:Measure(item)
  if not item or not finite(item.mapID) or not coordinate(item.x) or
      not coordinate(item.y) then return nil end
  local map, x, y = addon:Position()
  if not finite(map) or not coordinate(x) or not coordinate(y) then return nil end
  if item.floor ~= nil then
    local ok, sample = pcall(function() return addon.trails:NativeSample() end)
    if not ok or not sample or sample.uiMapID ~= map or
        sample.floor ~= item.floor then return nil end
  end
  local result = {target=item}
  local dx,dy
  if map==item.mapID then
    local width,height=addon:MapWorldSize(map)
    if finite(width) and finite(height) and width>0 and height>0 then
      dx,dy=(item.x-x)*width,(item.y-y)*height
    end
  end
  if dx==nil then
    local instance,north,west=self:WorldPosition(map,x,y)
    local targetInstance,targetNorth,targetWest=self:WorldPosition(item.mapID,item.x,item.y)
    if instance==nil or targetInstance~=instance then
      if map==item.mapID then return result end
      return nil
    end
    dx,dy=west-targetWest,north-targetNorth
  end
  result.distance = math.sqrt(dx*dx + dy*dy) -- direct planar yards only
  if dx == 0 and dy == 0 then return result end
  if type(GetPlayerFacing) ~= 'function' then return result end
  local ok, facing = pcall(GetPlayerFacing)
  if not ok or not finite(facing) or facing < 0 or facing >= 2*math.pi then
    return result
  end
  -- WoW facing is north=0, west=pi/2. Map Y increases southwards.
  result.angle = (atan2(-dx,-dy) - facing + math.pi) % (2*math.pi) - math.pi
  return result
end

-- Sequential connector following. Failure returns an explicitly unknown
-- direct bearing; it never certifies the missing link to the objective.
function navigation:Guidance(item)
  local direct=self:Measure(item)
  if not direct then return nil end
  direct.mode,direct.routeStatus='direct-unknown','route-unknown'
  if item~=self.target or not self.follower or self.follower.invalid then return direct end
  local signature,verified=pathKey(self.follower.item)
  if not verified or signature~=self.pathSignature then
    self.follower.invalid=true; return direct
  end
  local valid,here,width,height,sample,nodes,nextNode=activeLeg(self.follower)
  local index=self.follower.index
  if not valid then
    self.follower.invalid=true; return direct
  end
  if yards(here,nextNode,width,height)<=2 then
    if index<#nodes then
      self.follower.index=index+1
      local nextValid
      nextValid,here,width,height,sample,nodes,nextNode=activeLeg(self.follower)
      if not nextValid then
        self.follower.invalid=true; return direct
      end
    elseif self.follower.item.unknownEnd then
      return direct -- No observed final connector from this node to the goal.
    end
  end
  local reading=self:Measure({mapID=nextNode.uiMapID,x=nextNode.x,
    y=nextNode.y,floor=nextNode.floor~=0 and nextNode.floor or nil})
  if not reading then self.follower.invalid=true; return direct end
  reading.mode='observed'
  reading.routeStatus=self.follower.item.unknownEnd and 'partial-end' or 'known-route'
  reading.waypoint=nextNode
  reading.target=item
  reading.targetDistance=direct.distance
  return reading
end

-- TomTom's UID can outlive the pin when the player or TomTom clears it.
local function removedExternally(provider, handle)
  if type(provider.IsValidWaypoint) ~= "function" then return false end
  local ok, valid = pcall(provider.IsValidWaypoint, provider, handle)
  return ok and valid == false
end

function navigation:Clear()
  if self.handle then
    if not self.provider or type(self.provider.RemoveWaypoint) ~= "function" then return false end
    if not removedExternally(self.provider, self.handle) then
      local ok, result = pcall(self.provider.RemoveWaypoint, self.provider, self.handle)
      if not ok or result == false then return false end
    end
  end
  self.handle, self.key, self.provider, self.target = nil, nil, nil, nil
  self.follower, self.pathSignature = nil, nil
  return true
end

-- Native navigation owns its arrow and never creates a TomTom waypoint (an
-- external autoqueue profile could select even a non-crazy pin). Clear only
-- a previously-owned legacy handle if one exists.
function navigation:Next(item)
  if self.paused then return false, 'paused' end
  local signature,verified
  if item then signature,verified=pathKey(item) end
  if item and self.target and not self.handle and self.follower and
      not self.follower.invalid and sameTarget(item,self.target) then
    local originalSignature,originalVerified=pathKey(self.follower.item)
    if originalVerified and originalSignature==self.pathSignature and
        activeLeg(self.follower) and
        ((verified and signature==self.pathSignature) or
         item.walkStatus=='unknown-route') then
      if verified then self.follower.item=item end
      self.target=item
      return true,'observed-route'
    end
  end
  if not self:Clear() then
    self.target = item -- Native direction survives failure to remove a legacy pin.
    self.follower, self.pathSignature=nil,nil
    return false, 'old-pin'
  end
  self.target, self.pathSignature = item, signature
  if not item then return false, 'no-target' end
  if verified then
    local map,x,y=addon:Position()
    local width,height=addon:MapWorldSize(map)
    local nodes=item.walkWaypoints
    local ok,sample=pcall(function() return addon.trails:NativeSample() end)
    if map==item.mapID and coordinate(x) and coordinate(y) and
        finite(width) and finite(height) and width>0 and height>0 and
        ok and layer(nodes[1],sample,map) and
        yards({x=x,y=y},nodes[1],width,height)<=2 then
      self.follower={index=2,item=item}
    end
  end
  if not item.mapID or not coordinate(item.x) or not coordinate(item.y) then
    return true, 'native-unknown'
  end
  return true, self.follower and 'observed-route' or 'native-only'
end
