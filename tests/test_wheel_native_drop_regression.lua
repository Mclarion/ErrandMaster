local f=dofile('tests/wheel_fixture.lua')()
local w,s=f.wheel,f.addon.db.data.settings
assert(w:SetEditing(true))
local original=s.wheelSlots[2]
local p=w.slots[2].texture.point
f:cursor(p[4],p[5]);f:payload('spell',777)
assert(w:OverIcon(2),'fixture is at icon center')
w:UpdateNativePreview(.01)
assert(w.nativePreview and w.dragGhost.shown)
w.frame.scripts.OnReceiveDrag(w.frame)
assert(s.wheelSlots[2].type=='folder' and s.wheelSlots[2].entries[1].id==777 and
  s.wheelSlots[2].entries[2]==original,'immediate icon-center drop groups without dwell')
assert(not w.nativePreview and not w.dragGhost.shown,'drop cleans addon preview immediately')
assert(GetCursorInfo()=='spell','native cursor payload is deliberately retained')
local count=#s.wheelSlots
f:cursor(w.centerX,w.centerY);f:payload('item',888)
w:UpdateNativePreview(.01)
w.frame.scripts.OnReceiveDrag(w.frame)
assert(#s.wheelSlots==count,'hub drop cannot append an entry')
assert(not w.nativePreview and not w.dragGhost.shown,'rejected drop also clears addon preview')
f:hit(3,nil,.08);f:payload('item',889)
assert(not w:OverIcon(3),'inner wedge is insertion space, not icon center')
w.frame.scripts.OnReceiveDrag(w.frame)
assert(#s.wheelSlots==count+1 and s.wheelSlots[3].id==889,'non-icon ring drop inserts into slot')
print('native drop classification and immediate preview cleanup passed')
