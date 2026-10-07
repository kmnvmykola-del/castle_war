local Guide=require(game.ReplicatedStorage.Kingdoms.BattleGuide)
local report={passed=0,failed=0,cases={}}
local function test(name,fn)local ok,value=pcall(fn);report[ok and 'passed'or 'failed']+=1;report.cases[name]={passed=ok,result=ok and value or tostring(value)}end
local function snapshot(side)return {ViewerSide=side or 1,Sites={Castle={Owner=side or 1},Village={Owner=0},Enemy={Owner=side==2 and 1 or 2}},Units={}}end
test('Enemy and neutral selection never advance the friendly-selection step',function()
    local g=Guide.new();g:Begin(snapshot());g:Select(2);g:Select(0);assert(g.Step==1);g:Select(1);assert(g.Step==2);return true
end)
test('A friendly transfer does not satisfy the capture order',function()
    local g=Guide.new();g:Begin(snapshot());g:Select(1);g:Order('Castle',1);assert(g.Target==nil and g.Step==2);return true
end)
test('The guide waits for actual friendly troops after an order',function()
    local s=snapshot();local g=Guide.new();g:Begin(s);g:Select(1);g:Order('Village',0)
    assert(not g:Observe(s)and g.Step==2);s.Units={{1,'Defender',2}};assert(not g:Observe(s)and g.Step==2)
    s.Units={{2,'Defender',1}};assert(not g:Observe(s)and g.Step==3);return true
end)
test('Only capturing the ordered building completes the guide',function()
    local s=snapshot();local g=Guide.new();g:Begin(s);g:Select(1);g:Order('Village',0)
    s.Sites.Enemy.Owner=1;assert(not g:Observe(s)and g.Active)
    s.Sites.Village.Owner=1;assert(g:Observe(s)and not g.Active);assert(not g:Observe(s));return true
end)
test('Blue is local even when the player owns server side two',function()
    local s=snapshot(2);local g=Guide.new();g:Begin(s);g:Select(1);assert(g.Step==1);g:Select(2);g:Order('Village',0)
    s.Units={{1,'Archer',2}};g:Observe(s);assert(g.Step==3);s.Sites.Village.Owner=2;assert(g:Observe(s));return true
end)
test('Skipping clears pending progress and replay starts cleanly',function()
    local s=snapshot();local g=Guide.new();g:Begin(s);g:Select(1);g:Order('Village',0);g:Close();s.Sites.Village.Owner=1
    assert(not g:Observe(s));g:Begin(snapshot());assert(g.Active and g.Step==1 and g.Target==nil);return true
end)
test('The guide responds to narrow screens and hides behind menus',function()
    local UI=require(game.ReplicatedStorage.Kingdoms.UI);local u=UI.Build({PlayerGui=Instance.new('Folder')},{})
    local camera=workspace.CurrentCamera;local before=camera.ViewportSize;camera.ViewportSize={X=390,Y=844};u.Layout()
    u.Menu.Visible=false;u.UpdateBattleGuide(true,2);assert(u.BattleGuide.Visible and u.BattleGuide.Size.X.Offset==330)
    assert(string.find(u.BattleGuide.Hint.Text,'connected'));u.Menu.Visible=true;u.SyncHUD();assert(not u.BattleGuide.Visible)
    camera.ViewportSize=before;return true
end)
return report
