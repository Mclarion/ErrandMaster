local _, addon = ...
addon.radial = {}
local wheel = addon.radial
local ACTION = "ERRANDMASTER_WHEEL"
local CURSOR = "Interface\\AddOns\\ErrandMaster\\Textures\\HiddenCursor.blp"
local categories = {"Repair", "Bank", "Auction House", "Mailbox", "Vendor",
  "Class Trainer", "Custom"}
local icon = "Interface\\Icons\\INV_Misc_QuestionMark"
local directions = {}
for i = 1, #categories do
  local angle = math.pi / 2 - (i - 1) * 2 * math.pi / #categories
  directions[i] = {math.cos(angle), math.sin(angle)}
end

local function usable(value)
  return value ~= nil and (not issecretvalue or not issecretvalue(value))
end
local function outOfCombat()
  if not usable(InCombatLockdown) or type(InCombatLockdown) ~= "function" then return false end
  local ok, result = pcall(InCombatLockdown)
  return ok and usable(result) and result == false
end
local function cursorPosition()
  if not usable(GetCursorPosition) or type(GetCursorPosition) ~= "function" then return end
  local ok, x, y = pcall(GetCursorPosition)
  if not ok or not usable(x) or not usable(y) or
      type(x) ~= "number" or type(y) ~= "number" then return end
  local valid, scale, width, height = pcall(function()
    return UIParent:GetEffectiveScale(), UIParent:GetWidth(), UIParent:GetHeight()
  end)
  if not valid or not usable(scale) or not usable(width) or not usable(height) or
      type(scale) ~= "number" or type(width) ~= "number" or type(height) ~= "number" or
      scale <= 0 or width <= 0 or height <= 0 then return end
  return x / scale, y / scale, width, height
end
local function control(parent, title, x, y, width, action)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 24)
  b:SetPoint("TOPLEFT", x, y)
  b:SetText(title)
  b:SetScript("OnClick", action)
  return b
end
local function caption(parent, title, x, y)
  local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f:SetPoint("TOPLEFT", x, y)
  f:SetText(title)
  return f
end

function wheel:Create()
  if self.frame then return end
  local frame = CreateFrame("Frame", "ErrandMasterWheel", UIParent)
  frame:SetAllPoints(UIParent)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:EnableMouse(true)
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:SetScript("OnEvent", function() wheel:Close() end)
  frame:SetScript("OnUpdate", function() wheel:UpdateHighlight() end)
  frame:SetScript("OnMouseDown", function(_, mouse)
    if mouse ~= "LeftButton" then wheel:Close(); return end
    wheel:UpdateHighlight()
    local category = wheel.selected and categories[wheel.selected]
    wheel:Close()
    if category then addon.ui:OpenCategory(category) end
  end)
  frame:SetScript("OnKeyDown", function(_, key)
    if key == "ESCAPE" then wheel:Close() end
  end)
  frame:SetScript("OnHide", function() wheel:RestoreCursor() end)
  self.frame = frame
  self.slots = {}
  for i, name in ipairs(categories) do
    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetTexture(icon)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetText(name)
    self.slots[i] = {texture=texture, label=text}
  end
  local center = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  center:SetText("×")
  self.centerLabel = center
  frame:Hide()
  if UISpecialFrames then table.insert(UISpecialFrames, "ErrandMasterWheel") end
end
function wheel:Layout()
  if not self.frame then return end
  local settings = addon.db.data.settings
  local radius, iconSize = settings.wheelRadius, settings.wheelIconSize
  self.centerLabel:ClearAllPoints()
  self.centerLabel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX, self.centerY)
  for i, slot in ipairs(self.slots) do
    local vector = directions[i]
    slot.texture:SetSize(iconSize, iconSize)
    slot.texture:ClearAllPoints()
    slot.texture:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
      self.centerX + vector[1]*radius, self.centerY + vector[2]*radius)
    slot.label:ClearAllPoints()
    slot.label:SetPoint("TOP", slot.texture, "BOTTOM", 0, -3)
  end
end
function wheel:SetSelection(index)
  if self.selected == index then return end
  self.selected = index
  for i, slot in ipairs(self.slots) do
    if i == index then
      slot.texture:SetVertexColor(1, .82, .25)
      slot.texture:SetAlpha(1)
      slot.label:SetTextColor(1, .82, .25)
    else
      slot.texture:SetVertexColor(.7, .8, 1)
      slot.texture:SetAlpha(.8)
      slot.label:SetTextColor(.9, .9, .9)
    end
  end
  self.centerLabel:SetText(index and categories[index] or "×")
