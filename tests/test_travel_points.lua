local addon={}
local messages={}
addon.Print=function(_, message) messages[#messages+1]=message end
addon.Refresh=function() end
assert(loadfile('Core/Database.lua'))('ErrandMaster', addon)
ErrandMasterDB=nil
addon.db:Initialize('Travel-Test')
assert(loadfile('Core/Errands.lua'))('ErrandMaster', addon)
assert(loadfile('UI/TravelPoints.lua'))('ErrandMaster', addon)
local travel=addon.travelPoints
local point=assert(travel:ParseFavorite('Camp; 1412; 52.3; 48.9'))
assert(point.name=='Camp' and point.mapID==1412 and point.x==.523 and point.y==.489)
for _, raw in ipairs({'', 'Bad; 1412; 52', 'Bad; 0; 52; 48',
    'Bad; 1412; 101; 48', 'Bad; 1412; -1; 48', 'Bad; 1412; nan; 48',
    'Bad; 1412; 1e309; 48', 'Bad|Name; 1412; 52; 48',
    'Bad; 1412; 52,3; 48', 'Bad; 1412; 52; 48; extra'}) do
  assert(travel:ParseFavorite(raw)==nil, 'must reject invalid coordinate input: '..raw)
  local added, errorText=travel:AddFavorite(raw)
  assert(not added and errorText:find('Camp; 1412; 52.3; 48.9',1,true),
    'invalid input should return a concrete example')
end
assert(#addon.errands:All()==0, 'invalid input leaves storage unchanged')
local favorite=assert(travel:AddFavorite('  Camp ; 1412 ; 52.3 ; 48.9  '))
assert(favorite.favorite and favorite.scope=='character' and favorite.category=='Custom')
assert(travel:Favorites()[1].id==favorite.id)
assert(travel:RemoveFavorite(favorite.id) and not favorite.favorite and
  #travel:Favorites()==0, 'remove from Favorites must retain the target')
assert(not travel:RemoveFavorite(favorite.id), 'repeated removal is harmless')
assert(not travel:CurrentWaypoint())
local waypoint=assert(travel:Pin(1412,.45,.67))
assert(waypoint.category=='Waypoint' and not waypoint.favorite and
  waypoint.scope=='character' and waypoint.x==.45)
assert(travel:CurrentWaypoint().id==waypoint.id)
assert(not travel:Pin(0,.3,.4) and not travel:Pin(1412,1/0,.4),
  'invalid map coordinates must not create an errand')
assert(travel:Pin(1413,.32,.15).id==waypoint.id and
  #addon.errands:All()==2 and waypoint.mapID==1413,
  're-pinning replaces only the owned character waypoint')
local selected
addon.ActivateTarget=function(_, id) selected=id; return true end
assert(travel:SelectCurrent() and selected==waypoint.id)
assert(not travel:RemoveFavorite(waypoint.id), 'pin is not a favorite')
StaticPopupDialogs={}
local shown
StaticPopup_Show=function(key) shown=key; return true end
assert(travel:OpenFavoriteForm() and shown and StaticPopupDialogs[shown].hasEditBox)
local dialog=StaticPopupDialogs[shown]
dialog.OnAccept({editBox={GetText=function() return 'Wrong; 1412; 110; 5' end}})
assert(#addon.errands:All()==2 and messages[#messages]:find('Camp; 1412; 52.3; 48.9',1,true))
dialog.OnAccept({editBox={GetText=function() return 'Inn; 1412; 25; 50' end}})
assert(#travel:Favorites()==1 and travel:Favorites()[1].name=='Inn')
waypoint.completed=true
local native={uiMapID=1412,position={x=.29,y=.44}}
C_Map={GetUserWaypoint=function() return native end}
local existing=travel:CurrentWaypoint()
assert(existing and existing.source=='native' and existing.x==.29,
  'an existing native map waypoint also exposes Select Current')
assert(travel:SelectCurrent() and selected==waypoint.id and
  waypoint.x==.29 and waypoint.y==.44 and not waypoint.completed and
  native.position.x==.29 and native.position.y==.44,
  'native waypoint selection copies it into an owned target without changing the native pin')
C_Map=nil
print('travel waypoint, coordinate parsing, favorites and malformed-input tests passed')
