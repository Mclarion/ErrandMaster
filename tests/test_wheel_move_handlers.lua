local f=dofile('tests/wheel_fixture.lua')()
local w,db=f.wheel,f.addon.db
local slots=db.data.settings.wheelSlots
f:root();assert(w:SetEditing(true))
local mail,auction=slots[5],slots[2]
f:hit(5);w.frame.scripts.OnDragStart(w.frame)
f:hit(2);w.frame.scripts.OnUpdate(w.frame,.03)
f:time(.6);w.frame.scripts.OnUpdate(w.frame,.03)
w.frame.scripts.OnDragStop(w.frame)
local group=slots[2]
assert(group.type=='folder' and group.entries[1]==mail and group.entries[2]==auction)
f:click(2)
assert(w.submenu=='folder' and w.folderRef==group and w.count==3)
-- Drag child out to retained root ring without duplicate or collapse.
f:hit(1);w.frame.scripts.OnDragStart(w.frame)
f:hit(3,1,.95);w.frame.scripts.OnUpdate(w.frame,.03)
w.frame.scripts.OnDragStop(w.frame)
assert(slots[3]==mail and group.entries[1]==auction and w.folderRef==group)
-- Enter a second folder, move across two containers via retained tier.
w:GoBack()
local repair,vendor=slots[4],slots[5]
assert(db:WheelTransfer(db:WheelFindPath(repair),db:WheelFindPath(vendor),'group','Services'))
w:Layout()
local second=db:WheelFindPath(vendor)[1] and slots[db:WheelFindPath(vendor)[1]]
f:click(db:WheelFindPath(second)[1])
assert(w.folderRef==second)
f:hit(3,1);w.frame.scripts.OnDragStart(w.frame)
f:hit(2,1);w.frame.scripts.OnUpdate(w.frame,.03)
f:time(1.2);w.frame.scripts.OnUpdate(w.frame,.03)
w.frame.scripts.OnDragStop(w.frame)
assert(group.entries[#group.entries]==mail and second.entries[1]==repair,
  'moving retained root Mail into first folder preserves its identity')
w:GoBack()
local mailPath=db:WheelFindPath(mail)
assert(mailPath and #mailPath==2)
f:click(mailPath[1])
assert(w.folderRef==group)
f:hit(mailPath[2]);w.frame.scripts.OnDragStart(w.frame)
f:hit(db:WheelFindPath(second)[1],1);w.frame.scripts.OnUpdate(w.frame,.03)
f:time(1.8);w.frame.scripts.OnUpdate(w.frame,.03)
w.frame.scripts.OnDragStop(w.frame)
assert(second.entries[#second.entries]==mail and #group.entries==1)
-- Cancel has no persistent side effects, and root navigation remains intact.
f:hit(1);w.frame.scripts.OnDragStart(w.frame)
f:hit(1,1);w.frame.scripts.OnUpdate(w.frame,.03)
w:CancelWheelDrag()
assert(second.entries[#second.entries]==mail and not w.dragIndex)
w:GoBack();assert(w.submenu==nil and w.count==#slots)
-- Proposed native growth appears before release, leaves saved layout untouched,
-- and restores exactly on cursor cancellation.
local count=#slots
f:payload('item',555)
f:hit(1,1,.95);w.frame.scripts.OnUpdate(w.frame,.03)
assert(w.previewInsert==1 and w.count==count+1 and w.model.tiers[1].count==count+1)
assert(#slots==count and w.slots[2].previewX,'neighbors animate without saved mutation')
f:payload(nil,nil);w.frame.scripts.OnUpdate(w.frame,.03)
assert(w.count==count and not w.previewInsert and not w.nativeBaseModel and #slots==count)
print('handler grouping, cross-tier moves, cancellation and native growth passed')
