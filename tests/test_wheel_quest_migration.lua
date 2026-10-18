-- One-time safe quest-root migration: never reorder, replace, or resurrect.
local addon={}
assert(loadfile('Core/Database.lua'))('ErrandMaster',addon)
local function saved(slots)
  ErrandMasterDB={schema=5,nextId=1,nextLocationId=1,account={},characters={},locations={},
    settings={wheelSlots=slots}}
  addon.db:Initialize('Migration-Test')
  return ErrandMasterDB.settings
end
local slots={{type='category',category='Bank'},{type='folder',name='Favorites',entries={
  {type='category',category='Vendor'},{type='item',id=55}}}}
local settings=saved(slots)
assert(#settings.wheelSlots==3 and settings.wheelSlots[3].category=='Quests' and
  settings.wheelSlots[2].entries[2].id==55 and settings.wheelSlots[1].category=='Bank',
  'append missing Quests without changing custom root or folder contents')
addon.db:Initialize('Migration-Test')
assert(#settings.wheelSlots==3,'migration is idempotent')
assert(addon.db:WheelRemove(3))
addon.db:Initialize('Migration-Test')
assert(#settings.wheelSlots==2,'intentional later removal persists')
settings=saved({{type='folder',name='Quest bag',entries={{type='category',category='Quests'}}}})
assert(#settings.wheelSlots==1 and settings.wheelSlots[1].entries[1].category=='Quests',
  'nested category is reachable and not duplicated')
slots={}
for i=1,24 do slots[i]={type='item',id=i} end
settings=saved(slots)
assert(#settings.wheelSlots==24 and settings.wheelSlots[24].id==24 and
  settings.wheelQuestMigrationStatus=='full',
  'full wheel records explicit capacity failure without destroying user slots')
addon.db:WheelRemove(24)
addon.db:Initialize('Migration-Test')
assert(#settings.wheelSlots==23,'full one-time migration does not reinsert later')
settings=saved({})
assert(#settings.wheelSlots==0,'intentionally empty layout stays empty')
print('one-time quest root migration tests passed')
