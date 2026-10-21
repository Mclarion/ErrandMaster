-- Isolated WoW UI mock. No player data, gameplay calls or client launch.
return function()
  local frames={}
  local function frame()
    local f={scripts={},shown=false}
    setmetatable(f,{__index=function(_,key)
      if key=='CreateTexture' then return function(_,name,layer,template,sublevel)
        assert(layer==nil or ({BACKGROUND=true,BORDER=true,ARTWORK=true,OVERLAY=true,HIGHLIGHT=true})[layer],
          'invalid texture draw layer: '..tostring(layer))
        local region=frame();region.layer=layer;region.sublevel=sublevel or 0;return region
      end end
      if key=='CreateFontString' then return function() return frame() end end
      if key=='CreateAnimationGroup' then return function()
        return {CreateAnimation=function() return frame() end,Stop=function() end,Play=function() end}
      end end
      if key=='SetScript' then return function(self,name,fn) self.scripts[name]=fn end end
      if key=='SetSize' then return function(self,w,h) self.w,self.h=w,h end end
      if key=='SetWidth' then return function(self,w) self.w=w end end
      if key=='SetHeight' then return function(self,h) self.h=h end end
      if key=='SetScale' then return function(self,s) self.scale=s end end
      if key=='GetWidth' then return function(self) return self.w end end
      if key=='GetHeight' then return function(self) return self.h end end
      if key=='SetPoint' then return function(self,...) self.point={...} end end
      if key=='SetText' then return function(self,v) self.text=v end end
      if key=='GetText' then return function(self) return self.text end end
      if key=='SetTexture' then return function(self,v) self.texture=v end end
      if key=='SetAlpha' then return function(self,v) self.alpha=v end end
      if key=='SetDesaturated' then return function(self,v) self.desaturated=v end end
      if key=='SetBlendMode' then return function(self,v) self.blend=v end end
      if key=='SetRotation' then return function(self,v) self.rotation=v end end
      if key=='SetTexCoord' then return function(self,...)
        self.uv={...}; assert(#self.uv==4 or #self.uv==8)
        for _,v in ipairs(self.uv) do assert(type(v)=='number' and v==v) end
      end end
      if key=='EnableKeyboard' then return function(self,v) self.keyboard=v end end
      if key=='EnableMouse' then return function(self,v) self.mouse=v end end
      if key=='SetPropagateKeyboardInput' then return function(self,v) self.propagate=v end end
      if key=='SetVertexColor' then return function(self,...) self.color={...} end end
      if key=='Show' then return function(self) self.shown=true end end
      if key=='Hide' then return function(self) self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end end
      if key=='IsShown' then return function(self) return self.shown end end
      return function() end
    end})
    f.TitleText={SetText=function() end}
    frames[#frames+1]=f
    return f
  end
  UIParent=frame(); UIParent.w,UIParent.h=1920,1080
  local scale=1
  UIParent.GetEffectiveScale=function() return scale end
  CreateFrame=function() return frame() end
  UISpecialFrames={}
  local x,y=960,540
  GetCursorPosition=function() return x*scale,y*scale end
  InCombatLockdown=function() return false end
  local time=0
  GetTime=function() return time end
  local kind,id,location
  GetCursorInfo=function()
    if kind=='spell' then return kind,88,nil,id end
    return kind,id
  end
  C_Cursor={GetCursorItem=function() return location end}
  C_Item={GetItemID=function(v) assert(v==location); return id end}
  local cursorReset=0
  SetCursor=function() cursorReset=cursorReset+1 end
  CastSpell=function() error('unsafe cast') end
  RunMacro=function() error('unsafe macro') end
  UseItemByName=function() error('unsafe use') end
  local notices,opened={},{}
  local addon={ui={OpenCategory=function(_,name) opened[#opened+1]=name end},
    Print=function(_,message) notices[#notices+1]=message end,Refresh=function() end}
  assert(loadfile('Core/Database.lua'))('ErrandMaster',addon)
  ErrandMasterDB=nil
  addon.db:Initialize('Wheel-Fixture')
  assert(loadfile('UI/WheelGeometry.lua'))('ErrandMaster',addon)
  assert(loadfile('UI/RadialMenu.lua'))('ErrandMaster',addon)
  local wheel=addon.radial
  local control={addon=addon,wheel=wheel,frames=frames,notices=notices,opened=opened}
  function control:cursor(nx,ny) x,y=nx,ny end
  function control:scale(v) scale=v end
  function control:time(v) time=v end
  function control:payload(k,v) kind,id=k,v; location={} end
  function control:hit(index,level,factor)
    local tier=wheel.tiers[level or #wheel.tiers]
    local r=tier.innerRadius+(tier.outerRadius-tier.innerRadius)*(factor or .5)
    self:cursor(wheel.centerX+r*math.cos(tier.angles[index]),
      wheel.centerY+r*math.sin(tier.angles[index]))
    return wheel:IndexAtCursor()
  end
  function control:click(index,level)
    assert(self:hit(index,level)==index)
    wheel.frame.scripts.OnMouseDown(wheel.frame,'LeftButton')
  end
  function control:root()
    self:cursor(UIParent.w/2,UIParent.h/2)
    assert(wheel:Open())
  end
  -- Existing regression paths use an explicitly retained player layout.
  function control:legacyLayout()
    local categories={'Bank','Auction House','Repair','Vendor','Mailbox',
      'Trainer','Travel','Custom','Quests','Skills','Items'}
    local slots={}
    for i,category in ipairs(categories) do slots[i]={type='category',category=category} end
    addon.db.data.settings.wheelSlots=slots
    return slots
  end
  function control:button(label)
    for _,f in ipairs(frames) do
      if f.text==label and f.scripts.OnClick then return f end
    end
    error('missing button '..label)
  end
  function control:resets() return cursorReset end
  return control
end
