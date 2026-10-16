local addon = {}
local frames = {}
local function frame(parent)
  local f = {parent=parent, scripts={}, shown=false}
  function f:SetSize(w,h) self.width,self.height=w,h end
  function f:SetPoint(...) self.point={...} end
  function f:ClearAllPoints() self.point=nil end
  function f:SetText(text) self.text=text end
  function f:SetScript(event, fn) self.scripts[event]=fn end
  function f:Show() self.shown=true end
  function f:Hide() self.shown=false end
  function f:IsShown() return self.shown end
  function f:CreateFontString() return frame(self) end
  function f:EnableMouse(...) self.mouseEnabled={...} end
  function f:SetMovable(value) self.movable=value end
  function f:RegisterForDrag(...) self.dragButtons={...} end
  function f:SetClampedToScreen(value) self.clamped=value end
  function f:StartMoving() self.moving=true end
  function f:StopMovingOrSizing() self.moving=false end
  frames[#frames+1]=f
  return f
end
UIParent=frame()
CreateFrame=function(_,_,parent) return frame(parent) end
InCombatLockdown=function() return false end
local planned, displayMap = 0, nil
local ordered, deferred = {}, {}
addon.Plan=function(_, map) planned=planned+1; displayMap=map; return ordered,deferred,42,.2,.4 end
local chunk=assert(loadfile('UI/Destinations.lua')); chunk('ErrandMaster',addon)
assert(type(addon.destinations.Open)=='function')
assert(addon.destinations:Open())
assert(planned==1 and displayMap==nil, 'standalone list plans for the player map')
local window=addon.destinations.frame
assert(window.parent==UIParent and window.clamped and window.movable)
assert(window.dragButtons[1]=='LeftButton')
window.scripts.OnDragStart(window)
assert(window.moving)
window.scripts.OnDragStop(window)
assert(not window.moving)
ordered={{name='Bank',mapID=42,x=.25,y=.5,directYards=125},
         {name='Other',mapID=42,x=.9,y=.1}}
deferred={{name='Mailbox',mapID=43},{name='Unlocated'}}
assert(addon.destinations:Refresh())
assert(addon.destinations.rows[1].text:find('1. Bank',1,true))
assert(addon.destinations.rows[1].text:find('25.0, 50.0',1,true))
assert(addon.destinations.rows[1].text:find('125 yd direct',1,true))
assert(addon.destinations.rows[2].text:find('2. Other',1,true))
assert(not addon.destinations.rows[2].text:find('yd direct',1,true))
assert(addon.destinations.rows[3].text:find('Deferred: Mailbox',1,true))
assert(addon.destinations.rows[4].text:find('Deferred: Unlocated',1,true))
ordered={}
for i=1,30 do ordered[i]={name='Stop '..i,mapID=42,x=.5,y=.5} end
deferred={{name='Waiting'}}
addon.destinations:Refresh()
assert(#addon.destinations.rows<=10, 'bounded row pool')
assert(addon.destinations.nextButton.shown)
addon.destinations.nextButton.scripts.OnClick()
assert(addon.destinations.rows[1].text:find('Stop 9',1,true))
for i=1,30 do addon.destinations.nextButton.scripts.OnClick() end
assert(not addon.destinations.nextButton.shown, 'page cannot exceed last page')
assert(addon.destinations.rows[7].text:find('Deferred: Waiting',1,true))
ordered={{name='Fresh',mapID=42,x=.1,y=.2}}
deferred={}
addon.destinations:Refresh()
assert(addon.destinations.rows[1].text:find('Fresh',1,true) and
  not addon.destinations.nextButton.shown, 'refresh clamps stale page')
addon.destinations:Toggle()
assert(not window.shown)
addon.destinations:Toggle()
assert(window.shown)
print('destinations tests passed')