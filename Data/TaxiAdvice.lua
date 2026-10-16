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
function taxi:Clear()
  self.reachable={}
  self.open=false
end
-- The active taxi map is the only authoritative source of currently reachable
-- destinations. It does not provide a reusable all-source flight graph.
function taxi:Capture()
  self:Clear()
  local names={}
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
        end
      end
      self.reachable,self.open=names,true
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
    if state==1 and label(name) then names[name:lower()]=name end
  end
  self.reachable,self.open=names,true
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
