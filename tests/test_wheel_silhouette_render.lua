-- Actual wheel regions must render shape-matched additive light beneath original art.
local f=dofile('tests/wheel_fixture.lua')()
local w,s=f.wheel,f.addon.db.data.settings
local prefix='Interface\\AddOns\\ErrandMaster\\Textures\\'
local function check(slot,source,selected)
  local light=slot.iconGlow
  assert(slot.texture.texture==source,'original icon art preserved')
  assert(light.texture==prefix..'Glow'..source:match('([^\\]+)$'),
    'rendered underlay must use exact silhouette of source icon')
  assert(light.layer=='BORDER' and light.blend=='ADD' and slot.texture.layer=='ARTWORK')
  assert(light.w==slot.texture.w and light.h==slot.texture.h,
    'shape must share exact original canvas bounds')
  assert(light.point[4]==slot.texture.point[4] and light.point[5]==slot.texture.point[5],
    'shape and source must share a center')
  assert(light.alpha >= (selected and .55 or .2),'light remains visible')
  assert(light.shown and slot.texture.shown)
  assert(slot.texture.color[1]==1 and slot.texture.color[2]==1 and slot.texture.color[3]==1)
end
f:root()
check(w.slots[1],prefix..'PackBank.blp')
-- Build a retained ring with the root vendor slot selected.
f:click(3)
check({iconGlow=w.historyViews[1].iconGlows[3],texture=w.historyViews[1].icons[3]},
  prefix..'PackProfessionVendor.blp',true)
-- Re-use the active region for a different icon while keeping root retained.
check(w.slots[1],prefix..'PackFood.blp')
w:GoBack()
-- A native texture ID cannot be mapped to an unbundled Glow<ID> path.
s.wheelSlots[1]={type='category',category='Repair',icon=135841}
w:Layout()
local native=w.slots[1]
assert(native.texture.texture==135841)
assert(native.iconGlow.texture==prefix..'MedallionBlueActive.blp' or
  native.iconGlow.texture:match('Medallion.*Active%.blp$'),
  'unsupported icon must use known fallback, never an invented Glow path')
assert(native.iconGlow.w==w.tiers[1].glowSize)
s.wheelSlots[1]={type='category',category='Active Quests'}
s.wheelSlots[2]={type='category',category='Skills'}
s.wheelSlots[3]={type='folder',name='Custom'}
w:Layout()
check(w.slots[1],prefix..'PackQuestionQuestmark.blp')
check(w.slots[2],prefix..'ServiceSkills.blp')
assert(w.slots[3].texture.texture=='Interface\\Icons\\INV_Misc_Bag_08')
assert(w.slots[3].iconGlow.texture:match('Medallion.*Active%.blp$'),
  'native texture path must use a known fallback')
-- Pooled active and retained regions must disappear when counts/depth shrink.
s.wheelSlots={{type='category',category='Repair'}}
w:Layout()
assert(not w.slots[2].iconGlow.shown)
w:Enter('Vendor',1)
assert(w.historyViews[1].iconGlows[2] and not w.historyViews[1].iconGlows[2].shown)
w:GoBack()
assert(not w.historyViews[1].iconGlows[1].shown)
print('wheel silhouette glow active/retained/native/pool contract passed')
