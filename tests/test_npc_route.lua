-- Service candidates must be selected by observed connectivity, never by air alone.
local addon={discovery={PlayerClass=function() return 'Hunter' end}}
assert(loadfile('Routing/WalkGraph.lua'))('ErrandMaster',addon)
assert(loadfile('Routing/RoutePlanner.lua'))('ErrandMaster',addon)
local task={{id='bank',name='Visit bank',category='Bank',origin='manual'}}
local places={
  {id='npc-near',name='Isolated Banker',category='Bank',mapID=10,x=.101,y=.1,
    source='questiedb-forever',precision='candidate-spawn',npcID=101},
  {id='npc-connected',name='Reachable Banker',category='Bank',mapID=10,x=.2005,y=.1,
    source='questiedb-forever',precision='candidate-spawn',npcID=102},
  {id='npc-unknown',name='Unmapped Banker',category='Bank',mapID=10,x=.4,y=.1,
    source='questiedb-forever',precision='candidate-spawn',npcID=103},
}
local nodes={
  {id='start',uiMapID=10,floor=1,x=.1,y=.1},
  {id='isolated',uiMapID=10,floor=1,x=.101,y=.1},
  {id='reached',uiMapID=10,floor=1,x=.2,y=.1},
}
local edges={{a='start',b='reached',yards=100,source='observed-walk'}}
local context={mode='observed',floor=1,playerLevel=30,nodes=nodes,edges=edges}
local ordered,deferred=addon.route:Plan(task,10,.1,.1,true,places,nil,1000,1000,context)
assert(#ordered==1 and #deferred==0 and ordered[1].locationID=='npc-connected' and
  ordered[1].walkStatus=='partial-route' and ordered[1].walkYards==100,
  'reachability outranks a closer disconnected NPC spawn')
local direct=addon.route:Plan(task,10,.1,.1,true,places,nil,1000,1000)
assert(direct[1].locationID=='npc-near' and math.abs(direct[1].directYards-1)<.00001,
  'direct mode may estimate proximity but must not label that estimate walking: '..
  tostring(direct[1].locationID)..' '..tostring(direct[1].directYards))
local withoutEvidence=addon.route:Plan(task,10,.1,.1,true,places,nil,1000,1000,
  {mode='observed',floor=0,playerLevel=30,nodes=nodes,edges=edges})
assert(#withoutEvidence==0,
  'missing outdoor elevation must not turn a candidate spawn into a known walk')
local both,remaining=addon.route:Plan({task[1],
  {id='bank2',name='Second bank errand',category='Bank'},
  {id='bank3',name='Third bank errand',category='Bank'}},
  10,.1,.1,false,places,nil,1000,1000,context)
assert(#both==3 and #remaining==0 and both[2].locationID==both[1].locationID and
  both[2].id=='bank2' and both[3].id=='bank3' and
  both[2].walkStatus=='partial-route' and both[2].walkYards==0,
  'two service errands can share one candidate stop without a second unverified leg')
local dual={{id='vendor-first',npcID=200,name='Dual Service',category='Vendor',
  mapID=10,x=.11,y=.1},
  {id='repair-second',npcID=200,name='Dual Service',category='Repair',
    mapID=10,x=.3,y=.1}}
local specific=addon.route:Plan({{id='fix',name='Repair gear',category='Repair',npcID=200}},
  10,.1,.1,true,dual,nil,1000,1000)
assert(specific[1] and specific[1].locationID=='repair-second',
  'an ID-specific errand must still honor the requested NPC service')
addon.ProfessionFilters=function() return {'Alchemy'} end
local trainers={
  {id='mining',name='Mining Coach',category='Trainer',trainerGroup='Profession Trainer',
    specialty='Mining Trainer',mapID=10,x=.101,y=.1},
  {id='alchemy',name='Alchemy Coach',category='Trainer',trainerGroup='Profession Trainer',
    specialty='Alchemy Trainer',mapID=10,x=.2,y=.1},
}
local profession=addon.route:Plan({{id='learn',name='Find teacher',
  category='Profession Trainer'}},10,.1,.1,true,trainers,nil,1000,1000)
assert(profession[1] and profession[1].locationID=='alchemy',
  'profession search excludes a closer trainer for a different profession')
local missing,unknown=addon.route:Plan({{id='learn',name='Find teacher',
  category='Profession Trainer'}},10,.1,.1,true,{trainers[1]},nil,1000,1000)
assert(#missing==0 and #unknown==1,
  'no matching profession trainer remains deferred rather than switching professions')
print('NPC candidate routing prefers observed connectivity over air distance')
