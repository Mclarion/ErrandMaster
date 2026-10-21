-- Native map-wide flight positions, not known routes, reachable destinations, or learned rides.
-- C_TaxiMap.GetTaxiNodesForMap(uiMapID) returns MapTaxiNodeInfo (not TaxiNodeInfo).
local _,addon=...
addon.transportCatalog={cache={},order={},issues={}}
local catalog=addon.transportCatalog
local MAX_MAPS,MAX_NODES=32,512
local function safe(value)
  local ok,plain=pcall(function()
    if type(issecretvalue)=='function' and issecretvalue(value) then return false end
    if type(value)=='table' and type(issecrettable)=='function' and issecrettable(value) then return false end
    return true
  end)
  return ok and plain
end
local function integer(value,min,max)
  return safe(value) and type(value)=='number' and value==value and
    value%1==0 and value>=min and value<=max
end
local function coordinate(value)
  return safe(value) and type(value)=='number' and value==value and value>=0 and value<=1
end
local function copies(rows)
  local output={}
  for i,row in ipairs(rows) do
    local copy={}
    for key,value in pairs(row) do copy[key]=value end
    output[i]=copy
  end
  return output
end
function catalog:Issue(code)
  self.issues[code]=math.min(1000000,(self.issues[code] or 0)+1)
end
function catalog:Invalidate()
  self.cache,self.order={},{}
end
function catalog:OnEvent(event)
  if event=='TAXI_NODE_STATUS_CHANGED' or event=='TAXIMAP_OPENED' or
      event=='TAXIMAP_CLOSED' or event=='PLAYER_ENTERING_WORLD' then
    self:Invalidate()
  end
end
local function api()
  local ok,method=pcall(function() return C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap end)
  if ok and safe(method) and type(method)=='function' then return method end
