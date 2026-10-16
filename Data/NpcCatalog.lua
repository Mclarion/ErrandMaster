-- Read QuestieDB's public contract at runtime; never copy its NPC records into SavedVariables.
local _, addon = ...
addon.npcs = {state="unavailable", reason="QuestieDB Forever is required"}
local catalog = addon.npcs
local categories = {
  {"Repair","REPAIR"}, {"Bank","BANKER"}, {"Auction House","AUCTIONEER"},
  {"Flight Master","FLIGHT_MASTER"}, {"Innkeeper","INNKEEPER"},
  {"Vendor","VENDOR"}, {"Trainer","TRAINER"},
}
local classes={"Death Knight","Demon Hunter","Druid","Evoker","Hunter",
  "Mage","Monk","Paladin","Priest","Rogue","Shaman","Warlock","Warrior"}
local professions={"Alchemy","Blacksmithing","Cooking","Enchanting",
  "Engineering","First Aid","Fishing","Herbalism","Inscription",
  "Jewelcrafting","Leatherworking","Mining","Skinning","Tailoring"}
local function plain(value)
  local ok, safe = pcall(function()
    if type(issecretvalue)=="function" and issecretvalue(value) then return false end
    if type(value)=="table" and type(issecrettable)=="function" and issecrettable(value) then return false end
    return true
  end)
  return ok and safe
end
local function integer(value, low, high)
  return plain(value) and type(value)=="number" and value==value and
    value>=low and value<=high and value%1==0
end
local function call(fn, ...)
  if not plain(fn) or type(fn)~="function" then return end
  local ok, value = pcall(fn, ...)
  if ok and plain(value) then return value end
end
local function hasFlag(flags, flag)
  return integer(flags,0,4294967295) and integer(flag,1,2147483647) and
    math.floor(flags/flag)%2==1
end
local function trainerSpecialty(subtitle, flags, trainerFlag)
  if not hasFlag(flags,trainerFlag) or not plain(subtitle) or
      type(subtitle)~="string" or #subtitle>120 then return end
  local text=subtitle:lower()
  for _,group in ipairs({classes,professions}) do
    for _,label in ipairs(group) do
      local word=label:lower():gsub(" ","%%s+")
      if text:find("%f[%a]"..word.."%f[%A]") then
        return label.." Trainer",group==professions and "Profession Trainer" or "Class Trainer"
      end
    end
  end
end
local function vendorSpecialty(subtitle,flags,vendorFlag)
  if not hasFlag(flags,vendorFlag) or not plain(subtitle) or
      type(subtitle)~="string" or #subtitle>120 then return end
  local text=subtitle:lower()
  for _,label in ipairs({"Ammo","Reagent","Food"}) do
    if text:find("%f[%a]"..label:lower().."%f[%A]") then
      return label.." Vendor"
    end
  end
  for _,label in ipairs(professions) do
    local word=label:lower():gsub(" ","%%s+")
    if text:find("%f[%a]"..word.."%f[%A]") then
      return label.." Vendor","Profession Vendor"
    end
  end
end
local function faction()
  local result=call(UnitFactionGroup,"player")
  if result=="Alliance" then return "A" end
  if result=="Horde" then return "H" end
end
function catalog:Initialize()
  self.state, self.reason = "unavailable", "QuestieDB Forever is required"
  self.provider, self.ids, self.areas, self.byMap, self.records = nil,nil,nil,nil,nil
  self.coverageLimited={}
  self.indexIncomplete=false
  self.cursor = 1
  local provider=LibQuestieDB
  if not plain(provider) or type(provider)~="table" then return false end
  local inspected, compatible, reason, npc, source = pcall(function()
    local ok, message = provider.RequireContract(4)
    return ok, message, provider.Npc,
      provider.Support.Get("ZoneDB").private.areaIdToUiMapId
  end)
  -- pcall results are (success, contractResult, message, npc, source).
  if not inspected then self.reason="QuestieDB contract unavailable"; return false end
  if compatible~=true then
    self.reason=type(reason)=="string" and reason or "QuestieDB contract 4 required"
    return false
  end
  local flavorOK, flavor=pcall(function() return provider.flavor.name end)
  if not flavorOK or not plain(flavor) or flavor~="Forever" then
    self.reason="QuestieDB Forever data not active"; return false
  end
  if not plain(npc) or type(npc)~="table" or
      type(npc.GetAllIds)~="function" or type(npc.npcFlags)~="function" or
      type(npc.spawns)~="function" or type(npc.name)~="function" or
      not plain(source) or type(source)~="string" or #source>250000 or
      not source:match("^%s*return%s*{") then
    self.reason="QuestieDB NPC or map data unavailable"; return false
  end
  local loader=loadstring or load
  if type(loader)~="function" or type(setfenv)~="function" then
    self.reason="QuestieDB map decoder unavailable"; return false
  end
  local compiled=call(loader,source)
  if not compiled or not pcall(setfenv,compiled,{}) then
    self.reason="QuestieDB map decoder failed"; return false
  end
  local areas=call(compiled)
  if type(areas)~="table" or not plain(areas) or getmetatable(areas) then
    self.reason="QuestieDB map table invalid"; return false
  end
  local ids=call(npc.GetAllIds)
  if type(ids)~="table" or not plain(ids) or #ids>100000 then
    self.reason="QuestieDB NPC IDs unavailable"; return false
  end
  local flagsOK, flags=pcall(function() return provider.Enum.npcFlags end)
  if not flagsOK or not plain(flags) or type(flags)~="table" then
    self.reason="QuestieDB service flags unavailable"; return false
  end
  self.provider, self.ids, self.areas = provider, ids, areas
  self.flags, self.byMap, self.records = flags, {}, {}
  self.state, self.reason = "indexing", nil
  return true
