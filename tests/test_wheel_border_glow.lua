local f=dofile('tests/wheel_fixture.lua')()
local w=f.wheel
f:root()
local tier=w.tiers[#w.tiers]
local slot=w.slots[1]
assert(math.abs(slot.texture.w-tier.iconSize)<.001)
assert(math.abs(slot.iconGlow.w-tier.iconSize)<.001,
  'silhouette underglow shares the artwork canvas without spilling sectors')
assert(slot.texture.color[1]==1 and slot.texture.color[2]==1 and slot.texture.color[3]==1,
  'source artwork remains untinted')
assert(slot.iconGlow.layer=='BORDER' and slot.medallionGlow.layer=='BORDER' and
  slot.medallion.layer=='OVERLAY' and slot.activeMedallion.layer=='OVERLAY',
  'jewels remain above backlight')
w.frame.scripts.OnUpdate(w.frame,.016)
assert(slot.iconGlow.alpha>=.22 and slot.medallionGlow.alpha>=.18,
  'idle underglow must be plainly visible')
f:hit(1);w:SetSelection(1)
for i=1,120 do w.frame.scripts.OnUpdate(w.frame,.016) end
assert(slot.iconGlow.alpha>=.55 and slot.medallionGlow.alpha>=.48,
  'hover underglow must brighten both icon and jewel')
f:click(4)
local retained=w.historyViews[1]
local root=w.tiers[1]
assert(math.abs(retained.iconGlows[1].w-root.iconSize)<.001,
  'retained silhouette light shares its source icon size')
assert(retained.iconGlows[1].alpha>=.22 and retained.medallionGlows[1].alpha>=.18,
  'retained idle backlight is visible')
assert(retained.iconGlows[4].alpha>=.55 and retained.medallionGlows[4].alpha>=.48,
  'selected retained branch stays bright')
dofile('tests/test_wheel_silhouette_render.lua')
print('wheel border-aware glow rendering passed')
