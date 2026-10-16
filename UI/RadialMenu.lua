local _, addon = ...
addon.radial = {}
local wheel = addon.radial
local ACTION = "ERRANDMASTER_WHEEL"
local CURSOR = "Interface\\AddOns\\ErrandMaster\\Textures\\HiddenCursor.blp"
local categories = {"Repair", "Bank", "Auction House", "Mailbox", "Vendor",
  "Class Trainer", "Custom"}
local vendors = {"Vendor", "Ammo Vendor", "Reagent Vendor", "Food Vendor",
  "Profession Vendor", "Custom", "Back"}
local quickServices = {Repair=true, Bank=true, ["Auction House"]=true,
  Mailbox=true, Vendor=true, ["Class Trainer"]=true,
  ["Profession Trainer"]=true, ["Ammo Vendor"]=true,
  ["Reagent Vendor"]=true, ["Food Vendor"]=true, ["Profession Vendor"]=true}
local icon = "Interface\\Icons\\INV_Misc_QuestionMark"
local assetRoot = "Interface\\AddOns\\ErrandMaster\\Textures\\"
local classes = {DEATHKNIGHT="Death Knight", DEMONHUNTER="Demon Hunter",
  DRUID="Druid", EVOKER="Evoker", HUNTER="Hunter", MAGE="Mage",
  MONK="Monk", PALADIN="Paladin", PRIEST="Priest", ROGUE="Rogue",
  SHAMAN="Shaman", WARLOCK="Warlock", WARRIOR="Warrior"}
local palettes = {Azure={.42, .76, 1}, Ember={1, .48, .24},
  Violet={.78, .55, 1}, Slate={.75, .83, .85}}

local function usable(value)
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret then return false end
  end
  if value == nil then return false end
  if type(value) == "table" and type(issecrettable) == "function" then
    local ok, secret = pcall(issecrettable, value)
    if not ok or secret then return false end
  end
  return true
end
local function apiMethod(namespace, name)
  if not usable(namespace) or type(namespace) ~= "table" then return end
  local ok, method = pcall(function() return namespace[name] end)
  if ok and usable(method) and type(method) == "function" then return method end
end
local function safeLabel(value)
  return usable(value) and type(value) == "string" and #value > 0 and
    #value <= 80 and not value:find("[%c|]")
end
local function numeric(text, max)
  if not usable(text) or type(text) ~= "string" or not text:match("^%d+$") then return end
  local value = tonumber(text)
  if value and value >= 1 and value <= max and value % 1 == 0 then return value end
end
local function entryAt(index)
  if wheel.submenu == "vendor" then return {type="category", category=vendors[index]} end
  if wheel.submenu == "folder" then
    local folder = addon.db.data.settings.wheelSlots[wheel.folderIndex]
    if index == #folder.entries + 1 then return {type="category", category="Back"} end
  end
  local ok, entry = pcall(function()
    local slots = addon.db.data.settings.wheelSlots
    if not usable(slots) or type(slots) ~= "table" then return end
    local item
    if wheel.submenu == "folder" then item = slots[wheel.folderIndex].entries[index]
    else item = slots[index] end
    if type(item) ~= "table" or not usable(item) then return end
    local kind = item.type
    if not usable(kind) then return end
    if kind == "category" and safeLabel(item.category) and #item.category <= 40 then
      return {type="category", category=item.category}
    end
    if (kind == "spell" or kind == "macro") and usable(item.id) and
        type(item.id) == "number" and item.id >= 1 and item.id <= 2147483647 and
        item.id % 1 == 0 then return {type=kind, id=item.id} end
    if kind == "item" and usable(item.id) and type(item.id) == "number" and
        item.id >= 1 and item.id <= 2147483647 and item.id % 1 == 0 then
      return {type="item", id=item.id}
    end
    if (kind == "folder" or kind == "addon") and safeLabel(item.name) then
      return {type=kind, name=item.name}
    end
  end)
  return ok and entry or (not wheel.submenu and index <= #categories and
    {type="category", category=categories[index]} or nil)
