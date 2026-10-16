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
  function f:CreateTexture() return frame(self) end
  function f:SetTexture(value) self.texture=value end
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
assert(addon.destinations.controls[1].activate.icon.texture:find('PackWaypoint.blp',1,true),
  'Go uses the supplied waypoint artwork without replacing its text label')
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
local all = {
  {id=1,name='Bank|test',mapID=42,x=.25,y=.5,directYards=125,completed=false},
  {id=2,name='Other',mapID=42,x=.9,y=.1,walkStatus='known-route',walkYards=45,completed=false},
  {id=3,name='Mailbox',mapID=43,completed=false},
  {id=4,name='Unlocated',completed=false},
  {id=5,name='Finished',completed=true},
}
local calls, activated, refreshed = {}, nil, 0
addon.errands = {}
function addon.errands:All() return all end
function addon.errands:Get(id)
  for _, item in ipairs(all) do if item.id == id then return item end end
end
function addon.errands:Complete(id, value)
  calls[#calls+1]={'complete',id,value}; self:Get(id).completed=value
end
function addon.errands:Update(id, changes)
  calls[#calls+1]={'update',id,changes}
  for key,value in pairs(changes) do self:Get(id)[key]=value end
end
function addon.errands:Delete(id)
  calls[#calls+1]={'delete',id}
  for i, item in ipairs(all) do if item.id==id then table.remove(all,i); return end end
end
function addon.errands:Reorder(id, target)
  calls[#calls+1]={'reorder',id,target}
  for i, item in ipairs(all) do
    if item.id==id then table.insert(all,target,table.remove(all,i)); return end
  end
end
addon.ActiveTarget=function(_, active, pending)
  if activated then
    local selected=addon.errands:Get(activated)
    if selected and not selected.completed then return selected end
  end
  return active and active[1]
end
addon.ActivateTarget=function(_, id)
  activated=id
  addon:Refresh()
  return true
end
addon.Refresh=function() refreshed=refreshed+1; addon.destinations:Refresh() end
local function replan()
  ordered,deferred={},{}
  for _, item in ipairs(all) do
    if not item.completed then
      if item.mapID==42 then ordered[#ordered+1]=item
      else deferred[#deferred+1]=item end
    end
  end
end
replan()
assert(addon.destinations:Refresh())
local rows, buttons=addon.destinations.rows,addon.destinations.controls
assert(#rows==6 and #buttons==6, 'bounded two-line row pool with controls')
assert(rows[1].text:find('1. Current: Bank/test',1,true) and
  not rows[1].text:find('|',1,true) and
  rows[1].text:find('\n',1,true), 'safe two-line current row')
assert(rows[1].text:find('25.0, 50.0; ~125 yd direct estimate',1,true))
assert(rows[2].text:find('2. Next: Other',1,true) and
  rows[2].text:find('45 yd observed path',1,true))
assert(rows[3].text:find('Deferred: Mailbox',1,true) and
  rows[3].text:find('route unknown',1,true))
assert(rows[4].text:find('Deferred: Unlocated',1,true))
assert(rows[5].text:find('Done: Finished',1,true))
assert(buttons[1].activate.shown and buttons[1].done.shown and
  buttons[1].remove.shown and buttons[1].down.shown and
  not buttons[1].up.shown and buttons[5].done.text=='Reopen' and
  not buttons[5].activate.shown, 'visible contextual controls')
assert(buttons[1].favorite.text=='Fav' and buttons[1].favorite.shown)
buttons[1].favorite.scripts.OnClick()
assert(all[1].favorite and buttons[1].favorite.text=='Unfav' and
  rows[1].text:find('[Fav]',1,true), 'target toggles persistent favorite')
buttons[1].favorite.scripts.OnClick()
assert(all[1].favorite == false and buttons[1].favorite.text=='Fav')
refreshed=0
buttons[1].activate.scripts.OnClick()
assert(activated==1 and refreshed==1, 'Go delegates activation')
buttons[2].up.scripts.OnClick()
assert(calls[#calls][1]=='reorder' and calls[#calls][2]==2 and
  calls[#calls][3]==1 and addon.db.data.settings.optimize==false and refreshed==2,
  'manual move uses global order, disables optimization, refreshes')
replan(); addon.destinations:Refresh()
assert(rows[1].text:find('Stop: Other',1,true) and
  rows[2].text:find('Current: Bank/test',1,true),
  'explicit active target remains current after a reorder')
buttons[1].done.scripts.OnClick()
assert(calls[#calls][1]=='complete' and calls[#calls][2]==2 and
  calls[#calls][3]==true and refreshed==3)
replan(); addon.destinations:Refresh()
assert(rows[4].text:find('Done: Other',1,true))
buttons[4].done.scripts.OnClick()
assert(calls[#calls][1]=='complete' and calls[#calls][2]==2 and
  calls[#calls][3]==false, 'completed row can be reopened')
replan(); addon.destinations:Refresh()
buttons[2].remove.scripts.OnClick()
assert(calls[#calls][1]=='delete' and calls[#calls][2]==1, 'remove delegates deletion')
replan(); addon.destinations:Refresh()
ordered={}
for i=1,30 do ordered[i]={id=100+i,name='Stop '..i,mapID=42,x=.5,y=.5} end
deferred={{id=200,name='Waiting'}}
assert(addon.destinations:Refresh())
assert(#rows==6 and addon.destinations.nextButton.shown)
addon.destinations.nextButton.scripts.OnClick()
assert(rows[1].text:find('Stop 7',1,true))
for i=1,30 do addon.destinations.nextButton.scripts.OnClick() end
assert(not addon.destinations.nextButton.shown, 'page cannot exceed last page')
assert(rows[1].text:find('Deferred: Waiting',1,true))
ordered={{id=101,name='Fresh',mapID=42,x=.1,y=.2}}
deferred={}
addon.destinations:Refresh()
assert(rows[1].text:find('Fresh',1,true) and
  not addon.destinations.nextButton.shown, 'refresh clamps stale page')
ordered={{id=301,name='Partial',mapID=42,x=.25,y=.5,
  walkStatus='partial-route',walkYards=40},
  {id=302,name='No path',directYards=80}}
deferred={{id=303,name='Trainer',taxiFlightNode='Ironforge'},
  {id=304,name='Bank',nearbyZoneCandidate={name='Border Banker',zoneName='Border',directYards=150}},
  {id=305,name='Unknown',walkStatus='unknown-route'}}
addon.destinations:Refresh()
assert(rows[1].text:find('25.0, 50.0',1,true) and
  rows[1].text:find('40 yd observed; connector unknown',1,true),
  'a partial segment retains target coordinates and unknown-connector warning')
assert(rows[2].text:find('~80 yd direct estimate',1,true))
assert(rows[3].text:find('Trainer',1,true) and rows[3].text:find('Ironforge',1,true)
  and rows[3].text:find('walk unknown',1,true))
assert(rows[4].text:find('Border',1,true) and rows[4].text:find('direct; route unknown',1,true))
assert(rows[5].text:find('Unknown path:',1,true))
assert(rows[6].text:find('Done: Finished',1,true) and
  not buttons[6].activate.shown, 'completed target remains visible')
all={}; ordered={}; deferred={}
addon.destinations:Refresh()
assert(rows[1].text:find('No targets',1,true) and
  not rows[2].shown and not buttons[2].done.shown,
  'empty state has no stale interactive controls')
all={{id='em-42',name='String ID',mapID=42,completed=false}}
activated=nil; replan(); addon.destinations:Refresh()
assert(rows[1].text:find('Current: String ID',1,true) and
  buttons[1].activate.shown, 'production string IDs remain actionable')
buttons[1].activate.scripts.OnClick()
assert(activated=='em-42', 'activation preserves opaque string ID')
addon.destinations:Toggle()
assert(not window.shown and not addon.db.data.settings.showDestinations)
assert(not addon.destinations:Restore(), 'an intentionally hidden tracker stays hidden')
addon.destinations:Toggle()
assert(window.shown and addon.db.data.settings.showDestinations)
print('destinations tests passed')