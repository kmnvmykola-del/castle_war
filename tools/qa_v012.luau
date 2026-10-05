local q=Instance.new('Folder');q.Name='Version012QA';q.Parent=game.ReplicatedStorage
for _,name in {'SkinStyles','Progression','PlayerData','AccountServer','RoadCosmetics'}do game.ReplicatedStorage.Kingdoms[name]:Clone().Parent=q end
local P=require(q.Progression);local Data=require(q.PlayerData);local R=require(q.RoadCosmetics);local Account=require(q.AccountServer)
local H=game:GetService('HttpService');local function copy(v)return v and H:JSONDecode(H:JSONEncode(v))end
local report={passed=0,failed=0,cases={}}
local function test(name,fn)local ok,value=pcall(fn);report[ok and 'passed'or 'failed']+=1;report.cases[name]={passed=ok,result=ok and value or tostring(value)}end
local function store()
    local s={Data={},Retry=false,Fail=false}
    function s:GetAsync(k)if self.Fail then error('offline')end;return copy(self.Data[k])end
    function s:UpdateAsync(k,fn)if self.Fail then error('offline')end;if self.Retry then fn(copy(self.Data[k]))end;local v=fn(copy(self.Data[k]));if v then self.Data[k]=copy(v)end;return copy(v)end
    return s
end
local function profile(coins,roll,s)
    local d=Data.new({Store=s,Roll=roll});assert(d:Load(1));assert(d:Receipt(1,'qa-credit',coins or 10000));return d
