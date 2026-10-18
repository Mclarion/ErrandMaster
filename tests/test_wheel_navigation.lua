local f=dofile('tests/wheel_fixture.lua')()
local w,db=f.wheel,f.addon.db
local settings=db.data.settings
local first=settings.wheelSlots[1]
f:root()
assert(w.count==11 and w.slots[7].texture.texture:find('PackTravel.blp',1,true))
f:click(4)
assert(w.submenu=='Vendor' and w.count==6 and #w.history==1)
assert(w.historyViews[1].icons[4].shown and
  w.historyViews[1].medallions[4].texture:find('GreenActive.blp',1,true))
assert(math.abs(w.historyViews[1].sectors[4].w-
  f.addon.wheelGeometry.artDiameter(w.tiers[1].outerRadius))<.001)
assert(w.tiers[2].innerRadius==w.tiers[1].outerRadius)
assert(w.slots[1].texture.texture:find('PackFood.blp',1,true))
f:click(4)
assert(w.submenu=='Profession Vendor' and #w.history==2)
assert(w.tiers[3].innerRadius==w.tiers[2].outerRadius)
assert(w.menuEntries[1].category=='Cooking Vendor' or
  w.menuEntries[1].category:find('Vendor',1,true))
assert(w.slots[1].texture.shown and not w.slots[1].label.shown)
for i=1,w.count do
  assert(f:hit(i,nil,.96)==i)
end
f:click(w.count)
assert(w.submenu=='Vendor' and #w.history==1)
f:click(w.count)
assert(w.submenu==nil and #w.history==0 and w.slots[1].sector.uv[1]==0 and
  w.slots[1].sector.uv[2]==0,'returning root resets all sampled coordinates')
assert(settings.wheelSlots[1]==first,'navigation preserves existing custom layout')
-- Other retained menus remain reachable and return without changing slots.
f:click(7)
assert(w.submenu=='Travel' and w.menuEntries[1].category=='Flight Master')
f:click(5)
assert(w.submenu=='Waypoint' and w.menuEntries[1].category=='Pin')
f:click(2)
assert(w.submenu=='Travel')
f:click(6)
assert(w.submenu=='Favorites' and w.menuEntries[1].category=='Add Coordinates')
f:click(w.count)
assert(w.submenu=='Travel')
f:click(w.count)
assert(w.submenu==nil)
f.addon.quests={ZoneInventory=function() return {
  {name='Loch Modan',quests={{questID=321,title='Log quest without POI',hasLocation=false}}},
  {name='Ashenvale',quests={{questID=322,title='Second zone',hasLocation=false}}},
},true end}
f:click(9)
assert(w.submenu=='Quests' and w.menuEntries[1].name=='Loch Modan' and
  w.menuEntries[2].name=='Ashenvale','quest log zones replace obsolete current-map POIs')
f:click(1)
assert(w.submenu=='Quest Zone' and w.menuEntries[1].name=='Log quest without POI',
  'quest lacking a POI remains visible in its zone')
f:click(w.count)
assert(w.submenu=='Quests' and w.menuEntries[2].name=='Ashenvale')
f:click(w.count)
assert(w.submenu==nil)
local opened=0
f.addon.addonSettings={Open=function(_,page) opened=opened+1; assert(page=='layout' or page==nil) end}
f:click(8); f:click(3)
assert(w.submenu=='Settings')
f:click(1)
assert(settings.wheelUnlocked and settings.wheelPinned==nil)
f:click(1)
assert(not settings.wheelUnlocked)
f:click(2)
assert(opened==1 and not w.frame.shown)
-- Vendor and trainer menus still read database-selected professions.
settings.wheelProfessions={Alchemy=true,Mining=true}
local old=db.GetWheelProfessions
db.GetWheelProfessions=function() return {'Alchemy','Mining','Cooking','First Aid','Fishing'} end
f:root(); f:click(4); f:click(4)
assert(w.count==6 and w.menuEntries[1].category=='Alchemy Vendor' and
  w.menuEntries[2].category=='Mining Vendor')
assert(w.slots[1].texture.texture:find('PackAlchemyVendor.blp',1,true) and
  w.slots[2].texture.texture:find('PackMiningVendor.blp',1,true))
w:Close(); f:root(); f:click(6); f:click(2)
assert(w.submenu=='Profession Trainer' and w.menuEntries[1].category=='Alchemy Trainer' and
  w.slots[1].texture.texture:find('PackAlchemyTrainer.blp',1,true))
db.GetWheelProfessions=old
w:Close()
-- Collections remain navigable while unlocked; no combat action is triggered.
settings.wheelUnlocked=true
f:root(); f:click(10)
assert(w.submenu=='Skills' and w:DropEntry({type='spell',id=1234}))
assert(settings.wheelSkills[1].id==1234 and w.count==2)
f:click(2)
assert(w.submenu==nil)
f:click(11)
assert(w.submenu=='Items' and w:DropEntry({type='item',id=5678}))
assert(settings.wheelItems[1].id==5678)
f:click(2)
assert(w.submenu==nil)
f:click(8); f:click(3); f:click(2)
assert(opened==2 and w.frame.shown and settings.wheelUnlocked,
  'ordinary settings action must not dismiss persistent edit mode')
settings.wheelUnlocked=false
print('nested palette, defaults, professions, settings and collection navigation passed')
