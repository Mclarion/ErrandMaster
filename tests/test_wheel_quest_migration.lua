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
assert(#settings.wheelSlots==5 and settings.wheelSlots[5].category=='Quests' and
  settings.wheelSlots[2].entries[2].id==55 and settings.wheelSlots[1].category=='Services' and
  settings.wheelSlots[3].category=='Travel' and settings.wheelSlots[4].category=='Trainer',
  'legacy Bank moves under Services; missing Quests append without changing folder contents')
addon.db:Initialize('Migration-Test')
assert(#settings.wheelSlots==5,'migration is idempotent')
assert(addon.db:WheelRemove(5))
addon.db:Initialize('Migration-Test')
assert(#settings.wheelSlots==4,'intentional later removal persists')
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
settings=saved({{type='category',category='Bank'},
  {type='category',category='Custom'},
  {type='folder',name='My actions',entries={{type='spell',id=77}}}})
assert(settings.wheelServicesMigrationStatus=='superseded' and
  settings.wheelCustomAccess=='superseded' and
  settings.wheelSlots[1].category=='Services' and
  settings.wheelSlots[2].name=='My actions' and
  settings.wheelSlots[2].entries[1].id==77,
  'new hierarchy supersedes the old stock migration without losing edited folders')
settings.wheelServicesMigrationStatus='migrated'
addon.db:Initialize('Migration-Test')
assert(settings.wheelServicesMigrationStatus=='migrated' and
  settings.wheelSlots[2].name=='My actions',
  'existing migration status and edited slots remain stable on reload')
print('one-time quest root migration tests passed')