end
function wheel:UpdateHighlight()
  if not self.frame or not self.frame:IsShown() then return end
  local x, y = cursorPosition()
  if not x then self:SetSelection(nil); return end
  local dx, dy = x - self.centerX, y - self.centerY
  local deadZone = math.max(28, addon.db.data.settings.wheelIconSize * .7)
  if dx*dx + dy*dy < deadZone*deadZone then self:SetSelection(nil); return end
  local best, score = nil, -math.huge
  for i, vector in ipairs(directions) do
    local dot = dx*vector[1] + dy*vector[2]
    if dot > score then best, score = i, dot end
  end
  self:SetSelection(best)
end
function wheel:RestoreCursor()
  if self.cursorAttempted and type(SetCursor) == "function" then pcall(SetCursor, nil) end
  self.cursorAttempted = nil
end
function wheel:Close()
  if self.frame and self.frame:IsShown() then self.frame:Hide() end
  self:RestoreCursor()
  self.selected = nil
end
function wheel:Open()
  if not outOfCombat() then return false end
  self:Create()
  if self.frame:IsShown() then self:Close(); return false end
  local x, y = cursorPosition()
  if not x then return false end
  -- Keep the cancel/dead zone exactly under the cursor, even at screen edges.
  self.centerX, self.centerY = x, y
  self:Layout()
  self:SetSelection(0) -- Force an initial unselected render.
  self:SetSelection(nil)
  self.frame:Show()
  if type(SetCursor) == "function" then
    self.cursorAttempted = true
    pcall(SetCursor, CURSOR)
  end
  return true
end

function wheel:Notice(message)
  if self.status then self.status:SetText(message) end
end
function wheel:StopCapture()
  if not self.capture then return end
  pcall(self.capture.EnableKeyboard, self.capture, false)
  self.capture:Hide()
end
function wheel:BindingText()
  if type(GetBindingKey) ~= "function" then return "Key: unavailable (use WoW Key Bindings)" end
  local ok, key = pcall(GetBindingKey, ACTION)
  if not ok or (key and not usable(key)) then return "Key: unavailable (use WoW Key Bindings)" end
  return "Key: " .. (key or "not set")
end
function wheel:StartCapture()
  if not outOfCombat() then self:Notice("Change bindings out of combat."); return end
  if not self.capture then return end
  local ok = pcall(function()
    self.capture:EnableKeyboard(true)
    self.capture:SetPropagateKeyboardInput(false)
  end)
  if not ok then
    self:StopCapture()
    self:Notice("Key capture unavailable; use WoW Key Bindings.")
    return
  end
  self.capture:Show()
  self:Notice("Press a free key; Escape cancels.")
