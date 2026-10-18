local addon={}
for _,path in ipairs({'Core/Database.lua','Data/ServiceLocations.lua','Data/Discovery.lua'}) do
 assert(loadfile(path))('ErrandMaster',addon)
end
ErrandMasterDB=nil
addon.db:Initialize('Synthetic-Realm')
addon.db.data.settings.discoverServices=true
addon.Position=function() return 1432,.35,.48 end
addon.Refresh=function() end
InCombatLockdown=function() return false end
UnitName=function() return 'Synthetic supplies' end
GetMerchantNumItems=function() return 1 end
GetMerchantItemLink=function() return 'item:1001' end
GetItemInfoInstant=function() return 1001,'','','',1,0,5 end
CanMerchantRepair=function() error('optional API failed') end
local ok,report=addon.discovery:HandleEvent('MERCHANT_SHOW')
assert(ok,'optional repair failure must not discard readable merchant evidence')
local found={}
for _,item in ipairs(addon.locations:All()) do found[item.category]=true end
assert(found.Vendor and found['Food Vendor'] and not found.Repair)
assert(report and report.partial and report.failures.Repair=='unavailable',
 'partial repair evidence must be exposed')
print('discovery preserves independent evidence when repair API fails')
local add=addon.locations.Add
addon.locations.Add=function(self,category,...)
 if category=='Food Vendor' then return nil,'storage full' end
 return add(self,category,...)
end
CanMerchantRepair=function() return true end
ok,report=addon.discovery:HandleEvent('MERCHANT_SHOW')
assert(ok and report.partial and report.failures['Food Vendor']=='not-saved',
 'failed specialty write must be reported rather than claimed complete')
assert(report.saved.Vendor and report.saved.Repair and not report.saved['Food Vendor'])
addon.locations.Add=function() return nil,'storage full' end
ok,report=addon.discovery:HandleEvent('MERCHANT_SHOW')
assert(not ok and report.partial and next(report.saved)==nil,
 'full storage must report no observations saved')
print('discovery partial storage result identifies saved and failed categories')
addon.locations.Add=add
GetMerchantNumItems=function() return 3 end
GetMerchantItemLink=function(index) if index==2 then return nil end return 'item:'..(1000+index) end
GetItemInfoInstant=function(id)
 if id==1003 then error('uncached item') end
 return id,'','','',1,0,5
end
ok,report=addon.discovery:HandleEvent('MERCHANT_SHOW')
assert(ok and report.saved['Food Vendor'] and report.partial,
 'partial inventory reads must retain good evidence and disclose unknown coverage')
assert(report.failures['Inventory/item-link']=='1' and report.failures['Inventory/item-info']=='1')
GetMerchantNumItems=function() return 201 end
GetMerchantItemLink=function() return 'item:1001' end
GetItemInfoInstant=function(id) return id,'','','',1,0,5 end
ok,report=addon.discovery:HandleEvent('MERCHANT_SHOW')
assert(ok and report.failures['Inventory/scan-cap']=='1','inventory truncation must be explicit')
GetMerchantNumItems=function() return 0 end
CanMerchantRepair=nil
ok,report=addon.discovery:HandleEvent('MERCHANT_SHOW')
assert(ok and report.saved.Vendor and not report.saved.Repair and report.partial and
  report.failures.Repair=='unavailable',
  'missing repair API is unknown, even with a readable empty merchant inventory')
CanMerchantRepair=function() return false end
ok,report=addon.discovery:HandleEvent('MERCHANT_SHOW')
assert(ok and not report.partial,'a readable empty merchant with known non-repair is not an API error')
GetMerchantItemLink=nil
ok,report=addon.discovery:HandleEvent('MERCHANT_SHOW')
assert(ok and report.failures['Inventory/api']=='1','missing optional inventory API must not hide partial coverage')
print('merchant inventory failures and scan bounds are reported independently')
