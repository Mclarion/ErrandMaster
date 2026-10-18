local addon={}
local ids={}; for i=1,1000 do ids[i*2]=i end
local reads=0
LibQuestieDB={flavor={name='Forever'},Enum={npcFlags={VENDOR=4}},
 RequireContract=function() return true end,
 Support={Get=function() return {private={areaIdToUiMapId='return {[38]=1432}'}} end},
 Npc={GetAllIds=function() return ids end,
  npcFlags=function() reads=reads+1; return 0 end,
  spawns=function() return {} end,name=function() return 'Synthetic' end},
 Item={GetAllIds=function() return ids end,class=function() reads=reads+1; return 1 end,
  subClass=function() return 0 end,vendors=function() return nil end}}
assert(loadfile('Data/NpcCatalog.lua'))('ErrandMaster',addon)
local c=addon.npcs
assert(c:Initialize())
local status=c:Status()
assert(status.normalizing and status.normalizedEntries<=80,
 'initialization must not synchronously normalize an entire large provider list')
assert(reads==0 and not c:IsReady())
local calls=0
while c:Status().normalizing do
 local before=c:Status().normalizedEntries
 assert(not c:Step(7),'normalization cannot expose a ready catalog')
 local after=c:Status().normalizedEntries
 assert(after-before<=7,'each normalization step must honor its entry budget')
 assert(reads==0,'record indexing starts only after ID normalization finishes')
 calls=calls+1; assert(calls<1000)
end
assert(c:Status().total==1000 and c:Status().itemsTotal==1000)
assert(c:Status().issues['npc-ids-sparse'] and c:Status().issues['item-ids-sparse'])
while not c:Step(200) do end
assert(reads==2000 and c:IsReady(),'all valid IDs must be indexed exactly once')
assert(c:Initialize() and c:Status().normalizing)
LibQuestieDB.Npc.GetAllIds=function() return {1} end
LibQuestieDB.Item.GetAllIds=function() return {} end
assert(c:Initialize())
assert(not c:Status().normalizing and c:Step(20),'reinitialize must discard suspended old normalization')
assert(c:Status().total==1)
print('incremental provider normalization budgets, completeness and reset passed')
