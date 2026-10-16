-- Lua 5.1 standalone minimap-button contract; run via lupa.lua51 or lua5.1.
local addon = {db={data={settings={}}}, radial={}, destinations={}}
local opened, listed = 0, 0
function addon.radial:ShowSettings() opened = opened + 1 end
function addon.destinations:Toggle() listed = listed + 1 end
local frames = {}
local function frame(parent)
  local f = {parent=parent, scripts={}, x=500, y=500, width=140, height=140}
  function f:SetSize(w,h) self.width,self.height=w,h end
  function f:GetWidth() return self.width end
  function f:GetHeight() return self.height end
  function f:GetCenter() return self.x,self.y end
  function f:GetEffectiveScale() return 1 end
  function f:SetPoint(...) self.point={...} end
  function f:ClearAllPoints() self.point=nil end
  function f:SetScript(name, fn) self.scripts[name]=fn end
  function f:RegisterForClicks(...) self.clicks={...} end
  function f:RegisterForDrag(...) self.drags={...} end
  function f:CreateTexture()
    local t={}
    function t:SetAllPoints(point) self.all=point end
    function t:SetTexture(path) self.path=path end
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
local cx,cy=600,600
GetCursorPosition = function() return cx,cy end
local source=assert(loadfile('UI/Minimap.lua'))
source('ErrandMaster', addon)
assert(addon.minimap:Attach()==true, 'button attaches after initialization')
local button=addon.minimap.button
assert(button and button.parent==Minimap and button.kind=='Button', 'own minimap child')
assert(button.clicks[1]=='LeftButtonUp' and button.clicks[2]=='RightButtonUp')
button.scripts.OnClick(button,'LeftButton')
button.scripts.OnClick(button,'RightButton')
assert(opened==1 and listed==1, 'left opens settings; right toggles destinations')
assert(addon.minimap:Attach()==true and addon.minimap.button==button and #frames==1,
  'attachment is idempotent and leaves other minimap children alone')
-- Drag around the rim, save a plain finite angle, and suppress the release click.
local settings=addon.db.data.settings
assert(button.drags[1]=='LeftButton', 'only the left button drags')
button.scripts.OnDragStart(button)
cx,cy=500,580
button.scripts.OnUpdate(button)
assert(math.abs(button.point[4])<.001 and button.point[5]>0, 'drag follows cursor around minimap')
button.scripts.OnDragStop(button)
assert(type(settings.minimapAngle)=='number' and settings.minimapAngle==90,
  'drag persists a finite angle into settings')
button.scripts.OnClick(button,'LeftButton')
assert(opened==1, 'drag release is not a settings click')
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
