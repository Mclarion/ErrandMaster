local f=dofile('tests/wheel_fixture.lua')()
local w,db=f.wheel,f.addon.db
local slots=db.data.settings.wheelSlots
local function index(category)
  for i,v in ipairs(slots) do if v.category==category then return i end end
end
local mail=slots[index('Mailbox')]
local auction=slots[index('Auction House')]
assert(db:WheelTransfer({index('Mailbox')},{index('Auction House')},'group','Mail + Auction'))
local folder=slots[2]
assert(folder.type=='folder' and folder.entries[1]==mail and folder.entries[2]==auction)
local path=db:WheelFindPath(mail)
assert(path and #path==2 and db:WheelTransfer(path,{#slots+1},'insert'))
assert(slots[#slots]==mail and folder.entries[1]==auction)
-- Re-group into two folders, then move between them and back out.
assert(db:WheelTransfer(db:WheelFindPath(mail),db:WheelFindPath(folder),'group'))
local repair=slots[index('Repair')]
local vendor=slots[index('Vendor')]
assert(db:WheelTransfer(db:WheelFindPath(repair),db:WheelFindPath(vendor),'group','Repairs'))
local other=slots[index('Vendor') or 3]
assert(other.type=='folder' and other.entries[1]==repair)
assert(db:WheelTransfer(db:WheelFindPath(mail),db:WheelFindPath(other),'group'))
assert(other.entries[#other.entries]==mail and folder.entries[1]==auction)
assert(db:WheelTransfer(db:WheelFindPath(mail),{#slots+1},'insert') and slots[#slots]==mail)
local before=#slots
assert(not db:WheelTransfer(db:WheelFindPath(other),db:WheelFindPath(other),'group'))
assert(not db:WheelTransfer({999},{1},'insert'))
assert(not db:WheelTransfer(db:WheelFindPath(other),{1,99},'group'))
assert(#slots==before and other.entries[#other.entries]==vendor)
-- A nested folder uses the third visual tier; a third folder level is forbidden.
assert(db:WheelTransfer(db:WheelFindPath(mail),db:WheelFindPath(repair),'group','Nested'))
local nested=other.entries[1]
assert(nested.type=='folder' and nested.entries[1]==mail and nested.entries[2]==repair)
local isolated=slots[index('Bank')]
assert(not db:WheelTransfer(db:WheelFindPath(isolated),db:WheelFindPath(mail),'group','Too deep'))
assert(not db:WheelTransfer(db:WheelFindPath(other),db:WheelFindPath(nested),'group'))
assert(slots[index('Bank')]==isolated and other.entries[1]==nested)
-- Capacity and failed transfers leave the exact original references intact.
while #other.entries<8 do
  local source
  for _,entry in ipairs(slots) do if entry.type~='folder' and entry~=isolated then source=entry;break end end
  if not source then
    assert(db:WheelInsert({type='item',id=7000+#slots}))
    source=slots[#slots]
  end
  assert(db:WheelTransfer(db:WheelFindPath(source),db:WheelFindPath(other),'group'))
end
local extra=slots[1]
assert(not db:WheelTransfer(db:WheelFindPath(extra),db:WheelFindPath(other),'group'))
assert(slots[1]==extra and #other.entries==8)
print('wheel transfer identity, tiers, rejection and capacity passed')
