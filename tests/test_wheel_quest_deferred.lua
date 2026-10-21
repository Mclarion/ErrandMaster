-- Real wheel click -> live quest inventory -> real errand storage, no player saves.
local f=dofile('tests/wheel_fixture.lua')()
local addon,w=f.addon,f.wheel
f:legacyLayout()
assert(loadfile('Core/Errands.lua'))('ErrandMaster',addon)
assert(loadfile('Data/QuestWaypoints.lua'))('ErrandMaster',addon)
assert(loadfile('Data/Quests.lua'))('ErrandMaster',addon)
local rows={
  {title='Loch Modan',isHeader=true,isCollapsed=false},
  {title='Collect old letters',questID=501,isHeader=false,isComplete=false},
  {title=string.rep('A',120),questID=502,isHeader=false,isComplete=false},
}
local nextPoint
C_QuestLog={GetNumQuestLogEntries=function() return #rows,2 end,
 GetInfo=function(i) return rows[i] end,
 GetQuestsOnMap=function() return {} end,
 GetNextWaypoint=function(id) if id==502 then return nextPoint, .2,.4 end end}
f:root();f:click(9);f:click(1)
assert(w.menuEntries[1].name=='Collect old letters' and not w.menuEntries[1].mapID)
f:click(1)
local items=addon.errands:All()
assert(#items==1 and items[1].questID==501 and items[1].mapID==nil and
  items[1].x==nil and items[1].y==nil,
  'click queues an active unlocated quest without inventing an objective coordinate')
assert(f.notices[#f.notices]:find('no verified location',1,true),
  'a deferred quest tells the player why there is no navigation yet')
f:root();f:click(9);f:click(1);f:click(1)
assert(#addon.errands:All()==1 and w.hintText.text:find('already',1,true),
  'repeat click does not queue duplicates')
w:Close();f:root();f:click(9);f:click(1)
table.remove(rows,2)
f:click(1)
assert(#addon.errands:All()==1 and w.hintText.text:find('no longer',1,true),
  'removed log entry cannot be queued from an open wheel')
w:Close();nextPoint=44
f:root();f:click(9);f:click(1);f:click(1)
items=addon.errands:All()
assert(#items==2 and items[2].questID==502 and items[2].mapID==44 and
  items[2].x==.2 and #items[2].name<=80,
  'a native log waypoint queues even when the optional index adapter is absent')
print('wheel quest deferred and native location click regression passed')
