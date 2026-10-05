-- Server-only queue shared by every public lobby in the experience.
-- Services are injected so cross-server races and failures can be tested locally.
local Matchmaker={};Matchmaker.__index=Matchmaker
function Matchmaker.new(services)
    return setmetatable({S=services,LocalTickets={}},Matchmaker)
end
function Matchmaker.QueueKey(ticket)
    if ticket.Mode=='Ranked'then return 'Ranked_'..math.floor((ticket.Rank or 0)/100)end
    local level=ticket.Level or 1;return 'PvP_'..(level<10 and 1 or level<25 and 2 or level<50 and 3 or 4)
end
function Matchmaker:Queue(ticket)return self.S.QueueFor and self.S.QueueFor(Matchmaker.QueueKey(ticket))or self.S.Queue end
function Matchmaker.Compatible(a,b,now)
    local modeA,modeB=a.Mode or 'PvP',b.Mode or 'PvP'
    if modeA~=modeB then return false end
    if modeA=='Ranked'then
        local age=math.max(now-a.JoinedAt,now-b.JoinedAt)
        local window=age>=60 and 300 or age>=30 and 200 or 100
        return math.abs((a.Rank or 0)-(b.Rank or 0))<=window
    end
    local function band(level)return level<10 and 1 or level<25 and 2 or level<50 and 3 or 4 end
    return band(a.Level or 1)==band(b.Level or 1)
end
function Matchmaker:Join(userId,jobId,profile,mode)
    local s=self.S;local key=tostring(userId)
    local ticket={UserId=userId,JobId=jobId,Token=s.Guid(),JoinedAt=s.Now(),State='Queued',Mode=mode=='Ranked'and 'Ranked'or 'PvP',Rank=profile and profile.Rank or 0,Level=profile and profile.Level or 1}
    s.Tickets:SetAsync(key,ticket,90)
    self:Queue(ticket):SetAsync(key,ticket,90,ticket.JoinedAt);self.LocalTickets[userId]=ticket
    return ticket.Token
end
function Matchmaker:Renew(userId,token)
    local s=self.S;local key=tostring(userId)
    local value=s.Tickets:UpdateAsync(key,function(old)
        if not old or old.Token~=token then return nil end
        if old.State=='Claimed' and old.ClaimUntil<s.Now()then old.State='Queued';old.MatchId=nil;old.ClaimUntil=nil end
        return old
    end,90)
    if value and value.Token==token and value.State=='Queued'then self:Queue(value):SetAsync(key,value,90,value.JoinedAt)end
    return value
end
function Matchmaker:Cancel(userId,token)
    local s=self.S;local key=tostring(userId)
    local value=s.Tickets:UpdateAsync(key,function(old)
        if not old or old.Token~=token or old.State~='Queued'then return nil end
        old.State='Cancelled';return old
    end,15)
    if value and value.Token==token and value.State=='Cancelled'then self:Queue(value):RemoveAsync(key);self.LocalTickets[userId]=nil;return true end
    return false
end
function Matchmaker:Claim(ticket,matchId)
    local s=self.S
    local value=s.Tickets:UpdateAsync(tostring(ticket.UserId),function(old)
        if not old or old.Token~=ticket.Token or old.State~='Queued'then return nil end
        old.State='Claimed';old.MatchId=matchId;old.ClaimUntil=s.Now()+60;return old
    end,90)
    return value and value.Token==ticket.Token and value.State=='Claimed'and value.MatchId==matchId
end
function Matchmaker:Release(ticket,matchId)
    local s=self.S
    s.Tickets:UpdateAsync(tostring(ticket.UserId),function(old)
        if not old or old.Token~=ticket.Token or old.MatchId~=matchId then return nil end
        old.State='Queued';old.MatchId=nil;old.ClaimUntil=nil;old.AccessCode=nil;old.PrivateId=nil;return old
    end,90)