end
test('25 sets, old prices, 21 chest-only additions',function()
    assert(#P.Skins==25 and P.ChestPrice==300);local seen={};local chest=0
    for _,v in P.Skins do assert(not seen[v.Id]);seen[v.Id]=true;if v.ChestOnly then chest+=1;assert(v.Price==0)end end
    assert(chest==21 and P.Skin('Veteran').Price==400 and P.Skin('Royal').Price==800 and P.Skin('Dark').Price==1200)
    local pool=P.ChestPool(P.Normalize());assert(#pool==24);return {sets=25,chestOnly=chest,initialRewards=#pool}
end)
test('Every equal interval selects its advertised reward',function()
    for i=1,24 do local d=profile(300,function()return (i-.5)/24 end);local pool,sig=P.ChestPool(d.Profiles[1]);local ok,r=d:OpenChest(1,'interval-'..i,sig);assert(ok and r.Skin==pool[i]and d.Profiles[1].Coins==0)end
    return 'All 24 intervals matched the displayed order'
end)
test('24 chests collect every paid set without a duplicate',function()
    local d=profile();local seen={};for i=1,24 do local pool,sig=P.ChestPool(d.Profiles[1]);assert(#pool==25-i);local ok,r=d:OpenChest(1,'collect-'..i,sig);assert(ok and not seen[r.Skin]);seen[r.Skin]=true end
    assert(#P.ChestPool(d.Profiles[1])==0 and d.Profiles[1].Coins==2800);assert(not d:OpenChest(1,'full-collection',''));return {collected=24,spent=7200}
end)
test('Repeated requests and save callback retries spend once',function()
    local s=store();s.Retry=true;local calls=0;local d=profile(1000,function()calls+=1;return .5 end,s);local _,sig=P.ChestPool(d.Profiles[1]);local ok,r=d:OpenChest(1,'retry-request',sig);assert(ok);local first=r.Skin
    local ok2,r2=d:OpenChest(1,'retry-request',sig);assert(ok2 and r2.AlreadyApplied and r2.Skin==first and d.Profiles[1].Coins==700 and calls==2)
    local again=Data.new({Store=s});assert(again:Load(1));local ok3,r3=again:OpenChest(1,'retry-request',sig);assert(ok3 and r3.Skin==first and again.Profiles[1].Coins==700);return 'One durable reward and charge across retries and reload'
end)
test('Insufficient funds, bad request and changed odds preserve coins',function()
    local d=profile(299);local _,sig=P.ChestPool(d.Profiles[1]);assert(not d:OpenChest(1,'no-coins-request',sig)and d.Profiles[1].Coins==299)
    assert(not d:OpenChest(1,'bad',sig));d:Receipt(1,'more',1000);assert(d:Buy(1,'Veteran'));assert(not d:OpenChest(1,'stale-odds-request',sig)and d.Profiles[1].Coins==899)
    assert(not d:Buy(1,'Forest')and not d:Equip(1,'Forest'));return 'No charge or reward from rejected requests'
end)
test('Failed persistence applies neither charge nor reward',function()
    local s=store();local d=profile(1000,nil,s);local _,sig=P.ChestPool(d.Profiles[1]);s.Fail=true;assert(not d:OpenChest(1,'failed-save-request',sig));assert(d.Profiles[1].Coins==1000 and #P.ChestPool(d.Profiles[1])==24);return true
end)
test('Old ownership, map and settings survive migration and chest purchase',function()
    local s=store();s.Data.Player_1={Coins=1000,Skins={Default=true,Royal=true},Equipped='Royal',Map={Name='custom'},Prefs={Music=.2}}
    local d=Data.new({Store=s});assert(d:Load(1));local pool,sig=P.ChestPool(d.Profiles[1]);assert(#pool==23);assert(d:OpenChest(1,'migration-request',sig))
    local v=d.Profiles[1];assert(v.Coins==700 and v.Skins.Royal and v.Equipped=='Royal'and v.Map.Name=='custom'and v.Prefs.Music==.2);return true
end)
test('Server policy gates both pending and restricted accounts',function()
    local d=profile(1000);local player={UserId=1};local a=setmetatable({Data=d,Owners={[1]=player},Loading={},ChestEligibility={}},Account);local _,sig=P.ChestPool(d.Profiles[1]);local payload={RequestId='policy-request',Signature=sig}
    assert(not a:OpenChest(player,payload));a.ChestEligibility[player]=false;assert(not a:OpenChest(player,payload));assert(d.Profiles[1].Coins==1000);a.ChestEligibility[player]=true;assert(a:OpenChest(player,payload));return true
end)
local function graph(roads,edges,ids)local nodes={};for _,id in ids do table.insert(nodes,{Id=id})end;return {Definition={Nodes=nodes},Roads=roads,Edges=edges}end
test('Owned road changes with capture and loss',function()
    local road={A='a',B='b'};local map=graph({road},{{Roads={road},Controls={}}},{'a','b'});local sites={a={Owner=1},b={Owner=0}}
    assert(R.Owners(map,sites)[1]==0);sites.b.Owner=1;assert(R.Owners(map,sites)[1]==1);sites.b.Owner=2;assert(R.Owners(map,sites)[1]==0);sites.a.Owner=2;assert(R.Owners(map,sites)[1]==2);return true
end)
test('Neutral or hostile intermediate control prevents road cosmetics',function()
    local road={A='a',B='b'};local map=graph({road},{{Roads={road},Controls={'v'}}},{'a','b','v'});local sites={a={Owner=1},b={Owner=1},v={Owner=0}}
    assert(R.Owners(map,sites)[1]==0);sites.v.Owner=2;assert(R.Owners(map,sites)[1]==0);sites.v.Owner=1;assert(R.Owners(map,sites)[1]==1);return true
end)
test('Shared segments remain neutral when owners disagree',function()
    local x,y={A='a',B='b'},{A='c',B='d'};local map=graph({x,y},{{Roads={x,y},Controls={}}},{'a','b','c','d'});local sites={a={Owner=1},b={Owner=1},c={Owner=2},d={Owner=2}}
    assert(R.Owners(map,sites)[1]==0);sites.c.Owner=1;sites.d.Owner=1;assert(R.Owners(map,sites)[1]==1);return true
end)
test('Junction chains inherit only unanimous frontier ownership',function()
    local x,y,z,w={A='a',B='j'},{A='j',B='k'},{A='k',B='b'},{A='k',B='c'};local roads={x,y,z,w};local edges={};for _,r in roads do table.insert(edges,{Roads={r},Controls={}})end
    local map=graph(roads,edges,{'a','b','c','j','k'});local sites={a={Owner=1},b={Owner=1},c={Owner=1}};for _,o in R.Owners(map,sites)do assert(o==1)end
    sites.c.Owner=0;for _,o in R.Owners(map,sites)do assert(o==0)end;return true
end)
q:Destroy();return report
