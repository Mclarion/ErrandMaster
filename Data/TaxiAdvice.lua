local _, addon = ...
addon.taxiAdvice = {reachable={}}
local taxi = addon.taxiAdvice
local function usable(value)
  if value == nil then return false end
  if type(issecretvalue)=="function" then
    local ok,secret=pcall(issecretvalue,value)
    if not ok or secret then return false end
  end
  if type(value)=="table" and type(issecrettable)=="function" then
    local ok,secret=pcall(issecrettable,value)
    if not ok or secret then return false end
  end
  return true
end
local function label(value)
  return usable(value) and type(value)=="string" and #value>0 and
    #value<=80 and not value:find("[%c|]")
end
local function integer(value)
  return usable(value) and type(value)=="number" and value>=1 and
    value<=10000000 and value%1==0
end
local function seconds(value, allowZero)
  return usable(value) and type(value)=="number" and value==value and
    value>=(allowZero and 0 or 1) and value<=86400
end
local function field(object,key)
  if not usable(object) or type(object)~="table" then return end
  local ok,value=pcall(function() return object[key] end)
  if ok and usable(value) then return value end
end
local function consent()
  local taxi=addon.taxiAdvice
  -- Standalone legacy advice tests have no database. In-game consent is always
  -- the independent per-character transport setting, never ground trails.
  if addon.db and addon.db.data then return taxi:IsEnabled() end
  if not addon.trails or type(addon.trails.IsEnabled)~="function" then return false end
  local ok,enabled=pcall(addon.trails.IsEnabled,addon.trails)
  return ok and enabled==true
end
local MAX_LEGS, MAX_SAMPLES=64,32
local candidateNodes
local function buildScope()
  local project=usable(WOW_PROJECT_ID) and type(WOW_PROJECT_ID)=='number' and
    WOW_PROJECT_ID%1==0 and WOW_PROJECT_ID>=1 and WOW_PROJECT_ID<=100 and WOW_PROJECT_ID or 0
  local build,interface=0,0
  if type(GetBuildInfo)=='function' then
    local ok,_,revision,_,value=pcall(GetBuildInfo)
    if ok then
      if usable(revision) and type(revision)=='string' and
          #revision<=12 and revision:match('^%d+$') then build=revision end
      if usable(value) and type(value)=='number' and value%1==0 and
          value>=1 and value<=10000000 then interface=value end
    end
  end
  return tostring(project)..':'..tostring(build)..':'..tostring(interface)
end
local function safeTable(value)
  return usable(value) and type(value)=='table' and not getmetatable(value)
end
local function coordinate(n)
  return usable(n) and type(n)=='number' and n==n and n>=0 and n<=1
end
local function validLeg(leg)
  return safeTable(leg) and label(leg.originNode) and label(leg.nodeName) and
    integer(leg.originMapID) and integer(leg.destinationMapID) and
    coordinate(leg.originX) and coordinate(leg.originY) and
    coordinate(leg.destinationX) and coordinate(leg.destinationY) and
    seconds(leg.seconds) and integer(leg.samples) and leg.samples<=MAX_SAMPLES and
    (leg.distanceYards==nil or (type(leg.distanceYards)=='number' and
      leg.distanceYards==leg.distanceYards and leg.distanceYards>0 and
      leg.distanceYards<=1000000)) and
    leg.source=='observed-taxi' and
    (leg.timing==nil or leg.timing=='movement-tick-sampled')
end
-- Direction, maps and observed endpoints identify a flight. Taxi labels are not
-- unique; no node ID is available from the classic selection hook.
local function legKey(leg)
  return table.concat({leg.originNode:lower(),leg.nodeName:lower(),
    tostring(leg.originMapID),tostring(leg.destinationMapID),
    tostring(leg.originX),tostring(leg.originY),
    tostring(leg.destinationX),tostring(leg.destinationY)},'\n')
end
local function sameEndpoint(a,b)
  return a.originNode:lower()==b.originNode:lower() and
    a.nodeName:lower()==b.nodeName:lower() and
    a.originMapID==b.originMapID and a.destinationMapID==b.destinationMapID and
    math.abs(a.originX-b.originX)<=.01 and math.abs(a.originY-b.originY)<=.01 and
    math.abs(a.destinationX-b.destinationX)<=.01 and math.abs(a.destinationY-b.destinationY)<=.01
