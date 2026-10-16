-- Dynamic wheel studio contract, independent of the live Forever client.
local addon = {ui={OpenCategory=function() end}, Print=function() end}
local frames = {}
local function frame()
  local f = {scripts={}, shown=false}
  setmetatable(f, {__index=function(_, key)
    if key == "intro" then return nil end
    if key == "CreateTexture" or key == "CreateFontString" then
      return function() return frame() end
    end
    if key == "CreateAnimationGroup" then return function()
      local group = {CreateAnimation=function() return frame() end,
        Stop=function() end, Play=function(self) self.played=true end}
      return group
    end end
    if key == "SetScript" then return function(self, name, fn) self.scripts[name]=fn end end
    if key == "SetSize" then return function(self,w,h) self.w,self.h=w,h end end
    if key == "SetScale" then return function(self,value) self.scale=value end end
    if key == "GetWidth" then return function(self) return self.w end end
    if key == "GetHeight" then return function(self) return self.h end end
    if key == "SetPoint" then return function(self,...) self.point={...} end end
    if key == "SetText" then return function(self,text) self.text=text end end
    if key == "GetText" then return function(self) return self.text end end
    if key == "SetTexture" then return function(self,text) self.texture=text end end
    if key == "Show" then return function(self) self.shown=true end end
    if key == "Hide" then return function(self)
      self.shown=false
      if self.scripts.OnHide then self.scripts.OnHide(self) end
    end end
    if key == "IsShown" then return function(self) return self.shown end end
    return function() end
  end})
  f.TitleText = {SetText=function() end}
  frames[#frames+1]=f
  return f
end
UIParent=frame(); UIParent.w,UIParent.h=1920,1080
UIParent.GetEffectiveScale=function() return 1 end
CreateFrame=function() return frame() end
UISpecialFrames={}
local x,y=960,540
GetCursorPosition=function() return x,y end
InCombatLockdown=function() return false end
GetTime=function() return _G.testTime or 0 end
SetCursor=function() end
local droppedKind,droppedID
GetCursorInfo=function()
  if droppedKind=='spell' then return droppedKind,88,nil,droppedID end
  return droppedKind,droppedID
end
CastSpell=function() error('must not cast') end
RunMacro=function() error('must not run') end
UseItemByName=function() error('must not use item') end
assert(loadfile('Core/Database.lua'))('ErrandMaster',addon)
ErrandMasterDB=nil
addon.db:Initialize('Wheel-Realm')
assert(loadfile('UI/RadialMenu.lua'))('ErrandMaster',addon)
local wheel=addon.radial
wheel:ShowSettings()
assert(wheel.settingsFrame.shown and #wheel.editorRows==12)
assert(wheel.settingsFrame.scale==1)
UIParent.w,UIParent.h=1024,650
wheel.settingsFrame.scripts.OnEvent(wheel.settingsFrame,'DISPLAY_SIZE_CHANGED')
assert(wheel.settingsFrame.scale<1 and 755*wheel.settingsFrame.scale<650,
  'the entire studio must fit a short game window')
UIParent.w,UIParent.h=1920,1080
wheel.settingsFrame.scripts.OnEvent(wheel.settingsFrame,'UI_SCALE_CHANGED')
assert(wheel.settingsFrame.scale==1)
local function button(label)
  for _,f in ipairs(frames) do if f.text==label and f.scripts.OnClick then return f end end
  error('button missing: '..label)
end
local function click(label)
  local b=button(label); b.scripts.OnClick(b)
end
-- Game cursor drops and manual addon catalog entries grow the wheel; no gameplay actions.
droppedKind,droppedID='spell',31415
assert(wheel:DropNative() and #addon.db.data.settings.wheelSlots==8)
C_AddOns={GetNumAddOns=function() return 1 end,
  GetAddOnName=function(index) assert(index==1); return 'ErrandMaster' end}
click('Browse addons')
assert(wheel.slotType.text=='addon' and wheel.slotValue.text=='ErrandMaster')
click('Add entry')
assert(#addon.db.data.settings.wheelSlots==9)
wheel.slotType:SetText('item'); wheel.slotValue:SetText('1212')
click('Add entry')
assert(#addon.db.data.settings.wheelSlots==10)
local location={}
C_Cursor={GetCursorItem=function() return location end}
C_Item={GetItemID=function(value) assert(value==location); return 4444 end}
droppedKind,droppedID='item',999
assert(wheel:DropNative() and addon.db.data.settings.wheelSlots[11].id==4444)
assert(wheel:DropNative()==true)
assert(#addon.db.data.settings.wheelSlots==12)
assert(wheel:Open() and wheel.count==12 and wheel.radius>110)
assert(wheel.slots[12].texture.shown and wheel.frame.intro.played)
assert(wheel.slots[12].badge.text=='12' and wheel.slots[12].badge.point[1]=='TOPRIGHT')
wheel:Close()
-- Selecting #2 exposes remove/reorder; Active changes destination on the wheel.
wheel.editorRows[2].scripts.OnClick(wheel.editorRows[2])
assert(wheel.editorIndex==2)
click('Set ACTIVE / Move')
assert(wheel.activeIndex==2 and wheel.editorRows[2].text:find('Active',1,true))
assert(wheel:Open() and wheel.slots[2].badge.text=='A2')
x,y=960,540+wheel.radius
wheel.frame.scripts.OnMouseDown(wheel.frame,'LeftButton')
assert(wheel.activeIndex==nil and addon.db.data.settings.wheelSlots[1].category=='Bank')
-- Drop one row onto another quickly to reorder; hover for a folder.
wheel.editorRows[2].scripts.OnDragStart(wheel.editorRows[2])
_G.testTime=1
wheel.editorRows[1].scripts.OnEnter(wheel.editorRows[1])
wheel.editorRows[2].scripts.OnDragStop(wheel.editorRows[2])
assert(addon.db.data.settings.wheelSlots[1].category=='Repair')
wheel.folderName:SetText('Travel')
wheel.editorRows[2].scripts.OnDragStart(wheel.editorRows[2])
wheel.editorRows[1].scripts.OnEnter(wheel.editorRows[1])
_G.testTime=2
wheel.editorRows[2].scripts.OnDragStop(wheel.editorRows[2])
assert(addon.db.data.settings.wheelSlots[1].type=='folder')
assert(addon.db.data.settings.wheelSlots[1].name=='Travel' and
  #addon.db.data.settings.wheelSlots[1].entries==2)
wheel.editorRows[1].scripts.OnClick(wheel.editorRows[1])
assert(wheel.folderRows[1].shown)
x,y=960,540
assert(wheel:Open())
x,y=wheel.centerX,wheel.centerY+wheel.radius
wheel.frame.scripts.OnMouseDown(wheel.frame,'LeftButton')
assert(wheel.count==3 and wheel.submenu=='folder') -- two children and Back
wheel:Close()
wheel.folderRows[1].scripts.OnClick(wheel.folderRows[1])
assert(addon.db.data.settings.wheelSlots[1].type=='category')
-- Dragging to the explicit removal zone removes the source entry.
local count=#addon.db.data.settings.wheelSlots
wheel.editorRows[2].scripts.OnDragStart(wheel.editorRows[2])
local trash=button('Drag here to REMOVE')
trash.scripts.OnReceiveDrag(trash)
assert(#addon.db.data.settings.wheelSlots==count-1)
click('Scale +'); click('Theme')
assert(addon.db.data.settings.wheelScale>1 and addon.db.data.settings.wheelTheme=='Ember')
-- Invalid/protected cursor data, combat and full-wheel drops cannot mutate state.
count=#addon.db.data.settings.wheelSlots
GetCursorInfo=function() error('protected') end
assert(not wheel:DropNative() and #addon.db.data.settings.wheelSlots==count)
GetCursorInfo=function() return 'spell',123 end
assert(not wheel:DropNative() and #addon.db.data.settings.wheelSlots==count,
  'spellbook cursor slot must never be misread as a spell ID')
GetCursorInfo=function() return 'spell',1,nil,123 end
InCombatLockdown=function() return true end
assert(not wheel:DropNative() and #addon.db.data.settings.wheelSlots==count)
print('dynamic wheel editor tests passed')
