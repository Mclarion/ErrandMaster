-- A full ring keeps Travel inside a real wedge and readable whole labels.
local f=dofile('tests/wheel_fixture.lua')()
local addon,w=f.addon,f.wheel
local settings=addon.db.data.settings
settings.wheelSlots={}
for i=1,24 do settings.wheelSlots[i]={type='category',category='Repair'} end
settings.wheelSlots[7]={type='category',category='Travel'}
local slots=settings.wheelSlots
f:root()
assert(not w.travelShortcut and w.slots[7].texture.texture:find('PackTravel.blp',1,true))
f:click(7)
assert(w.submenu=='Travel' and w.menuEntries[1].category=='Flight Master' and
  w.menuEntries[2].category=='Portal' and w.menuEntries[3].category=='Boat')
assert(w.historyViews[1].labels[1].shown,'retained ring stays labeled')
assert(settings.wheelSlots==slots and #slots==24)
for i=1,w.count do assert(w.slots[i].label.shown,'submenu text visible') end
w:GoBack()
for i=1,w.count do assert(w.slots[i].label.shown,'root text visible') end
settings.wheelSlots={{type='category',category='Vendor'}}
w:Layout(); w:Enter('Profession Vendor',1)
addon.db.GetWheelProfessions=function() return {'Herbalism'} end
w:Layout()
assert(w.slots[1].label.text=='Herbalism' and w.slots[1].label.shown)
assert(w.slots[1].texture.texture:find('PackHerbalismVendor.blp',1,true))
w:GoBack(); w:GoBack()
settings.wheelSlots={{type='category',category='Food Vendor'},
  {type='category',category='Reagent Vendor'},
  {type='category',category='Ammo Vendor'},
  {type='category',category='Blacksmithing Vendor'}}
w:Layout()
for i,name in ipairs({'Food','Reagents','Ammo','BlacksmithingVendor'}) do
  assert(w.slots[i].texture.texture:find('Pack'..name..'.blp',1,true))
end
settings.wheelSlots={{type='category',category='Élémentaire Longue'}}
w:Layout()
local first=w.slots[1]
assert(first.label.shown and first.label.text:sub(1,2)=='É')
settings.wheelSlots={{type='category',category='Été'}}
w:Layout()
assert(first.label.text=='Été','UTF-8 short label survives pooled reuse')
settings.wheelSlots={}
for i=1,24 do settings.wheelSlots[i]={type='category',category='Blacksmithing Vendor'} end
w:Layout()
local boxes={}
for i=1,24 do
 local label=w.slots[i].label
 assert(label.shown and label.text:find('…',1,true) and label.w<=33,
  'dense label remains within allotted width')
 local x,y=label.point[4],label.point[5]
 boxes[i]={x-label.w/2,x+label.w/2,y-label.h/2,y+label.h/2}
end
for i=1,24 do
 local a,b=boxes[i],boxes[i%24+1]
 assert(math.min(a[2],b[2])<=math.max(a[1],b[1]) or
   math.min(a[4],b[4])<=math.max(a[3],b[3]),
   'adjacent whole labels overlap')
end
print('wheel transport and whole label tests passed')
