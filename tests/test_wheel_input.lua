local f=dofile('tests/wheel_fixture.lua')()
local wheel,addon=f.wheel,f.addon
f:legacyLayout()
f:root()
assert(wheel.count==11 and wheel.slots[1].label.shown)
assert(wheel.slots[1].sector.texture:find('WheelPatternT0N11.blp',1,true))
assert(wheel.slots[1].glow.texture:find('WheelBorderT0N11.blp',1,true))
assert(wheel.centerArt.texture:find('WheelCenter.blp',1,true))
assert(wheel.frame.w<UIParent.w and wheel.frame.h<UIParent.h)
wheel.frame.scripts.OnKeyDown(wheel.frame,'A')
wheel.frame.scripts.OnKeyDown(wheel.frame,'D')
assert(wheel.frame.shown,'movement keys must not dismiss wheel')
local tier=wheel.tiers[1]
assert(math.abs(wheel.slots[1].sector.w-addon.wheelGeometry.artDiameter(tier.outerRadius))<.001,
  'explicit UVs preserve physical radius')
for i=1,wheel.count do
  local slot=wheel.slots[i]
  assert(slot.texture.shown and slot.label.shown and slot.texture.alpha~=0)
  local sectorUV={addon.wheelGeometry.texCoords(tier.angles[i]-math.pi/2)}
  local jewelUV={addon.wheelGeometry.texCoords(tier.angles[i]+math.pi/2)}
  for j=1,8 do
    assert(math.abs(slot.sector.uv[j]-sectorUV[j])<.001)
    assert(math.abs(slot.medallion.uv[j]-jewelUV[j])<.001,
      'source upward point must face hub at every angle')
  end
  assert(rawget(slot.sector,'rotation')==nil,'client rotation scaling is not used')
  assert(f:hit(i,1,.96)==i,'whole outer sector selectable')
end
f:hit(1)
wheel:SetSelection(1)
assert(wheel.centerLabel.text=='Bank' and wheel.slots[1].glowTarget==1)
assert(wheel.centerPlate.shown and not wheel.centerArt.shown,
  'hover label replaces lettering artwork, not drawn across it')
wheel.frame.scripts.OnUpdate(wheel.frame,.016)
assert(wheel.slots[1].activeMedallion.alpha>0 and wheel.slots[1].activeMedallion.alpha<1,
  'hover jewel crossfades instead of swapping instantly')
wheel:Layout()
assert(wheel.centerLabel.text=='Bank' and wheel.centerPlate.shown,
  'resize/re-layout preserves active hub hover')
wheel:SetSelection(nil)
assert(wheel.centerLabel.text=='')
assert(not wheel.centerPlate.shown and wheel.centerArt.shown)
assert(addon.db:WheelReplace(1,{type='category',category='Blacksmithing Trainer'}))
wheel:Layout(); wheel:SetSelection(1)
assert(wheel.centerLabel.text=='Blacksmithing Trainer' and wheel.centerLabel.w>=80 and
  wheel.centerLabel.h>=38 and wheel.centerPlate.w>=wheel.centerLabel.w,
  'long hovered name wraps within the hub without covering sector icons')
assert(wheel.centerPlate.w<=wheel.tiers[1].innerRadius*2,
  'hover plate cannot cover neighboring sector icons')
wheel:SetSelection(nil)
assert(wheel.centerArt.shown and not wheel.centerPlate.shown,
  'unhovered hub retains its normal filled artwork')
