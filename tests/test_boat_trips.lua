-- Standalone Lua 5.1 contract; no imported endpoints or simulated zone-change lifecycle.
local addon={}
local clock=100
GetTime=function() return clock end
assert(loadfile('Data/BoatTrips.lua'))('ErrandMaster',addon)
local boat=assert(addon.boatTrips)
local bucket={enabled=true,legs={}}
assert(boat:Bind(bucket,'Pilot-Realm','1:120000:11000'))
assert(boat:Begin(10,.2,.2))
clock=145
assert(boat:Arrive(20,.8,.8))
assert(#bucket.legs==1)
local leg=bucket.legs[1]
assert(leg.originMapID==10 and leg.originX==.2 and leg.originY==.2 and
  leg.destinationMapID==20 and leg.destinationX==.8 and leg.destinationY==.8 and
  leg.seconds==45 and leg.samples==1 and leg.source=='user-confirmed-boat' and
  leg.character=='Pilot-Realm' and bucket.build=='1:120000:11000')
-- Native projection stub: two map IDs share one comparable world instance.
local function project(map,x,y)
  if map==10 or map==20 then return 0,y*1000,x*1000 end
end
local target={mapID=20,x=.9,y=.8}
local hint=assert(boat:Recommend(10,.05,.2,target,project))
assert(hint.kind=='boat' and hint.mapID==10 and hint.x==.2 and
  hint.destinationMapID==20 and hint.destinationX==.8 and
  hint.source=='user-confirmed-boat' and hint.estimate=='walking-distance-reduction' and
  hint.savedYards>100 and hint.directYards>hint.viaYards and
  not hint.totalSeconds and not hint.savedSeconds and not hint.waitSeconds,
  'only walking-distance reduction is inferred, not speed or wait')
assert(not boat:Recommend(10,.05,.2,{mapID=20,x=.1,y=.8},project),
  'landing must be near this particular target')
assert(not boat:Recommend(20,.8,.8,{mapID=10,x=.2,y=.2},project),
  'observation never implies the reverse direction')
local crossing=assert(boat:Recommend(10,.05,.2,target,function(map,x,y)
  return map==10 and 0 or 1,y*1000,x*1000
end), 'a recorded journey connects different worlds without a fictitious direct distance')
assert(crossing.estimate=='recorded-cross-world-connection' and crossing.viaYards==250 and
  not crossing.directYards and not crossing.savedYards and crossing.destinationX==.8)
local adjacent=assert(boat:Recommend(11,.05,.2,{mapID=21,x=.9,y=.8},function(map,x,y)
  return (map==10 or map==11) and 0 or 1,y*1000,x*1000
end), 'adjacent maps in the same endpoint worlds remain comparable')
assert(adjacent.mapID==10 and adjacent.destinationMapID==20)
-- A second observed destination is preferred only when its real landing helps this target.
clock=200
assert(boat:Begin(10,.2,.2))
clock=250
assert(boat:Arrive(20,.85,.8))
local choice=assert(boat:Recommend(10,.05,.2,target,project))
assert(choice.x==.2 and choice.destinationX==.85,
  'choose the observed landing that reduces approach plus final walking distance')
assert(not boat:Recommend(10,.99,.8,target,project),
  'proximity to target cannot justify a distant boat approach')
-- An explicit Cancel or invalid destination consumes the ticket; no zone changes are observed.
clock=300
assert(boat:Begin(10,.2,.2))
boat:Cancel()
clock=340
assert(not boat:Arrive(20,.8,.8) and #bucket.legs==2)
assert(not boat:Begin(0/0,.2,.2) and not boat:Begin(10,1/0,.2))
assert(not boat:Begin(10,-.1,.2) and not boat:Begin(0,.2,.2))
assert(boat:Begin(10,.2,.2))
assert(not boat:Arrive(20,1/0,.8) and #bucket.legs==2)
assert(not boat:Arrive(20,.8,.8), 'failed arrival cannot be retried as a new trip')
assert(boat:Begin(10,.2,.2))
clock=299
assert(not boat:Arrive(20,.8,.8), 'negative duration rejected')
clock=400
assert(boat:Begin(10,.2,.2))
clock=440
assert(boat:Arrive(20,.8,.8))
assert(#bucket.legs==2 and bucket.legs[1].samples==2 and bucket.legs[1].seconds==42.5,
  'same directed endpoints aggregate bounded ride-only durations')
local first=bucket.legs[1]
assert(not first.waitSeconds and not first.totalSeconds,
  'boarding command starts the travel clock; no inferred waiting time')
-- Consent is separate from ground trails and must be checked at both ends.
bucket.enabled=false
assert(not boat:Begin(10,.2,.2) and not boat:Recommend(10,.05,.2,target,project))
bucket.enabled=true
assert(boat:Begin(10,.2,.2))
bucket.enabled=false
clock=480
assert(not boat:Arrive(20,.8,.8) and #bucket.legs==2)
bucket.enabled=true
assert(not boat:Arrive(20,.8,.8))
-- Bound data belongs to one character and build; never consume another identity's records.
assert(not boat:Bind({enabled=true,build='other-build',legs=bucket.legs},'Pilot-Realm','1:120000:11000'))
assert(not boat:Recommend(10,.05,.2,target,project))
assert(not boat:Bind({enabled=true,build='1:120000:11000',legs=bucket.legs},'Other-Realm','1:120000:11000'))
assert(boat:Bind(bucket,'Pilot-Realm','1:120000:11000'))
assert(boat:Recommend(10,.05,.2,target,project))
local bad={enabled=true,build='1:120000:11000',legs={[1]=first,[3]=first}}
assert(not boat:Bind(bad,'Pilot-Realm','1:120000:11000'), 'sparse saved array rejected')
assert(not boat:Recommend(10,.05,.2,target,project))
bad.legs={first,{originMapID=10,originX=1/0,originY=.2,destinationMapID=20,
  destinationX=.8,destinationY=.8,seconds=30,samples=1,source='user-confirmed-boat',character='Pilot-Realm'}}
assert(not boat:Bind(bad,'Pilot-Realm','1:120000:11000'), 'invalid saved coordinates rejected')
bad.legs={first}
bad.legs[2]=first
assert(not boat:Bind(bad,'Pilot-Realm','1:120000:11000'), 'duplicate endpoints rejected')
assert(not boat:Bind({enabled=true,build='1:120000:11000',legs=setmetatable({first},{})},
  'Pilot-Realm','1:120000:11000'), 'metatable in persisted array rejected')
assert(not boat:Bind({enabled=true,legs={first}},'Pilot-Realm','1:120000:11000'),
  'unscoped persisted measurements are not reusable across builds')
assert(not boat:Bind({enabled=true,build='1:120000:11000',legs={first}},
  'Pilot-Realm','1:120000:11000'), 'unowned persisted measurements are not reusable')
assert(boat:Bind(bucket,'Pilot-Realm','1:120000:11000'))
-- Reload from persisted data (not an in-memory cache).
local reloaded={}
assert(loadfile('Data/BoatTrips.lua'))('ErrandMaster',reloaded)
assert(reloaded.boatTrips:Bind(bucket,'Pilot-Realm','1:120000:11000'))
assert(reloaded.boatTrips:Recommend(10,.05,.2,target,project).destinationX==.85)
-- Bounded storage refuses a novel leg without changing existing records.
local full={enabled=true,build='1:120000:11000',character='Pilot-Realm',legs={}}
for i=1,64 do
  full.legs[i]={originMapID=10,originX=i/100,originY=.2,
    destinationMapID=20,destinationX=i/100,destinationY=.8,
    seconds=30,samples=1,source='user-confirmed-boat',character='Pilot-Realm'}
end
assert(boat:Bind(full,'Pilot-Realm','1:120000:11000'))
assert(boat:Begin(10,.7,.3))
clock=520
assert(not boat:Arrive(20,.7,.8) and #full.legs==64)
full.legs[65]=full.legs[1]
assert(not boat:Bind(full,'Pilot-Realm','1:120000:11000'), 'oversized saved array rejected')
local empty={enabled=true,legs={}}
assert(boat:Bind(empty,'Pilot-Realm','1:120000:11000'))
GetTime=nil
assert(not boat:Begin(10,.2,.2), 'no clock means no measured duration')
GetTime=function() return clock end
assert(boat:Begin(10,.2,.2))
clock=clock+86401
assert(not boat:Arrive(20,.8,.8) and #empty.legs==0,
  'implausible elapsed travel rejected')
print('boat observations, gating, persisted validation and recommendations passed')
