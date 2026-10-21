-- Candidate flight stages require positions, not a recorded ride or opt-in recording.
local addon={db={character='A',data={characters={A={transport={enabled=false}}}}},
 transportCatalog={ServiceCandidatesOnMap=function(_,map)
  if map==10 then return {{name='Start',nodeID=1,mapID=10,x=.1,y=0,source='native-taxi-map'}} end
  if map==20 then return {{name='Stop',nodeID=2,mapID=20,x=.8,y=0,source='native-taxi-map'}} end
  return {}
 end}}
UnitOnTaxi=function() return false end
assert(loadfile('Data/TaxiAdvice.lua'))('ErrandMaster',addon)
local taxi=addon.taxiAdvice
local function projection(_,x,y) return 1,y*1000,x*1000 end
local target={mapID=20,x=.9,y=0}
local advice=taxi:Recommend(10,0,0,target,projection)
assert(advice and advice.source=='candidate-taxi' and advice.connectionStatus=='unconfirmed' and
 advice.rideEligibility=='unknown' and advice.originNode=='Start' and advice.nodeName=='Stop' and
 advice.savedYards==700 and advice.destinationMapID==20,
 'native nodes supply an unconfirmed candidate without recordings or transport consent')
assert(not taxi:Recommend(10,0,0,{mapID=20,x=.6,y=0},projection),'strict 600-yard gate')
assert(not taxi:Recommend(10,0,0,{mapID=20,x=.5,y=0},projection),'nearby destination')
addon.transportCatalog.ServiceCandidatesOnMap=function(_,map)
 if map==10 then return {{name='Start',mapID=10,x=.7,y=0}} end
 return {{name='Stop',mapID=20,x=.1,y=0}}
end
assert(not taxi:Recommend(10,0,0,target,projection),'longer combined walking legs')
addon.transportCatalog.ServiceCandidatesOnMap=function(_,map)
 if map==10 then return {{name='Start',mapID=10,x=.1,y=0}} end
 return {{name='Stop',mapID=20,x=.1,y=0}}
end
assert(not taxi:Recommend(10,0,0,target,projection),'equal combined walking legs')
addon.transportCatalog.ServiceCandidatesOnMap=function(_,map)
 if map==10 then return {{name='Start',mapID=10,x=.1,y=0,faction='Horde'}} end
 return {{name='Stop',mapID=20,x=.8,y=0}}
end
assert(not taxi:Recommend(10,0,0,target,projection),'opposing faction must not be suggested')
addon.transportCatalog.ServiceCandidatesOnMap=function() return {} end
addon.transportCatalog.NpcCandidatesOnMap=function(_,map)
 if map==10 then return {{name='Provider Start',mapID=10,x=.1,y=0,source='questiedb-forever'}} end
 return {{name='Provider Stop',mapID=20,x=.8,y=0,source='questiedb-forever'}}
end
assert(taxi:Recommend(10,0,0,target,projection).source=='candidate-taxi',
 'provider positions can supply candidates if native positions are unavailable')
addon.transportCatalog.NpcCandidatesOnMap=nil
addon.transportCatalog.ServiceCandidatesOnMap=function(_,map)
 if map==10 then return {{name='Start',mapID=10,x=.1,y=0}} end
 return {{name='Stop',mapID=20,x=.8,y=0}}
end
taxi.legs={one={character='A',source='observed-taxi',originNode='Recorded Start',
 nodeName='Recorded Stop',originMapID=10,originX=.1,originY=0,
 destinationMapID=20,destinationX=.83,destinationY=0}}
taxi.bucket=addon.db.data.characters.A.transport
taxi.bucket.enabled=false
local observed=taxi:Recommend(10,0,0,target,projection)
assert(observed.source=='candidate-taxi' and observed.nodeName=='Stop',
 'recording disabled does not turn a remembered ride into a verified current connection')
taxi.bucket.enabled=true
local verified=taxi:Recommend(10,0,0,target,projection)
assert(verified.source=='observed-taxi' and verified.connectionStatus=='observed' and
 verified.nodeName=='Recorded Stop' and verified.destinationX==.83,
 'observed actual landing remains authoritative when selected')
addon.transportCatalog.ServiceCandidatesOnMap=function(_,map)
 if map==10 then return {{name='Recorded Start',mapID=10,x=.1,y=0}} end
 return {{name='Recorded Stop',mapID=20,x=.88,y=0}}
end
verified=taxi:Recommend(10,0,0,target,projection)
assert(verified.source=='observed-taxi' and verified.destinationX==.83,
 'a more optimistic native marker must not replace actual landing for the same ride')
print('candidate transport advice and observed landing passed')
