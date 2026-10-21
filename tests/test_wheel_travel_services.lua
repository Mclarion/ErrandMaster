-- Travel choices queue service intent but never claim an unverified endpoint.
local f=dofile('tests/wheel_fixture.lua')()
local addon,w=f.addon,f.wheel
f:legacyLayout()
assert(loadfile('Core/Errands.lua'))('ErrandMaster',addon)
assert(loadfile('UI/TravelPoints.lua'))('ErrandMaster',addon)
local originalSlots=addon.db.data.settings.wheelSlots
f:root();f:click(7)
assert(w.submenu=='Travel' and w.menuEntries[1].category=='Flight Master' and
  w.menuEntries[2].category=='Portal' and w.menuEntries[3].category=='Boat')
f:click(2)
local items=addon.errands:All()
assert(#items==1 and items[1].category=='Portal' and items[1].origin=='suggested' and
  items[1].name=='Portal service request' and
  not items[1].mapID and not items[1].x and not items[1].y,
  'portal queues a service request, never a fabricated portal destination')
assert(f.notices[#f.notices]:find('unverified',1,true))
f:root();f:click(7);f:click(3)
items=addon.errands:All()
assert(#items==2 and items[2].category=='Boat' and not items[2].mapID,
  'boat queues an unresolved service request')
f:root();f:click(7);f:click(1)
items=addon.errands:All()
assert(#items==3 and items[3].category=='Flight Master' and not items[3].mapID,
  'flight master uses the existing NPC service category')
f:root();f:click(7);f:click(2)
assert(#addon.errands:All()==3 and f.notices[#f.notices]:find('Already queued',1,true),
  'repeat travel request does not duplicate pending category')
assert(addon.db.data.settings.wheelSlots==originalSlots,
  'travel navigation does not alter the saved wheel layout')
print('travel service wheel click tests passed')
