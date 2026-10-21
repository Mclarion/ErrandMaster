-- Persistent observed taxi evidence is per character/build, independent of trails.
local addon={}
GetBuildInfo=function() return '11.2.7','123','date',67890 end
WOW_PROJECT_ID=1
local clock=100
GetTime=function() return clock end
UnitOnTaxi=function() return false end
C_Map={GetMapInfo=function(id) return {name=({[10]='Start',[20]='Finish'})[id]} end}
NumTaxiNodes=function() return 2 end
TaxiNodeGetType=function(i) return i==1 and 'CURRENT' or 'REACHABLE' end
TaxiNodeName=function(i) return i==1 and 'Start' or 'Finish' end
assert(loadfile('Core/Database.lua'))('ErrandMaster',addon)
assert(loadfile('Data/TaxiAdvice.lua'))('ErrandMaster',addon)
local arrivalX,arrivalY,arrivalCheck
local function login(character)
  addon.db:Initialize(character)
  addon.taxiAdvice:Bind()
  local taxi=addon.taxiAdvice
  if not taxi.testWrapped then
    taxi.testWrapped=true
    local originalDepart,originalLanded=taxi.Depart,taxi.Landed
    taxi.Depart=function(self)
      originalDepart(self)
      if self.pending then self:Sample(self.pending.originMapID,self.pending.originX,
        self.pending.originY,function(m,x,y)
          return addon.navigation:WorldPosition(m,x,y) end) end
    end
    taxi.Landed=function(self,m,x,y)
      if self.pending and type(x)=='number' and x==x and type(y)=='number' then
        arrivalX,arrivalY=x,y
        local target=clock
        while self.pending and target-self.pending.last.time>10 do
          clock=self.pending.last.time+10
          self:Sample(self.pending.originMapID,math.min(.95,self.pending.originX+.05),self.pending.originY,
            function(a,b,c) return addon.navigation:WorldPosition(a,b,c) end)
        end
        clock=target
        if self.pending then self:Sample(m,x,y,function(a,b,c)
          return addon.navigation:WorldPosition(a,b,c) end) end
      end
      arrivalCheck=true
      local result=originalLanded(self,m,x,y)
      arrivalCheck=false
      return result
    end
  end
  return taxi
end
local function projection(map,x,y) return 1,y*1000,(map==10 and x or x+1)*1000 end
local target={mapID=20,x=.9,y=.1}
local taxi=login('A-Realm')
addon.navigation={WorldPosition=function(_,m,x,y) return 1,y*100,x*100 end}
addon.transportCatalog={ServiceCandidatesOnMap=function(_,m)
 if arrivalCheck and (m==20 or m==10) then
   return {{name='Arrival',mapID=m,x=arrivalX,y=arrivalY}} end
 return {}
end}

assert(taxi:IsEnabled() and not addon.db.data.settings.trailRecording)
assert(not addon.db:TrailBucket().enabled,'transport must not enable ground trails')
assert(taxi:Capture())
taxi:CaptureOrigin(10,.1,.1)
taxi:SelectedNode(2,10,.1,.1)
assert(not addon.db.data.characters['A-Realm'].transport or
  #addon.db.data.characters['A-Realm'].transport.legs==0,
  'selection alone must not save evidence')
