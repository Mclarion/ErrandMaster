-- Lua 5.1 end-to-end: explicit native-position boat journey into transient plan.
local addon={}
local function load(path) assert(loadfile(path))('ErrandMaster',addon) end
local frame={scripts={}}
function frame:RegisterEvent() end
function frame:UnregisterEvent() end
function frame:SetScript(name,fn) self.scripts[name]=fn end
CreateFrame=function() return frame end
local clock=100
GetTime=function() return clock end
WOW_PROJECT_ID=1
GetBuildInfo=function() return 'test','120000','test',11000 end
UnitFullName=function() return 'Pilot','Realm' end
local map,x,y=10,.2,.2
C_Map={GetBestMapForUnit=function() return map end,
 GetPlayerMapPosition=function() return {GetXY=function() return x,y end} end,
 GetMapWorldSize=function() return 1000,1000 end,
 GetMapInfo=function() return {mapType=3} end,GetMapGroupID=function() return nil end}
UnitOnTaxi=function() return false end
local messages={}
DEFAULT_CHAT_FRAME={AddMessage=function(_,text) messages[#messages+1]=text end}
load('Core/Database.lua')
addon.db:Initialize('Pilot-Realm')
load('Data/TaxiAdvice.lua')
assert(addon.taxiAdvice:Bind())
load('Data/BoatTrips.lua')
local target={id='em-1',name='Goal',category='Vendor',mapID=20,x=.9,y=.8,
 manualPosition=3,sequenceRank=3}
local saved={[target.id]=target};local deletes=0
addon.errands={revision=0,All=function() return {target} end,
 Get=function(_,id) return saved[id] end,
 Delete=function(_,id) deletes=deletes+1;saved[id]=nil end}
addon.locations={All=function() return {} end}
addon.quests={OnMap=function() return {} end,Invalidate=function() end}
addon.route={Plan=function() if map==10 then return {},{target} end return {target},{} end,
 DisplayOrder=function(_,ordered,deferred)
  local result={};for _,item in ipairs(ordered) do result[#result+1]=item end
  for _,item in ipairs(deferred) do result[#result+1]=item end
  return result
 end}
addon.navigation={WorldPosition=function(_,m,a,b) return 1,b*1000,a*1000 end,
 Next=function() end,Clear=function() end}
addon.ui={Refresh=function() end};addon.worldMap={Refresh=function() end}
addon.destinations={Refresh=function() end}
load('Core/Init.lua')
assert(addon:BindBoat())
local bucket=assert(addon.db:BoatBucket())
assert(bucket==addon.db.data.characters['Pilot-Realm'].boat)
assert(addon.boatTrips.bucket==bucket and addon.boatTrips.scope==addon.taxiAdvice.scope,
 'boat storage bound after flight scope is known')
assert(not addon:Plan()[1], 'unobserved boat cannot create a stage')
addon:Command('boat start')
assert(addon.boatTrips.pending and addon.boatTrips.pending.x==.2 and
 addon.boatTrips.pending.map==10,'start samples actual boarding position')
assert(messages[#messages]:find('board',1,true))
map=20;x=.8;y=.8;clock=140
assert(not addon:CheckArrival(map,x,y) and saved[target.id],
 'pending ride cannot consume destination near its actual landing')
assert(not addon:MovementTick() and saved[target.id],
 'movement during boat journey cannot auto-complete target')
addon:Command('boat arrive')
assert(#bucket.legs==1 and bucket.legs[1].originX==.2 and
 bucket.legs[1].destinationX==.8 and bucket.legs[1].destinationMapID==20 and
 bucket.legs[1].seconds==40 and deletes==0)
assert(not addon.boatTrips.pending and saved[target.id])
assert(messages[#messages]:find('disembark',1,true))
local onward=addon:Plan()
assert(onward[1]==target,'arrival refreshes onward original, no boat stage at landing')
-- Rebind from persisted observations (not a session-only cached recommendation).
local prior=bucket.legs[1]
load('Data/BoatTrips.lua')
assert(addon.boatTrips:Bind(bucket,addon.db.character,addon.taxiAdvice.scope))
map=10;x=.05;y=.2;addon:Refresh()
local ordered,deferred=addon:Plan()
assert(ordered[1] and ordered[1].category=='Boat' and
 ordered[1].transitForId==target.id and ordered[1].transitSource=='user-confirmed-boat' and
 ordered[1].boatAdvice and ordered[1].manualPosition==3 and
 deferred[1]==target,'reloaded directed evidence inserts only transient first stage')
assert(addon:ActiveTarget(ordered,deferred).transitForId==target.id)
-- A flight with a larger comparable reduction wins; no queue identity changes.
local taxiRecommend=addon.taxiAdvice.Recommend
addon.taxiAdvice.Recommend=function() return {kind='taxi',source='observed-taxi',
 savedYards=1000,originNode='Start',nodeName='End',mapID=10,x=.2,y=.2} end
addon:Refresh();ordered=addon:Plan()
assert(ordered[1].category=='Flight Master' and ordered[1].transitForId==target.id and
 ordered[1].transitSource=='observed-taxi')
addon.taxiAdvice.Recommend=taxiRecommend
addon:Refresh()
-- A directed cross-world observation has local approach/onward yards but no
-- meaningful inter-world direct-distance or purported time advantage.
local worldPosition=addon.navigation.WorldPosition
addon.navigation.WorldPosition=function(_,m,a,b)
 return m==10 and 1 or 2,b*1000,a*1000 end
ordered,deferred=addon:Plan()
assert(ordered[1] and ordered[1].category=='Boat' and
 ordered[1].boatAdvice.estimate=='recorded-cross-world-connection' and
 ordered[1].boatAdvice.savedYards==nil and ordered[1].boatAdvice.directYards==nil and
 deferred[1]==target,'cross-world boarding hint has no fabricated improvement')
addon:NavigateNext()
assert(messages[#messages-1]:find('improvement unknown',1,true) or
 messages[#messages]:find('improvement unknown',1,true),
 'cross-world command does not advertise a saved time or distance')
addon.navigation.WorldPosition=worldPosition;addon:Refresh()
x=.2;y=.2
assert(addon:CheckArrival(10,x,y) and saved[target.id] and deletes==0,
 'boarding point clears only transient stage, not saved errand')
ordered,deferred=addon:Plan()
assert(#ordered==0 and deferred[1]==target)
addon:Command('boat start')
assert(addon.boatTrips.pending)
ordered,deferred=addon:Plan()
assert(#ordered==0 and deferred[1]==target,'no transit recommendations during pending ride')
addon:Command('boat status')
assert(messages[#messages]:find('pending',1,true))
addon:Command('boat off')
assert(bucket.enabled==false and not addon.boatTrips.pending)
addon:Command('boat on')
assert(bucket.enabled==true and not addon.boatTrips.pending)
addon:Command('boat arrive')
assert(#bucket.legs==1,'off cancels ticket; arrive cannot invent endpoint')
addon:Command('boat clear')
assert(bucket.legs[1]==prior,'clear requires confirmation')
clock=171;addon:Command('boat confirm')
assert(bucket.legs[1]==prior,'expired confirmation retains recorded evidence')
addon:Command('boat clear')
clock=180;addon:Command('boat confirm')
assert(#bucket.legs==0 and bucket.enabled,'confirmed clear only boat evidence')
addon:Command('boat confirm')
assert(#bucket.legs==0,'confirmation is single use')
bucket.legs[1]=prior;bucket.build='different-build';bucket.character='Pilot-Realm'
addon.boatTrips:Cancel()
assert(not addon.boatTrips:Bind(bucket,addon.db.character,addon.taxiAdvice.scope))
local untouched=addon.db:BoatBucket()
assert(untouched==bucket and untouched.legs[1]==prior and bucket.build=='different-build',
 'build mismatch preserves existing saved boat evidence')
assert(not addon.boatTrips:Recommend(10,.05,.2,target,function(m,a,b)
 return addon.navigation:WorldPosition(m,a,b) end))
addon:Command('boat clear');addon:Command('boat confirm')
assert(bucket.legs[1]==prior and bucket.build=='different-build',
 'mismatched build cannot arm or confirm destructive reset')
print('boat integration lifecycle passed')
