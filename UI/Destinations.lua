local _, addon = ...
addon.destinations = {}
local destinations = addon.destinations
local ROW_HEIGHT, GAP = 54, 4
local CARD_TEXTURE = "Interface\\AddOns\\ErrandMaster\\Textures\\"
local colors = {Blue={.157,.439,1}, Violet={.675,.208,.847},
  Red={.933,.188,.188}, Green={.031,.745,.471}, Amber={.933,.537,0},
  Teal={0,.741,.835}, Gold={.914,.686,0}, Magenta={.898,.169,.51}}
local function tint(category)
  if type(category) ~= "string" then return colors.Magenta end
  local settings = addon.db and addon.db.data and addon.db.data.settings
  local overrides = settings and settings.wheelCategoryColors
  if type(overrides) == "table" then
    local ok, selected = pcall(function() return overrides[category] end)
    if ok and colors[selected] then return colors[selected] end
  end
  if category == "Bank" or category == "Personal Bank" or
      category == "Guild Bank" then return colors.Blue end
  if category == "Auction House" then return colors.Violet end
  if category == "Repair" then return colors.Red end
  if category:find("Vendor", 1, true) or category == "General Goods" then return colors.Green end
  if category:find("Trainer", 1, true) or category == "Skills" then return colors.Teal end
  if category == "Mailbox" then return colors.Amber end
  if category == "Travel" or category == "Quest" or category == "Quests" or
      category == "Flight Master" or category == "Waypoint" then return colors.Gold end
  return colors.Magenta
end

local function safe(value)
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    if not ok or secret then return false end
  end
  if type(value) == "table" and type(issecrettable) == "function" then
    local ok, secret = pcall(issecrettable, value)
    if not ok or secret then return false end
  end
  return true
end

local function number(value, low, high)
  return safe(value) and type(value) == "number" and value == value and
    value >= low and value <= high
end

