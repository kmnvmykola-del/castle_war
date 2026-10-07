local UI=require(script.Parent.UI)
local P=require(script.Parent.Progression)
local Meta={}
function Meta.Build(u,hooks)
    local C=UI.Colors;local function call(key,...)if hooks[key]then hooks[key](...)end end
    local m={Skin='Default',Models={},Profile=nil,Boards={}}
    local settings=u.MainButtons[3];table.remove(u.MainButtons,3)
    local profile=UI.Button(u.Main,'Profile','Profile',UDim2.new(1,0,0,44),UDim2.new(),function()call('Profile')end)
    local inventory=UI.Button(u.Main,'Inventory','Inventory · Sets',UDim2.new(1,0,0,44),UDim2.new(),function()call('Inventory')end)
    local shop=UI.Button(u.Main,'Shop','Shop · Skins',UDim2.new(1,0,0,44),UDim2.new(),function()call('Shop')end)
    local leaders=UI.Button(u.Main,'Leaders','Leaderboards',UDim2.new(1,0,0,44),UDim2.new(),function()call('Leaders')end)
    for _,b in {profile,inventory,shop,leaders,settings}do table.insert(u.MainButtons,b)end
    u.Ranked=UI.Button(u.Modes,'Ranked','Ranked · 0',UDim2.new(1,0,0,48),UDim2.fromOffset(0,120),function()call('Ranked')end);u.Ranked.BackgroundColor3=C.Gold;u.Ranked.TextColor3=C.Panel
    m.Pages={}
    for _,name in {'Profile','Shop','Leaders'}do
        local page=Instance.new('ScrollingFrame');page.Name=name;page.Active=true;page.BackgroundTransparency=1;page.BorderSizePixel=0;page.ScrollBarThickness=3;page.Visible=false;page.Parent=u.Card;page.CanvasSize=UDim2.fromOffset(0,name=='Shop'and 438 or 320);m.Pages[name]=page
    end
    m.Back=UI.Button(u.Card,'MetaBack','Back',UDim2.new(1,-40,0,36),UDim2.new(0,20,1,-48),function()call('MetaBack')end);m.Back.Visible=false
    local page=m.Pages.Profile
    m.Stats=UI.Label(page,'Stats','Loading profile…',UDim2.new(1,-8,0,226),UDim2.fromOffset(0,0),15);m.Stats.TextWrapped=true;m.Stats.TextYAlignment=Enum.TextYAlignment.Top
    m.Reward=UI.Label(page,'Reward','',UDim2.new(1,-8,0,62),UDim2.fromOffset(0,230),13);m.Reward.TextWrapped=true;m.Reward.TextColor3=C.Gold
    m.Persistence=UI.Label(page,'Persistence','',UDim2.new(1,-8,0,38),UDim2.fromOffset(0,296),11);m.Persistence.TextWrapped=true;m.Persistence.TextColor3=C.Muted
    UI.Button(page,'Retry','Refresh Profile',UDim2.new(1,-8,0,36),UDim2.fromOffset(0,340),function()call('RefreshProfile')end);page.CanvasSize=UDim2.fromOffset(0,385)
    page=m.Pages.Leaders
    m.RankTab=UI.Button(page,'Rank','Rank',UDim2.new(.5,-8,0,36),UDim2.new(),function()call('Board','Rank')end)
    m.WinsTab=UI.Button(page,'Wins','PvP Wins',UDim2.new(.5,-4,0,36),UDim2.fromScale(.5,0),function()call('Board','Wins')end)
    m.Mine=UI.Label(page,'Mine','Loading leaderboard…',UDim2.new(1,-8,0,48),UDim2.fromOffset(0,43),12);m.Mine.TextWrapped=true;m.Mine.TextColor3=C.Gold
    m.Rows=Instance.new('Frame');m.Rows.Name='Rows';m.Rows.BackgroundTransparency=1;m.Rows.Size=UDim2.new(1,-8,0,1);m.Rows.Position=UDim2.fromOffset(0,98);m.Rows.Parent=page
    function m.Apply(data)
        if data.Profile then
            m.Profile=data.Profile;m.Boards={};local d=m.Profile
            profile.Text='Profile · Lv. '..d.Level..' · '..d.Coins..' coins'
            if m.QueueMode~='Ranked'then u.Ranked.Text='Ranked · '..d.Rank end
            m.Stats.Text='Level: '..d.Level..'   ·   XP: '..d.LevelXP..'/200\nCoins: '..d.Coins..'\n\nRank: '..d.Rank..'\n'..(d.RankedGames<10 and 'Placement matches: '..d.RankedGames..'/10 matches'or 'Rank established')..'\nRanked win streak: '..d.WinStreak..'\n\nPvP: '..d.Wins..' wins / '..d.Losses..' losses\nAI: '..d.AIWins..' wins / '..d.AILosses..' losses\nLevel lobby: '..d.LobbyBand
            m.Persistence.Text=data.Persistent and 'Your profile is saved across servers and sessions.'or 'Studio: your profile lasts until Play stops.'
            m.RefreshShop()
        end
        if data.Reward and not data.Reward.AlreadyApplied then local r=data.Reward;m.Reward.Text=(r.Won and 'Victory!'or 'Defeat')..'  +'..r.XP..' XP\n'..(r.Coins>0 and '+'..r.Coins..' coins from leveling up. 'or '')..(r.Mode=='Ranked'and string.format('Rank: %+d',r.Rank)or '')end
        if data.Board then
            local b=data.Board
            m.Boards[b.Kind]=b
            if m.BoardKind and b.Kind~=m.BoardKind then return end
            m.RankTab.BackgroundColor3=b.Kind=='Rank'and C.Blue or C.Inset;m.WinsTab.BackgroundColor3=b.Kind=='Wins'and C.Blue or C.Inset
            m.Mine.Text=(b.Global and 'Global Top 100'or 'Studio: players in this test session')..'\nYou: '..(b.Mine.Place and '№'..b.Mine.Place or 'outside the Top 100')..' · '..b.Mine.Score
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
        if extra then u.Page=page;u.Settings.Visible=false;u.Title.Text=({Profile='Your Profile',Inventory='Inventory',Shop='Shop',Chests='Kingdom Chest',Leaders='Leaderboards'})[page]end
        u.Layout()
    end
    function u.Layout()
        oldLayout();local v=workspace.CurrentCamera.ViewportSize;local short=v.Y<480
        local collection=u.Page=='Inventory'or u.Page=='Shop'or u.Page=='Chests'
        local wanted=collection and 760 or u.Page=='Profile'and 580 or u.Page=='Leaders'and 580 or u.Page=='Mode'and 470 or u.Page=='Main'and (u.Return.Visible and 580 or 540)
        if wanted then local limit=v.Y-(collection and short and 76 or 80);local h=math.min(collection and short and limit or short and 300 or wanted,limit);local width=collection and math.min(1040,v.X-48)or u.Card.Size.X.Offset;u.Card.Size=UDim2.fromOffset(width,h);u.Card.Position=UDim2.new(.5,-width/2,.5,-h/2+(collection and short and 26 or 0))end
        local top=collection and (short and 48 or 70) or short and 54 or 90
        if collection then
            u.Title.Position=UDim2.fromOffset(24,short and 10 or 16);u.Title.Size=UDim2.new(1,-48,0,short and 30 or 40);u.Title.TextSize=short and 24 or 28;u.Title.TextColor3=C.Text
            u.Card.BackgroundColor3=Color3.fromRGB(15,25,37)
            if u.Divider then u.Divider.Position=UDim2.fromOffset(20,short and 42 or 62)end
        else u.Card.BackgroundColor3=C.Panel;u.Title.TextSize=short and 22 or 29 end
        for _,pane in m.Pages do pane.Position=UDim2.fromOffset(20,top+5);pane.Size=UDim2.new(1,-40,1,-top-64)end
        if short then
            for i,b in u.MainButtons do b.Size=UDim2.new(.5,-4,0,36);b.Position=UDim2.new((i-1)%2*.5,0,0,math.floor((i-1)/2)*43)end
        end
        u.Return.Position=UDim2.fromOffset(0,short and 175 or 364)
        if short then
            for i,b in {u.Modes.AI,u.Online,u.Ranked}do b.Size=UDim2.new(1/3,-4,0,42);b.Position=UDim2.new((i-1)/3,0,0,0);b.TextSize=11 end
            u.QueueStatus.Position=UDim2.fromOffset(0,50);u.Modes.Back.Position=UDim2.fromOffset(0,110)
        else
            u.Ranked.Size=UDim2.new(1,0,0,48);u.Ranked.Position=UDim2.fromOffset(0,120);u.QueueStatus.Position=UDim2.fromOffset(0,178);u.Modes.Back.Position=UDim2.fromOffset(0,234)
        end
        if m.CollectionLayout then m.CollectionLayout()end
    end
    require(script.Parent.CollectionUI).Build(u,m,hooks)
    u.Layout()
    return m
end
return Meta
