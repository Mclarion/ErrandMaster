local addon = {}
local function loadModule(path) assert(loadfile(path))("ErrandMaster", addon) end
local textures={}
local function fakeFrame()
  local f = {scripts={}, shown=true, text=""}
  setmetatable(f, {__index=function(_, key)
    if key == "CreateFontString" then return function() return fakeFrame() end end
    if key == "CreateTexture" then
      return function(self, _, layer)
        local texture=fakeFrame()
        texture.parent,texture.layer=self,layer
        textures[#textures+1]=texture
        return texture
      end
    end
    if key == "SetSize" then return function(self,w,h) self.width,self.height=w,h end end
    if key == "SetTexture" then return function(self,path) self.texture=path end end
    if key == "SetVertexColor" then return function(self,...) self.color={...} end end
    if key == "SetBlendMode" then return function(self,mode) self.blend=mode end end
    if key == "SetScript" then return function(self, event, fn) self.scripts[event] = fn end end
    if key == "SetText" then return function(self, text) self.text = text end end
    if key == "GetText" then return function(self) return self.text end end
    if key == "GetWidth" then return function() return 1920 end end
    if key == "GetHeight" then return function() return 1080 end end
    if key == "GetEffectiveScale" then return function() return 1 end end
    if key == "Hide" then return function(self) self.shown = false end end
    if key == "Show" then return function(self) self.shown = true end end
    if key == "IsShown" then return function(self) return self.shown end end
    return function() end
  end})
  f.TitleText = {SetText=function() end}
  return f
end
local eventFrame
CreateFrame = function(kind, _, _, template)
  local frame = fakeFrame()
  if kind == "Frame" and not template and not eventFrame then eventFrame = frame end
  return frame
end
UIParent = fakeFrame()
UISpecialFrames = {}
local mouseX, mouseY = 960, 540
GetCursorPosition = function() return mouseX, mouseY end
SetCursor = function() return true end
InCombatLockdown = function() return false end
local messages = {}
DEFAULT_CHAT_FRAME = {AddMessage=function(_, msg) messages[#messages+1] = msg end}
SlashCmdList = {}
UnitFullName = function() return nil, nil end
GetZoneText = function() return "Test Zone" end
C_Map = {GetBestMapForUnit=function() return 10 end,
  GetPlayerMapPosition=function() return {GetXY=function() return .2,.3 end} end}
LibQuestieDB = {flavor={name='Forever'},Enum={npcFlags={BANKER=256}},
  RequireContract=function(version) assert(version==4); return true end,
  Support={Get=function() return {private={areaIdToUiMapId='return {[215]=10}'}} end},
  Npc={GetAllIds=function() return {900} end,
    npcFlags=function() return 256 end,
    spawns=function() return {[215]={{20,30}}} end,
    name=function() return 'Test Banker' end,
    friendlyToFaction=function() return 'AH' end,
    minLevel=function() return 20 end}}
UnitFactionGroup=function() return 'Alliance' end
for line in io.lines("ErrandMaster.toc") do
  if not line:match("^#") and line:match("%.lua$") then loadModule(line) end
end
assert(eventFrame and eventFrame.scripts.OnEvent)
eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "ErrandMaster")
assert(not addon.db.data)
UnitFullName = function() return "Test", "Realm" end
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_LOGIN")
assert(addon.db.data and SlashCmdList.ERRANDMASTER and SLASH_ERRANDMASTER1 == "/em", messages[#messages])
local header,halo
for _,texture in ipairs(textures) do
  if texture.parent==addon.ui.frame and texture.texture and
      texture.texture:find('PackLogo.blp',1,true) then header=texture end
  if texture.parent==addon.ui.frame and texture.texture and
      texture.texture:find('DestinationButtonGlow.blp',1,true) then halo=texture end
end
assert(header and halo and header.layer=='ARTWORK' and header.width<=21 and
  halo.layer=='BACKGROUND' and halo.width>=44 and halo.color[4]>=.85 and halo.blend=='ADD',
  'main-window logo keeps its border above an independent brighter glow')
assert(addon.destinations.frame and not addon.destinations.frame:IsShown(),
  'empty target sidebar stays hidden on first login')
assert(addon.ui.targetsButton and addon.ui.targetsButton.scripts.OnClick,
  'the main window exposes a Targets control')
addon.ui.targetsButton.scripts.OnClick(addon.ui.targetsButton)
assert(not addon.destinations.frame:IsShown(),
  'targets button cannot reveal an empty sidebar')
addon.ui.targetsButton.scripts.OnClick(addon.ui.targetsButton)
assert(not addon.destinations.frame:IsShown() and
  addon.db.data.settings.showDestinations==true,
  'an enabled but empty sidebar remains hidden')
GetProfessions=function() return 1,2 end
GetProfessionInfo=function(index) return index==1 and 'Mining' or 'Alchemy' end
local configured,source=addon:ProfessionFilters()
assert(source=='configured' and #configured==12 and configured[1]=='Alchemy' and
  configured[#configured]=='First Aid','unset primary picks include all primaries and common trades')
assert(addon.db:SetProfessionPick(1,'Mining') and addon.db:SetProfessionPick(2,'Alchemy'))
local chosen,chosenSource=addon:ProfessionFilters()
assert(chosenSource=='configured' and #chosen==5 and chosen[1]=='Mining' and
  chosen[2]=='Alchemy','two saved picks override all-primary default')
assert(addon.db:SetCommonProfession('Fishing',false))
local excluded=addon:ProfessionFilters()
assert(#excluded==4 and excluded[3]=='Cooking' and excluded[4]=='First Aid',
  'saved common-profession opt-out reaches route filtering')
assert(addon.db:SetCommonProfession('Fishing',true))
assert(addon.db:SetProfessionPick(1,nil) and addon.db:SetProfessionPick(2,nil))
GetProfessions=nil; GetProfessionInfo=nil
local allDefault,defaultSource=addon:ProfessionFilters()
assert(defaultSource=='configured' and #allDefault==12,
  'missing native profession API does not suppress configured dropdown defaults')
assert(addon.npcs.state=='indexing', 'provider loaded before ErrandMaster starts')
assert(addon.minimap and addon.minimap.Attach and addon.destinations and
  addon.destinations.Toggle, 'the boot harness loads every TOC module')
-- Actual boot hooks must feed the selected first row, including transient legs.
local oldActiveTarget,oldPlan=addon.ActiveTarget,addon.Plan
local stagedTarget={id='transit:1',transitForId='1',name='Flight master',mapID=10,x=.4,y=.5}
local delivered={}
local oldBridgeUpdate=addon.waypointUI and addon.waypointUI.Update
addon.ActiveTarget=function() return stagedTarget end
addon.Plan=function() return {stagedTarget},{} end
addon.waypointUI.Update=function(_,target,explicit)
  delivered[#delivered+1]={target=target,explicit=explicit}
end
addon:RevalidateNavigation({}, {})
assert(delivered[#delivered].target==stagedTarget and not delivered[#delivered].explicit,
  'periodic revalidation feeds the actual transient first row')
addon:NavigateNext()
assert(delivered[#delivered].target==stagedTarget and delivered[#delivered].explicit,
  'manual next publishes the selected row explicitly')
stagedTarget=nil
addon:RevalidateNavigation({}, {})
assert(delivered[#delivered].target==nil,
  'empty queue notifies bridge to clear only its owned session')
addon.ActiveTarget,addon.Plan=oldActiveTarget,oldPlan
addon.waypointUI.Update=oldBridgeUpdate
local priorRevalidate=addon.RevalidateNavigation
local lateChecks=0
addon.RevalidateNavigation=function() lateChecks=lateChecks+1 end
eventFrame.scripts.OnEvent(eventFrame,'ADDON_LOADED','WaypointUI')
assert(lateChecks==1, 'late Waypoint UI load schedules an immediate target sync')
addon.RevalidateNavigation=priorRevalidate

assert(addon.trails.bucket == addon.db:TrailBucket() and not addon.trails:IsEnabled(),
  'boot binds the current character without enabling movement recording')
assert(BINDING_NAME_ERRANDMASTER_WHEEL and type(ErrandMaster_OpenWheel) == "function")
assert(ErrandMaster_OpenWheel())
mouseY = 650
addon.radial.frame.scripts.OnUpdate(addon.radial.frame)
addon.radial.frame.scripts.OnMouseDown(addon.radial.frame, "LeftButton")
assert(addon.radial.submenu == "Services")
local bankTier=addon.radial.tiers[#addon.radial.tiers]
mouseX, mouseY = addon.radial.centerX + bankTier.radius*math.cos(bankTier.angles[1]),
  addon.radial.centerY + bankTier.radius*math.sin(bankTier.angles[1])
addon.radial.frame.scripts.OnUpdate(addon.radial.frame)
addon.radial.frame.scripts.OnMouseDown(addon.radial.frame, "LeftButton")
assert(addon.radial.submenu == "Bank")
local personal=addon.radial.tiers[#addon.radial.tiers]
mouseX,mouseY=addon.radial.centerX+personal.radius*math.cos(personal.angles[1]),
  addon.radial.centerY+personal.radius*math.sin(personal.angles[1])
addon.radial.frame.scripts.OnUpdate(addon.radial.frame)
addon.radial.frame.scripts.OnMouseDown(addon.radial.frame,"LeftButton")
assert(#addon.errands:All() == 1 and addon.errands:All()[1].category == "Bank")
assert(addon.errands:All()[1].origin == "suggested")
addon.errands:Delete(addon.errands:All()[1].id)
local oldWheelOpen=addon.radial.Open
local oldWheelShown=addon.radial.frame.IsShown
addon.radial.frame.IsShown=function() return true end
addon.radial.Open=function() return false end
local beforeWheelMessages=#messages
SlashCmdList.ERRANDMASTER('wheel')
assert(#messages==beforeWheelMessages,
  'closing an already shown wheel is not an unavailable error')
addon.radial.frame.IsShown=function() return false end
SlashCmdList.ERRANDMASTER('wheel')
assert(#messages==beforeWheelMessages+1 and
  messages[#messages]:find('Wheel unavailable',1,true),
  'a failed open from a hidden wheel still reports unavailability')
addon.radial.Open=oldWheelOpen
addon.radial.frame.IsShown=oldWheelShown
SlashCmdList.ERRANDMASTER("wheel settings")
assert(addon.addonSettings.frame:IsShown() and addon.addonSettings.bind,
  'wheel settings opens compact AddOns settings, not the old studio')
assert(addon.radial.capture == nil)
addon.addonSettings.bind.scripts.OnClick(addon.addonSettings.bind)
assert(addon.radial.capture and addon.radial.capture:IsShown(),
  'Bind wheel in AddOns settings activates capture without the old studio')
addon.radial.capture.scripts.OnKeyDown(addon.radial.capture, 'ESCAPE')
assert(not addon.radial.capture:IsShown())
local savedWindowKeys, originalSave = {}, addon.windowPosition.Save
addon.windowPosition.Save=function(_, _, key)
  savedWindowKeys[#savedWindowKeys+1]=key; return true
end
for _, target in ipairs({{addon.ui.frame,'main'}}) do
  target[1].scripts.OnDragStart(target[1])
  target[1].scripts.OnHide(target[1])
  assert(savedWindowKeys[#savedWindowKeys]==target[2] and
    rawget(target[1], 'errandMoving')==nil,
    'a hidden window saves its interrupted drag position: '..target[2]..
      ' got '..tostring(savedWindowKeys[#savedWindowKeys]))
end
addon.windowPosition.Save=originalSave
mouseY = 540
InCombatLockdown = function() return false end
CanMerchantRepair = function() return true end
eventFrame.scripts.OnEvent(eventFrame, "MERCHANT_SHOW")
assert(#addon.locations:All() == 0)
SlashCmdList.ERRANDMASTER("discover on")
eventFrame.scripts.OnEvent(eventFrame, "MERCHANT_SHOW")
assert(#addon.locations:All() == 2)
C_GossipInfo = {GetPoiForUiMapID=function() return 5 end,
  GetPoiInfo=function() return {name="Guard marker", position={GetXY=function() return .7,.7 end}} end}
SlashCmdList.ERRANDMASTER("poi repair")
assert(#addon.locations:All() == 3)
SlashCmdList.ERRANDMASTER("forget loc-3")
assert(#addon.locations:All() == 2)
UnitClass = function(unit)
  if unit == "player" or unit == "npc" then return "Hunter", "HUNTER" end
end
GetNumTrainerServices = function() return 3 end
UnitName = function(unit) return unit == "npc" and "Huntmaster" end
IsTradeskillTrainer = function() return false end
eventFrame.scripts.OnEvent(eventFrame, "TRAINER_SHOW")
assert(#addon.locations:All() == 3 and addon.locations:All()[3].category == "Hunter Trainer")
SlashCmdList.ERRANDMASTER("forget loc-4")
assert(#addon.locations:All() == 2)
C_Bank = {AreAnyBankTypesViewable=function() return true end}
eventFrame.scripts.OnEvent(eventFrame, "BANKFRAME_OPENED")
assert(#addon.locations:All() == 3 and addon.locations:All()[3].category == "Bank")
SlashCmdList.ERRANDMASTER("forget loc-5")
assert(#addon.locations:All() == 2)
SlashCmdList.ERRANDMASTER("locations")
SlashCmdList.ERRANDMASTER("discover off")
assert(not addon.db.data.settings.discoverServices)
assert(addon:Position() == 10)
local x, y = select(2, addon:Position())
assert(x == .2 and y == .3)
SlashCmdList.ERRANDMASTER("add")
addon.ui.name:SetText("Smith visit")
addon.ui.category:SetText("Repair")
addon.ui.map:SetText("10")
addon.ui.x:SetText("35")
addon.ui.y:SetText("30")
addon.ui:Save(false)
assert(#addon.errands:All() == 1)
addon.ui.name:SetText("Nearest observed repair")
addon.ui.map:SetText(""); addon.ui.x:SetText(""); addon.ui.y:SetText("")
addon.ui:Save(false)
local suggested = addon.route:Plan(addon.errands:All(), 10, .2, .3, true, addon.locations:All())
assert(#suggested == 2 and suggested[1].id == addon.errands:All()[2].id)
SlashCmdList.ERRANDMASTER("route")
SlashCmdList.ERRANDMASTER("next")
addon.ui:Select(addon.errands:All()[1].id)
addon.ui:Change("complete")
assert(addon.errands:All()[1].completed)
addon.ui:Change("complete")
assert(not addon.errands:All()[1].completed)
SlashCmdList.ERRANDMASTER("settings")
SlashCmdList.ERRANDMASTER("optimize")
SlashCmdList.ERRANDMASTER("debug")
SlashCmdList.ERRANDMASTER("help")
C_Map.GetMapWorldSize = function(id) assert(id == 10); return 1000, 500 end
local liveX, liveY = .2, .3
C_Map.GetPlayerMapPosition=function() return {GetXY=function() return liveX,liveY end} end
local movedRefreshes=0
local normalRefresh=addon.Refresh
addon.Refresh=function(self)
  movedRefreshes=movedRefreshes+1
  return normalRefresh(self)
end
assert(type(addon.MovementTick)=='function', 'movement must trigger route refresh without trail consent or an active waypoint')
assert(not addon:MovementTick())
liveX=.209
assert(not addon:MovementTick() and movedRefreshes==0, 'nine yards does not trigger replanning')
liveX=.211
assert(addon:MovementTick() and movedRefreshes==1, 'eleven yards triggers a route refresh')
local onTaxi=true
UnitOnTaxi=function() return onTaxi end
liveX=.4
assert(not addon:MovementTick() and movedRefreshes==1, 'do not replan during taxi travel')
onTaxi=false
assert(addon:MovementTick() and movedRefreshes==2, 'landing immediately re-evaluates the route')
onTaxi=true
assert(not addon:MovementTick())
onTaxi=false
C_Map.GetPlayerMapPosition=function() return nil end
assert(not addon:MovementTick() and movedRefreshes==2,
  'landing waits for a valid post-flight location rather than using stale coordinates')
C_Map.GetPlayerMapPosition=function() return {GetXY=function() return .4,.3 end} end
assert(addon:MovementTick() and movedRefreshes==3,
  'a valid post-flight sample replans once without a 10-yard requirement')
assert(not addon:MovementTick() and movedRefreshes==3)
addon.Refresh=normalRefresh
C_Map.GetPlayerMapPosition=function() return {GetXY=function() return .2,.3 end} end
UnitOnTaxi=nil
addon.movementOrigin={map=10,x=.2,y=.3}
-- Riding changes the nearest service, but does not rewrite the queued errand.
local auction=addon.errands:Add({name='Find auction house',category='Auction House',
  origin='suggested',scope='character'})
local oldAll, oldLocations, oldNpcsReady, oldNpcsLocations=addon.errands.All,
  addon.locations.All,addon.npcs.IsReady,addon.npcs.LocationsOnMap
local oldMode=addon.db.data.settings.routeMode
local oldMapServices=addon.npcs.mapServices
addon.npcs.mapServices={[10]={['Auction House']=true}}
addon.db.data.settings.routeMode='direct'
addon.errands.All=function() return {auction} end
addon.locations.All=function() return {} end
addon.npcs.IsReady=function() return true end
addon.npcs.LocationsOnMap=function(_,map)
  if map~=10 then return {} end
  return {{id='west-ah',name='West Auctioneer',category='Auction House',
    mapID=10,x=.25,y=.3},
    {id='east-ah',name='East Auctioneer',category='Auction House',
    mapID=10,x=.85,y=.3}}
end
local positions={.2,.8,.2,.8}
local candidateIds={}
C_Map.GetPlayerMapPosition=function() return {GetXY=function() return positions[1],.3 end} end
UnitIsMounted=function() return true end
addon.Refresh=function(self)
  local stops=self:Plan()
  candidateIds[#candidateIds+1]=stops[1] and stops[1].locationID
end
assert(addon:Plan()[1].locationID=='west-ah')
table.remove(positions,1)
assert(addon:MovementTick() and candidateIds[1]=='east-ah',
  'mounted movement beyond 50 yards switches current-map nearest auction candidate')
table.remove(positions,1)
assert(addon:MovementTick() and candidateIds[2]=='west-ah' and
  addon.errands:Get(auction.id)==auction,
  'returning switches back without replacing the queued auction errand')
local ridingTaxi=true
UnitOnTaxi=function() return ridingTaxi end
table.remove(positions,1)
assert(not addon:MovementTick() and #candidateIds==2,
  'taxi travel never selects a riding candidate in mid-flight')
ridingTaxi=false
assert(addon:MovementTick() and candidateIds[3]=='east-ah',
  'landing recomputes nearest auction candidate without a 50-yard sample')
addon.Refresh=normalRefresh
addon.errands.All,addon.locations.All=oldAll,oldLocations
addon.npcs.IsReady,addon.npcs.LocationsOnMap=oldNpcsReady,oldNpcsLocations
addon.npcs.mapServices=oldMapServices
addon.db.data.settings.routeMode=oldMode
addon.errands:Delete(auction.id)
UnitIsMounted=nil; UnitOnTaxi=nil
C_Map.GetPlayerMapPosition=function() return {GetXY=function() return .2,.3 end} end
addon.movementOrigin={map=10,x=.2,y=.3}
C_QuestLog = {
  GetQuestsOnMap=function(id) return id == 10 and {{questID=501, mapID=10, x=.4, y=.5}} or {} end,
  GetLogIndexForQuestID=function(id) return id == 501 and 1 or nil end,
  GetInfo=function() return {title="Active quest", questID=501, isHeader=false} end,
}
addon.quests:Invalidate()
SlashCmdList.ERRANDMASTER("quest 501")
SlashCmdList.ERRANDMASTER("walking off") -- Explicitly test the legacy direct-estimate mode.
SlashCmdList.ERRANDMASTER("walking status")
assert(messages[#messages]:find("Direct-distance estimates",1,true),
  "walking status reports the currently selected mode")
local ordered, deferred, map, px, py = addon:Plan()
assert(map == 10 and px == .2 and py == .3 and #ordered == 3 and #deferred == 0)
local quest
for _, item in ipairs(ordered) do if item.questID == 501 then quest = item end end
assert(quest and quest.directYards and quest.directYards > 0)
local hasDistance = false
for _, row in ipairs(addon.ui.rows) do
  if row.text and row.text:find("yd direct", 1, true) then hasDistance = true end
end
assert(hasDistance and addon.ui.summary.text:find("yd direct", 1, true),
  "the main route window must label straight-line distance")
assert(not addon.ui.zone.text:find('|',1,true) and
  not addon.ui.summary.text:find('|',1,true),
  'rendered panel headings must not contain unescaped WoW formatting pipes')
SlashCmdList.ERRANDMASTER("walking on")
SlashCmdList.ERRANDMASTER("walking status")
assert(messages[#messages]:find("Observed-walk routing",1,true))
local noRoute, unknown = addon:Plan()
assert(#noRoute == 3 and #unknown == 0 and noRoute[1].walkStatus == 'unknown-route' and
  noRoute[1].walkYards == nil and noRoute[1].walkWaypoints == nil,
  'missing walk evidence exposes local coordinates without inventing a walk')
local removed=0
addon.navigation.provider={RemoveWaypoint=function(_, handle)
  assert(handle=="old-em"); removed=removed+1 end}
addon.navigation.handle="old-em"
SlashCmdList.ERRANDMASTER("next")
assert(removed==1 and addon.navigation.handle==nil,
  "no route must clear only the previous ErrandMaster TomTom handle")
local originalPlan=addon.Plan
addon.Plan=function() return {{id='partial',name='Test',mapID=10,x=.4,y=.5,
  walkStatus='partial-route',walkYards=15}},{} end
addon.navigation.provider={RemoveWaypoint=function(_, handle)
  assert(handle=="old-em"); removed=removed+1 end}
addon.navigation.handle="old-em"
SlashCmdList.ERRANDMASTER("next")
assert(removed==2 and addon.navigation.handle==nil,
  "partial route must clear a stale ErrandMaster waypoint")
addon.ui:Refresh()
assert(addon.ui.rows[1].text:find('link unknown',1,true),
  'partial observed yards must visibly warn that the destination connector is unknown')
addon.Plan=originalPlan
eventFrame.scripts.OnUpdate(eventFrame,.1) -- Finish indexing before timing navigation.
assert(addon.npcs:IsReady() and #addon.npcs:LocationsOnMap(10,'Bank')==1)
local baseNearby=addon.zoneSearch.Nearby
-- Exercise legacy hint fallback separately from the integrated sequence tests.
local baseRouteContext=addon.zoneSearch.RouteContext
addon.zoneSearch.RouteContext=nil
addon.zoneSearch.Nearby=function(_,map,x,y,wanted)
  assert(map==10 and x==.2 and y==.3 and wanted=='Bank')
  return {{name='Border Banker',category='Bank',mapID=20,zoneName='Border',
    x=.1,y=.5,directYards=150}}
end
local baseRoute=addon.route.Plan
addon.route.Plan=function() return {},{{id='border',name='Find bank',category='Bank'}} end
local _,borderDeferred=addon:Plan()
assert(borderDeferred[1].nearbyZoneCandidate and
  borderDeferred[1].nearbyZoneCandidate.zoneName=='Border',
  'unrouted nearby zone candidate remains deferred')
addon.destinations:Refresh()
assert(addon.destinations.lines[1]:find('Border',1,true) and
  addon.destinations.lines[1]:find('Border - Unknown Path',1,true) and
  addon.destinations.lines[1]:find('From you: Unknown',1,true) and
  addon.destinations.lines[1]:find('From route start: Unknown',1,true),
  'an unlocated nearby-zone hint must not become a measured destination')
addon.route.Plan=baseRoute
addon.zoneSearch.Nearby=baseNearby
addon.zoneSearch.Nearby=function(_,map,x,y,wanted,radius,limit)
  assert(map==10 and wanted=='Auction House' and radius==10000 and limit==1)
  return {{name='Projected Auctioneer',category='Auction House',mapID=20,
    zoneName='Border',x=.1,y=.5,directYards=3300}}
end
addon.route.Plan=function() return {},{{id='auction-deferred',name='Find auction',
  category='Auction House'}} end
local _,auctionDeferred=addon:Plan()
assert(auctionDeferred[1].nearbyZoneCandidate and
  auctionDeferred[1].nearbyZoneCandidate.directYards==3300 and
  not auctionDeferred[1].mapID,
  'projected cross-zone auction spawn is a direct hint, not an invented waypoint')
local pendingAuction=addon.errands:Add({name='Pending auction',category='Auction House',
  origin='suggested',scope='character'})
local heldPlan=addon.Plan
addon.Plan=function() return {},{{id=pendingAuction.id,name=pendingAuction.name,
  category='Auction House',nearbyZoneCandidate=auctionDeferred[1].nearbyZoneCandidate}} end
addon.db.data.characters[addon.db.character].activeErrandId=pendingAuction.id
local savedPrint=addon.Print
local auctionMessages={}
addon.Print=function(_,text) auctionMessages[#auctionMessages+1]=text end
addon:NavigateNext()
assert(table.concat(auctionMessages,' '):find('3300 yd straight-line',1,true) and
  table.concat(auctionMessages,' '):find('route unknown',1,true) and
  not addon.navigation.handle,
  'explicit next reports the projected auction hint without a cross-zone arrow or walking claim')
addon.Print=savedPrint; addon.Plan=heldPlan
addon.db.data.characters[addon.db.character].activeErrandId=nil
addon.errands:Delete(pendingAuction.id)
addon.route.Plan=baseRoute
addon.zoneSearch.Nearby=baseNearby
C_Map.GetMapInfo=function(id) return {name=id==20 and 'Ironforge' or 'Test Zone'} end
NumTaxiNodes=function() return 2 end
TaxiNodeGetType=function(i) return i==2 and 'REACHABLE' or 'CURRENT' end
TaxiNodeName=function(i) return i==2 and 'Ironforge' or 'Test Zone' end
eventFrame.scripts.OnEvent(eventFrame,'TAXIMAP_OPENED')
assert(addon.taxiAdvice:ForMap(20)=='Ironforge')
addon.route.Plan=function() return {},{{id='trainer',name='Shaman trainer',
  category='Class Trainer',mapID=20}} end
local _,flightDeferred=addon:Plan()
assert(flightDeferred[1].taxiFlightNode=='Ironforge',
  'open taxi-map reachability gives an optional flight leg to the named map')
addon.destinations:Refresh()
assert(addon.destinations.lines[1]:find('Ironforge',1,true) and
  addon.destinations.lines[1]:find('Shaman trainer',1,true) and
  addon.destinations.lines[1]:find('Walk Unknown',1,true),
  'the panel retains the requested trainer and keeps the post-flight walk unverified')
eventFrame.scripts.OnEvent(eventFrame,'TAXIMAP_CLOSED')
assert(not addon.taxiAdvice:ForMap(20))
addon.route.Plan=baseRoute
addon.zoneSearch.RouteContext=baseRouteContext
NumTaxiNodes=nil; TaxiNodeGetType=nil; TaxiNodeName=nil
C_Map.GetMapInfo=nil
assert(addon.ui.npcButton and addon.npcs:IsReady() and addon.npcs:Status().limited and
  addon.ui.npcStatus.text=='NPC catalog: incomplete',
  'NPC-only fixture is usable but exposes missing inventory coverage and a catalog entry point')
addon.navigation.provider={RemoveWaypoint=function(_, handle)
  assert(handle=="moving-em"); removed=removed+1 end}
addon.navigation.handle="moving-em"
addon.Plan=function() return {},{} end -- The player has left recorded evidence.
eventFrame.scripts.OnUpdate(eventFrame,1)
assert(removed==2, 'waypoint revalidation waits for the scheduled tick')
eventFrame.scripts.OnUpdate(eventFrame,1)
assert(removed==3 and addon.navigation.handle==nil,
  'periodic validation clears an obsolete waypoint even if trails are off')
addon.navigation.provider={RemoveWaypoint=function(_, handle)
  assert(handle=='manual-em'); removed=removed+1 end}
addon.navigation.handle='manual-em'
assert(addon.ui.clearWaypointButton and addon.ui.clearWaypointButton.scripts.OnClick)
addon.ui.clearWaypointButton.scripts.OnClick(addon.ui.clearWaypointButton)
assert(removed==4 and addon.navigation.handle==nil,
  'explicit clear removes only the ErrandMaster waypoint')
addon.navigation.provider={RemoveWaypoint=function() error('TomTom temporarily unavailable') end}
addon.navigation.handle='retry-em'
addon.ui.clearWaypointButton.scripts.OnClick(addon.ui.clearWaypointButton)
assert(addon.navigation.handle=='retry-em' and
  addon.ui.message.text:find('Could not clear',1,true),
  'a failed TomTom removal keeps the owned handle and reports failure')
addon.navigation.provider={RemoveWaypoint=function() removed=removed+1 end}
assert(addon.navigation:Clear() and removed==5)
addon.Plan=originalPlan
-- Active targets use an owned native indicator; TomTom remains untouched.
local selected=addon.errands:Add({name='Bank interaction',category='Bank',
  mapID=10,x=.2,y=.3,origin='suggested',scope='character'})
local originalRefresh, originalMapSize = addon.Refresh, C_Map.GetMapWorldSize
local oldTomTom = TomTom
local added, cleared, title = 0, 0
TomTom={AddWaypoint=function(_, map, x, y, options)
    assert(map==10 and x==.2 and y==.3 and options.crazy)
    added=added+1; title=options.title; return 'active-target'
  end,
  RemoveWaypoint=function(_, handle)
    assert(handle=='active-target'); cleared=cleared+1; return true
  end}
addon.Plan=function() return {{id=selected.id,name=selected.name,category='Bank',
  mapID=10,x=.2,y=.3,walkStatus='unknown-route'}},{} end
addon.Refresh=function(self) self:RevalidateNavigation() end
assert(addon.navigation.paused, 'Clear pin must remain cleared across refreshes')
addon:RevalidateNavigation()
assert(added==0 and addon.navigation.handle==nil)
assert(addon:ActivateTarget(selected.id) and added==0 and
  addon.navigation.target.id==selected.id and addon.navigation.handle==nil,
  'activation resumes native navigation without creating TomTom pins')
addon:RevalidateNavigation()
assert(added==0, 'periodic refresh leaves external waypoints alone')
assert(not addon:FinishTargetOnInteraction('MAIL_SHOW') and not selected.completed)
C_Map.GetMapWorldSize=function() return 1000,1000 end
assert(not addon:FinishTargetOnInteraction('BANKFRAME_OPENED') and not selected.completed,
  'generic nearby service UI never completes or removes a queue target')
assert(addon.db.data.characters[addon.db.character].activeErrandId==selected.id and
  cleared==0 and addon.navigation.handle==nil,
  'service UI does not advance the queue')
addon.errands:Delete(selected.id) -- Keep the original NPC and pin fixture counts unchanged.
local probe=addon.errands:Add({name='No TomTom available', category='Bank',
  mapID=10, x=.2, y=.3, scope='character'})
addon.Plan=function() return {{id=probe.id, name=probe.name, category='Bank',
  mapID=10, x=.2, y=.3, walkStatus='unknown-route'}},{} end
local previousNext, previousPrint=addon.navigation.Next, addon.Print
local notices={}
addon.navigation.Next=function() return false end
addon.Print=function(_, text) notices[#notices+1]=text end
addon:NavigateNext()
assert(not table.concat(notices,' '):find('TomTom points directly',1,true),
  'missing TomTom must not be described as an active arrow')
addon.navigation.Next, addon.Print=previousNext, previousPrint
TomTom=nil
notices={}
addon.Print=function(_, text) notices[#notices+1]=text end
addon:NavigateNext()
assert(table.concat(notices,' '):find('Native direct-bearing',1,true),
  'native navigation does not depend on TomTom being present')
TomTom={profile={arrow={enable=false}},
  AddWaypoint=function() return 'hidden-arrow' end,
  RemoveWaypoint=function() return true end}
notices={}
addon:NavigateNext()
assert(table.concat(notices,' '):find('Native direct-bearing',1,true),
  'external arrow profile does not disable the native indicator')
addon.navigation:Clear()
addon.db.data.settings.useTomTom=false
notices={}
addon:NavigateNext()
assert(table.concat(notices,' '):find('Native direct-bearing',1,true),
  'legacy TomTom setting does not disable native navigation')
addon.db.data.settings.useTomTom=true
addon.Print=previousPrint
TomTom=oldTomTom
addon.errands:Delete(probe.id)
local unlocated=addon.errands:Add({name='Unlocated bank', category='Bank',
  origin='suggested', scope='character'})
addon.Plan=function() return {{id=unlocated.id, name=unlocated.name,
  category='Bank'}},{} end
assert(addon:ActivateTarget(unlocated.id))
assert(not addon:FinishTargetOnInteraction('BANKFRAME_OPENED') and
  not unlocated.completed, 'service type alone cannot prove an unlocated target was reached')
addon.errands:Delete(unlocated.id)
addon.db.data.characters[addon.db.character].activeErrandId=nil
local resolved=addon.errands:Add({name='Resolved banker', category='Bank',
  origin='suggested', scope='character'})
addon.Plan=function() return {{id=resolved.id, name=resolved.name, category='Bank',
  npcID=501, mapID=10, x=.2, y=.3}},{} end
local oldUnitGUID=UnitGUID
UnitGUID=function() return 'Creature-0-0-0-0-502-00000001' end
assert(addon:ActivateTarget(resolved.id))
assert(not addon:FinishTargetOnInteraction('BANKFRAME_OPENED') and
  not resolved.completed, 'resolved NPC identity must reject a different banker at same spot')
UnitGUID=function() return nil end
assert(not addon:FinishTargetOnInteraction('BANKFRAME_OPENED') and
  not resolved.completed, 'missing NPC identity cannot be replaced by map proximity')
UnitGUID=function() return 'Creature-0-0-0-0-501-00000001' end
assert(not addon:FinishTargetOnInteraction('BANKFRAME_OPENED') and not resolved.completed,
  'even exact NPC service identity is not a Done action under remove-on-arrival')
UnitGUID=oldUnitGUID
addon.errands:Delete(resolved.id)
addon.db.data.characters[addon.db.character].activeErrandId=nil
local service=addon.errands:Add({name='Service-only banker', category='Bank',
  npcID=501, mapID=10, x=.2, y=.3, scope='character'})
addon.Plan=function() return {{id=service.id, name=service.name,
  category='Bank', npcID=501, mapID=10, x=.2, y=.3}},{} end
UnitGUID=function() return 'Creature-0-0-0-0-501-00000001' end
assert(addon:ActivateTarget(service.id))
assert(not addon:FinishTargetOnInteraction('GOSSIP_SHOW') and not service.completed,
  'speaking to a banker alone does not prove bank service was opened')
UnitGUID=oldUnitGUID
addon.errands:Delete(service.id)
addon.db.data.characters[addon.db.character].activeErrandId=nil
local visit=addon.errands:Add({name='Visit banker', category='NPC Visit',
  npcID=501, scope='character'})
addon.Plan=function() return {},{{id=visit.id, name=visit.name,
  category='NPC Visit', npcID=501}} end
assert(addon:ActivateTarget(visit.id))
assert(not addon:FinishTargetOnInteraction('GOSSIP_SHOW') and not visit.completed,
  'an NPC visit still requires the correct NPC identity')
UnitGUID=function() return 'Creature-0-0-0-0-501-00000001' end
assert(not addon:FinishTargetOnInteraction('GOSSIP_SHOW') and not visit.completed,
  'speaking to a matched NPC is not proof of queue arrival or completion')
UnitGUID=oldUnitGUID
addon.errands:Delete(visit.id)
addon.Plan=originalPlan; addon.Refresh=originalRefresh
C_Map.GetMapWorldSize=originalMapSize; TomTom=oldTomTom
SlashCmdList.ERRANDMASTER("walking off")
SlashCmdList.ERRANDMASTER("npcs bank")
assert(messages[#messages-2]:find('Test Banker',1,true) and
  messages[#messages]:find('/em npcs find',1,true))
SlashCmdList.ERRANDMASTER("npcs unsupported")
for i=#messages-2,#messages do
  assert(#messages[i]<=110, 'NPC help must be short enough for narrow game chat')
  local body=messages[i]:match('ErrandMaster:|r (.*)')
  assert(body and not body:find('|',1,true),
    'literal pipe characters are parsed as formatting codes by WoW chat')
end
SlashCmdList.ERRANDMASTER("npc add 900")
assert(addon.errands:All()[4].npcID==900 and addon.errands:All()[4].mapID==nil,
  'queued NPC uses the live provider locations, not a stale copied coordinate')
assert(addon.ui.mapButton, "the main window needs a map access button")
SlashCmdList.ERRANDMASTER("pin My marker")
assert(#addon.errands:All() == 5 and addon.errands:All()[5].category == "Pin")
local beforeWheel=addon:Plan()
addon.radial:SelectCategory('Bank')
local afterWheel=addon:Plan()
local routedBank=false
for _,stop in ipairs(afterWheel) do
  if stop.category=='Bank' and stop.npcID==900 and
      stop.locationSource=='questiedb-forever' then routedBank=true end
end
assert(#afterWheel==#beforeWheel+1 and routedBank,
  'adding a wheel service recalculates route using current QuestieDB candidates')
SlashCmdList.ERRANDMASTER("map") -- Native map may be unavailable in a bare test harness.
local refreshedAfterCombat = 0
local oldRefresh = addon.worldMap.Refresh
addon.worldMap.Refresh = function() refreshedAfterCombat=refreshedAfterCombat+1 end
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(refreshedAfterCombat == 1, "map overlay must retry after combat")
addon.worldMap.Refresh = oldRefresh
SlashCmdList.ERRANDMASTER("trails on")
assert(addon.trails:IsEnabled())
local trailBucket=addon.db:TrailBucket()
trailBucket.nodes[1]={id='trail-1'}
trailBucket.edges[1]={a='trail-1',b='trail-2'}
SlashCmdList.ERRANDMASTER("trails status")
assert(messages[#messages]:find('1/400',1,true) and
  messages[#messages]:find('1/1200',1,true) and
  messages[#messages]:find('on',1,true), 'status shows bounded current-character evidence')
GetTime=function() return 100 end
SlashCmdList.ERRANDMASTER("trails clear")
assert(#trailBucket.nodes==1 and #trailBucket.edges==1,
  'clear request must not delete data before confirmation')
SlashCmdList.ERRANDMASTER("trails confirm")
assert(#trailBucket.nodes==0 and #trailBucket.edges==0 and not addon.trails:IsEnabled(),
  'confirmation clears only bound character evidence and stops recording')
local priorRevalidate=addon.RevalidateNavigation
local rechecks=0
addon.navigation.target={id='active',mapID=10,x=.3,y=.3}
addon.RevalidateNavigation=function() rechecks=rechecks+1 end
eventFrame.scripts.OnUpdate(eventFrame,1)
assert(rechecks==0,'native navigation replanning is bounded, not every frame')
eventFrame.scripts.OnUpdate(eventFrame,1.1)
assert(rechecks==1,'active native target ticks with recording disabled')
eventFrame.scripts.OnUpdate(eventFrame,.1)
assert(rechecks==1,'no repeated graph rebuild before the next tick')
addon.navigation.target=nil
addon.RevalidateNavigation=priorRevalidate
SlashCmdList.ERRANDMASTER("trails confirm")
assert(not addon.trails:IsEnabled(), 'confirmation cannot be reused')
trailBucket.nodes[1]={id='saved'}
SlashCmdList.ERRANDMASTER("trails clear")
GetTime=function() return 131 end
SlashCmdList.ERRANDMASTER("trails confirm")
assert(#trailBucket.nodes==1, 'expired deletion request retains evidence')
addon.db.data.trails['Test-Realm']='corrupt retained trail'
addon.ui.frame=nil -- Simulate initialization against existing corrupt trail data.
eventFrame.scripts.OnEvent(eventFrame, 'PLAYER_LOGIN')
assert(addon.ui.frame and SlashCmdList.ERRANDMASTER and
  addon.db.data.trails['Test-Realm']=='corrupt retained trail' and
  not addon.trails:IsEnabled() and #addon.trails.nodes==0,
  'corrupt trail storage disables only trail functionality and preserves saved bytes')
addon.db.data.trails['Test-Realm']=trailBucket
assert(addon.trails:Bind())
issecretvalue = function(value) return value == 10 end
assert(addon:Position() == nil)
C_Map = setmetatable({}, {__index=function() error("protected map namespace") end})
assert(addon:Position() == nil)
issecretvalue = function() return false end
local touched = 0
local protectedVector = setmetatable({}, {__index=function()
  touched = touched + 1; error("protected vector indexed")
end})
issecrettable = function(value) return value == protectedVector end
C_Map = {GetBestMapForUnit=function() return 10 end,
  GetPlayerMapPosition=function() return protectedVector end}
assert(addon:Position() == 10 and touched == 0,
  "reject protected position before member access")
local originalDiagnostics=addon.npcs.Diagnostics
addon.npcs.Diagnostics=function(_,map,service)
 assert(map==10 and service=='Food Vendor')
 return {state='ready',candidates=0,factionExcluded=2,inventoryEvidence='not-evidenced',
   issues={['item-class']=3},mapLimited=true,mapIssues={['invalid-coordinate']=2}}
end
local beforeDiagnostics=#messages
SlashCmdList.ERRANDMASTER('npcs explain Food Vendor')
local diagnosticOutput=table.concat(messages,'\n',beforeDiagnostics+1)
assert(diagnosticOutput:find('not%-evidenced') and diagnosticOutput:find('item%-class=3'),
 'NPC explanation must expose absent evidence and bounded failure counters')
assert(diagnosticOutput:find('Map issues: invalid%-coordinate=2'),
 'explanation must distinguish map-specific reasons from global failures')
addon.npcs.Diagnostics=originalDiagnostics
local originalStatus=addon.npcs.Status
addon.npcs.Status=function() return {state='indexing',normalizing=true,normalizedEntries=80,processed=0,total=0} end
local beforeNormalization=#messages
SlashCmdList.ERRANDMASTER('npcs status')
assert(table.concat(messages,'\n',beforeNormalization+1):find('normalizing provider IDs'),
 'status must distinguish unfinished ID totals from an empty catalog')
addon.npcs.Status=originalStatus
addon.discovery.lastReport={saved={Vendor=true},partial=true,failures={['Food Vendor']='not-saved'}}
local beforeDiscovery=#messages
SlashCmdList.ERRANDMASTER('discover status')
local discoveryOutput=table.concat(messages,'\n',beforeDiscovery+1)
assert(discoveryOutput:find('Food Vendor=not%-saved') and discoveryOutput:find('Vendor'),
 'discovery status exposes partial saved observations')
print("boot mock passed")
dofile('tests/test_init_queue_regression.lua')
