local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Http=game:GetService('HttpService')
game:GetService('SoundService').RespectFilteringEnabled=true
local root=RS:WaitForChild('Kingdoms')
local Engine=require(root.Engine)
local Config=require(root.Config)
local Default=require(root.MapData)
local Network=require(root.MapNetwork)
local Catalog=require(root.MapCatalog)
local MatchLobby=require(root.MatchLobby)
local ServerNetwork=require(root.ServerNetwork)
local Progression=require(root.Progression)
local Account=require(root.AccountServer)
Players.CharacterAutoLoads=false
local lighting=game:GetService('Lighting')
lighting.ClockTime=14.5;lighting.Brightness=2
lighting.Ambient=Color3.fromRGB(130,135,119);lighting.OutdoorAmbient=Color3.fromRGB(156,163,148);lighting.GlobalShadows=true
local function remote(name)local r=root:FindFirstChild(name)or Instance.new('RemoteEvent');r.Name=name;r.Parent=root;return r end
local command,update,feedback,editorData=remote('Command'),remote('Snapshot'),remote('Feedback'),remote('EditorData')
local ready,throttles,profiles={}, {},{}
local account=Account.new(root,function(p,text)if p.Parent then feedback:FireClient(p,text)end end)
local lobby=MatchLobby.new({SharedLobby=not Run:IsStudio(),Profile=function(p)return account:Profile(p)end,Completed=function(session)account:Complete(session)end,SetSide=function(p,side)p:SetAttribute('KingdomSide',side)end,Notify=function(p,text)feedback:FireClient(p,text)end})
local network,privateSession,tryPrivate
local function snapshot(session,recipient)
    for _,s in session and {session} or lobby:Sessions()do
        local data=s.State:Snapshot();data.MapRevision=s.Revision;data.Mode=s.Mode;data.Skins=s.Skins
        for player,side in recipient and {[recipient]=s.Members[recipient]}or s.Members do if ready[player]then
            data.ViewerSide=side;data.Queueing=lobby:IsQueued(player);data.Connecting=false;data.PrivateMatch=false;data.Studio=Run:IsStudio()
            data.QueueMode=lobby.QueueInfo[player]and lobby.QueueInfo[player].Mode
            if network and not network.Studio then data.Queueing,data.Connecting=network:Status(player);data.PrivateMatch=network.Reserved and not network.IsHub;data.QueueMode=network.QueueMode and network.QueueMode[player]end
            local profile=account:Profile(player);data.LobbyBand=network and network.IsHub and network.Metadata.Band or profile and Progression.Band(profile.Level)
            update:FireClient(player,data)
        end end
    end
end
tryPrivate=function()
    if not network or not network.Reserved or network.IsHub or privateSession then return end
    local metadata=network.Metadata;if not metadata then return end
    local members={}
    for side,userId in metadata.Users do
        local player=Players:GetPlayerByUserId(userId)
        if not player or not ready[player]or not account:Profile(player)then return end
        members[player]=side
    end
    local map=metadata.Definition and Network.Create(metadata.Definition) or Catalog.Create(metadata.MapId)
    if not map then return end
    for p in members do lobby:Leave(p,true)end
    privateSession=lobby:NewSession(members,map,metadata.Mode,metadata.Difficulty);privateSession.Id=metadata.MatchId;privateSession.State:Start();snapshot(privateSession)
end
network=ServerNetwork.new(function(p,text)feedback:FireClient(p,text)end,function(p)
    if not p.Parent then return end
    if network and network.Reserved and network.MetadataLoaded then
        if not network.Metadata or not network.IsHub and not table.find(network.Metadata.Users,p.UserId)then p:Kick('This server is reserved for the players in one match.');return end
        tryPrivate()
    end
    if network and ready[p]then network:EnsureLobby(p,account:Profile(p))end
    if lobby.Players[p]then snapshot(lobby.Players[p],p)end
end)
local function register(player)
    local d=account:Load(player);if not player.Parent then return end
    profiles[player]=d;lobby:Register(player)
    if ready[player]and d then
        editorData:FireClient(player,{Map=d.Map,Prefs=d.Prefs,Persistent=account.Data.S.Store~=nil})
        if network then network:EnsureLobby(player,d)end;tryPrivate()
        snapshot(lobby.Players[player],player)
    end
