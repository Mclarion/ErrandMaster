"""Synthetic map-load and observed-guidance costs; not client frame timings."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
root = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
probe = lua.execute('''return function(root)
 local addon={}
 local ids,points={},{}
 for i=1,1000 do ids[i]=i; points[i]={35,48} end
 local reads=0
 LibQuestieDB={flavor={name='Forever'},Enum={npcFlags={VENDOR=4}},
  RequireContract=function() return true end,
  Support={Get=function() return {private={areaIdToUiMapId='return {[38]=1432}'}} end},
  Npc={GetAllIds=function() return ids end,npcFlags=function() return 4 end,
   spawns=function() return {[38]=points} end,
   name=function() reads=reads+1; return 'Synthetic' end,
   friendlyToFaction=function() return 'AH' end}}
 assert(loadfile(root..'/Data/NpcCatalog.lua'))('ErrandMaster',addon)
 assert(addon.npcs:Initialize()); while not addon.npcs:Step(200) do end
 local t=os.clock(); local places=addon.npcs:LocationsOnMap(1432)
 local first=os.clock()-t
 t=os.clock(); addon.npcs:LocationsOnMap(1432)
 return first,os.clock()-t,#places,reads
end''')
print('1k NPCs x 1k points: first map %.6fs; cached %.6fs; %d records; %d NPC detail reads' % probe(str(root)))
guidance = lua.execute('''return function(root)
 local addon={}
 assert(loadfile(root..'/Routing/Navigation.lua'))('ErrandMaster',addon)
 addon.Position=function() return 1432,.1,.1 end
 addon.MapWorldSize=function() return 1000,1000 end
 GetPlayerFacing=function() return 0 end
 local nodes,edges={},{}
 for i=1,400 do
  nodes[i]={id='n'..i,uiMapID=1432,floor=0,x=.1+(i-1)*.002,y=.1,worldMapID=0,wz=10}
  if i>1 then edges[#edges+1]={a='n'..(i-1),b='n'..i,yards=2,source='observed-walk'} end
 end
 for i=#edges+1,1200 do edges[i]={a='other'..i,b='unrelated'..i,yards=2,source='observed-walk'} end
 addon.trails={edges=edges,NativeSample=function() return {uiMapID=1432,floor=0,worldMapID=0,wz=10} end}
 local item={id='goal',mapID=1432,x=nodes[400].x,y=.1,walkStatus='known-route',
  unknownStart=false,unknownEnd=false,walkWaypoints=nodes,walkYards=798}
 assert(addon.navigation:Next(item))
 local start,peak=os.clock(),0
 for i=1,1000 do
  local t=os.clock()
  assert(addon.navigation:Guidance(item).mode=='observed')
  peak=math.max(peak,os.clock()-t)
 end
 return (os.clock()-start)/1000,peak
end''')
print('400-node / 1200-edge observed guidance: mean %.6fs; peak %.6fs per read' % guidance(str(root)))
