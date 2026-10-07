-- Executes the real MetaUI/CollectionUI builders with simulated GUI objects.
-- Mesh loading is replaced with catalogue-checked models, not actual GPU meshes.
local q=game.ReplicatedStorage.Kingdoms
local P=require(q.Progression)
local fakeArt={Prunes=0,Modules=require(q.MeshCatalog).Models}
function fakeArt.Prune()fakeArt.Prunes+=1 end
function fakeArt.Bounds()return {Minimum=Vector3.new(-10,0,-10),Maximum=Vector3.new(10,20,10)}end
function fakeArt.Clone(name,parent)
    assert(q.Geometry[name],'Missing asset '..name)
    local p=Instance.new('MeshPart');p.Name=name;p.Parent=parent;return p
end
function fakeArt.Unit(kind,parent,_,skin)
    local m=Instance.new('Model');m.Name=kind
    for _,limb in {'Torso','Head','LeftArm','RightArm','LeftLeg','RightLeg','Insignia'}do
        local prefix=skin~='Default'and skin..'_'or ''
        fakeArt.Clone(prefix..kind..'_'..limb,m)
    end
    if fakeArt.OnUnit then local fn=fakeArt.OnUnit;fakeArt.OnUnit=nil;fn()end
    if fakeArt.Fail then error('simulated mesh failure')end
    m.Parent=parent;return m
end
function fakeArt.Pose()end
factories.Art=function()return fakeArt end
local function element(kind,name,parent)local n=Instance.new(kind);n.Name=name;n.Parent=parent;return n end
local u={Page='Main',MainButtons={}}
u.Card=element('Frame','Card');u.Card.Size=UDim2.fromOffset(420,400)
u.Main=element('Frame','Main',u.Card);u.Modes=element('Frame','Modes',u.Card)
element('TextButton','AI',u.Modes);element('TextButton','Back',u.Modes)
for _,name in {'Play','Editor','Settings'}do table.insert(u.MainButtons,element('TextButton',name,u.Main))end
u.Play=u.MainButtons[1];u.EditorButton=u.MainButtons[2]
u.Title=element('TextLabel','Title',u.Card);u.Return=element('TextButton','Return',u.Main);u.Return.Visible=false
u.Online=element('TextButton','Online',u.Modes);u.QueueStatus=element('TextLabel','QueueStatus',u.Modes)
u.Settings=element('Frame','Settings',u.Card)
function u.Show(name)u.Page=name end
function u.Layout()end
local hooks={};local m=require(q.MetaUI).Build(u,hooks)
hooks.Inventory=function()u.Show('Inventory',false);m.SelectSkin(m.Profile.Equipped)end
hooks.Shop=function()u.Show('Shop',false);m.SelectSkin(m.SetPages.Shop.Selected)end
hooks.Chests=function()u.Show('Chests',false);m.ChestPreview()end
hooks.PreviewSkin=m.SelectSkin
local equipped,bought
hooks.EquipSkin=function(id)equipped=id end
hooks.BuySkin=function(id)bought=id end
local function profile(coins)
    local d=P.Normalize({Coins=coins or 2000});return P.Public(d)
end
local d=profile()
local function apply(p,extra)
    local payload={Profile=p,Persistent=false};for k,v in extra or {}do payload[k]=v end;m.Apply(payload)
end
local function visible(view)
    local count=0;for _,b in view.Buttons do if b.Visible then count+=1 end end;return count
