local addon={db={data={settings={showDestinations=true,optimize=true}}}}
local function frame(parent)
 local f={parent=parent,scripts={},shown=false}
 for _,name in ipairs({'SetSize','SetPoint','SetMinMaxValues','SetVertexColor'}) do
  f[name]=function(self,...) self[name..'Args']={...}; if name=='SetSize' then self.width,self.height=... elseif name=='SetPoint' then self.point={...}; self.points=self.points or {}; self.points[#self.points+1]={...} elseif name=='SetMinMaxValues' then self.min,self.max=... else self.vertexColor={...} end end
 end
 function f:SetWidth(x) self.width=x end
 function f:SetHeight(x) self.height=x end
 function f:GetWidth() return self.width end
 function f:GetHeight() return self.height end
 function f:GetBottom() return 30 end
 function f:GetTop() return 30+(self.height or 0) end
 function f:ClearAllPoints() self.point=nil end
 function f:SetText(x) self.text=x end
 function f:SetTexture(x) self.texture=x end
 function f:SetAlpha(x) self.alpha=x end
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:Show() self.shown=true end
 function f:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
 function f:IsShown() return self.shown end
 function f:CreateFontString() return frame(self) end
 function f:CreateTexture() return frame(self) end
 function f:GetParent() return self.parent end
 function f:EnableMouse() end
 function f:RegisterForDrag(...) self.dragButtons={...} end
 function f:SetMovable(v) self.movable=v end
 function f:SetResizable(v) self.resizable=v end
 function f:SetResizeBounds(...) self.bounds={...} end
 function f:SetClampedToScreen(v) self.clamped=v end
 function f:StartMoving() self.moving=true end
 function f:StartSizing() self.sizing=true end
 function f:StopMovingOrSizing() self.moving=false; self.sizing=false end
 function f:SetScrollChild(v) self.child=v end
 function f:GetVerticalScroll() return self.scroll or 0 end
 function f:SetVerticalScroll(v) self.scroll=v end
 function f:SetValue(v) self.value=v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
 function f:SetValueStep(v) self.step=v end
 function f:SetOrientation(v) self.orientation=v end
 function f:SetJustifyH(v) self.justifyH=v end
 function f:SetJustifyV(v) self.justifyV=v end
 function f:SetTextColor(...) self.textColor={...} end
 function f:SetShadowColor(...) self.shadowColor={...} end
 function f:SetShadowOffset(...) self.shadowOffset={...} end
 return f
end
UIParent=frame(); UIParent:SetSize(800,600)
CreateFrame=function(_,_,parent) return frame(parent) end
GameTooltip={SetOwner=function() end,SetText=function(self,t) self.text=t end,Show=function() end,Hide=function() end}
local mx,my=100,400
GetCursorPosition=function() return mx,my end
local ordered,deferred={},{}
addon.Plan=function() return ordered,deferred end
local all,calls={},{}
local cleared={}
addon.errands={}
function addon.errands:All() return all end
function addon.errands:Get(id) for _,v in ipairs(all) do if v.id==id then return v end end end
function addon.errands:Reorder(id,index)
 calls[#calls+1]={id,index}
 for i,v in ipairs(all) do if v.id==id then table.insert(all,index,table.remove(all,i)); return end end
end
function addon.errands:Update(id,change) for k,v in pairs(change) do self:Get(id)[k]=v end end
function addon.errands:ClearOrder(id) cleared[#cleared+1]=id; self:Get(id).manualPosition=nil end
function addon.errands:Delete(id) for i,v in ipairs(all) do if v.id==id then table.remove(all,i); return end end end
addon.ActivateTarget=function(_,id) addon.activated=id end
addon.Refresh=function(self) self.destinations:Refresh() end
assert(loadfile('UI/Destinations.lua'))('ErrandMaster',addon)
local d=addon.destinations
assert(d:Restore())
assert(not d.frame:IsShown() and #d.entries==0 and d.frame.CloseButton==nil)
assert(addon.db.data.settings.showDestinations)
assert(d:GetNavigationAnchor()==d.frame)
assert(d.frame.resizable and d.frame.clamped and d.frame.bounds[1]<=240)
assert(d.scroll and d.scroll.child==d.content and d.scrollbar)
assert(not d.prevButton and not d.nextButton)
for i=1,12 do
 all[i]={id=i,name='Target '..i,mapID=42,x=.1*i/12,y=.5,directYards=100+i,category=i==1 and 'Bank' or 'Vendor'}
 ordered[i]=all[i]
end
d:Refresh()
assert(d.frame:IsShown() and #d.entries==12 and #d.cards==12 and #d.rows==12)
assert(d.scrollbar.shown and d.scrollbar.max>0 and d.content.height>d.scroll.height)
assert(d.cards[12].point and d.cards[12].shown)
assert(d.cards[1].height<=76 and d.frame.width<=340)
assert(d.cards[1].height>=76, 'icon and reset controls fit within card height')
assert(d.cards[1].pattern.alpha and d.cards[1].pattern.alpha<.8)
assert(d.cards[1].frameArt.texture:find('CardFrame.blp',1,true))
assert(d.cards[1].pattern.texture:find('DestinationCardPattern.blp',1,true),
 'destination-only tinted card art fades at both edges')
assert(d.rows[1].justifyH=='LEFT' and d.rows[1].justifyV=='MIDDLE',
 'card text begins inside its colored area')
assert(d.rows[1].text:find('From you: Unknown',1,true))
assert(d.rows[1].text:find('From route start: Unknown',1,true))
assert(d.rows[1].points[1][1]=='TOPLEFT' and d.rows[1].points[1][4]>=10 and
 d.rows[1].points[1][5]<0, 'label inset is within tinted card')
assert(d.rows[1].textColor[1]==1 and d.rows[1].shadowColor[1]==0,
 'light text with dark shadow preserves contrast over tinted art')
local controls=d.controls[1]
assert(controls.remove and controls.favorite and controls.activate and controls.reset and not controls.done and not controls.up and not controls.down)
for _,action in ipairs({'remove','favorite','activate'}) do
 local b=controls[action]
 assert(not b.text or b.text=='')
 assert(b.icon and b.icon.texture and b.scripts.OnEnter and b.scripts.OnLeave)
 assert(b.glow and b.glow.texture and b.glow.texture:find('DestinationButtonGlow.blp',1,true)
  and b.glow.alpha and b.glow.alpha>.2,
  'control has a brighter backlit halo behind the original icon')
 assert(b.point[1]=='TOPLEFT' and b.point[2]==d.cards[1] and b.point[3]=='TOPRIGHT' and b.point[4]>0 and b.width>=20 and b.height>=17,
  'the icon floats outside the colored card with a click region')
 assert(b.icon.width==15 and b.icon.height==15)
 assert(b.width>=22 and b.height>=19 and b.glow.width>=28 and b.glow.alpha>=.85,
  'button border clears icon and halo strengthens without tinting source art')
 assert(-b.point[5]+b.height<=d.cards[1].height and
  d.cards[1].width+b.point[4]+b.width<=d.scroll.width,
  'clickable control stays inside the card row and scroll viewport')
end
assert(-controls.reset.point[5]+controls.reset.height<=d.cards[1].height and
  d.cards[1].width+controls.reset.point[4]+controls.reset.width<=d.scroll.width,
  'reset control remains within the same row and viewport')
controls.favorite.scripts.OnClick(); assert(all[1].favorite)
controls.activate.scripts.OnClick(); assert(addon.activated==1)
d.controls[5].activate.scripts.OnClick()
assert(calls[#calls][1]==5 and calls[#calls][2]==1 and addon.db.data.settings.optimize)
ordered[1].manualPosition=1; d:Refresh()
assert(d.rows[1].text:find('Overridden',1,true) and d.controls[1].reset.shown)
d.controls[1].reset.scripts.OnClick()
assert(cleared[#cleared]==1 and ordered[1].manualPosition==nil and not d.controls[1].reset.shown,
 'reset handler clears the manual anchor and refreshes the row')
local source=d.cards[8]
source.scripts.OnDragStart(source)
assert(d.ghost and d.ghost.shown and d.dragSource==8)
mx,my=230,312
source.scripts.OnUpdate(source,.05)
assert(d.ghost.point and d.ghost.point[4]==mx and d.ghost.point[5]==my)
local prior=#calls
mx,my=230,165 -- row three's center in the unscrolled viewport
-- Animated source remains mouse focus even as the pointer reaches the third slot.
GetMouseFoci=function() return {source} end
source.scripts.OnUpdate(source,.05)
assert(#calls==prior and d.preview and d.preview[3].id==8, 'live preview reorders before persistence')
assert(d.cards[3].animation or d.cards[3].targetY)
local oldScroll=d.scroll:GetVerticalScroll()
mx,my=230,8; source.scripts.OnUpdate(source,.2)
assert(d.scroll:GetVerticalScroll()>oldScroll)
local value=d.scroll:GetVerticalScroll()
d.scroll.scripts.OnMouseWheel(d.scroll,1)
assert(d.scroll:GetVerticalScroll()<value, 'mouse wheel scrolls the list')
source.scripts.OnDragStop(source)
assert(calls[#calls][1]==8 and calls[#calls][2]==3,
  'release persists only the moved item to its new position')
assert(not d.ghost.shown and not d.dragSource and addon.db.data.settings.optimize)
-- Hit-test slots in viewport space, not animated cards or the stale hover.
-- The scale converts hardware cursor pixels back to UIParent coordinates.
UIParent.GetEffectiveScale=function() return 2 end
GetCursorPosition=function() return mx*2,my*2 end
local scrolled=d.scrollMax
d.scroll:SetVerticalScroll(scrolled)
source=d.cards[1]; mx,my=230,31
source.scripts.OnDragStart(source)
GetMouseFoci=function() return {source} end
source.scripts.OnUpdate(source,.01)
assert(d.dragTarget==12, 'bottom boundary addresses last visible slot after scrolling')
source.scripts.OnDragStop(source)
assert(calls[#calls][1]==1 and calls[#calls][2]==12,
 'scaled cursor release at bottom persists the actual bottom slot')
d.scroll:SetVerticalScroll(0)
source=d.cards[12]; mx,my=230,324
source.scripts.OnDragStart(source)
source.scripts.OnUpdate(source,.01)
assert(d.dragTarget==1, 'top boundary addresses first slot')
source.scripts.OnDragStop(source)
assert(calls[#calls][1]==12 and calls[#calls][2]==1)
UIParent.GetEffectiveScale=nil; GetCursorPosition=function() return mx,my end
d.frame:SetSize(900,900); d.frame.scripts.OnSizeChanged(d.frame,900,900)
assert(d.frame.width<=UIParent.width and d.frame.height<=UIParent.height and #d.entries==12)
all={}; ordered={}; deferred={}; d:Refresh()
assert(not d.frame.shown and #d.entries==0 and addon.db.data.settings.showDestinations)
addon.db.data.settings.showDestinations=false; d:Refresh(); assert(not d.frame.shown)
all={{id='opaque',name='Unknown|target',mapID=43}}; deferred=all
d:Refresh(); assert(not d.frame.shown)
d:Toggle(); assert(d.frame.shown and d.rows[1].text:find('Unknown/target',1,true))
assert(d.rows[1].text:find('Unknown Location',1,true))
local sample={
 {id='partial',name='Partial',x=.25,y=.5,walkStatus='partial-route',walkYards=40},
 {id='flight',name='Trainer',taxiFlightNode='Ironforge'},
 {id='zone',name='Bank',nearbyZoneCandidate={zoneName='Border',directYards=150}},
 {id='done',name='Finished',completed=true},
}
all=sample; ordered={sample[1],sample[2],sample[3]}; deferred={}; d:Refresh()
assert(d.rows[1].text:find('Connector Unknown',1,true))
assert(d.rows[2].text:find('Walk Unknown',1,true))
assert(d.rows[3].text:find('Unknown Path',1,true))
assert(#d.entries==3 and not d.cards[4].shown,
  'completed errands never keep the otherwise-empty sidebar visible')
-- Every row measures from its immediate predecessor in the displayed order.
local stops={}
for i=1,15 do
 stops[i]={id='stop-'..i,name='Stop '..i,mapID=42,x=i*i/300,y=.5}
end
addon.Position=function() return 42,0,.5 end
addon.MapWorldSize=function(_,map) if map==42 then return 300,300 end end
addon.Plan=function() return stops,{} end
addon.route={DisplayOrder=function(_,route) return route end}
d:Refresh()
assert(#d.entries==15 and d.rows[1].text:find('From route start: 1 yd direct',1,true))
for i=2,15 do
 local distance=i*i-(i-1)*(i-1)
 assert(d.rows[i].text:find('From previous stop: '..distance..' yd direct',1,true),
  'row '..i..' measures from the preceding displayed stop')
end
local reversed={}
for i=15,1,-1 do reversed[#reversed+1]=stops[i] end
addon.Plan=function() return reversed,{} end
d:Refresh()
assert(d.rows[2].text:find('From previous stop: 29 yd direct',1,true),
 'reordered rows use the new displayed predecessor')
local flight={id='!taxi:stop-15',transitForId='stop-15',name='Flight',mapID=42,x=.1,y=.5}
addon.route.DisplayOrder=function() return {stops[1],flight,stops[15]} end
d:Refresh()
assert(d.rows[2].text:find('From previous stop: 29 yd direct',1,true) and
 d.rows[3].text:find('From previous stop: 195 yd direct',1,true),
 'transient flight row participates as the preceding displayed stop')
local unknown={id='unknown',name='Unlocated',mapID=42}
addon.route.DisplayOrder=function() return {stops[1],unknown,stops[15],stops[14]} end
d:Refresh()
assert(d.rows[2].text:find('From previous stop: Unknown',1,true) and
 d.rows[3].text:find('From previous stop: Unknown',1,true) and
 d.rows[4].text:find('From previous stop: 29 yd direct',1,true),
 'unresolved immediate predecessor stays unknown rather than skipping backward')
addon.route=nil
local planCalls=0
addon.Plan=function()
 planCalls=planCalls+1
 return {
  {id='first',name='Milly',category='Ammo Vendor',mapID=42,x=.2,y=.5},
  {id='second',name='Sven',category='Bank',mapID=42,x=.5,y=.5},
 },{{id='lost',name='Unknown',category='Repair',mapID=43}}
end
addon.Position=function() return 42,.1,.5 end
addon.MapWorldSize=function(_,map) if map==42 then return 1000,1000 end end
all={{id='first',name='Milly',mapID=42,x=.2,y=.5},
 {id='second',name='Sven',mapID=42,x=.5,y=.5},
 {id='lost',name='Unknown',mapID=43}}
d:Refresh()
assert(planCalls==1,'one shared route snapshot per refresh')
assert(d.rows[1].text:find('Vendor: Ammo',1,true) and
 d.rows[1].text:find('Milly',1,true),'service and NPC both appear')
assert(d.rows[1].text:find('From you: 100 yd',1,true) and
 d.rows[1].text:find('From route start: 100 yd',1,true))
assert(d.rows[2].text:find('From you: 400 yd',1,true) and
 d.rows[2].text:find('From previous stop: 300 yd',1,true),
 'second row measures from the immediately previous target')
assert(not d.rows[1].text:find('20.0, 50.0',1,true),'no coordinates in text')
assert(not d.controls[3].activate.shown and not d.controls[3].reset.shown,
 'unresolved stop has no order or navigation action')
local before=#calls
d:Drop(3,1)
d:Change('activate',3)
assert(#calls==before,'unknown destination cannot be reordered through handlers')
local projections={
 [42]={instance=7,north=0,west=0},
 [44]={instance=7,north=300,west=400},
 [45]={instance=8,north=300,west=400},
}
addon.navigation={WorldPosition=function(_,map)
 local p=projections[map]; return p.instance,p.north,p.west
end}
addon.Plan=function() return {
 {id='first',name='Milly',mapID=42,x=.2,y=.5},
 {id='other',name='Across map',mapID=44,x=.2,y=.5},
 {id='different',name='Other instance',mapID=45,x=.2,y=.5},
},{} end
all[2].id='other'; all[2].mapID=44
all[3].id='different'; all[3].mapID=45
d:Refresh()
assert(d.rows[2].text:find('From previous stop: 500 yd direct',1,true),
 'same-instance native projection supports cross-map direct distance')
assert(d.rows[3].text:find('From previous stop: Unknown',1,true),
 'cross-instance position is never fabricated')
addon.navigation=nil
addon.Plan=function() return ordered,deferred end
addon.Position=nil; addon.MapWorldSize=nil
all={sample[4]}; ordered={}; deferred={}; d:Refresh()
assert(#d.entries==0 and not d.frame.shown)
all={sample[1],sample[2],sample[3]}; ordered=all; d:Refresh()
UIParent:SetSize(240,180)
d.frame.scripts.OnSizeChanged(d.frame,900,900)
assert(d.frame.width<=240 and d.frame.height<=180 and d.scrollbar.shown,
 'short narrow viewport clamps shell without removing targets')
local many={}
for i=1,205 do many[i]={id=i,name='Target '..i} end
all=many; ordered=many; deferred={}; d:Refresh()
assert(#d.entries==205 and d.cards[205].shown,
 'scroll content includes every target, beyond the old fixed collection cap')
-- Exercise the real persisted queue and planner, not the index-recording stub.
local real={}
assert(loadfile('Core/Database.lua'))('ErrandMaster',real)
assert(loadfile('Core/Errands.lua'))('ErrandMaster',real)
assert(loadfile('Routing/RoutePlanner.lua'))('ErrandMaster',real)
ErrandMasterDB=nil; real.db:Initialize('Drag-Realm')
real.db.data.settings.showDestinations=true
local a=real.errands:Add({name='A',mapID=42,x=.9,y=.5})
local b=real.errands:Add({name='B',mapID=42,x=.5,y=.5})
local c=real.errands:Add({name='C',mapID=42,x=.1,y=.5})
function real:Plan()
 return self.route:Plan(self.errands:All(),42,0,.5,true,nil,nil,100,100)
end
function real:Refresh() self.destinations:Refresh() end
assert(loadfile('UI/Destinations.lua'))('ErrandMaster',real)
local tracker=real.destinations
tracker:Create(); tracker:Refresh()
assert(tracker.entries[1].id==c.id and tracker.entries[2].id==b.id and
 tracker.entries[3].id==a.id and real.errands:All()[1].id==a.id,
 'optimized display differs from saved insertion order')
tracker.scroll:SetVerticalScroll(0)
local realSource=tracker.cards[3]
mx,my=100,tracker.scroll:GetTop()-1
GetMouseFoci=function() return {realSource} end
realSource.scripts.OnDragStart(realSource)
realSource.scripts.OnUpdate(realSource,.01)
realSource.scripts.OnDragStop(realSource)
assert(a.manualPosition==1 and tracker.entries[1].id==a.id,
 'real drag handlers anchor A at displayed C slot 1, not saved C index 3')
assert(tracker.controls[1].reset.shown and tracker.rows[1].text:find('Overridden',1,true))
tracker.controls[1].reset.scripts.OnClick()
assert(a.manualPosition==nil,'Reset order clears only the selected persisted anchor')
assert(b.manualPosition==nil and c.manualPosition==nil)
local repair=real.errands:Add({name='Repair',category='Repair',mapID=43,x=.2,y=.4})
tracker:Refresh()
assert(tracker.entries[4].id==repair.id,'off-map repair starts deferred')
realSource=tracker.cards[4]
mx,my=100,tracker.scroll:GetTop()-1
GetMouseFoci=function() return {realSource} end
realSource.scripts.OnDragStart(realSource)
realSource.scripts.OnUpdate(realSource,.01)
realSource.scripts.OnDragStop(realSource)
local planned,pending=real:Plan()
local visible=real.route:DisplayOrder(planned,pending)
assert(repair.manualPosition==1 and visible[1].id==repair.id,
 'known off-map destination remains orderable despite its unknown route')
assert(tracker.entries[1].id==visible[1].id,
 'sidebar follows the route worker display order')
print('destinations tests passed')
real.Plan=function() return {{id='!taxi:'..a.id,transitForId=a.id,name='Flight Master',
 category='Flight Master',mapID=42,x=.2,y=.5,manualPosition=1},a},{} end
tracker:Refresh()
assert(tracker.entries[1].transit and tracker.rows[1].text:find('Flight step',1,true) and
 not tracker.rows[1].text:find('Overridden',1,true),'synthetic flight stage is not a saved manual override')
for _,button in pairs(tracker.controls[1]) do assert(not button.shown,'transient flight stages must not offer saved-errand controls') end
real.Plan=function() return {{id='!boat:'..a.id,transitForId=a.id,name='Recorded boat departure',
 category='Boat',mapID=42,x=.2,y=.5,manualPosition=1},a},{} end
tracker:Refresh()
assert(tracker.rows[1].text:find('Boat step',1,true) and not tracker.rows[1].text:find('Flight step',1,true),
 'a recorded boat intermediary must not be labeled as a flight')
