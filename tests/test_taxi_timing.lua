-- Taxi lifecycle: only explicitly selected rides with coherent world samples persist.
local addon={db={character='A',data={characters={A={}}}}}
local clock=100
GetTime=function() return clock end
WOW_PROJECT_ID=1
GetBuildInfo=function() return '11','123','date',67890 end
UnitOnTaxi=function() return true end
local store={enabled=true,legs={}}
addon.db.data.characters.A.transport=store
addon.db.TransportBucket=function() return store end
addon.navigation={WorldPosition=function(_,map,x,y)
  if map==10 or map==20 then return 1,y*1000,x*1000 end
end}
addon.transportCatalog={ServiceCandidatesOnMap=function(_,map)
  if map==20 then return {{mapID=20,x=.8,y=.1,name='Arrival Master'}} end
  return {}
end}
NumTaxiNodes=function() return 2 end
TaxiNodeGetType=function(i) return i==1 and 'CURRENT' or 'REACHABLE' end
TaxiNodeName=function(i) return i==1 and 'Start' or 'Arrival' end
assert(loadfile('Data/TaxiAdvice.lua'))('ErrandMaster',addon)
local taxi=addon.taxiAdvice
assert(taxi:Bind())
local function begin()
  assert(taxi:Capture())
  taxi:CaptureOrigin(10,.1,.1)
  taxi:SelectedNode(2,10,.1,.1)
  taxi:Depart()
  assert(taxi.pending)
  assert(taxi:Sample(10,.1,.1,function(m,x,y) return addon.navigation:WorldPosition(m,x,y) end))
end
begin()
clock=105;assert(taxi:Sample(10,.4,.1,function(m,x,y) return addon.navigation:WorldPosition(m,x,y) end))
clock=110;assert(taxi:Sample(20,.8,.1,function(m,x,y) return addon.navigation:WorldPosition(m,x,y) end))
assert(taxi:Landed(20,.8,.1) and #store.legs==1)
assert(store.legs[1].seconds==10 and store.legs[1].distanceYards==700)
local fastest=store.legs[1]
clock=120;begin();clock=130;taxi:Sample(10,.4,.1,function(m,x,y) return addon.navigation:WorldPosition(m,x,y) end)
clock=140;taxi:Sample(20,.8,.1,function(m,x,y) return addon.navigation:WorldPosition(m,x,y) end)
assert(taxi:Landed(20,.8,.1))
assert(store.legs[1]==fastest and store.legs[1].seconds==10 and store.legs[1].distanceYards==700,
  'longer valid ride must not overwrite fastest sample or its distance/endpoints')
clock=150;begin();clock=154;taxi:Sample(10,.4,.1,function(m,x,y) return addon.navigation:WorldPosition(m,x,y) end)
clock=158;taxi:Sample(20,.8,.1,function(m,x,y) return addon.navigation:WorldPosition(m,x,y) end)
assert(taxi:Landed(20,.8,.1) and store.legs[1].seconds==8 and store.legs[1].distanceYards==700)
clock=160;begin();clock=165;taxi:Sample(20,.5,.1,function(m,x,y) return addon.navigation:WorldPosition(m,x,y) end)
assert(not taxi:Landed(20,.5,.1) and store.legs[1].seconds==8,'remote dismount invalid')
clock=170;begin();clock=171
assert(not taxi:Sample(20,.8,.1,function(m,x,y) return addon.navigation:WorldPosition(m,x,y) end),
  'discontinuous/teleport displacement invalidates ride')
assert(not taxi:Landed(20,.8,.1) and store.legs[1].seconds==8)
clock=180;begin();clock=181
assert(not taxi:Sample(20,nil,.1,function(m,x,y) return addon.navigation:WorldPosition(m,x,y) end))
assert(not taxi.pending,'unreadable position cancels')
clock=190;begin();clock=195
assert(taxi:Sample(10,.1,.1,function(m,x,y) return addon.navigation:WorldPosition(m,x,y) end),
  'brief stationary pause while taxi remains active is valid')
clock=200;assert(taxi:Sample(10,.4,.1,function(m,x,y) return addon.navigation:WorldPosition(m,x,y) end))
clock=205;assert(taxi:Sample(20,.8,.1,function(m,x,y) return addon.navigation:WorldPosition(m,x,y) end))
assert(taxi:Landed(20,.81,.1) and store.legs[1].seconds==8,
  'arrival within 40 yards includes final sampled segment, but slower ride is not retained')
clock=210;begin();clock=211
assert(not taxi:Sample(20,.1,.1,function() return 2,100,100 end) and not taxi.pending,
  'cross-world projection discontinuity invalidates timing and distance')
clock=220;begin();taxi:SetEnabled(false)
assert(not taxi.pending and not taxi:Landed(20,.8,.1))
assert(loadfile('Data/TaxiAdvice.lua'))('ErrandMaster',addon)
taxi=addon.taxiAdvice;assert(taxi:Bind() and not taxi.pending and taxi.legs and next(taxi.legs))
assert(store.legs[1].seconds==8 and store.legs[1].distanceYards==700)
print('taxi timing and distance lifecycle passed')