end
function wheel:BindKey(key)
  if key == "ESCAPE" then self:StopCapture(); self:Notice("Binding canceled."); return end
  if not outOfCombat() then self:StopCapture(); self:Notice("Change bindings out of combat."); return end
  if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or
      key == "LALT" or key == "RALT" then return end
  if type(key) ~= "string" or not key:match("^[A-Z0-9]+$") then
    self:Notice("Use a keyboard key supported by WoW."); return
  end
  local modifiers = ""
  if IsShiftKeyDown and IsShiftKeyDown() then modifiers = modifiers .. "SHIFT-" end
  if IsControlKeyDown and IsControlKeyDown() then modifiers = modifiers .. "CTRL-" end
  if IsAltKeyDown and IsAltKeyDown() then modifiers = modifiers .. "ALT-" end
  key = modifiers .. key
  if type(GetBindingAction) ~= "function" or type(SetBinding) ~= "function" or
      type(SaveBindings) ~= "function" or type(GetCurrentBindingSet) ~= "function" then
    self:StopCapture(); self:Notice("Binding API unavailable; use WoW Key Bindings."); return
  end
  local ok, action = pcall(GetBindingAction, key)
  if not ok or (action and not usable(action)) then
    self:StopCapture(); self:Notice("Binding lookup unavailable."); return
  end
  if action and action ~= "" and action ~= ACTION then
    self:Notice(key .. " is already bound. Press another key or Escape."); return
  end
  local oldOK, oldKey, secondKey = pcall(GetBindingKey, ACTION)
  if not oldOK or (oldKey and not usable(oldKey)) or
      (secondKey and not usable(secondKey)) then
    self:StopCapture(); self:Notice("Binding lookup unavailable."); return
  end
  if oldKey == key and not secondKey then
    self:StopCapture(); self:Notice("Already bound to " .. key .. "."); return
  end
  local modeOK, mode = pcall(GetCurrentBindingSet)
  if not modeOK or not usable(mode) or (mode ~= 1 and mode ~= 2) then
    self:StopCapture(); self:Notice("Binding set unavailable."); return
  end
  local bound, result = pcall(SetBinding, key, ACTION)
  if not bound or not result then
    self:StopCapture(); self:Notice("Binding rejected; use WoW Key Bindings."); return
  end
  local function rollback()
    pcall(SetBinding, key)
    if oldKey then pcall(SetBinding, oldKey, ACTION) end
    if secondKey then pcall(SetBinding, secondKey, ACTION) end
  end
  for i = 1, 2 do
    local prior = i == 1 and oldKey or secondKey
    if prior and prior ~= key then
      local removed, removal = pcall(SetBinding, prior)
      if not removed or not removal then
        rollback()
        self:StopCapture(); self:Notice("Could not replace existing key; use WoW Key Bindings.")
        return
      end
    end
  end
  local keysOK, first, second = pcall(GetBindingKey, ACTION)
  if not keysOK or (first ~= key and second ~= key) or
      (first and first ~= key) or (second and second ~= key) then
    rollback()
    self:StopCapture(); self:Notice("Binding replacement not confirmed; use WoW Key Bindings.")
    return
  end
  local saved, savedResult = pcall(SaveBindings, mode)
  local verified, newAction = pcall(GetBindingAction, key)
  if not saved or savedResult == false or not verified or
      not usable(newAction) or newAction ~= ACTION then
    rollback()
    self:StopCapture()
    self:Notice("Could not save binding; use WoW Key Bindings.")
    return
  end
  self:StopCapture()
  self.bindingLabel:SetText("Key: " .. key)
  self:Notice("Wheel key set: " .. key .. ".")
end
function wheel:RefreshSettings()
  if not self.settingsFrame then return end
  local settings = addon.db.data.settings
  self.sizeLabel:SetText(string.format("Wheel radius: %d  |  Icon size: %d",
    settings.wheelRadius, settings.wheelIconSize))
  self.bindingLabel:SetText(self:BindingText())
end
function wheel:ShowSettings()
  if not self.settingsFrame then
    local frame = CreateFrame("Frame", "ErrandMasterWheelSettings", UIParent,
      "BasicFrameTemplateWithInset")
    frame:SetSize(365, 285)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnHide", function() wheel:StopCapture() end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:SetScript("OnEvent", function() wheel:StopCapture() end)
    frame:SetClampedToScreen(true)
    frame.TitleText:SetText("ErrandMaster - Wheel settings")
    self.settingsFrame = frame
    self.bindingLabel = caption(frame, "", 22, -43)
    self.bindButton = control(frame, "Set wheel key", 22, -72, 150,
      function() wheel:StartCapture() end)
    self.status = caption(frame, "Use WoW Key Bindings if direct capture is unavailable.", 22, -108)
    self.sizeLabel = caption(frame, "", 22, -150)
    local function adjust(field, delta, minimum, maximum)
      local settings = addon.db.data.settings
      settings[field] = math.max(minimum, math.min(maximum, settings[field] + delta))
      wheel:RefreshSettings()
    end
    control(frame, "Radius -", 22, -178, 78,
      function() adjust("wheelRadius", -10, 80, 200) end)
    control(frame, "Radius +", 105, -178, 78,
      function() adjust("wheelRadius", 10, 80, 200) end)
    control(frame, "Icon -", 192, -178, 72,
      function() adjust("wheelIconSize", -4, 32, 72) end)
    control(frame, "Icon +", 269, -178, 72,
      function() adjust("wheelIconSize", 4, 32, 72) end)
    control(frame, "Preview wheel", 22, -219, 155,
      function() wheel:Open() end)
    self.capture = CreateFrame("Frame", nil, frame)
    self.capture:SetAllPoints(frame)
    self.capture:EnableKeyboard(false)
    self.capture:SetScript("OnKeyDown", function(_, key) wheel:BindKey(key) end)
    self.capture:SetScript("OnMouseDown", function() wheel:StopCapture(); wheel:Notice("Binding canceled.") end)
    self.capture:Hide()
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "ErrandMasterWheelSettings") end
  end
  self:RefreshSettings()
  self.settingsFrame:Show()
end
