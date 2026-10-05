local Engine=require(script.Parent.Engine)
local Catalog=require(script.Parent.MapCatalog)
local Matchmaker=require(script.Parent.GlobalMatchmaker)
local Lobby={};Lobby.__index=Lobby
function Lobby.new(options)
    options=options or {}
    return setmetatable({Players={},Queue={},QueueInfo={},NextRevision=0,QueueElapsed=0,Now=options.Now or os.clock,SharedLobby=options.SharedLobby,Random=options.Random or Random.new(),SetSide=options.SetSide or function()end,Notify=options.Notify or function()end,Profile=options.Profile or function()return {Rank=0,Level=1}end,Completed=options.Completed or function()end},Lobby)
end
function Lobby:NewSession(members,map,mode,difficulty)
    self.NextRevision+=1
    local session={Members=members,Participants=table.clone(members),Forfeits={},Id=game:GetService('HttpService'):GenerateGUID(false),State=Engine.new(map,{Difficulty=difficulty}),Mode=mode or 'AI',Revision=self.NextRevision,Skins={}}
    for player,side in members do self.Players[player]=session;self.SetSide(player,side);session.Skins[side]=(self.Profile(player)or {}).Equipped or 'Default'end
    return session
end
function Lobby:Register(player)
    if not self.Players[player]then
        if self.SharedLobby then
            if not self.Waiting then self.Waiting=self:NewSession({},nil,'Lobby')end
            self.Waiting.Members[player]=1;self.Players[player]=self.Waiting;self.SetSide(player,1)
        else self:NewSession({[player]=1})end
    end
    return self.Players[player]
end
function Lobby:CancelQueue(player)
    for i=#self.Queue,1,-1 do if self.Queue[i]==player then table.remove(self.Queue,i)end end
    self.QueueInfo[player]=nil
end
function Lobby:IsQueued(player)return self.QueueInfo[player]~=nil end
function Lobby:Finish(session)
    if session.State.Phase=='Ended' and not session.RewardQueued then
        session.RewardQueued=true
        if session.State.Winner~=0 and session.Mode~='Lobby'then self.Completed(session)end
    end
end
function Lobby:Leave(player,disconnect)
    self:CancelQueue(player)
    local old=self.Players[player]
    if old then
        local side=old.Members[player];old.Members[player]=nil
        if old.Mode~='Lobby' and old.State.Phase~='Waiting' and old.State.Phase~='Ended'then
            old.Forfeits[side]=true;old.State.Phase='Ended';old.State.Winner=side==1 and 2 or 1
            for other in old.Members do self.Notify(other,'Противник вышел из матча. Победа.')end
        end
        self:Finish(old)
    end
    self.Players[player]=nil
    if not disconnect then self:Register(player)end
end
function Lobby:StartAI(player,map,difficulty)
    local current=self:Register(player)
    if current.State.Phase~='Waiting' and current.State.Phase~='Ended'then return false,'Сначала заверши текущий матч.'end
    self:Leave(player,true)
    local session=self:NewSession({[player]=1},map,'AI',difficulty);session.State:Start()
    return true,'Займи сёла и подготовь армию.'
end
function Lobby:Join(player,mode)
    local current=self:Register(player);mode=mode=='Ranked'and 'Ranked'or 'PvP'
    if current.State.Phase~='Waiting' and current.State.Phase~='Ended'then return false,'Сначала заверши текущий матч.'end
    if self:IsQueued(player)then return true,'Ожидаем второго игрока.'end
    self:Leave(player,false)
    local profile=self.Profile(player)or {};local ticket={Mode=mode,Rank=profile.Rank or 0,Level=profile.Level or 1,JoinedAt=self.Now()}
    table.insert(self.Queue,player);self.QueueInfo[player]=ticket
    self:PumpQueue()
    if not self:IsQueued(player)then return true,'Противник найден. Карта: '..self.Players[player].State.Map.Definition.Name end
    return true,'Ожидаем второго игрока на этом сервере.'
end
function Lobby:PumpQueue()
    for _,player in table.clone(self.Queue)do
        local ticket=self.QueueInfo[player];local other,gap
        if ticket then
            for _,candidate in self.Queue do
                local info=self.QueueInfo[candidate]
                if candidate~=player and Matchmaker.Compatible(ticket,info,self.Now())then
                    local distance=math.abs(ticket.Rank-info.Rank)
                    if not gap or distance<gap then other,gap=candidate,distance end
                end
            end
            if other then
                self:Leave(player,true);self:Leave(other,true)
                local map,mapId=Catalog.Random(self.Random)
                local session=self:NewSession({[player]=1,[other]=2},map,ticket.Mode);session.MapId=mapId;session.State:Start()
                for member in session.Members do self.Notify(member,'Противник найден. Карта: '..map.Definition.Name)end
            end
        end
    end
end
function Lobby:Sessions()
    local result,seen={},{}
    for _,session in self.Players do if not seen[session]then seen[session]=true;table.insert(result,session)end end
    return result
end
function Lobby:Step(dt)
    self.QueueElapsed+=dt
    if self.QueueElapsed>=1 then self.QueueElapsed=0;self:PumpQueue()end
    for _,session in self:Sessions()do session.State:Step(dt,session.Mode=='PvP'or session.Mode=='Ranked');self:Finish(session)end
end
return Lobby
