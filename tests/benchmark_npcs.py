"""Manual Lua 5.1 stress probe: 20k NPCs, 1k services, 200 errands."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
run = lua.execute('''return function(root)
 local addon={discovery={PlayerClass=function() return nil end}}
 LibQuestieDB={flavor={name='Forever'},Enum={npcFlags={BANKER=256}},
  RequireContract=function() return true end,
  Support={Get=function() return {private={areaIdToUiMapId='return {[215]=10}'}} end},
  Npc={GetAllIds=function() local t={} for i=1,20000 do t[i]=i end return t end,
   npcFlags=function(id) return id<=1000 and 256 or 0 end,
   spawns=function(id) return {[215]={{id/10,50}}} end,
   name=function(id) return 'Banker '..id end,
   friendlyToFaction=function() return 'AH' end}}
 UnitFactionGroup=function() return 'Alliance' end
 assert(loadfile(root..'/Data/NpcCatalog.lua'))('ErrandMaster',addon)
 assert(loadfile(root..'/Routing/WalkGraph.lua'))('ErrandMaster',addon)
 assert(loadfile(root..'/Routing/RoutePlanner.lua'))('ErrandMaster',addon)
 local clock=os.clock
 local t=clock(); assert(addon.npcs:Initialize())
 while not addon.npcs:Step(80) do end
 local indexed=clock()-t
 t=clock(); local places=addon.npcs:LocationsOnMap(10,'Bank'); local listed=clock()-t
 local nodes,edges,errands={},{},{}
 for i=1,400 do
  nodes[i]={id='n'..i,uiMapID=10,floor=1,x=i/401,y=.5}
  if i>1 then edges[i-1]={a='n'..(i-1),b='n'..i,yards=10,source='observed-walk'} end
 end
 for i=1,200 do errands[i]={id='e'..i,name='Bank',category='Bank'} end
 t=clock(); local chosen,deferred=addon.route:Plan(errands,10,1/401,.5,true,places,nil,1000,1000,
  {mode='observed',floor=1,nodes=nodes,edges=edges,playerLevel=60})
 assert(#places==1000 and #chosen==200 and #deferred==0)
 return indexed,listed,clock()-t,#places,#chosen,#deferred
end''')
print('index %.3fs; map %.3fs; 200 errands %.3fs; %d spawns, %d planned, %d deferred' % run(str(root)))
