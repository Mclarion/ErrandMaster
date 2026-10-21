-- Experimental imported catalogs must never feed the public route planner.
local addon={transportData={Docks={{map=0,x=100,y=20,z=0},{map=0,x=220,y=20,z=0}},
 Routes={[1]={kind='boat',stops={{dock=1},{dock=2}}}},
 Portals={{kind='portal',name='One-way portal',from={map=0,x=80,y=20,z=0},
 to={map=0,x=230,y=20,z=0}}}}}
CreateVector2D=function(x,y) return {GetXY=function() return x,y end} end
UnitFactionGroup=function() return 'Alliance' end
C_Map={GetWorldPosFromMapPos=function(map,pos)
 local x,y=pos:GetXY(); return 0,CreateVector2D((map==20 and 200 or 0)+x*150,y*100)
end,GetMapPosFromWorldPos=function(instance,pos,override)
 local x,y=pos:GetXY(); local map=override or (x>=200 and 20 or 10)
 return map,CreateVector2D((x-(map==20 and 200 or 0))/150,y/100)
end}
addon.navigation={WorldPosition=function(_,map,x,y)
 local instance,pos=C_Map.GetWorldPosFromMapPos(map,CreateVector2D(x,y))
 local wx,wy=pos:GetXY(); return instance,wx,wy
end}
assert(loadfile('Data/StaticTransport.lua'))('ErrandMaster',addon)
assert(loadfile('Routing/RoutePlanner.lua'))('ErrandMaster',addon)
assert(loadfile('Data/ZoneSearch.lua'))('ErrandMaster',addon)
local context=addon.zoneSearch:RouteContext({})
local boat=context.candidates({mapID=10,x=.95,y=.2},{category='Boat'})
assert(#boat==0,'an imported boat table must not supply public routing data')
local portal=context.candidates({mapID=20,x=.2,y=.2},{category='Portal'})
assert(#portal==0,'an imported portal table must not supply public routing data')
assert(#context.candidates({mapID=10,x=.5,y=.2},{category='Boat',npcID=999})==0)
local observed={id='local-boat',category='Boat',mapID=20,x=.2,y=.2,source='user-confirmed'}
local learned=addon.zoneSearch:RouteContext({observed}).candidates({mapID=10,x=.5,y=.2},{category='Boat'})
assert(#learned==1 and learned[1].id=='local-boat','local observations remain usable')
print('public route selection excludes imported transport tables and retains local observations')
