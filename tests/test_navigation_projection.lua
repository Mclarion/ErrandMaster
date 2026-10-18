-- Real navigation module: native world projection, not guessed cross-zone math.
local addon={}
assert(loadfile('Routing/Navigation.lua'))('ErrandMaster',addon)
local nav=addon.navigation
local map,x,y=10,.5,.5
addon.Position=function() return map,x,y end
addon.MapWorldSize=function() return nil end -- Classic capability gap.
local facing=0
GetPlayerFacing=function() return facing end
CreateVector2D=function(a,b) return {GetXY=function() return a,b end} end
local instances={[10]=0,[11]=0,[12]=1}
C_Map={GetWorldPosFromMapPos=function(id,vector)
  local a,b=vector:GetXY()
  -- Native axes increase north and west, unlike map XY (east and south).
  return instances[id],CreateVector2D(5000-b*500,2000-(id-10)*1000-a*1000)
end}
local target={id='across-zone',mapID=11,x=.5,y=.5}
local reading=nav:Guidance(target)
assert(reading and reading.distance and math.abs(reading.distance-1000)<.001,
  'cross-zone target on same world instance has direct projected yard distance')
assert(math.abs(reading.angle+math.pi/2)<.001 and reading.mode=='direct-unknown',
  'east cross-zone bearing works without claiming a walking path')
assert(nav:Measure({mapID=12,x=.5,y=.5})==nil,
  'never compare coordinates on different world instances')
-- Same-zone projection also supplies accurate bearing without GetMapWorldSize.
local same={mapID=10,x=.6,y=.5}
reading=nav:Measure(same)
assert(reading and math.abs(reading.distance-100)<.001 and math.abs(reading.angle+math.pi/2)<.001)
facing=3*math.pi/2
assert(math.abs(nav:Measure(same).angle)<.001,'east-facing player points straight ahead')
facing=0
local directions={{.5,.3,0},{.4,.5,math.pi/2},{.5,.7,-math.pi},{.6,.5,-math.pi/2}}
for _,v in ipairs(directions) do
  local r=nav:Measure({mapID=10,x=v[1],y=v[2]})
  assert(math.abs(r.distance-100)<.001 and math.abs(r.angle-v[3])<.001,
    'non-square map north/west/south/east cardinal bearings')
end
x=.501
assert(math.abs(nav:Measure(same).distance-99)<.001,'one yard movement updates direct distance')
x=.5
GetPlayerFacing=nil
reading=nav:Measure(target)
assert(reading.distance and reading.angle==nil,'missing facing retains distance only')
GetPlayerFacing=function() return 0 end
local original=C_Map.GetWorldPosFromMapPos
C_Map.GetWorldPosFromMapPos=function() error('API unavailable') end
assert(nav:Measure(target)==nil,'projection errors fail closed across zones')
addon.MapWorldSize=function() return 1000,500 end
assert(math.abs(nav:Measure(same).distance-100)<.001,'same-map yard scale survives projection failure')
C_Map.GetWorldPosFromMapPos=original
local instance,north,west=nav:WorldPosition(10,.5,.5)
assert(instance==0 and north==4750 and west==1500,'zero is a valid world instance')
assert(nav:WorldPosition(0,.5,.5)==nil and nav:WorldPosition(10,2,.5)==nil)
C_Map.GetWorldPosFromMapPos=function() return 0,CreateVector2D(0/0,10) end
assert(nav:Measure(target)==nil,'NaN projected coordinate rejected')
C_Map.GetWorldPosFromMapPos=function() return 0,CreateVector2D(4750,1500) end
issecretvalue=function(value) return value==4750 end
assert(nav:WorldPosition(10,.5,.5)==nil,'secret projection must not be used')
issecretvalue=nil
C_Map.GetWorldPosFromMapPos=original
local oldCreate=CreateVector2D
CreateVector2D=function() error('cannot construct vector') end
assert(nav:Measure(target)==nil,'vector errors rejected')
CreateVector2D=oldCreate
print('native world projection navigation tests passed')
