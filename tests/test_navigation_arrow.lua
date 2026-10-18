local addon={destinations={},navigation={}}
local function frame(parent)
  local result={parent=parent,shown=false,scripts={}}
  function result:SetSize(w,h) self.width,self.height=w,h end
  function result:SetPoint(...) self.point={...} end
  function result:CreateTexture(_,layer) local t=frame(self); t.layer=layer; return t end
  function result:SetBlendMode(value) self.blend=value end
  function result:SetVertexColor(...) self.color={...} end
  function result:SetAlpha(value) self.alpha=value end
  function result:CreateFontString() return frame(self) end
  function result:SetTexture(value) self.texture=value end
  function result:SetText(value) self.text=value end
  function result:SetRotation(value) self.rotation=value end
  function result:Show() self.shown=true end
  function result:Hide() self.shown=false end
  function result:SetScript(event,handler) self.scripts[event]=handler end
  return result
end
local anchor=frame()
addon.destinations.GetNavigationAnchor=function() return anchor end
CreateFrame=function(_,_,parent) return frame(parent) end
assert(loadfile('UI/NavigationArrow.lua'))('ErrandMaster',addon)
local arrow=addon.navigationArrow
local target={id='em-1',mapID=1,x=.3,y=.4}
addon.navigation.target=target
addon.navigation.Measure=function(_,item)
  assert(item==target)
  return {distance=12.49,angle=-math.pi/2}
end
assert(arrow:Refresh() and arrow.frame.parent==anchor and arrow.icon.shown and
  arrow.icon.rotation==-math.pi/2 and arrow.caption.text=='12 yd direct')
assert(arrow.glow and arrow.glow.layer=='BACKGROUND' and arrow.glow.blend=='ADD' and
  arrow.glow.shown and arrow.icon.color==nil,'arrow backlight sits below untinted direction icon')
addon.navigation.Guidance=function() return {distance=37.2,angle=math.pi/2,
  targetDistance=200,mode='observed',routeStatus='partial-end'} end
assert(arrow:Refresh() and arrow.icon.rotation==math.pi/2 and
  arrow.caption.text=='200 yd to target (direct)\n37 yd to waypoint; end unknown')
addon.navigation.Guidance=function() return {distance=12,angle=0,
  mode='direct-unknown'} end
assert(arrow:Refresh() and arrow.caption.text=='12 yd DIRECT; route unknown')
addon.navigation.Guidance=nil
addon.navigation.Measure=function() return {distance=nil,angle=nil} end
arrow.frame.scripts.OnUpdate(nil,.11)
assert(not arrow.icon.shown and arrow.caption.text=='Distance unknown',
  'unknown native data never displays a direction or fabricated yards')
assert(not arrow.glow.shown,'unknown direction must not leave a glowing false arrow')
addon.navigation.Measure=function() return nil end
arrow:Refresh()
assert(not arrow.icon.shown and arrow.caption.text=='Direction unknown; route unknown')
addon.navigation.target=nil
assert(not arrow:Refresh() and not arrow.frame.shown,'no active target hides arrow')
addon.navigation.target=target; addon.navigation.paused=true
assert(not arrow:Refresh() and not arrow.frame.shown,'explicit pause hides arrow')
-- Exercise the actual native projection and the actual frame timer together:
-- a one-yard change must display before any 10-yard route replan.
assert(loadfile('Routing/Navigation.lua'))('ErrandMaster',addon)
local px=.5
addon.Position=function() return 10,px,.5 end
addon.MapWorldSize=function() return nil end
CreateVector2D=function(x,y) return {GetXY=function() return x,y end} end
C_Map={GetWorldPosFromMapPos=function(map,vector)
  local x,y=vector:GetXY()
  return 0,CreateVector2D(5000-y*500,2000-x*1000)
end}
GetPlayerFacing=function() return 0 end
addon.navigation.target={mapID=10,x=.6,y=.5}
arrow.frame.scripts.OnUpdate(nil,.1)
assert(arrow.caption.text=='100 yd DIRECT; route unknown' and arrow.icon.shown)
px=.501
arrow.frame.scripts.OnUpdate(nil,.1)
assert(arrow.caption.text=='99 yd DIRECT; route unknown',
  'actual native projection updates displayed yard distance independently of replanning')
print('navigation arrow tests passed')
