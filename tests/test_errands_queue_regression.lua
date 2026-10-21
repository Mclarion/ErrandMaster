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
assert(type(addon.errands.revision)=='number' and addon.errands.revision==5,
 'Add and Reorder advance the transient revision once each')
local revision=addon.errands.revision
addon.errands:All(); addon.errands:Get(a.id)
assert(addon.errands.revision==revision,'reads never invalidate cached plans')
b.manualPosition=3 -- Existing independent anchor must survive Reset order.
addon.errands:ClearOrder(c.id)
assert(c.manualPosition==nil and b.manualPosition==3 and addon.errands.revision==revision+1,
 'Reset order clears only this anchor and invalidates the cache')
b.manualPosition=nil
revision=addon.errands.revision
addon.errands:ClearOrder(c.id)
assert(addon.errands.revision==revision,'Reset order without an anchor is a no-op')
assert(not pcall(function() addon.errands:Reorder(a.id,0) end) and
 addon.errands.revision==revision,'failed mutations do not advance revision')
addon.errands:Update(a.id,{name='Changed'})
assert(addon.errands.revision==revision+1)
revision=addon.errands.revision
addon.errands:Complete(a.id,true)
assert(addon.errands.revision==revision+1)
revision=addon.errands.revision
addon.errands:Delete(d.id)
assert(addon.errands.revision==revision+1)
revision=addon.errands.revision
addon.errands:Add({name='Another'})
assert(addon.errands.revision==revision+1)
print('errands queue selection regression passed')
