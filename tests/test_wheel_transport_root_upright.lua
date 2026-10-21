-- New root, in-wheel Travel, legacy migration and upright below-icon labels.
local f=dofile('tests/wheel_fixture.lua')()
local w,db=f.wheel,f.addon.db
assert(loadfile('Core/Errands.lua'))('ErrandMaster',f.addon)
assert(loadfile('UI/TravelPoints.lua'))('ErrandMaster',f.addon)
local settings=db.data.settings
assert(#settings.wheelSlots==8 and settings.wheelSlots[1].category=='Services' and
  settings.wheelSlots[4].category=='Trainer' and settings.wheelSlots[5].category=='Travel' and
  not w.travelShortcut,'fresh root has grouped Services and real Travel/Trainer wedges')
f:root();f:click(1)
assert(w.submenu=='Services' and w.menuEntries[1].category=='Bank' and
  w.menuEntries[2].category=='Auction House' and w.menuEntries[3].category=='Mailbox' and
  w.menuEntries[4].category=='Profession')
f:click(2)
assert(f.addon.errands:All()[1].category=='Auction House')
f:root();f:click(5)
assert(w.submenu=='Travel' and w.menuEntries[1].category=='Flight Master' and
  w.menuEntries[2].category=='Portal' and w.menuEntries[3].category=='Boat')
f:click(3)
assert(f.addon.errands:All()[2].category=='Boat' and
  not f.addon.errands:All()[2].mapID,'Boat remains unresolved without evidence')
local stock={}
for i,name in ipairs({'Bank','Auction House','Repair','Vendor','Mailbox',
    'Trainer','Travel','Custom','Quests','Skills','Items'}) do
  stock[i]={type='category',category=name}
end
ErrandMasterDB={schema=5,nextId=1,nextLocationId=1,account={},characters={},locations={},
  settings={wheelSlots=stock,wheelSkills={{type='spell',id=777}},
    wheelItems={{type='item',id=888}},wheelQuestMigrationStatus='present'}}
db:Initialize('Wheel-Fixture')
local names={}
for _,entry in ipairs(db.data.settings.wheelSlots) do
  if entry.category then names[entry.category]=(names[entry.category] or 0)+1 end
end
assert(#db.data.settings.wheelSlots==8 and names.Services==1 and names.Travel==1 and
  names.Trainer==1 and not names.Custom and not names.Bank and not names.Mailbox and
  not names['Auction House'],'legacy stock menu migrates to grouped root')
assert(db.data.settings.wheelSkills[1].id==777 and db.data.settings.wheelItems[1].id==888)
db:Initialize('Wheel-Fixture')
assert(#db.data.settings.wheelSlots==8,'hierarchy migration runs once')
local full={}
for i=1,24 do full[i]={type='item',id=i} end
full[1]={type='category',category='Bank'}
full[2]={type='category',category='Auction House'}
full[3]={type='category',category='Mailbox'}
full[8]={type='category',category='Custom'}
full[9]={type='folder',name='My actions',entries={{type='spell',id=123}}}
ErrandMasterDB={schema=5,nextId=1,nextLocationId=1,account={},characters={},locations={},
  settings={wheelSlots=full,wheelQuestMigrationStatus='full'}}
db:Initialize('Wheel-Fixture')
local hasFolder,hasCustom=false,false
for _,entry in ipairs(db.data.settings.wheelSlots) do
  if entry.name=='My actions' and entry.entries[1].id==123 then hasFolder=true end
  if entry.category=='Custom' then hasCustom=true end
end
assert(hasFolder and not hasCustom and #db.data.settings.wheelSlots<=24,
  'full edited wheel keeps player folder but retires Custom')
local count=#db.data.settings.wheelSlots
w:Close();f:root()
for i=1,w.count do
  local icon,label=w.slots[i].texture.point,w.slots[i].label.point
  assert(w.slots[i].label.shown and math.abs(icon[4]-label[4])<.01 and
    label[5]<icon[5],'every label stays upright beneath its icon')
end
assert(#db.data.settings.wheelSlots==count,'rendering does not change saved slots')
print('root Services, Travel, Trainer, edited-save migration and below-icon labels passed')
