local rs=game.ReplicatedStorage
local q=Instance.new('Folder');q.Name='Version06QA';q.Parent=rs
for _,name in {'Config','MapNetwork','MapData','MapEditor','MapCatalog','Engine','MatchLobby','GlobalMatchmaker'}do rs.Kingdoms[name]:Clone().Parent=q end
local C=require(q.Config);local N=require(q.MapNetwork);local E=require(q.Engine);local Catalog=require(q.MapCatalog)
local report={}
local ok,err=pcall(function()
    report.maps={}
    for _,item in Catalog.Items do
        local m=assert(Catalog.Create(item.Id));assert(#m.Sites==20)
        assert(#m.Bridges==(item.Id=='TwoBridges'and 2 or item.Id=='RiverPass'and 1 or 0))
        assert(m.Route(m.Castles[1],m.Castles[2],true))
        report.maps[item.Id]={bridges=#m.Bridges,sites=#m.Sites,river=m.River}
    end
    local editor=require(q.MapEditor).new({Name='QA',River=false,Nodes={},Roads={}},function()end,function()end)
    assert(editor:CanPlace(0,0));editor:Click(nil,0,0);assert(not editor:ToggleRiver()and editor.Definition.River==false)
    editor:Undo();assert(editor:ToggleRiver()and not editor:CanPlace(0,0));editor:ToggleRiver();editor:New();assert(editor.Definition.River==false)
    assert(editor:Import(editor:Export())and editor.Definition.River==false);report.editor='River toggles, central cells, safe rejection, undo and export verified'
    local function arena()
        local g=E.new();g:Start();g.Time=61;g.Phase='Battle'
        local units={};for _,u in g.Units do table.insert(units,u)end;for _,u in units do g:RemoveUnit(u)end
        return g
    end
    local function step(g,seconds)for _=1,math.floor(seconds*10)do g.Time+=.1;g:CombatAndMove(.1)end end
    local g=arena();g.Map={River=false,Route=function()return {Vector3.new(-120,0,120),Vector3.new(-120,0,-120)}end}
    for _=1,6 do g:CreateUnit('Defender',1,g.Sites.ACastle)end
    for _=1,8 do g:CreateUnit('Peasant',1,g.Sites.ACastle)end
    for _=1,8 do g:CreateUnit('Archer',1,g.Sites.ACastle)end
    assert(g:Send(1,{'ACastle'},'AFarm',100,'All','Auto'));step(g,12)
    local lastSoldier,firstSoldier,firstPeasant,firstBow=-math.huge,math.huge,math.huge,math.huge
    for _,u in g.Active do
        if u.Kind=='Defender'then lastSoldier=math.max(lastSoldier,u.Position.Z);firstSoldier=math.min(firstSoldier,u.Position.Z)
        elseif u.Kind=='Peasant'then assert(u.Formation);firstPeasant=math.min(firstPeasant,u.Position.Z)
        else assert(not u.Formation);firstBow=math.min(firstBow,u.Position.Z)end
    end
    assert(firstPeasant>lastSoldier+1 and firstBow>firstSoldier+1 and firstBow<=lastSoldier+.3)
    report.mixedFormation={peasantsBehind=true,archersBehindFront=true,archersPassRearRanks=true,incompleteSwordRow=6}
    g=arena();g.Map={River=true,Route=function()return {Vector3.new(-120,0,0),Vector3.new(120,0,0)}end}
    g.Sites.AFarm.Owner=1
    for _=1,24 do g:CreateUnit('Defender',1,g.Sites.ACastle)end
    for _=1,8 do g:CreateUnit('Peasant',1,g.Sites.ACastle)end
    assert(g:Send(1,{'ACastle'},'AFarm',100,'All','Auto'))
    local sawBridge,sawExpanded,maxLateral=false,false,0;local previous={}
    for _=1,700 do
        for id,u in g.Active do previous[id]=u.Position end
        step(g,.1)
        for id,u in g.Active do
            if previous[id]then assert((u.Position-previous[id]).Magnitude<=C.Units[u.Kind].Speed*.1+.06,'Formation teleported during reflow')end
            if math.abs(u.Position.X)<=16 then
                sawBridge=true;maxLateral=math.max(maxLateral,math.abs(u.Position.Z))
                assert(u.Formation.Columns==2 and math.abs(u.Position.Z)<=C.FormationSpacing/2+.05,'Bridge exceeded two columns')
            elseif u.Position.X>45 and u.Formation and u.Formation.Columns==4 then sawExpanded=true end
        end
    end
    assert(sawBridge and sawExpanded and #g.Sites.AFarm.Garrison==32)
    report.bridge={twoColumns=true,reexpanded=true,all32Arrived=true,maximumLateral=maxLateral}
    g=arena();local a=g:CreateUnit('Defender',1,g.Sites.ACastle);g:Detach(a);a.State='Marching';a.Squad=1;a.FormationIndex=1;a.Column=0;a.Position=Vector3.zero;a.Path={Vector3.zero,Vector3.new(20,0,0)};a.PathIndex=2;a.Target='BCastle';g.Active[a.Id]=a
    local b=g:CreateUnit('Archer',2,g.Sites.BCastle);g:Detach(b);b.State='Marching';b.Column=0;b.Position=Vector3.new(3,0,0);b.Path={b.Position,b.Position};b.PathIndex=2;b.Target='ACastle';b.Cooldown=100;g.Active[b.Id]=b
    step(g,.1);assert(not b.Dying,'Sword hit before close contact')
    local gapAtSwing=nil
    for _=1,20 do step(g,.1);if b.Dying and not gapAtSwing then gapAtSwing=(a.Position-b.Position).Magnitude end end
    assert(gapAtSwing and gapAtSwing<=1 and not g.Units[b.Id]);report.contact={gap=gapAtSwing,archerKilledOnFirstSwing=true}
    local Lobby=require(q.MatchLobby);local l=Lobby.new({Random=Random.new(6)});local p1,p2,p3,p4='one','two','three','four'
    l:Register(p1);l:Register(p2);assert(l:Join(p1));assert(l:Join(p2))
    local match=l.Players[p1];assert(match==l.Players[p2]and match.Mode=='PvP'and match.Members[p1]==1 and match.Members[p2]==2)
    assert(not match.State:Send(2,{'ACastle'},'AVillage1',100,'All','Auto'),'Side two controlled side one')
    assert(match.State:Send(2,{'BCastle'},'BVillage1',50,'All','Auto'))
    l:Step(3);assert(match.State.LastBotTarget==nil,'AI ran in a human match')
    l:Register(p3);assert(l:StartAI(p3,assert(Catalog.Create('LandFrontiers')),'Hard'));assert(l.Players[p3]~=match)
    l:Leave(p1,false);assert(match.State.Phase=='Ended'and match.State.Winner==2)
    l:Register(p4);l:Join(p4);l:CancelQueue(p4);assert(not l:IsQueued(p4))
    report.localMatch='Two sides, command ownership, no PvP bot, isolated AI, cancellation and disconnect victory verified'
    local shared=Lobby.new({SharedLobby=true});for i=1,100 do shared:Register('lobby'..i)end
    assert(#shared:Sessions()==1 and shared.Players.lobby1==shared.Players.lobby100)
    shared:Leave('lobby1',true);assert(shared.Players.lobby100.State.Phase=='Waiting')
    report.largeLobby='100 waiting players share one idle map simulation'
    -- Shared backend emulates different lobby jobs; every returned value is copied.
    local Http=game:GetService('HttpService')
    local function copy(v)return v and Http:JSONDecode(Http:JSONEncode(v))end
    local function map()
        local t={Data={}}
        function t:SetAsync(k,v,ttl,sort)self.Data[k]={value=copy(v),sortKey=sort}end
        function t:GetAsync(k)return self.Data[k]and copy(self.Data[k].value)end
        function t:RemoveAsync(k)self.Data[k]=nil end
        function t:UpdateAsync(k,fn,ttl)local v=fn(self:GetAsync(k));if v then self:SetAsync(k,v,ttl);return copy(v)end;return nil end
        function t:GetRangeAsync(_,limit)local r={};for k,v in self.Data do table.insert(r,{key=k,value=copy(v.value),sortKey=v.sortKey})end;table.sort(r,function(a,b)return a.sortKey<b.sortKey end);while #r>limit do table.remove(r)end;return r end
        return t
    end
    local tickets,queue,matches=map(),map(),map();local serial,reservations,now=0,0,1000
    local services={Tickets=tickets,Queue=queue,Matches=matches,Now=function()now+=1;return now end,Guid=function()serial+=1;return 'guid'..serial end,RandomMap=function()return 'RiverPass'end,Reserve=function()reservations+=1;return 'secret'..reservations,'private'..reservations end}
    local Global=require(q.GlobalMatchmaker);local lobbyA,lobbyB=Global.new(services),Global.new(services)
    local t1=lobbyA:Join(101,'jobA');local t2=lobbyB:Join(202,'jobB')
    lobbyA:Pump();lobbyB:Pump()
    local x,y=lobbyA:Assignment(101,t1),lobbyB:Assignment(202,t2)
    assert(x and y and x.PrivateId==y.PrivateId and x.AccessCode==y.AccessCode and reservations==1)
    local meta=matches:GetAsync(x.PrivateId);assert(meta.Users[1]==101 and meta.Users[2]==202 and meta.Mode=='PvP')
    local t3=lobbyA:Join(303,'jobA');assert(lobbyB:Cancel(303,t3));lobbyA:Pump();assert(not lobbyA:Assignment(303,t3))
    local t4=lobbyA:Join(404,'jobA');local t5=lobbyB:Join(505,'jobB')
    local before=reservations;local oldReserve=services.Reserve;services.Reserve=function()error('simulated reservation failure')end
    lobbyA:Pump();assert(tickets:GetAsync('404').State=='Queued'and tickets:GetAsync('505').State=='Queued')
    services.Reserve=oldReserve;lobbyB:Pump();assert(lobbyA:Assignment(404,t4)and lobbyB:Assignment(505,t5)and reservations==before+1)
    local solo=lobbyA:Solo(606,nil,'LandFrontiers','Hard');meta=matches:GetAsync(solo.PrivateId)
    assert(meta.Mode=='AI'and #meta.Users==1 and meta.Users[1]==606)
    local t6=lobbyA:Join(707,'jobA');local ticket=tickets:GetAsync('707');assert(lobbyA:Claim(ticket,'race'));assert(not lobbyB:Claim(ticket,'otherRace'));assert(not lobbyB:Cancel(707,t6));now+=61;lobbyA:Renew(707,t6);assert(tickets:GetAsync('707').State=='Queued')
    assert(lobbyA:Cancel(707,t6))
    local t7=lobbyA:Join(808,'jobA');local t8=lobbyB:Join(909,'jobB')
    local originalUpdate=tickets.UpdateAsync;local injected=false
    function tickets:UpdateAsync(k,fn,ttl)
        return originalUpdate(self,k,function(old)
            local result=fn(old)
            if k=='909'and result and result.State=='Matched'and not injected then injected=true;error('simulated commit failure')end
            return result
        end,ttl)
    end
    lobbyA:Pump();assert(injected and not lobbyA:Assignment(808,t7)and not lobbyB:Assignment(909,t8))
    assert(tickets:GetAsync('808').State=='Queued'and tickets:GetAsync('909').State=='Queued')
    tickets.UpdateAsync=originalUpdate;lobbyB:Pump();assert(lobbyA:Assignment(808,t7)and lobbyB:Assignment(909,t8))
    report.commitFailure='A partial pair assignment stays invisible and both tickets recover before teleport'
    report.globalMatchmaking='Different lobby jobs share one queue; pair gets one reserved server; AI gets solo server; duplicate claim, cancellation, reservation failure and claim timeout verified with mocked Roblox services'
end)
q:Destroy();if not ok then error(err)end
return report
