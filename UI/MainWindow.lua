local _, addon = ...
addon.ui = {}
local ui = addon.ui
local function button(parent, label, x, y, w, action)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 24)
  b:SetPoint("TOPLEFT", x, y)
  b:SetText(label)
  b:SetScript("OnClick", action)
  return b
end
local function label(parent, text, x, y)
  local t = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  t:SetPoint("TOPLEFT", x, y)
  t:SetText(text)
  return t
end
local function input(parent, title, x, y, width, max)
  label(parent, title, x, y)
  local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  edit:SetSize(width, 22)
  edit:SetPoint("TOPLEFT", x + 7, y - 17)
  edit:SetAutoFocus(false)
  edit:SetMaxLetters(max)
  edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  return edit
end
local function text(edit) return edit:GetText() or "" end
local function trim(value) return value:match("^%s*(.-)%s*$") end
local function numeric(value)
  value = trim(value)
  if value == "" then return nil end
  local result = tonumber(value)
  assert(result, "coordinates and map ID must be numbers")
  return result
end
function ui:Create()
  local frame = CreateFrame("Frame", "ErrandMasterWindow", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(730, 580)
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  frame:SetClampedToScreen(true)
  frame.TitleText:SetText("ErrandMaster - Smart Route Planner")
  frame:Hide()
  self.frame = frame
  self.zone = label(frame, "", 18, -35)
  self.message = label(frame, "", 18, -555)
  self.rows = {}
  label(frame, "Same-map route (straight-line estimate; not travel time)", 18, -61)
  for i = 1, 8 do
    local row = button(frame, "", 18, -77 - (i-1)*31, 420, function()
      local item = ui.visible[i]
      if item then ui:Select(item.id) end
    end)
    row:SetNormalFontObject("GameFontHighlightSmall")
    self.rows[i] = row
  end
  self.summary = label(frame, "", 18, -329)
  label(frame, "Selected errand", 18, -360)
  self.selectedText = label(frame, "None", 18, -378)
  button(frame, "Complete / Reopen", 18, -401, 135, function() ui:Change("complete") end)
  button(frame, "Edit", 158, -401, 75, function() ui:Change("edit") end)
  button(frame, "Delete", 238, -401, 75, function() ui:Change("delete") end)
  button(frame, "Up", 318, -401, 55, function() ui:Change("up") end)
  button(frame, "Down", 378, -401, 65, function() ui:Change("down") end)
  button(frame, "Previous page", 18, -443, 125, function()
    ui.page = math.max(1, ui.page - 1); ui:Refresh()
  end)
  button(frame, "Next page", 148, -443, 125, function()
    ui.page = ui.page + 1; ui:Refresh()
  end)
  button(frame, "Navigate next", 278, -443, 165, function() addon:NavigateNext() end)
  button(frame, "Optimize", 18, -477, 120, function()
    addon.db.data.settings.optimize = true; ui:Refresh()
  end)
  button(frame, "Manual order", 143, -477, 120, function()
    addon.db.data.settings.optimize = false; ui:Refresh()
  end)
  button(frame, "TomTom on/off", 268, -477, 175, function()
    local settings = addon.db.data.settings
    settings.useTomTom = not settings.useTomTom
    addon.navigation:Clear()
    ui:Refresh()
  end)
  label(frame, "Add or edit", 466, -61)
  self.name = input(frame, "Name", 466, -82, 230, 80)
  self.category = input(frame, "Category", 466, -137, 230, 40)
  self.description = input(frame, "Description", 466, -192, 230, 200)
  self.map = input(frame, "Map ID (leave blank if unknown)", 466, -247, 230, 12)
  self.x = input(frame, "X percent (0-100)", 466, -302, 90, 12)
  self.y = input(frame, "Y percent (0-100)", 596, -302, 90, 12)
  button(frame, "Use current position", 466, -358, 230, function()
    local map, x, y = addon:Position()
    if not map or not x then ui:Notice("Position unavailable; enter a location manually."); return end
    ui.map:SetText(tostring(map))
    ui.x:SetText(string.format("%.2f", x*100))
    ui.y:SetText(string.format("%.2f", y*100))
  end)
  button(frame, "Add errand", 466, -394, 110, function() ui:Save(false) end)
  button(frame, "Save edits", 584, -394, 110, function() ui:Save(true) end)
  button(frame, "Character / account", 466, -436, 230, function()
    local settings = addon.db.data.settings
    settings.defaultScope = settings.defaultScope == "account" and "character" or "account"
    ui:Refresh()
  end)
  button(frame, "Toggle selected scope", 466, -472, 230, function()
    local item = ui.selected and addon.errands:Get(ui.selected)
    if not item then ui:Notice("Select an errand first."); return end
    local ok, err = pcall(addon.errands.Update, addon.errands, item.id,
      {scope=item.scope == "account" and "character" or "account"})
    if not ok then ui:Notice(tostring(err)); return end
    addon:Refresh()
  end)
  self.discoveryButton = button(frame, "Discover services: off", 466, -504, 230, function()
    local settings = addon.db.data.settings
    settings.discoverServices = not settings.discoverServices
    ui:Refresh()
    ui:Notice("Passive discovery " .. (settings.discoverServices and "on" or "off") .. ".")
  end)
  button(frame, "Wheel settings", 18, -509, 160, function()
    addon.radial:ShowSettings()
  end)
  self.mapButton = button(frame, "Map destinations", 190, -509, 155,
    function() addon:Command("map") end)
  self:Refresh()
end
function ui:Notice(message)
  if self.message then self.message:SetText(message) end
  addon:Print(message)
end
function ui:Select(id)
  self.selected = id
  local item = addon.errands:Get(id)
  if not item then self:Refresh(); return end
  self.name:SetText(item.name)
  self.category:SetText(item.category or "")
  self.description:SetText(item.description or "")
  self.map:SetText(item.mapID and tostring(item.mapID) or "")
  self.x:SetText(item.x and string.format("%.2f", item.x*100) or "")
  self.y:SetText(item.y and string.format("%.2f", item.y*100) or "")
  self:Refresh()
end
function ui:Save(editing)
  local ok, err = pcall(function()
    local map, x, y = numeric(text(self.map)), numeric(text(self.x)), numeric(text(self.y))
    local input = {name=trim(text(self.name)), category=trim(text(self.category)),
      description=text(self.description), mapID=map, x=x and x/100, y=y and y/100}
    if input.category == "" then input.category = "Custom" end
    if editing then
      assert(self.selected, "select an errand first")
      if not map and not x and not y then input.clearLocation = true end
      addon.errands:Update(self.selected, input)
    else
      input.scope = addon.db.data.settings.defaultScope
      addon.errands:Add(input)
    end
  end)
  if not ok then self:Notice(tostring(err)); return end
  self:Notice(editing and "Errand updated." or "Errand added.")
  self.page = 1
  addon:Refresh()
end
function ui:Change(action)
  local item = self.selected and addon.errands:Get(self.selected)
  if not item then self:Notice("Select an errand first."); return end
  if action == "edit" then self:Select(item.id); self.name:SetFocus(); return end
  local ok, err = pcall(function()
    if action == "delete" then addon.errands:Delete(item.id); self.selected = nil
    elseif action == "complete" then addon.errands:Complete(item.id, not item.completed)
    else
      local all = addon.errands:All()
      for index, entry in ipairs(all) do if entry.id == item.id then
        addon.errands:Reorder(item.id, math.max(1, math.min(#all, index + (action == "up" and -1 or 1))))
        break
      end end
      addon.db.data.settings.optimize = false
    end
  end)
  if not ok then self:Notice(tostring(err)); return end
  addon:Refresh()
end
function ui:Refresh()
  if not self.frame then return end
  local map, x, y = addon:Position()
  local zone = GetZoneText and GetZoneText() or "Unknown zone"
  self.zone:SetText(string.format("Zone: %s | Map: %s | Order: %s | New scope: %s | TomTom: %s",
    tostring(zone), tostring(map or "unknown"), addon.db.data.settings.optimize and "automatic" or "manual",
    addon.db.data.settings.defaultScope, addon.db.data.settings.useTomTom and "on" or "off"))
  self.discoveryButton:SetText("Discover services: " ..
    (addon.db.data.settings.discoverServices and "on" or "off"))
  local active, deferred = addon:Plan()
  self.visible = {}
  local entries = {}
  for _, item in ipairs(active) do entries[#entries+1] = {item=item, status="Route"} end
  for _, item in ipairs(deferred) do entries[#entries+1] = {item=item, status="Unrouted"} end
  local completed = 0
  for _, item in ipairs(addon.errands:All()) do
    if item.completed then entries[#entries+1] = {item=item, status="Done"}; completed=completed+1 end
  end
  self.page = math.max(1, math.min(self.page or 1, math.max(1, math.ceil(#entries/8))))
  for i, row in ipairs(self.rows) do
    local entry = entries[(self.page-1)*8+i]
    if entry then
      local item = entry.item
      self.visible[i] = item
      row:SetText(string.format("%s  [%s] %s  %s%s", item.id == self.selected and ">" or " ", entry.status,
        item.name, item.x and string.format("(%s%.1f, %.1f)",
          item.approximate and "~" or "", item.x*100, item.y*100) or "(no position)",
        item.directYards and string.format(" ~%.0f yd direct", item.directYards) or ""))
      row:Show()
    else row:Hide() end
  end
  self.summary:SetText(string.format("%d routed | %d unrouted | %d done | page %d/%d%s",
    #active, #deferred, completed, self.page, math.max(1, math.ceil(#entries/8)),
    active[#active] and active[#active].cumulativeYards and
      string.format(" | ~%.0f yd direct total", active[#active].cumulativeYards) or ""))
  local chosen = self.selected and addon.errands:Get(self.selected)
  self.selectedText:SetText(chosen and (chosen.name .. " [" .. chosen.scope .. "]") or "None")
end
function ui:Toggle()
  if self.frame:IsShown() then self.frame:Hide() else self:Refresh(); self.frame:Show() end
end
function ui:OpenCategory(category)
  if not self.frame then return end
  self.selected = nil
  self.name:SetText("")
  self.category:SetText(category)
  self.description:SetText("")
  self.map:SetText("")
  self.x:SetText("")
  self.y:SetText("")
  self:Refresh()
  self.frame:Show()
  self.name:SetFocus()
end
