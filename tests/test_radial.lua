local addon = {db={data={settings={wheelRadius=110, wheelIconSize=46}}}, ui={}}
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
addon.Print = function() end
local chunk = assert(loadfile("UI/RadialMenu.lua")); chunk("ErrandMaster", addon)
local wheel = addon.radial
assert(wheel:Open() and wheel.frame:IsShown())
assert(wheel.centerX == 960 and wheel.centerY == 540)
assert(#cursorCalls == 1 and cursorCalls[1]:find("ErrandMaster",1,true))
mouseY = 650; wheel.frame.scripts.OnUpdate(wheel.frame)
assert(wheel.selected == 1)
wheel.frame.scripts.OnMouseDown(wheel.frame, "LeftButton")
assert(#opened == 1 and opened[1] == "Repair")
assert(not wheel.frame:IsShown() and cursorCalls[#cursorCalls] == "restore")
mouseX,mouseY=960,540
assert(wheel:Open()); wheel.frame.scripts.OnUpdate(wheel.frame)
assert(wheel.selected == nil)
wheel.frame.scripts.OnMouseDown(wheel.frame, "LeftButton")
assert(#opened == 1 and not wheel.frame:IsShown())
assert(wheel:Open()); wheel.frame.scripts.OnKeyDown(wheel.frame, "ESCAPE")
assert(not wheel.frame:IsShown() and cursorCalls[#cursorCalls] == "restore")
mouseX,mouseY=5,8
assert(wheel:Open())
assert(wheel.centerX == 5 and wheel.centerY == 8)
wheel.frame.scripts.OnMouseDown(wheel.frame, "LeftButton")
assert(#opened == 1 and not wheel.frame:IsShown())
mouseX,mouseY=960,540
assert(wheel:Open())
wheel.frame.scripts.OnEvent(wheel.frame, "PLAYER_REGEN_DISABLED")
assert(not wheel.frame:IsShown() and cursorCalls[#cursorCalls] == "restore")
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
  assert(opened[#opened] == category and not wheel.frame:IsShown())
end
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
wheel:ShowSettings()
assert(wheel.settingsFrame:IsShown())
wheel.bindButton.scripts.OnClick(wheel.bindButton)
wheel.capture.scripts.OnKeyDown(wheel.capture, "F7")
assert(wheel.bindingLabel.text:find("F7",1,true))
assert(not wheel.capture:IsShown())
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
