local UI=require(script.Parent.UI)
local P=require(script.Parent.Progression)
local Art=require(script.Parent.Art)
local Config=require(script.Parent.Config)
local Tween=game:GetService('TweenService')
local Collection={}
function Collection.Build(u,m,hooks)
    local C=UI.Colors;local function call(key,...)if hooks[key]then hooks[key](...)end end
    local function label(parent,name,text,y,h,size)local l=UI.Label(parent,name,text,UDim2.new(1,-8,0,h),UDim2.fromOffset(0,y),size or 13);l.TextWrapped=true;return l end
    local function viewport(page,name,y,h)
        local v=Instance.new('ViewportFrame');v.Name=name;v.Size=UDim2.new(1,-8,0,h);v.Position=UDim2.fromOffset(0,y);v.BackgroundColor3=C.Inset;v.BorderSizePixel=0;v.Ambient=Color3.fromRGB(196,196,202);v.LightColor=Color3.fromRGB(255,246,219);v.LightDirection=Vector3.new(-1,-1,-1);v.Parent=page
        local cam=Instance.new('Camera');cam.Parent=v;v.CurrentCamera=cam
        local world=Instance.new('WorldModel');world.Parent=v;return v,cam,world
    end
    local function army(parent,id)
        for i,kind in {'Defender','Archer','Runner','Peasant'}do local model=Art.Unit(kind,parent,Config.Colors[1],id);Art.Pose(model,CFrame.new((i-2.5)*1.4,0,0)*CFrame.Angles(0,math.pi,0),0,false,false)end
    end
    local function armyCamera(cam)cam.CFrame=CFrame.lookAt(Vector3.new(0,2.2,6.0),Vector3.new(0,1.15,0));cam.FieldOfView=36 end
    local page=m.Pages.Shop
    for _,child in page:GetChildren()do child:Destroy()end
    page.CanvasSize=UDim2.fromOffset(0,595)
    m.Balance=label(page,'Balance','Монеты: —',0,30,15);m.Balance.Size=UDim2.new(.5,0,0,30);m.Balance.TextColor3=C.Gold
    UI.Button(page,'Chests','Сундуки →',UDim2.new(.5,-8,0,32),UDim2.fromScale(.5,0),function()call('Chests')end)
    m.ViewMode='Army';m.ViewButtons={}
    for i,item in {{'Army','Армия'},{'Buildings','Базы'},{'Roads','Дороги'}}do
        local b=UI.Button(page,item[1],item[2],UDim2.new(1/3,-5,0,30),UDim2.new((i-1)/3,0,0,40),function()m.ViewMode=item[1];m.SelectSkin(m.Skin)end);b.TextSize=12;m.ViewButtons[item[1]]=b
    end
    local vp,cam,world=viewport(page,'Preview',78,165);m.World=world
    m.PreviewLoading=label(page,'Loading','',82,24,12)
    m.SkinName=label(page,'SkinName','',250,34,14)
    local list=Instance.new('ScrollingFrame');list.Name='SkinList';list.Position=UDim2.fromOffset(0,290);list.Size=UDim2.new(1,-8,0,113);list.BackgroundColor3=C.Panel;list.BorderSizePixel=0;list.ScrollBarThickness=4;list.CanvasSize=UDim2.fromOffset(0,math.ceil(#P.Skins/3)*46);list.Parent=page
    m.SkinButtons={}
    for i,skin in P.Skins do local b=UI.Button(list,skin.Id,skin.Name,UDim2.new(1/3,-5,0,41),UDim2.new((i-1)%3/3,0,0,math.floor((i-1)/3)*46),function()call('PreviewSkin',skin.Id)end);b.TextSize=11;b.TextWrapped=true;m.SkinButtons[skin.Id]=b end
    m.Buy=UI.Button(page,'Buy','',UDim2.new(.5,-8,0,40),UDim2.fromOffset(0,413),function()call('BuySkin',m.Skin)end)
    m.Equip=UI.Button(page,'Equip','Надеть',UDim2.new(.5,-4,0,40),UDim2.new(.5,0,0,413),function()call('EquipSkin',m.Skin)end)
    local hint=label(page,'Hint','Один набор: армия, здания и свои дороги. Характеристики прежние.',460,33,11);hint.TextColor3=C.Muted
    label(page,'CoinsTitle','Монеты за Robux',498,23,12);m.Products={}
    for i,product in P.Products do local b=UI.Button(page,product.Id,product.Coins..' монет\n'..(product.ProductId>0 and product.Price..' Robux'or 'Не подключено'),UDim2.new(1/3,-5,0,48),UDim2.new((i-1)/3,0,0,525),function()call('CoinPack',product.Id)end);b.TextSize=11;b.TextWrapped=true;b.Active=product.ProductId>0;b.AutoButtonColor=b.Active;m.Products[product.Id]=b end
    local oldRefresh=m.RefreshShop
    function m.RefreshShop()
        oldRefresh();local skin=P.Skin(m.Skin)
        if skin.ChestOnly and not(m.Profile and m.Profile.Skins[m.Skin])then m.Buy.Text='Из сундука';m.Buy.Active=false;m.Buy.BackgroundColor3=C.Inset end
        m.SkinName.Text=skin.Name..(skin.ChestOnly and ' · из сундука'or skin.Price>0 and ' · '..skin.Price..' монет'or ' · бесплатно')
        if m.Profile and m.Profile.Skins[m.Skin]then m.SkinName.Text=skin.Name..' · в коллекции'end
    end
    function m.SelectSkin(id)
        if not P.Skin(id)then return end;m.Skin=id;m.PreviewSerial=(m.PreviewSerial or 0)+1
        local serial=m.PreviewSerial;local mode=m.ViewMode
        for key,b in m.ViewButtons do b.BackgroundColor3=key==mode and C.Blue or C.Inset end
        for key,b in m.SkinButtons do b.BackgroundColor3=key==id and C.Blue or C.Inset end
        m.RefreshShop();m.PreviewLoading.Text='Загружаем модели…'
        for _,child in world:GetChildren()do child:Destroy()end;Art.Prune()
        local temp=Instance.new('Model');temp.Name='Набор'
        if mode=='Army'then army(temp,id)
        elseif mode=='Buildings'then
            local base=Art.Bounds('Castle_Upgrade3');local ground=-base.Minimum.Y;local height=base.Maximum.Y+ground
            Art.Clone('Castle_Upgrade3',temp,CFrame.new(0,ground,0),nil,id)
            Art.Clone(id..'_Herald',temp,CFrame.new(0,3,9.75));Art.Clone(id..'_RoofCrest',temp,CFrame.new(0,height-.1,0))
        else for i=-1,1 do Art.Clone(id..'_RoadTile',temp,CFrame.new(0,0,i*4))end end
        if serial~=m.PreviewSerial then temp:Destroy();return end
        for _,child in world:GetChildren()do child:Destroy()end;temp.Parent=world;m.PreviewLoading.Text=''
        if mode=='Army'then armyCamera(cam)
        elseif mode=='Buildings'then cam.CFrame=CFrame.lookAt(Vector3.new(28,29,47),Vector3.new(0,8,0));cam.FieldOfView=36
        else cam.CFrame=CFrame.lookAt(Vector3.new(6,8,11),Vector3.new(0,.15,0));cam.FieldOfView=42 end
    end
    page=Instance.new('ScrollingFrame');page.Name='Chests';page.BackgroundTransparency=1;page.BorderSizePixel=0;page.ScrollBarThickness=4;page.Visible=false;page.Parent=u.Card;m.Pages.Chests=page
    m.ChestBalance=label(page,'Balance','Монеты: —',0,30,15);m.ChestBalance.Size=UDim2.new(.5,0,0,30);m.ChestBalance.TextColor3=C.Gold
    UI.Button(page,'Collection','Коллекция →',UDim2.new(.5,-8,0,32),UDim2.fromScale(.5,0),function()call('Shop')end)
    local chestView,chestCam,chestWorld=viewport(page,'Preview',42,150)
    m.ChestResult=label(page,'Result','Один новый набор. Повторов нет.',196,44,14);m.ChestResult.TextColor3=C.Gold
    m.ChestOdds=label(page,'Odds','Загружаем награды…',244,48,12)
    m.ChestBuy=UI.Button(page,'Open','Купить и открыть · 300',UDim2.new(1,-8,0,42),UDim2.fromOffset(0,302),function()call('OpenChest')end)
    m.ChestSkin=UI.Button(page,'ViewReward','Посмотреть полученный набор',UDim2.new(1,-8,0,34),UDim2.fromOffset(0,354),function()if m.LastChestSkin then call('Shop');m.SelectSkin(m.LastChestSkin)end end);m.ChestSkin.Visible=false
    m.ChestRewards=label(page,'Rewards','',400,50,12);m.ChestRewards.TextYAlignment=Enum.TextYAlignment.Top
    function m.ChestPreview(id)
        m.ChestPreviewSerial=(m.ChestPreviewSerial or 0)+1;local serial=m.ChestPreviewSerial
        for _,child in chestWorld:GetChildren()do child:Destroy()end;Art.Prune()
        local temp=Instance.new('Model')
        if id then army(temp,id)else Art.Clone('CollectionChest',temp,CFrame.identity)end
        if serial~=m.ChestPreviewSerial then temp:Destroy();return end
        for _,child in chestWorld:GetChildren()do child:Destroy()end;temp.Parent=chestWorld
        if id then armyCamera(chestCam)else chestCam.CFrame=CFrame.lookAt(Vector3.new(2.9,2.2,4),Vector3.new(0,.7,0));chestCam.FieldOfView=36 end
    end
    function m.RefreshChest()
        m.ChestBalance.Text='Монеты: '..(m.Profile and m.Profile.Coins or '—')
        local info=m.ChestInfo;local pool=info and info.Pool or {};local count=#pool
        local enabled=info and info.Allowed and count>0 and m.Profile and m.Profile.Coins>=info.Price and not m.ChestPending
        m.ChestBuy.Active=enabled==true;m.ChestBuy.AutoButtonColor=m.ChestBuy.Active;m.ChestBuy.BackgroundColor3=m.ChestBuy.Active and C.Blue or C.Inset
        m.ChestBuy.Text=m.ChestPending and 'Открываем…'or count==0 and info and 'Коллекция собрана'or 'Купить и открыть · '..(info and info.Price or 300)
        if not info or info.Pending then m.ChestOdds.Text='Проверяем доступность сундуков…'
        elseif not info.Allowed then m.ChestOdds.Text='Случайные покупки недоступны для этого аккаунта Roblox.'
        elseif count==0 then m.ChestOdds.Text='Все 25 наборов уже в коллекции.'
        else m.ChestOdds.Text='Осталось '..count..' наборов. Каждый: 1/'..count..' (≈ '..string.format('%.4f',100/count)..'%).'end
        local lines={'Возможные награды до покупки:'}
        for _,id in pool do table.insert(lines,P.Skin(id).Name..' — 1/'..count..' (≈ '..string.format('%.4f',100/count)..'%)')end
        m.ChestRewards.Text=table.concat(lines,'\n');m.ChestRewards.Size=UDim2.new(1,-8,0,24+#pool*40);page.CanvasSize=UDim2.fromOffset(0,440+#pool*40)
    end
    local apply=m.Apply
    function m.HidePreviews()
        m.PreviewSerial=(m.PreviewSerial or 0)+1;m.ChestPreviewSerial=(m.ChestPreviewSerial or 0)+1
        for _,child in world:GetChildren()do child:Destroy()end
        for _,child in chestWorld:GetChildren()do child:Destroy()end
        Art.Prune()
    end
    local show=u.ShowMenu
    function u.ShowMenu(name)
        if name~='Shop'and name~='Chests'then m.HidePreviews()
        elseif name=='Shop'then for _,child in chestWorld:GetChildren()do child:Destroy()end;Art.Prune()
        else for _,child in world:GetChildren()do child:Destroy()end;Art.Prune()end
        show(name)
    end
    function m.Apply(data)
        apply(data)
        if data.ChestInfo then m.ChestInfo=data.ChestInfo end
        if data.ChestDone then m.ChestPending=false;m.ChestRequest=nil end
        m.RefreshChest()
        if data.Chest then
            m.LastChestSkin=data.Chest.Skin;m.ChestSkin.Visible=true;m.ChestResult.Text='Получено: '..P.Skin(data.Chest.Skin).Name
            local flash=Tween:Create(chestView,TweenInfo.new(.3),{BackgroundColor3=C.Gold});flash:Play()
            task.delay(.3,function()m.ChestPreview(data.Chest.Skin);Tween:Create(chestView,TweenInfo.new(.4),{BackgroundColor3=C.Inset}):Play()end)
        end
    end
end
return Collection
