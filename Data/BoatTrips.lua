-- Local, explicitly user-confirmed boat observations. Parent owns commands and SavedVariables.
-- Bind({enabled=true,legs={},build?,character?}, character, projectAndBuild)
-- Begin is an explicit boarded-now confirmation; Arrive is an explicit disembarked-now
-- confirmation. No zone-change/teleport inference, boarding wait or automatic ETA.
-- Saved legs: directed originMapID/X/Y, destinationMapID/X/Y, seconds (ride
-- only), samples, source='user-confirmed-boat', character. Max 64 legs.
-- Recommend(map,x,y,{mapID,x,y},projector) requires a projector returning
-- worldInstance,worldX,worldY in *yard-comparable* units for every point.
-- Returns a transient walking-distance hint, never an ETA or saved time.
local _,addon=...
local boat={}
addon.boatTrips=boat
local function coordinate(n)
  return type(n)=='number' and n==n and n>=0 and n<=1
end
local function mapID(n)
  return type(n)=='number' and n%1==0 and n>=1 and n<=10000000
end
local function identity(value)
  return type(value)=='string' and #value>0 and #value<=80 and
    not value:find('[%c|]')
end
local function validLeg(leg,character)
  return type(leg)=='table' and not getmetatable(leg) and
    leg.character==character and leg.source=='user-confirmed-boat' and
    mapID(leg.originMapID) and coordinate(leg.originX) and coordinate(leg.originY) and
    mapID(leg.destinationMapID) and coordinate(leg.destinationX) and
    coordinate(leg.destinationY) and type(leg.seconds)=='number' and
    leg.seconds>=1 and leg.seconds<=86400 and type(leg.samples)=='number' and
    leg.samples%1==0 and leg.samples>=1 and leg.samples<=32
end
local function key(leg)
  return table.concat({leg.originMapID,leg.originX,leg.originY,
    leg.destinationMapID,leg.destinationX,leg.destinationY},':')
end
local function validArray(legs,character)
  if type(legs)~='table' or getmetatable(legs) then return false end
  local count,seen=0,{}
  for index in pairs(legs) do
    count=count+1
    if count>64 or type(index)~='number' or index%1~=0 or
        index<1 or index>64 then return false end
  end
  for i=1,count do
    local leg=rawget(legs,i)
    if not validLeg(leg,character) then return false end
    local id=key(leg)
    if seen[id] then return false end
    seen[id]=true
  end
  return true
end
local function now()
  if type(GetTime)~='function' then return end
  local ok,value=pcall(GetTime)
  if ok and type(value)=='number' and value==value and value>=0 and value<=1000000000 then return value end
end
-- Parent provides one bucket per character and a concrete project/build scope.
-- A mismatch is rejected, never overwritten with another build's measurements.
function boat:Bind(bucket,character,scope)
  self.bucket=nil;self.pending=nil;self.character=nil;self.scope=nil
  if type(bucket)~='table' or getmetatable(bucket) or
      not identity(character) or not identity(scope) or
      (bucket.build~=nil and bucket.build~=scope) or
      (bucket.character~=nil and bucket.character~=character) or
      (type(bucket.legs)=='table' and next(bucket.legs)~=nil and
        (bucket.build~=scope or bucket.character~=character)) or
      not validArray(bucket.legs,character) then return false end
  self.bucket=bucket;self.character=character;self.scope=scope
  return true
end
local function active(self)
  return self.bucket and self.bucket.enabled==true and
    (self.bucket.build==nil or self.bucket.build==self.scope) and
    (self.bucket.character==nil or self.bucket.character==self.character) and
    validArray(self.bucket.legs,self.character)
end
function boat:Begin(map,x,y)
  self.pending=nil
  if not active(self) or
      not mapID(map) or not coordinate(x) or not coordinate(y) then return false end
  local at=now()
  if not at then return false end
  self.pending={map=map,x=x,y=y,at=at,character=self.character,scope=self.scope}
  return true
end
function boat:Arrive(map,x,y)
  local ticket=self.pending
  self.pending=nil
  if not ticket or not active(self) or
      ticket.character~=self.character or ticket.scope~=self.scope or
      not mapID(map) or not coordinate(x) or not coordinate(y) then return false end
  local at=now()
  local elapsed=at and at-ticket.at
  if not elapsed or elapsed<1 or elapsed>86400 then return false end
  local leg={originMapID=ticket.map,originX=ticket.x,originY=ticket.y,
    destinationMapID=map,destinationX=x,destinationY=y,seconds=elapsed,
    samples=1,source='user-confirmed-boat',character=self.character}
  local legs=self.bucket.legs
  local id=key(leg)
  for i=1,#legs do
    local old=legs[i]
    if key(old)==id then
      local samples=math.min(old.samples,32)
      leg.seconds=(old.seconds*samples+elapsed)/(samples+1)
      leg.samples=math.min(samples+1,32)
      legs[i]=leg
      return true
    end
  end
  if #legs>=64 then return false end
  legs[#legs+1]=leg
  self.bucket.build=self.scope
  self.bucket.character=self.character
  return true
end
function boat:Cancel()
  self.pending=nil
end
local function projected(projector,map,x,y)
  local ok,instance,north,west=pcall(projector,map,x,y)
  if ok and type(instance)=='number' and instance==instance and instance>=0 and
      instance%1==0 and instance<=10000000 and
      type(north)=='number' and north==north and math.abs(north)<100000000 and
      type(west)=='number' and west==west and math.abs(west)<100000000 then
    return instance,north,west
  end
end
local function distance(x,y,xx,yy)
  return math.sqrt((x-xx)^2+(y-yy)^2)
end
function boat:Recommend(map,x,y,target,projector)
  if not active(self) or
      not mapID(map) or not coordinate(x) or not coordinate(y) or
      type(target)~='table' or not mapID(target.mapID) or
      not coordinate(target.x) or not coordinate(target.y) or
      type(projector)~='function' then return end
  local world,py,px=projected(projector,map,x,y)
  local goal,ty,tx=projected(projector,target.mapID,target.x,target.y)
  if world==nil or goal==nil then return end
  local direct=world==goal and distance(px,py,tx,ty) or nil
  local best
  for _,leg in ipairs(self.bucket.legs) do
    if leg.character==self.character then
      local origin,oy,ox=projected(projector,leg.originMapID,leg.originX,leg.originY)
      local landing,ly,lx=projected(projector,leg.destinationMapID,leg.destinationX,leg.destinationY)
      if origin==world and landing==goal then
        local via=distance(px,py,ox,oy)+distance(lx,ly,tx,ty)
        local saved=direct and direct-via or nil
        if (not direct or (saved>=100 and saved>=direct*.15)) and
            (not best or via<best.viaYards) then
          best={kind='boat',mapID=leg.originMapID,x=leg.originX,y=leg.originY,
            destinationMapID=leg.destinationMapID,destinationX=leg.destinationX,
            destinationY=leg.destinationY,travelSeconds=leg.seconds,
            directYards=direct,viaYards=via,savedYards=saved,
            estimate=direct and 'walking-distance-reduction' or 'recorded-cross-world-connection',
            source='user-confirmed-boat'}
        end
      end
    end
  end
  return best
end
