local addon={}
assert(loadfile('UI/WheelGeometry.lua'))('ErrandMaster',addon)
local g=addon.wheelGeometry
local function near(a,b) return math.abs(a-b)<.001 end
for _,view in ipairs({{800,600,.7},{5120,1440,1},{1024,768,1.5},{600,900,1}}) do
 local w,h,ui=view[1],view[2],view[3]
 local x,y=w*.03,h*.98
 local model=g.layout({11,6,13},{4,4},40,20,.5,w,h,x,y)
 assert(model.x-model.extent>=0 and model.x+model.extent<=w and model.y-model.extent>=0 and model.y+model.extent<=h)
 assert(model.tiers[1].outerRadius<100,'small radius must remain useful')
 local big=g.layout({11,6,13},{4,4},100,40,1,w,h,x,y)
 assert(big.tiers[1].outerRadius>model.tiers[1].outerRadius,'scale/radius must change geometry')
 for level,tier in ipairs(model.tiers) do
  for index,angle in ipairs(tier.angles) do
   local r=tier.innerRadius+(tier.outerRadius-tier.innerRadius)*.95
   local hit,depth=g.hit(model,model.x+math.cos(angle)*r,model.y+math.sin(angle)*r)
   assert(hit==index and depth==level,'entire sector must hit')
   local ix,iy=g.icon(tier,index)
   assert(near(ix,math.cos(angle)*tier.radius) and near(iy,math.sin(angle)*tier.radius),'icon lies at tier midpoint')
   local rx,ry=g.rim(tier,index)
   assert(near(math.sqrt(rx*rx+ry*ry),tier.outerRadius),'ornament anchored to rim')
  end
 end
 assert(g.hit(model,model.x,model.y)==nil)
 assert(g.hit(model,model.x+model.extent+1,model.y)==nil)
end
local m=g.layout({0},{},40,20,1,800,600,400,300)
assert(#m.tiers==1 and #m.tiers[1].angles==0,'empty wheel remains valid')
local before=g.layout({11},{},100,40,1,1600,900,800,450)
local inserted=g.layout({12},{},100,40,1,1600,900,800,450)
assert(inserted.tiers[1].outerRadius>before.tiers[1].outerRadius,
  'each between-item insertion grows the root ring modestly')
assert(near(g.artRadius,248/256) and near(g.artDiameter(100)*g.artRadius,200),
  'explicit UVs use padded source radius without implicit rotation scale')
for _,uiScale in ipairs({.65,1,1.5}) do
  for _,dims in ipairs({{440,320},{5120,1440},{720,1280},{2000,480}}) do
    local w,h=dims[1]/uiScale,dims[2]/uiScale
    local model=g.layout({24,12,18,7},{6,3,5},220,72,1.5,w,h,w-.01,.01)
    assert(model.x>=model.extent and model.x<=w-model.extent)
    assert(model.y>=model.extent and model.y<=h-model.extent)
    for level,t in ipairs(model.tiers) do
      if level>1 then assert(near(t.innerRadius,model.tiers[level-1].outerRadius)) end
      for i,a in ipairs(t.angles) do
        local r=t.outerRadius*.999
        local hit,depth=g.hit(model,model.x+math.cos(a)*r,model.y+math.sin(a)*r)
        assert(hit==i and depth==level,'deep segment outer edge hit survives fit')
        assert(g.hit(model,model.x+math.cos(a)*(t.outerRadius+4),
          model.y+math.sin(a)*(t.outerRadius+4))~=i or level<#model.tiers,
          'outside visible art is not selectable')
      end
    end
  end
end
-- Square supplied icons must fit, not merely their radial centers.
for _,counts in ipairs({{11,6,13},{24,24,24},{3,3,3}}) do
 for _,viewport in ipairs({{1200,800},{440,320}}) do
  local model=g.layout(counts,{4,4},80,72,1.5,viewport[1],viewport[2],200,150)
  for level,t in ipairs(model.tiers) do
   for i in ipairs(t.angles) do
    local x,y=g.icon(t,i)
    for _,dx in ipairs({-.5,.5}) do
     for _,dy in ipairs({-.5,.5}) do
      local hit,depth=g.hit(model,model.x+x+dx*t.iconSize,model.y+y+dy*t.iconSize)
      assert(hit==i and depth==level,'icon corner crosses sector boundary')
     end
    end
   end
  end
 end
end
print('wheel geometry tests passed')
