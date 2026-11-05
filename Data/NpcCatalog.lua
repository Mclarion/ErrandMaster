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
local trainerAliases={alchemist="Alchemy",herbalist="Herbalism",
  fisherman="Fishing",engineer="Engineering",leatherworker="Leatherworking",
  leathercrafter="Leatherworking",blacksmith="Blacksmithing",tailor="Tailoring",
  enchanter="Enchanting",miner="Mining",skinner="Skinning",cook="Cooking",
  physician="First Aid"}
local trainerRanks={apprentice=true,journeyman=true,expert=true,artisan=true,
  master=true,superior=true}
local trainerSpecializations={
  ["dragonscale leatherworker"]="Leatherworking",
  ["elemental leatherworker"]="Leatherworking",
  ["tribal leatherworker"]="Leatherworking",
  ["goblin engineer"]="Engineering",["gnome engineer"]="Engineering",
  ["shadoweave tailor"]="Tailoring"}
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
local function trainerAlias(name, subtitle, flags, trainerFlag)
  if not hasFlag(flags,trainerFlag) then return end
  local profession
  for _,text in ipairs({name,subtitle}) do
    if type(text)=="string" and plain(text) and #text<=120 then
      -- Provider titles use occupations, not only profession names. Strip
      -- only known ranks and match the entire remaining title; a merchant
      -- mentioning leather goods must not become a leatherworking trainer.
      local title=text:lower():match("^%s*(.-)%s*$"):gsub("%s+"," ")
      if title=="pet trainer" then return "Pet Trainer" end
      if title=="weapon master" or title=="weapon trainer" then return "Weapon Trainer" end
      title=title:gsub(" trainer$","")
      local rank,occupation=title:match("^(%a+) (.+)$")
      if trainerRanks[rank] then title=occupation end
      profession=trainerAliases[title] or trainerSpecializations[title]
      if profession then break end
    end
  end
  if profession then return profession.." Trainer","Profession Trainer" end