end
function Matchmaker:Allocate(metadata)
    local s=self.S;local code,privateId=s.Reserve()
    metadata.PrivateId=privateId;metadata.CreatedAt=s.Now()
    s.Matches:SetAsync(privateId,metadata,7200)
    return code,privateId
end
function Matchmaker:Pair(a,b,matchId)
    local s=self.S
    local metadata={MatchId=matchId,Mode=a.Mode or 'PvP',MapId=s.RandomMap(),Users={a.UserId,b.UserId},State='Committing'}
    local code,privateId
    local ok=pcall(function()
        code,privateId=self:Allocate(metadata)
        for _,ticket in {a,b}do
            local value=s.Tickets:UpdateAsync(tostring(ticket.UserId),function(old)
                if not old or old.Token~=ticket.Token or old.MatchId~=matchId or old.State~='Claimed'then return nil end
                old.State='Matched';old.AccessCode=code;old.PrivateId=privateId;return old
            end,180)
            assert(value and value.MatchId==matchId and value.State=='Matched','Queue changed before commit')
        end
        metadata.State='Ready';s.Matches:SetAsync(privateId,metadata,7200)
    end)
    if not ok then
        -- Neither lobby teleports until both tickets have committed.
        for _,ticket in {a,b}do pcall(function()self:Release(ticket,matchId)end)end
        return false
    end
    for _,ticket in {a,b}do pcall(function()self:Queue(ticket):RemoveAsync(tostring(ticket.UserId))end)end
    return true
end
function Matchmaker:Pump()
    local candidates={}
    if self.S.QueueFor then
        local keys,seen={},{}
        for _,ticket in self.LocalTickets do
            if ticket.Mode=='Ranked'then local band=math.floor(ticket.Rank/100);for offset=-3,3 do if band+offset>=0 then keys['Ranked_'..(band+offset)]=true end end
            else keys[Matchmaker.QueueKey(ticket)]=true end
        end
        for key in keys do for _,item in self.S.QueueFor(key):GetRangeAsync(Enum.SortDirection.Ascending,100)do
            if not seen[item.key]then table.insert(candidates,item);seen[item.key]=true end
        end end
        table.sort(candidates,function(a,b)return a.value.JoinedAt<b.value.JoinedAt or a.value.JoinedAt==b.value.JoinedAt and a.value.UserId<b.value.UserId end)
    else candidates=self.S.Queue:GetRangeAsync(Enum.SortDirection.Ascending,100)end
    local used={};local now=self.S.Now()
    for i,item in candidates do
        local a=item.value;if used[a.UserId]then continue end
        local best,distance=nil,math.huge
        for j=i+1,#candidates do
            local b=candidates[j].value
            if not used[b.UserId]and a.UserId~=b.UserId and Matchmaker.Compatible(a,b,now)then
                local gap=math.abs((a.Rank or 0)-(b.Rank or 0))
                if gap<distance then best,distance=b,gap end
            end
        end
        if best then
            local matchId=self.S.Guid()
            if self:Claim(a,matchId)then
                used[a.UserId]=true
                if self:Claim(best,matchId)then used[best.UserId]=true;self:Pair(a,best,matchId)else self:Release(a,matchId)end
            end
        end
    end
end
function Matchmaker:Assignment(userId,token)
    local value=self.S.Tickets:GetAsync(tostring(userId))
    if value and value.Token==token and value.State=='Matched'then
        local metadata=self.S.Matches:GetAsync(value.PrivateId)
        if metadata and metadata.MatchId==value.MatchId and metadata.State=='Ready'then self.LocalTickets[userId]=nil;return value end
    end
    return nil
end
function Matchmaker:Solo(userId,definition,mapId,difficulty)
    local metadata={MatchId=self.S.Guid(),Mode='AI',Definition=definition,MapId=mapId,Difficulty=difficulty,Users={userId},State='Ready'}
    local code,privateId=self:Allocate(metadata)
    return {AccessCode=code,PrivateId=privateId,MatchId=metadata.MatchId}
end
return Matchmaker
