local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local Teleport=game:GetService('TeleportService')
local Http=game:GetService('HttpService')
local Catalog=require(script.Parent.MapCatalog)
local Global=require(script.Parent.GlobalMatchmaker)
local Directory=require(script.Parent.LobbyDirectory)
local Progression=require(script.Parent.Progression)
local Network={};Network.__index=Network
function Network.new(notify,changed)
    local self=setmetatable({Studio=Run:IsStudio(),Reserved=game.PrivateServerId~=''and game.PrivateServerOwnerId==0,Tokens={},Connections={},Notify=notify,Changed=changed,Metadata=nil,Closed=false},Network)
    if self.Studio then return self end
    local memory=game:GetService('MemoryStoreService')
    self.Core=Global.new({Queue=memory:GetSortedMap('KingdomsQueueV1'),Tickets=memory:GetHashMap('KingdomsTicketsV1'),Matches=memory:GetHashMap('KingdomsMatchesV1'),Now=os.time,Guid=function()return Http:GenerateGUID(false)end,Reserve=function()return Teleport:ReserveServerAsync(game.PlaceId)end,RandomMap=function()return Catalog.Items[Random.new():NextInteger(1,#Catalog.Items)].Id end})
    self.Core.S.QueueFor=function(key)return memory:GetSortedMap('KingdomsQueueV2_'..key)end
    self.Directory=Directory.new({Registry=memory:GetSortedMap('KingdomsLobbiesV1'),Locks=memory:GetHashMap('KingdomsLobbyLocksV1'),Matches=self.Core.S.Matches,Now=os.time,Guid=self.Core.S.Guid,Reserve=self.Core.S.Reserve,Capacity=Players.MaxPlayers})
    Teleport.TeleportInitFailed:Connect(function(player,_,_,_,options)
        local connection=self.Connections[player]
        if connection then connection.InFlight=false;connection.Options=options;connection.NextAttempt=os.clock()+3;self.Notify(player,'Переход задержался. Повторяем подключение…')end
    end)
    if self.Reserved then
        task.spawn(function()
            for _=1,3 do
                local ok,data=pcall(function()return self.Core.S.Matches:GetAsync(game.PrivateServerId)end)
                if ok and data and data.State=='Ready'then self.Metadata=data;self.IsHub=data.Mode=='Lobby';break end
                task.wait(2)
            end
            self.MetadataLoaded=true
            for _,p in Players:GetPlayers()do self.Changed(p)end
            if self.IsHub then
                while not self.Closed do
                    local users={};for _,p in Players:GetPlayers()do users[p.UserId]=true end
                    pcall(function()self.Directory:Advertise(self.Metadata,users)end);task.wait(10)
                end
            end
        end)
    end
    do
        task.spawn(function()
            local renewAt=0
            while not self.Closed do
                local renew=os.clock()>=renewAt;if renew then renewAt=os.clock()+10 end
                if next(self.Tokens)then pcall(function()self.Core:Pump()end)end
                for player,token in self.Tokens do
                    if player.Parent and not self.Connections[player]then
                        local ok,assignment=pcall(function()
                            if renew and not self.Core:Renew(player.UserId,token)then self.Tokens[player]=nil;self.Notify(player,'Поиск истёк. Нажми поиск ещё раз.');self.Changed(player);return nil end
                            return self.Core:Assignment(player.UserId,token)
                        end)
                        if ok and assignment then self:Connect(player,assignment)end
                    end
                end
                task.wait(2)
            end
        end)
    end
    task.spawn(function()
        while not self.Closed do
            for player,c in self.Connections do
                if c.InFlight and c.SentAt and os.clock()-c.SentAt>30 then c.InFlight=false;c.NextAttempt=os.clock()end
                if player.Parent and not c.InFlight and os.clock()>=c.NextAttempt then self:Attempt(player,c)end
            end
            task.wait(1)
        end
    end)
    game:BindToClose(function()self.Closed=true;for p,token in self.Tokens do pcall(function()self.Core:Cancel(p.UserId,token)end)end end)
    return self
end
function Network:Status(player)
    return self.Tokens[player]~=nil,self.Connections[player]~=nil
end
function Network:Attempt(player,c)
    if c.Attempts>=5 then
        self.Connections[player]=nil;self.Notify(player,'Не удалось подключиться. Нажми «Повторить подключение» или попробуй вернуться в лобби.');self.Changed(player);return
    end
    c.Attempts+=1;c.InFlight=true;c.SentAt=os.clock()
    local ok=pcall(function()Teleport:TeleportAsync(game.PlaceId,{player},c.Options)end)
    if not ok then c.InFlight=false;c.NextAttempt=os.clock()+3 end
end
function Network:Connect(player,assignment)
    if self.Connections[player]then return end
    local options=Instance.new('TeleportOptions');options.ReservedServerAccessCode=assignment.AccessCode
    local c={Options=options,Attempts=0,InFlight=false,NextAttempt=0};self.Connections[player]=c
    self.Notify(player,'Матч готов. Подключаемся к отдельному серверу…');self.Changed(player);self:Attempt(player,c)
end
function Network:Join(player,profile,mode)
    if self.Reserved and not self.IsHub then return false,'Вернись в лобби для поиска нового матча.'end
    if self.Connections[player]then return false,'Уже подключаемся к матчу.'end
    if self.Tokens[player]then
        local ok,assignment=pcall(function()return self.Core:Assignment(player.UserId,self.Tokens[player])end)
        if ok and assignment then self:Connect(player,assignment);return true,'Повторяем подключение.'end
        return true,'Поиск соперника среди всех лобби…'
    end
    local ok,token=pcall(function()return self.Core:Join(player.UserId,game.JobId,profile,mode)end)
    if not ok then return false,'Поиск временно недоступен. Попробуй ещё раз.'end
    self.QueueMode= self.QueueMode or {};self.QueueMode[player]=mode=='Ranked'and 'Ranked'or 'PvP'
    self.Tokens[player]=token;self.Changed(player);return true,'Поиск соперника среди всех лобби…'
end
function Network:Cancel(player)
    if self.Connections[player]then return false,'Матч уже готов, подключаемся.'end
    local token=self.Tokens[player];if not token then return true,'Поиск отменён.'end
    local ok,cancelled=pcall(function()return self.Core:Cancel(player.UserId,token)end)
    if ok and cancelled then self.Tokens[player]=nil;self.Changed(player);return true,'Поиск отменён.'end
    return false,'Соперник уже найден. Ожидаем подключения.'
end
function Network:Solo(player,definition,mapId,difficulty)
    if self.Reserved and not self.IsHub then return false,'Вернись в лобби для нового матча.'end
    if self.Connections[player]then return false,'Уже подключаемся к матчу.'end
    local cancelled,message=self:Cancel(player);if not cancelled then return false,message end
    self.Connections[player]={Attempts=0,InFlight=true,NextAttempt=math.huge}
    self.Changed(player)
    local ok,assignment=pcall(function()return self.Core:Solo(player.UserId,definition,mapId,difficulty)end)
    self.Connections[player]=nil
    if not ok then self.Changed(player);return false,'Не удалось создать сервер матча. Попробуй ещё раз.'end
    self:Connect(player,assignment);return true,'Подключаемся к матчу с ИИ…'
end
function Network:EnterLobby(player,level)
    if self.Studio then return true end
    if self.Connections[player]then return true end
    self.Connections[player]={Attempts=0,InFlight=true,NextAttempt=math.huge};self.Changed(player)
    task.spawn(function()
        local assignment
        for _=1,5 do
            local ok,value=pcall(function()return self.Directory:Find(level,player.UserId)end)
            if ok and value then assignment=value;break end
            task.wait(2)
        end
        self.Connections[player]=nil
        if not player.Parent then return end
        if assignment then self:Connect(player,assignment)else self.Notify(player,'Лобби временно недоступно. Можно повторить переход.');self.Changed(player)end
    end)
    return true
end
function Network:EnsureLobby(player,profile)
    if not self.Studio and profile and (not self.Reserved or self.IsHub and self.Metadata.Band~=Progression.Band(profile.Level))then return self:EnterLobby(player,profile.Level)end
    return false
end
function Network:Return(player,level)
    self.Tokens[player]=nil
    return self:EnterLobby(player,level or 1)
end
function Network:Remove(player)
    local token=self.Tokens[player]
    if token and not self.Connections[player]then pcall(function()self.Core:Cancel(player.UserId,token)end)end
    self.Tokens[player]=nil;self.Connections[player]=nil
end
return Network
