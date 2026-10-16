-- v0.6 opt-in walk evidence. No observation may invent a traversable edge.
local saved={nodes={},edges={},enabled=false}
local addon={db={data={settings={trailRecording=false}},
  TrailBucket=function() return saved end}}
assert(loadfile('Data/TrailRecorder.lua'))('ErrandMaster',addon)
local trails=addon.trails
local function sample(t,x,y,wx,wy,wz,floor,mode)
  return {time=t,uiMapID=10,worldMapID=123,floor=floor or 1,
    x=x,y=y,wx=wx,wy=wy,wz=wz,mode=mode or 'ground',level=20}
end
assert(not trails:Observe(sample(1,.1,.1,100,100,10)))
assert(#trails.nodes==0 and #trails.edges==0)
assert(trails:SetEnabled(true))
assert(trails.nodes==saved.nodes and trails.edges==saved.edges)
assert(trails:Observe(sample(1,.1,.1,100,100,10)))
assert(trails:Observe(sample(3,.101,.1,105,100,10)))
assert(#trails.nodes==2 and #trails.edges==1)
assert(trails.edges[1].yards==5 and trails.edges[1].source=='observed-walk')
assert(not trails:Observe(sample(4,.101,.1,105,100,10)))
assert(#trails.nodes==2)
assert(trails:Observe(sample(5,.9,.9,1000,1000,10)))
assert(#trails.edges==1, 'teleport-sized jump must break continuity')
assert(trails:Observe(sample(7,.901,.9,1005,1000,10)))
assert(#trails.edges==2 and trails.edges[2].a~=trails.edges[1].b)
assert(trails:Observe(sample(9,.901,.9,1005,1000,30,2)))
assert(#trails.edges==2, 'floor transition is not inferred from a 2D overlap')
assert(not trails:Observe(sample(10,.902,.9,1010,1000,30,2,'flight')))
assert(trails:Observe(sample(12,.903,.9,1015,1000,30,2)))
assert(#trails.edges==2, 'flight breaks the walk trail')
assert(trails:SetEnabled(false))
assert(saved.enabled==false)
assert(not trails:Observe(sample(14,.904,.9,1020,1000,30,2)))
local secret={}
issecretvalue=function(value) return value==secret end
assert(not trails:Observe(secret))
issecretvalue=nil
-- Native sample must distinguish world-map identity from UI-map identity and fail closed.
assert(trails:SetEnabled(true))
assert(trails:NativeSample()==nil)
InCombatLockdown=function() return false end
GetTime=function() return 20 end
UnitPosition=function() return 200,300,40,123 end
UnitLevel=function() return 20 end
GetUnitSpeed=function() return 7 end
IsFlying=function() return false end
UnitOnTaxi=function() return false end
IsSwimming=function() return false end
UnitInVehicle=function() return false end
C_Map={GetBestMapForUnit=function() return 10 end,
  GetMapLevels=function(id) assert(id==10); return 30,40 end,
  GetPlayerMapPosition=function()
    return {GetXY=function() return .2,.3 end}
  end}
local native=trails:NativeSample()
assert(native and native.uiMapID==10 and native.worldMapID==123 and
  native.wz==40 and native.minLevel==30)
assert(trails:Observe(native))
GetTime=function() return 22 end
UnitPosition=function() return 205,300,40,123 end
C_Map.GetPlayerMapPosition=function() return {GetXY=function() return .201,.3 end} end
assert(trails:ObserveNative())
assert(saved.edges[#saved.edges].minLevel==30,
  'suggested map level is retained only as a coarse path preference')
InCombatLockdown=function() return true end
assert(trails:NativeSample()==nil and not trails:ObserveNative(),
  'combat never contributes movement evidence')
InCombatLockdown=function() return false end
IsFlying=function() return true end
assert(trails:NativeSample()==nil and not trails:ObserveNative())
local count=#saved.nodes
assert(loadfile('Data/TrailRecorder.lua'))('ErrandMaster',addon)
assert(addon.trails:Bind() and #addon.trails.nodes==count and #saved.edges==3,
  'observed nodes and edges survive module reload without a fake connecting edge')
addon.db.character='Another-Realm'
assert(not addon.trails:IsEnabled() and not addon.trails:Observe(sample(25,.3,.3,210,300,40,0)),
  'character changes cannot reuse the previous character recording consent')
assert(not addon.trails:Clear() and #saved.nodes==count,
  'another character cannot clear a prior character trail through stale binding')
addon.db.character=nil
saved.nodes.unexpected={id='hidden'}
saved.edges.unexpected={a='hidden',b='other'}
assert(addon.trails:Clear() and next(saved.nodes)==nil and next(saved.edges)==nil and
  saved.enabled==false and not addon.trails:IsEnabled(),
  'clear stops recording and removes every bound key, including unexpected saved entries')
assert(addon.trails:SetEnabled(true))
for i=1,400 do saved.nodes[i]={id='trail-'..i} end
assert(not addon.trails:Observe(sample(30,.4,.4,220,300,40,0)) and
  #saved.nodes==400 and not addon.trails:IsEnabled(),
  'full storage must stop recording visibly rather than retry forever')
print('opt-in trail continuity, floor, flight and native-guard tests passed')
