local _, addon = ...
addon.addonSettings = addon.addonSettings or {}
local page = addon.addonSettings

local primary = {"Alchemy", "Blacksmithing", "Enchanting", "Engineering",
  "Herbalism", "Inscription", "Jewelcrafting", "Leatherworking", "Mining",
  "Skinning", "Tailoring"}
local common = {"Cooking", "Fishing", "First Aid"}
local known = {}
for _, name in ipairs(primary) do known[name:lower()] = true end
for _, name in ipairs(common) do known[name:lower()] = true end

local function combat()
  if type(InCombatLockdown) ~= "function" then return false end
  local ok, active = pcall(InCombatLockdown)
  return not ok or active == true
end
local function label(parent, text, x, y)
  local font = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  font:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  font:SetText(text)
  return font
end
local function button(parent, text, x, y, width, height, action)
  local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  control:SetSize(width, height)
  control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  control:SetText(text)
  control:SetScript("OnClick", action)
  return control
end
local function overrides()
  local db = addon.db
  if not db or type(db.ProfessionOverrides) ~= "function" then return {} end
  local ok, names = pcall(db.ProfessionOverrides, db)
  return ok and type(names) == "table" and names or {}
end
local function report(message)
  if page.status then page.status:SetText(message) end
end
local function changed()
  page:Refresh()
  if type(addon.Refresh) == "function" then addon:Refresh() end
end
local function modify(method, name)
  local db = addon.db
  if not db or type(db[method]) ~= "function" then return false end
  local ok, result = pcall(db[method], db, name)
  return ok and result ~= false
