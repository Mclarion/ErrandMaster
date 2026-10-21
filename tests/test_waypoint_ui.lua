-- API mock models Waypoint UI's dot-call functions and normalized session readback.
local addon={db={data={settings={useWaypointUI=true}}}}
assert(loadfile('Routing/WaypointUI.lua'))('ErrandMaster',addon)
local bridge=addon.waypointUI
local first={id='errand-1',name='Bank',mapID=1412,x=.25,y=.75}
local second={id='errand-2',name='Herbs',mapID=1412,x=.5,y=.4}
local stage={id='taxi:errand-2',transitForId='errand-2',name='Flight master',mapID=1412,x=.2,y=.3}
local current, calls, clears, args=nil,0,0,nil
local function api()
  return {Navigation={GetUserNavigation=function() return current end,
    NewUserNavigation=function(options)
      calls=calls+1; args=options
      current={name=options.name,mapID=options.mapID,x=options.x/100,y=options.y/100,
        flags=options.flags}
      return current
    end,
    ClearUserNavigation=function(preserve,suppress)
      assert(preserve==true and suppress==true)
      clears=clears+1; current=nil
    end}}
end
WaypointUIAPI=nil
assert(not bridge:Update(first) and calls==0, 'absent addon is harmless')
WaypointUIAPI={Navigation={NewUserNavigation=function() error('must not use incomplete API') end}}
assert(not bridge:Update(first) and calls==0, 'incomplete API is harmless')
WaypointUIAPI=api()
assert(bridge:Update(first) and calls==1 and args.x==25 and args.y==75 and
  args.syncNativeWaypoint==true and args.superTracked==true and args.suppressAudio==true and
  args.flags=='ErrandMaster', 'dot call, percentage coordinates, native supertracking for in-world marker')
assert(bridge:Update({id=first.id,name=first.name,mapID=first.mapID,x=first.x,y=first.y}) and calls==1,
  'unchanged replanned target does not republish')
assert(bridge:Update(stage) and calls==2 and clears==0 and args.x==20 and
  args.name=='Flight master', 'transient first row is published')
assert(bridge:Update(second) and calls==3 and args.x==50 and clears==0,
  'changed target replaces only owned navigation')
assert(not bridge:Update({id='unknown',name='Unknown'}) and clears==1 and not current,
  'unlocated target clears owned navigation')
assert(bridge:Update(first) and calls==4)
current={flags='SomeOtherAddon',name='Foreign',mapID=1412,x=.1,y=.2}
assert(not bridge:Update(second) and calls==4 and clears==1 and current.name=='Foreign',
  'foreign takeover blocks periodic publishing')
current=nil
assert(not bridge:Update(second) and calls==4,
  'a cleared foreign pin does not silently resume publishing')
assert(bridge:Update(second,true) and calls==5,
  'explicit ErrandMaster selection may publish after a foreign takeover')
current={flags='SomeOtherAddon',name='Foreign',mapID=1412,x=.1,y=.2}
assert(not bridge:Update(nil) and clears==1 and current.name=='Foreign',
  'empty queue must not clear foreign navigation')
assert(bridge:Update(first,true) and calls==6, 'explicit selection can replace foreign pin')
assert(not bridge:Update(nil) and clears==2 and current==nil,
  'empty queue clears owned navigation only')
WaypointUIAPI=nil
assert(not bridge:Update(first) and calls==6)
WaypointUIAPI=api() -- optional addon appears later
assert(bridge:Update(first) and calls==7, 'late load works without a reload')
addon.db.data.settings.useWaypointUI=false
assert(not bridge:Update(first) and clears==3, 'turning setting off clears owned pin')
assert(not bridge:Update(first) and calls==7)
addon.db.data.settings.useWaypointUI=true
WaypointUIAPI.Navigation.GetUserNavigation=function() error('provider failed') end
assert(not bridge:Update(first) and calls==7, 'read errors cannot overwrite unknown pin')
WaypointUIAPI=api();current=nil
assert(not bridge:Update(first) and calls==7,
  'ambiguous readback after provider error blocks automatic retry')
assert(bridge:Update(first,true) and calls==8)
assert(bridge:Update({id='another-stop',name=first.name,mapID=first.mapID,
  x=first.x,y=first.y}) and calls==9,
  'a distinct queue stop at identical coordinates is still a target change')
WaypointUIAPI.Navigation.NewUserNavigation=function() error('provider failed') end
assert(not bridge:Update(second) and calls==9, 'write errors do not crash')
WaypointUIAPI=nil
print('Waypoint UI bridge ownership, transient staging, optional API and failure tests passed')
