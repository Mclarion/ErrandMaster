"""Synthetic maximum-size provider-list initialization timing (not client FPS)."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
probe = lua.execute('''return function(root)
 local addon={}
 local npcs,items={},{}
 for i=1,100000 do npcs[i]=i end
 for i=1,1000000 do items[i]=i end
 LibQuestieDB={flavor={name='Forever'},Enum={npcFlags={VENDOR=4}},
  RequireContract=function() return true end,
  Support={Get=function() return {private={areaIdToUiMapId='return {[38]=1432}'}} end},
  Npc={GetAllIds=function() return npcs end,npcFlags=function() return 0 end,
   spawns=function() return {} end,name=function() return 'Synthetic' end},
  Item={GetAllIds=function() return items end,class=function() return 1 end,
   subClass=function() return 0 end,vendors=function() return nil end}}
 assert(loadfile(root..'/Data/NpcCatalog.lua'))('ErrandMaster',addon)
 local started=os.clock()
 assert(addon.npcs:Initialize())
 local elapsed=os.clock()-started
 local peak,steps=0,0
 while addon.npcs:Status().normalizing do
  local t=os.clock()
  addon.npcs:Step(200)
  peak=math.max(peak,os.clock()-t); steps=steps+1
 end
 local status=addon.npcs:Status()
 assert(status.total==100000 and status.itemsTotal==1000000)
 return elapsed,peak,steps,collectgarbage('count')/1024
end''')
print('100k NPC + 1m item IDs: initialization %.6fs; peak normalization step %.6fs; %d steps; Lua heap %.1f MiB' % probe(str(root)))
