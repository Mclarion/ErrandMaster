-- Opt-in observations of actual ground movement, stored per character.
local _, addon = ...
addon.trails = {nodes={}, edges={}}
local trails = addon.trails
function trails:Bind()
  self.bucket, self.character, self.last, self.pendingClear = nil, nil, nil, nil
  self.nodes, self.edges = {}, {} -- Never keep evidence from a prior character on failure.
  if not addon.db or not addon.db.TrailBucket then return false end
  local ok, bucket = pcall(addon.db.TrailBucket, addon.db)
  if not ok or type(bucket) ~= "table" or type(bucket.nodes) ~= "table" or
      type(bucket.edges) ~= "table" then return false end
  self.nodes, self.edges = bucket.nodes, bucket.edges
  self.bucket, self.character = bucket, addon.db.character
  self.last = nil -- Never bridge a reload/log-in as though movement was continuous.
  self.pendingClear = nil
  return true
end
function trails:IsEnabled()
  return self.bucket and self.bucket.enabled == true and
    self.character == addon.db.character or false
end
local function plain(value)
  local ok, safe = pcall(function()
    if type(issecretvalue) == "function" and issecretvalue(value) then return false end
    if type(value) == "table" and type(issecrettable) == "function" and issecrettable(value) then return false end
    return true
  end)
  return ok and safe
end
local function number(value, low, high)
  return plain(value) and type(value) == "number" and value == value and
    value >= low and value <= high
end
local function integer(value, low, high)
  return number(value, low, high) and value % 1 == 0
end
local function field(value, key)
  if not plain(value) or type(value) ~= "table" then return end
  local ok, result = pcall(function() return value[key] end)
  if ok and plain(result) then return result end
end
local function method(value, key)
  local result = field(value, key)
  if type(result) == "function" then return result end
end
local function call(fn, ...)
  if not plain(fn) or type(fn) ~= "function" then return end
  local ok, value = pcall(fn, ...)
  if ok and plain(value) then return value end
end
local function clean(value)
  if not plain(value) or type(value) ~= "table" then return end
  local ok, result = pcall(function()
    return {time=value.time,uiMapID=value.uiMapID,worldMapID=value.worldMapID,
      floor=value.floor,x=value.x,y=value.y,wx=value.wx,wy=value.wy,wz=value.wz,
      mode=value.mode,level=value.level,minLevel=value.minLevel}
  end)
  if not ok then return end
  if not number(result.time, 0, 100000000) or
      not integer(result.uiMapID, 1, 10000000) or
      not integer(result.worldMapID, 1, 10000000) or
      not integer(result.floor, 0, 50) or
      not number(result.x, 0, 1) or not number(result.y, 0, 1) or
      not number(result.wx, -10000000, 10000000) or
      not number(result.wy, -10000000, 10000000) or
      not number(result.wz, -10000000, 10000000) or
      not integer(result.level, 1, 100) or not plain(result.mode) or
      result.mode ~= "ground" then return end
  if not plain(result.minLevel) or
      (result.minLevel ~= nil and not integer(result.minLevel, 1, 100)) then return end
  for _, fieldName in ipairs({"uiMapID","worldMapID","floor","mode","level"}) do
    if not plain(result[fieldName]) then return end
  end
  return result
end

