local addon={}
C_Map={GetMapInfo=function(id)
  return {name=id==15 and 'Ironforge' or 'Loch Modan'}
end}
NumTaxiNodes=function() return 3 end
TaxiNodeGetType=function(i)
  return ({'CURRENT','REACHABLE','DISTANT'})[i]
end
TaxiNodeName=function(i)
  return ({'Thelsamar','Ironforge','Unknown Town'})[i]
end
assert(loadfile('Data/TaxiAdvice.lua'))('ErrandMaster',addon)
local taxi=addon.taxiAdvice
assert(taxi:Capture() and taxi:ForMap(15)=='Ironforge',
  'only a currently reachable native taxi node may match a destination zone')
assert(not taxi:ForMap(16), 'a different zone is not a confirmed reachable leg')
TaxiNodeGetType=function() return 'DISTANT' end
assert(taxi:Capture() and not taxi:ForMap(15),
  'a stale node must not survive a taxi-status change')
taxi:Clear()
assert(not taxi:ForMap(15), 'closing the taxi map clears transient reachability')
NumTaxiNodes=nil; TaxiNodeGetType=nil; TaxiNodeName=nil
FlightMapFrame={GetMapID=function() return 13 end}
C_TaxiMap={GetAllTaxiNodes=function(map)
  assert(map==13)
  return {{name='Ironforge',state=1,nodeID=8},
    {name='Stormwind',state=2,nodeID=9}}
end}
assert(taxi:Capture() and taxi:ForMap(15)=='Ironforge',
  'modern taxi map fallback reads only reachable nodes')
C_TaxiMap.GetAllTaxiNodes=function() error('protected') end
assert(not taxi:Capture() and not taxi:ForMap(15),
  'protected taxi API fails closed and discards stale advice')
print('taxi advice uses only live reachable taxi-map evidence')
