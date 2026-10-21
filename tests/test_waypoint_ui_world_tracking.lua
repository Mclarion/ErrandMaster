-- A matching Waypoint UI session is not proof of a visible world marker.
local addon={db={data={settings={useWaypointUI=true}}}}
assert(loadfile('Routing/WaypointUI.lua'))('ErrandMaster',addon)
local bridge=addon.waypointUI
local target={id='mail',name='Mailbox',mapID=1412,x=.34,y=.52}
local current,tracked,calls=nil,false,0
local native
C_Map={GetUserWaypoint=function() return native end}
WaypointUIAPI={Navigation={
  GetUserNavigation=function() return current end,
  IsUserNavigationTracked=function() return tracked end,
  NewUserNavigation=function(options)
    calls=calls+1
    assert(options.syncNativeWaypoint and options.superTracked)
    current={flags=options.flags,name=options.name,mapID=options.mapID,
      x=options.x/100,y=options.y/100}
    native={uiMapID=options.mapID,position={x=options.x/100,y=options.y/100}}
    if calls>=2 then tracked=true end -- supertracking did not latch on first publication
    return current
  end,
  ClearUserNavigation=function() current=nil; native=nil end,
}}
assert(not bridge:Update(target,true) and calls==1,
  'a session alone must not claim the world marker is visible')
assert(bridge:Update(target) and calls==2 and tracked,
  'a matching but untracked pin must recover its world marker')
local foreign={uiMapID=1412,position={x=.7,y=.8}}
native=foreign;tracked=false
assert(not bridge:Update(target) and calls==2 and native==foreign,
  'tracking recovery must never overwrite an unrelated native waypoint')
print('Waypoint UI tracking recovery and foreign safety passed')
