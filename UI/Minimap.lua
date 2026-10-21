-- Passive, unprotected minimap control. Wire minimap:Attach() after db initialization.
local _, addon = ...
addon.minimap = {}
local control = addon.minimap
local DEFAULT_ANGLE = 45
local ICON = "Interface\\AddOns\\ErrandMaster\\Textures\\PackLogo.blp"
local TARGET_ICON = "Interface\\AddOns\\ErrandMaster\\Textures\\PackWaypoint.blp"
local MARKER_CORNER = 11 * math.sqrt(2)
local RIM_CLEARANCE = 18 * math.sqrt(2) + 3

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

local function hideTarget(self)
  if self.targetMarker then self.targetMarker:Hide() end
end

-- Reuse the selected stop, but measure against the live player position.
-- Unknown projection, scale, or rotation hides the pin rather than guessing.
function control:RefreshTarget(target, mapID, px, py, worldW, worldH)
  local ok, id, x, y, key = pcall(function() return target.mapID,target.x,target.y,target.id end)
  if not ok or not plain(key) or
      (type(key)~="string" and type(key)~="number") or
      not number(id,1,10000000) or id%1~=0 or
      not number(mapID,1,10000000) or
      not number(x,0,1) or not number(y,0,1) or
      not number(px,0,1) or not number(py,0,1) or
      not number(worldW,1,10000000) or not number(worldH,1,10000000) then
    self.targetPosition=nil
    hideTarget(self)
    return false
  end
  local east,north=(x-px)*worldW,(py-y)*worldH
  if id~=mapID then
    local projected,a,an,aw,b,bn,bw=pcall(function()
      local ai,ax,ay=addon.navigation:WorldPosition(mapID,px,py)
      local bi,bx,by=addon.navigation:WorldPosition(id,x,y)
      return ai,ax,ay,bi,bx,by
    end)
    if not projected or not number(a,0,10000000) or not number(b,0,10000000) or a~=b or
        not number(an,-100000000,100000000) or not number(aw,-100000000,100000000) or
        not number(bn,-100000000,100000000) or not number(bw,-100000000,100000000) then
      self.targetPosition=nil;hideTarget(self);return false
    end
    east,north=aw-bw,bn-an
  end
  self.targetPosition={mapID=mapID, dx=east, dy=north}
  return self:UpdateTargetGeometry()
end

function control:UpdateTargetGeometry()
  local position=self.targetPosition
  if not position then hideTarget(self); return false end
  local ok,map,radius,mapID,create=pcall(function()
    return Minimap,C_Minimap.GetViewRadius(),C_Minimap.GetUiMapID(),CreateFrame
  end)
  if not ok or not plain(map) or not map or not number(radius,1,100000) or
      not number(mapID,1,10000000) or mapID~=position.mapID or
      not plain(create) or type(create)~="function" then
    hideTarget(self); return false
  end
  local sized,w,h=pcall(function() return map:GetWidth(),map:GetHeight() end)
  if not sized or not number(w,1,10000) or not number(h,1,10000) or
      math.min(w,h)<=2*MARKER_CORNER+4 then
    hideTarget(self); return false
  end
  local rotateOK,rotation=pcall(GetCVar,"rotateMinimap")
  if not rotateOK or not plain(rotation) or (rotation~="0" and rotation~="1") then
    hideTarget(self); return false
  end
  local east,north=position.dx,position.dy
  if rotation=="1" then
    local facingOK, facing=pcall(GetPlayerFacing)
    if not facingOK or not number(facing,0,2*math.pi) then
      hideTarget(self); return false
    end
    east,north=east*math.cos(facing)+north*math.sin(facing),
      north*math.cos(facing)-east*math.sin(facing)
  end
  local length=math.sqrt(east*east+north*north)
  local offscreen=length>radius+.000001
  local bearing
  if offscreen then
    bearing=math.acos(math.max(-1,math.min(1,north/length)))
    if east>0 then bearing=-bearing end
    east,north=east*radius/length,north*radius/length
  end
  local marker=self.targetMarker
  if not marker then
    local created,item=pcall(function()
      local f=create("Frame",nil,map)
      f:SetSize(22,22)
      f:EnableMouse(false)
      f:SetFrameLevel(map:GetFrameLevel()+8)
      local glow=f:CreateTexture(nil,"BACKGROUND")
      glow:SetSize(32,32)
      glow:SetPoint("CENTER",f,"CENTER")
      glow:SetTexture("Interface\\AddOns\\ErrandMaster\\Textures\\DestinationButtonGlow.blp")
      glow:SetBlendMode("ADD")
      glow:SetVertexColor(1,.82,.4)
      glow:SetAlpha(.9)
      f.emGlow=glow
      local icon=f:CreateTexture(nil,"OVERLAY")
      icon:SetAllPoints(f)
      icon:SetTexture(TARGET_ICON)
      f.icon=icon
      return f
    end)
    if not created or not item then return false end
    marker=item;self.targetMarker=marker
  end
  local placed=pcall(function()
    marker.offscreen=offscreen
    marker.icon:SetTexture(offscreen and 'Interface\\MINIMAP\\MinimapArrow' or TARGET_ICON)
    if type(marker.icon.SetRotation)=='function' then marker.icon:SetRotation(bearing or 0)
    elseif offscreen then error('bearing rotation unavailable') end
    -- A rotated square still needs corner clearance; keep the whole marker in
    -- the inscribed circle, rather than just its center inside the map.
    local x,y=east*w/(2*radius),north*h/(2*radius)
    local limit=math.min(w,h)/2-MARKER_CORNER-2
    local distance=math.sqrt(x*x+y*y)
    if distance>limit then x,y=x*limit/distance,y*limit/distance end
    marker:ClearAllPoints()
    marker:SetPoint("CENTER",map,"CENTER",x,y)
  end)
  if not placed then hideTarget(self);return false end
  marker:Show()
  return true
