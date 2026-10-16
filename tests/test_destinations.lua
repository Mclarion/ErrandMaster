local addon = {db={data={settings={showDestinations=true}}}}
local frames = {}
local function frame(parent)
  local f = {parent=parent, scripts={}, shown=false}
  function f:SetSize(w,h) self.width,self.height=w,h end
  function f:SetWidth(w) self.width=w end
  function f:SetHeight(h) self.height=h end
  function f:SetJustifyH(value) self.justifyH=value end
  function f:SetJustifyV(value) self.justifyV=value end
  function f:SetPoint(...) self.point={...} end
  function f:ClearAllPoints() self.point=nil end
  function f:SetText(text) self.text=text end
  function f:SetScript(event, fn) self.scripts[event]=fn end
  function f:HookScript(event, fn)
    self.hooks=self.hooks or {}; self.hooks[event]=fn
  end
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
CreateFrame=function(_,_,parent,template)
  local result=frame(parent)
  if template=='BasicFrameTemplateWithInset' then
    result.TitleText=frame(result)
    result.CloseButton=frame(result)
  end
  return result
end
InCombatLockdown=function() return false end
local planned, displayMap = 0, nil
local ordered, deferred = {}, {}
addon.Plan=function(_, map) planned=planned+1; displayMap=map; return ordered,deferred,42,.2,.4 end
local chunk=assert(loadfile('UI/Destinations.lua')); chunk('ErrandMaster',addon)
assert(type(addon.destinations.Open)=='function')
assert(type(addon.destinations.Restore)=='function' and addon.destinations:Restore(),
  'target tracker opens by default on login')
assert(planned==1 and displayMap==nil, 'standalone list plans for the player map')
local window=addon.destinations.frame
assert(window.parent==UIParent and window.clamped and window.movable)
assert(window.point[1]=='TOPLEFT' and window.width<=340,
  'own compact tracker starts away from the usual right-side guide space')
assert(addon.destinations.rows[1].width and addon.destinations.rows[1].width<=300,
  'tracker rows wrap inside the available width')
assert(window.CloseButton.hooks and window.CloseButton.hooks.OnClick,
  'native template close button saves the visibility choice')
window:Hide() -- The inherited close handler hides its parent frame.
window.CloseButton.hooks.OnClick(window.CloseButton)
assert(not addon.db.data.settings.showDestinations and
  not addon.destinations:Restore(), 'closing with X persists across login')
addon.destinations:Open()
assert(window:IsShown() and addon.db.data.settings.showDestinations)
assert(window.dragButtons[1]=='LeftButton')
window.scripts.OnDragStart(window)
assert(window.moving)
window.scripts.OnDragStop(window)
assert(not window.moving)
window.scripts.OnDragStart(window)
local savedPosition
addon.windowPosition={Save=function(_, _, key) savedPosition=key end}
window.scripts.OnHide(window)
assert(not window.moving and not window.errandMoving and savedPosition=='targets',
  'closing a frame mid-drag must stop and persist its final position')
ordered={{name='Bank|test',mapID=42,x=.25,y=.5,directYards=125},
         {name='Other',mapID=42,x=.9,y=.1}}
deferred={{name='Mailbox',mapID=43},{name='Unlocated'}}
assert(addon.destinations:Refresh())
assert(addon.destinations.rows[1].text:find('1. Bank/test',1,true) and
  not addon.destinations.rows[1].text:find('|',1,true))
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
assert(not window.shown and not addon.db.data.settings.showDestinations)
assert(not addon.destinations:Restore(), 'an intentionally hidden tracker stays hidden')
addon.destinations:Toggle()
assert(window.shown and addon.db.data.settings.showDestinations)
print('destinations tests passed')