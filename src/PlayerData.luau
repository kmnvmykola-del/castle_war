-- Atomic profile changes preserve maps/preferences and deduplicate matches and receipts.
local P=require(script.Parent.Progression)
local Data={};Data.__index=Data
local function copy(d)return game:GetService('HttpService'):JSONDecode(game:GetService('HttpService'):JSONEncode(d))end
function Data.new(options)
    return setmetatable({S=options or {},Profiles={},Busy={},Errors={},BoardCache={}},Data)
end
function Data:Load(userId,force)
    if self.Profiles[userId]and not force then return self.Profiles[userId]end
    while self.Busy[userId]do task.wait()end;self.Busy[userId]=true
    local ok,value=true,nil
    if self.S.Store then ok,value=pcall(function()local options=Instance.new('DataStoreGetOptions');options.UseCache=false;return self.S.Store:GetAsync('Player_'..userId,options)end)
    elseif force then value=self.Profiles[userId]end
    self.Busy[userId]=nil
    if not ok then self.Errors[userId]='Не удалось загрузить профиль. Попробуй ещё раз.';return nil,self.Errors[userId]end
    local d=P.Normalize(value);self.Profiles[userId]=d;self.Errors[userId]=nil;return d
end
function Data:Update(userId,change)
    if not self.Profiles[userId]then return false,self.Errors[userId]or 'Профиль ещё загружается.'end
    while self.Busy[userId]do task.wait()end
    self.Busy[userId]=true;local outcome,rejected
    local ok,value=pcall(function()
        local function transform(old)
            outcome,rejected=nil,nil
            local d=P.Normalize(copy(old or self.Profiles[userId]));local accepted,result=change(d)
            if not accepted then rejected=result;return nil end
            outcome=result;if typeof(result)~='table'or not result.AlreadyApplied then d.Revision+=1 end;return d
        end
        if self.S.Store then return self.S.Store:UpdateAsync('Player_'..userId,transform)end
        return transform(self.Profiles[userId])
    end)
    self.Busy[userId]=nil
    if not ok then return false,'Сохранение временно недоступно. Изменение не применено.'end
    if rejected then return false,rejected end
    if value then self.Profiles[userId]=value end
    return true,outcome
end
function Data:Result(userId,result)
    return self:Update(userId,function(d)
        local reward=P.Apply(d,result);return true,reward or {AlreadyApplied=true}
    end)
end
function Data:Buy(userId,skinId)
    local skin=P.Skin(skinId);if not skin or skin.Price==0 then return false,'Выбери доступный набор.'end
    return self:Update(userId,function(d)
        if d.Skins[skinId]then return false,'Набор уже куплен.'end
        if d.Coins<skin.Price then return false,'Недостаточно монет.'end
        d.Coins-=skin.Price;d.Skins[skinId]=true;return true,'Набор куплен. Можно надеть его в магазине.'
    end)
end
function Data:Equip(userId,skinId)
    if not P.Skin(skinId)then return false,'Неизвестный набор.'end
    return self:Update(userId,function(d)
        if not d.Skins[skinId]then return false,'Сначала купи этот набор.'end
        d.Equipped=skinId;return true,'Набор выбран для следующего матча.'
    end)
