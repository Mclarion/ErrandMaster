local f=dofile('tests/wheel_fixture.lua')()
local w,db=f.wheel,f.addon.db
f:legacyLayout()
local s=db.data.settings
f:root()
assert(w.slots[6].texture.texture:find('PackClassTrainer.blp',1,true),'H01 root Trainer illustration')
f:click(6)
assert(w.menuEntries[1].category=='Class Trainer' and w.menuEntries[4].category=='Weapon Trainer' and
  w.menuEntries[2].category=='Pet Trainer')
w:Close()
UnitClass=function() return 'Hunter','HUNTER' end
f:root();f:click(6)
local pet=false
for _,v in ipairs(w.menuEntries) do if v.category=='Pet Trainer' then pet=true end end
assert(pet,'H02 hunter-specific trainer')
w:Close()
s.wheelPinned=true;s.wheelUnlocked=false
assert(w:SetEditing(true) and s.wheelUnlocked and s.wheelPinned==nil,'E01 edit replaces pin state')
assert(w:Open())
assert(w.centerLabel.text=='EDIT MODE' and w.centerLabel.shown,'E02 persistent hub indication')
assert(not w.pinButton,'E01 no pin control')
s.wheelSlots[8]={type='category',category='Settings'}
w:Layout();f:click(8)
assert(w.submenu=='Settings' and #w.menuEntries==3,'E01 no Pin Wheel menu entry')
w:Close()
-- A preexisting category becomes a black folder while retaining both identities.
local source=s.wheelSlots[5];local destination=s.wheelSlots[2]
assert(db:WheelFolder(5,2,'Auction and Mail'))
local folder=s.wheelSlots[2]
assert(folder.type=='folder' and folder.entries[1]==source and folder.entries[2]==destination,
 'E05/E06 grouping retains the actual entries with a black folder')
w:Close();f:root()
assert(w.slots[2].sector.color[1]<.1,'E05 folder surface is near-black')
-- Grouping an existing folder into another must fail atomically, not delete contents.
local snapshot=#s.wheelSlots
assert(not db:WheelFolder(2,3,'Nested') and #s.wheelSlots==snapshot and s.wheelSlots[2]==folder)
print('wheel acceptance: trainer, edit, black grouping and identity passed')
