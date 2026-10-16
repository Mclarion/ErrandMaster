local addon = {worldMap=nil, errands={}, quests={}, locations={}}
local created = {}
local function frame(parent)
  local result = {parent=parent, scripts={}, shown=false, width=1000, height=500}
  function result:SetSize(w,h) self.width,self.height=w,h end
  function result:GetWidth() return self.width end
  function result:GetHeight() return self.height end
  function result:SetPoint(...) self.point={...} end
  function result:SetAllPoints(parent) self.allPoints=parent end
  function result:SetParent(parent) self.parent=parent end
  function result:ClearAllPoints() self.point=nil end
  function result:Show() self.shown=true end
  function result:Hide() self.shown=false end
  function result:IsShown() return self.shown end
  function result:SetScript(name, fn) self.scripts[name]=fn end
  function result:SetText(text) self.text=text end
  function result:CreateTexture() local child=frame(self); function child:SetColorTexture(...) self.color={...} end; return child end
  function result:CreateFontString() return frame(self) end
  return result
end
CreateFrame = function(kind, name, parent)
  local item = frame(parent); item.kind=kind; created[#created+1]=item; return item
end
local canvas = frame()
local map = {mapID=42, canvas=canvas, providers={}, clicks={}}
function map:GetMapID() return self.mapID end
function map:GetCanvas() return self.canvas end
function map:AddDataProvider(provider) self.providers[#self.providers+1]=provider; provider:OnAdded(self) end
function map:AddCanvasClickHandler(handler) self.clicks[#self.clicks+1]=handler end
WorldMapFrame = map
InCombatLockdown = function() return false end
IsShiftKeyDown = function() return false end
local chunk = assert(loadfile('UI/WorldMap.lua')); chunk('ErrandMaster', addon)
assert(addon.worldMap:Attach() == true)
assert(#map.providers == 1 and #map.clicks == 1)
assert(addon.worldMap:Attach() == true)
assert(#map.providers == 1 and #map.clicks == 1, 'attachment must be idempotent')
for _, event in ipairs({'OnMapInsetMouseEnter','OnMapInsetMouseLeave','OnGlobalAlphaChanged'}) do
  assert(type(map.providers[1][event]) == 'function', event..' callback is required by MapCanvas')
  map.providers[1][event](map.providers[1])
end
local route = {
  {id='one', name='Bank', mapID=42, x=.25, y=.5, directYards=112},
  {id='other', name='Other map', mapID=43, x=.7, y=.8},
  {id='bad', name='Invalid', mapID=42, x=0/0, y=.1},
  {id='edge', name='Edge', mapID=42, x=1, y=0},
}
local observed = {
  {id='loc-1', name='Mailbox', category='Mailbox', mapID=42, x=.75, y=.2, source='service-event'},
  {id='loc-2', name='Unplaced', mapID=42},
  {id='loc-3', name='Other map', mapID=43, x=.2, y=.2},
  {id='loc-4', name='Out of bounds', mapID=42, x=1.01, y=.2},
}
local requestedMap
addon.Plan = function(_, id) requestedMap=id; return route, {}, id, .25, .5 end
addon.locations.All = function() return observed end
local adds, refreshes, questAdds = {}, 0, {}
addon.errands.Add = function(_, item) adds[#adds+1]=item; return item end
addon.quests.OnMap = function() return {{questID=1001,title='Find the smith',mapID=42,x=.5,y=.5}, {questID=1002,title='Visit the bank',mapID=42}, {questID=0,title='Invalid',mapID=42}} end
addon.quests.Add = function(_, questID, mapID) questAdds[#questAdds+1]={questID,mapID}; return {questID=questID} end
addon.Refresh = function() refreshes=refreshes+1 end
assert(addon.worldMap:Refresh())
local pins = addon.worldMap.pins
assert(#pins == 3, 'only valid same-map route stops and observed services make pins')
assert(pins[1].parent == canvas and pins[2].parent == canvas and pins[3].parent == canvas)
assert(pins[1].shown and pins[2].shown and pins[3].shown)
assert(pins[1].point[4] == 250 and pins[1].point[5] == -250, 'normalized route coordinate')
assert(pins[2].point[4] == 1000 and pins[2].point[5] == 0, 'edge coordinate')
assert(pins[3].point[4] == 750 and pins[3].point[5] == -100, 'observed coordinate')
assert(pins[1].label and pins[1].label.text:find('Bank', 1, true) and
  pins[1].label.text:find('yd direct', 1, true), 'route marker identifies its stop and direct distance')
assert(pins[3].label.text:find('Mailbox', 1, true), 'observed marker identifies its service')
assert(pins[1].number.text == '1' and pins[2].number.text == '4',
  'route numbering retains plan order even when intermediate stops are not on this map')
assert(pins[3].number.text == 'S1' and pins[1].number.point[1] == 'TOPRIGHT',
  'service pins have a distinct sequence and number is upper-right over marker')
assert(pins[2].label.text:find('4. Edge',1,true), 'route label matches ordered stop number')
-- When a native/sibling icon is already at the stop, show only our exponent
-- number above it; never hide, move or change the existing icon.
local native=frame(canvas)
native.width,native.height=18,18
native.shown=true
native.GetCenter=function() return 250,250 end
canvas.GetLeft=function() return 0 end
canvas.GetTop=function() return 500 end
canvas.GetChildren=function() return native end
addon.worldMap:Refresh()
assert(not pins[1].icon.shown and pins[1].number.point[2]==native and native.shown and
  native.point==nil, 'coincident icon stays untouched beneath our superscript')
canvas.GetChildren=function() return nil end
addon.worldMap:Refresh()
assert(pins[1].icon.shown and pins[1].number.point[2]==pins[1],
  'own marker is restored when the native icon goes away')
observed[1].name=string.rep('x', 23)..'é service'
addon.worldMap:Refresh()
assert(not pins[3].label.text:find(string.char(195), 1, true),
  'map labels must not cut through a UTF-8 character')
observed[1].name='Mailbox'
local first = pins[1]
canvas.width=0/0
assert(addon.worldMap:Refresh() == false and not pins[1].shown,
  'invalid canvas dimensions must hide, not place, markers')
canvas.width=1000
addon.worldMap:Refresh()
assert(#pins == 3 and pins[1] == first, 'refresh must reuse pins')
map.mapID=43; addon.worldMap:Refresh()
assert(requestedMap == 43, 'map pins must plan for the map being viewed')
assert(#pins == 3 and pins[1] == first and pins[3].shown == false,
  'map change must hide surplus pins, not leave stale decorations')
assert(pins[1].point[4] == 700 and pins[1].point[5] == -400)
map.mapID=42; addon.worldMap:Refresh()
assert(#pins == 3 and pins[3].shown)
InCombatLockdown=function() return true end
map.mapID=43; map.providers[1]:OnMapChanged()
assert(not pins[1].shown and not pins[3].shown and not addon.worldMap.questPanel.shown,
  'combat-time map changes must hide stale markers and quest controls')
InCombatLockdown=function() return false end
addon.worldMap:Refresh()
assert(pins[1].shown and not pins[3].shown and addon.worldMap.currentMapID==43)
map.mapID=42; addon.worldMap:Refresh()
local shift=false
IsShiftKeyDown = function() return shift end
assert(map.clicks[1](map,'LeftButton',.35,.6) == false and #adds==0)
shift=true
assert(map.clicks[1](map,'RightButton',.35,.6) == false and #adds==0)
for _, pair in ipairs({{nil,.2},{-.1,.2},{1.1,.2},{.2,0/0},{.2,math.huge}}) do
  assert(map.clicks[1](map,'LeftButton',pair[1],pair[2]) == false)
end
assert(#adds==0)
assert(map.clicks[1](map,'LeftButton',.35,.6) == true)
assert(#adds==1 and adds[1].mapID==42 and adds[1].x==.35 and adds[1].y==.6)
assert(adds[1].name and adds[1].scope and adds[1].origin=='manual')
assert(refreshes==1)
assert(addon.worldMap.questRows and addon.worldMap.questRows[1].shown)
addon.worldMap.questRows[1].scripts.OnClick(addon.worldMap.questRows[1])
assert(#questAdds==1 and questAdds[1][1]==1001 and questAdds[1][2]==42)
assert(refreshes==2)
addon.quests.Add=nil
local chatInput
ChatFrame_OpenChat = function(command) chatInput=command end
addon.worldMap:Refresh()
assert(addon.worldMap.questPanel.shown, 'quest selection should offer slash fallback')
addon.worldMap.questRows[1].scripts.OnClick(addon.worldMap.questRows[1])
assert(chatInput == '/em quest 1001', 'fallback prepopulates the slash quest command')
ChatFrame_OpenChat=nil
addon.worldMap:Refresh()
assert(addon.worldMap.questPanel.shown == false, 'hide when neither quest selection path exists')
addon.worldMap:OnRemoved(map)
assert(not pins[1].shown and not pins[2].shown and not pins[3].shown)
addon.quests.Add = function(_, questID, id) return {questID=questID, mapID=id} end
WorldMapFrame=nil
assert(addon.worldMap:Attach() == false and addon.worldMap:Refresh() == false)
local lazyMap = {mapID=42, canvas=canvas, providers={}, clicks={}}
lazyMap.GetMapID, lazyMap.GetCanvas = map.GetMapID, map.GetCanvas
lazyMap.AddDataProvider, lazyMap.AddCanvasClickHandler = map.AddDataProvider, map.AddCanvasClickHandler
OpenWorldMap = function() WorldMapFrame=lazyMap end
assert(addon.worldMap:Open() and addon.worldMap.map == lazyMap and
  #lazyMap.providers == 1 and #lazyMap.clicks == 1,
  "map action must open and attach even before WorldMapFrame is loaded")
assert(addon.worldMap.questPanel.parent == lazyMap and
  addon.worldMap.questPanel.point[2] == lazyMap,
  'quest controls must follow a recreated world-map frame')
OpenWorldMap=nil
-- Reattaching a removed provider must not install the same click callback twice.
WorldMapFrame=map
assert(addon.worldMap:Attach() and #map.providers == 1 and #map.clicks == 1)
local blizzardPin = frame(canvas)
blizzardPin:Show()
map.mapID=42
addon.quests.Add = function(_, questID, mapID) questAdds[#questAdds+1]={questID,mapID}; return {questID=questID} end
local many = {}
for i=1,8 do many[i]={questID=2000+i,title='Quest '..i,mapID=42} end
addon.quests.OnMap = function() return many end
addon.worldMap:Refresh()
assert(addon.worldMap.questRows[1].text=='Quest 1')
assert(addon.worldMap.questNext.shown)
addon.worldMap.questNext.scripts.OnClick()
assert(addon.worldMap.questRows[1].text=='Quest 7')
assert(addon.worldMap.questRows[3].shown==false)
assert(addon.worldMap.questPrev.shown and not addon.worldMap.questNext.shown)
addon.worldMap.questRows[1].scripts.OnClick(addon.worldMap.questRows[1])
assert(questAdds[#questAdds][1]==2007)
map.mapID=43; addon.worldMap:Refresh()
assert(addon.worldMap.questPanel.shown==false)
assert(blizzardPin.shown, 'refresh must never hide unrelated map children')
map.mapID=42
InCombatLockdown=function() return true end
local before=#adds
assert(addon.worldMap:Refresh()==false and addon.worldMap:Open()==false)
assert(map.clicks[1](map,'LeftButton',.5,.5)==false and #adds==before)
InCombatLockdown=function() return false end
map.GetCanvas=nil
assert(addon.worldMap:Attach()==false and addon.worldMap:Refresh()==false)
assert(blizzardPin.shown, 'missing API must not touch other pins')
map.GetCanvas=function(self) return self.canvas end
-- A failed click registration must retry instead of permanently marking attached.
local flaky = {mapID=42, canvas=canvas, providers={}, clicks={}, attempts=0}
flaky.GetMapID=map.GetMapID; flaky.GetCanvas=map.GetCanvas
flaky.AddDataProvider=map.AddDataProvider
flaky.AddCanvasClickHandler=function(self, handler)
  self.attempts=self.attempts+1
  if self.attempts==1 then error('temporarily unavailable') end
  self.clicks[#self.clicks+1]=handler
end
WorldMapFrame=flaky
assert(addon.worldMap:Attach()==false)
assert(addon.worldMap:Attach()==true and #flaky.providers==1 and #flaky.clicks==1)
local opened=0
flaky.IsShown=function() return false end
OpenWorldMap=function() opened=opened+1 end
assert(addon.worldMap:Open() and opened==1)
OpenWorldMap=nil
assert(addon.worldMap:Open()==false, 'do not claim an open without an opening API')
-- Secret map IDs must never be consumed by coordinate or quest operations.
local realGetID=flaky.GetMapID
issecretvalue=function(value) return value==777 end
flaky.mapID=777
assert(addon.worldMap:Refresh()==false)
assert(flaky.clicks[1](flaky,'LeftButton',.2,.2)==false)
flaky.GetMapID=realGetID; issecretvalue=nil
flaky.mapID=42
local legacyPlan=addon.Plan
addon.Plan=function() return {{id='walk',name='Walked',mapID=42,x=.1,y=.2,
  walkYards=55,walkStatus='partial-route'}},
  {{id='gap',name='Gap',mapID=42,x=.3,y=.4,walkStatus='unknown-route'}} end
observed={}
addon.worldMap:Refresh()
assert(pins[1].number.text=='P1' and pins[1].label.text:find('connector unverified',1,true) and
  pins[2].number.text=='U1' and pins[2].label.text:find('Unknown walking path',1,true),
  'map keeps uncertain destinations visible without claiming a walking path')
addon.Plan=legacyPlan
observed={}
addon.npcs={IsReady=function() return true end,
  LocationsOnMap=function(_, id)
    assert(id==42)
    return {{id='npc-900',npcID=900,name='Banker',category='Bank',
      source='questiedb-forever',mapID=42,x=.6,y=.4,phaseUnverified=true}}
  end}
addon.worldMap:Refresh()
assert(pins[3].number.text=='N1' and
  pins[3].label.text:find('QuestieDB candidate',1,true) and
  pins[3].label.text:find('phase',1,true),
  'map differentiates database spawn candidates from player-observed service locations')
for i=1,200 do
  observed[i]={id='loc-'..i,name='Observed '..i,mapID=42,x=(i-1)/200,y=.3}
end
addon.worldMap:Refresh()
assert(#addon.worldMap.pins == 120, 'marker display must be bounded')
print('world-map tests passed')
