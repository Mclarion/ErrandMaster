-- Optional Waypoint UI session bridge. Never touch its stored pins or global destination.
local _, addon = ...
addon.waypointUI = {}
local bridge = addon.waypointUI
local FLAG = 'ErrandMaster'
local function valid(n, low, high)
  return type(n)=='number' and n==n and n>=low and n<=high
end
local function readable(value)
  local ok, allowed=pcall(function()
    return not (type(issecretvalue)=='function' and issecretvalue(value)) and
      not (type(value)=='table' and type(issecrettable)=='function' and issecrettable(value))
  end)
  return ok and allowed
end
local function provider()
  local ok, navigation=pcall(function() return WaypointUIAPI and WaypointUIAPI.Navigation end)
  if not ok or not readable(navigation) or type(navigation)~='table' then return nil end
  local validAPI=pcall(function()
    assert(type(navigation.GetUserNavigation)=='function' and
      type(navigation.NewUserNavigation)=='function' and
      type(navigation.ClearUserNavigation)=='function')
    assert(readable(navigation.GetUserNavigation) and
      readable(navigation.NewUserNavigation) and readable(navigation.ClearUserNavigation))
  end)
  return validAPI and navigation or nil
end
local function worldTracked(api)
  if type(api.IsUserNavigationTracked)~='function' then return nil end
  local ok,tracked=pcall(api.IsUserNavigationTracked)
  if not ok or not readable(tracked) or type(tracked)~='boolean' then return nil end
  return tracked
end
local function snapshot(item)
  if not readable(item) or type(item)~='table' then return nil end
  local ok, map,x,y,name,id,transitForId=pcall(function()
    return item.mapID,item.x,item.y,item.name,item.id,item.transitForId
  end)
  if not ok or not readable(map) or not readable(x) or not readable(y) or
    not valid(map,1,1000000) or map%1~=0 or not valid(x,0,1) or
    not valid(y,0,1) then return nil end
  if not readable(name) or type(name)~='string' or #name>100 or
    name:find('[%c|]') or name=='' then name='ErrandMaster target' end
  if not readable(id) or not readable(transitForId) then return nil end
  return {mapID=map,x=x,y=y,name=name,id=id,transitForId=transitForId}
end
local function matches(session, target)
  if not target or not readable(session) or type(session)~='table' then return false end
  local ok,flag,map,x,y,name=pcall(function()
    return session.flags,session.mapID,session.x,session.y,session.name
  end)
  return ok and readable(flag) and readable(map) and readable(x) and
    readable(y) and readable(name) and flag==FLAG and map==target.mapID and
    type(name)=='string' and name==target.name and valid(x,0,1) and
    valid(y,0,1) and math.abs(x-target.x)<.0005 and math.abs(y-target.y)<.0005
end
local function ownsNativeWaypoint(target)
  if not target then return false end
  local ok,map,x,y=pcall(function()
    local point=C_Map and C_Map.GetUserWaypoint and C_Map.GetUserWaypoint()
    return point and point.uiMapID,point and point.position and point.position.x,
      point and point.position and point.position.y
  end)
  return ok and readable(map) and readable(x) and readable(y) and
    map==target.mapID and valid(x,0,1) and valid(y,0,1) and
    math.abs(x-target.x)<.0005 and math.abs(y-target.y)<.0005
end
function bridge:Update(item, explicit)
  local api=provider()
  if not api then return false end -- Probe again on refresh for late-loaded addons.
  local ok,current=pcall(api.GetUserNavigation) -- Public API functions are dot-called.
  if not ok or (current~=nil and not readable(current)) then
    self.blocked=true; self.owned=nil; return false
  end
  if self.owned and current and not matches(current,self.owned) then
    self.blocked=true; self.owned=nil; self.recoveryAttempts=nil -- Foreign takeover.
  elseif self.owned and not current then
    self.owned=nil -- Player cleared our pin: honor the manual dismissal.
    self.blocked=true; self.recoveryAttempts=nil
  end
  local settings=addon.db and addon.db.data and addon.db.data.settings
  local enabled=settings and settings.useWaypointUI==true
  local target=enabled and snapshot(item) or nil
  if not target then
    if self.owned and current and matches(current,self.owned) then
      -- Waypoint UI clears the native pin only when preserveWaypoint is false.
      -- Do so only when it still matches our owned destination.
      local cleared,clearResult=pcall(api.ClearUserNavigation,
        not ownsNativeWaypoint(self.owned),true)
      if not cleared or clearResult==false then return false end
      local verified,remaining=pcall(api.GetUserNavigation)
      if not verified or (remaining and matches(remaining,self.owned)) then return false end
      if remaining then self.blocked=true end
      self.owned=nil
    end
    return false
  end
  if self.blocked and not explicit then return false end
  -- A native waypoint from another source is not ours to replace on refresh.
  -- Explicit ErrandMaster navigation remains a deliberate override.
  if not explicit and type(C_Map)=='table' and type(C_Map.GetUserWaypoint)=='function' then
    local nativeOK,native=pcall(C_Map.GetUserWaypoint)
    if not nativeOK or (native and not ownsNativeWaypoint(self.owned)) or
        (self.owned and not native) then
      self.blocked=true
      return false
    end
  end
  if self.owned and matches(current,target) and self.owned.id==target.id and
      self.owned.transitForId==target.transitForId then
    local tracked=worldTracked(api)
    if tracked~=false then self.recoveryAttempts=nil; return true end
    -- Session readback is not an in-world marker. Recover only our native pin;
    -- never steal a foreign waypoint after it replaces our tracked target.
    if not ownsNativeWaypoint(target) then
      self.blocked=true;self.owned=nil;return false
    end
    self.recoveryAttempts=(self.recoveryAttempts or 0)+1
    if self.recoveryAttempts>3 then return false end
  else self.recoveryAttempts=nil end
  -- Initial publication is allowed only into an empty session. A deliberate
  -- ErrandMaster selection can replace a foreign session; periodic refresh cannot.
  if current and not self.owned and not explicit then return false end
  local published,result=pcall(api.NewUserNavigation,{
    name=target.name,mapID=target.mapID,x=target.x*100,y=target.y*100,
    flags=FLAG,suppressAudio=true,stripCoordinates=true,
    -- The in-world Waypoint UI frame selects the native supertracked target;
    -- a session pin alone can be read back while the world marker stays hidden.
    syncNativeWaypoint=true,superTracked=true,
  })
  if not published or not readable(result) or not matches(result,target) then
    self.owned=nil; self.blocked=true; return false
  end
  local readOK,actual=pcall(api.GetUserNavigation)
  if not readOK or not matches(actual,target) then
    self.owned=nil; self.blocked=true; return false
  end
  self.owned=target; self.blocked=nil
  if worldTracked(api)==false then return false end
  self.recoveryAttempts=nil
  return true
end
