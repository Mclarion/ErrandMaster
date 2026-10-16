param(
 [Parameter(Mandatory=$true)][string]$Archive,
 [Parameter(Mandatory=$true)][string]$Manifest
)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$root='B:\Blizzard\World of Warcraft\_classic_beta_'
$interface=Join-Path $root 'Interface'
$target=Join-Path $interface 'AddOns\ErrandMaster'
$provider=Join-Path $interface 'AddOns\QuestieDB'
$expected=Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
function Assert-Stopped {
 if((Get-Item (Join-Path $root 'WowB.exe')).VersionInfo.FileVersion -ne '1.60.1.70425'){throw 'Unexpected build'}
 if(Get-Process Wow,WowB -ErrorAction SilentlyContinue){throw 'World of Warcraft is running; installation refused'}
}
function Inventory([string]$folder){
 if(-not(Test-Path -LiteralPath $folder -PathType Container)){throw "Missing $folder"}
 $actual=@{}
 foreach($item in Get-ChildItem -LiteralPath $folder -Recurse -File -Force){
  $relative=$item.FullName.Substring($folder.Length+1).Replace('\','/')
  $actual[$relative]=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
 }
 return $actual
}
function Assert-Inventory([string]$folder,$files){
 $actual=Inventory $folder;$properties=@($files.PSObject.Properties)
 if($actual.Count -ne $properties.Count){throw "Inventory count mismatch at $folder"}
 foreach($entry in $properties){if(-not $actual.ContainsKey($entry.Name) -or $actual[$entry.Name] -ne $entry.Value){throw "Changed file: $($entry.Name)"}}
 return $actual.Count
}
Assert-Stopped
if((Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash -ne $expected.zipSHA256){throw 'Archive hash mismatch'}
$oldCount=Assert-Inventory $target $expected.old
$providerBefore=Inventory $provider
if($providerBefore.Count -lt 60){throw 'QuestieDB inventory unexpectedly small'}
$states=@(Get-ChildItem (Join-Path $root 'WTF\Account') -Filter AddOns.txt -Recurse -File -ErrorAction Stop)
if($states.Count -lt 1){throw 'No addon-state files'}
foreach($state in $states){
 if(@(Select-String -LiteralPath $state.FullName -Pattern '^ErrandMaster: enabled$').Count -ne 1 -or
    @(Select-String -LiteralPath $state.FullName -Pattern '^QuestieDB: enabled$').Count -ne 1){throw 'Addon state mismatch'}
}
$stateHashes=@{};foreach($state in $states){$stateHashes[$state.FullName]=(Get-FileHash $state.FullName -Algorithm SHA256).Hash}
$stage=Join-Path $interface ('.ErrandMaster-stage-'+[guid]::NewGuid().ToString('N'))
$backupRoot=Join-Path $interface 'ErrandMaster-backups'
$stamp=[DateTime]::UtcNow.ToString('yyyyMMddHHmmss')+'-'+[guid]::NewGuid().ToString('N')
$backup=Join-Path $backupRoot ('ErrandMaster-v0.6.0-rc1-'+$stamp)
$savedBackup=Join-Path $backupRoot ('SavedVariables-v0.6.0-rc1-'+$stamp)
$backedUp=$false
try{
 New-Item -ItemType Directory -Path $stage,$backupRoot,$savedBackup -Force|Out-Null
 Expand-Archive -LiteralPath $Archive -DestinationPath $stage
 $candidate=Join-Path $stage 'ErrandMaster';$newCount=Assert-Inventory $candidate $expected.new
 $accountRoot=Join-Path $root 'WTF\Account'
 $saved=@(Get-ChildItem $accountRoot -Recurse -File -Filter 'ErrandMaster.lua*'|Where-Object{$_.Directory.Name -eq 'SavedVariables' -and $_.Name -in @('ErrandMaster.lua','ErrandMaster.lua.bak')})
 foreach($file in $saved){
  if(($file.Attributes -band [IO.FileAttributes]::ReparsePoint)-ne 0){throw 'Linked SavedVariables file'}
  $copy=Join-Path $savedBackup $file.FullName.Substring($accountRoot.Length+1)
  New-Item -ItemType Directory -Path (Split-Path -Parent $copy) -Force|Out-Null
  Copy-Item -LiteralPath $file.FullName -Destination $copy
  if((Get-FileHash $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash $copy -Algorithm SHA256).Hash){throw 'SavedVariables backup mismatch'}
 }
 Assert-Stopped
 Move-Item -LiteralPath $target -Destination $backup;$backedUp=$true
 [void](Assert-Inventory $backup $expected.old)
 Move-Item -LiteralPath $candidate -Destination $target
 [void](Assert-Inventory $target $expected.new)
 $providerAfter=Inventory $provider
 if($providerAfter.Count -ne $providerBefore.Count){throw 'QuestieDB changed during upgrade'}
 foreach($key in $providerBefore.Keys){if($providerAfter[$key]-ne $providerBefore[$key]){throw 'QuestieDB changed during upgrade'}}
 foreach($state in $states){if((Get-FileHash $state.FullName -Algorithm SHA256).Hash -ne $stateHashes[$state.FullName]){throw 'Addon state changed during upgrade'}}
 Assert-Stopped
 Write-Output "Installed $newCount ErrandMaster files; backup $backup ($oldCount files); SavedVariables backup $savedBackup ($($saved.Count) files); QuestieDB and addon states unchanged; game stopped"
}catch{
 if($backedUp){
  if(Test-Path $target){Move-Item $target (Join-Path $backupRoot ('ErrandMaster-rejected-'+[guid]::NewGuid().ToString('N')))}
  Move-Item $backup $target
  [void](Assert-Inventory $target $expected.old)
 }
 throw
}finally{if(Test-Path $stage){Remove-Item $stage -Recurse -Force}}