end
function page:Select(slot, name)
  if combat() then report("Change professions out of combat."); return end
  local selected = {self.picks[1], self.picks[2]}
  if selected[slot] == name then self:CloseMenus(); return end
  selected[slot] = name
  if name and selected[3-slot] == name then selected[3-slot] = nil end
  local previous = overrides()
  local desired, seen = {}, {}
  for _, entry in ipairs(previous) do
    if type(entry) == "string" and not known[entry:lower()] and not seen[entry:lower()] then
      desired[#desired+1] = entry; seen[entry:lower()] = true
    end
  end
  for index = 1, 2 do
    local entry = selected[index]
    if entry and not seen[entry:lower()] then
      desired[#desired+1] = entry; seen[entry:lower()] = true
    end
  end
  for _, entry in ipairs(common) do
    if self.commonChecks[entry]:GetChecked() and not seen[entry:lower()] then
      desired[#desired+1] = entry; seen[entry:lower()] = true
    end
  end
  -- Preserve unrelated manual filters; only replace the profession choices this page owns.
  for _, entry in ipairs(previous) do
    if type(entry) == "string" and known[entry:lower()] then modify("RemoveProfession", entry) end
  end
  for _, entry in ipairs(desired) do
    if known[entry:lower()] and not modify("AddProfession", entry) then
      report("Could not save profession choice.")
      self:CloseMenus(); changed(); return
    end
  end
  self:CloseMenus()
  changed()
end
function page:CloseMenus()
  if not self.menus then return end
  for _, menu in ipairs(self.menus) do menu:Hide() end
end
function page:Refresh()
  if not self.frame then return end
  local names, selected = overrides(), {}
  for _, name in ipairs(names) do
    if type(name) == "string" then selected[name:lower()] = true end
  end
  self.picks = {}
  for _, name in ipairs(names) do
    if type(name) == "string" and known[name:lower()] then
      for _, trade in ipairs(primary) do
        if name:lower() == trade:lower() then
          self.picks[#self.picks+1] = trade
          break
        end
      end
      if #self.picks == 2 then break end
    end
  end
  for index = 1, 2 do
    self.pickButtons[index]:SetText((self.picks[index] or "None") .. "  v")
  end
  for _, name in ipairs(common) do
    self.commonChecks[name]:SetChecked(selected[name:lower()] == true)
  end
  self.detect:SetChecked(#names == 0)
  local settings = addon.db and addon.db.data and addon.db.data.settings or {}
  self.optimize:SetChecked(settings.optimize == true)
  self.tomtom:SetChecked(settings.useTomTom == true)
  self.flip:SetChecked(settings.wheelArtReversed == true)
  report(#names == 0 and "Detected professions are used when available." or
    "Manual choices override detected professions for this character.")
end
function page:Build()
  if self.frame then return self.frame end
  if type(CreateFrame) ~= "function" then return nil end
  local frame = CreateFrame("Frame", "ErrandMasterAddonSettings", UIParent)
  frame:SetSize(460, 490)
  self.frame = frame
  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  if type(background.SetColorTexture) == "function" then
    background:SetColorTexture(0.06, 0.08, 0.12, 0.96)
  else background:SetTexture(0.06, 0.08, 0.12, 0.96) end
  self.close = button(frame, "Close", 368, -12, 76, 24, function() frame:Hide() end)
  self.close:Hide()
  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetSize(27, 27)
  icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -12)
  icon:SetTexture("Interface\\AddOns\\ErrandMaster\\Textures\\PackLogo.blp")
  label(frame, "ErrandMaster", 51, -16)
  label(frame, "Trainer filters (this character)", 16, -49)
  label(frame, "Main professions", 16, -73)
  self.pickButtons, self.menus, self.commonChecks = {}, {}, {}
  for slot = 1, 2 do
    local x = slot == 1 and 16 or 236
    self.pickButtons[slot] = button(frame, "None  v", x, -92, 204, 26, function()
      local menu = page.menus[slot]
      local shown = menu:IsShown()
      page:CloseMenus()
      if not shown then menu:Show() end
    end)
    local menu = CreateFrame("Frame", nil, frame)
    menu:SetSize(204, 276)
    menu:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -120)
    if type(menu.SetFrameStrata) == "function" then menu:SetFrameStrata("DIALOG") end
    local background = menu:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(menu)
    if type(background.SetColorTexture) == "function" then
      background:SetColorTexture(0.06, 0.08, 0.12, 0.98)
    else background:SetTexture(0.06, 0.08, 0.12, 0.98) end
    local choices = {"None"}
    for _, name in ipairs(primary) do choices[#choices+1] = name end
    for index, name in ipairs(choices) do
      button(menu, name, 2, -2 - (index-1)*22, 200, 22, function()
        local choice = index ~= 1 and name or nil
        page:Select(slot, choice)
      end)
    end
    menu:Hide()
    self.menus[slot] = menu
  end
  label(frame, "Also include", 16, -134)
  for index, name in ipairs(common) do
    local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", frame, "TOPLEFT", 16+(index-1)*143, -151)
    label(frame, name, 43+(index-1)*143, -157)
    self.commonChecks[name] = check
    check:SetScript("OnClick", function(self)
      if combat() then self:SetChecked(not self:GetChecked()); report("Change professions out of combat."); return end
      local ok = modify(self:GetChecked() and "AddProfession" or "RemoveProfession", name)
      if not ok then report("Could not save profession choice."); page:Refresh(); return end
      changed()
    end)
  end
  self.detect = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  self.detect:SetSize(24, 24)
  self.detect:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -198)
  label(frame, "Use detected professions (clear manual choices)", 43, -204)
  self.detect:SetScript("OnClick", function(self)
    if combat() then page:Refresh(); report("Change professions out of combat."); return end
    if not self:GetChecked() then
      page:Refresh()
      report("Choose a profession above to override detection.")
      return
    end
    if type(addon.db.ClearProfessions) == "function" then
      local ok = pcall(addon.db.ClearProfessions, addon.db)
      if ok then changed(); return end
    end
    page:Refresh(); report("Could not clear manual choices.")
  end)
  label(frame, "Routing", 16, -248)
  local function setting(field, x, text)
    local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -267)
    label(frame, text, x+27, -273)
    check:SetScript("OnClick", function(self)
      if combat() then page:Refresh(); report("Change settings out of combat."); return end
      local settings = addon.db and addon.db.data and addon.db.data.settings
      if type(settings) ~= "table" then page:Refresh(); return end
      settings[field] = self:GetChecked() == true
      changed()
    end)
    return check
  end
  self.optimize = setting("optimize", 16, "Optimize stop order")
  self.tomtom = setting("useTomTom", 236, "Use TomTom if available")
  label(frame, "Wheel", 16, -326)
  self.bind = button(frame, "Bind wheel", 16, -349, 146, 26, function()
    if addon.radial and type(addon.radial.StartCapture) == "function" then
      addon.radial:StartCapture()
    else report("Wheel binding is unavailable.") end
  end)
  self.flip = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  self.flip:SetSize(24, 24)
  self.flip:SetPoint("TOPLEFT", frame, "TOPLEFT", 236, -350)
  label(frame, "Flip pie art", 264, -355)
  self.flip:SetScript("OnClick", function(self)
    if combat() then page:Refresh(); report("Change wheel art out of combat."); return end
    addon.db.data.settings.wheelArtReversed = self:GetChecked() == true
    if addon.radial and type(addon.radial.RefreshAppearance) == "function" and
        addon.radial.frame then addon.radial:RefreshAppearance() end
    changed()
  end)
  self.advanced = button(frame, "Advanced wheel layout", 16, -391, 186, 25, function()
    if addon.radial and type(addon.radial.ShowSettings) == "function" then
      addon.radial:ShowSettings()
    else report("Advanced wheel controls are unavailable.") end
  end)
  self.addSections = button(frame, "Add missing sections", 236, -391, 208, 25, function()
    if combat() then report("Change wheel sections out of combat."); return end
    if not addon.db or type(addon.db.WheelAddMissingDefaults) ~= "function" then
      report("Wheel sections unavailable."); return
    end
    local ok, count = pcall(addon.db.WheelAddMissingDefaults, addon.db)
    if not ok then report("Could not add wheel sections."); return end
    changed()
    if addon.radial and addon.radial.frame and addon.radial.frame:IsShown() then
      addon.radial:Layout()
    end
    report(count > 0 and ("Added " .. count .. " sections; existing slots unchanged.") or
      "No missing sections (or wheel is full).")
  end)
  label(frame, "Use Edit and Pin directly on the wheel.", 16, -425)
  self.status = label(frame, "", 16, -452)
  frame:SetScript("OnHide", function() page:CloseMenus() end)
  self:Refresh()
  frame:Hide()
  return frame
end
function page:Register()
  if self.registered then return self.category end
  local frame = self:Build()
  if not frame then return nil end
  if type(Settings) == "table" and
      type(Settings.RegisterCanvasLayoutCategory) == "function" and
      type(Settings.RegisterAddOnCategory) == "function" then
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, frame, "ErrandMaster")
    if ok and category then
      local added = pcall(Settings.RegisterAddOnCategory, category)
      if added then self.category, self.mode, self.registered = category, "settings", true; return category end
    end
  end
  if type(InterfaceOptions_AddCategory) == "function" then
    frame.name = "ErrandMaster"
    local ok = pcall(InterfaceOptions_AddCategory, frame)
    if ok then self.category, self.mode, self.registered = frame, "legacy", true; return frame end
  end
  self.mode, self.registered = "standalone", true
  if type(UISpecialFrames) == "table" then
    local present = false
    for _, name in ipairs(UISpecialFrames) do
      if name == "ErrandMasterAddonSettings" then present = true; break end
    end
    if not present then table.insert(UISpecialFrames, "ErrandMasterAddonSettings") end
  end
  return frame
end
function page:Open()
  self:Register()
  if not self.frame then return false end
  self:Refresh()
  if self.mode == "settings" and type(Settings) == "table" and
      type(Settings.OpenToCategory) == "function" then
    local ok = pcall(Settings.OpenToCategory, self.category:GetID())
    if ok then return true end
  elseif self.mode == "legacy" and type(InterfaceOptionsFrame_OpenToCategory) == "function" then
    local ok = pcall(InterfaceOptionsFrame_OpenToCategory, self.category)
    if ok then return true end
  end
  -- The page can still be opened when neither options API is available.
  if type(self.frame.SetParent) == "function" then self.frame:SetParent(UIParent) end
  self.close:Show()
  self.frame:ClearAllPoints()
  self.frame:SetPoint("CENTER", UIParent, "CENTER")
  self.frame:Show()
  return true
end
