local UI=require(script.Parent.UI)
local P=require(script.Parent.Progression)
local Art=require(script.Parent.Art)
local Config=require(script.Parent.Config)
local Meta={}
function Meta.Build(u,hooks)
    local C=UI.Colors;local function call(key,...)if hooks[key]then hooks[key](...)end end
    local m={Skin='Default',Models={},Profile=nil,Boards={}}
    local settings=u.MainButtons[3];table.remove(u.MainButtons,3)
    local profile=UI.Button(u.Main,'Profile','Профиль',UDim2.new(1,0,0,44),UDim2.new(),function()call('Profile')end)
    local shop=UI.Button(u.Main,'Shop','Магазин · скины',UDim2.new(1,0,0,44),UDim2.new(),function()call('Shop')end)
    local leaders=UI.Button(u.Main,'Leaders','Таблица лидеров',UDim2.new(1,0,0,44),UDim2.new(),function()call('Leaders')end)
    for _,b in {profile,shop,leaders,settings}do table.insert(u.MainButtons,b)end
    u.Ranked=UI.Button(u.Modes,'Ranked','Ранговый · 0',UDim2.new(1,0,0,48),UDim2.fromOffset(0,120),function()call('Ranked')end);u.Ranked.BackgroundColor3=C.Gold;u.Ranked.TextColor3=C.Panel
    m.Pages={}
    for _,name in {'Profile','Shop','Leaders'}do
        local page=Instance.new('ScrollingFrame');page.Name=name;page.BackgroundTransparency=1;page.BorderSizePixel=0;page.ScrollBarThickness=3;page.Visible=false;page.Parent=u.Card;page.CanvasSize=UDim2.fromOffset(0,name=='Shop'and 438 or 320);m.Pages[name]=page
    end
    m.Back=UI.Button(u.Card,'MetaBack','Назад',UDim2.new(1,-40,0,36),UDim2.new(0,20,1,-48),function()call('MetaBack')end);m.Back.Visible=false
    local page=m.Pages.Profile
    m.Stats=UI.Label(page,'Stats','Профиль загружается…',UDim2.new(1,-8,0,226),UDim2.fromOffset(0,0),15);m.Stats.TextWrapped=true;m.Stats.TextYAlignment=Enum.TextYAlignment.Top
    m.Reward=UI.Label(page,'Reward','',UDim2.new(1,-8,0,62),UDim2.fromOffset(0,230),13);m.Reward.TextWrapped=true;m.Reward.TextColor3=C.Gold
    m.Persistence=UI.Label(page,'Persistence','',UDim2.new(1,-8,0,38),UDim2.fromOffset(0,296),11);m.Persistence.TextWrapped=true;m.Persistence.TextColor3=C.Muted
    UI.Button(page,'Retry','Обновить профиль',UDim2.new(1,-8,0,36),UDim2.fromOffset(0,340),function()call('RefreshProfile')end);page.CanvasSize=UDim2.fromOffset(0,385)
    page=m.Pages.Shop
    m.Balance=UI.Label(page,'Balance','Монеты: —',UDim2.new(1,-8,0,26),UDim2.new(),15);m.Balance.TextColor3=C.Gold
    local viewport=Instance.new('ViewportFrame');viewport.Name='Preview';viewport.Size=UDim2.new(1,-8,0,156);viewport.Position=UDim2.fromOffset(0,30);viewport.BackgroundColor3=C.Inset;viewport.BorderSizePixel=0;viewport.Ambient=Color3.fromRGB(190,190,190);viewport.LightColor=Color3.new(1,1,1);viewport.Parent=page
    local cam=Instance.new('Camera');cam.CFrame=CFrame.lookAt(Vector3.new(0,2.2,4.7),Vector3.new(0,1.1,0));cam.FieldOfView=34;cam.Parent=viewport;viewport.CurrentCamera=cam
    local world=Instance.new('WorldModel');world.Parent=viewport;m.World=world
    m.SkinButtons={}
    for i,skin in P.Skins do
        local b=UI.Button(page,skin.Id,skin.Name,UDim2.new(.25,-5,0,34),UDim2.new((i-1)/4,0,0,195),function()call('PreviewSkin',skin.Id)end);b.TextSize=11;m.SkinButtons[skin.Id]=b
    end
    m.SkinName=UI.Label(page,'SkinName','',UDim2.new(1,-8,0,25),UDim2.fromOffset(0,236),14)
    m.Buy=UI.Button(page,'Buy','',UDim2.new(.5,-8,0,40),UDim2.fromOffset(0,269),function()call('BuySkin',m.Skin)end)
    m.Equip=UI.Button(page,'Equip','Надеть',UDim2.new(.5,-4,0,40),UDim2.new(.5,0,0,269),function()call('EquipSkin',m.Skin)end)
    UI.Label(page,'CoinsTitle','Купить монеты за Robux',UDim2.new(1,-8,0,22),UDim2.fromOffset(0,321),13)
    m.Products={}
    for i,product in P.Products do
        local b=UI.Button(page,product.Id,product.Coins..' монет\n'..(product.ProductId>0 and product.Price..' Robux'or 'Не подключено'),UDim2.new(1/3,-5,0,48),UDim2.new((i-1)/3,0,0,349),function()call('CoinPack',product.Id)end);b.TextSize=11;b.TextWrapped=true;b.Active=product.ProductId>0;b.AutoButtonColor=b.Active;m.Products[product.Id]=b
    end
    local hint=UI.Label(page,'Hint','Оформление сохраняет характеристики войск.',UDim2.new(1,-8,0,30),UDim2.fromOffset(0,403),11);hint.TextWrapped=true;hint.TextColor3=C.Muted
    page=m.Pages.Leaders
    m.RankTab=UI.Button(page,'Rank','По рангу',UDim2.new(.5,-8,0,36),UDim2.new(),function()call('Board','Rank')end)
    m.WinsTab=UI.Button(page,'Wins','По победам PvP',UDim2.new(.5,-4,0,36),UDim2.fromScale(.5,0),function()call('Board','Wins')end)
    m.Mine=UI.Label(page,'Mine','Загружаем таблицу…',UDim2.new(1,-8,0,48),UDim2.fromOffset(0,43),12);m.Mine.TextWrapped=true;m.Mine.TextColor3=C.Gold
    m.Rows=Instance.new('Frame');m.Rows.Name='Rows';m.Rows.BackgroundTransparency=1;m.Rows.Size=UDim2.new(1,-8,0,1);m.Rows.Position=UDim2.fromOffset(0,98);m.Rows.Parent=page
    function m.SelectSkin(id)
        if not P.Skin(id)then return end;m.Skin=id
        for _,obj in m.Models do obj:Destroy()end;m.Models={}
        for i,kind in {'Defender','Archer','Runner','Peasant'}do local model=Art.Unit(kind,world,Config.Colors[1],id);Art.Pose(model,CFrame.new((i-2.5)*1.2,0,0)*CFrame.Angles(0,math.pi,0),0,false,false);table.insert(m.Models,model)end
        for skin,b in m.SkinButtons do b.BackgroundColor3=skin==id and C.Blue or C.Inset end
        m.RefreshShop()
    end
    function m.RefreshShop()
        local d=m.Profile;local skin=P.Skin(m.Skin);local owned=d and d.Skins[m.Skin]
        m.Balance.Text='Монеты: '..(d and d.Coins or '—');m.SkinName.Text=skin.Name..(skin.Price>0 and ' · '..skin.Price..' монет'or '')
        m.Buy.Text=owned and 'Куплено'or 'Купить · '..skin.Price;m.Buy.Active=d~=nil and not owned and d.Coins>=skin.Price;m.Buy.BackgroundColor3=m.Buy.Active and C.Blue or C.Inset
        m.Equip.Text=d and d.Equipped==m.Skin and 'Надето'or 'Надеть';m.Equip.Active=owned==true and d.Equipped~=m.Skin;m.Equip.BackgroundColor3=m.Equip.Active and C.Blue or C.Inset
    end
    function m.Apply(data)
        if data.Profile then
            m.Profile=data.Profile;m.Boards={};local d=m.Profile
            profile.Text='Профиль · ур. '..d.Level..' · '..d.Coins..' монет'
            if m.QueueMode~='Ranked'then u.Ranked.Text='Ранговый · '..d.Rank end
            m.Stats.Text='Уровень: '..d.Level..'   ·   Опыт: '..d.LevelXP..'/200\nМонеты: '..d.Coins..'\n\nРанг: '..d.Rank..'\n'..(d.RankedGames<10 and 'Определение ранга: '..d.RankedGames..'/10 матчей'or 'Ранг определён')..'\nСерия ранговых побед: '..d.WinStreak..'\n\nPvP: '..d.Wins..' побед / '..d.Losses..' поражений\nИИ: '..d.AIWins..' побед / '..d.AILosses..' поражений\nЛобби уровня: '..d.LobbyBand
            m.Persistence.Text=data.Persistent and 'Профиль сохраняется между серверами и заходами.'or 'Studio: профиль действует до остановки Play.'
            m.RefreshShop()
        end
        if data.Reward and not data.Reward.AlreadyApplied then local r=data.Reward;m.Reward.Text=(r.Won and 'Победа!'or 'Поражение')..'  +'..r.XP..' опыта\n'..(r.Coins>0 and '+'..r.Coins..' монет за уровень. 'or '')..(r.Mode=='Ranked'and string.format('Ранг: %+d',r.Rank)or '')end
        if data.Board then
            local b=data.Board
            m.Boards[b.Kind]=b
            if m.BoardKind and b.Kind~=m.BoardKind then return end
            m.RankTab.BackgroundColor3=b.Kind=='Rank'and C.Blue or C.Inset;m.WinsTab.BackgroundColor3=b.Kind=='Wins'and C.Blue or C.Inset
            m.Mine.Text=(b.Global and 'Общий топ-100'or 'Studio: игроки текущей проверки')..'\nТы: '..(b.Mine.Place and '№'..b.Mine.Place or 'вне топ-100')..' · '..b.Mine.Score
            for _,child in m.Rows:GetChildren()do child:Destroy()end
            for i,entry in b.Entries do
                local row=UI.Label(m.Rows,'Player'..entry.UserId,'#'..entry.Place..'   '..(entry.Name or tostring(entry.UserId)),UDim2.new(1,-62,0,27),UDim2.fromOffset(0,(i-1)*31),12)
                row.TextTruncate=Enum.TextTruncate.AtEnd
                local score=UI.Label(m.Rows,'Score'..i,tostring(entry.Score),UDim2.fromOffset(60,27),UDim2.new(1,-60,0,(i-1)*31),12);score.TextXAlignment=Enum.TextXAlignment.Right
            end
            m.Pages.Leaders.CanvasSize=UDim2.fromOffset(0,100+#b.Entries*31)
        end
    end
    local oldShow,oldLayout=u.Show,u.Layout
    function u.Show(page,inGame)
        local extra=m.Pages[page]~=nil
        oldShow(extra and 'Settings'or page,inGame)
        for name,pane in m.Pages do pane.Visible=name==page end
        m.Back.Visible=extra
        if extra then u.Page=page;u.Settings.Visible=false;u.Title.Text=({Profile='Твой профиль',Shop='Коллекция королевств',Chests='Сундуки',Leaders='Таблица лидеров'})[page]end
        u.Layout()
    end
    function u.Layout()
        oldLayout();local v=workspace.CurrentCamera.ViewportSize;local short=v.Y<480
        local wanted=(u.Page=='Shop'or u.Page=='Chests')and 650 or u.Page=='Profile'and 580 or u.Page=='Leaders'and 580 or u.Page=='Mode'and 470 or u.Page=='Main'and (u.Return.Visible and 530 or 480)
        if wanted then local h=math.min(short and 300 or wanted,v.Y-80);local width=(u.Page=='Shop'or u.Page=='Chests')and math.min(600,v.X-40)or u.Card.Size.X.Offset;u.Card.Size=UDim2.fromOffset(width,h);u.Card.Position=UDim2.new(.5,-width/2,.5,-h/2)end
        local top=short and 54 or 90
        for _,pane in m.Pages do pane.Position=UDim2.fromOffset(20,top+5);pane.Size=UDim2.new(1,-40,1,-top-64)end
        if short then
            for i,b in u.MainButtons do b.Size=UDim2.new(.5,-4,0,36);b.Position=UDim2.new((i-1)%2*.5,0,0,math.floor((i-1)/2)*43)end
        end
        u.Return.Position=UDim2.fromOffset(0,short and 132 or 312)
        if short then
            for i,b in {u.Modes.AI,u.Online,u.Ranked}do b.Size=UDim2.new(1/3,-4,0,42);b.Position=UDim2.new((i-1)/3,0,0,0);b.TextSize=11 end
            u.QueueStatus.Position=UDim2.fromOffset(0,50);u.Modes.Back.Position=UDim2.fromOffset(0,110)
        else
            u.Ranked.Size=UDim2.new(1,0,0,48);u.Ranked.Position=UDim2.fromOffset(0,120);u.QueueStatus.Position=UDim2.fromOffset(0,178);u.Modes.Back.Position=UDim2.fromOffset(0,234)
        end
    end
    require(script.Parent.CollectionUI).Build(u,m,hooks)
    workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(u.Layout);u.Layout()
    return m
end
return Meta
