-- Focused queue, native heading and manual-anchor contracts (Lua 5.1).
local addon={}
local function load(path) assert(loadfile(path))('ErrandMaster',addon) end
load('Core/Database.lua'); load('Core/Errands.lua'); load('Routing/RoutePlanner.lua')
load('Routing/Navigation.lua')
ErrandMasterDB=nil; addon.db:Initialize('Test-Realm')
local a=addon.errands:Add({name='A',mapID=10,x=.8,y=.5})
local b=addon.errands:Add({name='B',mapID=10,x=.7,y=.5})
local c=addon.errands:Add({name='C',mapID=10,x=.1,y=.5})
local d=addon.errands:Add({name='D',mapID=10,x=.2,y=.5})
local initial=addon.route:Plan(addon.errands:All(),10,0,.5,true,nil,nil,100,100)
assert(initial[1].id==c.id)
addon.errands:Reorder(a.id,1)
assert(a.manualPosition==1 and b.manualPosition==nil and c.manualPosition==nil)
local ordered=addon.route:Plan(addon.errands:All(),10,0,.5,true,nil,nil,100,100)
assert(ordered[1].id==a.id and ordered[2].id==b.id and ordered[3].id==d.id and ordered[4].id==c.id,
  'only moved target is fixed; remaining items optimize from its endpoint')
addon.errands:Reorder(d.id,2)
ordered=addon.route:Plan(addon.errands:All(),10,0,.5,true,nil,nil,100,100)
assert(ordered[1].id==a.id and ordered[2].id==d.id and ordered[3].id==c.id,
  'second anchor does not release the first')
addon.errands:Delete(a.id)
ordered=addon.route:Plan(addon.errands:All(),10,0,.5,true,nil,nil,100,100)
assert(ordered[2].id==d.id,'deleted anchor leaves remaining anchor at its slot')
local ok=pcall(function() addon.errands:Reorder(b.id,0) end)
assert(not ok,'invalid order cannot mutate saved anchors')
local x,y=.5,.5
local target={id='em-native',name='Native',mapID=10,x=.6,y=.5}
local oldPin={}; local removed=0; local added=0
TomTom={AddWaypoint=function() added=added+1 end,
  RemoveWaypoint=function(_,handle) assert(handle==oldPin); removed=removed+1 end}
addon.navigation.handle=oldPin; addon.navigation.provider=TomTom
assert(addon.navigation:Clear() and removed==1)
addon.navigation.paused=nil
addon.db.data.settings.useTomTom=false
assert(addon.navigation:Next(target) and added==0 and addon.navigation.target==target,
  'native target works with TomTom absent/off and does not add an external pin')
C_Map={GetBestMapForUnit=function() return 10 end,
  GetPlayerMapPosition=function() return {GetXY=function() return x,y end} end,
  GetMapWorldSize=function() return 1000,1000 end,
  GetMapInfo=function() return {mapType=3} end,
  GetMapGroupID=function() return nil end}
GetPlayerFacing=function() return 0 end
UnitOnTaxi=function() return false end
local frame={scripts={}}
function frame:RegisterEvent() end
function frame:UnregisterEvent() end
function frame:SetScript(name,cb) self.scripts[name]=cb end
CreateFrame=function() return frame end
addon.ui={Create=function() end,Refresh=function() end}
addon.destinations={Refresh=function() end,Restore=function() end}
addon.locations={All=function() return {} end}
addon.quests={OnMap=function() return {} end}
SlashCmdList={}
assert(loadfile('Core/Init.lua'))('ErrandMaster',addon)
local heading=addon.navigation:Measure(target)
assert(heading and heading.distance and math.abs(heading.distance-100)<.001 and
  heading.angle and math.abs(heading.angle+math.pi/2)<.001,
  'east of player requires an eastward bearing from north-facing')
