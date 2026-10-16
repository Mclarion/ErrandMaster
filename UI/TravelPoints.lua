-- Character-owned map pin and coordinate favorites; never touch Blizzard's waypoint.
local _, addon = ...
addon.travelPoints = {}
local travel = addon.travelPoints
local EXAMPLE = "Example: Camp; 1412; 52.3; 48.9 (map ID; X%; Y%)."
local function plain(value)
  local ok, valid = pcall(function()
    if type(issecretvalue)=="function" and issecretvalue(value) then return false end
    if type(value)=="table" and type(issecrettable)=="function" and
        issecrettable(value) then return false end
    return true
  end)
  return ok and valid
end
local function integer(value)
  return plain(value) and type(value)=="number" and value==value and
    value>=1 and value<=1000000 and value%1==0
end
local function coordinate(value)
  return plain(value) and type(value)=="number" and value==value and
    value>=0 and value<=1
end
local function percent(raw)
  if not raw:match("^%d+%.?%d*$") and not raw:match("^%.%d+$") then return end
  local number=tonumber(raw)
  if number and number>=0 and number<=100 then return number/100 end
end
local function refresh()
  if type(addon.Refresh)=="function" then pcall(addon.Refresh,addon) end
end
function travel:ParseFavorite(raw)
  if not plain(raw) or type(raw)~="string" or #raw>160 then return nil end
  local name, map, east, north=raw:match("^%s*(.-)%s*;%s*(.-)%s*;%s*(.-)%s*;%s*(.-)%s*$")
  if not name or #name<1 or #name>80 or not name:match("%S") or
      name:find("[;|%c]") or not map:match("^%d+$") then return nil end
  local id=tonumber(map)
  local x,y=percent(east),percent(north)
  if not integer(id) or not x or not y then return nil end
  return {name=name,mapID=id,x=x,y=y,category="Custom",scope="character",
    origin="manual",favorite=true}
end
function travel:AddFavorite(raw)
  local input=self:ParseFavorite(raw)
  if not input then return nil, EXAMPLE end
  if not addon.errands or type(addon.errands.Add)~="function" then
    return nil,"Favorites are unavailable. "..EXAMPLE
  end
  local ok, item=pcall(addon.errands.Add,addon.errands,input)
  if not ok or not item then return nil,"Could not save favorite. "..EXAMPLE end
  refresh()
  return item
end
function travel:Favorites()
  local items={}
  if not addon.errands or type(addon.errands.All)~="function" then return items end
  local ok, all=pcall(addon.errands.All,addon.errands)
  if not ok or not plain(all) or type(all)~="table" then return items end
  for i=1,math.min(#all,200) do
    local item=all[i]
    local valid, favorite, completed=pcall(function()
      return item.favorite,item.completed
    end)
    if valid and favorite==true and completed~=true then items[#items+1]=item end
  end
  return items
end
function travel:RemoveFavorite(id)
  if not plain(id) or type(id)~="string" or not id:match("^em%-%d+$") or
      not addon.errands or
      type(addon.errands.Update)~="function" then return false end
  for _,item in ipairs(self:Favorites()) do
    local ok, matches=pcall(function() return item.id==id end)
    if ok and matches then
      local changed=pcall(addon.errands.Update,addon.errands,id,{favorite=false})
      if changed then refresh() end
      return changed
    end
  end
  return false
end
function travel:CurrentWaypoint(includeCompleted)
  if addon.errands and type(addon.errands.All)=="function" then
    local ok,all=pcall(addon.errands.All,addon.errands)
    if ok and plain(all) and type(all)=="table" then
      for i=#all,1,-1 do
        local item=all[i]
        local valid, kind, scope, map, x, y, completed=pcall(function()
          return item.category,item.scope,item.mapID,item.x,item.y,item.completed
        end)
        if valid and kind=="Waypoint" and scope=="character" and integer(map) and
            coordinate(x) and coordinate(y) and (includeCompleted or completed~=true) then
          return item
        end
      end
    end
  end
  if includeCompleted then return end
  local apiOK,method=pcall(function() return C_Map and C_Map.GetUserWaypoint end)
  if not apiOK or not plain(method) or type(method)~="function" then return end
  local ok,point=pcall(method)
  if not ok or not plain(point) or type(point)~="table" then return end
  local read,map,x,y=pcall(function()
    return point.uiMapID,point.position.x,point.position.y
  end)
  if read and integer(map) and coordinate(x) and coordinate(y) then
    return {source="native",mapID=map,x=x,y=y,name="Current map waypoint"}
  end
end
function travel:Pin(map,x,y)
  if not integer(map) or not coordinate(x) or not coordinate(y) or
      not addon.errands then return nil,"Invalid waypoint map or coordinates." end
  local existing=self:CurrentWaypoint(true)
  local ok, item
  if existing and type(addon.errands.Update)=="function" then
    ok,item=pcall(addon.errands.Update,addon.errands,existing.id,
      {mapID=map,x=x,y=y,name="Map waypoint"})
    if ok and item and type(addon.errands.Complete)=="function" then
      pcall(addon.errands.Complete,addon.errands,item.id,false)
    end
  elseif type(addon.errands.Add)=="function" then
    ok,item=pcall(addon.errands.Add,addon.errands,{name="Map waypoint",
      category="Waypoint",scope="character",origin="manual",mapID=map,x=x,y=y})
  end
  if not ok or not item then return nil,"Could not save waypoint." end
  refresh()
  return item
end
function travel:SelectCurrent()
  local point=self:CurrentWaypoint()
  if not point then return false,"No saved map waypoint. Open Travel, Waypoint, Pin." end
  if point.source=="native" then
    local saved,reason=self:Pin(point.mapID,point.x,point.y)
    if not saved then return false,reason end
    point=saved
  end
  if type(addon.ActivateTarget)~="function" then return false,"Targets are unavailable." end
  local ok, selected=pcall(addon.ActivateTarget,addon,point.id)
  if not ok or selected~=true then return false,"Could not select the saved waypoint." end
  return true
end
function travel:OpenFavoriteForm()
  if not plain(StaticPopupDialogs) or type(StaticPopupDialogs)~="table" or
      type(StaticPopup_Show)~="function" then
    addon:Print("Coordinate form unavailable. "..EXAMPLE)
    return false
  end
  local key="ERRANDMASTER_FAVORITE_COORDINATES"
  StaticPopupDialogs[key]={
    text="Add favorite: Name; map ID; X; Y. "..EXAMPLE,
    button1="Add",button2="Cancel",hasEditBox=true,maxLetters=160,
    timeout=0,whileDead=true,hideOnEscape=true,
    OnAccept=function(dialog)
      local ok,raw=pcall(function() return dialog.editBox:GetText() end)
      local saved,message=self:AddFavorite(ok and raw or nil)
      addon:Print(saved and "Favorite coordinates saved. Open Travel, Favorites to select it." or message)
    end,
  }
  local ok=pcall(StaticPopup_Show,key)
  if not ok then addon:Print("Coordinate form unavailable. "..EXAMPLE) end
  return ok
end
