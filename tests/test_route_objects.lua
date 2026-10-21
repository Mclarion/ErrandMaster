local addon={navigation={WorldPosition=function(_,map,x,y) return 0,map*100+x*100,y*100 end}}
assert(loadfile('Routing/RoutePlanner.lua'))('ErrandMaster',addon)
assert(loadfile('Data/ZoneSearch.lua'))('ErrandMaster',addon)
local boxes={
 [10]={{id='box-a',objectID=1,category='Mailbox',mapID=10,x=.9,y=.5}},
 [11]={{id='box-b',objectID=2,category='Mailbox',mapID=11,x=0,y=.5}}}
addon.objects={byMap=boxes,IsReady=function() return true end,
 LocationsOnMap=function(_,map) return boxes[map] or {} end}
local context=addon.zoneSearch:RouteContext({})
local chosen=context.candidates({mapID=10,x=.99,y=.5},{category='Mailbox'})
assert(#chosen==1 and chosen[1].objectID==2,'mailboxes must participate in cross-map nearest selection')
assert(#context.candidates({mapID=10,x=.99,y=.5},{category='Bank'})==0,'object mailboxes are not bank NPCs')
addon.objects.IsReady=function() return false end
assert(#addon.zoneSearch:RouteContext({}).candidates({mapID=10,x=.5,y=.5},{category='Mailbox'})==0)
print('mailbox object candidates integrated with global service resolution')