end
Players.PlayerAdded:Connect(register);for _,p in Players:GetPlayers()do register(p)end
Players.PlayerRemoving:Connect(function(p)ready[p]=nil;throttles[p]=nil;profiles[p]=nil;network:Remove(p);lobby:Leave(p,true);task.defer(function()account:Release(p)end);if network.Studio or network.Reserved then snapshot()end end)
command.OnServerEvent:Connect(function(player,action,payload)
    if typeof(action)~='string' or typeof(payload)~='table' then return end
    if action=='Ready'then
        if network.Reserved and network.MetadataLoaded and (not network.Metadata or not network.IsHub and not table.find(network.Metadata.Users,player.UserId))then player:Kick('This server is reserved for the players in one match.');return end
        ready[player]=true
        local d=account:Profile(player)or account:Load(player);if not d then return end
        account:Publish(player);tryPrivate();snapshot(lobby:Register(player),player);editorData:FireClient(player,{Map=d.Map,Prefs=d.Prefs,Persistent=account.Data.S.Store~=nil})
        network:EnsureLobby(player,d)
        return
    end
    if not ready[player]then return end
    if not account:Profile(player)then feedback:FireClient(player,'Your profile is still loading.');return end
    local now=os.clock();throttles[player]=throttles[player]or {}
    if now-(throttles[player][action]or 0)<.12 then return end;throttles[player][action]=now
    if action=='Prefs'then
        local data={}
        for _,k in {'Music','Effects','Camera','Zoom'}do local v=payload[k];if typeof(v)=='number'and v==v then local audio=k=='Music'or k=='Effects';data[k]=math.clamp(v,audio and 0 or .5,audio and 1 or 2)end end
        data.Grid=payload.Grid==true;data.Labels=payload.Labels~=false
        data.BattleTutorialDone=payload.BattleTutorialDone==true
        local ok,message=account.Data:Field(player.UserId,'Prefs',data);if not ok then feedback:FireClient(player,message)end;return
    elseif action=='SaveMap'then
        local map,reason=Network.Create(payload.Definition)
        if not map then feedback:FireClient(player,reason);return end
        local ok,message=account.Data:Field(player.UserId,'Map',map.Definition)
        if not ok then feedback:FireClient(player,message);return end
        editorData:FireClient(player,{Map=map.Definition,Persistent=account.Data.S.Store~=nil,Saved=true})
        return
    end
    local ok,message=false,'Unknown command.'
    local session=lobby:Register(player);local state=session.State;local side=session.Members[player]
    if action=='Start'then
        if state.Phase=='Waiting'or state.Phase=='Ended'then
            local map=Default
            if payload.Definition then
                local reason;map,reason=Network.Create(payload.Definition)
                if not map then feedback:FireClient(player,reason);return end
            elseif payload.MapId=='Random'then map=Catalog.Random()
            elseif payload.MapId then
                local known=false;for _,item in Catalog.Items do if item.Id==payload.MapId then known=true;break end end
                if not known then feedback:FireClient(player,'Select an existing map.');return end
                map=assert(Catalog.Create(payload.MapId))
            end
            local difficulty=Config.BotInterval[payload.Difficulty]and payload.Difficulty or 'Hard'
            if network.Studio then ok,message=lobby:StartAI(player,map,difficulty)
            else
                local mapId='TwoBridges';for _,item in Catalog.Items do if item.Name==map.Definition.Name then mapId=item.Id;break end end
                ok,message=network:Solo(player,payload.Definition and map.Definition or nil,mapId,difficulty)
            end
        else message='A battle is already in progress.'end
    elseif action=='JoinPvP'or action=='JoinRanked'then
        local mode=action=='JoinRanked'and 'Ranked'or 'PvP'
        if network.Studio then ok,message=lobby:Join(player,mode)else ok,message=network:Join(player,account:Profile(player),mode)end
    elseif action=='CancelPvP'then if network.Studio then lobby:CancelQueue(player);ok=true;message='Search cancelled.'else ok,message=network:Cancel(player)end
    elseif action=='ReturnMenu'then
        if network.Reserved and not network.IsHub then lobby:Leave(player,false);account:Await(player);local profile=account:Profile(player);if player.Parent then network:Return(player,profile and profile.Level)end;ok=true;message='Returning to the lobby…'
        elseif network.Studio then lobby:Leave(player,false);ok=true;message='Match ended.'
        else ok,message=network:Cancel(player)end
    elseif action=='Send'then ok,message=state:Send(side,payload.Sources,payload.Target,payload.Percent,payload.Filter,payload.Route)
    elseif action=='Upgrade'then ok,message=state:Upgrade(side,payload.Site)
    end
    feedback:FireClient(player,message,ok);if network.Studio or network.Reserved then snapshot()else snapshot(lobby.Players[player],player)end
end)
local accumulator,sync=0,0
Run.Heartbeat:Connect(function(dt)
    accumulator+=math.min(dt,.5);sync+=dt;local steps=0
    while accumulator>=Config.Step and steps<5 do accumulator-=Config.Step;lobby:Step(Config.Step);steps+=1 end
    if sync>=Config.SnapshotInterval then sync=0;if next(ready)then
        for _,s in lobby:Sessions()do if s.State.Phase~='Waiting'then snapshot(s)end end
    end end
end)
if network.Reserved then task.delay(90,function()
    if not privateSession and not network.IsHub then for _,p in Players:GetPlayers()do feedback:FireClient(p,'The second player did not connect. Returning to the lobby.');network:Return(p,account:Profile(p)and account:Profile(p).Level)end end
end)end
if Run:IsStudio()then _G.KingdomsLobby=lobby;_G.KingdomsAccount=account end

