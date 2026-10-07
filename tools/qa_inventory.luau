local q=game.ReplicatedStorage.Kingdoms
local P=require(q.Progression);local Data=require(q.PlayerData);local Account=require(q.AccountServer)
local H=game:GetService('HttpService')
local function copy(v)return v and H:JSONDecode(H:JSONEncode(v))end
local report={passed=0,failed=0,cases={}}
local function test(name,fn)
    local ok,value=pcall(fn);report[ok and 'passed'or 'failed']+=1;report.cases[name]={passed=ok,result=ok and value or tostring(value)}
end
local function store()
    local s={Data={},Retry=false,Fail=false}
    function s:GetAsync(key)if self.Fail then error('offline')end;return copy(self.Data[key])end
    function s:UpdateAsync(key,fn)
        if self.Fail then error('offline')end
        if self.Retry then fn(copy(self.Data[key]))end
        local d=fn(copy(self.Data[key]));if d then self.Data[key]=copy(d)end;return copy(d)
    end
    return s
end
local function profile(coins,roll,s)
    local data=Data.new({Store=s,Roll=roll});assert(data:Load(1));assert(data:Receipt(1,'credit',coins or 10000));return data
end
local function open(d,id)local _,signature=P.ChestPool(d.Profiles[1]);return d:OpenChest(1,id,signature)end
test('25 complete sets, 21 coin purchases, three premium sets',function()
    local ordinary,premium=0,0;local seen={}
    for _,skin in P.Skins do
        assert(not seen[skin.Id]);seen[skin.Id]=true
        if skin.RobuxPrice then premium+=1;assert(skin.Price==0 and skin.Rarity=='Mythic'and typeof(skin.GamePassId)=='number'and skin.GamePassId>=0 and skin.GamePassId%1==0)
        elseif skin.Price>0 then ordinary+=1 end
    end
    assert(#P.Skins==25 and ordinary==21 and premium==3 and P.ChestPrice==300)
    assert(P.Skin('Storm').RobuxPrice==199 and P.Skin('Dragon').RobuxPrice==399 and P.Skin('Oracle').RobuxPrice==699)
    return {sets=25,coinOffers=ordinary,premiumOffers=premium}
end)
test('Every ticket matches the advertised numerical odds',function()
    local _,_,total=P.ChestPool();assert(total==84000)
    local counts={};for i=0,total-1 do local id=P.DrawChest((i+.5)/total);counts[id]=(counts[id]or 0)+1 end
    local tiers={};for _,skin in P.Skins do if skin.Id~='Default'then assert(counts[skin.Id]==skin.Weight);tiers[skin.Rarity]=(tiers[skin.Rarity]or 0)+counts[skin.Id]end end
    assert(tiers.Common/total==.6 and tiers.Rare/total==.3 and tiers.Epic/total==.09 and tiers.Mythic/total==.01)
    assert(counts.Storm/total==.005 and counts.Dragon/total==.003 and counts.Oracle/total==.002)
    return {tickets=total,mythicPercent=1}
end)
test('Inventory changes never increase the mythic chance',function()
    local empty=P.Normalize();local full=P.Normalize()
    for _,skin in P.Skins do if skin.Rarity~='Mythic'then full.Skins[skin.Id]=true end end
    local a,signature=P.ChestRewards(empty);local b,nextSignature=P.ChestRewards(full)
    assert(signature==nextSignature and #a==24 and #b==24)
    for i,r in a do assert(r.Chance==b[i].Chance and r.Weight==b[i].Weight)end
    return true
end)
test('Roll endpoints and every boundary select a valid set',function()
    local pool,_,total=P.ChestPool();local sum=0
    assert(P.DrawChest(0)==pool[1]and P.DrawChest(1)==pool[#pool])
    for i,id in pool do
        assert(P.DrawChest((sum+.5)/total)==id);sum+=P.Skin(id).Weight
        if i<#pool then assert(P.DrawChest((sum+.5)/total)==pool[i+1])end
    end
    return true
end)
test('All ordinary sets can be bought and equipped, premiums cannot bypass Robux',function()
    for _,skin in P.Skins do if skin.Price>0 then
        local d=profile();assert(d:Buy(1,skin.Id));assert(d.Profiles[1].Coins==10000-skin.Price)
        assert(d:Equip(1,skin.Id));assert(d.Profiles[1].Equipped==skin.Id);assert(not d:Buy(1,skin.Id))
    end end
    local d=profile();for _,id in {'Storm','Dragon','Oracle'}do assert(not d:Buy(1,id));assert(not d:Equip(1,id))end
    assert(d.Profiles[1].Coins==10000);return true
end)
test('Duplicate refunds, repeat requests and UpdateAsync retries apply once',function()
    local s=store();s.Retry=true;local d=profile(1000,function()return 0 end,s)
    assert(open(d,'new-reward'));local id=P.DrawChest(0);assert(d.Profiles[1].Coins==700)
    local ok,r=open(d,'duplicate-reward');assert(ok and r.Duplicate and r.Refund==P.Skin(id).DuplicateCoins)
    local coins=d.Profiles[1].Coins;assert(coins==400+r.Refund)
    local _,repeated=open(d,'duplicate-reward');assert(repeated.AlreadyApplied and repeated.Duplicate and repeated.Refund==r.Refund and d.Profiles[1].Coins==coins)
    return {duplicateRefund=r.Refund,balance=coins}
end)
test('All rarity refunds match the UI and never fund a free case',function()
    local pool,_,total=P.ChestPool();local sum=0
    for _,id in pool do
        local skin=P.Skin(id);local roll=(sum+.5)/total;sum+=skin.Weight
        local d=profile(600,function()return roll end);assert(open(d,'first-reward'));local ok,r=open(d,'second-reward')
        assert(ok and r.Duplicate and r.Refund==skin.DuplicateCoins and r.Refund<P.ChestPrice and d.Profiles[1].Coins==r.Refund)
    end
    return true
end)
test('Insufficient coins and outdated odds never spend or award',function()
    local d=profile(299);assert(not open(d,'too-few-coins'));assert(d.Profiles[1].Coins==299)
    d=profile(300);assert(not d:OpenChest(1,'wrong-odds','old'));assert(d.Profiles[1].Coins==300 and P.CollectionCount(d.Profiles[1])==1)
    return true
end)
test('Failed saves leave coins and ownership unchanged',function()
    local s=store();local d=profile(600,function()return 0 end,s);s.Fail=true
    assert(not open(d,'offline-case'));assert(not d:Buy(1,'Royal'));assert(not d:GrantPass(1,'Oracle'))
    assert(d.Profiles[1].Coins==600 and P.CollectionCount(d.Profiles[1])==1);return true
end)
test('Full collection closes case purchases',function()
    local d=profile();for _,skin in P.Skins do d.Profiles[1].Skins[skin.Id]=true end
    assert(not open(d,'full-collection')and d.Profiles[1].Coins==10000);return true
end)
test('Older chest history, maps and settings survive migration',function()
    local s=store();s.Data.Player_1={Coins=700,Skins={Royal=true},Equipped='Royal',Map={Name='Saved'},Prefs={Music=.25},Chests={['old-request']='Royal'}}
    local d=Data.new({Store=s,Roll=function()return 0 end});assert(d:Load(1));local ok,r=open(d,'old-request')
    assert(ok and r.AlreadyApplied and r.Skin=='Royal'and d.Profiles[1].Coins==700)
    assert(open(d,'migrated-case'));local p=d.Profiles[1];assert(p.Map.Name=='Saved'and p.Prefs.Music==.25 and p.Equipped=='Royal'and p.Skins.Royal)
    return true
end)
test('Roblox ownership is required before a premium kit is granted',function()
    local d=profile();local player={UserId=1,Parent=true};local skin=P.Skin('Oracle');local old=skin.GamePassId;skin.GamePassId=12345
    local owns=false;local fail=false
    local account=setmetatable({Data=d,Owners={[1]=player},Loading={},Publish=function()end,Notify=function()end,Market={UserOwnsGamePassAsync=function()if fail then error('offline')end;return owns end}},Account)
    assert(not account:VerifyPass(player,'Oracle')and not d.Profiles[1].Skins.Oracle)
    fail=true;assert(not account:VerifyPass(player,'Oracle'));fail=false;owns=true
    assert(account:VerifyPass(player,'Oracle'));assert(d.Profiles[1].Skins.Oracle and d.Profiles[1].Coins==10000)
    local revision=d.Profiles[1].Revision;assert(account:VerifyPass(player,'Oracle'));assert(d.Profiles[1].Revision==revision)
    skin.GamePassId=old;return true
end)
test('Policy pending or restricted blocks the case on the server',function()
    local d=profile();local player={UserId=1};local a=setmetatable({Data=d,ChestEligibility={},Profile=function()return d.Profiles[1]end},Account)
    local _,signature=P.ChestPool(d.Profiles[1]);local payload={RequestId='policy-request',Signature=signature}
    assert(not a:OpenChest(player,payload));a.ChestEligibility[player]=false;assert(not a:OpenChest(player,payload))
    assert(d.Profiles[1].Coins==10000);a.ChestEligibility[player]=true;assert(a:OpenChest(player,payload));return true
end)
return report
