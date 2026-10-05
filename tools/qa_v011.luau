local q=Instance.new('Folder');q.Name='Version011QA';q.Parent=game.ReplicatedStorage
for _,name in {'SkinStyles','Progression','PlayerData','AccountServer','LobbyDirectory','GlobalMatchmaker','Config','MapNetwork','MapData','MapCatalog','Engine','MatchLobby'}do game.ReplicatedStorage.Kingdoms[name]:Clone().Parent=q end
local P=require(q.Progression);local Data=require(q.PlayerData);local G=require(q.GlobalMatchmaker);local Directory=require(q.LobbyDirectory)
local Http=game:GetService('HttpService');local function copy(v)return v and Http:JSONDecode(Http:JSONEncode(v))end
local report={passed=0,failed=0,cases={}}
local function test(name,fn)local at=os.clock();local ok,value=pcall(fn);report[ok and 'passed'or 'failed']+=1;report.cases[name]={passed=ok,result=ok and value or tostring(value),seconds=os.clock()-at}end
local function store()
    local s={Data={},Fail=false,Retry=false}
    function s:GetAsync(key)if self.Fail then error('read unavailable')end;return copy(self.Data[key])end
    function s:SetAsync(key,value,ttl,sort)self.Data[key]=copy(value);self.Sort=self.Sort or {};self.Sort[key]=sort or 0 end
    function s:RemoveAsync(key)self.Data[key]=nil end
    function s:UpdateAsync(key,fn,ttl)
        if self.Fail then error('write unavailable')end
        if self.Retry then fn(self:GetAsync(key))end
        local value=fn(self:GetAsync(key));if value~=nil then self:SetAsync(key,value,ttl);return copy(value)end;return nil
    end
    function s:GetRangeAsync(_,limit)local list={};for k,v in self.Data do table.insert(list,{key=k,value=copy(v),sortKey=self.Sort and self.Sort[k]or 0})end;table.sort(list,function(a,b)return a.sortKey<b.sortKey or a.sortKey==b.sortKey and a.key<b.key end);while #list>limit do table.remove(list)end;return list end
    function s:GetSortedAsync(_,limit,minValue)
        local list={};for k,v in self.Data do if not minValue or v>=minValue then table.insert(list,{key=k,value=v})end end;table.sort(list,function(a,b)return a.value>b.value end)
        local pages={Index=1,IsFinished=#list<=limit}
        function pages:GetCurrentPage()local page={};for i=self.Index,math.min(#list,self.Index+limit-1)do table.insert(page,list[i])end;return page end
        function pages:AdvanceToNextPageAsync()self.Index+=limit;self.IsFinished=self.Index+limit>#list end
        return pages
    end
    return s
end
local function profile(stores)local d=Data.new(stores);assert(d:Load(1));return d end
local function result(id,mode,won,difficulty)return {Id=id,Mode=mode or 'PvP',Won=won~=false,Difficulty=difficulty or 'Hard'}end
test('XP levels and coins are independent of ranked points',function()
    local d=profile();assert(d:Result(1,result('a')));assert(d:Result(1,result('b')))
    local p=d.Profiles[1];assert(p.Level==2 and p.Coins==100 and p.Rank==0 and p.Wins==2)
    local ok,r=d:Result(1,result('b'));assert(ok and r.AlreadyApplied and p.XP==200)
    d:Result(1,result('loss','PvP',false));p=d.Profiles[1];assert(p.XP==240 and p.Losses==1 and p.Coins==100)
    return '200 XP grants one level and 100 coins; repeated result grants nothing'
end)
test('AI difficulty rewards are 20, 35 and 50 XP without PvP wins or rank',function()
    local d=profile();for i,difficulty in {'Easy','Normal','Hard'}do d:Result(1,result('AI'..i,'AI',true,difficulty))end
    local p=d.Profiles[1];assert(p.XP==105 and p.AIWins==3 and p.Wins==0 and p.Rank==0)
    return {XP=p.XP,AIWins=p.AIWins,PvPWins=p.Wins,Rank=p.Rank}
end)
test('First ten ranked games calibrate rapidly, then streak gains stabilize',function()
    local d=profile();for i=1,10 do d:Result(1,result('cal'..i,'Ranked'))end
    assert(d.Profiles[1].Rank==1000)
    d:Result(1,result('reset','Ranked',false));assert(d.Profiles[1].Rank==975 and d.Profiles[1].WinStreak==0)
    local gains={25,25,35,45,50,50}
    for i,gain in gains do local _,r=d:Result(1,result('stable'..i,'Ranked'));assert(r.Rank==gain)end
    return {calibratedRank=1000,steadyGains=gains}
end)
test('Calibration losses are small, zero is a floor, and leaving grants no XP',function()
    local d=profile();d:Result(1,result('l','Ranked',false));assert(d.Profiles[1].Rank==0)
    d:Result(1,result('w','Ranked'));assert(d.Profiles[1].Rank==100)
    local r=result('quit','Ranked',false);r.Forfeit=true;local _,reward=d:Result(1,r)
    assert(d.Profiles[1].Rank==75 and reward.XP==0 and d.Profiles[1].WinStreak==0)
    return 'New players start at zero; win +100 and loss -25; forfeits record the loss'
end)
test('Atomic changes survive callback retries, reject failed saves and preserve old map/preferences',function()
    local s=store();s:SetAsync('Player_1',{Map={Name='saved'},Prefs={Music=.3}});s.Retry=true
    local d=profile({Store=s});d:Result(1,result('once'));assert(s.Data.Player_1.XP==100 and s.Data.Player_1.Wins==1)
    assert(s.Data.Player_1.Map.Name=='saved'and s.Data.Player_1.Prefs.Music==.3)
    s.Fail=true;local ok=d:Result(1,result('failure'));assert(not ok and d.Profiles[1].XP==100)
    local bad=Data.new({Store=s});assert(not bad:Load(2)and not bad:Result(2,result('blocked')))
    return 'Callbacks can retry without double rewards; failed loads do not create a blank overwritable profile'
end)
test('Cosmetic purchases spend the exact price once and equipment requires ownership',function()
    local d=profile();assert(not d:Equip(1,'Royal')and not d:Buy(1,'Veteran'))
    d:Receipt(1,'test',1500);assert(d:Buy(1,'Veteran'));assert(d.Profiles[1].Coins==1100)
    assert(not d:Buy(1,'Veteran')and not d:Buy(1,'invalid'));assert(d:Equip(1,'Veteran'))
    assert(d.Profiles[1].Equipped=='Veteran'and d.Profiles[1].Rank==0 and d.Profiles[1].XP==0)
    return '400 coins spent once, no combat/progression bonus, owned skin can be equipped'
end)
test('A paid receipt delivered to different servers credits coins exactly once',function()
    local s=store();s.Retry=true;local a=profile({Store=s});local b=profile({Store=s})
    assert(a:Receipt(1,'purchase',1500));local ok,r=b:Receipt(1,'purchase',1500)
    assert(ok and r.AlreadyApplied and s.Data.Player_1.Coins==1500)
    assert(a:Receipt(1,'second',500));assert(s.Data.Player_1.Coins==2000)
    return 'Cross-server duplicate receipt did not duplicate purchased currency'
end)
test('Marketplace receipt acknowledges only persisted currency for a known product and loaded buyer',function()
    local s=store();local data=profile({Store=s});local Account=require(q.AccountServer)
    local notices=0;local account=setmetatable({Data=data,FindPlayer=function(id)return id==1 and {}or nil end,Publish=function()end,Notify=function()notices+=1 end},Account)
    local previous=P.Products[1].ProductId;P.Products[1].ProductId=123
    local r={PlayerId=1,ProductId=123,PurchaseId='actual-callback-test'}
    assert(account:ProcessReceipt(r)==Enum.ProductPurchaseDecision.PurchaseGranted)
    assert(account:ProcessReceipt(r)==Enum.ProductPurchaseDecision.PurchaseGranted and data.Profiles[1].Coins==500 and notices==1)
    assert(account:ProcessReceipt({PlayerId=1,ProductId=999,PurchaseId='unknown'})==Enum.ProductPurchaseDecision.NotProcessedYet)
    assert(account:ProcessReceipt({PlayerId=2,ProductId=123,PurchaseId='absent'})==Enum.ProductPurchaseDecision.NotProcessedYet)
    s.Fail=true;assert(account:ProcessReceipt({PlayerId=1,ProductId=123,PurchaseId='failed'})==Enum.ProductPurchaseDecision.NotProcessedYet)
    P.Products[1].ProductId=previous
    return 'Unknown product, missing player and failed durable save never acknowledge the sale'
end)
test('Pending match rewards recover after rejoin and remain idempotent',function()
    local s,inbox=store(),store();local d=profile({Store=s,Inbox=inbox})
    inbox:SetAsync('1',{pending=result('pending','Ranked')})
    assert(d:Recover(1));assert(d.Profiles[1].Rank==100 and d.Profiles[1].XP==100)
    inbox:SetAsync('1',{pending=result('pending','Ranked')});assert(d:Recover(1))
    assert(d.Profiles[1].XP==100 and not next(inbox.Data['1']))
    return 'Persisted outbox reward was recovered once and cleared'
end)
test('Returning to the same lobby refreshes an old cached profile after a match elsewhere',function()
    local s=store();local hub=profile({Store=s});local match=profile({Store=s})
    match:Result(1,result('away','Ranked'));assert(hub.Profiles[1].Rank==0)
    assert(hub:Load(1,true).Rank==100 and hub.Profiles[1].XP==100)
    return 'Rejoin performs an uncached read; the old lobby profile cannot hide a new rank or currency'
end)
test('Leaderboard projections reject older rank writes and separate wins from AI',function()
    local s,wins,rank=store(),store(),store();local a=profile({Store=s,Wins=wins,Rank=rank})
    a:Result(1,result('rank','Ranked'));a:Project(1)
    local b=profile({Store=s,Wins=wins,Rank=rank});b:Result(1,result('loss','Ranked',false));b:Project(1);a:Project(1)
    assert(math.floor(rank.Data['1']/100000000)==75)
    local board=b:Board('Rank',1);assert(board.Entries[1].Score==75 and board.Mine.Place==1)
    assert(math.floor(wins.Data['1']/100000000)==1)
    return 'New rank 75 remains visible despite a delayed write of old rank 100'
end)
test('A player outside the top hundred still receives their exact global place',function()
    local rank=store();local data=profile({Store=store(),Rank=rank});data:Project(1)
    for id=2,251 do rank:SetAsync(tostring(id),id*100000000+1)end
    local board=data:Board('Rank',1);assert(#board.Entries==100 and board.Mine.Place==251)
    return {topRows=100,myPlace=251}
end)
test('Ranked matchmaking ignores XP level, protects large gaps and expands with time',function()
    local a={Mode='Ranked',Rank=0,Level=1,JoinedAt=1000};local b={Mode='Ranked',Rank=90,Level=60,JoinedAt=1000}
    assert(G.Compatible(a,b,1000));b.Rank=250;assert(not G.Compatible(a,b,1000)and not G.Compatible(a,b,1030)and G.Compatible(a,b,1060))
    b.Rank=1000;assert(not G.Compatible(a,b,2000));b.Mode='PvP';assert(not G.Compatible(a,b,2000))
    a.Mode='PvP';assert(not G.Compatible(a,b,2000));b.Level=8;assert(G.Compatible(a,b,2000))
    return 'Rank range 100/200/300; separate modes; casual matchmaking uses the same level-band lobbies'
end)
test('Shared rank queues choose the closest opponent across lobbies and create one private match',function()
    local now,serial,reservations=1000,0,0;local queues={};local tickets,matches=store(),store()
    local services={Tickets=tickets,Matches=matches,QueueFor=function(key)queues[key]=queues[key]or store();return queues[key]end,Now=function()return now end,Guid=function()serial+=1;return 'id'..serial end,RandomMap=function()return 'TwoBridges'end,Reserve=function()reservations+=1;return 'code'..reservations,'server'..reservations end}
    local a,b=G.new(services),G.new(services)
    local token=a:Join(1,'lobbyA',{Rank=0,Level=1},'Ranked');now+=1
    b:Join(2,'lobbyB',{Rank=70,Level=50},'Ranked');now+=1
    local closest=b:Join(3,'lobbyC',{Rank=10,Level=20},'Ranked');a:Pump();b:Pump()
    local x,y=a:Assignment(1,token),b:Assignment(3,closest)
    assert(x and y and x.PrivateId==y.PrivateId and reservations==1)
    assert(matches.Data[x.PrivateId].Mode=='Ranked'and tickets.Data['2'].State=='Queued')
    return 'Closest rank paired despite different XP levels and lobby servers'
end)
test('Level-band lobby routing reuses a hub, prevents overfill and replaces expired hubs',function()
    local now,serial,reserves=1000,0,0
    local s={Registry=store(),Locks=store(),Matches=store(),Now=function()return now end,Guid=function()serial+=1;return 'g'..serial end,Capacity=2,Reserve=function()reserves+=1;return 'access'..reserves,'hub'..reserves end}
    local a,b=Directory.new(s),Directory.new(s)
    local x=a:Find(50,1);local y=b:Find(80,2);assert(x.PrivateId==y.PrivateId and reserves==1)
    local z=b:Find(55,3);assert(z.PrivateId~=x.PrivateId and reserves==2)
    a:Advertise(x,{[1]=true,[2]=true});assert(s.Registry.Data[x.PrivateId].Count==2)
    local novice=a:Find(1,4);assert(novice.Band=='1–9'and novice.PrivateId~=x.PrivateId)
    now+=100;local fresh=a:Find(50,5);assert(fresh.PrivateId~=x.PrivateId and fresh.PrivateId~=z.PrivateId)
    return '50+ users share a capacity-limited hub; novices use their own band; stale hubs expire'
end)
test('Natural victory and disconnect complete each local session once, including ranked games',function()
    local completed={};local profileInfo={[1]={Rank=0,Level=1,Equipped='Veteran'},[2]={Rank=0,Level=60}}
    local lobby=require(q.MatchLobby).new({Profile=function(p)return profileInfo[p.Id]end,Completed=function(s)table.insert(completed,s)end})
    local a,b={Id=1},{Id=2};assert(lobby:Join(a,'Ranked')and lobby:Join(b,'Ranked'))
    local session=lobby.Players[a];assert(session==lobby.Players[b]and session.Mode=='Ranked'and session.Skins[1]=='Veteran')
    lobby:Leave(b,true);lobby:Step(.1);lobby:Finish(session)
    assert(#completed==1 and session.State.Winner==1 and session.Forfeits[2]and session.Participants[b]==2)
    assert(lobby:StartAI(a,nil,'Hard'));local ai=lobby.Players[a];ai.State.Phase='Ended';ai.State.Winner=1;lobby:Step(.1);lobby:Leave(a,false)
    assert(#completed==2)
    return 'Both participants are retained for reward processing, and each match finishes once'
end)
test('Local ranked search pairs waiting players when the permitted gap grows',function()
    local now=1000;local a,b={Id=1},{Id=2}
    local profiles={[a]={Rank=0,Level=1},[b]={Rank=250,Level=70}}
    local lobby=require(q.MatchLobby).new({Now=function()return now end,Profile=function(p)return profiles[p]end})
    assert(lobby:Join(a,'Ranked')and lobby:Join(b,'Ranked'))
    assert(lobby:IsQueued(a)and lobby:IsQueued(b))
    now+=31;lobby:Step(1);assert(lobby:IsQueued(a)and lobby:IsQueued(b))
    now+=30;lobby:Step(1)
    assert(not lobby:IsQueued(a)and not lobby:IsQueued(b)and lobby.Players[a]==lobby.Players[b])
    assert(lobby.Players[a].Mode=='Ranked')
    return 'The 60-second rank expansion starts a local match without a third player joining'
end)
q:Destroy();return report
