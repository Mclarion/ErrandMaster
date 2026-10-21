-- Optional QuestieDB Forever object candidates; no object data is bundled here.
-- Exact base name "Mailbox" is observed in the installed baked Object rows. It is
-- not a gameobject-type API: other mailbox-like names remain unknown/unsupported.
local _,addon=...
addon.objects={state='unavailable',reason='QuestieDB Forever Object data unavailable'}
local catalog=addon.objects
local function safe(value)
  local ok,result=pcall(function()
    if type(issecretvalue)=='function' and issecretvalue(value) then return false end
    if type(value)=='table' and type(issecrettable)=='function' and issecrettable(value) then return false end
    return true
  end)
  return ok and result
end
local function integer(value,lo,hi)
  return safe(value) and type(value)=='number' and value==value and
    value%1==0 and value>=lo and value<=hi
end
local function read(fn,...)
  if not safe(fn) or type(fn)~='function' then return nil,false end
  local ok,result=pcall(fn,...)
  return ok and safe(result) and result or nil,ok
end
function catalog:Issue(code,mapID)
  self.issues[code]=(self.issues[code] or 0)+1
  self.reason='QuestieDB Object coverage incomplete: '..code
  if mapID then self.mapIssues[mapID]=true end
end
function catalog:Status()
  local issues={}
  for k,v in pairs(self.issues or {}) do issues[k]=v end
  return {state=self.state,reason=self.reason,limited=true,issues=issues,
    processed=math.max(0,(self.cursor or 1)-1),total=self.ids and #self.ids or 0,
    normalizing=self.normalizer~=nil,normalizedEntries=self.normalizedEntries or 0,
    classification='exact raw name Mailbox only; other mailbox names/objects not evidenced',
    mapIssues=self.mapIssues}