end
function Data:OpenChest(userId,requestId,signature)
    if typeof(requestId)~='string'or #requestId>64 or #requestId<8 then return false,'Некорректный запрос.'end
    local roll=self.S.Roll and self.S.Roll()or Random.new():NextNumber()
    return self:Update(userId,function(d)
        if d.Chests[requestId]then return true,{Skin=d.Chests[requestId],AlreadyApplied=true}end
        local pool,current=P.ChestPool(d)
        if #pool==0 then return false,'Все наборы уже собраны.'end
        if signature~=current then return false,'Список наград изменился. Проверь новые шансы.'end
        if d.Coins<P.ChestPrice then return false,'Недостаточно монет.'end
        local id=pool[math.clamp(math.floor(roll*#pool)+1,1,#pool)]
        d.Coins-=P.ChestPrice;d.Skins[id]=true;d.Chests[requestId]=id
        return true,{Skin=id,Coins=P.ChestPrice}
    end)
end
function Data:Receipt(userId,purchaseId,coins)
    return self:Update(userId,function(d)
        if d.Receipts[purchaseId]then return true,{AlreadyApplied=true}end
        d.Coins+=coins;d.Receipts[purchaseId]=true;return true,{Coins=coins}
    end)
end
function Data:Field(userId,key,value)
    if key~='Map' and key~='Prefs'then return false,'Неизвестное поле.'end
    return self:Update(userId,function(d)d[key]=value;return true,true end)
end
function Data:Deliver(userId,result)
    if self.S.Inbox then
        local queued=pcall(function()self.S.Inbox:UpdateAsync(tostring(userId),function(old)local d=old or {};d[result.Id]=result;return d end)end)
        if not queued then return false,'Награда ожидает сохранения.'end
    end
    local ok,reward=self:Result(userId,result)
    if ok and self.S.Inbox then pcall(function()self.S.Inbox:UpdateAsync(tostring(userId),function(old)if old then old[result.Id]=nil end;return old end)end)end
    return ok,reward
end
function Data:Recover(userId)
    if not self.S.Inbox then return true end
    local ok,results=pcall(function()return self.S.Inbox:GetAsync(tostring(userId))end)
    if not ok then return false end
    local list={};for _,result in results or {}do table.insert(list,result)end
    table.sort(list,function(a,b)return (a.At or 0)<(b.At or 0)end)
    for _,result in list do if not self:Deliver(userId,result)then return false end end
    return true
end
function Data:Project(userId)
    local d=self.Profiles[userId];if not d then return end
    -- Embed a monotonic profile revision in the ordered score to reject late writes.
    -- Rank is the primary sort field; revision only breaks equal-score ties.
    local scale=100000000
    for name,store in {Wins=self.S.Wins,Rank=self.S.Rank}do
        if store then pcall(function()
            local incoming=d[name]*scale+d.Revision
            store:UpdateAsync(tostring(userId),function(old)
                if old and old%scale>d.Revision then return nil end;return incoming
            end)
        end)end
    end
    self.BoardCache={}
end
function Data:Board(kind,userId)
    kind=kind=='Rank' and 'Rank' or 'Wins';local now=os.clock();local cached=self.BoardCache[kind]
    if not cached or now-cached.At>30 then
        local entries={};local store=self.S[kind]
        if store then
            local ok,pages=pcall(function()return store:GetSortedAsync(false,100)end)
            if not ok then return nil,'Таблица временно недоступна.'end
            for i,v in pages:GetCurrentPage()do table.insert(entries,{Place=i,UserId=tonumber(v.key),Score=math.floor(v.value/100000000)})end
        else
            for id,d in self.Profiles do table.insert(entries,{UserId=id,Score=d[kind]})end
            table.sort(entries,function(a,b)return a.Score>b.Score or a.Score==b.Score and a.UserId<b.UserId end)
            for i,v in entries do v.Place=i end
        end
        cached={At=now,Entries=entries};self.BoardCache[kind]=cached
    end
    local mine=self.Profiles[userId];local place
    for _,entry in cached.Entries do if entry.UserId==userId then place=entry.Place;break end end
    local store=self.S[kind]
    if not place and store and mine then
        local ok,position=pcall(function()
            local score=store:GetAsync(tostring(userId));if score==nil then return nil end
            local pages=store:GetSortedAsync(false,100,score+1);local count=0
            while true do
                count+=#pages:GetCurrentPage()
                if pages.IsFinished then return count+1 end
                pages:AdvanceToNextPageAsync()
            end
        end)
        if ok then place=position end
    end
    return {Kind=kind,Entries=copy(cached.Entries),Mine={Place=place,Score=mine and mine[kind]or 0},Global=self.S.Store~=nil}
end
return Data
