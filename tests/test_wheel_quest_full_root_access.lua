-- Exercise the actual center-button handler: a full custom root cannot accept a 25th wedge.
local f=dofile('tests/wheel_fixture.lua')()
local w,db=f.wheel,f.addon.db
local slots={}
for i=1,24 do slots[i]={type='item',id=i} end
ErrandMasterDB={schema=5,nextId=1,nextLocationId=1,account={},characters={},locations={},
  settings={wheelSlots=slots}}
db:Initialize('Wheel-Fixture')
local settings=db.data.settings
assert(settings.wheelQuestMigrationStatus=='full' and #settings.wheelSlots==24)
for i=1,24 do assert(settings.wheelSlots[i].id==i) end
f.addon.quests={ZoneInventory=function() return {{name='Loch Modan',quests={
  {questID=501,title='A local quest',hasLocation=false}}}},true end}
f:root()
assert(w.count==24 and w.menuEntries==nil)
assert(w.hintText.text:find('Right-click the center',1,true),
  'the built-in shortcut must be discoverable on a full custom root')
w.centerClose.scripts.OnMouseDown(w.centerClose,'RightButton')
w.centerClose.scripts.OnClick(w.centerClose,'RightButton')
assert(w.submenu=='Quests' and w.menuEntries[1].name=='Loch Modan',
  'full custom root needs built-in quest navigation without a root wedge')
f:click(1)
assert(w.submenu=='Quest Zone' and w.menuEntries[1].name=='A local quest',
  'the fallback must reach the actual character quest log')
assert(#settings.wheelSlots==24 and w.tiers[1].count==24 and w.count<=24,
  'navigation cannot mutate saved slots or render a 25th wedge')
f:click(w.count)
assert(w.submenu=='Quests' and w.count<=24)
f:click(w.count)
assert(w.submenu==nil and w.count==24 and w.frame:IsShown(),
  'Back returns through both built-in levels to the unchanged full root')
for i=1,24 do assert(settings.wheelSlots[i].id==i) end
w.centerClose.scripts.OnClick(w.centerClose,'LeftButton')
assert(not w.frame:IsShown(),'left-click center still closes')
-- A category deliberately removed from a migrated layout must not be restored.
settings.wheelQuestMigrationStatus='present'
f:root()
w.centerClose.scripts.OnClick(w.centerClose,'RightButton')
assert(w.submenu==nil and not w.frame:IsShown() and #settings.wheelSlots==24,
  'intentional removal does not enable the capacity-only shortcut')
settings.wheelQuestMigrationStatus='full'
assert(db:WheelRemove(24))
f:root()
w.centerClose.scripts.OnClick(w.centerClose,'RightButton')
assert(w.submenu==nil and not w.frame:IsShown() and #settings.wheelSlots==23,
  'shortcut ceases when the root is no longer full')
-- Exercise the editor's add and trash pathways, rather than changing the status by hand.
assert(w:SetEditing(true))
assert(w:DropEntry({type='item',id=24}) and #settings.wheelSlots==24)
w.dragIndex,w.hoverRemove=24,true
w:FinishDrag()
assert(#settings.wheelSlots==23 and settings.wheelQuestMigrationStatus=='full')
assert(w:DropEntry({type='category',category='Quests'}) and #settings.wheelSlots==24)
assert(settings.wheelQuestMigrationStatus~='full',
  'explicitly adding Quests resolves the full-root migration')
w.dragIndex,w.hoverRemove=24,true
w:FinishDrag()
assert(w:DropEntry({type='item',id=24}) and #settings.wheelSlots==24)
for i=1,24 do assert(settings.wheelSlots[i].id==i, 'custom entries must survive editing') end
f:root()
assert(not w.hintText.text:find('Right-click the center',1,true),
  'removed Quests must not revive the migration shortcut')
w.centerClose.scripts.OnClick(w.centerClose,'RightButton')
assert(w.submenu==nil and not w.frame:IsShown(),
  'intentional removal from a full root does not reopen Quests')
print('full custom root quest access tests passed')