local function validID(id)
  return number(id, 1, 1000000000) or
    (safe(id) and type(id) == "string" and #id > 0 and #id <= 128)
end

local function title(value, limit)
  if not safe(value) or type(value) ~= "string" then return "Unnamed" end
  value = value:gsub("|", "/"):gsub("[%c]", " ")
  limit = limit or 28
  if #value <= limit then return value end
  local cut = limit - 3
  while cut > 0 do
    local byte = value:byte(cut + 1)
    if not byte or byte < 128 or byte > 191 then break end
    cut = cut - 1
  end
  return value:sub(1, cut) .. "..."
end

local function entry(item, kind, index, activeID, nextID)
  if type(item) ~= "table" or not safe(item) then return end
  local ok, id, name, map, x, y, yards, walkYards, status, completed,
    nearby, flight, favorite, category = pcall(function()
      return item.id, item.name, item.mapID, item.x, item.y,
        item.directYards, item.walkYards, item.walkStatus, item.completed,
        item.nearbyZoneCandidate, item.taxiFlightNode, item.favorite, item.category
    end)
  if not ok or not safe(id) or not safe(name) or not safe(map) or
      not safe(x) or not safe(y) or not safe(yards) or not safe(walkYards) or
      not safe(status) or not safe(completed) or not safe(nearby) or
      not safe(flight) or not safe(favorite) or not safe(category) then return end
  if id ~= nil and not validID(id) then return end
  local location = number(x, 0, 1) and number(y, 0, 1) and
    string.format("%.1f, %.1f", x * 100, y * 100) or nil
  local evidence
  if kind == "done" then evidence = "Done"
  elseif status == "known-route" and number(walkYards, 0, 10000000) then
    evidence = string.format("%.0f yd - Observed Path", walkYards)
  elseif status == "partial-route" and number(walkYards, 0, 10000000) then
    evidence = string.format("%.0f yd observed - Connector Unknown", walkYards)
    if location then evidence = location .. " - " .. evidence end
  elseif type(nearby) == "table" and safe(nearby) then
    local read, zone, distance = pcall(function() return nearby.zoneName, nearby.directYards end)
    if read and safe(zone) and type(zone) == "string" and number(distance, 0, 10000000) then
      evidence = string.format("%.0f yd - %s - Unknown Path", distance, title(zone, 22))
    end
  end
  if not evidence and type(flight) == "string" and #flight <= 80 then
    evidence = "Fly: " .. title(flight, 20) .. " - Walk Unknown"
  end
  if not evidence and number(yards, 0, 10000000) then
    evidence = string.format("~%.0f yd direct - Unknown Path", yards)
    if location then evidence = location .. " - " .. evidence end
  end
  if not evidence then evidence = location and (location .. " - Unknown Path") or "Unknown Location" end
  return {id=id, completed=kind == "done" or completed == true,
    favorite=favorite == true, category=category,
    text=(favorite == true and "[Fav] " or "") .. title(name, 27) .. " - " .. evidence}
end

local function append(list, entries, kind, seen, activeID, nextID)
  if type(entries) ~= "table" or not safe(entries) then return end
  local okLength, count = pcall(function() return #entries end)
  if not okLength or type(count) ~= "number" or count < 0 then return end
  for i = 1, count do
    local ok, item = pcall(function() return entries[i] end)
    if not ok or item == nil then break end
    local row = entry(item, kind, i, activeID, nextID)
    if row and (not row.id or not seen[row.id]) then
      list[#list+1] = row
      if row.id then seen[row.id] = true end
    end
  end
end

local function settings()
  return addon.db and addon.db.data and addon.db.data.settings
end
local function cursor()
  if type(GetCursorPosition) ~= "function" then return end
  local ok, x, y = pcall(GetCursorPosition)
  if not ok or not number(x, -100000, 100000) or not number(y, -100000, 100000) then return end
  local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
  if not number(scale, .05, 20) then scale = 1 end
  return x / scale, y / scale
end

function destinations:GetNavigationAnchor()
  return self.frame or self:Create()
end
function destinations:Change(action, index)
  local row = self.visible and self.visible[index]
  local id = row and row.id
  if not validID(id) or not addon.errands then return end
  local ok, item = pcall(addon.errands.Get, addon.errands, id)
  if not ok or not item then return end
  if action == "activate" then
    local moved = pcall(addon.errands.Reorder, addon.errands, id, 1)
    if moved and type(addon.ActivateTarget) == "function" then
      pcall(addon.ActivateTarget, addon, id)
    end
  elseif action == "favorite" then
    pcall(addon.errands.Update, addon.errands, id, {favorite=not (item.favorite == true)})
  elseif action == "remove" then
    pcall(addon.errands.Delete, addon.errands, id)
  else return end
  if type(addon.Refresh) == "function" then addon:Refresh() else self:Refresh() end
end
function destinations:Drop(sourceIndex, targetIndex)
  local source, target = self.visible[sourceIndex], self.visible[targetIndex]
  if not source or not target or not validID(source.id) or not validID(target.id)
      or source.id == target.id then return end
  -- Reorder accepts a displayed slot, not the target's saved-list index.
  local ok = pcall(addon.errands.Reorder, addon.errands, source.id, targetIndex)
  if ok then
    if type(addon.Refresh) == "function" then addon:Refresh() else self:Refresh() end
  end
end
function destinations:HoveredCard()
  local focus
  if type(GetMouseFoci) == "function" then
    local ok, foci = pcall(GetMouseFoci)
    if ok and safe(foci) and type(foci) == "table" then focus = foci[1] end
  elseif type(GetMouseFocus) == "function" then
    local ok, value = pcall(GetMouseFocus)
    if ok then focus = value end
  end
  for _ = 1, 5 do
    if not focus then break end
    for i, card in ipairs(self.cards) do if focus == card then return i end end
    if type(focus.GetParent) ~= "function" then break end
    local ok, parent = pcall(focus.GetParent, focus)
    if not ok then break end
    focus = parent
  end
  return self.hoveredRow
end
-- Cards move during preview, so hit-testing their frames can name the dragged
-- source instead of the slot under the pointer. Use the stationary list grid.
function destinations:CursorSlot()
  local x, y = cursor()
  local viewport = self.scroll
  if not x or not y or not viewport or #self.entries == 0 then return end
  local top = viewport.GetTop and viewport:GetTop()
  local bottom = viewport.GetBottom and viewport:GetBottom()
  if not number(top, -100000, 100000) or not number(bottom, -100000, 100000)
      or top <= bottom or y < bottom or y > top then return end
  local left = viewport.GetLeft and viewport:GetLeft()
  local right = viewport.GetRight and viewport:GetRight()
  if number(left, -100000, 100000) and number(right, -100000, 100000)
      and (x < left or x > right) then return end
  local offset = viewport:GetVerticalScroll() or 0
  if not number(offset, 0, 1000000) then return end
  local slot = math.floor((top - y + offset) / (ROW_HEIGHT + GAP)) + 1
  return math.max(1, math.min(#self.entries, slot))
end
function destinations:StopDrag(commit)
  local source = self.dragSource
  local target = commit and (self:CursorSlot() or self.dragTarget) or nil
  self.dragSource, self.dragTarget, self.hoveredRow, self.preview = nil, nil, nil, nil
  if self.ghost then self.ghost:Hide() end
  if source and self.cards[source] then self.cards[source]:SetAlpha(1) end
  if commit and source and target and source ~= target then self:Drop(source, target)
  else self:Render() end
end
function destinations:DragTick(elapsed)
  if not self.dragSource then return end
  local x,y = cursor()
  if x and self.ghost then
    self.ghost:ClearAllPoints()
    self.ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
  end
  local viewport = self.scroll
  local bottom = viewport.GetBottom and viewport:GetBottom()
  local top = viewport.GetTop and viewport:GetTop()
  if y and bottom and top then
    local delta = y < bottom + 24 and 190 or (y > top - 24 and -190 or 0)
    if delta ~= 0 then self:ScrollBy(delta * math.min(elapsed or .03, .1)) end
  end
  local target = self:CursorSlot()
  if target and target ~= self.dragSource and target ~= self.dragTarget and self.visible[target] then
    self.dragTarget = target
    local visual = {}
    for i, item in ipairs(self.entries) do visual[i] = item end
    local dragged = table.remove(visual, self.dragSource)
    table.insert(visual, target, dragged)
    self.preview = visual
    self:Render(true)
  end
end
function destinations:ScrollBy(delta)
  if not self.scroll then return end
  local current = self.scroll:GetVerticalScroll() or 0
  local value = math.max(0, math.min(self.scrollMax or 0, current + delta))
  self.scroll:SetVerticalScroll(value)
  if self.scrollbar then self.scrollbar:SetValue(value) end
end
function destinations:ClampSize()
  local panel = self.frame
  if not panel then return end
  local width = UIParent.GetWidth and UIParent:GetWidth() or 800
  local height = UIParent.GetHeight and UIParent:GetHeight() or 600
  if not number(width, 1, 100000) then width = 800 end
  if not number(height, 1, 100000) then height = 600 end
  local w = math.min(math.max(panel:GetWidth() or 300, math.min(225,width)), width)
  local h = math.min(math.max(panel:GetHeight() or 340, math.min(125,height)), height)
  if w ~= panel:GetWidth() or h ~= panel:GetHeight() then panel:SetSize(w,h) end
  local listWidth = math.max(1, w - 34)
  self.scroll:SetSize(listWidth, math.max(1,h-45))
  self.content:SetWidth(listWidth)
  for _, card in ipairs(self.cards) do card:SetWidth(math.max(1,listWidth-3)) end
  self:UpdateScroll()
end
function destinations:UpdateScroll()
  if not self.scroll then return end
  self.content:SetHeight(math.max(1, #self.entries * (ROW_HEIGHT+GAP)))
  self.scrollMax = math.max(0, self.content:GetHeight() - self.scroll:GetHeight())
  self.scrollbar:SetMinMaxValues(0, self.scrollMax)
  if self.scrollMax > 0 then self.scrollbar:Show() else self.scrollbar:Hide() end
  self:ScrollBy(0)
end
local function tooltip(button, label)
  button:SetScript("OnEnter", function(self)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(label)
      GameTooltip:Show()
    end
  end)
  button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end
function destinations:MakeCard(i)
  local card = CreateFrame("Frame", nil, self.content)
  card:SetSize(math.max(1,self.scroll:GetWidth()-3), ROW_HEIGHT)
  card:EnableMouse(true)
  card:RegisterForDrag("LeftButton")
  local pattern = card:CreateTexture(nil, "BACKGROUND")
  pattern:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
  pattern:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0)
  pattern:SetTexture(CARD_TEXTURE .. "DestinationCardPattern.blp")
  pattern:SetAlpha(.48)
  local art = card:CreateTexture(nil, "BORDER")
  art:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
  art:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 0, 0)
  art:SetTexture(CARD_TEXTURE .. "CardFrame.blp")
  art:SetAlpha(.8)
  card.pattern, card.frameArt = pattern, art
  local row = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
  row:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -39, 7)
  row:SetJustifyH("CENTER"); row:SetJustifyV("MIDDLE")
  local controls = {}
  for _, spec in ipairs({{"remove", "PackCross.blp", -5, -3, "Remove target"},
      {"favorite", "PackFavourites.blp", -5, -20, "Toggle favorite"},
      {"activate", "PackWaypoint.blp", -5, -37, "Move to top / navigate"}}) do
    local action = spec[1]
    local button = CreateFrame("Button", nil, card)
    button:SetSize(20,17)
    button:SetPoint("TOPRIGHT", card, "TOPRIGHT", spec[3], spec[4])
    local glow = button:CreateTexture(nil, "BORDER")
    glow:SetPoint("CENTER", button, "CENTER", 0, 0)
    glow:SetSize(23, 23)
    glow:SetTexture(CARD_TEXTURE .. "DestinationButtonGlow.blp")
    glow:SetVertexColor(1, .83, .42)
    glow:SetAlpha(.64)
    button.glow = glow
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(15,15)
    icon:SetPoint("CENTER", button, "CENTER", 0,0)
    icon:SetTexture(CARD_TEXTURE .. spec[2]); button.icon = icon
    tooltip(button, spec[5])
    button:SetScript("OnClick", function() self:Change(action, i) end)
    controls[action] = button
  end
  card:SetScript("OnEnter", function() self.hoveredRow = i end)
  card:SetScript("OnLeave", function() if self.hoveredRow == i then self.hoveredRow = nil end end)
  card:SetScript("OnDragStart", function()
    if not self.visible[i] or not validID(self.visible[i].id) then return end
    self.dragSource, self.dragTarget = i, nil
    self.ghost.label:SetText(self.visible[i].text)
    local shade=tint(self.visible[i].category)
    self.ghost.pattern:SetVertexColor(shade[1],shade[2],shade[3])
    self.ghost:Show(); card:SetAlpha(.35)
    self:DragTick(0)
  end)
  card:SetScript("OnUpdate", function(_,elapsed)
    if self.dragSource == i then self:DragTick(elapsed)
    elseif card.targetY and card.currentY then
      local step = math.min(1,(elapsed or 0)*14)
      card.currentY = card.currentY + (card.targetY-card.currentY)*step
      if math.abs(card.currentY-card.targetY)<.15 then card.currentY=card.targetY end
      card:ClearAllPoints()
      card:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, card.currentY)
    end
  end)
  card:SetScript("OnDragStop", function() if self.dragSource == i then self:StopDrag(true) end end)
  self.rows[i], self.cards[i], self.controls[i] = row, card, controls
end
function destinations:Create()
  if self.frame then return self.frame end
  local panel = CreateFrame("Frame", "ErrandMasterDestinations", UIParent)
  local availableWidth = UIParent.GetWidth and UIParent:GetWidth() or 800
  local availableHeight = UIParent.GetHeight and UIParent:GetHeight() or 600
  if not number(availableWidth, 1, 100000) then availableWidth = 800 end
  if not number(availableHeight, 1, 100000) then availableHeight = 600 end
  panel:SetSize(math.min(300,availableWidth),math.min(340,math.max(125,availableHeight*.65)))
  panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24,-130)
  if addon.windowPosition then addon.windowPosition:Restore(panel,"targets") end
  panel:SetMovable(true); panel:SetResizable(true); panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton"); panel:SetClampedToScreen(true)
  if panel.SetResizeBounds then panel:SetResizeBounds(math.min(225,availableWidth),math.min(125,availableHeight),availableWidth,availableHeight)
  elseif panel.SetMinResize then panel:SetMinResize(225,125) end
  local background = panel:CreateTexture(nil,"BACKGROUND")
  background:SetPoint("TOPLEFT",panel,"TOPLEFT",0,0)
  background:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",0,0)
  background:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
  background:SetAlpha(.22)
  panel:SetScript("OnDragStart", function(f) f:StartMoving(); f.errandMoving=true end)
  panel:SetScript("OnDragStop", function(f)
    if f.errandMoving then
      f:StopMovingOrSizing(); f.errandMoving=nil
      if addon.windowPosition then addon.windowPosition:Save(f,"targets") end
    end
  end)
  panel:SetScript("OnHide", function(f)
    if self.dragSource then self:StopDrag(false) end
    if f.errandMoving or f.errandSizing then
      f:StopMovingOrSizing(); f.errandMoving=nil; f.errandSizing=nil
      if addon.windowPosition then addon.windowPosition:Save(f,"targets") end
    end
  end)
  local heading=panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  heading:SetPoint("TOPLEFT",panel,"TOPLEFT",11,-8)
  heading:SetText("TARGETS")
  local grip=CreateFrame("Button",nil,panel)
  grip:SetSize(18,18); grip:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",0,0)
  grip:SetScript("OnMouseDown",function()
    panel:StartSizing("BOTTOMRIGHT"); panel.errandSizing=true
  end)
  grip:SetScript("OnMouseUp",function()
    if not panel.errandSizing then return end
    panel:StopMovingOrSizing(); panel.errandSizing=nil
    self:ClampSize()
    if addon.windowPosition then addon.windowPosition:Save(panel,"targets") end
  end)
  local gripMark=grip:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  gripMark:SetPoint("CENTER",grip,"CENTER",0,0); gripMark:SetText("◢")
  self.grip=grip
  self.scroll=CreateFrame("ScrollFrame",nil,panel)
  self.scroll:SetPoint("TOPLEFT",panel,"TOPLEFT",8,-24)
  self.scroll:SetSize(266,295)
  self.content=CreateFrame("Frame",nil,self.scroll)
  self.content:SetSize(266,1)
  self.scroll:SetScrollChild(self.content)
  self.scrollbar=CreateFrame("Slider",nil,panel,"UIPanelScrollBarTemplate")
  self.scrollbar:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-6,-27)
  self.scrollbar:SetPoint("BOTTOMRIGHT",panel,"BOTTOMRIGHT",-6,21)
  self.scrollbar:SetOrientation("VERTICAL")
  self.scrollbar:SetValueStep(ROW_HEIGHT+GAP)
  self.scrollbar:SetScript("OnValueChanged",function(_,value)
    self.scroll:SetVerticalScroll(value)
  end)
  self.scroll:SetScript("OnMouseWheel",function(_,delta)
    self:ScrollBy(-delta*(ROW_HEIGHT+GAP))
  end)
  if self.scroll.EnableMouseWheel then self.scroll:EnableMouseWheel(true) end
  self.ghost=CreateFrame("Frame",nil,UIParent)
  self.ghost:SetSize(245,ROW_HEIGHT)
  self.ghost:SetAlpha(.85)
  self.ghost.pattern=self.ghost:CreateTexture(nil,"BACKGROUND")
  self.ghost.pattern:SetPoint("TOPLEFT",self.ghost,"TOPLEFT",0,0)
  self.ghost.pattern:SetPoint("BOTTOMRIGHT",self.ghost,"BOTTOMRIGHT",0,0)
  self.ghost.pattern:SetTexture(CARD_TEXTURE .. "CardPattern.blp")
  self.ghost.pattern:SetAlpha(.7)
  local ghostArt=self.ghost:CreateTexture(nil,"BACKGROUND")
  ghostArt:SetPoint("TOPLEFT",self.ghost,"TOPLEFT",0,0)
  ghostArt:SetPoint("BOTTOMRIGHT",self.ghost,"BOTTOMRIGHT",0,0)
  ghostArt:SetTexture(CARD_TEXTURE .. "CardFrame.blp")
  self.ghost.label=self.ghost:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  self.ghost.label:SetPoint("CENTER",self.ghost,"CENTER",0,0)
  self.ghost:Hide()
  self.rows,self.cards,self.controls,self.visible,self.entries,self.lines={},{},{},{},{},{}
  self.frame=panel
  panel:SetScript("OnSizeChanged",function() self:ClampSize() end)
  self:ClampSize()
  panel:Hide()
  return panel
end
function destinations:Render(preview)
  if not self.frame then return end
  local visual = preview and self.preview or self.entries
  self.visible = self.entries -- event callbacks always address persistent displayed indices
  for i=1,#self.entries do
    if not self.cards[i] then self:MakeCard(i) end
    local item,card=self.entries[i],self.cards[i]
    local shade=tint(item.category)
    card.pattern:SetVertexColor(shade[1],shade[2],shade[3])
    self.rows[i]:SetText(item.text)
    self.rows[i]:Show(); card:Show()
    card:SetAlpha(self.dragSource==i and .35 or 1)
    local position=i
    if preview then
      for j,value in ipairs(visual) do if value==item then position=j; break end end
    end
    local targetY=-(position-1)*(ROW_HEIGHT+GAP)
    card.targetY=targetY
    if not card.currentY or not preview then card.currentY=targetY end
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT",self.content,"TOPLEFT",0,card.currentY)
    for action,button in pairs(self.controls[i]) do
      if item.id and (action~="activate" or not item.completed) then button:Show()
      else button:Hide() end
    end
    self.controls[i].favorite.icon:SetAlpha(item.favorite and 1 or .55)
  end
  for i=#self.entries+1,#self.cards do
    self.cards[i]:Hide(); self.rows[i]:Hide()
  end
  self:UpdateScroll()
end
function destinations:Refresh()
  if not self.frame then return false end
  local entries,seen={},{}
  if type(addon.Plan)=="function" then
    local ok,ordered,deferred=pcall(addon.Plan,addon)
    if ok then
      if addon.route and type(addon.route.DisplayOrder)=="function" then
        local valid,display=pcall(addon.route.DisplayOrder,addon.route,ordered,deferred)
        if valid then append(entries,display,"ordered",seen) end
      else
        append(entries,ordered,"ordered",seen)
        append(entries,deferred,"deferred",seen)
      end
    end
  end

  self.entries,self.lines=entries,{}
  for i,item in ipairs(entries) do self.lines[i]=item.text end
  if self.dragSource then self:StopDrag(false) end
  self:Render()
  if #entries==0 or (settings() and settings().showDestinations==false) then
    self.frame:Hide()
  else self.frame:Show() end
  return true
end
function destinations:Open()
  self:Create()
  if settings() then settings().showDestinations=true end
  self:Refresh()
  return true
end
function destinations:Toggle()
  if self.frame and self.frame:IsShown() then
    if settings() then settings().showDestinations=false end
    self.frame:Hide()
    return false
  end
  return self:Open()
end
function destinations:Restore()
  if settings() and settings().showDestinations==false then return false end
  return self:Open()
end
