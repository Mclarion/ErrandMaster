local addon = {}
local function loadModule(path) assert(loadfile(path))("ErrandMaster", addon) end
local function fakeFrame()
  local f = {scripts={}, shown=true, text=""}
  setmetatable(f, {__index=function(_, key)
    if key == "CreateFontString" or key == "CreateTexture" then
      return function() return fakeFrame() end
    end
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
assert(addon.destinations.frame and addon.destinations.frame:IsShown(),
  'the separate right-side targets panel is visible on first login')
assert(addon.ui.targetsButton and addon.ui.targetsButton.scripts.OnClick,
  'the main window exposes a Targets control')
addon.ui.targetsButton.scripts.OnClick(addon.ui.targetsButton)
assert(not addon.destinations.frame:IsShown() and
  addon.db.data.settings.showDestinations==false)
addon.ui.targetsButton.scripts.OnClick(addon.ui.targetsButton)
assert(addon.destinations.frame:IsShown() and
  addon.db.data.settings.showDestinations==true)
GetProfessions=function() return 1,2 end
GetProfessionInfo=function(index) return index==1 and 'Mining' or 'Alchemy' end
local automatic,source=addon:ProfessionFilters()
assert(source=='auto' and #automatic==2 and automatic[1]=='Mining')
assert(addon.db:AddProfession('Fishing'))
local manual,manualSource=addon:ProfessionFilters()
assert(manualSource=='manual' and #manual==1 and manual[1]=='Fishing',
  'explicit character preference overrides optional client profession detection')
addon.db:ClearProfessions()
GetProfessions=nil; GetProfessionInfo=nil
local unavailable,unavailableSource=addon:ProfessionFilters()
assert(unavailableSource=='unavailable' and #unavailable==0)
assert(addon.npcs.state=='indexing', 'provider loaded before ErrandMaster starts')
assert(addon.minimap and addon.minimap.Attach and addon.destinations and
  addon.destinations.Toggle, 'the boot harness loads every TOC module')
assert(addon.trails.bucket == addon.db:TrailBucket() and not addon.trails:IsEnabled(),
  'boot binds the current character without enabling movement recording')
assert(BINDING_NAME_ERRANDMASTER_WHEEL and type(ErrandMaster_OpenWheel) == "function")
assert(ErrandMaster_OpenWheel())
mouseY = 650
addon.radial.frame.scripts.OnUpdate(addon.radial.frame)
addon.radial.frame.scripts.OnMouseDown(addon.radial.frame, "LeftButton")
assert(addon.radial.submenu == "Bank")
mouseX, mouseY = addon.radial.centerX, addon.radial.centerY + addon.radial.radius
addon.radial.frame.scripts.OnUpdate(addon.radial.frame)
addon.radial.frame.scripts.OnMouseDown(addon.radial.frame, "LeftButton")
assert(#addon.errands:All() == 1 and addon.errands:All()[1].category == "Bank")
assert(addon.errands:All()[1].origin == "suggested")
addon.errands:Delete(addon.errands:All()[1].id)
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
liveX=.24
assert(not addon:MovementTick() and movedRefreshes==0, '40 yards does not trigger replanning')
liveX=.251
assert(addon:MovementTick() and movedRefreshes==1, '51 yards triggers a route refresh')
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
  'a valid post-flight sample replans once without a 50-yard requirement')
assert(not addon:MovementTick() and movedRefreshes==3)
addon.Refresh=normalRefresh
C_Map.GetPlayerMapPosition=function() return {GetXY=function() return .2,.3 end} end
UnitOnTaxi=nil
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
assert(#noRoute == 0 and #unknown == 3 and unknown[1].walkStatus == "unknown-route",
  "missing walk evidence must not silently fall back to a direct route")
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
  addon.destinations.lines[1]:find('direct',1,true),
  'the target panel labels an unknown border route as a direct-distance hint')
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
  addon.destinations.lines[1]:find('walk unknown',1,true),
  'the panel retains the requested trainer and keeps the post-flight walk unverified')
eventFrame.scripts.OnEvent(eventFrame,'TAXIMAP_CLOSED')
assert(not addon.taxiAdvice:ForMap(20))
addon.route.Plan=baseRoute
NumTaxiNodes=nil; TaxiNodeGetType=nil; TaxiNodeName=nil
C_Map.GetMapInfo=nil
assert(addon.ui.npcButton and addon.ui.npcStatus.text=='NPC catalog: ready',
  'main window shows the provider index state and a catalog entry point')
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
-- Active targets follow an owned TomTom arrow; unknown walking stays explicit.
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
assert(addon:ActivateTarget(selected.id) and added==1 and
  title:find('walking path unverified',1,true) and
  addon.navigation.handle=='active-target', 'activation resumes a direct, labeled arrow')
addon:RevalidateNavigation()
assert(added==1, 'periodic refresh does not duplicate the owned waypoint')
assert(not addon:FinishTargetOnInteraction('MAIL_SHOW') and not selected.completed)
C_Map.GetMapWorldSize=function() return 1000,1000 end
assert(addon:FinishTargetOnInteraction('BANKFRAME_OPENED') and selected.completed)
assert(addon.db.data.characters[addon.db.character].activeErrandId==nil and
  cleared==1 and addon.navigation.handle==nil,
  'interacting at the matched bank marks it done and advances the arrow')
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
assert(addon:FinishTargetOnInteraction('BANKFRAME_OPENED') and resolved.completed,
  'matching service interaction and resolved NPC identity complete the target')
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
assert(addon:FinishTargetOnInteraction('GOSSIP_SHOW') and visit.completed,
  'explicit NPC Visit completes when speaking to the matched NPC')
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
print("boot mock passed")