end
local function vendorSpecialties(subtitle,flags,vendorFlag)
  local matches={}
  if not hasFlag(flags,vendorFlag) or not plain(subtitle) or
      type(subtitle)~="string" or #subtitle>120 then return matches end
  local text=subtitle:lower()
  for _,label in ipairs({"Ammo","Reagent","Food"}) do
    if text:find("%f[%a]"..label:lower().."%f[%A]") or
        (label=="Reagent" and text:find("%f[%a]reagents%f[%A]")) then
      matches[#matches+1]={label.." Vendor","QuestieDB NPC subtitle"}
    end
  end
  for _,label in ipairs(professions) do
    local word=label:lower():gsub(" ","%%s+")
    if text:find("%f[%a]"..word.."%f[%A]") then
      matches[#matches+1]={label.." Vendor","QuestieDB NPC subtitle","Profession Vendor"}
    end
  end
  return matches
end
local function faction()
  local result=call(UnitFactionGroup,"player")
  if result=="Alliance" then return "A" end
  if result=="Horde" then return "H" end
end
-- Do not trust Lua's length operator or ipairs on provider-owned arrays.
-- Bound raw entries, retain original numeric keys, and never invoke metatables.
function catalog:ListKeys(list,limit,code,mapID)
  local keys={}
  if not plain(list) or type(list)~='table' or getmetatable(list) then
    self:Issue(code..'-read',mapID); return keys
  end
  local count=0
  for key in next,list do
    count=count+1
    if count>limit then self:Issue(code..'-cap',mapID); break end
    if integer(key,1,2147483647) then keys[#keys+1]=key
    else self:Issue(code..'-key',mapID) end
  end
  table.sort(keys)
  if #keys>0 and keys[#keys]~=#keys then self:Issue(code..'-sparse',mapID) end
  return keys
end
function catalog:ReadIds(list,limit,code)
  local ids,seen={},{}
  if not plain(list) or type(list)~='table' or getmetatable(list) then
    self:Issue(code..'-read'); return ids
  end
  local count,keyCount,maxKey=0,0,0
  for key,id in next,list do
    if self.normalizer and coroutine.running()==self.normalizer then
      if self.normalizeRemaining==0 then coroutine.yield() end
      self.normalizeRemaining=self.normalizeRemaining-1
      self.normalizedEntries=self.normalizedEntries+1
    end
    count=count+1
    if count>limit then self:Issue(code..'-cap'); break end
    if not integer(key,1,2147483647) then self:Issue(code..'-key')
    else
      keyCount=keyCount+1; maxKey=math.max(maxKey,key)
      if not integer(id,1,2147483647) then self:Issue(code..'-value')
      elseif seen[id] then self:Issue(code..'-duplicate')
      else ids[#ids+1]=id; seen[id]=true end
    end
  end
  if maxKey~=keyCount then self:Issue(code..'-sparse') end
  return ids
end
function catalog:NormalizeStep(batch)
  self.normalizeRemaining=batch
  local ok=coroutine.resume(self.normalizer)
  if not ok then
    self:Issue('id-normalization-read')
    self.state,self.reason='unavailable','QuestieDB ID normalization failed; reinitialize provider'
  end
  if not ok or coroutine.status(self.normalizer)=='dead' then self.normalizer=nil end
end
function catalog:Initialize()
  self.normalizer,self.normalizedEntries=nil,0
  self.issues={}
  self.state, self.reason = "unavailable", "QuestieDB Forever is required"
  self.provider, self.ids, self.areas, self.byMap, self.records = nil,nil,nil,nil,nil
  self.coverageLimited={}
  self.mapIssues={}
  self.mapServices={}
  self.indexIncomplete=false
  self.cursor = 1
  self.itemCursor, self.itemIds, self.inventory = 1,nil,{}
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
  if type(ids)~="table" or not plain(ids) then
    self.reason="QuestieDB NPC IDs unavailable"; return false
  end
  self.reason=nil
  local flagsOK, flags=pcall(function() return provider.Enum.npcFlags end)
  if not flagsOK or not plain(flags) or type(flags)~="table" then
    self.reason="QuestieDB service flags unavailable"; return false
  end
  self.provider, self.ids, self.areas = provider, {}, areas
  self.flags, self.byMap, self.records = flags, {}, {}
  local item=provider.Item
  local itemIds
  if plain(item) and type(item)=="table" and type(item.GetAllIds)=="function" and
      type(item.vendors)=="function" and type(item.class)=="function" and
      type(item.subClass)=="function" then
    itemIds=call(item.GetAllIds)
    if type(itemIds)~="table" or not plain(itemIds) then itemIds=nil end
  end
  if not itemIds then
    self.indexIncomplete=true
    self.reason="QuestieDB Item inventory unavailable; vendor specialty coverage limited to subtitles"
  end
  self.state = "indexing"
  self.normalizer=coroutine.create(function()
    self.ids=self:ReadIds(ids,100000,'npc-ids')
    if itemIds then self.itemIds=self:ReadIds(itemIds,1000000,'item-ids') end
  end)
  self:NormalizeStep(80)
  return self.state=='indexing'
end
function catalog:Issue(code,mapID)
  self.issues=self.issues or {}
  self.issues[code]=math.min(1000000,(self.issues[code] or 0)+1)
  self.indexIncomplete=true
  if mapID then
    self.mapIssues[mapID]=self.mapIssues[mapID] or {}
    local issues=self.mapIssues[mapID]
    issues[code]=math.min(1000000,(issues[code] or 0)+1)
    self.coverageLimited[mapID]=true
  end
  if not self.reason then self.reason="QuestieDB coverage incomplete: "..code end
end
function catalog:Status()
  local issues={}
  for code,count in pairs(self.issues or {}) do issues[code]=count end
  return {state=self.state,reason=self.reason,processed=math.max(0,(self.cursor or 1)-1),
    issues=issues,
    normalizing=self.normalizer~=nil,normalizedEntries=self.normalizedEntries or 0,
    total=self.ids and #self.ids or 0,
    itemsProcessed=self.itemIds and math.min(#self.itemIds,(self.itemCursor or 1)-1) or 0,
    itemsTotal=self.itemIds and #self.itemIds or 0,
    limited=self.indexIncomplete or next(self.coverageLimited or {})~=nil}
end
function catalog:IsReady() return self.state=="ready" end
function catalog:Step(batch)
  if self.state~="indexing" then return self:IsReady() end
  batch = integer(batch,1,200) and batch or 80
  if self.normalizer then self:NormalizeStep(batch); return false end
  -- Item and NPC phases share the scheduler's per-call budget; never expose a
  -- ready catalog until the complete inventory-to-NPC index has been built.
  if self.itemIds and self.itemCursor<=#self.itemIds then
    local item=self.provider.Item
    local lastItem=math.min(#self.itemIds,self.itemCursor+batch-1)
    for index=self.itemCursor,lastItem do
      local id=self.itemIds[index]
      if integer(id,1,2147483647) then
        local ok,cls,sub,vendors=pcall(function()
          local class=item.class(id)
          if class~=6 and class~=5 and class~=0 then return class end
          local subclass=class==0 and item.subClass(id) or nil
          if class==0 and subclass~=5 then return class,subclass end
          return class,subclass,item.vendors(id)
        end)
        if not ok then
          self:Issue('item-read')
          self.reason="Some QuestieDB Item reads failed; vendor specialties are incomplete"
        elseif not integer(cls,0,255) or (cls==0 and not integer(sub,0,255)) then
          self:Issue('item-class')
        elseif cls==6 or cls==5 or (cls==0 and sub==5) then
          local label=cls==6 and "Ammo Vendor" or cls==5 and "Reagent Vendor" or "Food Vendor"
          if vendors~=nil and (type(vendors)~="table" or not plain(vendors) or
              getmetatable(vendors)) then
            self:Issue('item-vendors-read')
            self.reason="Some QuestieDB Item vendor lists are invalid; vendor specialties are incomplete"
          elseif type(vendors)=="table" then
            local valid=pcall(function()
              for _,key in ipairs(self:ListKeys(vendors,2000,'item-vendors')) do
                local npcID=rawget(vendors,key)
                if integer(npcID,1,2147483647) then
                  local matched=self.inventory[npcID] or {}
                  matched[label]=true
                  self.inventory[npcID]=matched
                else
                  self:Issue('item-vendor-id')
                end
              end
            end)
            if not valid then
              self:Issue('item-vendors-read')
              self.reason="Some QuestieDB Item vendor lists could not be read"
            end
          end
        end
      end
    end
    self.itemCursor=lastItem+1
    return false
  end
  local last=math.min(#self.ids,self.cursor+batch-1)
  local npc=self.provider.Npc
  for index=self.cursor,last do
    local id=self.ids[index]
    if integer(id,1,2147483647) then
      local flags=call(npc.npcFlags,id)
      local service=false
      if not integer(flags,0,4294967295) then self:Issue('npc-flags') end
      for _,entry in ipairs(categories) do
        if hasFlag(flags,self.flags[entry[2]]) then service=true; break end
      end
      if service then
        local read,spawns=pcall(npc.spawns,id)
        if not read or type(spawns)~="table" or not plain(spawns) then
          self:Issue('npc-spawns')
        end
        if not read then
          self.indexIncomplete=true
          self.reason="Some QuestieDB NPC spawn reads failed; catalog is incomplete"
        end
        if type(spawns)=="table" and plain(spawns) then
          local indexed=pcall(function()
            if next(spawns)==nil then self:Issue('empty-spawns') end
            for area, points in pairs(spawns) do
              local mapID=self.areas[area]
              if not integer(mapID,1,10000000) then self:Issue('unmapped-area')
              elseif type(points)~="table" or not plain(points) or next(points)==nil then
                self:Issue('empty-spawns',mapID)
              end
              if integer(mapID,1,10000000) and type(points)=="table" and
                  plain(points) and next(points)~=nil then
                local bucket=self.byMap[mapID] or {}
                bucket[id]=true
                self.byMap[mapID]=bucket
                local services=self.mapServices[mapID] or {}
                for _,entry in ipairs(categories) do
                  if hasFlag(flags,self.flags[entry[2]]) then services[entry[1]]=true end
                end
                self.mapServices[mapID]=services
              end
            end
          end)
          if not indexed then
            self:Issue('npc-map-read')
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
      if #records>=10000 then self:Issue('record-cap',mapID); break end
      local name=call(npc.name,id)
      local flags=call(npc.npcFlags,id)
      local friendly=call(npc.friendlyToFaction,id)
      local spawns=call(npc.spawns,id)
      local subtitle=call(npc.subName,id)
      local specialty,trainerGroup=trainerSpecialty(subtitle,flags,self.flags.TRAINER)
      if not specialty then specialty,trainerGroup=trainerAlias(name,subtitle,flags,self.flags.TRAINER) end
      local vendorLabels={}
      if hasFlag(flags,self.flags.VENDOR) then
        for _,label in ipairs({"Ammo Vendor","Reagent Vendor","Food Vendor"}) do
          if self.inventory[id] and self.inventory[id][label] then
            vendorLabels[#vendorLabels+1]={label,"QuestieDB Item vendors/class"}
          end
        end
        for _,kind in ipairs(vendorSpecialties(subtitle,flags,self.flags.VENDOR)) do
          if not (self.inventory[id] and self.inventory[id][kind[1]]) then
            vendorLabels[#vendorLabels+1]=kind
          end
        end
      end
      if type(name)=="string" and #name>0 and #name<=120 and
          integer(flags,0,4294967295) and type(spawns)=="table" and plain(spawns) then
        local admitted=friendly=="A" or friendly=="H" or friendly=="AH"
        if admitted then
          local minLevel=call(npc.minLevel,id)
          local ok=pcall(function()
            for area, points in pairs(spawns) do
              if self.areas[area]==mapID and type(points)=="table" and plain(points) then
                for _,spawnIndex in ipairs(self:ListKeys(points,10000,'spawn-list',mapID)) do
                  if #records>=10000 then self:Issue('record-cap',mapID); return end
                  local point=rawget(points,spawnIndex)
                  local x,y,phased=validSpawn(point)
                  if x and #records<10000 then
                    for _,entry in ipairs(categories) do
                      if hasFlag(flags,self.flags[entry[2]]) then
                        local specialties=entry[2]=="VENDOR" and #vendorLabels>0 and vendorLabels or
                          {{entry[2]=="TRAINER" and specialty or nil,nil}}
                        for _,kind in ipairs(specialties) do
                        if #records>=10000 then
                          self:Issue('record-cap',mapID)
                          self.reason="QuestieDB map "..mapID.." exceeds the 10,000-record cap; NPC search is incomplete"
                          break
                        end
                        records[#records+1]={id="npc-"..id.."-"..area.."-"..spawnIndex.."-"..entry[2].."-"..(kind[1] or "general"),
                          npcID=id,name=name,category=entry[1],mapID=mapID,x=x,y=y,
                          source="questiedb-forever",precision="candidate-spawn",
                          phaseUnverified=phased,friendlyToFaction=friendly,
                          minLevel=minLevel,subtitle=subtitle,
                          specialty=kind[1],trainerGroup=entry[2]=="TRAINER" and trainerGroup or nil,
                          vendorGroup=entry[2]=="VENDOR" and kind[3] or nil,
                          functionEvidence=kind[2] or (kind[1] and "QuestieDB NPC name/subtitle" or nil)}
                        end
                      end
                    end
                  elseif x then
                    self:Issue('record-cap',mapID)
                    self.reason="QuestieDB map "..mapID.." exceeds the 10,000-record cap; NPC search is incomplete"
                  else
                    self:Issue('invalid-coordinate',mapID)
                  end
                end
              end
            end
          end)
          if not ok then
            self:Issue('npc-map-read',mapID)
            self.reason="Some QuestieDB NPC spawns could not be read; this map is incomplete"
          end
        else
          self:Issue('npc-faction',mapID)
        end
      else
        self:Issue('npc-record',mapID)
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
function catalog:Diagnostics(mapID, wanted)
  local selected=self:LocationsOnMap(mapID,wanted)
  local report=self:Status()
  report.mapID,report.service=mapID,wanted
  report.candidates,report.factionExcluded=#selected,0
  report.mapLimited=self.coverageLimited and self.coverageLimited[mapID] or false
  report.mapIssues={}
  for code,count in pairs(self.mapIssues and self.mapIssues[mapID] or {}) do
    report.mapIssues[code]=count
  end
  report.inventoryEvidence='not-evidenced'
  for _,record in ipairs(selected) do
    if record.functionEvidence=='QuestieDB Item vendors/class' then
      report.inventoryEvidence='candidate-evidence'
    end
  end
  local side=faction()
  for _,record in ipairs(self.records and self.records[mapID] or {}) do
    local matches=not wanted or record.category:lower()==wanted:lower() or
      (record.specialty and record.specialty:lower()==wanted:lower()) or
      (record.trainerGroup and record.trainerGroup:lower()==wanted:lower()) or
      (record.vendorGroup and record.vendorGroup:lower()==wanted:lower())
    if matches and side and record.friendlyToFaction~='AH' and record.friendlyToFaction~=side then
      report.factionExcluded=report.factionExcluded+1
    end
  end
  return report
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
