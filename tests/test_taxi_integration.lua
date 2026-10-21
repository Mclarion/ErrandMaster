-- End-to-end Lua 5.1: native selection, observed landing and transient plan stage.
local addon={db={character='A',data={settings={routeMode='direct',optimize=false},characters={A={}}}},
 trails={IsEnabled=function() return true end}}
local frame={scripts={},registered={}}
function frame:RegisterEvent(event) self.registered[event]=true end
function frame:UnregisterEvent() end
function frame:SetScript(name,fn) self.scripts[name]=fn end
CreateFrame=function() return frame end
local hooks={}
TakeTaxiNode=function() end
hooksecurefunc=function(name,fn) hooks[name]=fn end
local riding=false; UnitOnTaxi=function() return riding end
local clock=100; GetTime=function() return clock end
local map,x,y=10,.1,.1
C_Map={GetBestMapForUnit=function() return map end,
 GetPlayerMapPosition=function() return {GetXY=function() return x,y end} end,
 GetMapWorldSize=function() return 1000,1000 end,
 GetMapInfo=function(id) return {name=({[10]='Start',[20]='Finish'})[id],mapType=3} end,
 GetMapGroupID=function() return nil end}
NumTaxiNodes=function() return 2 end
TaxiNodeGetType=function(i) return i==1 and 'CURRENT' or 'REACHABLE' end
TaxiNodeName=function(i) return i==1 and 'Start' or 'Finish' end
local target={id='goal',name='Goal',mapID=20,x=.9,y=.1}
local saved={goal=target}; local deletions=0
addon.errands={revision=0,All=function() return {target} end,
 Get=function(_,id) return saved[id] end,
 Delete=function(_,id) deletions=deletions+1;saved[id]=nil end}
addon.locations={All=function() return {} end}
addon.quests={OnMap=function() return {} end,Invalidate=function() end}
addon.npcs={IsReady=function() return false end}
addon.navigation={WorldPosition=function(_,id,a,b) return 1,b*1000,(id==10 and a or a+1)*1000 end,
 Next=function() end,Clear=function() end}