end

function control:RefreshFromCachedPlan()
  if type(addon.CachedPlan)~="function" or type(addon.ActiveTarget)~="function" then
    return false
  end
  local ok,ordered,deferred,map,x,y=pcall(addon.CachedPlan,addon)
  if not ok or not plain(ordered) or type(ordered)~="table" or
      not plain(deferred) or type(deferred)~="table" then
    return self:RefreshTarget(nil)
  end
  local chosen,target=pcall(addon.ActiveTarget,addon,ordered,deferred)
  if not chosen or not target or not plain(target) then return self:RefreshTarget(nil) end
  if type(addon.Position)=='function' then
    local positioned,currentMap,currentX,currentY=pcall(addon.Position,addon)
    if not positioned or not number(currentMap,1,10000000) or
        not number(currentX,0,1) or not number(currentY,0,1) then
      return self:RefreshTarget(nil)
    end
    map,x,y=currentMap,currentX,currentY
  end
  local size=self.worldSize
  if not size or size.map~=map then
    if type(addon.MapWorldSize)~="function" then return self:RefreshTarget(nil) end
    local sized,width,height=pcall(addon.MapWorldSize,addon,map)
    if not sized or not number(width,1,10000000) or
        not number(height,1,10000000) then return self:RefreshTarget(nil) end
    size={map=map,width=width,height=height}
    self.worldSize=size
  end
  return self:RefreshTarget(target,map,x,y,size.width,size.height)
end

local function settings()
  local ok, value = pcall(function() return addon.db.data.settings end)
  if ok and plain(value) and type(value) == "table" then return value end
end

local function angle()
  local data = settings()
  local ok, value = pcall(function() return data and data.minimapAngle end)
  if ok and number(value, 0, 360) then return value end
  return DEFAULT_ANGLE
end

local function radii(button,map)
  local ok,width,height,mapScale,buttonScale=pcall(function()
    return map:GetWidth(),map:GetHeight(),map:GetEffectiveScale(),button:GetEffectiveScale()
  end)
  if not ok or not number(width,1,10000) or not number(height,1,10000) or
      not number(mapScale,.001,100) or not number(buttonScale,.001,100) then return end
  -- Offset units belong to the UIParent-owned button, not its minimap anchor.
  local ratio=mapScale/buttonScale
  -- The launcher sits outside the visible rim including its square corners.
  return width*ratio/2+RIM_CLEARANCE,height*ratio/2+RIM_CLEARANCE
end

local function place(button, map, degrees)
  local rx,ry = radii(button,map)
  if not rx then return false end
  local radians = math.rad(degrees)
  local x, y = rx * math.cos(radians), ry * math.sin(radians)
  if button.emRimX==x and button.emRimY==y then return true end
  local ok = pcall(function()
    button:ClearAllPoints()
    button:SetPoint("CENTER", map, "CENTER", x, y)
  end)
  if ok then button.emRimX,button.emRimY=x,y end
  return ok
