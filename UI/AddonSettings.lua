local _, addon = ...
addon.addonSettings = addon.addonSettings or {}
local page = addon.addonSettings

local primary = {"Alchemy", "Blacksmithing", "Enchanting", "Engineering",
  "Herbalism", "Leatherworking", "Mining", "Skinning", "Tailoring"}
local common = {"Cooking", "Fishing", "First Aid"}


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

local function report(message)
  page:Notice(message)
end
function page:Notice(message)
  self.notice = message
  if self.status then self.status:SetText(message or "") end
  self:RefreshBinding()
end
function page:RefreshBinding()
  if not self.bindingStatus then return end
  local radial = addon.radial
  local text = "Key: unavailable (use WoW Key Bindings)"
  if radial and type(radial.BindingText) == "function" then
    local ok, result = pcall(radial.BindingText, radial)
    if ok and type(result) == "string" then text = result end
  end
  self.bindingStatus:SetText(text)
end
local function dismissOptions()
  -- Dismiss the native container as well as the canvas; a hidden canvas alone
  -- can leave the wheel behind SettingsPanel on modern clients.
  for _, panel in ipairs({SettingsPanel or false, InterfaceOptionsFrame or false}) do
    if panel and type(panel.Hide) == "function" then pcall(panel.Hide, panel) end
  end
  if page.frame then page.frame:Hide() end
end
local function changed()
  page:Refresh()
  if addon.radial and addon.radial.frame and addon.radial.frame:IsShown() then addon.radial:Layout() end
  if type(addon.Refresh) == "function" then addon:Refresh() end
end

function page:Select(slot, name)
  if combat() then report("Change professions out of combat."); return end
  if not addon.db:SetProfessionPick(slot,name) then report("Invalid profession."); return end
  self:CloseMenus()
  changed()
end
function page:CloseMenus()
  if not self.menus then return end
  for _, menu in ipairs(self.menus) do menu:Hide() end
