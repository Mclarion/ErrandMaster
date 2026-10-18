-- Client-reported persistent edit lifecycle, using actual wheel handlers.
local f=dofile('tests/wheel_fixture.lua')()
local w,s=f.wheel,f.addon.db.data.settings
assert(w:SetEditing(true))
assert(w.frame and w.frame:IsShown() and s.wheelUnlocked,
  'enabling edit mode must open the wheel, not leave a hidden editing state')
assert(w:Open() and w.frame:IsShown() and s.wheelUnlocked,
  'bound Open during editing must keep the wheel visible')
w.frame.scripts.OnKeyDown(w.frame,'ESCAPE')
assert(not w.frame:IsShown() and not s.wheelUnlocked,
  'Escape explicitly exits editing before dismissing the wheel')
assert(w:SetEditing(true) and w.frame:IsShown())
w.centerClose.scripts.OnClick(w.centerClose,'LeftButton')
assert(not w.frame:IsShown() and not s.wheelUnlocked,
  'center explicitly exits editing before dismissing the wheel')
assert(w:SetEditing(true))
w.outside.scripts.OnClick(w.outside)
assert(w.frame:IsShown() and s.wheelUnlocked,'outside click must not dismiss editing')
f.addon.travelPoints={OpenFavoriteForm=function() return false end}
w:SelectCategory('Add Coordinates')
assert(w.frame:IsShown() and s.wheelUnlocked,'failed coordinate form does not dismiss editing')
f.addon.addonSettings={Open=function() end}
w:SelectCategory('AddOns Settings')
assert(w.frame:IsShown() and s.wheelUnlocked,'ordinary settings action keeps editing visible')
print('wheel persistent editing lifecycle regression passed')
