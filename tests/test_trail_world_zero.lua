-- Regression: world instance zero is valid, distinct from a missing identity.
local saved={nodes={},edges={},enabled=false}
local addon={db={data={settings={}},TrailBucket=function() return saved end}}
assert(loadfile('Data/TrailRecorder.lua'))('ErrandMaster',addon)
assert(loadfile('Routing/WalkGraph.lua'))('ErrandMaster',addon)
local now,x,wx,world=1,.2,100,0
InCombatLockdown=function() return false end
GetTime=function() return now end
UnitPosition=function() return wx,200,30,world end
UnitLevel=function() return 20 end
GetUnitSpeed=function() return 7 end
IsFlying=function() return false end
UnitOnTaxi=function() return false end
IsSwimming=function() return false end
UnitInVehicle=function() return false end
C_Map={GetBestMapForUnit=function() return 1432 end,
 GetPlayerMapPosition=function() return {GetXY=function() return x,.3 end} end}
local trails=addon.trails
assert(trails:SetEnabled(true))
local first=trails:NativeSample()
assert(first and first.worldMapID==0,'native world instance zero must not be rejected')
assert(trails:Observe(first),'clean sample must preserve instance zero')
now,x,wx=2,.201,105
assert(trails:ObserveNative())
assert(#saved.nodes==2 and #saved.edges==1,'continuous instance-zero samples must create evidence')
local route=addon.walkGraph:Plan(saved.nodes,saved.edges,saved.nodes[1],saved.nodes[2],20)
assert(route.status=='known-route' and route.yards==5,'graph must accept recorded instance-zero evidence')
world=-1
assert(trails:NativeSample()==nil,'negative world instance remains invalid')
world=nil
assert(trails:NativeSample()==nil,'missing world instance remains invalid')
world=1; now,x,wx=3,.202,110
assert(trails:ObserveNative())
assert(#saved.edges==1,'different world instances must not be bridged')
print('world-instance-zero native sampling, recording and graph regression passed')
