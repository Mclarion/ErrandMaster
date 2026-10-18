local fixture=dofile('tests/wheel_fixture.lua')
local f=fixture()
local w=f.wheel
local original=w.Create
w.Create=function(self)
  original(self)
  error('synthetic creation fault')
end
local ok,result=pcall(w.Open,w)
assert(ok and result==false,'opening failure must release chat and return, not throw')
for _,frame in ipairs(f.frames) do
  assert(not (frame.keyboard and frame.shown),'failed opening retains keyboard capture')
end
assert(f.notices[#f.notices]:find('synthetic creation fault',1,true),'first failure is visible in chat')
w.Create=original
assert(w:Open(),'a fresh open can recover after a failed creation')
local current=w.frame
w.UpdateHighlight=function() error('synthetic update fault') end
assert(pcall(current.scripts.OnUpdate,current,.016),'update failure must not repeat every frame')
assert(not current:IsShown() and current.scripts.OnUpdate==nil)
assert(f.notices[#f.notices]:find('synthetic update fault',1,true))
local notice
f.addon.addonSettings={Notice=function(_,v) notice=v end}
w:Notice('Binding canceled.')
assert(notice=='Binding canceled.','new settings page receives binding feedback')
print('wheel failed-open/update cleanup and feedback passed')
