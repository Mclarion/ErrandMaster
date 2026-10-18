local addon={}
assert(loadfile('Core/Database.lua'))('ErrandMaster',addon)
assert(loadfile('Core/Errands.lua'))('ErrandMaster',addon)
ErrandMasterDB=nil
addon.db:Initialize('Test-Realm')
local a=addon.errands:Add({name='First',mapID=10,x=.1,y=.1})
local b=addon.errands:Add({name='Second',mapID=20,x=.2,y=.2})
local c=addon.errands:Add({name='Unlocated'})
local bucket=addon.db.data.characters[addon.db.character]
bucket.activeErrandId=a.id
local d=addon.errands:Add({name='New first',mapID=10,x=.11,y=.11})
assert(bucket.activeErrandId==nil,'adding a stop invalidates a stale explicit selection')
bucket.activeErrandId=b.id
addon.errands:Reorder(c.id,1)
assert(bucket.activeErrandId==nil and addon.errands:All()[1].id==c.id,
  'manual reorder updates first visible entry and resets stale selection')
assert(a and d)
print('errands queue selection regression passed')
