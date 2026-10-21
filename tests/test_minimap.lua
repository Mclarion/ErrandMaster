-- Lua 5.1 standalone minimap-button contract; run via lupa.lua51 or lua5.1.
local addon = {db={data={settings={}}}, radial={}, destinations={}, addonSettings={}}
local opened, listed, configured = 0, 0, 0
function addon.radial:Open() opened = opened + 1 end
function addon.destinations:Toggle() listed = listed + 1 end
function addon.addonSettings:Open() configured = configured + 1 end
local frames = {}
local function frame(parent)
  local f = {parent=parent, scripts={}, x=500, y=500, width=140, height=140}
  function f:SetSize(w,h) self.width,self.height=w,h end
  function f:GetWidth() return self.width end
  function f:GetHeight() return self.height end
  function f:GetCenter() return self.x,self.y end
  function f:GetEffectiveScale() return self.scale or 1 end
  function f:GetFrameLevel() return self.level or 0 end
  function f:SetFrameStrata(value)
    assert(value=='FULLSCREEN_DIALOG' or value=='HIGH', 'invalid WoW frame strata')
    self.strata=value
  end
  function f:SetFrameLevel(value) self.level=value end
  function f:SetPoint(...)
    if self.failPoint then error('temporary positioning failure') end
    self.point={...}; self.placements=(self.placements or 0)+1
  end
  function f:ClearAllPoints() self.point=nil end
  function f:SetScript(name, fn) self.scripts[name]=fn end
  function f:Show() self.shown=true end
  function f:Hide() self.shown=false end
  function f:SetAlpha(value) self.alpha=value end
  function f:EnableMouse(value) self.mouse=value end
  function f:RegisterForClicks(...) self.clicks={...} end
  function f:RegisterForDrag(...) self.drags={...} end
  function f:CreateTexture(_,layer)
    local t={layer=layer}
    function t:SetBlendMode(value) self.blend=value end
    function t:SetVertexColor(...) self.color={...} end
    function t:SetAlpha(value) self.alpha=value end
    function t:SetAllPoints(point) self.all=point end
    function t:SetSize(w,h) self.width,self.height=w,h end
    function t:SetPoint(...) self.point={...} end
    function t:SetTexture(path) self.path=path end
    function t:SetRotation(value) self.rotation=value end
    self.icon=t
    return t
  end
  return f
