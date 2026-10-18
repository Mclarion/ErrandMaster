local f=dofile('tests/wheel_fixture.lua')()
local w=f.wheel
f:root()
assert(w.centerShadow and w.centerShadow.layer=='BACKGROUND' and w.centerShadow.shown,
 'W02 hub has shadow continuous with ring silhouette')
assert(w.centerArt.w < w.tiers[1].innerRadius*2,'W01 transparent source fringe must not spill over aperture')
local slot=w.slots[1]
assert(slot.iconGlow and slot.iconGlow.layer=='BORDER' and slot.texture.layer=='ARTWORK',
  'W04 backlight below untinted icon')
assert(slot.medallionGlow and slot.medallionGlow.layer=='BORDER' and
  slot.texture.layer=='ARTWORK' and slot.medallion.layer=='OVERLAY',
  'W04/W05 jewel backlight below icons as well as supplied jewel art')
assert(slot.texture.color[1]==1 and slot.texture.color[2]==1 and slot.texture.color[3]==1)
assert(slot.shadow.color and slot.shadow.color[1]==0,'W03 default black shadow')
f:hit(1); w:SetSelection(1)
w.frame.scripts.OnUpdate(w.frame,.016)
assert(slot.shadow.color[1]>0 and slot.shadow.color[1]<slot.sector.color[1],
 'W03 shadow eases toward branch color')
assert(slot.medallionGlow.alpha>0,'W05 active jewel stronger')
local shade=slot.shadow.color[1]
w:Layout()
assert(math.abs(slot.shadow.color[1]-shade)<.000001,'W03 relayout preserves current shadow tint')
f:click(4)
w.frame.scripts.OnUpdate(w.frame,.016)
local retained=w.historyViews[1]
assert(retained.iconGlows[1].shown and retained.medallionGlows[1].shown,'W04/W05 retained ring backlights')
assert(retained.shadows[4].color[2]>0,'W03 expanded branch colored shadow')
local retainedShade=retained.shadows[4].color[2]
w:RenderHistory()
assert(math.abs(retained.shadows[4].color[2]-retainedShade)<.000001,
  'W03 history rebuild preserves current selected branch tint')
assert(retained.medallionGlows[1].layer=='BORDER' and retained.icons[1].layer=='ARTWORK',
  'retained jewel backlights also remain behind icon artwork')
local back=w.slots[w.count]
assert(back.texture.desaturated == false, 'White-category supplied icons retain their original colors')
assert(back.sector.color[1]>back.sector.color[3] and back.sector.color[3]>.5,
 'W06 warm WhiteGold surface retains color contrast')
print('wheel effect layering, hub and branch transition passed')