end
function page:Refresh()
  if not self.frame then return end
  local preferences=addon.db:ProfessionPreferences()
  self.picks=preferences.picks
  for index = 1, 2 do
    self.pickButtons[index]:SetText((self.picks[index] or "All professions") .. "  v")
  end
  for _, name in ipairs(common) do
    self.commonChecks[name]:SetChecked(preferences.common[name])
  end
  local settings = addon.db and addon.db.data and addon.db.data.settings or {}
  self.optimize:SetChecked(settings.optimize == true)
  self.targets:SetChecked(settings.showDestinations~=false)
  for key,controls in pairs(self.metrics) do controls.value:SetText(tostring(settings[key])) end
  local slots=settings.wheelSlots
  self.slotIndex=math.max(1,math.min(self.slotIndex or 1,#slots))
  local entry=slots[self.slotIndex]
  self.slotLabel:SetText(entry and (self.slotIndex.." / "..#slots.."   "..(entry.name or entry.category or (entry.type.." "..tostring(entry.id)))) or "Empty wheel")
  self.iconInput:SetText(entry and entry.icon and tostring(entry.icon) or "")
  self:RefreshBinding()
  if not self.notice then
    self.status:SetText((not self.picks[1] or not self.picks[2]) and
      "An unset picker includes every primary profession." or "Both selected: only these primary professions are included.")
  end
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
  self.close = button(frame, "Close", 368, -12, 76, 24, function() page.frame:Hide() end)
  self.close:Hide()
  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetSize(27, 27)
  local iconGlow = frame:CreateTexture(nil, "BACKGROUND")
  iconGlow:SetSize(42, 42)
  iconGlow:SetPoint("CENTER", icon, "CENTER")
  iconGlow:SetTexture("Interface\\AddOns\\ErrandMaster\\Textures\\DestinationButtonGlow.blp")
  iconGlow:SetVertexColor(1, .78, .3, .65)
  iconGlow:SetBlendMode("ADD")
  icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -12)
  icon:SetTexture("Interface\\AddOns\\ErrandMaster\\Textures\\PackLogo.blp")
  label(frame, "ErrandMaster", 51, -16)
  self.panels,self.tabs={},{}
  local root=frame
  for index,key in ipairs({"general","wheel","layout"}) do
    local tab=CreateFrame("Frame",nil,root)
    tab:SetSize(460,380); tab:SetPoint("TOPLEFT",root,"TOPLEFT",0,-78)
    self.panels[key]=tab
    self.tabs[key]=button(root,({"General","Wheel","Layout"})[index],16+(index-1)*144,-48,138,25,
      function() page:SelectTab(key) end)
  end
  frame=self.panels.general
  label(frame, "Trainer and vendor professions (this character)", 16, -8)
  label(frame, "Leave either picker unset to include all primary professions.", 16, -32)
  self.pickButtons, self.menus, self.commonChecks = {}, {}, {}
  for slot = 1, 2 do
    local x = slot == 1 and 16 or 236
    self.pickButtons[slot] = button(frame, "All professions  v", x, -54, 204, 26, function()
      local menu = page.menus[slot]
      local shown = menu:IsShown()
      page:CloseMenus()
      if not shown then menu:Show() end
    end)
    local menu = CreateFrame("Frame", nil, frame)
    menu:SetSize(204, 224)
    menu:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -82)
    if type(menu.SetFrameStrata) == "function" then menu:SetFrameStrata("DIALOG") end
    local background = menu:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(menu)
    if type(background.SetColorTexture) == "function" then
      background:SetColorTexture(0.06, 0.08, 0.12, 0.98)
    else background:SetTexture(0.06, 0.08, 0.12, 0.98) end
    local choices = {"All professions"}
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
  label(frame, "Also include", 16, -102)
  for index, name in ipairs(common) do
    local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", frame, "TOPLEFT", 16+(index-1)*143, -121)
    label(frame, name, 43+(index-1)*143, -127)
    self.commonChecks[name] = check
    check:SetScript("OnClick", function(self)
      if combat() then self:SetChecked(not self:GetChecked()); report("Change professions out of combat."); return end
      local ok = addon.db:SetCommonProfession(name,self:GetChecked()==true)
      if not ok then report("Could not save profession choice."); page:Refresh(); return end
      changed()
    end)
  end
  label(frame, "Targets and navigation", 16, -184)
  local function setting(field, x, text)
    local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -210)
    label(frame, text, x+27, -216)
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
  self.targets = setting("showDestinations", 236, "Show targets")
  label(frame, "The navigation arrow appears above a non-empty target list.",16,-256)
  label(frame, "Arriving within 2 yards removes the queued stop.",16,-278)
  label(frame, "Dragged stops keep their place; others can still optimize.",16,-300)
  frame=self.panels.wheel
  label(frame,"Size follows your viewport and WoW UI scale.",16,-8)
  self.bind = button(frame, "Bind wheel", 16, -246, 146, 26, function()
    if addon.radial and type(addon.radial.StartCapture) == "function" then
      if addon.radial:StartCapture() then page:Notice("Press a free key or mouse button; Escape cancels.") end
    else report("Wheel binding is unavailable.") end
  end)
  self.bindingStatus=label(frame,"",16,-285)
  local function input(parent,x,y,width)
    local field=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
    field:SetSize(width,26);field:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y)
    if field.SetAutoFocus then field:SetAutoFocus(false) end
    if field.SetMaxLetters then field:SetMaxLetters(40) end
    field:SetText("")
    field:SetScript("OnEscapePressed",function(self) if self.ClearFocus then self:ClearFocus() end end)
    return field
  end
  self.metrics={}
  for index,spec in ipairs({{"wheelRadius","Radius",40,220,10},{"wheelScale","Wheel scale",.5,1.5,.1},{"wheelIconSize","Icon size",20,72,4}}) do
    local key,y=spec[1],-40-(index-1)*58
    label(frame,spec[2].." ("..spec[3].."–"..spec[4]..")",16,y)
    local value=input(frame,205,y+4,65)
    local function apply(number)
      if combat() then page:Refresh(); report("Change wheel size out of combat.");return end
      if not addon.db:SetWheelMetric(key,number) then report("Enter a value in the displayed range.");return end
      changed()
    end
    value:SetScript("OnEnterPressed",function(self) apply(tonumber(self:GetText()));if self.ClearFocus then self:ClearFocus() end end)
    local minus=button(frame,"-",284,y+4,36,26,function()
      apply(math.max(spec[3],math.floor((addon.db.data.settings[key]-spec[5])*100+.5)/100)) end)
    local plus=button(frame,"+",326,y+4,36,26,function()
      apply(math.min(spec[4],math.floor((addon.db.data.settings[key]+spec[5])*100+.5)/100)) end)
    local save=button(frame,"Apply",368,y+4,72,26,function() apply(tonumber(value:GetText())) end)
    self.metrics[key]={value=value,minus=minus,plus=plus,apply=save}
  end
  label(frame,"Colors and ornament direction are fixed by the artwork.",16,-210)
  self.preview=button(frame,"Preview wheel",236,-246,204,26,function()
    if addon.radial then dismissOptions();addon.radial:Open() end end)
  frame=self.panels.layout
  label(frame,"Drag spells or bag items onto the unlocked wheel.",16,-8)
  label(frame,"Hover an entry to create a folder; drop between to insert.",16,-30)
  self.editWheel=button(frame,"Unlock and edit wheel",16,-57,204,26,function()
    if combat() then report("Edit out of combat.");return end
    addon.db.data.settings.wheelUnlocked=true
    if addon.radial then
      dismissOptions()
      if addon.radial.SetEditing then addon.radial:SetEditing(true) end
      addon.radial:Open()
    end
  end)
  self.addSections = button(frame, "Add missing sections",236,-57,204,26,function()
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
  self.slotLabel=label(frame,"",16,-107)
  button(frame,"Previous",16,-129,94,24,function() page.slotIndex=math.max(1,(page.slotIndex or 1)-1);page:Refresh() end)
  button(frame,"Next",116,-129,94,24,function() page.slotIndex=(page.slotIndex or 1)+1;page:Refresh() end)
  self.removeSlot=button(frame,"Remove selected",236,-129,204,24,function()
    if not combat() and addon.db:WheelRemove(page.slotIndex) then changed() end end)
  label(frame,"Name / category / spell or item ID",16,-170)
  self.nameInput=input(frame,20,-192,245)
  local kinds={"folder","category","spell","item","macro","addon"};self.entryKind="folder"
  self.kind=button(frame,"New folder",284,-192,156,26,function()
    for i,name in ipairs(kinds) do if page.entryKind==name then
      page.entryKind=kinds[i%#kinds+1];page.kind:SetText("New "..page.entryKind);break end end end)
  self.addEntry=button(frame,"Add entry",16,-226,126,26,function()
    if combat() then report("Edit out of combat.");return end
    local kind,value=page.entryKind,page.nameInput:GetText()
    local entry={type=kind}
    if kind=="folder" then entry.name=value;entry.entries={}
    elseif kind=="category" then entry.category=value
    elseif kind=="addon" then entry.name=value else entry.id=tonumber(value) end
    if addon.db:WheelInsert(entry) then page.slotIndex=#addon.db.data.settings.wheelSlots;changed()
    else report("Use a valid name/ID; wheel capacity is 24 entries.") end end)
  self.rename=button(frame,"Rename folder",152,-226,130,26,function()
    if not combat() and addon.db:WheelRename(page.slotIndex,page.nameInput:GetText()) then changed() end end)
  label(frame,"Selected icon file ID (empty restores default)",16,-274)
  self.iconInput=input(frame,20,-297,160)
  self.applyIcon=button(frame,"Set icon",202,-297,110,26,function()
    if combat() then report("Edit out of combat.");return end
    local text=page.iconInput:GetText();local id=tonumber(text)
    if text~="" and not id then report("Use a numeric icon file ID.");return end
    if addon.db:WheelSetIcon(page.slotIndex,id) then changed() else report("Invalid icon ID.") end end)
  self.status = label(root, "", 16, -462)
  root:SetScript("OnHide", function()
    page:CloseMenus()
    if addon.radial and addon.radial.StopCapture then addon.radial:StopCapture() end
  end)
  self:SelectTab("general")
  self:Refresh()
  root:Hide()
  return root
end
function page:SelectTab(key)
  if not self.panels or not self.panels[key] then return false end
  self:CloseMenus();self.activeTab=key
  for name,panel in pairs(self.panels) do if name==key then panel:Show() else panel:Hide() end end
  for name,tab in pairs(self.tabs) do
    local title=({general="General",wheel="Wheel",layout="Layout"})[name]
    tab:SetText(name==key and ("[ "..title.." ]") or title)
    if name==key and type(tab.Disable)=="function" then tab:Disable()
    elseif name~=key and type(tab.Enable)=="function" then tab:Enable() end
  end
  self:RefreshBinding()
  return true
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
function page:Open(tab)
  self:Register()
  if not self.frame then return false end
  self:Refresh()
  if tab then self:SelectTab(tab) end
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
