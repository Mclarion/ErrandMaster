local _, addon = ...
addon.zoneSearch = {}
local search = addon.zoneSearch
local function usable(value)
  if value == nil then return false end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue,value)
    if not ok or secret then return false end
  end
  if type(value) == "table" and type(issecrettable) == "function" then
    local ok, secret = pcall(issecrettable,value)
    if not ok or secret then return false end
  end
  return true
end
local function finite(value)
  return usable(value) and type(value)=="number" and value==value and
    value>=-100000000 and value<=100000000
end
local function mapMethod(name)
  if not usable(C_Map) then return end
  local ok,method=pcall(function() return C_Map[name] end)
  if ok and usable(method) and type(method)=="function" then return method end
end
local function world(map,x,y,method)
  local ok,vector=pcall(CreateVector2D,x,y)
  if not ok or not usable(vector) then return end
  local valid,continent,position=pcall(method,map,vector)
  if not valid or not finite(continent) or not usable(position) then return end
  local projected,wx,wy=pcall(function() return position:GetXY() end)
  if projected and finite(wx) and finite(wy) then return continent,wx,wy end
end
local function within(value,minimum,maximum)
  return math.max(minimum,math.min(maximum,value))
end
-- Candidate spawns in sibling UI maps and their immediate child maps only.
-- Cities may be children of a sibling zone. Distance is direct world distance;
-- neither the zone boundary nor terrain is a proven walking connection.
function search:Nearby(map,x,y,wanted,radius,limit,query)
  if not finite(map) or map%1~=0 or map<1 or not finite(x) or
      not finite(y) or x<0 or x>1 or y<0 or y>1 or
      not finite(radius) or radius<1 or radius>10000 or
      not finite(limit) or limit%1~=0 or limit<1 or limit>20 or
      not addon.npcs or not addon.npcs.IsReady or not addon.npcs:IsReady() or
      type(CreateVector2D)~="function" or not usable(CreateVector2D) then return {} end
  if wanted and (not usable(wanted) or type(wanted)~="string") then return {} end
  if query and (not usable(query) or type(query)~="string" or #query>80) then return {} end
  local getInfo=mapMethod("GetMapInfo")
  local children=mapMethod("GetMapChildrenInfo")
  local convert=mapMethod("GetWorldPosFromMapPos")
  if not getInfo or not children or not convert then return {} end
  local origin,px,py=world(map,x,y,convert)
  if not origin then return {} end
  local ok,info=pcall(getInfo,map)
  if not ok or not usable(info) then return {} end
  local parentOK,parent=pcall(function() return info.parentMapID end)
  if not parentOK or not finite(parent) or parent<1 or parent%1~=0 then return {} end
  local found,related=pcall(children,parent)
  if not found or not usable(related) or type(related)~="table" or
      #related>80 then return {} end
  local candidates={}
  for _,child in ipairs(related) do
    candidates[#candidates+1]=child
    local valid,id=pcall(function() return child.mapID end)
    if valid and finite(id) and id%1==0 and id>0 and id~=map then
      local foundChildren,nested=pcall(children,id)
      if foundChildren and usable(nested) and type(nested)=="table" and #nested<=80 then
        for _,submap in ipairs(nested) do
          if #candidates>=160 then break end
          candidates[#candidates+1]=submap
        end
      end
    end
  end
  local top,needle={},query and query:lower()
  local seen={}
  for _,child in ipairs(candidates) do
    local checked,candidate,name=pcall(function() return child.mapID,child.name end)
    if checked and finite(candidate) and candidate%1==0 and candidate~=map and
        not seen[candidate] and usable(name) and type(name)=="string" and
        #name<=80 and not name:find("[%c|]") then
      seen[candidate]=true
      local continent,ax,ay=world(candidate,0,0,convert)
      local opposite,bx,by=world(candidate,1,1,convert)
      if continent==origin and opposite==origin then
        local edgeX=within(px,math.min(ax,bx),math.max(ax,bx))
        local edgeY=within(py,math.min(ay,by),math.max(ay,by))
        if (edgeX-px)^2+(edgeY-py)^2<=radius*radius then
          local entries=addon.npcs:LocationsOnMap(candidate,wanted)
          for _,place in ipairs(entries) do
            local valid,entryName,subtitle,specialty,sx,sy=pcall(function()
              return place.name,place.subtitle,place.specialty,place.x,place.y
            end)
            if valid and finite(sx) and finite(sy) and sx>=0 and sx<=1 and
                sy>=0 and sy<=1 and usable(entryName) and type(entryName)=="string" and
                (not needle or entryName:lower():find(needle,1,true) or
                  (usable(subtitle) and type(subtitle)=="string" and
                    subtitle:lower():find(needle,1,true)) or
                  (usable(specialty) and type(specialty)=="string" and
                    specialty:lower():find(needle,1,true))) then
              local other,wx,wy=world(candidate,sx,sy,convert)
              if other==origin then
                local score=(wx-px)^2+(wy-py)^2
                if score<=radius*radius then
                  local entry={}
                  for key,value in pairs(place) do entry[key]=value end
                  entry.zoneName=name
                  entry.directYards=math.sqrt(score)
                  top[#top+1]=entry
                end
              end
            end
          end
        end
      end
    end
  end
  table.sort(top,function(a,b)
    if a.directYards~=b.directYards then return a.directYards<b.directYards end
    return tostring(a.id)<tostring(b.id)
  end)
  local result={}
  for i=1,math.min(#top,limit) do result[i]=top[i] end
  return result
end

-- One plan-local cache: no radius or sibling-zone restriction. Native world
-- projections compare only the same instance; unprojectable maps cannot be
-- advertised as nearer than a measurable candidate.
function search:RouteContext(observed,walk)
  local projections,sizes,choices={},{},{}
  local function projected(point)
    if not point or not finite(point.mapID) or not finite(point.x) or not finite(point.y) then return end
    local key=point.mapID..':'..point.x..':'..point.y
    if projections[key]==nil then
      local instance,x,y
      if addon.navigation and addon.navigation.WorldPosition then
        instance,x,y=addon.navigation:WorldPosition(point.mapID,point.x,point.y)
      end
      projections[key]=instance~=nil and {instance,x,y} or false
    end
    local value=projections[key]
    if value then return value[1],value[2],value[3] end
  end
  local function metric(from,to)
    if not from or not to then return end
    local ai,ax,ay=projected(from)
    local bi,bx,by=projected(to)
    if ai~=nil and ai==bi then return math.sqrt((ax-bx)^2+(ay-by)^2) end
    if from.mapID==to.mapID and finite(from.x) and finite(from.y) and finite(to.x) and finite(to.y) then
      if sizes[from.mapID]==nil then
        local w,h=addon:MapWorldSize(from.mapID)
        sizes[from.mapID]=finite(w) and finite(h) and w>0 and h>0 and {w,h} or false
      end
      local size=sizes[from.mapID]
      if size then return math.sqrt(((from.x-to.x)*size[1])^2+((from.y-to.y)*size[2])^2) end
    end
  end
  local function candidates(from,item)
    local key=table.concat({from.mapID,from.x,from.y,tostring(item.category),tostring(item.npcID)},':')
    if choices[key] then return choices[key] end
    local best,score
    local function consider(place)
      if addon.route:Matches(item,place) then
        local current=metric(from,place)
        if current and (not score or current<score or
            (current==score and tostring(place.id)<tostring(best.id))) then best,score=place,current end
      end
    end
    for _,place in ipairs(observed or {}) do consider(place) end
    local instance=projected(from)
    local npcs=addon.npcs
    if npcs and npcs:IsReady() then
      local base=item.category
      if type(base)=='string' and base:sub(-7)==' Vendor' then base='Vendor' end
      if type(base)=='string' and base:sub(-8)==' Trainer' then base='Trainer' end
      local function possible(map)
        return item.npcID or not npcs.mapServices or
          (npcs.mapServices[map] and npcs.mapServices[map][base])
      end
      if possible(from.mapID) then
        for _,place in ipairs(npcs:LocationsOnMap(from.mapID)) do consider(place) end
      end
      -- No affine projection guarantee: corner coordinates cannot bound an
      -- interior service. Scan service-indexed maps and compare actual records.
      for map,bucket in pairs(npcs.byMap or {}) do
        if instance~=nil and map~=from.mapID and possible(map) and
            (not item.npcID or bucket[item.npcID]) then
          for _,place in ipairs(npcs:LocationsOnMap(map)) do consider(place) end
        end
      end
    end
    local result=best and {best} or {}
    choices[key]=result
    return result
  end
  return {distance=metric,candidates=candidates,walk=walk}
end
