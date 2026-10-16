local legacySlots = {}
for i, category in ipairs({'Repair','Bank','Auction House','Mailbox','Vendor',
  'Class Trainer','Custom'}) do
  legacySlots[i] = {type='category',category=category}
end
local addon = {db={data={settings={wheelRadius=110, wheelIconSize=46,
  wheelSlots=legacySlots}}}, ui={}}
local function fakeFrame()
  local f = {scripts={}, shown=false}
  setmetatable(f, {__index=function(_, key)
    if key == "CreateFontString" or key == "CreateTexture" then return function() return fakeFrame() end end
    if key == "SetScript" then return function(self, event, fn) self.scripts[event] = fn end end
    if key == "SetSize" then return function(self, w, h) self.w,self.h=w,h end end
    if key == "GetWidth" then return function(self) return self.w end end
    if key == "GetHeight" then return function(self) return self.h end end
    if key == "SetPoint" then return function(self, ...) self.point={...} end end
    if key == "Show" then return function(self) self.shown=true end end
    if key == "Hide" then return function(self) self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end end
    if key == "IsShown" then return function(self) return self.shown end end
    if key == "SetText" then return function(self, value) self.text=value end end
    if key == "GetText" then return function(self) return self.text end end
    if key == "SetTexture" then return function(self, value) self.texture=value end end
    if key == "SetRotation" then return function(self, value) self.rotation=value end end
    return function() end
  end})
  f.TitleText = {SetText=function() end}
  return f
