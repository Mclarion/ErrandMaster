--[[ Retired label-around-wedges and obsolete color expectations. Current
-- hierarchy coverage lives in tests/test_wheel_navigation.lua.
-- Exercise the new default hierarchy without altering an older player's custom slots.
local addon = {ui={}}
local function frame()
  local object={scripts={},shown=false}
  setmetatable(object,{__index=function(_,method)
    if method=='CreateFontString' or method=='CreateTexture' then
      return function() return frame() end end
    if method=='SetScript' then return function(self,name,callback) self.scripts[name]=callback end end
    if method=='SetSize' then return function(self,w,h) self.w,self.h=w,h end end
    if method=='SetWidth' then return function(self,w) self.w=w end end
    if method=='SetHeight' then return function(self,h) self.h=h end end
    if method=='SetPoint' then return function(self,...) self.point={...} end end
    if method=='GetWidth' then return function(self) return self.w end end
    if method=='GetHeight' then return function(self) return self.h end end
    if method=='SetText' then return function(self,text) self.text=text end end
    if method=='SetTexture' then return function(self,texture) self.texture=texture end end
    if method=='SetAlpha' then return function(self,alpha) self.alpha=alpha end end
    if method=='SetDesaturated' then return function(self,value) self.desaturated=value end end
    if method=='SetRotation' then return function(self,value) self.rotation=value end end
    if method=='SetVertexColor' then return function(self,...) self.color={...} end end
    if method=='Show' then return function(self) self.shown=true end end
    if method=='Hide' then return function(self) self.shown=false end end
    if method=='IsShown' then return function(self) return self.shown end end
    return function() end
  end})
  object.TitleText={SetText=function() end}
  return object
end
UIParent=frame(); UIParent.w,UIParent.h=1920,1080
UIParent.GetEffectiveScale=function() return 1 end
CreateFrame=function() return frame() end
UISpecialFrames={}
local mx,my=960,540
GetCursorPosition=function() return mx,my end
InCombatLockdown=function() return false end
local open,notice,queued,settingsOpened={},{},{},0
addon.Print=function(_,message) notice[#notice+1]=message end
addon.Refresh=function() end
addon.ProfessionFilters=function() return {'Alchemy','Mining'} end
addon.addonSettings={Open=function() settingsOpened=settingsOpened+1 end}
local questAdds={}
addon.Position=function() return 10 end
addon.quests={OnMap=function(_,map)
  assert(map==10)
  return {{title='A Local Quest',questID=321,mapID=10,x=.2,y=.3}}
end, Add=function(_,id,map)
  questAdds[#questAdds+1]={id,map}; return {name='A Local Quest'}
end}
addon.ui.OpenCategory=function(_,category) open[#open+1]=category end
addon.ui.Refresh=function() end
addon.ui.frame=frame()
addon.errands={All=function() return queued end,Add=function(_,item)
  queued[#queued+1]=item; return item end}
assert(loadfile('Core/Database.lua'))('ErrandMaster',addon)
ErrandMasterDB=nil
addon.db:Initialize('Wheel-Test')
assert(loadfile('UI/RadialMenu.lua'))('ErrandMaster',addon)
local wheel=addon.radial
local function click(index)
  local angle=wheel.tiers[#wheel.tiers].angles[index]
  mx,my=wheel.centerX+wheel.radius*math.cos(angle),
    wheel.centerY+wheel.radius*math.sin(angle)
  wheel.frame.scripts.OnMouseDown(wheel.frame,'LeftButton')
end
local function openWheel()
  mx,my=960,540
  assert(wheel:Open() and wheel.frame:IsShown())
end
openWheel()
assert(wheel.count==11 and wheel.slots[11].label.shown,
  'all 11 default categories stay labeled')
assert(wheel.slots[7].texture.texture:find('PackTravel.blp',1,true) and
  wheel.slots[9].texture.texture:find('PackQuestmark.blp',1,true) and
  wheel.lockIcon.texture:find('PackPadlockUnlocked.blp',1,true),
  'fresh root uses the supplied travel, quest and edit-action icons')
local palette={Bank={.157,.439,1},['Auction House']={.675,.208,.847},
  Repair={.933,.188,.188},Vendor={.031,.745,.471},Mailbox={.933,.537,0},
  Trainer={0,.741,.835},Travel={.914,.686,0},Custom={.898,.169,.51}}
for i=1,8 do
  local wanted=palette[addon.db.data.settings.wheelSlots[i].category]
  local actual=wheel.slots[i].sector.color
  for channel=1,3 do assert(actual[channel]==wanted[channel]) end
  assert(wheel.slots[i].glow.color[1]==1 and
    wheel.slots[i].glow.color[2]==1 and wheel.slots[i].glow.color[3]==1,
    'golden borders must not take the wedge category tint')
end
click(4); assert(wheel.submenu=='Vendor' and wheel.count==6)
assert(wheel.historyViews[1].medallions[4].texture:find('MedallionGreenActive.blp',1,true),
  'open submenu keeps its parent medallion active')
assert(wheel.historyViews[1].medallions[4].rotation==
  wheel.historyViews[1].sectors[4].rotation and
  math.abs(wheel.historyViews[1].sectors[4].w-
    wheel.tiers[1].outerRadius*2*math.sqrt(2))<.001,
  'retained rings use the same orientation and rotation compensation as the active ring')
assert(wheel.slots[1].medallion.texture:find('MedallionRedInactive.blp',1,true))
assert(#wheel.history==1 and wheel.history[1].menu==nil and
  wheel.historyViews[1].icons[4].shown and
  wheel.historyViews[1].icons[1].texture:find('PackBank.blp',1,true) and
  wheel.historyViews[1].icons[4].alpha==1 and
  wheel.historyViews[1].sectors[4].alpha>wheel.historyViews[1].sectors[1].alpha,
  'root wheel remains visible with intact, lit selected icon')
assert(wheel.centerX==wheel.history[1].x and wheel.centerY==wheel.history[1].y and
  wheel.tiers[2].innerRadius>=wheel.tiers[1].outerRadius and
  wheel.tiers[2].sweep<2*math.pi,
  'children occupy a partial outer ring around the same center')
local away=wheel.tiers[2].centerAngle+math.pi
mx,my=wheel.centerX+wheel.radius*math.cos(away),
  wheel.centerY+wheel.radius*math.sin(away)
assert(wheel:IndexAtCursor()==nil,'empty side of a partial submenu is not clickable')
local bankAngle=wheel.tiers[1].angles[1]
mx,my=wheel.centerX+wheel.tiers[1].radius*math.cos(bankAngle),
  wheel.centerY+wheel.tiers[1].radius*math.sin(bankAngle)
wheel.frame.scripts.OnMouseDown(wheel.frame,'LeftButton')
assert(wheel.submenu=='Bank','inner-ring choice remains interactive when a child is open')
click(3); click(4)
assert(wheel.submenu=='Vendor','Back then a different root choice opens its ring')
assert(wheel.slots[1].texture.texture:find('PackFood.blp',1,true) and
  wheel.slots[2].texture.texture:find('PackReagents.blp',1,true) and
  wheel.slots[3].texture.texture:find('PackAmmo.blp',1,true),
  'use the newly supplied art in the corresponding vendor choices')
assert(wheel.slots[1].sector.color[1]==.933 and
  wheel.slots[2].sector.color[3]==.847 and
  wheel.slots[3].sector.color[1]==.68, 'vendor choices inherit pack colors')
assert(wheel.slots[4].texture.texture:find('PackProfessionVendor.blp',1,true) and
  wheel.slots[5].texture.texture:find('PackGeneral.blp',1,true) and
  wheel.slots[6].texture.texture:find('PackBack.blp',1,true))
assert(wheel.slots[4].label.text=='Profession Vendor' and
  wheel.slots[4].label.point[1]=='CENTER' and
  wheel.tiers[2].iconSize+wheel.tiers[2].labelHeight <=
    wheel.tiers[2].outerRadius-wheel.tiers[2].innerRadius,
  'full labels and icons fit inside each annular wedge without truncation')
local function hasOverlap(slot)
  local image,label=slot.texture,slot.label
  return math.abs(image.point[4]-label.point[4])<(image.w+label.w)/2 and
    math.abs(image.point[5]-label.point[5])<(image.h+label.h)/2
end
for i=1,wheel.count do
  assert(not hasOverlap(wheel.slots[i]),'vendor icon/text boxes must not overlap')
end
click(4); assert(wheel.submenu=='Profession Vendor' and wheel.count==6)
for i=1,wheel.count do
  assert(not hasOverlap(wheel.slots[i]),'profession icon/text boxes must not overlap')
end
assert(#wheel.history==2 and wheel.tiers[3].innerRadius>=wheel.tiers[2].outerRadius and
  wheel.tiers[3].sweep<2*math.pi and wheel.tiers[3].centerAngle==wheel.tiers[2].angles[4],
  'third tier opens outside the second and points at its selected parent')
assert(wheel.slots[1].texture.texture:find('PackAlchemyVendor.blp',1,true))
assert(wheel.menuEntries[3].category=='Cooking Vendor' and
  wheel.menuEntries[4].category=='First Aid Vendor' and
  wheel.menuEntries[5].category=='Fishing Vendor' and
  wheel.slots[5].texture.texture:find('PackFishingVendor.blp',1,true))
click(2); assert(queued[1].category=='Mining Vendor' and not wheel.frame:IsShown())
openWheel(); click(4); click(4); click(6)
assert(wheel.submenu=='Vendor' and #wheel.history==1 and
  not wheel.historyViews[2].icons[4].shown and wheel.frame:IsShown(),
  'nested Back restores the previous ring and hides only the deepest tier')
click(6); assert(wheel.submenu==nil and #wheel.history==0 and
  not wheel.historyViews[1].icons[4].shown,
  'Vendor Back returns to the main ring and clears inactive layers')
assert(wheel.slots[1].sector.rotation==0 and wheel.slots[1].glow.rotation==0,
  'returning from a rotated submenu resets the first root wedge and gold border')
addon.ProfessionFilters=function() return {'Herbalism','Blacksmithing'} end
click(4); click(4)
assert(wheel.count==6 and
  wheel.slots[1].texture.texture:find('PackHerbalismVendor.blp',1,true) and
  wheel.slots[2].texture.texture:find('PackBlacksmithingVendor.blp',1,true) and
  wheel.slots[1].sector.color[2]==.745 and
  wheel.slots[2].sector.color[2]==.537,
  'known professions and common professions get matching art and colors')
click(6); click(6)
addon.ProfessionFilters=function() return {},'unavailable' end
click(4); click(4)
assert(wheel.count==13 and wheel.menuEntries[12].category=='Fishing Vendor',
  'without configured professions all nine primary and three common professions appear')
assert(wheel.slots[1].texture.texture:find('PackAlchemyVendor.blp',1,true),
  'Alchemy uses the newly supplied profession icon')
local vendorArt={['Cooking Vendor']='PackCookingVendor.blp',
  ['Enchanting Vendor']='PackEnchantmentVendor.blp',
  ['Engineering Vendor']='PackEngineeringVendor.blp',
  ['First Aid Vendor']='PackFirstAidVendor.blp',
  ['Fishing Vendor']='PackFishingVendor.blp',
  ['Leatherworking Vendor']='PackLeatherworkingVendor.blp',
  ['Mining Vendor']='PackMiningVendor.blp',
  ['Tailoring Vendor']='PackTailoringVendor.blp'}
for i,entry in ipairs(wheel.menuEntries) do
  if vendorArt[entry.category] then
    assert(wheel.slots[i].texture.texture:find(vendorArt[entry.category],1,true),
      entry.category..' uses its own supplied artwork')
  end
end
click(13); click(6)
addon.ProfessionFilters=function() return {'Unrecognized Profession'} end
click(4); click(4)
assert(wheel.count==13, 'an unrecognized profession must not hide the primary choices')
click(13); click(6)
addon.ProfessionFilters=function() return {'Alchemy','Mining'} end
UnitClass=function() return 'Rogue','ROGUE' end
click(6); assert(wheel.submenu=='Trainer' and wheel.count==4)
assert(wheel.slots[1].texture.texture:find('ClassRogue.blp',1,true) and
  wheel.slots[2].texture.texture:find('PackProfessionTrainer.blp',1,true))
click(2); assert(wheel.submenu=='Profession Trainer' and wheel.count==6)
assert(wheel.menuEntries[3].category=='Cooking Trainer' and
  wheel.menuEntries[4].category=='First Aid Trainer' and
  wheel.menuEntries[5].category=='Fishing Trainer' and
  wheel.slots[1].texture.texture:find('PackAlchemyTrainer.blp',1,true) and
  wheel.slots[3].texture.texture:find('PackCookingTrainer.blp',1,true) and
  wheel.slots[4].texture.texture:find('PackFirstAidTrainer.blp',1,true) and
  wheel.slots[5].texture.texture:find('PackFishingTrainer.blp',1,true) and
  wheel.slots[2].texture.texture:find('PackMiningTrainer.blp',1,true))
click(2); assert(queued[2].category=='Mining Trainer')
addon.ProfessionFilters=function() return {'Engineering','Enchanting'} end
openWheel(); click(6); click(2)
assert(wheel.menuEntries[1].category=='Engineering Trainer' and
  wheel.slots[1].texture.texture:find('PackEngineeringTrainer.blp',1,true) and
  wheel.menuEntries[2].category=='Enchanting Trainer' and
  wheel.slots[2].texture.texture:find('PackEnchantmentTrainer.blp',1,true))
click(6); click(4); wheel:Close()
addon.ProfessionFilters=function() return {'Herbalism','Blacksmithing'} end
openWheel(); click(6); click(2)
assert(wheel.menuEntries[1].category=='Herbalism Trainer' and
  wheel.slots[1].texture.texture:find('PackHerbalismTrainer.blp',1,true) and
  wheel.menuEntries[2].category=='Blacksmithing Trainer' and
  wheel.slots[2].texture.texture:find('PackBlacksmithingTrainer.blp',1,true))
click(6); click(4); wheel:Close()
addon.ProfessionFilters=function() return {'Leatherworking'} end
openWheel(); click(6); click(2)
assert(wheel.menuEntries[1].category=='Leatherworking Trainer' and
  wheel.slots[1].texture.texture:find('PackLeatherworkingTrainer.blp',1,true))
click(5); click(4); wheel:Close()
addon.ProfessionFilters=function() return {'Tailoring'} end
openWheel(); click(6); click(2)
assert(wheel.menuEntries[1].category=='Tailoring Trainer' and
  wheel.slots[1].texture.texture:find('PackTailoringTrainer.blp',1,true))
click(5); click(4); wheel:Close()
local pinOpened,formOpened,selectedWaypoint=0,0,nil
local savedWaypoint
addon.worldMap={Open=function() pinOpened=pinOpened+1; return true end}
addon.travelPoints={CurrentWaypoint=function() return savedWaypoint end,
  OpenFavoriteForm=function() formOpened=formOpened+1; return true end,
  SelectCurrent=function() selectedWaypoint=savedWaypoint.id; return true end,
  Favorites=function() local result={}; for _,item in ipairs(queued) do
    if item.favorite and not item.completed then result[#result+1]=item end
  end; return result end,
  RemoveFavorite=function(_,id) for _,item in ipairs(queued) do
    if item.id==id then item.favorite=false; return true end end end}
openWheel(); click(7); assert(wheel.submenu=='Travel' and wheel.count==7)
assert(wheel.slots[1].texture.texture:find('PackFlightMaster.blp',1,true) and
  wheel.slots[2].texture.texture:find('PackPortal.blp',1,true) and
  wheel.slots[3].texture.texture:find('PackBoat.blp',1,true) and
  wheel.slots[4].texture.texture:find('PackHearthstone.blp',1,true))
click(1); assert(queued[3].category=='Flight Master')
openWheel(); click(7); click(2)
assert(not wheel.frame:IsShown() and notice[#notice]:find('no route was queued',1,true),
  'portal/boat must not invent a route')
openWheel(); click(7); click(5)
assert(wheel.submenu=='Waypoint' and wheel.count==2 and
  wheel.slots[1].texture.texture:find('PackWaypoint.blp',1,true))
click(1)
assert(pinOpened==1 and addon.worldMap.pinMode and not wheel.frame:IsShown(),
  'Pin opens the map for one addon-owned waypoint click')
savedWaypoint={id='em-100',mapID=10,x=.3,y=.4}
openWheel(); click(7); click(5)
assert(wheel.count==3 and wheel.menuEntries[2].category=='Select Current',
  'a saved waypoint exposes Select Current')
click(2); assert(selectedWaypoint=='em-100')
openWheel(); click(5); assert(wheel.submenu=='Mailbox' and wheel.count==2 and
  wheel.slots[1].texture.texture:find('PackMailbox.blp',1,true))
click(1); assert(queued[4].category=='Mailbox')
openWheel(); click(8); assert(wheel.submenu=='Custom' and wheel.count==4)
assert(wheel.slots[3].texture.texture:find('PackSettings.blp',1,true))
click(3); assert(wheel.submenu=='Settings' and wheel.count==4 and
  wheel.menuEntries[1].category=='Edit Wheel' and
  wheel.menuEntries[2].category=='Pin Wheel' and
  wheel.lockButton.shown==false and wheel.pinButton.shown==false,
  'Edit and Pin/Unpin live in Settings, not an external rail')
click(1); assert(addon.db.data.settings.wheelUnlocked and wheel.frame:IsShown())
click(1); assert(not addon.db.data.settings.wheelUnlocked)
click(2); assert(addon.db.data.settings.wheelPinned and
  wheel.menuEntries[2].category=='Unpin Wheel')
click(2); assert(not addon.db.data.settings.wheelPinned)
click(3); assert(settingsOpened==1 and not wheel.frame:IsShown())
local activatedFavorite
addon.ActivateTarget=function(_,id) activatedFavorite=id; return true end
openWheel(); click(7); click(6)
assert(wheel.submenu=='Favorites' and wheel.count==4)
assert(wheel.historyViews[2].icons[6].texture:find('PackFavourites.blp',1,true),
  'Travel Favorites uses the supplied star')
click(1); assert(formOpened==1, 'Add Coordinates opens an input form')
openWheel(); click(7); click(6); click(2)
assert(wheel.submenu=='Current Favorites' and wheel.count==1,
  'empty current favorites retain a Back control')
wheel:Close()
queued[#queued+1]={id=73,name='Favorite Bank',category='Bank',favorite=true,completed=false}
openWheel(); click(7); click(6); click(2)
assert(wheel.submenu=='Current Favorites' and wheel.count==2 and
  wheel.slots[1].label.text:find('Favorite',1,true),
  'favorites list saved marked errands')
click(1); assert(activatedFavorite==73, 'favorite selects an existing errand')
wheel:Close()
openWheel(); click(7); click(6); click(3)
assert(wheel.submenu=='Remove Favorite' and wheel.count==2)
click(1); assert(not queued[#queued].favorite and queued[#queued].id==73,
  'remove from favorites retains the original target')
wheel:Close(); table.remove(queued)
openWheel(); click(9); assert(wheel.submenu=='Quests' and wheel.count==2)
click(1); assert(wheel.submenu=='Active Quests' and wheel.count==2)
click(1); assert(questAdds[1][1]==321 and questAdds[1][2]==10)
addon.quests.OnMap=function() return {} end
openWheel(); click(9); click(1)
assert(wheel.submenu=='Quests' and wheel.count==2 and
  wheel.hintText.text:find('No active quest POIs',1,true))
wheel:Close()
openWheel(); click(10); assert(wheel.submenu=='Skills' and wheel.count==1)
assert(wheel:DropEntry({type='spell',id=1234}) and wheel.count==2)
assert(not wheel:DropEntry({type='item',id=5678}) and wheel.count==2)
assert(addon.db.data.settings.wheelSkills[1].id==1234)
wheel:Close(); openWheel(); click(11)
assert(wheel.submenu=='Items' and wheel:DropEntry({type='item',id=5678}))
assert(addon.db.data.settings.wheelItems[1].id==5678)
assert(addon.db:WheelCollectionRemove('item',1))
wheel:Close(); openWheel()
assert(wheel.slots[1].texture.texture:find('PackBank.blp',1,true) and
  wheel.slots[2].texture.texture:find('PackAuctionHouse.blp',1,true) and
  wheel.slots[3].texture.texture:find('PackRepair.blp',1,true))
click(1); assert(wheel.submenu=='Bank' and wheel.count==3 and
  wheel.slots[2].texture.texture:find('PackGuild.blp',1,true))
click(2); assert(open[#open]=='Guild Bank' and not wheel.frame:IsShown(),
  'guild bank opens manual location entry; it is not a verified service route')
openWheel(); click(1); click(1)
assert(queued[5].category=='Bank' and not wheel.frame:IsShown())
addon.db:Initialize('Wheel-Test')
assert(#addon.db.data.settings.wheelItems==0 and
  addon.db.data.settings.wheelSkills[1].id==1234)
assert(wheel.centerClose and wheel.centerClose.icon.texture:find('PackCross.blp',1,true),
  'the supplied cross is a distinct clickable center control')
wheel.centerClose.scripts.OnClick(wheel.centerClose)
assert(not wheel.frame:IsShown(), 'center cross closes the wheel')
UIParent.w,UIParent.h=800,600; mx,my=400,300
assert(wheel:Open())
click(4); click(4)
assert(#wheel.history==2 and wheel.centerX>=wheel.outerRadius and
  wheel.centerX<=UIParent.w-wheel.outerRadius and
  wheel.centerY>=wheel.outerRadius and
  wheel.centerY<=UIParent.h-wheel.outerRadius,
  'three-tier ring fits a compact viewport')
wheel.slots[2].sector.SetRotation=false
wheel:Layout()
assert(not wheel.slots[2].sector.shown and wheel.slots[2].texture.shown,
  'missing texture rotation hides patterned wedges but preserves selection')
wheel:Close()
UIParent.w,UIParent.h=1920,1080
openWheel()
local settings=addon.db.data.settings
settings.wheelUnlocked=true
wheel:RefreshAppearance()
assert(wheel.centerClose.shown, 'Cross stays accessible while editing')
assert(wheel.lockIcon.texture:find('PackPadlockLocked.blp',1,true),
  'edit mode offers the supplied Lock action icon')
click(10)
assert(wheel.submenu=='Skills' and #wheel.history==1,
  'unlocked wheel can still open its drag/drop collection')
assert(wheel:DropEntry({type='spell',id=4321}) and wheel.count==3)
local oldX,oldY=wheel.centerX,wheel.centerY
local savedRoot=settings.wheelCenter
mx,my=oldX,oldY
wheel.centerClose.scripts.OnDragStart(wheel.centerClose)
assert(wheel.dragCenter, 'center Cross supports drag in edit mode')
mx,my=mx+75,my+40
wheel.frame.scripts.OnUpdate(wheel.frame)
assert(wheel.centerX>oldX+60 and wheel.centerY>oldY+30 and
  wheel.layoutX==wheel.centerX and #wheel.history==1,
  'dragging a nested wheel moves its active layer and connector')
wheel.centerClose.scripts.OnDragStop(wheel.centerClose)
assert(settings.wheelCenter==savedRoot,
  'moving a nested menu does not corrupt the saved root-wheel position')
wheel.centerClose.scripts.OnClick(wheel.centerClose)
assert(wheel.frame:IsShown(), 'drag release cannot accidentally close the wheel')
click(wheel.count)
assert(wheel.submenu==nil and #wheel.history==0,
  'Back remains usable while editing')
assert(addon.db:WheelCollectionRemove('spell',2))
click(11)
assert(wheel.submenu=='Items' and wheel:DropEntry({type='item',id=8753}),
  'unlocked wheel can open and edit the item collection too')
click(wheel.count)
assert(addon.db:WheelCollectionRemove('item',1))
click(8); assert(wheel.submenu=='Custom',
  'edit mode keeps Custom reachable so the user can return to Lock')
click(3); assert(wheel.submenu=='Settings' and wheel.menuEntries[1].category=='Lock Wheel')
settings.wheelPinned=true
local openedBefore=settingsOpened
click(3)
assert(settingsOpened==openedBefore+1 and not wheel.frame:IsShown(),
  'AddOns Settings dismisses even a pinned unlocked wheel before opening the page')
openWheel(); click(8); click(3); click(1)
assert(not settings.wheelUnlocked, 'reopened wheel can be locked via Custom > Settings')
openedBefore=settingsOpened
click(3)
assert(settingsOpened==openedBefore+1 and not wheel.frame:IsShown(),
  'AddOns Settings also dismisses a pinned locked wheel')
settings.wheelPinned=false
openWheel()
wheel.centerClose.scripts.OnMouseDown(wheel.centerClose)
wheel.centerClose.scripts.OnClick(wheel.centerClose)
assert(not wheel.frame:IsShown(), 'Cross closes an unlocked wheel')
settings.wheelUnlocked=false
print('default wheel palette, nested navigation and collection tests passed')
]]
dofile('tests/test_wheel_navigation.lua')