end
local function display(entry)
  if not entry then return "", icon end
  if entry.type == "category" then
    if entry.category == "Bank" then return "Bank", assetRoot .. "Bank.blp" end
    if entry.category == "Class Trainer" and usable(UnitClass) and type(UnitClass) == "function" then
      local ok, _, token = pcall(UnitClass, "player")
      if ok and usable(token) and type(token) == "string" and classes[token] then
        return classes[token] .. " Trainer", assetRoot .. "Class" .. classes[token]:gsub(" ", "") .. ".blp"
      end
    end
    return entry.category, icon
  end
  if entry.type == "folder" then return entry.name, "Interface\\Icons\\INV_Misc_Bag_08" end
  if entry.type == "addon" then return entry.name, "Interface\\Icons\\INV_Misc_Gear_01" end
  local label = ({spell="Spell #", macro="Macro #", item="Item #"})[entry.type] .. entry.id
  local spellInfo = entry.type == "spell" and apiMethod(C_Spell, "GetSpellInfo")
  local macroName = entry.type == "macro" and apiMethod(C_Macro, "GetMacroName")
  if spellInfo then
    local ok, info = pcall(spellInfo, entry.id)
    if ok and usable(info) and type(info) == "table" then
      local nameOK, name, image = pcall(function() return info.name, info.iconID end)
      if nameOK then
        if safeLabel(name) then label = name end
        if usable(image) and type(image) == "number" and image > 0 and
            image <= 2147483647 and image % 1 == 0 then return label, image end
      end
    end
  elseif macroName then
    local ok, name = pcall(macroName, entry.id)
    if ok and safeLabel(name) then label = name end
  end
  if entry.type == "item" and usable(GetItemInfo) and type(GetItemInfo) == "function" then
    local ok, name, _, _, _, _, _, _, _, image = pcall(GetItemInfo, entry.id)
    if ok then
      if safeLabel(name) then label = name end
      if usable(image) and type(image) == "number" then return label, image end
    end
  end
  return label, icon
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
local function edit(parent, title, x, y, width, limit)
  caption(parent, title, x, y)
  local field = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  field:SetSize(width, 22)
  field:SetPoint("TOPLEFT", x + 7, y - 17)
  field:SetAutoFocus(false)
  field:SetMaxLetters(limit)
  field:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  field:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  return field
end
local function animate(frame)
  if not frame or type(frame.CreateAnimationGroup) ~= "function" then return end
  local ok, animation = pcall(function()
    local group = frame.intro
    if not group then
      group = frame:CreateAnimationGroup()
      local fade = group:CreateAnimation("Alpha")
      fade:SetFromAlpha(0)
      fade:SetToAlpha(1)
      fade:SetDuration(.18)
      frame.intro = group
    end
    group:Stop()
    group:Play()
  end)
  return ok and animation
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
    local index = wheel.selected
    if wheel.activeIndex and not wheel.submenu then
      wheel:Close()
      if index and addon.db:WheelMove(wheel.activeIndex, index) then
        wheel:Notice("Moved active entry to slot " .. index .. ".")
        wheel.activeIndex = nil
        wheel:RefreshEditor()
      end
      return
    end
    local entry = index and entryAt(index)
    local submenu = wheel.submenu
    wheel:Close()
    if entry then
      if entry.type == "category" then
        if entry.category == "Vendor" and not submenu then
          wheel.submenu = "vendor"
          wheel:Open()
        elseif entry.category == "Back" then wheel:Open()
        else wheel:SelectCategory(entry.category) end
      elseif entry.type == "folder" then
        wheel.submenu, wheel.folderIndex = "folder", index
        wheel:Open()
      else
        local name = display(entry)
        addon:Print(name .. " selected; not executed." ..
          (entry.type == "addon" and " Open its own settings using that addon's controls." or ""))
      end
    end
  end)
  frame:SetScript("OnKeyDown", function(_, key)
    if key == "ESCAPE" then wheel:Close() end
  end)
  frame:SetScript("OnHide", function() wheel:RestoreCursor() end)
  self.frame = frame
  self.slots = {}
  local center = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  center:SetText("×")
  self.centerLabel = center
  frame:Hide()
  if UISpecialFrames then table.insert(UISpecialFrames, "ErrandMasterWheel") end
end
function wheel:EnsureSlots(count)
  local frame = self.frame
  for i = #self.slots+1, count do
    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetTexture(icon)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local badge = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badge:SetPoint("TOPRIGHT", texture, "TOPRIGHT", 4, 4)
    self.slots[i] = {texture=texture, label=text, badge=badge}
  end
  for i = count+1, #self.slots do
    self.slots[i].texture:Hide()
    self.slots[i].label:Hide()
    self.slots[i].badge:Hide()
  end
end
function wheel:SelectCategory(category)
  if not quickServices[category] or not addon.errands then
    addon.ui:OpenCategory(category)
    return
  end
  for _, task in ipairs(addon.errands:All()) do
    if task.category == category and task.origin == "suggested" and not task.completed then
      addon:Print("Already queued: " .. task.name .. ".")
      return
    end
  end
  local ok, task = pcall(addon.errands.Add, addon.errands, {
    name="Nearest " .. category, category=category, origin="suggested", scope="character"})
  if not ok then addon:Print("Could not queue " .. category .. "."); return end
  addon:Refresh()
  addon:Print("Queued " .. category .. "; route recalculated from current NPC candidates and observed evidence. Direct proximity is not a walking path.")
  return task
