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
loadModule("Core/Database.lua")
loadModule("Core/Errands.lua")
loadModule("Data/ServiceLocations.lua")
loadModule("Data/Discovery.lua")
loadModule("Data/Quests.lua")
loadModule("Routing/RoutePlanner.lua")
loadModule("Routing/Navigation.lua")
loadModule("UI/RadialMenu.lua")
loadModule("UI/WorldMap.lua")
loadModule("UI/MainWindow.lua")
loadModule("Core/Init.lua")
assert(eventFrame and eventFrame.scripts.OnEvent)
eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "ErrandMaster")
assert(not addon.db.data)
UnitFullName = function() return "Test", "Realm" end
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_LOGIN")
assert(addon.db.data and SlashCmdList.ERRANDMASTER and SLASH_ERRANDMASTER1 == "/em", messages[#messages])
assert(BINDING_NAME_ERRANDMASTER_WHEEL and type(ErrandMaster_OpenWheel) == "function")
assert(ErrandMaster_OpenWheel())
mouseY = 650
addon.radial.frame.scripts.OnUpdate(addon.radial.frame)
addon.radial.frame.scripts.OnMouseDown(addon.radial.frame, "LeftButton")
assert(addon.ui.category:GetText() == "Repair" and addon.ui.frame:IsShown())
SlashCmdList.ERRANDMASTER("wheel settings")
assert(addon.radial.settingsFrame:IsShown() and addon.radial.bindButton)
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
C_QuestLog = {
  GetQuestsOnMap=function(id) return id == 10 and {{questID=501, mapID=10, x=.4, y=.5}} or {} end,
  GetLogIndexForQuestID=function(id) return id == 501 and 1 or nil end,
  GetInfo=function() return {title="Active quest", questID=501, isHeader=false} end,
}
addon.quests:Invalidate()
SlashCmdList.ERRANDMASTER("quest 501")
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
assert(addon.ui.mapButton, "the main window needs a map access button")
SlashCmdList.ERRANDMASTER("pin My marker")
assert(#addon.errands:All() == 4 and addon.errands:All()[4].category == "Pin")
SlashCmdList.ERRANDMASTER("map") -- Native map may be unavailable in a bare test harness.
local refreshedAfterCombat = 0
local oldRefresh = addon.worldMap.Refresh
addon.worldMap.Refresh = function() refreshedAfterCombat=refreshedAfterCombat+1 end
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(refreshedAfterCombat == 1, "map overlay must retry after combat")
addon.worldMap.Refresh = oldRefresh
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
