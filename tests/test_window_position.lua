local addon={db={data={settings={windowPositions={}}}}}
UIParent={GetWidth=function() return 1000 end, GetHeight=function() return 600 end,
  GetLeft=function() return 0 end, GetBottom=function() return 0 end}
local frame={x=300,y=400}
function frame:GetCenter() return self.x,self.y end
function frame:ClearAllPoints() self.cleared=true end
function frame:SetPoint(...) self.point={...} end
assert(loadfile('UI/WindowPosition.lua'))('ErrandMaster',addon)
assert(addon.windowPosition:Save(frame,'targets'))
assert(addon.db.data.settings.windowPositions.targets.x==.3)
local restored={ClearAllPoints=frame.ClearAllPoints, SetPoint=frame.SetPoint}
assert(addon.windowPosition:Restore(restored,'targets'))
assert(restored.point[1]=='CENTER' and restored.point[4]==300 and restored.point[5]==400)
frame.x=-40
assert(not addon.windowPosition:Save(frame,'targets') and
  addon.db.data.settings.windowPositions.targets.x==.3,
  'off-screen drag positions must not corrupt saved settings')
assert(not addon.windowPosition:Restore(restored,'main'))
print('window position persistence tests passed')
