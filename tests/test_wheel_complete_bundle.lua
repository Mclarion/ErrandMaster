-- 2026-10-21 wheel acceptance: migrate old layouts, hierarchy, and icon/label/shadow placement.
local f=dofile('tests/wheel_fixture.lua')()
local db,w=f.addon.db,f.wheel
local old={}
for _,category in ipairs({'Travel','Quests','Repair','Bank','Auction House','Mailbox','Vendor','Trainer','Custom','Settings'}) do
  old[#old+1]={type='category',category=category}
end
old[#old+1]={type='folder',name='My shortcuts',entries={{type='item',id=123}}}
ErrandMasterDB.settings.wheelSlots=old
ErrandMasterDB.settings.wheelHierarchy20261021=nil
-- Reload must migrate already-versioned, player-edited layouts too.
db:Initialize('Wheel-Fixture')
local names={}
for _,entry in ipairs(db.data.settings.wheelSlots) do
  if entry.type=='category' then names[entry.category]=(names[entry.category] or 0)+1 end
end
assert(names.Travel==1 and names.Services==1 and names.Trainer==1 and names.Quests==1,
  'Travel, Services, Trainer and Quests must be real top-level wedges')
assert(not names.Custom and not names.Bank and not names.Mailbox and not names['Auction House'],
  'retired stock entries must not remain on root even on edited saves')
assert(db.data.settings.wheelSlots[#db.data.settings.wheelSlots].name=='My shortcuts',
  'player folders must survive migration')
local once=#db.data.settings.wheelSlots
db:Initialize('Wheel-Fixture')
assert(#db.data.settings.wheelSlots==once,'wheel migration must be idempotent')
f:root()
local function open(name)
  while #w.history>0 do w:GoBack() end
  for i=1,w.count do
    if db.data.settings.wheelSlots[i].category==name then f:click(i);return end
  end
  error('missing root '..name)
end
open('Services')
assert(w.menuEntries[1].category=='Bank' and w.menuEntries[2].category=='Auction House' and
  w.menuEntries[3].category=='Mailbox' and w.menuEntries[4].category=='Profession',
  'Services must contain banking, auction, mail and Profession')
f:click(4)
assert(w.submenu=='Profession' and #w.menuEntries>10,
  'Profession should offer primary and secondary specializations while slots are open')
local found={}
for _,item in ipairs(w.menuEntries) do found[item.category]=true end
assert(found['Alchemy Trainer'] and found['Engineering Trainer'] and found['Fishing Trainer'],
  'all profession specialties must be visible before both primary slots are occupied')
GetProfessions=function() return 12,nil end
GetProfessionInfo=function(index) return index==12 and 'Alchemy' or 'Mining' end
assert(#db:GetWheelTrainerProfessions()==12,
  'one learned primary leaves every trainer specialty available')
GetProfessions=function() return 12,34 end
w:Layout()
found={}
for _,item in ipairs(w.menuEntries) do found[item.category]=true end
assert(w.count==6 and found['Alchemy Trainer'] and found['Mining Trainer'] and
  found['Cooking Trainer'] and found['Fishing Trainer'] and found['First Aid Trainer'] and
  not found['Engineering Trainer'],
  'two learned primary slots restrict primary trainers but retain secondary specialties')
GetProfessions=nil;GetProfessionInfo=nil
open('Trainer')
found={}
for _,item in ipairs(w.menuEntries) do found[item.category]=true end
assert(found['Class Trainer'] and found['Weapon Trainer'] and found['Pet Trainer'],
  'Trainer is a separate top-level group with class, pet and weapon trainers')
local travelIndex
for i,item in ipairs(db.data.settings.wheelSlots) do if item.category=='Travel' then travelIndex=i end end
assert(travelIndex and not w.travelShortcut,
  'Travel must be inside the wheel with no outside shortcut')
local tier=w.tiers[#w.tiers]
for i=1,w.count do
  local slot=w.slots[i]
  local icon,label=slot.texture.point,slot.label.point
  assert(math.abs(label[4]-icon[4])<.01 and label[5]<icon[5]-tier.iconSize*.55,
    'every label should be directly below its icon')
  assert(slot.iconShadow.shown and slot.iconShadow.w>slot.texture.w*1.15 and
    slot.iconShadow.alpha>=.8,'icon silhouette shadow must be prominent')
  if i==1 then
    assert(slot.rimShadow.shown and slot.rimBase.shown and
      slot.rimBase.w>slot.sector.w*1.06 and slot.rimShadow.layer=='BACKGROUND',
      'one continuous mask surrounds the active tier')
  else assert(not slot.rimShadow.shown and not slot.rimBase.shown,
    'no per-wedge shadow seams or overlapping dark blobs') end
end
w:SetSelection(1)
local hover=w.slots[1].rimShadow.color
assert(hover[1]>.07 and hover[2]>.07,'hover must tint wheel perimeter')
assert(w.historyViews[1].rimShadows[1].color[1]==hover[1],
  'expanded parent rim must use hovered element color too')
w:SetSelection(nil)
assert(w.slots[1].rimShadow.color[1]<hover[1],
  'wheel shadow must return to neutral when hover ends')
print('2026-10-21 complete wheel hierarchy and placement acceptance passed')
