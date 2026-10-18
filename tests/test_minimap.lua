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
  button.level>Minimap.level and button.width>=36 and button.icon.width>=30,
  'button sits above the map, with a usable hitbox and icon')
assert(button.icon.path:find('Textures\\PackLogo.blp',1,true),
  'the minimap button uses the cropped user-supplied compass')
assert(button.emGlow and button.emGlow.layer=='BACKGROUND' and button.emGlow.blend=='ADD' and
  button.emGlow.width>button.icon.width and button.icon.color==nil,
  'minimap art remains untinted above an independent soft backlight')
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
assert(math.abs(button.point[4])<.001 and math.abs(button.point[5]-94)<.001,
  'idle resize reattaches at saved angle using map-to-button effective scale')
local placements=button.placements
button.scripts.OnUpdate(button,.21)
assert(button.placements==placements,'unchanged geometry does not repeatedly reanchor')
Minimap.scale=1.2
button.scripts.OnUpdate(button,.21)
assert(math.abs(button.point[5]-136)<.001,'map scaling moves button out to physical rim')
button.scale=.75
button.scripts.OnUpdate(button,.21)
assert(math.abs(button.point[5]-178)<.001,'different UIParent/button scale is compensated')
Minimap.width=0
button.scripts.OnUpdate(button,.21)
assert(math.abs(button.point[5]-178)<.001,'transient invalid geometry preserves last safe position')
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
Minimap=nil
addon.minimap.button=nil
assert(addon.minimap:Attach()==false, 'missing minimap is harmless')
assert(replaced.parent~=nil, 'existing minimap children were never removed')
print('minimap click, drag, persistence and fallback: pass')