addon.ui={Refresh=function() end};addon.worldMap={Refresh=function() end}
addon.destinations={Refresh=function() end};addon.minimap={RefreshFromCachedPlan=function() end}
assert(loadfile('Routing/RoutePlanner.lua'))('ErrandMaster',addon)
assert(loadfile('Data/TaxiAdvice.lua'))('ErrandMaster',addon)
local transport={enabled=true,legs={}}
addon.db.data.characters.A.transport=transport
addon.db.TransportBucket=function() return transport end
addon.transportCatalog={OnEvent=function() end,ServiceCandidatesOnMap=function(_,id)
 if id==20 then return {{name='Landing Master',mapID=20,x=.1,y=.1}} end
 return {}
end}
assert(addon.taxiAdvice:Bind())
assert(loadfile('Core/Init.lua'))('ErrandMaster',addon)
addon:InstallTaxiHook()
assert(type(hooks.TakeTaxiNode)=='function','explicit native selection must be hooked')
frame.scripts.OnEvent(frame,'TAXIMAP_OPENED')
assert(addon.taxiAdvice.open)
hooks.TakeTaxiNode(2)
assert(addon.taxiAdvice.selection and addon.taxiAdvice.selection.nodeName=='Finish')
frame.scripts.OnEvent(frame,'TAXIMAP_CLOSED')
assert(addon.taxiAdvice.selection and not addon.taxiAdvice.open)
local before=addon:Plan();assert(#before==0,'no route learned from selection alone')
riding=true;addon:MovementTick();assert(addon.taxiAdvice.pending)
clock=110;x=.6;addon:MovementTick()
clock=120;map=20;x=.1;addon:MovementTick()
clock=121;map=20;x=.1;y=.1;riding=false
addon:MovementTick()
local leg=transport.legs[1]
assert(leg and leg.originX==.1 and leg.destinationX==.1 and leg.destinationMapID==20)
assert(not addon.taxiAdvice.pending)
assert(not addon.taxiAdvice:Recommend(10,.99,.1,target,function(m,a,b)
 return addon.navigation:WorldPosition(m,a,b)
end),'observed connection alone is not a useful walking-distance improvement')
map=10;x=.1;y=.1
local planned,deferred=addon:Plan()
assert(#planned==1 and planned[1].transitForId=='goal' and #deferred==1 and deferred[1].id=='goal',
 'stage precedes original outside taxi UI')
assert(planned[1].category=='Flight Master' and planned[1].mapID==10 and planned[1].x==.1)
assert(planned[1].taxiAdvice and planned[1].taxiAdvice.estimate=='walking-distance-reduction')
assert(addon:ActiveTarget(planned,{}).transitForId=='goal')
assert(addon:CheckArrival(10,.1,.1) and saved.goal and deletions==0,
 'takeoff arrival only clears transient stage')
planned,deferred=addon:Plan();assert(#planned==0 and #deferred==1 and deferred[1].id=='goal')
riding=true;addon:MovementTick();planned,deferred=addon:Plan()
assert(#planned==0 and #deferred==1 and not deferred[1].transitForId,'suppress during taxi')
map=20;x=.1;y=.1;riding=false;addon:MovementTick()
planned=addon:Plan();assert(#planned==1 and planned[1].id=='goal' and saved.goal)
addon.trails.IsEnabled=function() return false end
addon.taxiStageDone.goal=nil
map=10;x=.1;y=.1;addon:Refresh();planned,deferred=addon:Plan()
assert(planned[1] and planned[1].transitForId=='goal',
 'ground trails off must not suppress independent flight learning')
assert(addon.taxiAdvice:SetEnabled(false))
addon:Refresh();planned,deferred=addon:Plan()
assert(#planned==0 and #deferred==1 and not deferred[1].transitForId,'transport off suppresses reuse')
frame.scripts.OnEvent(frame,'TAXIMAP_OPENED')
hooks.TakeTaxiNode(2)
assert(not addon.taxiAdvice.selection,'transport off rejects native selection learning')
frame.scripts.OnEvent(frame,'TAXIMAP_CLOSED')
addon.taxiAdvice:SetEnabled(true)
addon.taxiStageDone.goal=nil
planned=addon:Plan();assert(planned[1] and planned[1].transitForId=='goal')
riding=true;addon:MovementTick()
local suppressed,suppressedDeferred=addon:CachedPlan()
assert(#suppressed==0 and suppressedDeferred[1].id=='goal',
 'boarding invalidates an existing cached transit stage')
riding=false;addon:MovementTick()
frame.scripts.OnEvent(frame,'TAXIMAP_OPENED')
frame.scripts.OnEvent(frame,'TAXIMAP_CLOSED') -- secure post-hook may run after UI close
hooks.TakeTaxiNode(2)
assert(addon.taxiAdvice.selection and addon.taxiAdvice.selection.originMapID==10,
 'selection after synchronous native close uses the captured map snapshot')
clock=150;addon.taxiAdvice:Depart()
assert(not addon.taxiAdvice.pending,'stale selection cannot become taxi evidence')
addon.taxiAdvice.selection=nil
riding=true;addon:MovementTick();riding=false;map=20;addon:MovementTick()
assert(#transport.legs==1 and transport.legs[1]==leg,
 'taxi movement without timely explicit selection cannot fabricate another leg')
addon:Command('transport off')
assert(not addon.taxiAdvice:IsEnabled() and transport.enabled==false)
addon:Command('transport on')
assert(addon.taxiAdvice:IsEnabled() and transport.enabled==true)
addon:Command('transport clear')
assert(#transport.legs==1,'reset needs confirmation')
addon:Command('transport confirm')
assert(#transport.legs==0 and not next(addon.taxiAdvice.legs) and
 addon.taxiAdvice:IsEnabled(),'reset affects only this character flight data')
-- Fresh character / recording disabled: native positions still yield an
-- unconfirmed stage before the original off-map errand.
assert(addon.taxiAdvice:SetEnabled(false))
addon.transportCatalog={OnEvent=function() end,ServiceCandidatesOnMap=function(_,id)
 if id==10 then return {{name='Native Start',nodeID=1,mapID=10,x=.1,y=.1}} end
 if id==20 then return {{name='Native Stop',nodeID=2,mapID=20,x=.1,y=.1}} end
 return {}
end}
map=10;x=.1;y=.1;addon.taxiStageDone=nil;addon:Refresh()
planned,deferred=addon:Plan()
assert(#planned==1 and planned[1].transitForId=='goal' and #deferred==1 and
 deferred[1].id=='goal' and planned[1].taxiAdvice.source=='candidate-taxi' and
 planned[1].taxiAdvice.connectionStatus=='unconfirmed',
 'default flight stage is position-only; recording opt-in cannot gate advice')
-- Screenshot route: a nearby Repair precedes an Auction House 2057 yd from
-- the player. The flight belongs to the Repair-to-Auction leg, not route start.
local repair={id='repair',name='Repair',category='Repair',mapID=10,x=.15,y=.1,manualPosition=1}
local auction={id='auction',name='Auction House',category='Auction House',
 mapID=20,x=.9,y=.1,manualPosition=2}
saved.goal=nil;saved.repair=repair;saved.auction=auction
addon.errands.All=function() return {repair,auction} end
addon.transportCatalog.ServiceCandidatesOnMap=function(_,id)
 if id==10 then return {{name='Repair Flight',nodeID=1,mapID=10,x=.16,y=.1}} end
 if id==20 then return {{name='Auction Flight',nodeID=2,mapID=20,x=.85,y=.1}} end
 return {}
end
addon.navigation.WorldPosition=function(_,id,a,b) return 1,b*1000,(id==10 and a or a)*2571.25 end
addon:Refresh();planned,deferred=addon:Plan()
local display=addon.route:DisplayOrder(planned,deferred)
assert(#display==3 and display[1].id=='repair' and
 display[2].transitForId=='auction' and display[3].id=='auction',
 'transit and destination must render as distinct adjacent rows after Repair')
assert(display[2].id~='auction' and display[2].taxiAdvice.connectionStatus=='unconfirmed' and
 display[2].taxiAdvice.directYards==(.9-.15)*2571.25,
 'flight leg must start at the previous planned target, not the player')
assert(saved.repair==repair and saved.auction==auction and repair.manualPosition==1 and
 auction.manualPosition==2 and not saved[display[2].id],
 'candidate stage cannot mutate persisted identities or manual positions')
riding=true;addon:MovementTick()
local airborne,airborneDeferred=addon:CachedPlan()
local airborneDisplay=addon.route:DisplayOrder(airborne,airborneDeferred)
assert(#airborneDisplay==2 and airborneDisplay[1].id=='repair' and
 airborneDisplay[2].id=='auction',
 'boarding drops cached later-target stages, not only a first-row stage')
riding=false;addon:MovementTick()
-- A long player-to-Auction distance cannot override a short preceding leg.
addon.navigation.WorldPosition=function(_,id,a,b) return 1,b*1000,a*1000 end
repair.x=.1;auction.x=.7
addon.transportCatalog.ServiceCandidatesOnMap=function(_,id)
 if id==10 then return {{name='Repair Flight',mapID=10,x=.11,y=.1}} end
 return {{name='Auction Flight',mapID=20,x=.69,y=.1}}
end
addon:Refresh();planned,deferred=addon:Plan()
display=addon.route:DisplayOrder(planned,deferred)
assert(#display==2 and display[1].id=='repair' and display[2].id=='auction',
 'exactly 600 yd from Repair suppresses flight even though player is 700 yd away')
auction.x=.701;addon:Refresh();planned,deferred=addon:Plan()
display=addon.route:DisplayOrder(planned,deferred)
assert(#display==3 and display[1].id=='repair' and
 display[2].transitForId=='auction' and display[3].id=='auction',
 'above 600 yd and shorter combined ground legs restore later transit')
addon.transportCatalog.ServiceCandidatesOnMap=function(_,id)
 if id==10 then return {{name='Far Takeoff',mapID=10,x=.5,y=.1}} end
 return {{name='Far Landing',mapID=20,x=.1,y=.1}}
end
addon:Refresh();planned,deferred=addon:Plan()
display=addon.route:DisplayOrder(planned,deferred)
assert(#display==2 and display[2].id=='auction',
 'longer combined ground legs must not produce a later flight')
print('taxi integration lifecycle and later-target stages passed')