end
local function copyLeg(leg,character)
  return {originNode=leg.originNode,nodeName=leg.nodeName,
    originMapID=leg.originMapID,originX=leg.originX,originY=leg.originY,
    destinationMapID=leg.destinationMapID,destinationX=leg.destinationX,
    destinationY=leg.destinationY,seconds=leg.seconds,samples=leg.samples,
    distanceYards=leg.distanceYards,
    source='observed-taxi',timing=leg.timing,character=character}
end
function taxi:Bind()
  self.legs={}
  self.sessionLegs={} -- no endpoint coordinates: advice-only, never persisted/recommended
  self.selection=nil;self.pending=nil;self.closing=nil;self.mapOrigin=nil
  self.reachable={};self.indices={};self.open=false;self.current=nil
  self.bucket=nil
  self.legCount=0
  if not addon.db or type(addon.db.TransportBucket)~='function' then return false end
  local ok,bucket=pcall(addon.db.TransportBucket,addon.db)
  if not ok or not bucket then return false end
  local legs=bucket.legs
  -- Bound the entire read to 65 entries; reject sparse/non-array data and
  -- unexpected fields, never trust SavedVariables as executable route objects.
  local count=0
  local valid=pcall(function()
    for key in pairs(legs) do
      count=count+1
      if count>MAX_LEGS or type(key)~='number' or key%1~=0 or
          key<1 or key>MAX_LEGS then error('invalid transport array') end
    end
    for i=1,count do if not rawget(legs,i) then error('sparse transport array') end end
  end)
  if not valid then return false end
  local scope=buildScope()
  if bucket.build~=nil and (type(bucket.build)~='string' or
      #bucket.build>32) then return false end
  if bucket.build==scope then
    for i=1,count do
      local leg=rawget(legs,i)
      if not validLeg(leg) then return false end
      local key=legKey(leg)
      if self.legs[key] then return false end
      self.legs[key]=copyLeg(leg,addon.db.character)
    end
    self.legCount=count
  end
  self.bucket=bucket
  self.scope=scope
  return true
end
function taxi:IsEnabled()
  return self.bucket~=nil and self.bucket.enabled==true and addon.db and
    addon.db.data and addon.db.data.characters[addon.db.character] and
    addon.db.data.characters[addon.db.character].transport==self.bucket
end
function taxi:SetEnabled(enabled)
  if type(enabled)~='boolean' or not self.bucket then return false end
  self.bucket.enabled=enabled
  if not enabled then self.selection=nil;self.pending=nil end
  return true
end
function taxi:ClearLearned()
  if not self.bucket then return false end
  self.bucket.legs={}
  self.bucket.build=self.scope
  self.legs={}
  self.sessionLegs={}
  self.legCount=0
  self.selection=nil;self.pending=nil
  return true
end
local function saveLeg(self,leg)
  if not validLeg(leg) then return false end
  -- Disambiguate within the same directed map pair only. A small position
  -- window tolerates sampling jitter without coalescing distant namesakes.
  local old,oldKey,slot
  for key,saved in pairs(self.legs or {}) do
    if validLeg(saved) and sameEndpoint(saved,leg) then
      if old then return false end -- ambiguous observation: fail closed
      old,oldKey= saved,key
    end
  end
  if old and self.bucket and self.bucket.build==self.scope then
    for i=1,#self.bucket.legs do
      if legKey(self.bucket.legs[i])==oldKey then slot=i;break end
    end
    if not slot then return false end
  end
  if not old and (self.legCount or 0)>=MAX_LEGS then return false end
  if self.bucket then
    if self.bucket.build~=self.scope then
      self.bucket.legs={}
      self.bucket.build=self.scope
      self.legs={}
      self.legCount=0
      old,oldKey,slot=nil,nil,nil
    end
    if old then
      if old.seconds<=leg.seconds then return true end
      -- Fastest sample is atomic: duration, sampled distance and both actual
      -- endpoints must come from the same ride, never an average.
      self.bucket.legs[slot]=copyLeg(leg)
    else
      self.bucket.legs[#self.bucket.legs+1]=copyLeg(leg)
      self.legCount=self.legCount+1
    end
  end
  self.legs=self.legs or {}
  if not self.bucket and not old then self.legCount=(self.legCount or 0)+1 end
  if oldKey then self.legs[oldKey]=nil end
  leg.character=addon.db and addon.db.character
  self.legs[legKey(leg)]=leg
  return true
end
local now
function taxi:Clear()
  if self.open and label(self.current) then
    self.closing={current=self.current,indices=self.indices,origin=self.mapOrigin,
      at=now and now()}
  end
  self.reachable={}
  self.indices={}
  self.mapOrigin=nil
  self.open=false
  self.current=nil
  -- TAXIMAP_CLOSED occurs at departure; retain the in-progress observation.
end
-- The active taxi map is the only authoritative source of currently reachable
-- destinations. It does not provide a reusable all-source flight graph.
function taxi:Capture()
  self:Clear()
  self.closing=nil
  self.selection=nil
  local names={}
  local indices={}
  local current
  if usable(NumTaxiNodes) and type(NumTaxiNodes)=="function" and
      usable(TaxiNodeGetType) and type(TaxiNodeGetType)=="function" and
      usable(TaxiNodeName) and type(TaxiNodeName)=="function" then
    local ok,count=pcall(NumTaxiNodes)
    if not ok or not usable(count) or type(count)~="number" or
        count<0 or count>200 or count%1~=0 then return false end
    if count>0 then
      for i=1,count do
        local stateOK,state=pcall(TaxiNodeGetType,i)
        local nameOK,name=pcall(TaxiNodeName,i)
        if not stateOK or not nameOK or not usable(state) or
            not usable(name) then return false end
        if state=="REACHABLE" and label(name) then
          names[name:lower()]=name
          indices[i]=name
        elseif state=="CURRENT" and label(name) then
          if current then return false end
          current=name
        end
      end
      self.reachable,self.current,self.open,self.indices=names,current,true,indices
      return true
    end
  end
  if not usable(FlightMapFrame) or not usable(C_TaxiMap) then return false end
  local frameOK,mapID=pcall(function() return FlightMapFrame:GetMapID() end)
  local methodOK,method=pcall(function() return C_TaxiMap.GetAllTaxiNodes end)
  if not frameOK or not usable(mapID) or type(mapID)~="number" or
      mapID<1 or mapID%1~=0 or not methodOK or not usable(method) or
      type(method)~="function" then return false end
  local ok,nodes=pcall(method,mapID)
  if not ok or not usable(nodes) or type(nodes)~="table" or #nodes>200 then return false end
  for _,node in ipairs(nodes) do
    if not usable(node) then return false end
    local read,name,state=pcall(function() return node.name,node.state end)
    if not read or not usable(name) or not usable(state) then return false end
    if state==1 and label(name) then
      names[name:lower()]=name
      local slot=field(node,'slotIndex')
      if integer(slot) and slot<=200 then
        if indices[slot] and indices[slot]~=name then return false end
        indices[slot]=name
      end
    elseif state==0 and label(name) then
      if current then return false end
      current=name
    end
  end
  self.reachable,self.current,self.open,self.indices=names,current,true,indices
  return true
end
-- Exact map-name match is a conservative hint, not proof of proximity between
-- the landing node and the requested NPC, nor of a walkable path after landing.
function taxi:ForMap(mapID)
  if not self.open or not usable(mapID) or type(mapID)~="number" or
      mapID<1 or mapID%1~=0 or not usable(C_Map) then return end
  local methodOK,method=pcall(function() return C_Map.GetMapInfo end)
  if not methodOK or not usable(method) or type(method)~="function" then return end
  local ok,info=pcall(method,mapID)
  if not ok or not usable(info) then return end
  local read,name=pcall(function() return info.name end)
  if read and label(name) then return self.reachable[name:lower()] end
end

-- Session-only cost comparison still requires independent observed walking costs.
-- Native selection/arrival observations below also populate bounded flight storage.
now=function()
  if not usable(GetTime) or type(GetTime)~="function" then return end
  local ok,value=pcall(GetTime)
  if ok and usable(value) and type(value)=="number" and value==value and
      value>=0 and value<=1000000000 then return value end
end
function taxi:BeginFlight(originMapID,destinationMapID)
  if not consent() or not self.open or not label(self.current) or
      not integer(originMapID) or not integer(destinationMapID) or
      originMapID==destinationMapID then return end
  local destination=self:ForMap(destinationMapID)
  local startedAt=now()
  if not destination or not startedAt then return end
  self.pending={originMapID=originMapID,destinationMapID=destinationMapID,
    originNode=self.current,nodeName=destination,startedAt=startedAt,
    character=addon.db and addon.db.character}
  return self.pending
end
function taxi:CompleteFlight(ticket,arrivalMapID,observation)
  local arrival=now()
  local elapsed=ticket and arrival and arrival-ticket.startedAt
  if not consent() or not ticket or ticket~=self.pending or
      (addon.db and addon.db.character)~=ticket.character or
      not integer(arrivalMapID) or arrivalMapID~=ticket.destinationMapID or
      not seconds(elapsed) or field(observation,"taxiObserved")~=true or
      field(observation,"arrivalObserved")~=true then return false end
  self.pending=nil
  self.sessionLegs=self.sessionLegs or {}
  local key=ticket.originNode:lower().."\n"..ticket.nodeName:lower()
  local count=0
  for _ in pairs(self.sessionLegs) do count=count+1 end
  if not self.sessionLegs[key] and count>=MAX_LEGS then return false end
  self.sessionLegs[key]={originMapID=ticket.originMapID,
    destinationMapID=ticket.destinationMapID,originNode=ticket.originNode,
    nodeName=ticket.nodeName,seconds=elapsed,source="observed-taxi",
    timing='event-sampled',character=ticket.character}
  return true
end

-- Parent Core/Init.lua: Advise(item.mapID,{direct={seconds=...,source=
-- 'observed-walk'},landing={seconds=...,source='observed-walk'}}) when
-- independently measured costs refer to the same target. Provider flight
-- masters can be approach candidates, never proof of a route or duration.
-- The result is advice only: no pins, clicks, boarding or queue mutation.
function taxi:Advise(destinationMapID,costs)
  if not consent() or not self.open or not label(self.current) or
      not integer(destinationMapID) then return end
  local node=self:ForMap(destinationMapID)
  if not node then return end
  local direct,landing=field(costs,"direct"),field(costs,"landing")
  local directTime,landingTime=field(direct,"seconds"),field(landing,"seconds")
  if field(direct,"source")~="observed-walk" or
      field(landing,"source")~="observed-walk" or
      not seconds(directTime) or not seconds(landingTime,true) then return end
  local key=self.current:lower().."\n"..node:lower()
  local leg=self.sessionLegs and self.sessionLegs[key]
  if not leg or leg.destinationMapID~=destinationMapID or
      leg.character~=(addon.db and addon.db.character) or
      leg.source~="observed-taxi" or not seconds(leg.seconds) or
      directTime<=leg.seconds+landingTime then return end
  return {kind="taxi",originNode=leg.originNode,nodeName=node,
    destinationMapID=destinationMapID,flightSeconds=leg.seconds,
    timing='event-sampled',totalSeconds=leg.seconds+landingTime,
    savedSeconds=directTime-leg.seconds-landingTime,
    steps={{kind="flight",nodeName=node,seconds=leg.seconds,source="observed-taxi"},
      {kind="walk",seconds=landingTime,source="observed-walk"}}}
end

-- A post-hook witnesses the user's selection; the addon never boards a flight.
function taxi:CaptureOrigin(map,x,y)
  if self.open and integer(map) and coordinate(x) and coordinate(y) and consent() then
    self.mapOrigin={map=map,x=x,y=y}
  end
end
function taxi:SelectedNode(index,map,x,y)
  if not consent() or not integer(index) or not addon.db or
      type(addon.db.character)~='string' or addon.db.character=='' then return end
  local recent=self.closing
  local time=now()
  if not self.open and (not recent or not time or not recent.at or
      time-recent.at<0 or time-recent.at>10) then return end
  local current=self.open and self.current or (recent and recent.current)
  local indices=self.open and self.indices or (recent and recent.indices)
  local origin=self.open and self.mapOrigin or (recent and recent.origin)
  if not label(current) then return end
  if origin then map,x,y=origin.map,origin.x,origin.y end
  if not integer(map) or not coordinate(x) or not coordinate(y) then return end
  local name=indices and indices[index]
  if not label(name) or not time then return end
  self.selection={originNode=current,nodeName=name,originMapID=map,
    originX=x,originY=y,character=addon.db and addon.db.character,selectedAt=time}
end
function taxi:Depart()
  local selection=self.selection
  self.selection=nil
  if not consent() or not selection or selection.character~=(addon.db and addon.db.character) then return end
  local startedAt=now()
  if not startedAt or not selection.selectedAt or
      startedAt-selection.selectedAt<0 or startedAt-selection.selectedAt>15 then return end
  selection.startedAt=startedAt
  selection.last=nil
  selection.distanceYards=0
  selection.sampleCount=0
  self.pending=selection
end
-- Called only on the existing half-second movement tick while UnitOnTaxi is
-- positively true. Native world projection is a comparable yard coordinate,
-- not a map-normalized delta. A changed instance, missing projection, or a
-- jump faster than 250 yd/s is not evidence of traversed distance.
function taxi:Sample(map,x,y,projection)
  local ticket=self.pending
  if not ticket then return false end
  local time=now()
  local instance,north,west
  if integer(map) and coordinate(x) and coordinate(y) and type(projection)=='function' then
    local ok,a,b,c=pcall(projection,map,x,y)
    if ok and usable(a) and type(a)=='number' and a==a and a>=0 and
        usable(b) and type(b)=='number' and b==b and math.abs(b)<1e8 and
        usable(c) and type(c)=='number' and c==c and math.abs(c)<1e8 then
      instance,north,west=a,b,c
    end
  end
  if not consent() or ticket.character~=(addon.db and addon.db.character) or
      not time or not instance then self.pending=nil;return false end
  local last=ticket.last
  if last then
    local dt=time-last.time
    local distance=math.sqrt((north-last.north)^2+(west-last.west)^2)
    if instance~=last.instance or dt<0 or dt>15 or
        (distance>0 and (dt<=0 or dt>10 or distance>250*dt+10)) or
        ticket.distanceYards+distance>1000000 then
      self.pending=nil;return false
    end
    ticket.distanceYards=ticket.distanceYards+distance
  end
  ticket.last={instance=instance,north=north,west=west,time=time,map=map,x=x,y=y}
  ticket.sampleCount=ticket.sampleCount+1
  return true
end
function taxi:Landed(map,x,y)
  local ticket=self.pending
  self.pending=nil
  if not consent() or not ticket or ticket.character~=(addon.db and addon.db.character) or
      not integer(map) or not coordinate(x) or not coordinate(y) then return false end
  local arrived=now()
  local elapsed=arrived and arrived-ticket.startedAt
  if not seconds(elapsed) or not ticket.last or
      ticket.sampleCount<2 or ticket.distanceYards<=0 then return false end
  -- Arrival tolerance is 40 world yards around a faction-compatible native
  -- flight node, or a provider flight-master spawn if native nodes unavailable.
  -- Position is corroboration of dismount, not proof of currently unlocked routes.
  local projection=addon.navigation and addon.navigation.WorldPosition
  if type(projection)~='function' then return false end
  local ok,instance,north,west=pcall(projection,addon.navigation,map,x,y)
  if not ok or instance~=ticket.last.instance or type(north)~='number' or
      type(west)~='number' then return false end
  local final=math.sqrt((north-ticket.last.north)^2+(west-ticket.last.west)^2)
  if final>40 or arrived-ticket.last.time<0 or arrived-ticket.last.time>2 then return false end
  ticket.distanceYards=ticket.distanceYards+final
  local near=false
  for _,node in ipairs(candidateNodes(map)) do
    local good,world,ny,wx=pcall(projection,addon.navigation,node.mapID,node.x,node.y)
    if good and world==instance and type(ny)=='number' and type(wx)=='number' and
        math.sqrt((north-ny)^2+(west-wx)^2)<=40 then near=true;break end
  end
  if not near then return false end
  return saveLeg(self,{originNode=ticket.originNode,nodeName=ticket.nodeName,
    originMapID=ticket.originMapID,originX=ticket.originX,originY=ticket.originY,
    destinationMapID=map,destinationX=x,destinationY=y,
    seconds=elapsed,samples=1,distanceYards=ticket.distanceYards,
    source='observed-taxi',timing='movement-tick-sampled'})
end
local function projected(projection,map,x,y)
  local ok,instance,north,west=pcall(projection,map,x,y)
  if ok and usable(instance) and type(instance)=='number' and instance>=0 and
      usable(north) and type(north)=='number' and north==north and math.abs(north)<1e8 and
      usable(west) and type(west)=='number' and west==west and math.abs(west)<1e8 then
    return instance,north,west
  end
end
local function yards(a,b,c,d)
  return math.sqrt((a-c)^2+(b-d)^2)
end
-- Native map nodes and provider NPCs locate services; neither proves a flight
-- connection, unlocked node, boarding eligibility or a walkable approach.
candidateNodes=function(map)
  local catalog=addon.transportCatalog
  if not catalog then return {} end
  local function read(method)
    if type(method)~='function' then return {} end
    local ok,rows=pcall(method,catalog,map,'Flight Master')
    if not ok or not usable(rows) or type(rows)~='table' or getmetatable(rows) then return {} end
    local found={}
    for i=1,math.min(#rows,32) do
      local row=rows[i]
      if type(row)=='table' and usable(row) and integer(field(row,'mapID')) and
          field(row,'mapID')==map and coordinate(field(row,'x')) and
          coordinate(field(row,'y')) and label(field(row,'name')) then
        local faction=field(row,'faction')
        if faction~='Horde' and faction~='Alliance' then
          found[#found+1]=row
        else
          local factionOK,playerFaction=pcall(UnitFactionGroup,'player')
          if factionOK and usable(playerFaction) and playerFaction==faction then
            found[#found+1]=row
          end
        end
      end
    end
    return found
  end
  local native=read(catalog.ServiceCandidatesOnMap)
  if #native>0 then return native end
  return read(catalog.NpcCandidatesOnMap)
end
-- Same native projection and instance for all points; never inferred map-name paths.
function taxi:Recommend(playerMap,px,py,target,projection)
  if not integer(playerMap) or not coordinate(px) or not coordinate(py) or
      type(target)~='table' or not integer(field(target,'mapID')) or
      not coordinate(field(target,'x')) or not coordinate(field(target,'y')) or
      type(projection)~='function' then return end
  if type(UnitOnTaxi)~='function' then return end
  local ok,onTaxi=pcall(UnitOnTaxi,'player')
  if not ok or not usable(onTaxi) or onTaxi~=false then return end
  local instance,pyard,pxyard=projected(projection,playerMap,px,py)
  local goal,ty,tx=projected(projection,target.mapID,target.x,target.y)
  if not instance or instance~=goal then return end
  local direct=yards(pxyard,pyard,tx,ty)
  if direct<=600 then return end
  local best
  local starts,stops=candidateNodes(playerMap),candidateNodes(target.mapID)
  for _,start in ipairs(starts) do
    local origin,oy,ox=projected(projection,start.mapID,start.x,start.y)
    if origin==instance then
      for _,stop in ipairs(stops) do
        if start.nodeID~=stop.nodeID or not start.nodeID or start.mapID~=stop.mapID then
          local landing,ly,lx=projected(projection,stop.mapID,stop.x,stop.y)
          if landing==instance then
            local via=yards(pxyard,pyard,ox,oy)+yards(lx,ly,tx,ty)
            local saved=direct-via
            if saved>0 and (not best or saved>best.savedYards) then
              best={kind='taxi',originNode=start.name,nodeName=stop.name,
                mapID=start.mapID,x=start.x,y=start.y,
                destinationMapID=stop.mapID,destinationX=stop.x,destinationY=stop.y,
                savedYards=saved,directYards=direct,viaYards=via,
                estimate='walking-distance-reduction',source='candidate-taxi',
                connectionStatus='unconfirmed',rideEligibility='unknown'}
            end
          end
        end
      end
    end
  end
  if not consent() or not addon.db or type(addon.db.character)~='string' or
      addon.db.character=='' then return best end
  for _,leg in pairs(self.legs or {}) do
    if leg.character==(addon.db and addon.db.character) and
        leg.source=='observed-taxi' and coordinate(leg.originX) and
        coordinate(leg.originY) and coordinate(leg.destinationX) and
        coordinate(leg.destinationY) then
      local origin,oy,ox=projected(projection,leg.originMapID,leg.originX,leg.originY)
      local landing,ly,lx=projected(projection,leg.destinationMapID,leg.destinationX,leg.destinationY)
      if origin==instance and landing==instance then
        local via=yards(pxyard,pyard,ox,oy)+yards(lx,ly,tx,ty)
        local saved=direct-via
        local sameRide=best and best.source=='candidate-taxi' and
          best.originNode==leg.originNode and best.nodeName==leg.nodeName and
          best.mapID==leg.originMapID and best.destinationMapID==leg.destinationMapID and
          math.abs(best.x-leg.originX)<=.01 and math.abs(best.y-leg.originY)<=.01
        if saved>0 and
            (not best or saved>best.savedYards or sameRide) then
          best={kind='taxi',originNode=leg.originNode,nodeName=leg.nodeName,
            mapID=leg.originMapID,x=leg.originX,y=leg.originY,
            destinationMapID=leg.destinationMapID,destinationX=leg.destinationX,
            destinationY=leg.destinationY,savedYards=saved,
            directYards=direct,viaYards=via,estimate='walking-distance-reduction',
            timing=leg.timing or 'sampling-unknown',source='observed-taxi',
            connectionStatus='observed',rideEligibility='unknown'}
        end
      end
    end
  end
  return best
end
