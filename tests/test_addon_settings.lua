-- Isolated WoW frame and DB contract mocks; no SavedVariables or client globals.
local function frame(kind, parent)
  local f = {kind=kind, parent=parent, scripts={}, shown=true, children={}}
  if parent then parent.children[#parent.children+1] = f end
  function f:CreateFontString() return frame("FontString", self) end
  function f:CreateTexture() return frame("Texture", self) end
  function f:SetPoint(...) self.point={...} end
  function f:ClearAllPoints() self.point=nil end
  function f:SetSize(w,h) self.w,self.h=w,h end
  function f:SetText(text) self.text=text end
  function f:SetTexture(texture) self.texture=texture end
  function f:SetVertexColor(...) self.color={...} end
  function f:SetBlendMode(mode) self.blend=mode end
  function f:GetText() return self.text end
  function f:SetChecked(value) self.checked=value end
  function f:GetChecked() return self.checked end
  function f:SetScript(event, fn) self.scripts[event]=fn end
  function f:SetAllPoints() end
  function f:SetColorTexture() end
  function f:SetFrameStrata() end
  function f:Disable() self.disabled=true end
  function f:Enable() self.disabled=false end
  function f:SetParent(value) self.parent=value end
  function f:Show() self.shown=true end
  function f:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
  function f:IsShown() return self.shown end
  function f:Click(checked)
    if checked ~= nil then self.checked=checked end
    assert(self.scripts.OnClick, 'missing click handler')(self)
  end
  return f
end
UIParent = frame('Frame')
CreateFrame = function(kind, _, parent) return frame(kind, parent) end
local function makeAddon()
  local refreshes,captures,editors,sections=0,0,0,0
  local addon
  addon={radial={StartCapture=function() captures=captures+1; return true end,
    StopCapture=function() addon.radial.captureActive=false end,
    BindingText=function() return 'Key: CTRL-G' end,
    Open=function() editors=editors+1 end}}
  assert(loadfile('Core/Database.lua'))('ErrandMaster',addon)
  ErrandMasterDB=nil;addon.db:Initialize('settings-test')
  function addon.db:WheelAddMissingDefaults() sections=sections+1;return 4 end
  function addon:Refresh() refreshes=refreshes+1 end
  return addon,function() return addon.db:ProfessionOverrides(),refreshes,captures,editors,sections end
end
local source = assert(loadfile('UI/AddonSettings.lua'))
local function load()
  local addon,state=makeAddon()
  source('ErrandMaster',addon)
  return addon,addon.addonSettings,state
end
local addon,page,state=load()
local calls, opened = 0, nil
Settings={RegisterCanvasLayoutCategory=function(f,name)
  calls=calls+1; assert(f==page.frame and name=='ErrandMaster')
  return {GetID=function() return 99 end}
end, RegisterAddOnCategory=function(c) assert(c:GetID()==99) end,
  OpenToCategory=function(id) opened=id end}
assert(page:Register() and page.mode=='settings')
assert(page:Register() and calls==1, 'registration must be idempotent')
assert(page:Open() and opened==99)
assert(page.frame.w==460 and page.frame.h==490)
local headerIcon,headerGlow
for _,child in ipairs(page.frame.children) do
  if child.kind=='Texture' and child.texture and child.texture:find('PackLogo.blp',1,true) then headerIcon=child end
  if child.kind=='Texture' and child.texture and child.texture:find('DestinationButtonGlow.blp',1,true) then headerGlow=child end
end
assert(headerIcon and headerGlow and headerIcon.w<=25 and headerGlow.w>=46 and
  headerGlow.blend=='ADD' and headerGlow.color[4]>=.85,
  'settings header logo retains its rim, with a stronger independent backlight')
local function within(canvas, child)
  if child.point and child.point[2]==canvas and child.point[3]=='TOPLEFT' then
    local x,y=child.point[4],child.point[5]
    assert(x>=0 and -y>=0 and x+(child.w or 0)<=canvas.w and
      -y+(child.h or 0)<=canvas.h, 'control exceeds compact canvas')
  end
  for _, nested in ipairs(child.children) do within(child,nested) end
end
for _, child in ipairs(page.frame.children) do within(page.frame,child) end
assert(page.bind and page.pickButtons[1] and page.pickButtons[2] and
  page.commonChecks.Cooking and page.commonChecks.Fishing and page.commonChecks['First Aid'])
assert(not page.flip and not page.tomtom and not page.advanced, 'no flip, external arrow or expert modal controls')
assert(page.activeTab=='general' and page.panels.general:IsShown() and not page.panels.layout:IsShown())
assert(page.tabs.general.disabled and page.tabs.general.text:find('General',1,true))
assert(page.bindingStatus.text=='Key: CTRL-G')
assert(page.pickButtons[1].text:find('All professions',1,true))
assert(page.commonChecks.Cooking.checked and page.commonChecks.Fishing.checked and page.commonChecks['First Aid'].checked)
page.pickButtons[1]:Click()
assert(page.menus[1]:IsShown() and not page.menus[2]:IsShown())
page.menus[1].children[3]:Click() -- The second choice (Alchemy) follows the menu backdrop.
assert(page.picks[1]=='Alchemy' and #addon.db:GetWheelProfessions()==12)
page.pickButtons[2]:Click()
page.menus[2].children[9]:Click() -- Mining through the actual second dropdown.
assert(page.picks[2]=='Mining' and #addon.db:GetWheelProfessions()==5)
page.pickButtons[2]:Click()
page.menus[2].children[2]:Click() -- None removes the second choice.
assert(page.picks[1]=='Alchemy' and not page.picks[2] and #addon.db:GetWheelProfessions()==12)
page:Select(2,'Mining')
page:Select(2,'Alchemy')
assert(not page.picks[1] and page.picks[2]=='Alchemy', 'duplicate main trades collapse')
page.commonChecks.Cooking:Click(false)
assert(#addon.db:GetWheelProfessions()==11)
page:Refresh();assert(not page.commonChecks.Cooking.checked)
assert(not page.menus[1]:IsShown())
page.optimize:Click(false)
page.targets:Click(false)
assert(addon.db.data.settings.optimize==false and addon.db.data.settings.showDestinations==false)
assert(page.waypointUI.checked and addon.db.data.settings.useWaypointUI==true)
page.waypointUI:Click(false)
assert(addon.db.data.settings.useWaypointUI==false)
page:Refresh();assert(not page.waypointUI.checked)
page.waypointUI:Click(true)
assert(addon.db.data.settings.useWaypointUI==true)
page.bind:Click()
assert(select(3,state())==1 and select(2,state())>0)
assert(page.status.text:find('Escape cancels',1,true))
page:Refresh()
assert(page.status.text:find('Escape cancels',1,true), 'refresh retains capture notice')
page:Notice('Wheel key set: CTRL-G.')
assert(page.status.text=='Wheel key set: CTRL-G.')
page:RefreshBinding()
assert(page.bindingStatus.text=='Key: CTRL-G')
addon.radial.captureActive=true
page.frame:Hide()
assert(not addon.radial.captureActive,'closing settings stops key capture')
page.tabs.layout:Click()
assert(page.activeTab=='layout' and page.panels.layout:IsShown() and not page.panels.general:IsShown())
assert(page.tabs.layout.disabled and not page.tabs.general.disabled and page.tabs.layout.text=='[ Layout ]')
page.nameInput:SetText('Supplies');page.addEntry:Click()
local slot=#addon.db.data.settings.wheelSlots
assert(addon.db.data.settings.wheelSlots[slot].type=='folder')
page.iconInput:SetText('134400');page.applyIcon:Click()
assert(addon.db.data.settings.wheelSlots[slot].icon==134400)
page.nameInput:SetText('New supplies');page.rename:Click()
assert(addon.db.data.settings.wheelSlots[slot].name=='New supplies')
page.editWheel:Click();assert(addon.db.data.settings.wheelUnlocked and select(4,state())==1)
-- Native options containers and standalone page must be hidden before wheel methods.
local order={}
SettingsPanel={Hide=function() order[#order+1]='modern' end}
InterfaceOptionsFrame={Hide=function() order[#order+1]='legacy' end}
addon.radial.SetEditing=function() order[#order+1]='edit' end
addon.radial.Open=function() order[#order+1]='open' end
page.frame:Show();page.editWheel:Click()
assert(table.concat(order,',')=='modern,legacy,edit,open' and not page.frame:IsShown())
order={};page.frame:Show();page.preview:Click()
assert(table.concat(order,',')=='modern,legacy,open' and not page.frame:IsShown())
SettingsPanel=nil;InterfaceOptionsFrame=nil
page.tabs.wheel:Click()
page.metrics.wheelRadius.value:SetText('40');page.metrics.wheelRadius.apply:Click()
page.metrics.wheelScale.value:SetText('0.5');page.metrics.wheelScale.apply:Click()
page.metrics.wheelIconSize.value:SetText('20');page.metrics.wheelIconSize.apply:Click()
assert(addon.db.data.settings.wheelRadius==40 and addon.db.data.settings.wheelScale==.5 and addon.db.data.settings.wheelIconSize==20)
page.metrics.wheelRadius.value:SetText('invalid');page.metrics.wheelRadius.apply:Click()
assert(addon.db.data.settings.wheelRadius==40 and page.status.text:find('range',1,true))
page.addSections:Click()
assert(select(5,state())==1 and page.status.text:find('Added 4 sections',1,true))

-- Preserve an unrelated manual filter when replacing a trade.
addon.db:AddProfession('Custom Trade')
page:Refresh()
page:Select(2,'Tailoring')
assert((state())[1]=='Custom Trade','new preferences preserve unrelated legacy filters')

-- Legacy registration and opening, including an absent modern Settings API.
Settings=nil
local legacy,legacyPage=load()
local added,openedLegacy=0,0
InterfaceOptions_AddCategory=function(f) added=added+1; assert(f.name=='ErrandMaster') end
InterfaceOptionsFrame_OpenToCategory=function(f) openedLegacy=openedLegacy+1; assert(f==legacyPage.frame) end
assert(legacyPage:Register()==legacyPage.frame and legacyPage.mode=='legacy')
assert(legacyPage:Open() and added==1 and openedLegacy==1)
InterfaceOptions_AddCategory=function() error('missing client API') end
InterfaceOptionsFrame_OpenToCategory=nil
local standalone,standalonePage=load()
assert(standalonePage:Register()==standalonePage.frame and standalonePage.mode=='standalone')
assert(standalonePage:Open() and standalonePage.frame:IsShown() and standalonePage.close:IsShown())
standalonePage.close:Click()
assert(not standalonePage.frame:IsShown())
InterfaceOptions_AddCategory=nil
local noApi,noApiPage=load()
assert(noApiPage:Open() and noApiPage.mode=='standalone')
Settings={RegisterCanvasLayoutCategory=function() error('unsupported') end,
  RegisterAddOnCategory=function() end}
local throwing,throwingPage=load()
assert(throwingPage:Open() and throwingPage.mode=='standalone')

-- Combat veto reverts controls without changing stored preferences.
InCombatLockdown=function() return true end
noApiPage:Select(1,'Mining')
noApiPage.commonChecks.Fishing:Click(false)
noApiPage.optimize:Click(false)
assert(#noApi.db:ProfessionOverrides()==0 and noApi.db.data.settings.optimize==true)
assert(noApiPage.commonChecks.Fishing:GetChecked())
InCombatLockdown=nil
print('addon settings mocks: registration, controls, fallback, and combat PASS')