end
function catalog:IsReady() return self.state=='ready' end
function catalog:Initialize()
  self.state,self.reason='unavailable','QuestieDB Forever Object data unavailable'
  self.provider,self.ids,self.areas,self.byMap=nil,nil,nil,{}
  self.cursor,self.normalizer,self.normalizedEntries=1,nil,0
  self.issues,self.mapIssues={},{}
  self.records={}
  local db=LibQuestieDB
  if not safe(db) or type(db)~='table' then return false end
  local ok,contract,message,object,source,flavor=pcall(function()
    local supported,reason=db.RequireContract(4)
    return supported,reason,db.Object,db.Support.Get('ZoneDB').private.areaIdToUiMapId,db.flavor.name
  end)
  if not ok then self.reason='QuestieDB object contract unavailable'; return false end
  if contract~=true then self.reason=type(message)=='string' and message or 'QuestieDB contract 4 required'; return false end
  if flavor~='Forever' then self.reason='QuestieDB Forever data not active'; return false end
  if not safe(object) or type(object)~='table' or
    type(object.GetAllIds)~='function' or type(object.GetRaw)~='function' or
    type(object.name)~='function' or type(object.spawns)~='function' or
    not safe(source) or type(source)~='string' or #source>250000 or
    not source:match('^%s*return%s*{') then
    self.reason='QuestieDB Object getters or ZoneDB map unavailable'; return false
  end
  local loader=loadstring or load
  if type(loader)~='function' then self.reason='ZoneDB decoder unavailable'; return false end
  local compiled
  if type(setfenv)=='function' then
    compiled=read(loader,source)
    if compiled and not pcall(setfenv,compiled,{}) then compiled=nil end
  else compiled=read(loader,source,'ZoneDB','t',{}) end
  local areas=compiled and read(compiled)
  if type(areas)~='table' or not safe(areas) or getmetatable(areas) then
    self.reason='ZoneDB area mapping invalid'; return false
  end
  local ids=read(object.GetAllIds)
  if type(ids)~='table' or not safe(ids) or getmetatable(ids) then
    self.reason='QuestieDB Object IDs unavailable'; return false
  end
  self.provider,self.areas,self.ids=object,areas,{}
  self.state='indexing'
  self.reason='Only exact raw-name Mailbox objects are classified; provider coverage is partial'
  self.normalizer=coroutine.create(function()
    local count=0
    local seen={}
    for key,id in next,ids do
      if self.budget==0 then coroutine.yield() end
      self.budget=self.budget-1
      self.normalizedEntries=self.normalizedEntries+1
      count=count+1
      if count>100000 then self:Issue('object-ids-cap'); break end
      if not integer(key,1,2147483647) or not integer(id,1,2147483647) then
        self:Issue('object-ids-invalid')
      elseif seen[id] then self:Issue('object-ids-duplicate')
      else seen[id]=true; self.ids[#self.ids+1]=id end
    end
  end)
  return true
end
function catalog:Step(batch)
  if self.state~='indexing' then return self:IsReady() end
  batch=integer(batch,1,200) and batch or 80
  if self.normalizer then
    self.budget=batch
    local ok=coroutine.resume(self.normalizer)
    if not ok then
      self.state,self.reason='unavailable','QuestieDB Object ID normalization failed'
      self.normalizer=nil
      return false
    end
    if coroutine.status(self.normalizer)=='dead' then self.normalizer=nil end
    return false
  end
  local last=math.min(#self.ids,self.cursor+batch-1)
  for i=self.cursor,last do
    local id=self.ids[i]
    local name,ok=read(self.provider.GetRaw,id,'name')
    if not ok then self:Issue('object-raw-name-read')
    elseif name=='Mailbox' then
      local spawns,spawnOK=read(self.provider.spawns,id)
      if not spawnOK or (spawns~=nil and (type(spawns)~='table' or
          not safe(spawns) or getmetatable(spawns))) then
        self:Issue('object-spawns-read')
      elseif type(spawns)=='table' then
        local count=0
        local indexed=pcall(function()
          for area,points in next,spawns do
            count=count+1
            if count>2000 then self:Issue('object-areas-cap'); break end
            local mapID=self.areas[area]
            if not integer(mapID,1,10000000) then self:Issue('unmapped-area')
            elseif type(points)~='table' or not safe(points) or getmetatable(points) then
              self:Issue('object-points-read',mapID)
            else
              local bucket=self.byMap[mapID] or {}
              bucket[#bucket+1]={id=id,area=area}
              self.byMap[mapID]=bucket
            end
          end
        end)
        if not indexed then self:Issue('object-areas-read') end
      else self:Issue('missing-spawns') end
    end
  end
  self.cursor=last+1
  if self.cursor>#self.ids then self.state='ready'; return true end
  return false
end
local function copies(records)
  local result={}
  for _,record in ipairs(records) do
    local copy={}
    for key,value in pairs(record) do copy[key]=value end
    result[#result+1]=copy
  end
  return result
end
function catalog:LocationsOnMap(mapID,wanted)
  if not self:IsReady() or not integer(mapID,1,10000000) or
    (wanted and (type(wanted)~='string' or wanted:lower()~='mailbox')) then return {} end
  if self.records[mapID] then return copies(self.records[mapID]) end
  local records={}
  for _,entry in ipairs(self.byMap[mapID] or {}) do
    if #records>=10000 then self:Issue('object-record-cap',mapID); break end
    local name=read(self.provider.name,entry.id)
    local spawns=read(self.provider.spawns,entry.id)
    local points=type(spawns)=='table' and safe(spawns) and rawget(spawns,entry.area)
    if type(points)~='table' or not safe(points) or getmetatable(points) then
      self:Issue('object-map-read',mapID)
    else
      local count=0
      local ok=pcall(function()
        for key,point in next,points do
          count=count+1
          if count>10000 or #records>=10000 then self:Issue('object-record-cap',mapID); break end
          local x,y,phase
          if type(point)=='table' and safe(point) and not getmetatable(point) then
            x,y,phase=rawget(point,1),rawget(point,2),rawget(point,3)
          end
          if integer(key,1,2147483647) and safe(x) and safe(y) and
            type(x)=='number' and type(y)=='number' and x==x and y==y and
            x>=0 and x<=100 and y>=0 and y<=100 then
            records[#records+1]={id='object-'..entry.id..'-'..entry.area..'-'..key,
              objectID=entry.id,name=type(name)=='string' and name or 'Mailbox',
              category='Mailbox',mapID=mapID,x=x/100,y=y/100,
              source='questiedb-forever',precision='candidate-spawn',
              phaseUnverified=phase~=nil}
          else self:Issue('invalid-coordinate',mapID) end
        end
      end)
      if not ok then self:Issue('object-map-read',mapID) end
    end
  end
  table.sort(records,function(a,b) return a.id<b.id end)
  self.records[mapID]=records
  return copies(records)
end