end
local function nearestPreview(category, map, x, y, width, height)
  if not quickServices[category] or not addon.npcs or
      not addon.npcs:IsReady() then return end
  local searches={category}
  if category == "Class Trainer" then
    local class = addon.discovery and addon.discovery:PlayerClass()
    if not safeLabel(class) then return end
    searches={class .. " Trainer"}
  elseif category == "Profession Trainer" and addon.ProfessionFilters then
    local names=addon:ProfessionFilters()
    if #names>0 then
      searches={}
      for _,name in ipairs(names) do searches[#searches+1]=name.." Trainer" end
    end
  end
  local nearest
  for _,wanted in ipairs(searches) do
    local ok, matches = pcall(addon.npcs.Nearest,addon.npcs,
      map,x,y,wanted,width,height,1)
    if ok and usable(matches) and type(matches)=="table" and
        usable(matches[1]) and type(matches[1])=="table" then
      local candidate=matches[1]
      if not nearest or (type(candidate.directYards)=="number" and
          (type(nearest.directYards)~="number" or
           candidate.directYards<nearest.directYards)) then nearest=candidate end
    end
  end
  if not nearest then return end
  local name, yards = nearest.name, nearest.directYards
  if not safeLabel(name) then return end
  local label=name:sub(1,20)
  if #name>20 then label=label.."..." end
  local distance=usable(yards) and type(yards)=="number" and yards>=0 and
    yards<10000000 and string.format("~%.0f yd direct",yards) or "map proximity only"
  return label.." ("..distance..")"
end
function wheel:Layout()
  if not self.frame then return end
  local settings = addon.db.data.settings
  local count = self.submenu == "vendor" and #vendors or
    self.submenu == "folder" and #(settings.wheelSlots[self.folderIndex].entries)+1 or
    (settings.wheelSlots and #settings.wheelSlots or #categories)
  self:EnsureSlots(count)
  local scale = settings.wheelScale or 1
  local iconSize = settings.wheelIconSize * scale
  local radius = math.max(settings.wheelRadius,
    count * settings.wheelIconSize * 1.6 / (2 * math.pi)) * scale
  self.radius, self.count = radius, count
  self.vectors = {}
  self.previews = {}
  local map, px, py, width, height
  if addon.npcs and type(addon.Position)=="function" then
    local ok, id, x, y = pcall(addon.Position,addon)
    if ok and usable(id) and usable(x) and usable(y) and
        type(id)=="number" and type(x)=="number" and type(y)=="number" and
        x>=0 and x<=1 and y>=0 and y<=1 then map,px,py=id,x,y end
    if map and type(addon.MapWorldSize)=="function" then
      local valid, w, h=pcall(addon.MapWorldSize,addon,map)
      if valid then width,height=w,h end
    end
  end
  local previewCache={}
  self.centerLabel:ClearAllPoints()
  self.centerLabel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", self.centerX, self.centerY)
  self.centerLabel:SetText(self.activeIndex and
    ("Active #" .. self.activeIndex .. ": choose slot") or "×")
  for i = 1, count do
    local slot = self.slots[i]
    slot.texture:Show(); slot.label:Show(); slot.badge:Show()
    slot.badge:SetText(self.activeIndex == i and ("A" .. i) or tostring(i))
    slot.badge:SetTextColor(self.activeIndex == i and 1 or .95,
      self.activeIndex == i and .82 or .95, self.activeIndex == i and .25 or .95)
    local entry=entryAt(i)
    local name, texture = display(entry)
    if map and entry and entry.type=="category" then
      local category=entry.category
      if previewCache[category]==nil then
        previewCache[category]=nearestPreview(category,map,px,py,width,height) or false
      end
      local preview=previewCache[category]
      if preview then self.previews[i]=preview; name=name.."\n"..preview end
    end
    slot.label:SetText(name)
    slot.texture:SetTexture(texture)
    local angle = math.pi / 2 - (i - 1) * 2 * math.pi / count
    local vector = {math.cos(angle), math.sin(angle)}
    self.vectors[i] = vector
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
  local colors = palettes[addon.db.data.settings.wheelTheme] or palettes.Azure
  for i = 1, self.count or 0 do
    local slot = self.slots[i]
    if i == index then
      slot.texture:SetVertexColor(1, .82, .25)
      slot.texture:SetAlpha(1)
      slot.label:SetTextColor(1, .82, .25)
    else
      slot.texture:SetVertexColor(colors[1], colors[2], colors[3])
      slot.texture:SetAlpha(.8)
      slot.label:SetTextColor(.9, .9, .9)
    end
  end
  self.centerLabel:SetText(index and index > 0 and
    (display(entryAt(index)) .. (self.previews and self.previews[index] and
      "\n" .. self.previews[index] or "")) or
    (self.activeIndex and "Move active entry" or "×"))
end
function wheel:UpdateHighlight()
  if not self.frame or not self.frame:IsShown() then return end
  local x, y = cursorPosition()
  if not x then self:SetSelection(nil); return end
  local dx, dy = x - self.centerX, y - self.centerY
  local deadZone = math.max(28, addon.db.data.settings.wheelIconSize *
    (addon.db.data.settings.wheelScale or 1) * .7)
  if dx*dx + dy*dy < deadZone*deadZone then self:SetSelection(nil); return end
  local best, score = nil, -math.huge
  for i, vector in ipairs(self.vectors or {}) do
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
  self.submenu = nil
  self.folderIndex = nil
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
  animate(self.frame)
  if type(SetCursor) == "function" then
    self.cursorAttempted = true
    pcall(SetCursor, CURSOR)
  end
  return true
end

function wheel:Notice(message)
  if self.status then self.status:SetText(message) end
end
function wheel:AssignSlot()
  if not outOfCombat() then self:Notice("Change wheel slots out of combat."); return false end
  local ok, slotText, kind, value = pcall(function()
    return self.slotNumber:GetText(), self.slotType:GetText(), self.slotValue:GetText()
  end)
  if not ok or not usable(kind) or not usable(value) then
    self:Notice("Invalid slot entry."); return false
  end
  local slot = numeric(slotText, 24)
  if not slot then self:Notice("Choose a slot from 1 to 24."); return false end
  local entry
  if kind == "category" and safeLabel(value) and #value <= 40 then
    entry = {type=kind, category=value}
  elseif kind == "addon" and safeLabel(value) and #value <= 40 then
    entry = {type=kind, name=value}
  elseif kind == "spell" or kind == "macro" or kind == "item" then
    local id = numeric(value, 2147483647)
    if id then
      local macroName = kind == "macro" and apiMethod(C_Macro, "GetMacroName")
      if macroName then
        local found, name = pcall(macroName, id)
        if not found or not safeLabel(name) then
          self:Notice("Macro ID not found; choose an existing macro."); return false
        end
      end
      entry = {type=kind, id=id}
    end
  end
  if not entry then self:Notice("Use a category/addon name or a positive spell/item/macro ID."); return false end
  local settings = addon.db.data.settings
  if type(settings.wheelSlots) ~= "table" or not usable(settings.wheelSlots) then
    settings.wheelSlots = {}
    for i, category in ipairs(categories) do
      settings.wheelSlots[i] = {type="category", category=category}
    end
  end
  if slot > #settings.wheelSlots + 1 then
    self:Notice("Add the next empty slot first."); return false
  end
  if addon.db.WheelReplace then
    local success = slot == #settings.wheelSlots + 1 and addon.db:WheelInsert(entry) or
      addon.db:WheelReplace(slot, entry)
    if not success then self:Notice("Entry rejected."); return false end
  else settings.wheelSlots[slot] = entry end
  self:RefreshEditor()
  self:Notice("Slot " .. slot .. " set to " .. display(entry) .. ".")
  return true
end
function wheel:StopCapture()
  if not self.capture then return end
  pcall(self.capture.EnableKeyboard, self.capture, false)
  pcall(self.capture.EnableMouse, self.capture, false)
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
    self.capture:EnableMouse(true)
    self.capture:SetPropagateKeyboardInput(false)
  end)
  if not ok then
    self:StopCapture()
    self:Notice("Key capture unavailable; use WoW Key Bindings.")
    return
  end
  self.capture:Show()
  self:Notice("Press a free key or mouse button; Escape cancels.")
end
function wheel:BindMouse(button)
  if not usable(button) or type(button) ~= "string" then return end
  local primary = {LeftButton="BUTTON1", RightButton="BUTTON2", MiddleButton="BUTTON3"}
  local key = primary[button]
  if not key then
    local number = button:match("^Button(%d+)$")
    if number and tonumber(number) >= 1 and tonumber(number) <= 31 then
      key = "BUTTON" .. tonumber(number)
    end
  end
  if key then self:BindKey(key)
  else self:Notice("Mouse button not reported by the game; press another or Escape.") end
end
function wheel:BindKey(key)
  if not usable(key) or type(key) ~= "string" then
    self:StopCapture(); self:Notice("Key state unavailable; use WoW Key Bindings."); return
  end
  if key == "ESCAPE" then self:StopCapture(); self:Notice("Binding canceled."); return end
  if not outOfCombat() then self:StopCapture(); self:Notice("Change bindings out of combat."); return end
  if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or
      key == "LALT" or key == "RALT" then return end
  if not key:match("^[A-Z0-9]+$") then
    self:Notice("Key not reported by the game; press another or Escape."); return
  end
  local function modifierState(api)
    if not usable(api) or type(api) ~= "function" then return end
    local ok, held = pcall(api)
    if ok and usable(held) and type(held) == "boolean" then return held end
  end
  local shift = modifierState(IsShiftKeyDown)
  local control = modifierState(IsControlKeyDown)
  local alt = modifierState(IsAltKeyDown)
  if shift == nil or control == nil or alt == nil then
    self:StopCapture(); self:Notice("Modifier state unavailable; use WoW Key Bindings."); return
  end
  local modifiers = ""
  if shift then modifiers = modifiers .. "SHIFT-" end
  if control then modifiers = modifiers .. "CTRL-" end
  if alt then modifiers = modifiers .. "ALT-" end
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
local function cursorEntry()
  if not usable(GetCursorInfo) or type(GetCursorInfo) ~= "function" then return end
  local ok, kind, position, _, spellID = pcall(GetCursorInfo)
  if not ok or not usable(kind) then return end
  local id
  if kind == "spell" then id = spellID -- First cursor value is not a spell ID.
  elseif kind == "macro" then id = position
  elseif kind == "item" then
    local cursorItem, itemID = apiMethod(C_Cursor, "GetCursorItem"), apiMethod(C_Item, "GetItemID")
    if cursorItem and itemID then
      local found, location = pcall(cursorItem)
      if found and usable(location) then
        local resolved, value = pcall(itemID, location)
        if resolved then id = value end
      end
    end
  else return end
  if not usable(id) or
      type(id) ~= "number" or id % 1 ~= 0 or id < 1 or id > 2147483647 then return end
  -- A cursor is inspected only: never pick up, use, cast or clear its payload.
  return {type=kind, id=id}
end
function wheel:RefreshEditor()
  if not self.editorRows then return end
  local slots = addon.db.data.settings.wheelSlots
  if not slots then return end
  local pageCount = math.max(1, math.ceil(#slots / #self.editorRows))
  self.editorPage = math.min(math.max(1, self.editorPage or 1), pageCount)
  for rowIndex, button in ipairs(self.editorRows) do
    local index = (self.editorPage-1)*#self.editorRows + rowIndex
    local entry = slots[index]
    button.slotIndex = entry and index or nil
    if entry then
      local name = display(entry)
      button:SetText(string.format("%s %d. %s%s", self.activeIndex == index and "Active" or "   ",
        index, name, entry.type == "folder" and " [folder]" or ""))
      button:Show()
    else button:Hide() end
  end
  if self.editorLabel then
    local selection = self.editorIndex and slots[self.editorIndex]
    self.editorLabel:SetText(string.format("%d/24 entries | page %d/%d | %s", #slots,
      self.editorPage, pageCount,
      selection and ("Selected #" .. self.editorIndex .. ": " .. display(selection)) or "Select an entry"))
  end
  if self.folderLabel then
    local folder = self.editorIndex and slots[self.editorIndex]
    self.folderLabel:SetText(folder and folder.type == "folder" and
      ("Folder: " .. folder.name .. " | " .. #folder.entries .. "/8 items") or
      "Hold over an entry while dragging to make a folder.")
    for i, button in ipairs(self.folderRows or {}) do
      local item = folder and folder.type == "folder" and folder.entries[i]
      if item then button:SetText(i .. ". " .. display(item)); button:Show()
      else button:Hide() end
    end
  end
end
function wheel:Choose(index)
  local slots = addon.db.data.settings.wheelSlots
  if not slots or not slots[index] then return end
  self.editorIndex = index
  self.slotNumber:SetText(tostring(index))
  local entry = slots[index]
  self.slotType:SetText(entry.type)
  self.slotValue:SetText(entry.category or entry.name or (entry.id and tostring(entry.id)) or "")
  self:RefreshEditor()
end
function wheel:DropEntry(entry, target, hovered)
  if not outOfCombat() then self:Notice("Edit the wheel out of combat."); return false end
  local slots = addon.db.data.settings.wheelSlots
  if target and not slots[target] then return false end
  local db = addon.db
  local success
  if target and hovered and hovered >= .45 then
    if slots[target].type == "folder" then success = db:WheelAddToFolder(target, entry)
    else
      local raw = self.folderName:GetText()
      local name = usable(raw) and safeLabel(raw) and #raw <= 40 and raw or "New folder"
      success = db:WheelInsert(entry, target)
      if success then
        success = db:WheelFolder(target, target+1, name)
        if not success then db:WheelRemove(target) end -- preserve the old wheel on failed grouping
      end
    end
  else success = db:WheelInsert(entry, target) end
  if success then
    self.activeIndex = nil
    self:Notice("Entry added. Selection previews only; no spell or macro executed.")
    self:RefreshEditor()
    animate(self.settingsFrame)
  else self:Notice("Drop rejected (invalid entry or wheel/folder full).") end
  return success
end
function wheel:DropNative(target)
  local entry = cursorEntry()
  if not entry then self:Notice("Drop a spell, item, or macro from a game panel."); return false end
  local elapsed = 0
  if target and self.hoverIndex == target and self.hoverStart and type(GetTime) == "function" then
    local ok, now = pcall(GetTime)
    if ok and usable(now) and type(now) == "number" then elapsed = now - self.hoverStart end
  end
  return self:DropEntry(entry, target, elapsed)
end
function wheel:FinishDrag()
  local source, target = self.dragIndex, self.hoverIndex
  self.dragIndex, self.hoverIndex = nil, nil
  if not source or not outOfCombat() then return end
  if self.hoverRemove then
    self.hoverRemove = nil
    if addon.db:WheelRemove(source) then
      self.activeIndex, self.editorIndex = nil, nil
      self:Notice("Entry removed."); self:RefreshEditor(); animate(self.settingsFrame)
    end
    return
  end
  if not target or target == source then return end
  local elapsed = 0
  if self.hoverStart and type(GetTime) == "function" then
    local ok, now = pcall(GetTime)
    if ok and usable(now) and type(now) == "number" then elapsed = now - self.hoverStart end
  end
  local success
  if elapsed >= .45 then
    local name = self.folderName:GetText()
    success = addon.db:WheelFolder(source, target, name ~= "" and name or "New folder")
  else success = addon.db:WheelMove(source, target) end
  if success then
    self.editorIndex, self.activeIndex = nil, nil
    self:Notice(elapsed >= .45 and "Folder created. Name it in the editor." or "Wheel reordered.")
    self:RefreshEditor()
    animate(self.settingsFrame)
  end
end
function wheel:AddNamedEntry()
  if not outOfCombat() then return false end
  local kind, value = self.slotType:GetText(), self.slotValue:GetText()
  if not usable(kind) or not usable(value) then return false end
  local entry
  if kind == "category" and safeLabel(value) and #value <= 40 then
    entry = {type=kind, category=value}
  elseif kind == "addon" and safeLabel(value) and #value <= 40 then
    entry = {type=kind, name=value}
  elseif kind == "spell" or kind == "macro" or kind == "item" then
    local id = numeric(value, 2147483647)
    if id then entry = {type=kind, id=id} end
  end
  if not entry then self:Notice("Enter category, addon, spell, item or macro with a valid value."); return false end
  return self:DropEntry(entry)
end
function wheel:BrowseAddOn()
  -- Add-ons do not supply a standard draggable cursor payload. Browse installed names instead.
  local method = apiMethod(C_AddOns, "GetAddOnName")
  local countMethod = apiMethod(C_AddOns, "GetNumAddOns")
  if not method and usable(GetAddOnInfo) and type(GetAddOnInfo) == "function" then method = GetAddOnInfo end
  if not countMethod and usable(GetNumAddOns) and type(GetNumAddOns) == "function" then countMethod = GetNumAddOns end
  if not method or not countMethod then self:Notice("Add-on listing unavailable; enter its name manually."); return end
  local ok, count = pcall(countMethod)
  if not ok or not usable(count) or type(count) ~= "number" or count < 1 or count > 1000 then return end
  for _ = 1, count do
    self.addonCursor = (self.addonCursor or 0) % count + 1
    local found, name = pcall(method, self.addonCursor)
    if found and safeLabel(name) and #name <= 40 then
      self.slotType:SetText("addon"); self.slotValue:SetText(name)
      self:Notice("Add-on " .. self.addonCursor .. "/" .. count .. ": " .. name .. ". Click Add entry.")
      return
    end
  end
end
function wheel:RefreshSettings()
  if not self.settingsFrame then return end
  local settings = addon.db.data.settings
  self.sizeLabel:SetText(string.format("Radius %d  |  Icon %d  |  Scale %.2f  |  Theme %s",
    settings.wheelRadius, settings.wheelIconSize, settings.wheelScale or 1,
    settings.wheelTheme or "Azure"))
  self.bindingLabel:SetText(self:BindingText())
  if self.professionStatus and addon.ProfessionFilters then
    local names,source=addon:ProfessionFilters()
    local label=#names>0 and table.concat(names, ", ") or "not detected; add manually"
    if #label>48 then label=label:sub(1,45).."..." end
    self.professionStatus:SetText("Professions ("..source.."): "..label)
  end
  self:RefreshEditor()
end
function wheel:ChangeProfession(mode)
  if not outOfCombat() then self:Notice("Change professions out of combat."); return end
  if mode=="auto" then addon.db:ClearProfessions()
  else
    local ok,name=pcall(self.professionInput.GetText,self.professionInput)
    if not ok or not safeLabel(name) then
      self:Notice("Enter a profession name first."); return
    end
    local changed=mode=="add" and addon.db:AddProfession(name) or
      addon.db:RemoveProfession(name)
    if not changed then self:Notice("Profession unchanged; check name or duplicate."); return end
  end
  self:RefreshSettings()
  addon:Refresh()
end
function wheel:FitSettings()
  if not self.settingsFrame then return end
  local ok, width, height = pcall(function() return UIParent:GetWidth(), UIParent:GetHeight() end)
  if not ok or not usable(width) or not usable(height) or
      type(width) ~= "number" or type(height) ~= "number" or
      width ~= width or height ~= height or width <= 0 or height <= 0 then return end
  local scale = math.min(1, (width - 32) / 745, (height - 32) / 755)
  if scale > .2 then pcall(self.settingsFrame.SetScale, self.settingsFrame, scale) end
end
function wheel:ShowSettings()
  if not self.settingsFrame then
    local frame = CreateFrame("Frame", "ErrandMasterWheelSettings", UIParent,
      "BasicFrameTemplateWithInset")
    frame:SetSize(745, 755)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetScript("OnHide", function()
      wheel:StopCapture(); wheel.dragIndex = nil; wheel.hoverIndex = nil
    end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    frame:RegisterEvent("UI_SCALE_CHANGED")
    frame:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_REGEN_DISABLED" then wheel:StopCapture()
      else wheel:FitSettings() end
    end)
    frame:SetClampedToScreen(true)
    frame.TitleText:SetText("ErrandMaster - Wheel studio")
    self.settingsFrame = frame
    self.bindingLabel = caption(frame, "", 22, -43)
    self.bindButton = control(frame, "Bind wheel", 22, -66, 130,
      function() wheel:StartCapture() end)
    self.status = caption(frame, "Drag a spell/item/macro to a slot; entries only preview.", 22, -690)
    self.sizeLabel = caption(frame, "", 22, -106)
    local function adjust(field, delta, minimum, maximum)
      local settings = addon.db.data.settings
      settings[field] = math.max(minimum, math.min(maximum, settings[field] + delta))
      wheel:RefreshSettings()
    end
    control(frame, "Radius -", 22, -128, 78,
      function() adjust("wheelRadius", -10, 80, 200) end)
    control(frame, "Radius +", 105, -128, 78,
      function() adjust("wheelRadius", 10, 80, 200) end)
    control(frame, "Icon -", 192, -128, 72,
      function() adjust("wheelIconSize", -4, 32, 72) end)
    control(frame, "Icon +", 269, -128, 72,
      function() adjust("wheelIconSize", 4, 32, 72) end)
    local function appearance(scale, theme)
      if addon.db:SetWheelAppearance(scale, theme) then wheel:RefreshSettings() end
    end
    control(frame, "Scale -", 22, -160, 78, function()
      local settings = addon.db.data.settings
      appearance(math.max(.75, math.floor((settings.wheelScale -.05)*10+.5)/10), settings.wheelTheme)
    end)
    control(frame, "Scale +", 105, -160, 78, function()
      local settings = addon.db.data.settings
      appearance(math.min(1.5, math.floor((settings.wheelScale +.15)*10+.5)/10), settings.wheelTheme)
    end)
    local themes = {"Azure", "Ember", "Violet", "Slate"}
    control(frame, "Theme", 192, -160, 148, function()
      local current = addon.db.data.settings.wheelTheme
      for i, theme in ipairs(themes) do
        if theme == current then
          appearance(addon.db.data.settings.wheelScale, themes[i % #themes + 1]); break
        end
      end
    end)
    caption(frame, "Trainer filter (per character; manual overrides auto)", 383, -45)
    self.professionStatus = caption(frame, "", 383, -67)
    self.professionInput = edit(frame, "Profession name (e.g. Alchemy)", 383, -94, 176, 40)
    self.professionAddButton = control(frame, "Add", 577, -111, 84,
      function() wheel:ChangeProfession("add") end)
    self.professionRemoveButton = control(frame, "Remove", 577, -141, 84,
      function() wheel:ChangeProfession("remove") end)
    self.professionAutoButton = control(frame, "Use auto detection", 383, -164, 176,
      function() wheel:ChangeProfession("auto") end)
    self.editorLabel = caption(frame, "", 22, -211)
    caption(frame, "Click #2 for Move/Remove. Drag to reorder; hold 0.45s to folder.", 22, -233)
    self.editorRows = {}
    for i = 1, 12 do
      local row = control(frame, "", 22, -259 - (i-1)*27, 330, function(button)
        wheel:Choose(button.slotIndex)
      end)
      row:RegisterForDrag("LeftButton")
      row:SetScript("OnDragStart", function(button)
        if outOfCombat() then wheel.dragIndex = button.slotIndex end
      end)
      row:SetScript("OnEnter", function(button)
        wheel.hoverIndex = button.slotIndex
        local ok, now = pcall(function() return GetTime and GetTime() end)
        wheel.hoverStart = ok and usable(now) and type(now) == "number" and now or nil
      end)
      row:SetScript("OnLeave", function(button)
        if wheel.hoverIndex == button.slotIndex then wheel.hoverIndex = nil end
      end)
      row:SetScript("OnReceiveDrag", function(button)
        if wheel.dragIndex then wheel.hoverIndex = button.slotIndex; wheel:FinishDrag()
        else wheel:DropNative(button.slotIndex) end
      end)
      row:SetScript("OnDragStop", function() wheel:FinishDrag() end)
      self.editorRows[i] = row
    end
    control(frame, "< Previous", 22, -587, 100, function()
      wheel.editorPage = math.max(1, (wheel.editorPage or 1)-1); wheel:RefreshEditor()
    end)
    control(frame, "Next >", 127, -587, 100, function()
      wheel.editorPage = (wheel.editorPage or 1)+1; wheel:RefreshEditor()
    end)
    local trash = control(frame, "Drag here to REMOVE", 22, -625, 330, function()
      if wheel.editorIndex and outOfCombat() and addon.db:WheelRemove(wheel.editorIndex) then
        wheel.activeIndex, wheel.editorIndex = nil, nil
        wheel:RefreshEditor()
      end
    end)
    trash:SetScript("OnEnter", function() wheel.hoverRemove = true end)
    trash:SetScript("OnLeave", function() wheel.hoverRemove = nil end)
    trash:SetScript("OnReceiveDrag", function()
      if wheel.dragIndex then wheel.hoverRemove = true; wheel:FinishDrag() end
    end)
    self.slotNumber = edit(frame, "Selected slot (1-24)", 383, -245, 60, 2)
    self.slotType = edit(frame, "Type: category / addon / spell / item / macro", 383, -296, 136, 8)
    self.slotValue = edit(frame, "Name or numeric ID", 383, -347, 278, 40)
    self.applySlotButton = control(frame, "Replace slot", 383, -399, 136,
      function() wheel:AssignSlot() end)
    control(frame, "Add entry", 526, -399, 136, function() wheel:AddNamedEntry() end)
    control(frame, "Browse addons", 383, -430, 136, function() wheel:BrowseAddOn() end)
    control(frame, "Drop entry here", 526, -430, 136, function() wheel:DropNative() end)
      :SetScript("OnReceiveDrag", function() wheel:DropNative() end)
    control(frame, "Set ACTIVE / Move", 383, -462, 136, function()
      if wheel.editorIndex and outOfCombat() then
        wheel.activeIndex = wheel.editorIndex
        wheel:Notice("Active #" .. wheel.activeIndex .. ": open wheel and choose its destination.")
        wheel:RefreshEditor()
      end
    end)
    control(frame, "Preview wheel", 526, -462, 136,
      function() wheel:Open() end)
    self.folderName = edit(frame, "Folder name (hover a slot while dragging)", 383, -500, 278, 40)
    control(frame, "Rename folder", 383, -553, 136, function()
      if wheel.editorIndex and outOfCombat() and
          addon.db:WheelRename(wheel.editorIndex, wheel.folderName:GetText()) then
        wheel:RefreshEditor()
      end
    end)
    self.folderLabel = caption(frame, "", 383, -588)
    self.folderRows = {}
    for i = 1, 8 do
      local child = control(frame, "", 383, -607 - (i-1)*17, 279, function(button)
        if wheel.editorIndex and outOfCombat() and
            addon.db:WheelRemove(wheel.editorIndex, button.childIndex) then
          wheel:Notice("Removed item from folder."); wheel:RefreshEditor()
        end
      end)
      child:SetSize(279, 16)
      child.childIndex = i
      self.folderRows[i] = child
    end
    self.capture = CreateFrame("Frame", nil, frame)
    self.capture:SetAllPoints(frame)
    self.capture:EnableKeyboard(false)
    self.capture:EnableMouse(false)
    self.capture:SetScript("OnKeyDown", function(_, key) wheel:BindKey(key) end)
    self.capture:SetScript("OnMouseDown", function(_, button) wheel:BindMouse(button) end)
    self.capture:Hide()
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "ErrandMasterWheelSettings") end
  end
  self:FitSettings()
  self:RefreshSettings()
  self.settingsFrame:Show()
  animate(self.settingsFrame)
end
