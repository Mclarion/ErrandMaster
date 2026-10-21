"""Exercise the bridge against Waypoint UI 1.7.4's packaged render-selection code."""
from pathlib import Path
import re
import zipfile
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
ZIP = ROOT / '.testdeps/WaypointUI-1.7.4.zip'
assert ZIP.is_file(), 'pinned official Waypoint UI 1.7.4 fixture required'

with zipfile.ZipFile(ZIP) as archive:
    def upstream(path, signature):
        text = archive.read('WaypointUI/' + path).decode('utf-8-sig').replace('\r\n', '\n')
        match = re.search(r'(?m)^' + re.escape(signature) + r'\n.*?^end\s*$', text, re.S | re.M)
        assert match, f'upstream implementation missing: {signature}'
        return match.group()

    publish = upstream('Code/MapPin/MapPin.lua', 'function MapPin.NewUserNavigation(options)')
    clear = upstream('Code/MapPin/MapPin.lua', 'function MapPin.ClearUserNavigation(preserveWaypoint, suppressAdvance)')
    tracked_native = upstream('Code/MapPin/MapPin.lua', 'function MapPin.IsUserNavigationTracked()')
    tracked = upstream('Code/MapPin/MapPin.lua', 'function MapPin.IsCustomUserNavigationTracked()')
    active = upstream('Code/Waypoint/Waypoint_Director.lua', 'local function ShouldSetActive()')

lua = LuaRuntime()
lua.execute('''
  MapPin = {}
  MapPinUtil = {MergePinOptions=function(target, source)
    for k,v in pairs(source) do target[k]=v end
    return target
  end, CreateVisualPinOptions=function(options) return {flags=options.flags,
    stripCoordinates=options.stripCoordinates} end,
  IsCurrentWaypoint=function() return false end, PlayUserNavigationAudio=function() end}
  local sessionData={userNavigation=nil}
  local native, trackedNative, nativeWrites = nil, false, 0
  MapPinUtil.GetSessionData=function() return sessionData end
  MapPinUtil.SaveSessionData=function() end
  MapPinUtil.ClearPendingUserNavigationValidation=function() end
  MapPinUtil.IsPathfindingEnabled=function() return false end
  MapPinUtil.IsCurrentWaypoint=function(map,x,y)
    return native and native.uiMapID==map and native.position.x==x and native.position.y==y
  end
  C_Map = {GetUserWaypoint=function() return native end}
  C_SuperTrack = {IsSuperTrackingAnything=function() return trackedNative end}
  MapPin.CreateUserWaypointPoint=function(mapID,x,y)
    if not mapID or not x or not y then return end
    return mapID,{x=x/100,y=y/100},{uiMapID=mapID,position={x=x/100,y=y/100}}
  end
  MapPin.SetUserNavigation=function(options) sessionData.userNavigation=options; return options end
  MapPin.GetUserNavigation=function() return sessionData.userNavigation end
  MapPin.SuppressNextUserNavigationValidation=function() end
  MapPinUtil.GetCurrentWaypointState=function()
    return native~=nil, native and native.uiMapID,
      native and native.position.x, native and native.position.y
  end
  MapPinUtil.DoesWaypointMatch=function(a,x,y,b,u,v)
    return a~=nil and b~=nil and a==b and x==u and y==v
  end
  MapPinUtil.PendingUserNavigationValidation={}
  Enum={SuperTrackingType={UserWaypoint=1}}
  GetHighestPrioritySuperTrackingType=function() return trackedNative and 1 or 0 end
  MapPin.IsCustomUserNavigation=function(info)
    if info==nil then info=MapPin.GetUserNavigation() end
    return info~=nil and info.fromWUI~=false
  end
  CallbackRegistry = {Trigger=function() end}
  SetUserWaypoint=function(point) native=point; nativeWrites=nativeWrites+1 end
  ClearUserWaypoint=function() native=nil; trackedNative=false end
  SetSuperTrackedUserWaypoint=function(on) trackedNative=on end
  function replaceNative(point) native=point; trackedNative=true end
  function renderSelected() return ShouldSetActive() and MapPin.IsCustomUserNavigationTracked() end
  function resetNative() native=nil; trackedNative=false end
  function nativeWriteCount() return nativeWrites end
  function readSession() return MapPin.GetUserNavigation() end
  Waypoint_Director={ShouldShowInCurrentLocation=function() return true end}
  addon={db={data={settings={useWaypointUI=true}}}}
''')
lua.execute(publish + '\n' + clear + '\n' + tracked_native + '\n' + tracked + '\nlocal IsSuperTrackingAnything=C_SuperTrack.IsSuperTrackingAnything\n' + active + '\n_G.ShouldSetActive=ShouldSetActive')
lua.execute('assert(loadfile("Routing/WaypointUI.lua"))("ErrandMaster",addon)')
lua.execute('''
  local bridge=addon.waypointUI
  local first={id='a',name='Bank',mapID=1412,x=.25,y=.75}
  local stage={id='!taxi:a',transitForId='a',name='Flight Master',mapID=1412,x=.2,y=.3}
  WaypointUIAPI={Navigation={
    GetUserNavigation=MapPin.GetUserNavigation,
    NewUserNavigation=MapPin.NewUserNavigation,
    ClearUserNavigation=MapPin.ClearUserNavigation
  }}
  assert(bridge:Update(first), 'bridge must publish current selection')
  assert(renderSelected(), 'actual Waypoint UI selection must activate the in-world marker')
  assert(nativeWriteCount()==1)
  assert(bridge:Update({id='a',name='Bank',mapID=1412,x=.25,y=.75}))
  assert(nativeWriteCount()==1, 'refresh must not rewrite/replan the same target')
  assert(bridge:Update(stage) and renderSelected(), 'transient first row must be visible in-world')
  assert(readSession().name=='Flight Master' and nativeWriteCount()==2)
  assert(not bridge:Update(nil) and not C_Map.GetUserWaypoint(),
    'clearing our stage must also remove its native in-world marker')
  assert(bridge:Update(first) and renderSelected())
  local foreign={uiMapID=1412,position={x=.8,y=.1}}
  replaceNative(foreign)
  assert(not bridge:Update(nil) and C_Map.GetUserWaypoint()==foreign,
    'foreign replacement of native pin must never be cleared by our bridge')
  assert(not bridge:Update(stage) and C_Map.GetUserWaypoint()==foreign,
    'automatic publication must not overwrite an existing foreign native pin')
''')
print('Packaged Waypoint UI render-selection integration passed')
