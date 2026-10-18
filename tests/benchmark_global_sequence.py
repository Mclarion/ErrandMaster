"""Synthetic global sequential planning probe; not a client frame-time guarantee."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
run = LuaRuntime().execute('''return function(root)
 local addon={discovery={PlayerClass=function() return nil end}}
 local areas={} for m=1,200 do areas[#areas+1]='['..m..']='..m end
 LibQuestieDB={flavor={name='Forever'},Enum={npcFlags={BANKER=256}},
  RequireContract=function() return true end,
  Support={Get=function() return {private={areaIdToUiMapId='return {'..table.concat(areas,',')..'}'}} end},
  Npc={GetAllIds=function() local t={} for i=1,10000 do t[i]=i end return t end,
   npcFlags=function() return 256 end,
   spawns=function(id) return {[math.ceil(id/50)]={{(id%50)+1,50}}} end,
   name=function(id) return 'Banker '..id end,
   friendlyToFaction=function() return 'AH' end}}
 UnitFactionGroup=function() return 'Alliance' end
 for _,file in ipairs({'Data/NpcCatalog.lua','Routing/RoutePlanner.lua','Data/ZoneSearch.lua'}) do
  assert(loadfile(root..'/'..file))('ErrandMaster',addon)
 end
 addon.navigation={WorldPosition=function(_,map,x,y) return 0,map*1000+x*1000,y*1000 end}
 addon.MapWorldSize=function() return 1000,1000 end
 assert(addon.npcs:Initialize()) while not addon.npcs:Step(80) do end
 local errands={} for i=1,200 do errands[i]={id='e'..i,category='Bank',name='Bank'} end
 local function plan()
  local t=os.clock()
  local ordered,deferred=addon.route:Sequence(errands,{mapID=1,x=0,y=.5},true,{},
   addon.zoneSearch:RouteContext({}))
  assert(#ordered==200 and #deferred==0)
  for _,item in ipairs(ordered) do assert(item.mapID==1 and item.x==.01) end
  return os.clock()-t
 end
 return plan(),plan()
end''')
cold, warm = run(str(root))
print(f'200 maps / 10,000 bank spawns / 200 sequential requests: cold {cold:.3f}s; warm {warm:.3f}s')