end
apply(d)
local report={passed=0,failed=0,cases={}}
local function test(name,fn)local ok,value=pcall(fn);report[ok and 'passed'or 'failed']+=1;report.cases[name]={passed=ok,result=ok and value or tostring(value)}end
test('Inventory contains owned sets only, with equipment and no purchase action',function()
    assert(#u.MainButtons==7 and u.Main.Inventory)
    hooks.Inventory();local v=m.SetPages.Inventory
    assert(u.Page=='Inventory'and m.Pages.Inventory.Visible)
    assert(visible(v)==1 and v.Buttons.Default and not v.Buttons.Dragon)
    assert(not v.Buy and not v.Detail.Buy and v.Equip.Text=='✓ Set Equipped')
    assert(not string.find(v.Cards.Default.Status.Text,'coins'));return true
end)
test('Unowned selections cannot be previewed or equipped from inventory',function()
    local v=m.SetPages.Inventory;local before=v.Selected
    m.SelectSkin('Dragon');assert(v.Selected==before and m.Skin==before)
    equipped=nil;v.Equip.Activated.Callback();assert(equipped==nil);return true
end)
test('Shop has 24 offers, currency filters and purchase actions without equipment',function()
    hooks.Shop();local v=m.SetPages.Shop
    assert(visible(v)==24 and not v.Buttons.Default and not v.Equip and not v.Detail.Equip)
    assert(v.FeaturedButtons.Storm and v.FeaturedButtons.Dragon and v.FeaturedButtons.Oracle)
    v.Filters.Coins.Activated.Callback();assert(visible(v)==21)
    v.Filters.Robux.Activated.Callback();assert(visible(v)==3)
    v.Filters.All.Activated.Callback();return true
end)
test('Every set previews army, building decor and roads with matching assets',function()
    for _,skin in P.Skins do
        if skin.Id=='Default'then hooks.Inventory()else hooks.Shop()end
        local v=m.SetPages[u.Page]
        for _,mode in {'Army','Buildings','Roads'}do
            v.Mode=mode;m.SelectSkin(skin.Id)
            local world=v.World
            if mode=='Army'then assert(#world:GetChildren()[1]:GetChildren()==4)
            elseif mode=='Buildings'then assert(world:GetChildren()[1][skin.Id..'_Herald']and world:GetChildren()[1][skin.Id..'_RoofCrest'])
            else assert(world:GetChildren()[1][skin.Id..'_RoadTile'])end
        end
    end
    return {previews=75}
end)
test('Newly owned set enters inventory, equips and updates equipped status',function()
    d.Skins.Royal=true;apply(d);hooks.Inventory()
    local v=m.SetPages.Inventory;assert(visible(v)==2)
    m.SelectSkin('Royal');assert(v.Equip.Active);v.Equip.Activated.Callback();assert(equipped=='Royal')
    d.Equipped='Royal';apply(d);assert(not v.Equip.Active and v.Equip.Text=='✓ Set Equipped')
    v.Filters.Mythic.Activated.Callback();assert(visible(v)==0 and v.Empty.Visible)
    v.Filters.All.Activated.Callback();return true
end)
test('Shop remembers its selection independently from equipped inventory kit',function()
    hooks.Shop();m.SelectSkin('Dragon');hooks.Inventory();assert(m.Skin=='Royal')
    hooks.Shop();assert(m.Skin=='Dragon');return true
end)
test('Owned shop offer links to inventory instead of purchasing or equipping',function()
    m.SelectSkin('Royal');local v=m.SetPages.Shop
    assert(not v.Buy.Active and not v.Buy.Visible and v.ToInventory.Visible)
    v.Filters.Available.Activated.Callback();assert(visible(v)==23 and not v.Buttons.Royal.Visible)
    v.Filters.All.Activated.Callback();v.ToInventory.Activated.Callback()
    assert(u.Page=='Inventory'and m.Skin=='Royal'and not m.SetPages.Inventory.Equip.Active);return true
end)
test('Coin offers guard insufficient balance and unconfigured Robux stays disabled',function()
    hooks.Shop();m.SelectSkin('Forest');assert(m.Buy.Active and string.find(m.Buy.Text,'400'))
    m.Buy.Activated.Callback();assert(bought=='Forest')
    local poor=profile(399);apply(poor);assert(not m.Buy.Active and string.find(m.SetPages.Shop.Hint.Text,'Need 1 more coin'))
    bought=nil;m.Buy.Activated.Callback();assert(bought==nil)
    apply(d);for _,id in {'Storm','Dragon','Oracle'}do m.SelectSkin(id);assert(not m.Buy.Active and string.find(m.Buy.Text,tostring(P.Skin(id).RobuxPrice)))end
    return true
end)
test('Profile updates cannot leave a revoked set selected in inventory',function()
    hooks.Inventory();m.SelectSkin('Royal');apply(profile())
    assert(m.Skin=='Default'and not m.SetPages.Inventory.Buttons.Royal)
    assert(m.SetPages.Inventory.World:GetChildren()[1].Name=='Default_Preview')
    apply(d);return true
end)
test('Case displays 24 exact outcomes and handles policy, completion and pending state',function()
    local raw=P.Normalize(d);local rewards,signature=P.ChestRewards(raw)
    local info={Allowed=true,Pending=false,Complete=false,Price=300,Rewards=rewards,Signature=signature}
    m.ChestInfo=info;m.RefreshChest();assert(m.ChestBuy.Active)
    for _,r in rewards do assert(string.find(m.ChestRewards.Text,r.Weight..'/'..r.Total,1,true))end
    info.Allowed=false;m.RefreshChest();assert(not m.ChestBuy.Active)
    info.Allowed=true;m.ChestPending=true;m.RefreshChest();assert(not m.ChestBuy.Active)
    m.Apply({ChestDone=true});assert(m.ChestBuy.Active)
    info.Complete=true;m.RefreshChest();assert(not m.ChestBuy.Active);info.Complete=false;return true
end)
test('Case reward becomes selectable in owned inventory and duplicates show compensation',function()
    hooks.Chests();d.Skins.Storm=true
    apply(d,{Chest={Skin='Storm',Duplicate=false,Refund=0},ChestDone=true})
    assert(m.LastChestSkin=='Storm'and m.ChestSkin.Visible);m.ChestSkin.Activated.Callback()
    assert(u.Page=='Inventory'and m.Skin=='Storm'and m.SetPages.Inventory.Buttons.Storm)
    m.Apply({Chest={Skin='Storm',Duplicate=true,Refund=250},ChestDone=true});assert(string.find(m.ChestResult.Text,'250'));return true
end)
test('Leaving a page releases models and stale loads cannot repopulate it',function()
    hooks.Inventory();m.SetPages.Inventory.Mode='Army';m.SelectSkin('Royal');assert(#m.SetPages.Inventory.World:GetChildren()==1)
    u.Show('Main',false);assert(#m.SetPages.Inventory.World:GetChildren()==0)
    hooks.Inventory();fakeArt.OnUnit=function()u.Show('Main',false)end;m.SelectSkin('Royal')
    assert(#m.SetPages.Inventory.World:GetChildren()==0 and u.Page=='Main');return true
end)
test('Preview errors stay contained and later selections recover',function()
    hooks.Inventory();fakeArt.Fail=true;m.SelectSkin('Royal');fakeArt.Fail=false
    assert(m.SetPages.Inventory.Loading.Text~=''and #m.SetPages.Inventory.World:GetChildren()==0)
    m.SelectSkin('Royal');assert(m.SetPages.Inventory.Loading.Text==''and #m.SetPages.Inventory.World:GetChildren()==1);return true
end)
return report
