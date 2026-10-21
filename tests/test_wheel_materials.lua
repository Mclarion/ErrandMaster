local f=dofile('tests/wheel_fixture.lua')()
local w=f.wheel
f:legacyLayout()
f:root()
local function same(a,b)
 for i=1,3 do assert(math.abs(a[i]-b[i])<.0001,'branch colors must match') end
end
local rootColor=w.slots[4].sector.color
assert(w.slots[4].shadow and w.slots[4].relief,'separate surface/shadow layers')
assert(w.slots[4].borderGlow.texture:find('WheelHalo',1,true),'halo must be a soft effect, not duplicated hard border')
assert(w.slots[4].medallion.layer=='OVERLAY' and w.slots[4].medallion.sublevel==6)
assert(w.slots[4].activeMedallion.sublevel==7 and w.slots[4].borderGlow.sublevel<6,'jewels must render above effects')
f:click(4)
for i=1,w.count-1 do
 same(w.slots[i].sector.color,rootColor)
 assert(w.slots[i].medallion.texture:find('Green',1,true))
end
same(w.slots[w.count].sector.color,{1,.92,.72})
assert(w.slots[w.count].texture.desaturated == false,'Back has a neutral surface without altering supplied artwork')
local h=w.historyViews[1]
assert(h.halos[4].alpha>.5 and h.halos[3].alpha==0,'chosen ancestor path stays lit')
assert(h.medallions[4].sublevel==6,'retained jewels are top-layer too')
f:click(4)
for i=1,w.count-1 do same(w.slots[i].sector.color,rootColor) end
assert(w.historyViews[2].halos[4].alpha>.5)
f:hit(1);w:SetSelection(1)
w.frame.scripts.OnUpdate(w.frame,.016)
assert(w.slots[1].borderGlow.alpha>0 and w.slots[1].borderGlow.alpha<1,'smooth glow transition')
w:Close()
f:root()
for _,slot in ipairs(w.slots) do
 assert(slot.glowAlpha==0 and slot.glowTarget==0 and slot.activeMedallion.alpha==0 and
   slot.borderGlow.alpha==0,'reopened pooled slots must start without stale highlights')
end
w:Close()
for _,v in ipairs(w.historyViews) do
 for _,r in ipairs(v.halos) do assert(not r.shown,'no stale ancestor glows after close') end
end
print('wheel material, inherited palette, path glow and jewel layering passed')
