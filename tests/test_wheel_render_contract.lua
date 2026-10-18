local f=dofile('tests/wheel_fixture.lua')()
local g=f.addon.wheelGeometry
local function near(a,b) return math.abs(a-b)<.001 end
-- Compact even with the player's large icon/scale settings and deeper menus.
local m=g.layout({11,6,13},{4,4},80,72,1.5,1652,1013,10,1000)
assert(m.extent*2<=520,'nested wheel must have a compact maximum diameter')
assert(m.extent*2<=1013*.62,'hierarchy leaves world visible')
assert(type(g.texCoords)=='function','explicit UV rotation avoids client SetRotation scaling')
for _,a in ipairs({0,math.pi/2,math.pi,-math.pi/2,.427}) do
 local uv={g.texCoords(a)}
 assert(#uv==8)
 -- Bilinear texture mapping at visual sector axis must sample source top.
 local x,y=.5-.3*math.sin(a),.5-.3*math.cos(a)
 local u=uv[1]+x*(uv[5]-uv[1])+y*(uv[3]-uv[1])
 local v=uv[2]+x*(uv[6]-uv[2])+y*(uv[4]-uv[2])
 assert(near(u,.5) and near(v,.2),'UV sector axis matches hit-test angle')
end
f:root()
f.wheel:SetSelection(1)
for _,slot in ipairs(f.wheel.slots) do
 if slot.sector.shown then assert(slot.sector.alpha>=.9,'pattern stays visible at rest') end
end
assert(f.wheel:Open()==false and not f.wheel.frame.shown,'second invocation closes')
print('wheel compact/UV/opacity/toggle contract passed')