end
CreateFrame = function(kind, name, parent, template)
  local f=frame(parent); f.kind=kind; f.name=name; f.template=template
  frames[#frames+1]=f
  return f
end
UIParent=frame()
Minimap=frame(UIParent)
UIParent.scale=1;Minimap.scale=.8;Minimap.level=7
local cx,cy=600,600
GetCursorPosition = function() return cx,cy end
local source=assert(loadfile('UI/Minimap.lua'))
source('ErrandMaster', addon)
-- A map with no geometry at login must recover without another external Attach call.
Minimap.width=0
assert(addon.minimap:Attach()==false and addon.minimap.button==nil,
  'initial missing geometry reports unattached')
local pending=frames[1]
assert(pending and pending.alpha==0 and pending.mouse==false and pending.scripts.OnUpdate,
  'failed initial button is invisible and noninteractive while its retry callback runs')
pending.scripts.OnUpdate(pending,.21)
assert(addon.minimap.button==nil and pending.alpha==0 and pending.mouse==false and #frames==1,
  'failed retry stays invisible and noninteractive without another button')
assert(addon.minimap:Attach()==false and #frames==1,
  'manual retry while geometry is invalid reuses the pending button')
local pendingClick=pending.scripts.OnClick
local pendingUpdate=pending.scripts.OnUpdate
Minimap.width=140
pending.failPoint=true
pending.scripts.OnUpdate(pending,.21)
assert(addon.minimap.button==nil and pending.alpha==0 and pending.mouse==false and #frames==1,
  'failed SetPoint retry remains noninteractive and does not allocate another button')
assert(addon.minimap:Attach()==false and pending.scripts.OnClick==pendingClick and
  pending.scripts.OnUpdate==pendingUpdate and #frames==1,
  'failed manual retry does not replace handlers')
pending.failPoint=false
pending.scripts.OnUpdate(pending,.21)
assert(addon.minimap.button==pending and pending.alpha==1 and pending.mouse==true and pending.point[2]==Minimap,
  'later geometry automatically attaches the pending button')
assert(addon.minimap:Attach()==true and #frames==1 and pending.scripts.OnClick==pendingClick and
  pending.scripts.OnUpdate==pendingUpdate,
  'repeat attachment does not duplicate frames or handlers after recovery')
pending.scripts.OnClick(pending,'LeftButton')
assert(opened==1, 'recovered button keeps its click action')
opened=0
frames={}
source('ErrandMaster', addon)
assert(addon.minimap:Attach()==true, 'button attaches after initialization')
local button=addon.minimap.button
assert(button and button.parent==UIParent and button.kind=='Button', 'unclipped UIParent button')
assert(button.point[2]==Minimap and button.strata=='FULLSCREEN_DIALOG' and
  button.level>Minimap.level and button.width>=36 and button.icon.width>=28,
  'button sits above the map, with a usable hitbox and icon')
assert(button.icon.path:find('Textures\\PackLogo.blp',1,true),
  'the minimap button uses the cropped user-supplied compass')
assert(button.emGlow and button.emGlow.layer=='BACKGROUND' and button.emGlow.blend=='ADD' and
  button.emGlow.width>button.icon.width and button.icon.color==nil,
  'minimap art remains untinted above an independent soft backlight')
assert(button.icon.width<=button.width-8 and button.icon.height<=button.height-8 and
  button.emGlow.alpha>=.85 and button.emGlow.width>=button.width+16,
  'logo border has breathing room in the hitbox and a strong separate halo')
local rimClearance=math.sqrt(2)*button.width/2
local rimDistance=math.sqrt(button.point[4]^2+button.point[5]^2)
assert(rimDistance>Minimap.width*Minimap.scale/(2*button:GetEffectiveScale())+rimClearance,
  'whole launcher square clears minimap rim even on diagonal drags')
assert(button.clicks[1]=='LeftButtonUp' and button.clicks[2]=='RightButtonUp' and
  button.clicks[3]=='MiddleButtonUp')
button.scripts.OnClick(button,'LeftButton')
button.scripts.OnClick(button,'RightButton')
button.scripts.OnClick(button,'MiddleButton')
assert(opened==1 and listed==1 and configured==1,
  'left opens wheel, right toggles targets, middle opens addon settings')
assert(addon.minimap:Attach()==true and addon.minimap.button==button and #frames==1,
  'attachment is idempotent and leaves other minimap children alone')
-- Drag around the rim, save a plain finite angle, and suppress the release click.
local settings=addon.db.data.settings
assert(button.drags[1]=='LeftButton', 'only the left button drags')
button.scripts.OnDragStart(button)
cx,cy=400,464 -- Minimap center in physical pixels at .8 effective scale.
button.scripts.OnUpdate(button)
assert(math.abs(button.point[4])<.001 and button.point[5]>0, 'drag follows cursor around minimap')
button.scripts.OnDragStop(button)
assert(type(settings.minimapAngle)=='number' and settings.minimapAngle==90,
  'drag persists a finite angle into settings')
button.scripts.OnClick(button,'LeftButton')
assert(opened==1, 'drag release is not a wheel click')
button.scripts.OnMouseDown(button,'LeftButton')
button.scripts.OnClick(button,'LeftButton')
assert(opened==2, 'next ordinary click still works')
-- Some clients do not deliver OnClick after a drag; new mouse-down must clear suppression.
button.scripts.OnDragStart(button)
button.scripts.OnUpdate(button)
button.scripts.OnDragStop(button)
button.scripts.OnMouseDown(button,'LeftButton')
button.scripts.OnClick(button,'LeftButton')
assert(opened==3, 'a drag without release click cannot swallow a later click')
-- Restoring a saved angle does not touch any other button.
Minimap.width,Minimap.height=280,210
button.scripts.OnUpdate(button,.21)
assert(math.abs(button.point[4])<.001 and math.abs(button.point[5]-(84+36*math.sqrt(2)/2+3))<.001,
  'idle resize reattaches at saved angle using map-to-button effective scale')
local placements=button.placements
button.scripts.OnUpdate(button,.21)
assert(button.placements==placements,'unchanged geometry does not repeatedly reanchor')
Minimap.scale=1.2
button.scripts.OnUpdate(button,.21)
assert(math.abs(button.point[5]-(126+36*math.sqrt(2)/2+3))<.001,'map scaling moves button out to physical rim')
button.scale=.75
button.scripts.OnUpdate(button,.21)
assert(math.abs(button.point[5]-(168+36*math.sqrt(2)/2+3))<.001,'different UIParent/button scale is compensated')
Minimap.width=0
button.scripts.OnUpdate(button,.21)
assert(math.abs(button.point[5]-(168+36*math.sqrt(2)/2+3))<.001,'transient invalid geometry preserves last safe position')
Minimap.width,Minimap.height,Minimap.scale,button.scale=140,140,.8,1
addon.minimap.button=nil
settings.minimapAngle=180
assert(addon.minimap:Attach())
assert(addon.minimap.button.point[4]<0 and math.abs(addon.minimap.button.point[5])<.001)
local replaced=addon.minimap.button
-- Malformed persisted coordinates must fall back, never anchor an unbounded position.
addon.minimap.button=nil
settings.minimapAngle=math.huge
assert(addon.minimap:Attach() and addon.minimap.button.point[4]>0)
addon.minimap.button=nil
settings.minimapAngle='bad'
assert(addon.minimap:Attach() and addon.minimap.button.point[4]>0)
-- No saved state before database initialization: click remains available.
addon.db.data=nil
addon.minimap.button=nil
assert(addon.minimap:Attach())
button=addon.minimap.button
button.scripts.OnClick(button,'RightButton')
assert(listed==2)
button.scripts.OnDragStart(button)
button.scripts.OnDragStop(button)
-- Missing or secret native coordinates fail closed without writing.
addon.db.data={settings={}}
settings=addon.db.data.settings
GetCursorPosition=nil
button.scripts.OnDragStart(button)
button.scripts.OnUpdate(button)
button.scripts.OnDragStop(button)
assert(settings.minimapAngle==nil, 'unavailable cursor must not save')
GetCursorPosition=function() return math.huge,500 end
button.scripts.OnDragStart(button)
button.scripts.OnUpdate(button)
button.scripts.OnDragStop(button)
assert(settings.minimapAngle==nil, 'nonfinite cursor must not save')
GetCursorPosition=function() return 550,550 end
issecretvalue=function(value) return value==550 end
button.scripts.OnDragStart(button)
button.scripts.OnUpdate(button)
button.scripts.OnDragStop(button)
assert(settings.minimapAngle==nil, 'secret cursor coordinates must not save')
issecretvalue=nil
addon.radial=nil
addon.destinations=nil
button.scripts.OnClick(button,'LeftButton')
button.scripts.OnClick(button,'RightButton')
-- Active navigation is a second, non-clickable marker independent of the launcher.
C_Minimap={GetUiMapID=function() return 42 end, GetViewRadius=function() return 10 end}
GetCVar=function() return '0' end
Minimap.width,Minimap.height=140,140
addon.minimap:RefreshTarget({id='bank',name='Bank',mapID=42,x=.51,y=.5},42,.5,.5,1000,1000)
local marker=addon.minimap.targetMarker
assert(marker and marker.shown and marker.mouse==false and marker~=button and
  marker.point[2]==Minimap and marker.point[4]>0 and marker.point[4]+marker.width/2<Minimap.width/2 and
  math.abs(marker.point[5])<.001 and marker.icon.path~=button.icon.path,
  'on-map destination is scaled from authoritative minimap radius, not launcher rim')
addon.minimap:RefreshTarget({id='quest',name='Quest',mapID=43,x=.51,y=.5},42,.5,.5,1000,1000)
assert(not marker.shown, 'cross-map destination is not projected')
addon.minimap:RefreshTarget({id='bad',mapID=42,x=0/0,y=.5},42,.5,.5,1000,1000)
assert(not marker.shown, 'invalid coordinates clear prior marker')
addon.minimap:RefreshTarget({id='bank',mapID=42,x=.51,y=.5},42,.5,.5,1000,1000)
Minimap.width=280; addon.minimap:UpdateTargetGeometry()
assert(marker.shown and marker.point[4]>0 and marker.point[4]<70,
  'rectangular resize retains a square marker within the shorter map dimension')
GetCVar=function() return '1' end
GetPlayerFacing=function() return math.pi/2 end
addon.minimap:UpdateTargetGeometry()
assert(marker.shown and math.abs(marker.point[4])<.001 and
  marker.point[5]<0 and math.abs(marker.point[5])+marker.height/2<Minimap.height/2,
  'rotating minimap rotates east to bottom when facing north-to-east')
GetPlayerFacing=function() return nil end
addon.minimap:UpdateTargetGeometry()
assert(not marker.shown, 'rotation without heading fails closed')
GetCVar=function() return '0' end
C_Minimap.GetViewRadius=function() return nil end
addon.minimap:UpdateTargetGeometry()
assert(not marker.shown, 'unavailable native view radius cannot create a guessed pin')
C_Minimap.GetViewRadius=function() return 10 end
addon.minimap:RefreshTarget({id='far',mapID=42,x=.9,y=.5},42,.5,.5,1000,1000)
assert(marker.shown and marker.offscreen and marker.icon.path=='Interface\\MINIMAP\\MinimapArrow' and
  marker.point[4]<140 and marker.point[4]>0,
  'offscreen target uses a distinct rim bearing, never a false point-position pin')
assert(math.abs(marker.point[4])+marker.width/2<Minimap.width/2 and
  math.abs(marker.point[5])+marker.height/2<Minimap.height/2,
  'rim arrow square stays within the map including its rotated corners')
assert(marker.emGlow and marker.emGlow.layer=='BACKGROUND' and
  marker.emGlow.blend=='ADD' and marker.emGlow.alpha>=.85 and
  marker.icon.color==nil, 'destination pin and rim arrow keep original art over a halo')
Minimap.width,Minimap.height=40,40
addon.minimap:UpdateTargetGeometry()
assert(marker.shown and math.sqrt(marker.point[4]^2+marker.point[5]^2)+
  marker.width*math.sqrt(2)/2<=20, 'tiny map still contains the rotated arrow')
Minimap.width,Minimap.height=30,30
assert(not addon.minimap:UpdateTargetGeometry() and not marker.shown,
  'marker hides when its square cannot fit the map')
Minimap.width,Minimap.height=280,140
addon.navigation={WorldPosition=function(_,map) if map==42 then return 0,100,100 end;return 0,100,0 end}
addon.minimap:RefreshTarget({id='cross',mapID=43,x=.5,y=.5},42,.5,.5,1000,1000)
assert(marker.shown and marker.offscreen,'same-world cross-zone target has an evidenced bearing marker')
addon.navigation.WorldPosition=function(_,map) return map,100,100 end
addon.minimap:RefreshTarget({id='cross',mapID=43,x=.5,y=.5},42,.5,.5,1000,1000)
assert(not marker.shown,'different world instances cannot produce a bearing')
addon.navigation=nil
addon.minimap:RefreshTarget(nil)
assert(not marker.shown, 'no target removes destination, preserving launcher')
GetCVar=function() return '0' end
local cachedCalls=0
addon.CachedPlan=function() cachedCalls=cachedCalls+1
  return {{id='cached',mapID=42,x=.51,y=.5}}, {},42,.5,.5 end
addon.ActiveTarget=function(_,ordered) return ordered[1] end
addon.MapWorldSize=function() return 1000,1000 end
button.scripts.OnUpdate(button,.21)
assert(cachedCalls==1 and marker.shown, 'timer uses cached route snapshot, never Plan')
addon.Position=function() return 42,.505,.5 end
button.scripts.OnUpdate(button,.21)
assert(marker.shown and marker.point[4]>0 and marker.point[4]<70,
  'marker uses live position between ten-yard route replans, not the old snapshot origin')
addon.Position=function() return nil end
button.scripts.OnUpdate(button,.21)
assert(not marker.shown,'unavailable live position must not reuse stale geometry')
addon.Position=nil
addon.CachedPlan=function() cachedCalls=cachedCalls+1; return {},{},42,.5,.5 end
button.scripts.OnUpdate(button,.21)
assert(not marker.shown, 'empty cached plan removes stale destination')
Minimap=nil
addon.minimap.button=nil
assert(addon.minimap:Attach()==false, 'missing minimap is harmless')
assert(replaced.parent~=nil, 'existing minimap children were never removed')
print('minimap click, drag, persistence and fallback: pass')