GetPlayerFacing=function() return 3*math.pi/2 end
heading=addon.navigation:Measure(target)
assert(heading and math.abs(heading.angle)<.001)
GetPlayerFacing=nil
heading=addon.navigation:Measure(target)
assert(heading and heading.distance and heading.angle==nil,'missing facing hides direction')
C_Map.GetMapWorldSize=nil
heading=addon.navigation:Measure(target)
assert(heading and heading.distance==nil and heading.angle==nil,'no yard scale hides both')
C_Map.GetMapWorldSize=function() return 1000,1000 end
local protected=0/0
assert(addon.navigation:Measure({mapID=10,x=protected,y=.5})==nil)
assert(addon.navigation:Measure({mapID=11,x=.6,y=.5})==nil,
  'cross-map bearing is not fabricated')
local secretFacing=math.pi/4
issecretvalue=function(value) return value==secretFacing end
GetPlayerFacing=function() return secretFacing end
heading=addon.navigation:Measure(target)
assert(heading and heading.distance and heading.angle==nil,'secret facing hides arrow')
issecretvalue=nil; GetPlayerFacing=nil
x=.5985
local queue=addon.errands:Add({name='Arrive',mapID=10,x=.6,y=.5})
addon.db.data.characters[addon.db.character].activeErrandId=queue.id
addon.Plan=function() return {{id=queue.id,name=queue.name,mapID=10,x=.6,y=.5}},{} end
local refreshes=0
addon.Refresh=function() refreshes=refreshes+1 end
addon.movementOrigin={map=10,x=.5,y=.5}
assert(addon:MovementTick() and addon.errands:Get(queue.id)==nil and refreshes==1,
  'within 2 direct yards removes active queue entry without service completion')
local far=addon.errands:Add({name='Far',mapID=10,x=.6,y=.5})
addon.db.data.characters[addon.db.character].activeErrandId=far.id
addon.Plan=function() return {{id=far.id,name=far.name,mapID=10,x=.6,y=.5,floor=1}},{} end
addon.trails={NativeSample=function() return {uiMapID=10,floor=2} end}
assert(not addon:MovementTick() and addon.errands:Get(far.id),'different floor must not arrive')
addon.trails.NativeSample=function() return {uiMapID=10,floor=0} end
assert(not addon:MovementTick() and addon.errands:Get(far.id),
  'native floor zero is unknown, not matching-floor evidence')
addon.trails.NativeSample=function() return {uiMapID=10,floor=1} end
UnitOnTaxi=function() return true end
assert(not addon:MovementTick() and addon.errands:Get(far.id),'taxi must not arrive')
UnitOnTaxi=function() return false end
x=.598
assert(addon:MovementTick() and not addon.errands:Get(far.id),
  'exact two-yard boundary on matching floor permits arrival')
local ambiguous=addon.errands:Add({name='Other level',mapID=10,x=.6,y=.5})
addon.db.data.characters[addon.db.character].activeErrandId=ambiguous.id
addon.Plan=function() return {ambiguous},{} end
C_Map.GetMapGroupID=function() return 45 end
assert(not addon:CheckArrival(10,.6,.5) and addon.errands:Get(ambiguous.id),
  'grouped multi-floor coordinates must not delete an unqualified target')
C_Map.GetMapGroupID=function() return nil end
C_Map.GetMapInfo=function() return {mapType=4} end
assert(not addon:CheckArrival(10,.6,.5) and addon.errands:Get(ambiguous.id),
  'dungeon map without reliable floor evidence remains queued')
C_Map.GetMapInfo=function() return nil end
assert(not addon:CheckArrival(10,.6,.5) and addon.errands:Get(ambiguous.id),
  'unknown map type remains queued')
local savedFloor=addon.errands:Add({name='Saved floor',mapID=10,x=.6,y=.5,floor=2})
addon.errands:Reorder(savedFloor.id,1) -- Display position, not a hidden selection, owns navigation.
addon.Plan=function(self)
 return self.route:Plan(self.errands:All(),10,.6,.5,true,nil,nil,1000,1000)
end
addon.trails.NativeSample=function() return {uiMapID=10,floor=1} end
assert(not addon:CheckArrival(10,.6,.5) and addon.errands:Get(savedFloor.id),
  'saved floor survives real route and rejects different-floor arrival')
addon.trails.NativeSample=function() return {uiMapID=10,floor=2} end
assert(addon:CheckArrival(10,.6,.5) and not addon.errands:Get(savedFloor.id),
  'saved floor survives route and permits matching-floor 2-yard arrival')
print('native navigation and queue tests passed')
