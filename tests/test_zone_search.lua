local addon={npcs={IsReady=function() return true end, LocationsOnMap=function(_,map,wanted)
  if map~=20 then return {} end
  local entries={
    {id='east',name='Border Banker',category='Bank',mapID=20,x=.1,y=.5},
    {id='wrong',name='Distant Trainer',category='Trainer',mapID=20,x=.8,y=.5},
  }
  local filtered={}
  for _,place in ipairs(entries) do
    if not wanted or place.category==wanted then filtered[#filtered+1]=place end
  end
  return filtered
end}}
local world={
  [10]={0,1000,0,1000}, [20]={1000,2000,0,1000},
  [30]={3000,4000,0,1000},
}
CreateVector2D=function(x,y) return {GetXY=function() return x,y end} end
C_Map={
  GetMapInfo=function(map) return {parentMapID=map==10 and 1 or 1,name='Zone '..map} end,
  GetMapChildrenInfo=function(parent)
    assert(parent==1)
    return {{mapID=10,name='Home'}, {mapID=20,name='Border'},
      {mapID=30,name='Faraway'}}
  end,
  GetWorldPosFromMapPos=function(map,position)
    local bounds=world[map]
    if not bounds then return end
    local x,y=position:GetXY()
    local px=bounds[1]+x*(bounds[2]-bounds[1])
    local py=bounds[3]+y*(bounds[4]-bounds[3])
    return 1,CreateVector2D(px,py)
  end,
}
assert(loadfile('Data/ZoneSearch.lua'))('ErrandMaster',addon)
local nearby=addon.zoneSearch:Nearby(10,.95,.5,'Bank',500,10)
assert(#nearby==1 and nearby[1].name=='Border Banker' and
  nearby[1].zoneName=='Border' and math.abs(nearby[1].directYards-150)<.001,
  'border search must use same-continent world coordinates in yards')
assert(#addon.zoneSearch:Nearby(10,.95,.5,'Trainer',500,10)==0,
  'distant NPCs and incorrect services must not be shown')
assert(#addon.zoneSearch:Nearby(10,.95,.5,nil,500,10,'trainer')==0,
  'text search must filter before limiting nearby candidates')
local old=C_Map.GetWorldPosFromMapPos
C_Map.GetWorldPosFromMapPos=function(map,pos)
  if map==20 then return 2,CreateVector2D(1100,500) end
  return old(map,pos)
end
assert(#addon.zoneSearch:Nearby(10,.95,.5,'Bank',500,10)==0,
  'different continents are never treated as adjacent')
C_Map.GetWorldPosFromMapPos=nil
assert(#addon.zoneSearch:Nearby(10,.95,.5,'Bank',500,10)==0,
  'unavailable world projection fails closed')
print('nearby zone search respects map projection and unknown connectivity')