taxi:Depart()
clock=130
assert(taxi:Landed(20,.7,.1))
local store=addon.db.data.characters['A-Realm'].transport
assert(store.build=='1:123:67890','scope must retain the numeric client project identity')
assert(store and #store.legs==1 and store.legs[1].seconds==30 and store.legs[1].samples==1)
assert(store.legs[1].destinationX==.7 and store.legs[1].destinationY==.1 and
 store.legs[1].originX==.1 and store.legs[1].originY==.1 and
 store.legs[1].timing=='movement-tick-sampled')
local first=assert(taxi:Recommend(10,.1,.1,target,projection))
assert(first.timing=='movement-tick-sampled' and first.viaYards==200 and first.mapID==10 and first.x==.1,
 'approach starts at observed origin and connector starts at actual landing')
-- Re-execute module (a UI reload) using the same SavedVariables.
assert(loadfile('Data/TaxiAdvice.lua'))('ErrandMaster',addon)
taxi=login('A-Realm')
assert(taxi:Recommend(10,.1,.1,target,projection), 'learned endpoints survive reload without taxi UI')
assert(not taxi.open and not taxi.selection and not taxi.pending)
login('B-Realm')
assert(not taxi:Recommend(10,.1,.1,target,projection),'character isolation')
login('A-Realm')
assert(taxi:SetEnabled(false) and not taxi:Recommend(10,.1,.1,target,projection))
assert(not addon.db:TrailBucket().enabled)
assert(loadfile('Data/TaxiAdvice.lua'))('ErrandMaster',addon)
taxi=login('A-Realm')
assert(not taxi:IsEnabled() and not taxi:Recommend(10,.1,.1,target,projection))
assert(taxi:SetEnabled(true) and taxi:Recommend(10,.1,.1,target,projection))
assert(taxi:ClearLearned() and #store.legs==0 and not taxi:Recommend(10,.1,.1,target,projection))
-- Build mismatch cannot be reused; bad persisted rows fail closed without damage.
store.legs[1]={originNode='Start',nodeName='Finish',originMapID=10,originX=.1,originY=.1,
 destinationMapID=20,destinationX=.1,destinationY=.1,seconds=30,samples=1,source='observed-taxi'}
GetBuildInfo=function() return '11.2.8','123','date',67891 end
assert(taxi:Bind() and not taxi:Recommend(10,.1,.1,target,projection))
GetBuildInfo=function() return '11.2.7','123','date',67890 end
store.legs[1].originX=1/0
assert(not taxi:Bind() and not taxi:Recommend(10,.1,.1,target,projection))
assert(store.legs[1].originX==1/0,'invalid saved evidence must not be modified')
store.legs={}
assert(taxi:Bind())
assert(taxi:Capture())
taxi:CaptureOrigin(10,.1,.1);taxi:SelectedNode(2,10,.1,.1);taxi:Depart()
clock=150;assert(taxi:Landed(20,.1,.1))
assert(store.legs[1].samples==1 and store.legs[1].seconds==20)
assert(taxi:Capture())
taxi:CaptureOrigin(10,.1,.1);taxi:SelectedNode(2,10,.1,.1);taxi:Depart()
clock=190;assert(taxi:Landed(20,.1,.1))
assert(#store.legs==1 and store.legs[1].samples==1 and store.legs[1].seconds==20,
 'longer observation does not replace the fastest duration')
-- Same labels can describe separate directed endpoints; neither replaces the other.
assert(taxi:Capture())
taxi:CaptureOrigin(10,.8,.1);taxi:SelectedNode(2,10,.8,.1);taxi:Depart()
clock=220;assert(taxi:Landed(20,.8,.1))
assert(#store.legs==2 and store.legs[1].originX==.1 and store.legs[2].originX==.8,
 'distant same-name endpoints must stay independent')
assert(taxi:Recommend(10,.8,.1,target,projection).x==.8)
assert(loadfile('Data/TaxiAdvice.lua'))('ErrandMaster',addon)
taxi=login('A-Realm')
assert(#store.legs==2 and taxi:Recommend(10,.8,.1,target,projection).x==.8,
 'both same-name endpoints survive reload')
-- Reverse flight is not evidence for the forward direction.
local reverseTarget={mapID=10,x=.1,y=.1}
assert(not taxi:Recommend(20,.8,.1,reverseTarget,projection))
TaxiNodeName=function(i) return i==1 and 'Finish' or 'Start' end
assert(taxi:Capture())
taxi:CaptureOrigin(20,.8,.1);taxi:SelectedNode(2,20,.8,.1);taxi:Depart()
clock=240;assert(taxi:Landed(10,.1,.1))
assert(#store.legs==3 and taxi:Recommend(20,.8,.1,reverseTarget,projection).mapID==20)
assert(taxi:Recommend(10,.8,.1,target,projection).mapID==10,
 'reverse observation must not overwrite forward endpoints')
assert(loadfile('Data/TaxiAdvice.lua'))('ErrandMaster',addon)
taxi=login('A-Realm')
assert(#store.legs==3 and taxi:Recommend(20,.8,.1,reverseTarget,projection).mapID==20)
TaxiNodeName=function(i) return i==1 and 'Start' or 'Finish' end
-- No valid landing means no record, even if a destination label is known.
assert(taxi:Capture())
taxi:CaptureOrigin(10,.5,.1);taxi:SelectedNode(2,10,.5,.1);taxi:Depart()
clock=250;assert(not taxi:Landed(20,nil,.1) and #store.legs==3)
assert(taxi:Capture())
taxi:CaptureOrigin(10,.5,.1);taxi:SelectedNode(2,10,.5,.1);taxi:Depart()
clock=260;assert(not taxi:Landed(20,0/0,.1) and #store.legs==3,
 'invalid normalized landing must not be replaced with a map or node center')
print('transport persistence lifecycle passed')