end

local function cursorAngle(map)
  local ok, getCursor = pcall(function() return GetCursorPosition end)
  if not ok or not plain(getCursor) or type(getCursor) ~= "function" then return end
  local valid, x, y = pcall(getCursor)
  if not valid or not number(x, -1000000, 1000000) or not number(y, -1000000, 1000000) then return end
  local centered, mx, my, scale = pcall(function()
    local centerX, centerY = map:GetCenter()
    return centerX, centerY, map:GetEffectiveScale()
  end)
  if not centered or not number(mx, -1000000, 1000000) or
    not number(my, -1000000, 1000000) or not number(scale, .001, 100) then return end
  local dx, dy = x / scale - mx, y / scale - my
  local length = math.sqrt(dx * dx + dy * dy)
  if not number(length, .001, 2000000) then return end
  local degrees = math.deg(math.acos(math.max(-1, math.min(1, dx / length))))
  if dy < 0 then degrees = 360 - degrees end
  return degrees
end

local function completeAttachment(self, map)
  local item = self.pendingButton
  if not item or not place(item, map, angle()) then return false end
  item:SetAlpha(1)
  item:EnableMouse(true)
  self.button = item
  self.pendingButton = nil
  return true
end

function control:Attach()
  if self.button then return true end
  local ok, map, create = pcall(function() return Minimap, CreateFrame end)
  if not ok or not plain(map) or not map or not plain(create) or type(create) ~= "function" then return false end
  if self.pendingButton then return completeAttachment(self, map) end
  local ready, button = pcall(function()
    local item = create("Button", nil, UIParent) -- avoid Minimap clipping and map-child strata
    -- An unanchored button must still receive OnUpdate, but must not draw or accept clicks.
    item:SetAlpha(0)
    item:EnableMouse(false)
    item:SetSize(36, 36)
    item:SetFrameStrata("FULLSCREEN_DIALOG")
    item:SetFrameLevel(map:GetFrameLevel() + 10)
    local glow=item:CreateTexture(nil,"BACKGROUND")
    glow:SetSize(54,54)
    glow:SetPoint("CENTER",item,"CENTER")
    glow:SetTexture("Interface\\AddOns\\ErrandMaster\\Textures\\DestinationButtonGlow.blp")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1,.82,.4)
    glow:SetAlpha(.9)
    item.emGlow=glow
    local icon = item:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("CENTER", item, "CENTER")
    icon:SetTexture(ICON)
    item:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    item:RegisterForDrag("LeftButton")
    item:SetScript("OnMouseDown", function()
      -- If dragging did not generate a release click, do not swallow the next click.
      self.suppressClick = nil
    end)
    item:SetScript("OnClick", function(_, mouse)
      if self.suppressClick then self.suppressClick = nil; return end
      local target, method
      if mouse == "LeftButton" then target, method = addon.radial, "Open"
      elseif mouse == "RightButton" then target, method = addon.destinations, "Toggle"
      elseif mouse == "MiddleButton" then target, method = addon.addonSettings, "Open" end
      local accessible, callback = pcall(function() return target and target[method] end)
      if accessible and plain(callback) and type(callback) == "function" then
        pcall(callback, target)
      end
    end)
    item:SetScript("OnDragStart", function()
      self.dragging = true
      self.moved = nil
    end)
    local elapsed=0
    item:SetScript("OnUpdate", function(_,dt)
      if not self.dragging then
        elapsed=elapsed+(number(dt,0,10) and dt or .2)
        if elapsed>=.2 then
          elapsed=0
          if self.pendingButton==item then self:Attach() else place(item,map,angle()) end
          self:RefreshFromCachedPlan()
        end
        return
      end
      local degrees = cursorAngle(map)
      if degrees and place(item, map, degrees) then
        self.dragAngle = degrees
        self.moved = true
      end
    end)
    item:SetScript("OnDragStop", function()
      if not self.dragging then return end
      self.dragging = nil
      if not self.moved then return end
      self.suppressClick = true
      self.moved = nil
      local data = settings()
      if data and number(self.dragAngle, 0, 360) then
        pcall(function() data.minimapAngle = self.dragAngle end)
      end
    end)
    return item
  end)
  if not ready or not button then return false end
  self.pendingButton = button
  return completeAttachment(self, map)
end
