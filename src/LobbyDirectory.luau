-- Shared level-band lobbies with capacity claims and a short creation lease.
local P=require(script.Parent.Progression)
local Directory={};Directory.__index=Directory
function Directory.new(services)return setmetatable({S=services},Directory)end
function Directory:Claim(id,userId,band)
    local s=self.S;local now=s.Now();local accepted=false
    local entry=s.Registry:UpdateAsync(id,function(old)
        accepted=false;if not old or old.Band~=band or old.Expires<=now then return nil end
        old.Pending=old.Pending or {};for key,expiry in old.Pending do if expiry<=now then old.Pending[key]=nil end end
        local count=old.Count or 0;for _ in old.Pending do count+=1 end
        local key=tostring(userId)
        if not old.Pending[key] and count>=old.Capacity then return nil end
        old.Pending[key]=now+45;accepted=true;return old
    end,90)
    return accepted and entry or nil
end
function Directory:Find(level,userId)
    local s=self.S;local band=P.Band(level)
    for _,item in s.Registry:GetRangeAsync(Enum.SortDirection.Ascending,100)do
        local value=item.value
        if value.Band==band then local found=self:Claim(item.key,userId,band);if found then return found end end
    end
    local token=s.Guid();local acquired=false
    s.Locks:UpdateAsync(band,function(old)
        acquired=false;if old and old.Until>s.Now()then return nil end
        acquired=true;return {Token=token,Until=s.Now()+15}
    end,20)
    if not acquired then return nil end
    local ok,entry=pcall(function()
        local code,id=s.Reserve();local value={Mode='Lobby',Band=band,PrivateId=id,AccessCode=code,Capacity=s.Capacity,Count=0,Pending={[tostring(userId)]=s.Now()+45},Expires=s.Now()+60,State='Ready'}
        s.Matches:SetAsync(id,value,7200);s.Registry:SetAsync(id,value,90,s.Now());return value
    end)
    s.Locks:UpdateAsync(band,function(old)if old and old.Token==token then old.Until=0;return old end;return nil end,1)
    if not ok then error(entry)end;return entry
end
function Directory:Advertise(metadata,users)
    local s=self.S;local now=s.Now()
    local entry=s.Registry:UpdateAsync(metadata.PrivateId,function(old)
        local value=old or table.clone(metadata);value.Pending=value.Pending or {}
        for key,expiry in value.Pending do if expiry<=now or users[tonumber(key)]then value.Pending[key]=nil end end
        local count=0;for _ in users do count+=1 end
        value.Count=count;value.Expires=now+45;return value
    end,90)
    s.Matches:SetAsync(metadata.PrivateId,metadata,7200)
    return entry
end
return Directory