assert(addon.db:WheelReplace(1,{type='category',category='Bank'}))
wheel:Layout()
local original=wheel.slots[2].sector.SetTexCoord
wheel.slots[2].sector.SetTexCoord=function() error('texture coordinates unavailable') end
wheel:Layout()
assert(not wheel.slots[2].sector.shown and wheel.slots[2].texture.shown)
assert(not wheel.slots[2].borderGlow.shown)
wheel.slots[2].sector.SetTexCoord=original
wheel:Layout()
assert(wheel.slots[1].sector.uv[1]==0 and wheel.slots[1].sector.uv[2]==0)
assert(wheel:StartCapture() and wheel.capture.shown)
assert(wheel.capture.propagate==false and wheel.capture.keyboard==true)
wheel:Close()
assert(not wheel.capture.shown and wheel.capture.keyboard==false)
f:root(); assert(wheel:StartCapture())
wheel.frame:Hide()
assert(not wheel.capture.shown and wheel.capture.keyboard==false,'direct wheel hide releases capture')
f:root(); assert(wheel:StartCapture())
wheel.frame.scripts.OnEvent(wheel.frame,'PLAYER_REGEN_DISABLED')
assert(not wheel.capture.shown and not wheel.frame.shown,'combat releases capture')
f:root(); assert(wheel:StartCapture())
wheel.capture.scripts.OnEvent(wheel.capture,'PLAYER_REGEN_DISABLED')
assert(not wheel.capture.shown,'capture itself observes combat without wheel')
assert(wheel:StartCapture())
wheel.capture:Hide()
assert(wheel.capture.keyboard==false and wheel.capture.mouse==false,
  'direct capture hide cannot leave input enabled')
local show=wheel.capture.Show
wheel.capture.Show=function() error('protected frame show') end
assert(not wheel:StartCapture() and wheel.capture.keyboard==false and
  wheel.capture.mouse==false and not wheel.capture.shown,
  'capture show error rolls back keyboard and mouse')
wheel.capture.Show=show
assert(wheel:StartCapture())
wheel.capture.scripts.OnKeyDown(wheel.capture,'ESCAPE')
assert(not wheel.capture.shown)
local bound
GetBindingKey=function() return bound end
GetBindingAction=function(key) return key==bound and 'ERRANDMASTER_WHEEL' or
  key=='F8' and 'MOVEFORWARD' or '' end
SetBinding=function(key,action)
  if action then bound=key elseif bound==key then bound=nil end
  return true
end
SaveBindings=function() end
GetCurrentBindingSet=function() return 1 end
IsShiftKeyDown=function() return false end
IsControlKeyDown=function() return false end
IsAltKeyDown=function() return false end
assert(wheel:StartCapture())
wheel.capture.scripts.OnKeyDown(wheel.capture,'F8')
assert(bound==nil and wheel.capture.shown,'occupied binding not overwritten')
wheel.capture.scripts.OnKeyDown(wheel.capture,'F7')
assert(bound=='F7' and not wheel.capture.shown)
local queued={}
addon.errands={All=function() return queued end,Add=function(_,value)
  queued[#queued+1]=value; return value end}
f:click(3)
assert(not wheel.frame.shown and #queued==1 and queued[1].category=='Repair')
f:root(); f:click(3)
assert(#queued==1,'repeat quick service does not duplicate a task')
f:root(); f:click(1)
assert(wheel.submenu=='Bank' and wheel.frame.shown)
f:click(3)
assert(wheel.submenu==nil and wheel.frame.shown,'Back stays reachable')
f:cursor(wheel.centerX,wheel.centerY)
wheel.centerClose.scripts.OnClick(wheel.centerClose)
assert(not wheel.frame.shown,'center closes')
f:root(); f:cursor(wheel.centerX,wheel.centerY)
wheel.frame.scripts.OnMouseDown(wheel.frame,'LeftButton')
assert(not wheel.frame.shown,'hub mouse closes when no button intercepted')
f:root(); wheel.outside.scripts.OnClick(wheel.outside)
assert(not wheel.frame.shown,'locked outside click closes')
f:root(); wheel.frame.scripts.OnKeyDown(wheel.frame,'ESCAPE')
assert(not wheel.frame.shown and f:resets()==0)
C_Spell={GetSpellInfo=function() return {name='Safe Spell',iconID=135000} end}
addon.db:WheelReplace(1,{type='spell',id=1234})
f:root()
assert(wheel.slots[1].texture.texture==135000)
f:click(1)
assert(f.notices[#f.notices]:find('not executed',1,true))
InCombatLockdown=function() return true end
assert(not wheel:Open() and not wheel:DropNative())
print('wheel input, visual state, binding and safe action tests passed')
