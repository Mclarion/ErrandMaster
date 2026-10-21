-- Flight insertion uses the user's strict >600 yard gate and total walking legs.
local addon={db={character='A'},trails={IsEnabled=function() return true end}}
UnitOnTaxi=function() return false end
assert(loadfile('Data/TaxiAdvice.lua'))('ErrandMaster',addon)
local taxi=addon.taxiAdvice
local leg={originMapID=10,originX=.1,originY=0,destinationMapID=20,
 destinationX=.5,destinationY=0,character='A',source='observed-taxi',
 originNode='Start',nodeName='Stop'}
taxi.legs={one=leg}
local function projection(map,x,y) return 0,y*1000,x*1000 end
local function recommend(x) return taxi:Recommend(10,0,0,{mapID=20,x=x,y=0},projection) end
assert(not recommend(.599),'below 600 yards never inserts a flight')
assert(not recommend(.6),'exactly 600 yards never inserts a flight')
assert(recommend(.601),'above 600 yards may insert a shorter known flight')
leg.destinationX=.11
assert(recommend(.7),'even a small positive walking reduction qualifies; no old 100-yard/15% gate')
leg.destinationX=.1
assert(not recommend(.7),'equal walking distance is not an improvement')
leg.destinationX=.09
assert(not recommend(.7),'longer combined walking distance cannot insert a flight')
leg.destinationX=.5
local adjacent=taxi:Recommend(11,0,0,{mapID=21,x=.7,y=0},projection)
assert(adjacent and adjacent.mapID==10 and adjacent.destinationMapID==20,
 'actual endpoint maps may be adjacent to the player and target maps')
taxi.legs={}
assert(not recommend(.7),'positions alone do not establish a known usable connection')
print('flight strict 600-yard gate, combined walking distance and adjacent endpoint maps passed')