end
function catalog:Status()
  return {state=self.state,reason=self.reason,processed=math.max(0,(self.cursor or 1)-1),
    total=self.ids and #self.ids or 0,
    limited=self.indexIncomplete or next(self.coverageLimited or {})~=nil}
end
function catalog:IsReady() return self.state=="ready" end
function catalog:Step(batch)
  if self.state~="indexing" then return self:IsReady() end
  batch = integer(batch,1,200) and batch or 80
  local last=math.min(#self.ids,self.cursor+batch-1)
  local npc=self.provider.Npc
  for index=self.cursor,last do
    local id=self.ids[index]
    if integer(id,1,2147483647) then
      local flags=call(npc.npcFlags,id)
      local service=false
      for _,entry in ipairs(categories) do
        if hasFlag(flags,self.flags[entry[2]]) then service=true; break end
      end
      if service then
        local read,spawns=pcall(npc.spawns,id)
        if not read then
          self.indexIncomplete=true
          self.reason="Some QuestieDB NPC spawn reads failed; catalog is incomplete"
        end
        if type(spawns)=="table" and plain(spawns) then
          local indexed=pcall(function()
            for area, points in pairs(spawns) do
              local mapID=self.areas[area]
              if integer(mapID,1,10000000) and type(points)=="table" and
                  plain(points) and #points>0 then
                local bucket=self.byMap[mapID] or {}
                bucket[id]=true
                self.byMap[mapID]=bucket
              end
            end
          end)
          if not indexed then
            self.indexIncomplete=true
            self.reason="Some QuestieDB NPC map entries could not be indexed"
          end
        end
      end
    end
  end
  self.cursor=last+1
  if self.cursor>#self.ids then self.state="ready"; return true end
  return false
end
local function validSpawn(point)
  if not plain(point) or type(point)~="table" then return end
  local ok,x,y,phase=pcall(function() return point[1],point[2],point[3] end)
  if not ok or not plain(x) or not plain(y) or not plain(phase) or
      type(x)~="number" or type(y)~="number" or x~=x or y~=y or
      x<0 or x>100 or y<0 or y>100 then return end
  return x/100,y/100,phase~=nil
end
function catalog:LocationsOnMap(mapID, wanted)
  if not self:IsReady() or not integer(mapID,1,10000000) then return {} end
  if wanted and type(wanted)~="string" then return {} end
  if not self.records[mapID] then
    local records={}
    local npc=self.provider.Npc
    for id in pairs(self.byMap[mapID] or {}) do
      local name=call(npc.name,id)
      local flags=call(npc.npcFlags,id)
      local friendly=call(npc.friendlyToFaction,id)
      local spawns=call(npc.spawns,id)
      local subtitle=call(npc.subName,id)
      local specialty,trainerGroup=trainerSpecialty(subtitle,flags,self.flags.TRAINER)
      local vendorType,vendorGroup=vendorSpecialty(subtitle,flags,self.flags.VENDOR)
      specialty=specialty or vendorType
      if type(name)=="string" and #name>0 and #name<=120 and
          integer(flags,0,4294967295) and type(spawns)=="table" and plain(spawns) then
        local admitted=friendly=="A" or friendly=="H" or friendly=="AH"
        if admitted then
          local ok=pcall(function()
            for area, points in pairs(spawns) do
              if self.areas[area]==mapID and type(points)=="table" and plain(points) then
                for spawnIndex, point in ipairs(points) do
                  local x,y,phased=validSpawn(point)
                  if x and #records<10000 then
                    for _,entry in ipairs(categories) do
                      if hasFlag(flags,self.flags[entry[2]]) then
                        records[#records+1]={id="npc-"..id.."-"..area.."-"..spawnIndex.."-"..entry[2],
                          npcID=id,name=name,category=entry[1],mapID=mapID,x=x,y=y,
                          source="questiedb-forever",precision="candidate-spawn",
                          phaseUnverified=phased,friendlyToFaction=friendly,
                          minLevel=call(npc.minLevel,id),subtitle=subtitle,
                          specialty=specialty,trainerGroup=trainerGroup,
                          vendorGroup=vendorGroup,
                          functionEvidence=specialty and "QuestieDB NPC subtitle" or nil}
                      end
                    end
                  elseif x then
                    self.coverageLimited[mapID]=true
                    self.reason="QuestieDB map "..mapID.." exceeds the 10,000-record cap; NPC search is incomplete"
                  end
                end
              end
            end
          end)
          if not ok then
            self.coverageLimited[mapID]=true
            self.reason="Some QuestieDB NPC spawns could not be read; this map is incomplete"
          end
        end
      end
    end
    table.sort(records,function(a,b)
      if a.name~=b.name then return a.name<b.name end
      if a.npcID~=b.npcID then return a.npcID<b.npcID end
      if a.x~=b.x then return a.x<b.x end
      return a.y<b.y
    end)
    self.records[mapID]=records
  end
  local side=faction()
  local output={}
  for _,record in ipairs(self.records[mapID]) do
    if (not wanted or record.category:lower()==wanted:lower() or
        (record.specialty and record.specialty:lower()==wanted:lower()) or
        (record.trainerGroup and record.trainerGroup:lower()==wanted:lower()) or
        (record.vendorGroup and record.vendorGroup:lower()==wanted:lower())) and
        (record.friendlyToFaction=="AH" or not side or record.friendlyToFaction==side) then
      output[#output+1]=record
    end
  end
  return output
end
function catalog:Find(query,mapID,x,y,width,height)
  if type(query)~="string" or #query<1 or #query>80 then return {} end
  local result,seen={},{}
  local measured=type(width)=="number" and type(height)=="number" and
    plain(width) and plain(height) and width>0 and height>0
  local sx,sy=measured and width or 1,measured and height or 1
  local position=type(x)=="number" and type(y)=="number" and
    plain(x) and plain(y) and x>=0 and x<=1 and y>=0 and y<=1
  local needle=query:lower()
  for _,item in ipairs(self:LocationsOnMap(mapID)) do
    if item.name:lower():find(needle,1,true) or
        (item.subtitle and item.subtitle:lower():find(needle,1,true)) or
        (item.specialty and item.specialty:lower():find(needle,1,true)) then
      local score=position and ((item.x-x)^2*sx*sx+(item.y-y)^2*sy*sy) or 0
      local previous=seen[item.npcID]
      if not previous or score<previous.score then
        local entry={id=item.npcID,name=item.name,
          category=item.specialty or item.category,subtitle=item.subtitle,
          x=item.x,y=item.y,score=score,phaseUnverified=item.phaseUnverified}
        if not previous then result[#result+1]=entry end
        seen[item.npcID]=entry
      end
    end
  end
  for i,entry in ipairs(result) do result[i]=seen[entry.id] end
  table.sort(result,function(a,b)
    if a.score~=b.score then return a.score<b.score end
    if a.name~=b.name then return a.name<b.name end
    return a.id<b.id
  end)
  local first={}
  for i=1,math.min(#result,20) do first[i]=result[i] end
  return first
end
-- Geometric proximity only; no terrain, phasing, or path assertion.
function catalog:Nearest(mapID,x,y,wanted,width,height,limit)
  if not integer(mapID,1,10000000) or not plain(x) or not plain(y) or
      type(x)~="number" or type(y)~="number" or x~=x or y~=y or
      x<0 or x>1 or y<0 or y>1 then return {} end
  limit=integer(limit,1,20) and limit or 5
  local measured=plain(width) and plain(height) and type(width)=="number" and
    type(height)=="number" and width>0 and height>0 and
    width<=10000000 and height<=10000000
  local sx,sy=measured and width or 1, measured and height or 1
  local top={}
  for _,place in ipairs(self:LocationsOnMap(mapID,wanted)) do
    local dx,dy=(place.x-x)*sx,(place.y-y)*sy
    local score=dx*dx+dy*dy
    local index=1
    while index<=#top and (top[index].score<score or
        (top[index].score==score and top[index].place.id<place.id)) do
      index=index+1
    end
    if index<=limit then
      table.insert(top,index,{place=place,score=score})
      if #top>limit then table.remove(top) end
    end
  end
  local result={}
  for _,entry in ipairs(top) do
    local record={}
    for key,value in pairs(entry.place) do record[key]=value end
    record.directYards=measured and math.sqrt(entry.score) or nil
    record.mapGap=math.sqrt((record.x-x)^2+(record.y-y)^2)
    result[#result+1]=record
  end
  return result
end
