local _, addon = ...
addon.navigationArrow = {}
local arrow = addon.navigationArrow

-- Parent the indicator to the sidebar-provided anchor, never to TomTom/UIParent.
function arrow:Create()
  if self.frame then return self.frame end
  local anchor = addon.destinations and addon.destinations.GetNavigationAnchor and
    addon.destinations:GetNavigationAnchor()
  if not anchor or type(CreateFrame) ~= 'function' then return nil end
  local frame = CreateFrame('Frame', nil, anchor)
  frame:SetSize(220, 80)
  frame:SetPoint('BOTTOM', anchor, 'TOP', 0, 4)
  local icon = frame:CreateTexture(nil, 'ARTWORK')
  icon:SetSize(32, 32)
  icon:SetPoint('TOP', frame, 'TOP', 0, -2)
  icon:SetTexture('Interface\\MINIMAP\\MinimapArrow')
  local glow=frame:CreateTexture(nil,'BACKGROUND')
  glow:SetSize(48,48)
  glow:SetPoint('CENTER',icon,'CENTER')
  glow:SetTexture('Interface\\AddOns\\ErrandMaster\\Textures\\DestinationButtonGlow.blp')
  glow:SetBlendMode('ADD')
  glow:SetVertexColor(1,.82,.4)
  glow:SetAlpha(.7)
  self.glow=glow
  local caption = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
  caption:SetPoint('TOP', icon, 'BOTTOM', 0, -2)
  caption:SetText('Direction unknown')
  frame:Hide()
  self.frame, self.icon, self.caption = frame, icon, caption
  local elapsed = 0
  frame:SetScript('OnUpdate', function(_, dt)
    if type(dt) ~= 'number' or dt ~= dt or dt < 0 or dt > 10 then return end
    elapsed = elapsed + dt
    if elapsed >= .1 then elapsed = 0; arrow:Refresh() end
  end)
  return frame
end

function arrow:Refresh()
  local frame = self:Create()
  if not frame then return false end
  local nav = addon.navigation
  local target = nav and not nav.paused and nav.target
  if not target then frame:Hide(); return false end
  frame:Show()
  local measure = type(nav.Guidance)=='function' and nav.Guidance or nav.Measure
  local ok, reading = pcall(measure, nav, target)
  if not ok or not reading then
    self.icon:Hide(); self.glow:Hide()
    self.caption:SetText('Direction unknown; route unknown'); return true
  end
  if reading.angle ~= nil and type(self.icon.SetRotation) == 'function' then
    self.icon:SetRotation(reading.angle)
    self.icon:Show()
    self.glow:Show()
  else self.icon:Hide(); self.glow:Hide() end
  if reading.distance then
    if reading.mode=='observed' then
      local suffix=reading.routeStatus=='partial-end' and '; end unknown' or ''
      if reading.targetDistance then
        self.caption:SetText(string.format('%.0f yd to target (direct)\n%.0f yd to waypoint%s',
          reading.targetDistance,reading.distance,suffix))
      else
        self.caption:SetText(string.format('%.0f yd to observed waypoint%s',reading.distance,suffix))
      end
    elseif reading.mode=='direct-unknown' then
      self.caption:SetText(string.format('%.0f yd DIRECT; route unknown',reading.distance))
    else
      self.caption:SetText(string.format('%.0f yd direct', reading.distance))
    end
  else
    self.caption:SetText(reading.mode=='direct-unknown' and
      'Distance unknown; route unknown' or 'Distance unknown')
  end
  return true
end
