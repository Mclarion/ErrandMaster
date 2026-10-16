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
  function f:GetText() return self.text end
  function f:SetChecked(value) self.checked=value end
  function f:GetChecked() return self.checked end
  function f:SetScript(event, fn) self.scripts[event]=fn end
  function f:SetAllPoints() end
  function f:SetColorTexture() end
  function f:SetFrameStrata() end
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
  local names, refreshes, captures, editors, sections = {}, 0, 0, 0, 0
  local db = {data={settings={optimize=true,useTomTom=true}}}
  function db:ProfessionOverrides()
    local copy={}
    for _,v in ipairs(names) do copy[#copy+1]=v end
    return copy
  end
  function db:AddProfession(name)
    for _,v in ipairs(names) do if v:lower()==name:lower() then return false end end
    names[#names+1]=name; return true
  end
  function db:RemoveProfession(name)
    for i,v in ipairs(names) do
      if v:lower()==name:lower() then table.remove(names,i); return true end
    end
    return false
  end
  function db:ClearProfessions() names={} end
  function db:WheelAddMissingDefaults() sections=sections+1; return 4 end
  local addon={db=db, radial={StartCapture=function() captures=captures+1 end,
    ShowSettings=function() editors=editors+1 end}}
  function addon:Refresh() refreshes=refreshes+1 end
  return addon, function() return names,refreshes,captures,editors,sections end
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
local function within(canvas, child)
  if child.point and child.point[2]==canvas and child.point[3]=='TOPLEFT' then
    local x,y=child.point[4],child.point[5]
    assert(x>=0 and -y>=0 and x+(child.w or 0)<=canvas.w and
      -y+(child.h or 0)<=canvas.h, 'control exceeds compact canvas')
  end
  for _, nested in ipairs(child.children) do within(canvas,nested) end
end
for _, child in ipairs(page.frame.children) do within(page.frame,child) end
assert(page.bind and page.pickButtons[1] and page.pickButtons[2] and
  page.commonChecks.Cooking and page.commonChecks.Fishing and page.commonChecks['First Aid'])
page.flip:Click(true)
assert(addon.db.data.settings.wheelArtReversed==true)
page.flip:Click(false)
assert(page.pickButtons[1].text:find('None',1,true) and page.detect.checked)
page.detect:Click(false)
assert(page.detect.checked and #(state())==0 and
  page.status.text:find('Choose a profession',1,true))
page.pickButtons[1]:Click()
assert(page.menus[1]:IsShown() and not page.menus[2]:IsShown())
page.menus[1].children[3]:Click() -- The second choice (Alchemy) follows the menu backdrop.
assert((state())[1]=='Alchemy' and page.pickButtons[1].text:find('Alchemy',1,true))
page:Select(2,'Mining')
assert((state())[2]=='Mining' and page.pickButtons[2].text:find('Mining',1,true))
page.pickButtons[2]:Click()
page.menus[2].children[2]:Click() -- None removes the second choice.
assert(#(state())==1 and (state())[1]=='Alchemy')
page:Select(2,'Mining')
page:Select(2,'Alchemy')
assert(#(state())==1 and (state())[1]=='Alchemy', 'duplicate main trades collapse')
page.commonChecks.Cooking:Click(true)
assert(#(state())==2 and (state())[2]=='Cooking')
page.commonChecks.Cooking:Click(false)
assert(#(state())==1)
page.detect:Click(true)
assert(#(state())==0 and page.detect.checked)
assert(not page.menus[1]:IsShown())
page.optimize:Click(false)
page.tomtom:Click(false)
assert(addon.db.data.settings.optimize==false and addon.db.data.settings.useTomTom==false)
page.bind:Click()
assert(select(3,state())==1 and select(2,state())>0)
assert(page.advanced, 'advanced controls need an accessible entry from AddOns Settings')
page.advanced:Click()
assert(select(4,state())==1, 'advanced wheel editor opens from AddOns Settings')
assert(page.status.text:find('Detected',1,true))
page.addSections:Click()
assert(select(5,state())==1 and page.status.text:find('Added 4 sections',1,true))

-- Preserve an unrelated manual filter when replacing a trade.
addon.db:AddProfession('Custom Trade')
page:Refresh()
page:Select(2,'Tailoring')
assert((state())[1]=='Custom Trade' and (state())[2]=='Tailoring')
page.detect:Click(true)
assert(#(state())==0, 'clear removes even legacy manual filters')

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
noApiPage.commonChecks.Fishing:Click(true)
noApiPage.optimize:Click(false)
assert(#noApi.db:ProfessionOverrides()==0 and noApi.db.data.settings.optimize==true)
assert(not noApiPage.commonChecks.Fishing:GetChecked())
InCombatLockdown=nil
print('addon settings mocks: registration, controls, fallback, and combat PASS')
