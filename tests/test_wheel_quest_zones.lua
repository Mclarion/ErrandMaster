-- Actual wheel click path using a changing character quest-log inventory.
local f=dofile('tests/wheel_fixture.lua')()
local w, addon=f.wheel,f.addon
local rows={
  {name='Loch Modan',quests={{questID=501,title='Missing POI',hasLocation=false,isComplete=false},
    {questID=502,title='Native target',hasLocation=true,mapID=17,x=.3,y=.4,isComplete=false}}},
  {name='Lac Modan',quests={{questID=601,title='Autre quête',hasLocation=true,mapID=44,x=.1,y=.2,isComplete=true}}},
}
local calls,notices={},{}
local originalNotice=w.Notice
w.Notice=function(self,message) notices[#notices+1]=message;return originalNotice(self,message) end
addon.quests={ZoneInventory=function() return rows,true end,
  Add=function(_,id,map) calls[#calls+1]={id,map};return {name='queued'} end}
local function label(index) return w.menuEntries[index] and (w.menuEntries[index].name or w.menuEntries[index].category) end
local function questRoot() f:root();f:click(9);assert(w.submenu=='Quests') end
questRoot()
assert(label(1)=='Loch Modan' and label(2)=='Lac Modan')
assert(w.slots[1].sector.color[1]==w.history[1].entries[9].color[1],
  'zones inherit the Quests parent color')
f:click(1)
assert(label(1)=='Missing POI' and label(2)=='Native target' and w.count==3)
assert(w.slots[1].sector.color[1]==w.history[2].entries[1].color[1],
  'quests inherit the selected zone color')
f:click(1)
assert(#calls==0 and w.frame.shown and notices[#notices]:find('location'),
  'quest without native destination stays visible and gives guidance')
f:click(2)
assert(#calls==1 and calls[1][1]==502 and calls[1][2]==17,
  'queue uses native target map, never player or zone map')
questRoot();f:click(1);f:click(w.count)
assert(w.submenu=='Quests' and label(2)=='Lac Modan','Back returns to zones')
f:click(2)
assert(label(1)=='Autre quête','localized zone and quest names survive navigation')
-- A removal between render and click must never enqueue a stale target.
rows[2].quests={}
f:click(1)
assert(#calls==1 and notices[#notices]:find('no longer'), 'removed quest is rejected')
w.frame.scripts.OnEvent(w.frame,'QUEST_LOG_UPDATE')
assert(w.count==1 and w.menuEntries[1].category=='Back',
  'quest-log update refreshes an open zone ring after removal')
w:Close();questRoot()
rows={}
for i=1,47 do rows[i]={name='Zone '..i,quests={{questID=1000+i,title='Quest '..i,hasLocation=false}}} end
w:Layout()
assert(w.count<=24 and label(w.count)=='Next' and label(w.count-1)=='Back')
f:click(w.count)
assert(label(1)=='Zone 23' and label(w.count)=='Next')
f:click(w.count)
assert(label(1)=='Zone 44' and label(w.count)=='Previous')
f:click(w.count)
assert(label(1)=='Zone 23','Previous pages without climbing hierarchy')
f:click(1)
rows[23].quests={}
for i=1,48 do rows[23].quests[i]={questID=2000+i,title='Quest '..i,hasLocation=false} end
w:Layout()
assert(w.count<=24 and label(w.count)=='Next')
f:click(w.count)
assert(label(1)=='Quest 23')
f:click(w.count)
assert(label(1)=='Quest 44')
f:click(w.count-1)
assert(w.submenu=='Quests' and label(1)=='Zone 23','Back returns to same zone page')
f:click(w.count-2)
assert(w.submenu==nil,'Back reaches root')
addon.quests.ZoneInventory=function() error('API unavailable') end
f:click(9)
assert(w.submenu=='Quests' and w.count==1 and label(1)=='Back')
assert(notices[#notices]:find('unavailable'),'unavailable quest API is explicit')
w:Close()
addon.db.data.settings.wheelQuestMigrationStatus='full'
local noticeCount=#notices
f:root()
assert(#notices==noticeCount,
  'stale full status must not warn when Quests is already on the root')
w:Close()
addon.db.data.settings.wheelQuestMigrationStatus='present'
rows={{name='A long localized quest-log zone',quests={{questID=9000,
  title=string.rep('L',120),hasLocation=false}}}}
addon.quests.ZoneInventory=function() return rows,true end
questRoot();f:click(1)
assert(w.menuEntries[1].id==9000 and #w.menuEntries[1].name==120,
  'long valid localized titles are not silently omitted')
print('zone quest click-path tests passed')