function trails:SetEnabled(enabled)
  if type(enabled) ~= "boolean" or not plain(enabled) or
      not addon.db or not addon.db.data then return false end
  if not self.bucket or self.character ~= addon.db.character then
    if not self:Bind() then return false end
  end
  if enabled and (#self.nodes >= 400 or #self.edges >= 1200) then return false end
  self.bucket.enabled = enabled
  self.last = nil
  self.pendingClear = nil
  return true
end
function trails:Status()
  if not self.bucket or self.character ~= addon.db.character then return 0, 0, false end
  return #self.nodes, #self.edges, self:IsEnabled()
end
function trails:Clear()
  if not self.bucket or self.character ~= addon.db.character then return false end
  for key in pairs(self.edges) do self.edges[key] = nil end
  for key in pairs(self.nodes) do self.nodes[key] = nil end
  self.bucket.enabled, self.last, self.pendingClear = false, nil, nil
  return true
end
function trails:Observe(input)
  if not self:IsEnabled() then
    self.last = nil; return false
  end
  local sample = clean(input)
  if not sample then self.last = nil; return false end
  if #self.nodes >= 400 or #self.edges >= 1200 then
    self.bucket.enabled, self.last = false, nil
    if type(addon.Print) == "function" then
      pcall(addon.Print, addon,
        "Trail storage full; recording stopped. Use /em trails status or /em trails clear to review/reset.")
    end
    return false
  end
  local prior = self.last
  if prior then
    local dx, dy, dz = sample.wx-prior.wx, sample.wy-prior.wy, sample.wz-prior.wz
    local yards = math.sqrt(dx*dx + dy*dy + dz*dz)
    local duration = sample.time - prior.time
    if yards <= .75 and duration > 0 then return false end
    local continuous = sample.uiMapID == prior.uiMapID and
      sample.worldMapID == prior.worldMapID and sample.floor == prior.floor and
      duration >= .2 and duration <= 8 and
      yards <= math.min(80, 25*duration+5) and math.abs(dz) <= 6 and
      math.abs(sample.x-prior.x) <= .03 and math.abs(sample.y-prior.y) <= .03
    local node = {id="trail-"..(#self.nodes+1),uiMapID=sample.uiMapID,
      worldMapID=sample.worldMapID,floor=sample.floor,x=sample.x,y=sample.y,
      wx=sample.wx,wy=sample.wy,wz=sample.wz,source="observed-walk"}
    self.nodes[#self.nodes+1] = node
    if continuous then
      self.edges[#self.edges+1] = {a=prior.id,b=node.id,yards=yards,
        source="observed-walk",minLevel=sample.minLevel}
    end
    sample.id = node.id
  else
    local node = {id="trail-"..(#self.nodes+1),uiMapID=sample.uiMapID,
      worldMapID=sample.worldMapID,floor=sample.floor,x=sample.x,y=sample.y,
      wx=sample.wx,wy=sample.wy,wz=sample.wz,source="observed-walk"}
    self.nodes[#self.nodes+1] = node
    sample.id = node.id
  end
  self.last = sample
  return true
end
function trails:NativeSample()
  if not plain(InCombatLockdown) or type(InCombatLockdown) ~= "function" then return end
  local combatOK, combat = pcall(InCombatLockdown)
  if not combatOK or not plain(combat) or type(combat) ~= "boolean" or combat then return end
  local getMap = method(C_Map, "GetBestMapForUnit")
  local getPos = method(C_Map, "GetPlayerMapPosition")
  if not getMap or not getPos then return end
  local mapID = call(getMap, "player")
  if not integer(mapID, 1, 10000000) then return end
  local position = call(getPos, mapID, "player")
  local getXY = method(position, "GetXY")
  if not getXY then return end
  local posOK, x, y = pcall(getXY, position)
  if not posOK or not number(x, 0, 1) or not number(y, 0, 1) then return end
  local worldOK, wx, wy, wz, worldMapID = pcall(function() return UnitPosition("player") end)
  if not worldOK or not number(wx, -10000000, 10000000) or
      not number(wy, -10000000, 10000000) or
      not number(wz, -10000000, 10000000) or
      not integer(worldMapID, 1, 10000000) then return end
  local flags = {IsFlying, UnitOnTaxi, IsSwimming, UnitInVehicle}
  for i=1,4 do
    local check = flags[i]
    if not plain(check) or type(check) ~= "function" then return end
    local ok, state = pcall(check, "player")
    if not ok or not plain(state) or type(state) ~= "boolean" or state then return end
  end
  local level = call(UnitLevel, "player")
  local speed = call(GetUnitSpeed, "player")
  local now = call(GetTime)
  if not integer(level, 1, 100) or not number(speed, 0, 40) or
      not number(now, 0, 100000000) then return end
  local minLevel
  local getLevels = method(C_Map, "GetMapLevels")
  if getLevels then
    local suggested = call(getLevels, mapID)
    if integer(suggested, 1, 100) then minLevel = suggested end
  end
  return {time=now,uiMapID=mapID,worldMapID=worldMapID,floor=0,
    x=x,y=y,wx=wx,wy=wy,wz=wz,mode="ground",level=level,minLevel=minLevel}
end
function trails:ObserveNative()
  local sample = self:NativeSample()
  if not sample then self.last = nil; return false end
  return self:Observe(sample)
end
