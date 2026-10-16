"""Manual Lua 5.1 stress probe for the bounded observed-walk planner."""
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
run = LuaRuntime().execute("""
local addon = {}
assert(loadfile('Routing/WalkGraph.lua'))('ErrandMaster', addon)
assert(loadfile('Routing/RoutePlanner.lua'))('ErrandMaster', addon)
return function(count)
  local nodes, edges, errands = {}, {}, {}
  for i=1,400 do
    nodes[i] = {id='n'..i, uiMapID=10, floor=1, x=i/400, y=.2}
    if i > 1 then edges[i-1] = {a='n'..(i-1),b='n'..i,
      yards=10,source='observed-walk'} end
  end
  for i=1,count do
    local index = 1 + math.floor(i*398/count)
    errands[i] = {id='e'..i,name='Stop '..i,mapID=10,
      floor=1,x=index/400,y=.2}
  end
  local t=os.clock()
  local known,deferred=addon.route:Plan(errands,10,1/400,.2,true,nil,nil,
    1000,1000,{mode='observed',floor=1,nodes=nodes,edges=edges,playerLevel=60})
  return os.clock()-t,#known,#deferred
end
""")
if __name__ == "__main__":
    import os
    os.chdir(ROOT)
    for count in (10, 20, 50, 200):
        elapsed, known, deferred = run(count)
        print(f"{count} stops, 400 nodes: {elapsed:.3f}s; {known} known, {deferred} deferred", flush=True)
