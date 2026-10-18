local f=dofile('tests/wheel_fixture.lua')()
local w,db=f.wheel,f.addon.db
local settings=db.data.settings
f:root()
assert(w:SetEditing(true) and settings.wheelUnlocked and settings.wheelPinned==nil)
assert(not w.outside.shown,'outside must not block external bag/spellbook dragging')
assert(w.centerClose.shown and w.addButton.shown)
local n=#settings.wheelSlots
f:payload('spell',31415)
f:hit(2,1,.95) -- Ring insertion space, not the occupied icon center.
w.frame.scripts.OnUpdate(w.frame,.03)
assert(w.dragGhost.shown and w.slots[2].previewX,'native cursor should preview between-slot insertion')
w.frame.scripts.OnReceiveDrag(w.frame)
assert(#settings.wheelSlots==n+1 and settings.wheelSlots[2].id==31415)
assert(settings.wheelSlots[2].type=='spell')
f:payload(nil,nil)
-- A long hover in the same wedge but outside its icon must still insert.
local beforeOuter=#settings.wheelSlots
f:payload('spell',31416)
f:hit(4,1,.95)
w.frame.scripts.OnUpdate(w.frame,.03)
f:time(1)
w.frame.scripts.OnUpdate(w.frame,.03)
w.frame.scripts.OnReceiveDrag(w.frame)
assert(#settings.wheelSlots==beforeOuter+1 and settings.wheelSlots[4].id==31416,
  'outer 95% wedge drop must insert, not group')
f:hit(4,1,.95)
assert(w:DropEntry({type='spell',id=31418},4,1))
assert(settings.wheelSlots[4].id==31418,
  'DropEntry itself must not trust a wedge-wide elapsed hover for grouping')
f:payload(nil,nil)
-- Old hover history cannot turn a non-icon ring drop into grouping.
f:hit(4)
w.frame.scripts.OnUpdate(w.frame,.03)
f:time(2)
f:hit(4,1,.95)
w.frame.scripts.OnUpdate(w.frame,.03)
f:hit(4,1,.95)
w.frame.scripts.OnUpdate(w.frame,.03)
f:payload('spell',31417)
w.frame.scripts.OnReceiveDrag(w.frame)
assert(settings.wheelSlots[4].id==31417,'non-icon drop inserts regardless of old dwell history')
f:payload(nil,nil)
assert(db:WheelRemove(4) and db:WheelRemove(4) and db:WheelRemove(4))
w:Layout(); w:RefreshAppearance()
f:time(0)
f:hit(3)
w.frame.scripts.OnDragStart(w.frame)
assert(w.dragIndex==3 and w.dragGhost.shown)
f:hit(5)
w.frame.scripts.OnUpdate(w.frame,.03)
assert(w.dragTarget==5 and w.dragMode=='insert' and w.dragGhost.point[4]~=nil)
assert(w.slots[4].previewX and w.slots[4].previewX~=w.centerX,
  'other icons interpolate toward live insertion targets')
local old=settings.wheelSlots[3]
w.frame.scripts.OnDragStop(w.frame)
assert(settings.wheelSlots[5]==old and not w.dragGhost.shown and not w.dragIndex)
-- Long hover directly over another icon creates a folder rather than insertion.
f:hit(3)
w.frame.scripts.OnDragStart(w.frame)
local source=settings.wheelSlots[3]
f:hit(4)
w.frame.scripts.OnUpdate(w.frame,.03)
f:time(.6)
w.frame.scripts.OnUpdate(w.frame,.03)
assert(w.dragMode=='folder' and w.slots[4].glowTarget==1)
w.frame.scripts.OnDragStop(w.frame)
assert(#settings.wheelSlots==n and settings.wheelSlots[3].type=='folder')
assert(settings.wheelSlots[3].entries[1]==source and
  #settings.wheelSlots[3].entries==2,'moving into folder preserves both entries')
local folder=settings.wheelSlots[3]
f:click(3)
assert(w.submenu=='folder' and w.count==3)
f:payload('item',777)
f:hit(1)
w.frame.scripts.OnReceiveDrag(w.frame)
assert(folder.entries[1].id==777 and folder.entries[1].type=='item')
f:payload(nil,nil)
assert(w.count==4)
f:hit(1)
w.frame.scripts.OnDragStart(w.frame)
f:hit(3)
w.frame.scripts.OnUpdate(w.frame,.03)
w.frame.scripts.OnDragStop(w.frame)
assert(folder.entries[3].id==777 and #folder.entries==3,
  'nested folder move reorders without duplication')
f:click(w.count)
assert(w.submenu==nil and w.count==n)
-- User can create and populate a truly empty folder from the visible + menu.
w.addButton.scripts.OnClick(w.addButton)
assert(w.addMenu.shown)
f:button('+ Folder').scripts.OnClick(f:button('+ Folder'))
local empty=settings.wheelSlots[#settings.wheelSlots]
assert(empty.type=='folder' and #empty.entries==0)
f:click(w.count)
assert(w.submenu=='folder' and w.count==1,'empty folder remains navigable with Back')
f:payload('spell',91919)
f:hit(1,nil,.08) -- Drop into the empty folder's ring, not its former parent position.
w.frame.scripts.OnReceiveDrag(w.frame)
assert(empty.entries[1].id==91919 and w.count==2)
f:payload(nil,nil)
f:click(2)
-- External item location is resolved, never used or consumed.
local prior=#settings.wheelSlots
f:payload('item',4444)
f:hit(1,nil,.95)
w.frame.scripts.OnReceiveDrag(w.frame)
assert(#settings.wheelSlots==prior+1 and settings.wheelSlots[1].id==4444)
f:payload(nil,nil)
local count=#settings.wheelSlots
GetCursorInfo=function() return 'spell',123 end
assert(not w:DropNative(1) and #settings.wheelSlots==count)
GetCursorInfo=function() error('protected cursor') end
assert(not w:DropNative(1) and #settings.wheelSlots==count)
-- Drag cancellation, combat and close clear all transients; no mutation.
f:hit(2); w.frame.scripts.OnDragStart(w.frame)
assert(w.dragIndex and w.dragGhost.shown)
w:Close()
assert(not w.dragIndex and not w.dragGhost.shown and not w.hoverStart)
assert(#settings.wheelSlots==count)
InCombatLockdown=function() return true end
assert(not w:DropNative(1) and not w:SetEditing(false))
InCombatLockdown=function() return false end
assert(w:SetEditing(true),'explicit close exited editing; re-enable it for the drag test')
f:cursor(w.centerX,w.centerY)
w.centerClose.scripts.OnDragStart(w.centerClose)
local oldX,oldY=w.centerX,w.centerY
f:cursor(oldX+95,oldY+35)
w.frame.scripts.OnUpdate(w.frame,.03)
w.centerClose.scripts.OnDragStop(w.centerClose)
assert(settings.wheelCenter and settings.wheelCenter.x>0 and
  math.abs(settings.wheelCenter.x*UIParent.w-w.centerX)<1)
w.centerClose.scripts.OnClick(w.centerClose)
assert(w.frame.shown,'drag release does not close')
w.centerClose.scripts.OnMouseDown(w.centerClose)
w.centerClose.scripts.OnClick(w.centerClose)
assert(not w.frame.shown,'next intentional center click closes')
-- UIParent units change on scale/resolution events, not saved normalized data.
f:root()
local savedX,savedY=settings.wheelCenter.x,settings.wheelCenter.y
UIParent.w,UIParent.h=960,540
w.frame.scripts.OnEvent(w.frame,'UI_SCALE_CHANGED')
assert(w.centerX>=w.model.extent and w.centerX<=UIParent.w-w.model.extent)
assert(w.centerY>=w.model.extent and w.centerY<=UIParent.h-w.model.extent)
assert(settings.wheelCenter.x==savedX and settings.wheelCenter.y==savedY)
f:click(4)
local nestedCenterX,nestedCenterY=w.centerX,w.centerY
UIParent.w,UIParent.h=1200,675
w.frame.scripts.OnEvent(w.frame,'DISPLAY_SIZE_CHANGED')
assert(math.abs(w.centerX-nestedCenterX*1200/960)<1 and
  math.abs(w.centerY-nestedCenterY*675/540)<1)
assert(settings.wheelCenter.x==savedX and settings.wheelCenter.y==savedY,
  'deep viewport resize never overwrites root center')
w:Close()
print('wheel native drop, live insert, folder hover, nested edits and cleanup passed')
