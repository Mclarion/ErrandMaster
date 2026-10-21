-- Pure, UI-scale-independent wheel geometry. Coordinates are UIParent units.
local _, addon = ...
local geometry = {}
addon.wheelGeometry = geometry
local pi, cos, sin = math.pi, math.cos, math.sin
local function clamp(value, low, high) return math.max(low,math.min(high,value)) end
local function sweep(count, level)
  return level == 1 and 2*pi or math.min(5.5,math.max(pi/2,count*.42))
end
function geometry.layout(counts, parents, radius, icon, scale, width, height, x, y)
  radius=clamp(radius or 100,40,220)*clamp(scale or 1,.5,1.5)
  icon=clamp(icon or 40,20,72)*clamp(scale or 1,.5,1.5)
  local rootCount=counts[1] or 0
  -- Each additional slot after eight opens a little arc room; there is no
  -- abrupt threshold where several insertions leave the ring unchanged.
  local rootOuter=math.max(radius*1.12*(1+math.max(0,rootCount-8)*.018),
    icon*rootCount*.83/(2*pi)*1.4,icon*1.8)
  local raw={}
  for level,count in ipairs(counts) do
    local inner=level==1 and rootOuter*.42 or raw[level-1].outerRadius
    local outer=level==1 and rootOuter or inner/(level==2 and .70 or .74)
    raw[level]={innerRadius=inner,outerRadius=outer,count=count}
  end
  if #raw==0 then raw[1]={innerRadius=radius*.42,outerRadius=radius,count=0} end
  local maxRadius=raw[#raw].outerRadius
  -- A menu is not a fullscreen overlay. Cap the complete hierarchy in UI
  -- units as well as against the viewport; never hardcode a monitor resolution.
  local budget=math.min(520,math.min(width,height)*.62)
  local fit=math.min(1,math.max(1,budget)/(2*(maxRadius+20)))
  local extent=maxRadius*fit+20*fit
  local result={tiers={},fit=fit,extent=extent,width=width,height=height,
    x=clamp(x or width/2,extent,width-extent),
    y=clamp(y or height/2,extent,height-extent)}
  for level,t in ipairs(raw) do
    local centerAngle=pi/2
    if level>1 then
      local parent=result.tiers[level-1]
      centerAngle=parent.angles[clamp(parents[level-1] or 1,1,math.max(1,parent.count))] or pi/2
    end
    local arc=sweep(t.count,level)
    local inner,outer=t.innerRadius*fit,t.outerRadius*fit
    local tier={depth=level,count=t.count,centerAngle=centerAngle,sweep=arc,
      innerRadius=inner,outerRadius=outer,radius=(inner+outer)/2,angles={}}
    -- Reserve room for the whole square underglow and the sector border.
    -- A disk around the slot center bounds every square corner, regardless
    -- of how its screen-aligned sides rotate relative to this wedge.
    -- A small inward bias creates breathing room between icons and rim labels.
    -- Recalculate clearance around the shifted center so even dense 24+ wedges
    -- retain the complete square underlay inside their sector border.
    tier.iconRadius=tier.radius-math.min(5*fit,(outer-inner)*.10)
    local radial=math.min(tier.iconRadius-inner,outer-tier.iconRadius)
    local halfAngle=t.count>0 and arc/(2*t.count) or pi/2
    local angular=tier.iconRadius*sin(halfAngle)
    tier.borderInset=math.min(2*fit,math.min(radial,angular)*.12)
    local clearance=math.min(radial-tier.borderInset,
      tier.iconRadius*sin(halfAngle-tier.borderInset/tier.iconRadius))
    local glowLimit=clearance*math.sqrt(2)*.98
    tier.iconSize=math.min(icon*fit*1.08,glowLimit/1.25)
    tier.glowSize=tier.iconSize*1.25
    for i=1,t.count do
      tier.angles[i]=level==1 and pi/2-(i-1)*arc/t.count or
        centerAngle+arc/2-(i-.5)*arc/t.count
    end
    result.tiers[level]=tier
  end
  return result
end
function geometry.icon(tier,index)
  local angle=tier.angles[index]
  return cos(angle)*tier.iconRadius,sin(angle)*tier.iconRadius
end
-- Upright label centered directly below its icon on every spoke, including
-- the lower semicircle (where an outward radial label used to sit above it).
function geometry.labelPosition(tier,index)
  local x,y=geometry.icon(tier,index)
  return x,y-tier.iconSize*.70
end
function geometry.rim(tier,index)
  local angle=tier.angles[index]
  return cos(angle)*tier.outerRadius,sin(angle)*tier.outerRadius
end
function geometry.hit(model,x,y)
  local dx,dy=x-model.x,y-model.y
  local r=math.sqrt(dx*dx+dy*dy)
  for level=#model.tiers,1,-1 do
    local tier=model.tiers[level]
    if r>=tier.innerRadius and r<=tier.outerRadius+2 then
      if tier.count<1 then return end
      local direction=math.atan2 and math.atan2(dy,dx) or
        (dx==0 and (dy>=0 and pi/2 or -pi/2) or math.atan(dy/dx)+(dx<0 and pi or 0))
      if level>1 and cos(direction-tier.centerAngle)<cos(tier.sweep/2) then return end
      local best,alignment=nil,-2
      for i,angle in ipairs(tier.angles) do
        local score=cos(direction-angle)
        if score>alignment then best,alignment=i,score end
      end
      return best,level
    end
  end
end
-- Explicit texture coordinates avoid client-dependent SetRotation scaling.
-- Eight transparent pixels on a 512 canvas prevent clamp-to-edge streaks.
geometry.artRadius=248/256
function geometry.artDiameter(outerRadius) return outerRadius*2/geometry.artRadius end
function geometry.texCoords(angle)
  local c,s=cos(angle),sin(angle)
  local function uv(x,y) return .5+c*x-s*y,.5+s*x+c*y end
  local ulx,uly=uv(-.5,-.5)
  local llx,lly=uv(-.5,.5)
  local urx,ury=uv(.5,-.5)
  local lrx,lry=uv(.5,.5)
  return ulx,uly,llx,lly,urx,ury,lrx,lry
end