end
function catalog:LocationsOnMap(mapID,wanted)
  if not integer(mapID,1,10000000) or
      (wanted~=nil and (not safe(wanted) or type(wanted)~='string' or
        wanted:lower()~='flight master')) then return {} end
  if self.cache[mapID] then return copies(self.cache[mapID]) end
  local method=api()
  if not method then self:Issue('api-unavailable'); return {} end
  local ok,nodes=pcall(method,mapID)
  if not ok or not safe(nodes) or type(nodes)~='table' or getmetatable(nodes) then
    self:Issue('map-read'); return {}
  end
  local records,seen={},{}
  local count=0
  local parsed=pcall(function()
    for key,node in next,nodes do
      count=count+1
      if count>MAX_NODES then self:Issue('node-cap'); break end
      if not integer(key,1,2147483647) or not safe(node) or
          type(node)~='table' or getmetatable(node) then
        self:Issue('node-invalid')
      else
        local id,name,position,faction,undiscovered=rawget(node,'nodeID'),
          rawget(node,'name'),rawget(node,'position'),rawget(node,'faction'),
          rawget(node,'isUndiscovered')
        local positionOK=safe(position) and
          (type(position)=='table' or type(position)=='userdata')
        local x,y
        if positionOK then
          local projected,px,py=pcall(function() return position:GetXY() end)
          if projected then x,y=px,py end
        end
        if integer(id,1,2147483647) and not seen[id] and safe(name) and
            type(name)=='string' and #name>0 and #name<=120 and
            not name:find('[%c|]') and coordinate(x) and coordinate(y) then
          seen[id]=true
          local side=integer(faction,0,2) and
            ({[0]='Neutral',[1]='Horde',[2]='Alliance'})[faction] or nil
          if not side then self:Issue('faction-unknown') end
          local discovery
          if safe(undiscovered) and type(undiscovered)=='boolean' then
            discovery=undiscovered
          end
          records[#records+1]={id='taxi-'..mapID..'-'..id,nodeID=id,
            name=name,category='Flight Master',mapID=mapID,x=x,y=y,
            source='native-taxi-map',precision='map-node',faction=side,
            isUndiscovered=discovery,plannerEligible=false}
        else self:Issue('node-invalid') end
      end
    end
  end)
  if not parsed then self:Issue('node-read'); return {} end
  table.sort(records,function(a,b) return a.nodeID<b.nodeID end)
  if #self.order==MAX_MAPS then
    local evicted=table.remove(self.order,1)
    self.cache[evicted]=nil
  end
  self.order[#self.order+1]=mapID
  self.cache[mapID]=records
  return copies(records)
end
-- Independent NPC spawn candidates; never join by name or proximity to a
-- native node (neither establishes node identity or route reachability).
function catalog:NpcCandidatesOnMap(mapID,wanted)
  if not integer(mapID,1,10000000) or
      (wanted~=nil and (not safe(wanted) or type(wanted)~='string' or
        wanted:lower()~='flight master')) then return {} end
  local npc=addon.npcs
  local side
  local sideOK,group=pcall(function() return UnitFactionGroup('player') end)
  if sideOK and safe(group) then
    if group=='Alliance' then side='A' elseif group=='Horde' then side='H' end
  end
  if not side or not safe(npc) or type(npc)~='table' then return {} end
  local ready,available=pcall(function() return npc:IsReady() end)
  if not ready or available~=true then return {} end
  local ok,rows=pcall(function() return npc:LocationsOnMap(mapID,'Flight Master') end)
  if not ok or not safe(rows) or type(rows)~='table' or getmetatable(rows) then
    self:Issue('npc-read'); return {}
  end
  local output,count={},0
  local parsed=pcall(function()
    for _,row in next,rows do
      count=count+1
      if count>MAX_NODES then self:Issue('npc-cap'); break end
      if safe(row) and type(row)=='table' and not getmetatable(row) and
          rawget(row,'category')=='Flight Master' and rawget(row,'mapID')==mapID and
          (rawget(row,'friendlyToFaction')==side or rawget(row,'friendlyToFaction')=='AH') and
          coordinate(rawget(row,'x')) and coordinate(rawget(row,'y')) then
        local record={}
        for key,value in next,row do
          if safe(key) and safe(value) and type(value)~='table' and
              type(value)~='function' and type(value)~='userdata' then
            record[key]=value
          end
        end
        record.plannerEligible=false
        output[#output+1]=record
      end
    end
  end)
  if not parsed then self:Issue('npc-read'); return {} end
  return output
end
-- Faction-compatible native boarding positions, not known connections. Advice
-- may compare these to destination map positions as unconfirmed candidates;
-- node discovery, ride availability and actual landing remain unknown.
function catalog:ServiceCandidatesOnMap(mapID)
  local ok,side=pcall(function() return UnitFactionGroup('player') end)
  if not ok or not safe(side) or (side~='Alliance' and side~='Horde') then return {} end
  local output={}
  for _,row in ipairs(self:LocationsOnMap(mapID,'Flight Master')) do
    if row.faction==side or row.faction=='Neutral' then
      row.friendlyToFaction=row.faction=='Neutral' and 'AH' or (side=='Alliance' and 'A' or 'H')
      row.rideEligibility='unknown'
      output[#output+1]=row
    end
  end
  return output
end
-- No map-wide node, NPC spawn, or discovery flag proves taxi access.
function catalog:EligibleOnMap(mapID,wanted)
  return {}
end
function catalog:Status()
  local issues={}
  for key,value in pairs(self.issues) do issues[key]=value end
  local count=0
  for _,records in pairs(self.cache) do count=count+#records end
  return {state=api() and 'ready' or 'unavailable',limited=true,
    reason='Map-wide nodes include opposing factions; discovery and ride eligibility unverified',
    cachedMaps=#self.order,rawPositions=count,eligibleCandidates=0,issues=issues}
end
-- Core forwards existing taxi/world events; no extra frame or update loop.