end
UIParent = fakeFrame(); UIParent.w=1920; UIParent.h=1080
UIParent.GetEffectiveScale = function() return 1 end
CreateFrame = function() return fakeFrame() end
UISpecialFrames = {}
local mouseX, mouseY = 960, 540
GetCursorPosition = function() return mouseX, mouseY end
local cursorCalls = {}
SetCursor = function(path) cursorCalls[#cursorCalls+1] = path or "restore"; return true end
InCombatLockdown = function() return false end
local opened = {}
addon.ui.OpenCategory = function(_, category) opened[#opened+1]=category end
local printed = {}
addon.Print = function(_, value) printed[#printed+1] = value end
local chunk = assert(loadfile("UI/RadialMenu.lua")); chunk("ErrandMaster", addon)
local wheel = addon.radial
assert(wheel:Open() and wheel.frame:IsShown())
assert(wheel.capture == nil, 'wheel studio was never opened')
assert(wheel:StartCapture() and wheel.capture:IsShown() and
  wheel.capture.scripts.OnKeyDown and wheel.capture.scripts.OnMouseDown,
  'AddOns settings binding captures a key without opening the old studio')
wheel.capture.scripts.OnKeyDown(wheel.capture, 'ESCAPE')
assert(not wheel.capture:IsShown(), 'Escape cancels binding capture')
assert(wheel.slots[1].sector and wheel.slots[1].glow and
  wheel.slots[1].sector.texture:find('WheelSector07.blp',1,true))
assert(wheel.slots[1].glow.texture:find('WheelGlow07.blp',1,true))
assert(wheel.trim.texture:find('WheelTrim07.blp',1,true) and
  wheel.centerArt.texture:find('WheelCenter.blp',1,true),
  'decorative gilt rim and map hub follow the active slot count')
assert(wheel.slots[1].texture.texture:find('PackRepair.blp',1,true) and
  wheel.slots[3].texture.texture:find('PackAuctionHouse.blp',1,true) and
  wheel.slots[4].texture.texture:find('PackMailbox.blp',1,true) and
  wheel.slots[5].texture.texture:find('ServiceVendor.blp',1,true),
  'service slots use readable bundled glyphs rather than red question marks')
assert(wheel.slots[1].label.text=='Repair' and
  wheel.detailText.text:find('Choose a service',1,true))
assert(wheel.slots[2].sector.rotation<0)
addon.db.data.settings.wheelArtReversed=true
wheel:Layout()
assert(wheel.slots[2].sector.rotation>0)
addon.db.data.settings.wheelArtReversed=false
wheel.slots[2].sector.SetRotation=function() error('not supported') end
wheel:Layout()
assert(not wheel.slots[1].sector.shown and not wheel.slots[2].glow.shown and
  wheel.slots[2].texture.shown, 'unsupported rotation falls back to usable icons')
wheel.slots[2].sector.SetRotation=nil
UnitClass = function() return "Hunter", "HUNTER" end
wheel:Layout()
assert(wheel.slots[2].texture.texture:find("Textures\\PackBank.blp", 1, true))
assert(wheel.slots[6].texture.texture:find("Textures\\ClassHunter.blp", 1, true))
assert(wheel.slots[6].label.text:find("Hunter",1,true))
addon.Position=function() return 10,.1,.1 end
addon.MapWorldSize=function() return 1000,1000 end
addon.discovery={PlayerClass=function() return 'Hunter' end}
addon.npcs={IsReady=function() return true end,
  Nearest=function(_,map,x,y,wanted)
    assert(map==10 and x==.1 and y==.1)
    if wanted=='Bank' then return {{name='Banker One',directYards=40}} end
    if wanted=='Hunter Trainer' then return {{name='Hunter Tutor',directYards=55}} end
    return {}
  end}
wheel:Layout()
assert(wheel.slots[2].label.text=='Bank' and
  not wheel.slots[6].label.text:find('Hunter Tutor',1,true),
  'previews belong in the detail card, not around crowded wedges')
wheel:SetSelection(2)
assert(wheel.detailText.text:find('~40 yd direct',1,true))
addon.ProfessionFilters=function() return {'Alchemy'} end
addon.db.data.settings.wheelSlots={}
for i,category in ipairs({'Repair','Bank','Auction House','Mailbox','Vendor',
  'Class Trainer','Profession Trainer'}) do
  addon.db.data.settings.wheelSlots[i]={type='category',category=category}
end
local originalNearest=addon.npcs.Nearest
addon.npcs.Nearest=function(_,map,x,y,wanted)
  if wanted=='Mining Trainer' then return {{name='Mining Coach',directYards=10}} end
  if wanted=='Alchemy Trainer' then return {{name='Alchemy Coach',directYards=100}} end
  return originalNearest(_,map,x,y,wanted)
end
wheel:Layout()
wheel:SetSelection(7)
assert(wheel.detailText.text:find('Alchemy Coach',1,true),
  'wheel profession preview respects character-selected profession')
addon.db.data.settings.wheelSlots=legacySlots
addon.npcs=nil
assert(wheel.centerX == 960 and wheel.centerY == 540)
assert(#cursorCalls == 0, 'native cursor must stay visible for bag-to-wheel dragging')
mouseY = 650; wheel.frame.scripts.OnUpdate(wheel.frame)
assert(wheel.selected == 1)
wheel.frame.scripts.OnMouseDown(wheel.frame, "LeftButton")
assert(#opened == 1 and opened[1] == "Repair")
assert(not wheel.frame:IsShown() and #cursorCalls == 0)
mouseX,mouseY=960,540
assert(wheel:Open()); wheel.frame.scripts.OnUpdate(wheel.frame)
assert(wheel.selected == nil)
wheel.frame.scripts.OnMouseDown(wheel.frame, "LeftButton")
assert(#opened == 1 and not wheel.frame:IsShown())
assert(wheel:Open()); wheel.frame.scripts.OnKeyDown(wheel.frame, "ESCAPE")
assert(not wheel.frame:IsShown() and #cursorCalls == 0)
SetCursor=function() error('cursor unavailable') end
assert(wheel:Open() and wheel.frame:IsShown())
wheel:Close()
SetCursor=function(path) cursorCalls[#cursorCalls+1] = path or 'restore'; return true end
mouseX,mouseY=5,8
assert(wheel:Open())
assert(wheel.centerX >= wheel.radius and wheel.centerY >= wheel.radius,
  'full wheel must remain on screen by the edge')
wheel.frame.scripts.OnMouseDown(wheel.frame, "LeftButton")
assert(#opened == 1 and not wheel.frame:IsShown())
mouseX,mouseY=960,540
assert(wheel:Open())
wheel.frame.scripts.OnEvent(wheel.frame, "PLAYER_REGEN_DISABLED")
assert(not wheel.frame:IsShown() and #cursorCalls == 0)
-- Changing the key is a user-initiated, out-of-combat binding operation.
local expected = {"Bank", "Auction House", "Mailbox", "Vendor", "Class Trainer", "Custom"}
for i, category in ipairs(expected) do
  mouseX, mouseY = 960, 540
  assert(wheel:Open())
  local angle = math.pi/2 - i * 2*math.pi/7
  mouseX, mouseY = 960 + 110*math.cos(angle), 540 + 110*math.sin(angle)
  wheel.frame.scripts.OnUpdate(wheel.frame)
  assert(wheel.selected == i+1, "incorrect highlighted wheel category")
  wheel.frame.scripts.OnMouseDown(wheel.frame, "LeftButton")
  if category == "Bank" or category == "Vendor" or category == "Mailbox" or
      category == "Custom" then
    assert(wheel.frame:IsShown() and wheel.submenu == category)
    wheel:Close()
  else
    assert(opened[#opened] == category and not wheel.frame:IsShown())
  end
end
local queued = {}
addon.errands = {
  All=function() return queued end,
  Add=function(_, details)
    queued[#queued+1] = details
    return details
  end,
}
addon.Refresh = function() end
mouseX, mouseY = 960, 540
assert(wheel:Open()); mouseY = 650
wheel.frame.scripts.OnMouseDown(wheel.frame, "LeftButton")
assert(#queued == 1 and queued[1].category == "Repair" and
  queued[1].origin == "suggested" and queued[1].scope == "character")
assert(wheel:Open()); mouseY = 650
wheel.frame.scripts.OnMouseDown(wheel.frame, "LeftButton")
assert(#queued == 1, "a repeat selection must not add duplicate pending errands")
mouseX, mouseY = 960, 540
assert(wheel:Open())
local vendorAngle = math.pi/2 - 4*2*math.pi/7
mouseX, mouseY = 960 + 110*math.cos(vendorAngle), 540 + 110*math.sin(vendorAngle)
wheel.frame.scripts.OnMouseDown(wheel.frame, "LeftButton")
assert(wheel.submenu == "Vendor" and wheel.frame:IsShown())
local ammoAngle = math.pi/2 - 4*math.pi/6
mouseX = wheel.centerX + 110*math.cos(ammoAngle)
mouseY = wheel.centerY + 110*math.sin(ammoAngle)
wheel.frame.scripts.OnMouseDown(wheel.frame, "LeftButton")
assert(#queued == 2 and queued[2].category == "Ammo Vendor" and not wheel.frame:IsShown())
addon.errands = nil
mouseX, mouseY = 960, 540
local currentKey
GetBindingKey = function() return currentKey end
GetBindingAction = function(key) return key == currentKey and "ERRANDMASTER_WHEEL" or "" end
SetBinding = function(key, action)
  if action then assert(action == "ERRANDMASTER_WHEEL"); currentKey = key
  elseif key == currentKey then currentKey = nil end
  return true
end
GetCurrentBindingSet = function() return 1 end
SaveBindings = function() end -- Native API has no documented success return.
IsShiftKeyDown = function() return false end
IsControlKeyDown = function() return false end
IsAltKeyDown = function() return false end
local professions={}
addon.db.AddProfession=function(_,name) professions[#professions+1]=name; return true end
addon.db.RemoveProfession=function(_,name)
  for i,entry in ipairs(professions) do
    if entry==name then table.remove(professions,i); return true end
  end
end
addon.db.ClearProfessions=function() professions={} end
addon.ProfessionFilters=function()
  return professions,#professions>0 and 'manual' or 'unavailable'
end
wheel:ShowSettings()
assert(wheel.settingsFrame:IsShown())
assert(wheel.professionInput and wheel.professionStatus and wheel.professionAddButton,
  'wheel settings expose manual profession selection')
wheel.professionInput:SetText('Alchemy')
wheel.professionAddButton.scripts.OnClick(wheel.professionAddButton)
assert(#professions==1 and professions[1]=='Alchemy' and
  wheel.professionStatus.text:find('Alchemy',1,true))
wheel.professionRemoveButton.scripts.OnClick(wheel.professionRemoveButton)
assert(#professions==0)
wheel.professionInput:SetText('Mining')
wheel.professionAddButton.scripts.OnClick(wheel.professionAddButton)
wheel.professionAutoButton.scripts.OnClick(wheel.professionAutoButton)
assert(#professions==0)
wheel.bindButton.scripts.OnClick(wheel.bindButton)
wheel.capture.scripts.OnKeyDown(wheel.capture, "F7")
assert(wheel.bindingLabel.text:find("F7",1,true))
assert(not wheel.capture:IsShown())
-- Mouse clicks must enter the same native binding path, not cancel capture.
wheel.bindButton.scripts.OnClick(wheel.bindButton)
wheel.capture.scripts.OnMouseDown(wheel.capture, "Button4")
assert(currentKey == "BUTTON4" and not wheel.capture:IsShown())
assert(wheel.bindingLabel.text:find("BUTTON4", 1, true))
wheel.bindButton.scripts.OnClick(wheel.bindButton)
wheel.capture.scripts.OnKeyDown(wheel.capture, "F7")
assert(currentKey == "F7" and not wheel.capture:IsShown())
issecretvalue = function(value) return value == "secret-modifier" end
IsShiftKeyDown = function() return "secret-modifier" end
IsControlKeyDown = function() return false end
IsAltKeyDown = function() return false end
wheel.bindButton.scripts.OnClick(wheel.bindButton)
local protected, protectedError = pcall(wheel.capture.scripts.OnMouseDown,
  wheel.capture, "Button5")
assert(protected, tostring(protectedError))
assert(currentKey == "F7" and not wheel.capture:IsShown())
assert(wheel.status.text:find("Modifier state unavailable", 1, true))
issecretvalue = nil
IsShiftKeyDown = nil
wheel.bindButton.scripts.OnClick(wheel.bindButton)
assert(pcall(wheel.capture.scripts.OnMouseDown, wheel.capture, "Button5"))
assert(currentKey == "F7" and not wheel.capture:IsShown())
IsShiftKeyDown = function() error("protected modifier") end
wheel.bindButton.scripts.OnClick(wheel.bindButton)
assert(pcall(wheel.capture.scripts.OnMouseDown, wheel.capture, "Button5"))
assert(currentKey == "F7" and not wheel.capture:IsShown())
IsShiftKeyDown = function() return false end
local bindingLookup = GetBindingAction
GetBindingAction = function(key)
  if key == "F8" then return "MOVEFORWARD" end
  return bindingLookup(key)
end
wheel.bindButton.scripts.OnClick(wheel.bindButton)
wheel.capture.scripts.OnKeyDown(wheel.capture, "F8")
assert(currentKey == "F7" and wheel.capture:IsShown())
wheel.capture.scripts.OnKeyDown(wheel.capture, "ESCAPE")
assert(not wheel.capture:IsShown())
SaveBindings = function() error("save refused") end
wheel.bindButton.scripts.OnClick(wheel.bindButton)
wheel.capture.scripts.OnKeyDown(wheel.capture, "F9")
assert(currentKey == "F7" and not wheel.capture:IsShown())
SaveBindings = function() end
local originalSetBinding = SetBinding
-- A sparse binding result must not skip the secondary key when replacing it.
local originalGetBindingKey, originalGetBindingAction = GetBindingKey, GetBindingAction
local sparseSecond, sparseNew = "F6", nil
GetBindingKey = function()
  if sparseNew then return sparseNew, sparseSecond end
  return nil, sparseSecond
end
GetBindingAction = function(key)
  return (key == sparseSecond or key == sparseNew) and "ERRANDMASTER_WHEEL" or ""
end
SetBinding = function(key, action)
  if key == "F6" and action == nil then sparseSecond = nil
  elseif key == "F9" and action == "ERRANDMASTER_WHEEL" then sparseNew = key
  elseif key == "F9" and action == nil then sparseNew = nil
  elseif key == "F6" and action == "ERRANDMASTER_WHEEL" then sparseSecond = key end
  return true
end
wheel.bindButton.scripts.OnClick(wheel.bindButton)
wheel.capture.scripts.OnKeyDown(wheel.capture, "F9")
assert(sparseNew == "F9" and sparseSecond == nil and not wheel.capture:IsShown(),
  "replacement must remove a secondary-only previous binding")
GetBindingKey, GetBindingAction, SetBinding = originalGetBindingKey, originalGetBindingAction, originalSetBinding
SetBinding = function(key, action)
  if key == "F7" and not action then return nil end
  return originalSetBinding(key, action)
end
wheel.bindButton.scripts.OnClick(wheel.bindButton)
wheel.capture.scripts.OnKeyDown(wheel.capture, "F9")
assert(currentKey == "F7" and not wheel.capture:IsShown())
SetBinding = originalSetBinding
-- Settings allow all three entry types; selecting numeric entries only reports them.
assert(wheel.slotNumber and wheel.slotType and wheel.slotValue and wheel.applySlotButton)
wheel.slotNumber:SetText("2"); wheel.slotType:SetText("category")
wheel.slotValue:SetText("Supply run")
wheel.applySlotButton.scripts.OnClick(wheel.applySlotButton)
assert(addon.db.data.settings.wheelSlots[2].category == "Supply run")
assert(wheel:Open())
assert(wheel.slots[2].label.text:find("Supply run",1,true))
mouseX,mouseY=960+110*math.cos(math.pi/2-2*math.pi/7),540+110*math.sin(math.pi/2-2*math.pi/7)
wheel.frame.scripts.OnMouseDown(wheel.frame, "LeftButton")
assert(opened[#opened] == "Supply run")
C_Spell = {GetSpellInfo=function(id)
  assert(id == 1234)
  return {name="Safe Spell", iconID=135000}
end}
C_Macro = {GetMacroName=function(id)
  if id == 7 then return "Safe Macro" end
end}
RunMacro = function() error("macro executed") end
RunMacroText = function() error("macro text executed") end
CastSpell = function() error("spell cast") end
local function assign(slot, kind, value)
  wheel.slotNumber:SetText(slot); wheel.slotType:SetText(kind)
  wheel.slotValue:SetText(value); wheel.applySlotButton.scripts.OnClick(wheel.applySlotButton)
end
assign("1", "spell", "1234")
assert(addon.db.data.settings.wheelSlots[1].id == 1234)
mouseX,mouseY=960,540
assert(wheel:Open() and wheel.slots[1].label.text:find("Safe Spell",1,true))
assert(wheel.slots[1].texture.texture == 135000)
mouseY=650; wheel.frame.scripts.OnMouseDown(wheel.frame, "LeftButton")
assert(printed[#printed]:find("Safe Spell",1,true) and printed[#printed]:find("not executed",1,true))
assign("3", "macro", "7")
assert(addon.db.data.settings.wheelSlots[3].id == 7)
mouseX,mouseY=960,540
assert(wheel:Open() and wheel.slots[3].label.text:find("Safe Macro",1,true))
local angle = math.pi/2-2*2*math.pi/7
mouseX,mouseY=960+110*math.cos(angle),540+110*math.sin(angle)
wheel.frame.scripts.OnMouseDown(wheel.frame, "LeftButton")
assert(printed[#printed]:find("Safe Macro",1,true) and printed[#printed]:find("not executed",1,true))
local previous = addon.db.data.settings.wheelSlots[3]
assign("8", "spell", "1234")
assign("3", "macro", "8") -- Missing macro must not replace slot.
assign("3", "macro", "7; /cast x")
assign("3", "spell", "0")
assign("3", "category", "bad\nname")
assert(addon.db.data.settings.wheelSlots[3] == previous)
InCombatLockdown = function() return true end
assign("3", "category", "Combat change")
assert(addon.db.data.settings.wheelSlots[3] == previous)
InCombatLockdown = function() return false end
C_Spell, C_Macro = nil, nil
assign("4", "spell", "1234")
assign("5", "macro", "7")
mouseX,mouseY=960,540
assert(wheel:Open() and wheel.slots[4].label.text:find("Spell #1234",1,true)
  and wheel.slots[5].label.text:find("Macro #7",1,true))
wheel:Close()
local protectedNamespace = setmetatable({}, {__index=function() error("protected API namespace") end})
C_Spell, C_Macro = protectedNamespace, protectedNamespace
assert(wheel:Open() and wheel.slots[4].label.text:find("Spell #1234",1,true)
  and wheel.slots[5].label.text:find("Macro #7",1,true),
  "blocked metadata APIs must leave wheel selection usable")
wheel:Close()
assign("6", "macro", "7")
assert(addon.db.data.settings.wheelSlots[6].id == 7)
C_Spell, C_Macro = nil, nil
local secretID = "555"
issecretvalue = function(value) return value == secretID end
assign("4", "spell", secretID)
assert(addon.db.data.settings.wheelSlots[4].id == 1234)
issecretvalue = nil
wheel.capture.SetPropagateKeyboardInput = function() error("restricted") end
wheel.bindButton.scripts.OnClick(wheel.bindButton)
assert(not wheel.capture:IsShown())
wheel.capture.EnableKeyboard = function() error("protected keyboard") end
wheel.bindButton.scripts.OnClick(wheel.bindButton)
assert(not wheel.capture:IsShown())
InCombatLockdown = function() return true end
wheel.bindButton.scripts.OnClick(wheel.bindButton)
assert(not wheel.capture:IsShown())
print("radial interaction tests passed")
