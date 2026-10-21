-- Flight recommendations require live reachability, an observed duration and
-- independently evidenced walking costs; none imply automatic taxi interaction.
local addon={trails={IsEnabled=function() return true end}}
local clock=1000
GetTime=function() return clock end
C_Map={GetMapInfo=function(id) return {name=({[15]='Ironforge',[16]='Loch Modan'})[id]} end}
NumTaxiNodes=function() return 2 end
TaxiNodeGetType=function(i) return i==1 and 'CURRENT' or 'REACHABLE' end
TaxiNodeName=function(i) return i==1 and 'Thelsamar' or 'Ironforge' end
assert(loadfile('Data/TaxiAdvice.lua'))('ErrandMaster',addon)
local taxi=addon.taxiAdvice
assert(taxi:Capture())
local costs={direct={seconds=1200,source='observed-walk'},
  landing={seconds=180,source='observed-walk'}}
assert(not taxi:Advise(15,costs), 'reachability and geometry alone do not establish benefit')
local ticket=assert(taxi:BeginFlight(16,15), 'departing from the current live taxi node')
taxi:Clear() -- native TAXIMAP_CLOSED precedes arrival; do not discard ticket
clock=1360
assert(not taxi:CompleteFlight(ticket,15,{arrivalObserved=true}), 'unobserved taxi ride is not measured')
assert(taxi:CompleteFlight(ticket,15,{taxiObserved=true,arrivalObserved=true}))
assert(not next(taxi.legs or {}), 'a legacy arrival event without coordinates is not endpoint evidence')
assert(taxi:Capture())
local advice=assert(taxi:Advise(15,costs))
assert(advice.kind=='taxi' and advice.nodeName=='Ironforge' and
  advice.timing=='event-sampled' and advice.originNode=='Thelsamar' and advice.flightSeconds==360 and
  advice.totalSeconds==540 and advice.savedSeconds==660 and
  advice.steps[1].kind=='flight' and advice.steps[2].kind=='walk' and
  advice.steps[2].seconds==180,
  'only measured connection and measured connector beat measured direct route')
assert(not taxi:Advise(15,{direct={seconds=450,source='observed-walk'},landing=costs.landing}))
assert(not taxi:Advise(15,{direct={seconds=1200,source='straight-line'},landing=costs.landing}))
assert(not taxi:Advise(15,{direct=costs.direct,landing={seconds=180,source='geometric'}}))
assert(not taxi:Advise(16,costs), 'not reachable by this master')
TaxiNodeGetType=function() return 'DISTANT' end
assert(taxi:Capture() and not taxi:Advise(15,costs), 'live connection revoked')
TaxiNodeGetType=function(i) return i==1 and 'CURRENT' or 'REACHABLE' end
assert(taxi:Capture() and taxi:Advise(15,costs), 'observed ride may be reused at same master')
addon.trails.IsEnabled=function() return false end
assert(not taxi:BeginFlight(16,15) and not taxi:Advise(15,costs),
  'revoked observation consent disables learning and personalized advice')
addon.trails.IsEnabled=function() return true end
GetTime=nil
assert(not taxi:BeginFlight(16,15), 'no native clock means no measured flight time')
assert(not taxi:Advise(15,{direct={seconds=1/0,source='observed-walk'},landing=costs.landing}))
assert(not taxi:Advise(15,{direct=costs.direct,landing={seconds=0/0,source='observed-walk'}}))
taxi:Clear()
NumTaxiNodes=nil; TaxiNodeGetType=nil; TaxiNodeName=nil
FlightMapFrame={GetMapID=function() return 13 end}
C_TaxiMap={GetAllTaxiNodes=function() return {
  {name='Thelsamar',state=0},{name='Ironforge',state=1},
  {name='Unknown Town',state=2}} end}
assert(taxi:Capture() and taxi.current=='Thelsamar' and taxi:ForMap(15)=='Ironforge',
  'modern taxi frame supplies only current and reachable native nodes')
assert(not taxi:SelectedNode(9,16,.2,.3),'modern nodes without slotIndex cannot prove a selected destination')
C_TaxiMap.GetAllTaxiNodes=function() return {
  {name='Thelsamar',state=0,slotIndex=1},
  {name='Ironforge',state=1,slotIndex=9}} end
addon.db={character='test'}
GetTime=function() return 1400 end
assert(taxi:Capture() and taxi.indices[9]=='Ironforge')
taxi:SelectedNode(2,16,.2,.3)
assert(not taxi.selection,'array position is not slotIndex')
taxi:SelectedNode(9,16,.2,.3)
assert(taxi.selection and taxi.selection.nodeName=='Ironforge')
taxi:Clear()
assert(taxi.selection and taxi.closing.indices[9]=='Ironforge')
print('taxi measured advice, slotIndex and consent passed')
