local UIS=game:GetService('UserInputService')
local UI={}
UI.Colors={Panel=Color3.fromRGB(24,35,42),Inset=Color3.fromRGB(40,54,59),Text=Color3.fromRGB(240,235,213),Muted=Color3.fromRGB(163,179,180),Gold=Color3.fromRGB(204,172,102),Blue=Color3.fromRGB(68,128,158),Line=Color3.fromRGB(76,94,97)}
local C=UI.Colors
local function corner(p,r)local x=Instance.new('UICorner');x.CornerRadius=UDim.new(0,r or 5);x.Parent=p end
local function border(p,color)local x=Instance.new('UIStroke');x.Color=color or C.Line;x.Transparency=.4;x.Thickness=1;x.Parent=p end
function UI.Frame(parent,name,size,pos,color)
    local f=Instance.new('Frame');f.Name=name;f.Size=size;f.Position=pos;f.BackgroundColor3=color or C.Panel;f.BorderSizePixel=0;f.Parent=parent;return f
end
function UI.Label(parent,name,text,size,pos,fontSize)
    local l=Instance.new('TextLabel');l.Name=name;l.Size=size;l.Position=pos;l.Text=text;l.TextColor3=C.Text;l.TextSize=fontSize or 14;l.Font=Enum.Font.Gotham;l.BackgroundTransparency=1;l.TextXAlignment=Enum.TextXAlignment.Left;l.Parent=parent;return l
end
function UI.Button(parent,name,text,size,pos,fn)
    local b=Instance.new('TextButton');b.Name=name;b.Size=size;b.Position=pos;b.Text=text;b.TextColor3=C.Text;b.TextSize=14;b.Font=Enum.Font.GothamMedium;b.BackgroundColor3=C.Inset;b.BorderSizePixel=0;b.Parent=parent;corner(b,5)
    b.Activated:Connect(function()
        if b.Active==false then return end
        if UI.PlaySound then UI.PlaySound('Click')end
        fn()
    end)
    return b
end
function UI.TextBox(parent,name,text,size,pos)
    local b=Instance.new('TextBox');b.Name=name;b.Size=size;b.Position=pos;b.Text=text;b.TextColor3=C.Text;b.TextSize=14;b.Font=Enum.Font.Gotham;b.BackgroundColor3=C.Inset;b.BorderSizePixel=0;b.ClearTextOnFocus=false;b.Parent=parent;corner(b,5);return b
end
function UI.Slider(parent,name,title,pos,initial,callback)
    local f=UI.Frame(parent,name,UDim2.new(1,0,0,55),pos);f.BackgroundTransparency=1
    local l=UI.Label(f,'Label',title,UDim2.new(1,-64,0,20),UDim2.fromOffset(0,0),13)
    local value=UI.Label(f,'Value','',UDim2.fromOffset(60,20),UDim2.new(1,-60,0,0),13);value.TextXAlignment=Enum.TextXAlignment.Right
    local hit=UI.Frame(f,'Hit',UDim2.new(1,0,0,32),UDim2.fromOffset(0,22));hit.BackgroundTransparency=1;hit.Active=true
    local track=UI.Frame(hit,'Track',UDim2.new(1,0,0,4),UDim2.new(0,0,.5,-2),C.Line);corner(track,2)
    local fill=UI.Frame(track,'Fill',UDim2.new(initial,0,1,0),UDim2.fromOffset(0,0),C.Gold);corner(fill,2)
    local thumb=UI.Frame(hit,'Thumb',UDim2.fromOffset(24,24),UDim2.new(initial,-12,.5,-12),C.Gold);corner(thumb,12);thumb.Active=true
    local input=nil
    local object={Frame=f,Hit=hit,Value=initial,Text=value}
    function object.Set(v)
        object.Value=math.clamp(v,0,1);fill.Size=UDim2.new(object.Value,0,1,0);local radius=thumb.Size.X.Offset/2;thumb.Position=UDim2.new(object.Value,-radius,.5,-radius);value.Text=math.floor(object.Value*100+.5)..'%'
    end
    local function change(x)object.Set((x-hit.AbsolutePosition.X)/hit.AbsoluteSize.X);callback(object.Value,false)end
    local function begin(i)if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then input=i;change(i.Position.X)end end
    hit.InputBegan:Connect(begin);thumb.InputBegan:Connect(begin)
    UIS.InputChanged:Connect(function(i)if input and (i==input or i.UserInputType==Enum.UserInputType.MouseMovement)then change(i.Position.X)end end)
    UIS.InputEnded:Connect(function(i)if input and (i==input or i.UserInputType==Enum.UserInputType.MouseButton1)then input=nil;callback(object.Value,true);if UI.PlaySound then UI.PlaySound('Click')end end end)
    object.Set(initial);return object
end
function UI.Build(player,hooks)
    local function call(k,...)if hooks[k] then hooks[k](...)end end
    local gui=Instance.new('ScreenGui');gui.Name='KingdomsUI';gui.AutoLocalize=false;gui.ResetOnSpawn=false;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.DisplayOrder=10;gui.Parent=player.PlayerGui
    local overlay=Instance.new('ScreenGui');overlay.Name='KingdomsOverlay';overlay.AutoLocalize=false;overlay.ResetOnSpawn=false;overlay.IgnoreGuiInset=true;overlay.ScreenInsets=Enum.ScreenInsets.None;overlay.ClipToDeviceSafeArea=false;overlay.DisplayOrder=20;overlay.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;overlay.Parent=player.PlayerGui
    local u={Gui=gui,Overlay=overlay,Page='Main'}
    local hud=UI.Frame(gui,'HUD',UDim2.fromScale(1,1),UDim2.fromScale(0,0));hud.BackgroundTransparency=1;hud.Visible=false;u.HUD=hud
    u.MenuButton=UI.Button(hud,'Menu','',UDim2.fromOffset(44,44),UDim2.fromOffset(12,10),function()call('Menu')end)
    for i=1,3 do UI.Frame(u.MenuButton,'Line'..i,UDim2.fromOffset(22,2),UDim2.fromOffset(11,12+i*6),C.Text)end
    local info=UI.Frame(hud,'Information',UDim2.fromOffset(220,104),UDim2.new(0,12,1,-116));corner(info);border(info);info.Active=true;u.Information=info
    u.Summary=UI.Label(info,'Summary','',UDim2.new(1,-24,1,-16),UDim2.fromOffset(12,8),14);u.Summary.TextWrapped=true;u.Summary.TextYAlignment=Enum.TextYAlignment.Center
    u.InfoToggle=UI.Button(hud,'Info','i',UDim2.fromOffset(44,44),UDim2.new(0,12,1,-56),function()call('Info')end);u.InfoToggle.TextSize=22;u.InfoExpanded=false
    local toast=UI.Frame(gui,'Feedback',UDim2.fromOffset(420,34),UDim2.new(.5,-210,0,64));corner(toast);toast.Visible=false
    u.Toast=toast;u.ToastText=UI.Label(toast,'Text','',UDim2.new(1,-20,1,0),UDim2.fromOffset(10,0),12);u.ToastText.TextXAlignment=Enum.TextXAlignment.Center;u.ToastText.TextWrapped=true
    local panel=UI.Frame(gui,'Orders',UDim2.fromOffset(310,192),UDim2.new(0,16,1,-208));corner(panel);border(panel);panel.Visible=false;panel.Active=true;u.Panel=panel
    u.Building=UI.Label(panel,'Building','',UDim2.new(1,-58,0,24),UDim2.fromOffset(12,9),16);u.Building.Font=Enum.Font.GothamMedium
    u.CloseSelection=UI.Button(panel,'Close','×',UDim2.fromOffset(30,28),UDim2.new(1,-40,0,7),function()call('Deselect')end)
    u.Roster={}
    for i,name in {'Peasant','Defender','Archer','Runner'} do u.Roster[name]=UI.Label(panel,name,'',UDim2.new(.5,-16,0,22),UDim2.new((i-1)%2*.5,12,0,37+math.floor((i-1)/2)*24),12)end
    u.Percent=UI.Slider(panel,'Slider','Send',UDim2.fromOffset(12,88),.5,function(v)call('Percent',math.floor(v*100+.5))end);u.Percent.Frame.Size=UDim2.new(1,-24,0,47)
    local dock=UI.Frame(gui,'SendPercentage',UDim2.fromOffset(600,88),UDim2.new(.5,-300,1,-100));corner(dock);border(dock);dock.Active=true;dock.Visible=false;u.Dock=dock
    u.Upgrade=UI.Button(panel,'Upgrade','Upgrade · 50 troops',UDim2.new(1,-24,0,40),UDim2.fromOffset(12,142),function()call('Upgrade')end)
    u.TouchOrder=UI.Button(panel,'Order','Order →',UDim2.fromOffset(98,28),UDim2.new(1,-138,0,7),function()call('TouchOrder')end);u.TouchOrder.Visible=UIS.TouchEnabled
    local selection=UI.Frame(gui,'SelectionBox',UDim2.fromOffset(0,0),UDim2.fromOffset(0,0),C.Blue);selection.BackgroundTransparency=.85;border(selection,C.Gold);selection.Visible=false;u.SelectionBox=selection
    toast.Parent=overlay;toast.ZIndex=20
    local menu=UI.Frame(overlay,'Menu',UDim2.fromScale(1,1),UDim2.fromScale(0,0));menu.BackgroundTransparency=.25;menu.Active=true;u.Menu=menu
    local card=UI.Frame(menu,'Card',UDim2.fromOffset(420,378),UDim2.new(.5,-210,.5,-189));corner(card,10);border(card,C.Gold);u.Card=card
    u.Title=UI.Label(card,'Title','Frontier\nKingdoms',UDim2.new(1,-40,0,68),UDim2.fromOffset(20,18),29);u.Title.Font=Enum.Font.GothamMedium
    local divider=UI.Frame(card,'Divider',UDim2.new(1,-40,0,1),UDim2.fromOffset(20,87),C.Gold);divider.BackgroundTransparency=.45;u.Divider=divider
    local main=UI.Frame(card,'Main',UDim2.new(1,-40,1,-108),UDim2.fromOffset(20,96));main.BackgroundTransparency=1;u.Main=main
    local buttons={}
    buttons[1]=UI.Button(main,'Play','Play',UDim2.new(1,0,0,44),UDim2.fromOffset(0,0),function()call('Play')end);buttons[1].BackgroundColor3=C.Blue
    buttons[2]=UI.Button(main,'Editor','Map Editor',UDim2.new(1,0,0,44),UDim2.fromOffset(0,94),function()call('Editor')end)
    buttons[3]=UI.Button(main,'Settings','Settings',UDim2.new(1,0,0,44),UDim2.fromOffset(0,146),function()call('Settings')end)
    u.MainButtons=buttons;u.Play=buttons[1];u.EditorButton=buttons[2]
    u.Return=UI.Button(main,'Return','End Match & Exit',UDim2.new(1,0,0,34),UDim2.fromOffset(0,248),function()call('Return')end);u.Return.Visible=false
    u.Result=UI.Label(card,'Result','Loading models…',UDim2.new(1,-40,0,22),UDim2.new(0,20,1,-30),11);u.Result.TextColor3=C.Muted
    local dif=UI.Frame(card,'Difficulties',UDim2.new(1,-40,1,-110),UDim2.fromOffset(20,80));dif.BackgroundTransparency=1;dif.Visible=false;u.Difficulties=dif
    u.MapChoice=UI.Button(dif,'Map','Map: Two Crossings  ▾',UDim2.new(1,0,0,34),UDim2.fromOffset(0,0),function()call('MapChoice')end);u.MapChoice.TextSize=13
    local modes=UI.Frame(card,'Modes',UDim2.new(1,-40,1,-110),UDim2.fromOffset(20,96));modes.BackgroundTransparency=1;modes.Visible=false;u.Modes=modes
    UI.Button(modes,'AI','Vs AI',UDim2.new(1,0,0,48),UDim2.fromOffset(0,0),function()call('AI')end).BackgroundColor3=C.Blue
    u.Online=UI.Button(modes,'Player','PvP · 1v1',UDim2.new(1,0,0,48),UDim2.fromOffset(0,60),function()call('Online')end)
    u.QueueStatus=UI.Label(modes,'Status','PvP matches use a random map.',UDim2.new(1,0,0,46),UDim2.fromOffset(0,120),12);u.QueueStatus.TextWrapped=true;u.QueueStatus.TextColor3=C.Muted
    UI.Button(modes,'Back','Back',UDim2.new(1,0,0,38),UDim2.fromOffset(0,180),function()call('Back')end)
    local maps=Instance.new('ScrollingFrame');maps.Name='Maps';maps.Size=UDim2.new(1,-40,1,-110);maps.Position=UDim2.fromOffset(20,96);maps.BackgroundTransparency=1;maps.BorderSizePixel=0;maps.ScrollBarThickness=3;maps.CanvasSize=UDim2.fromOffset(0,300);maps.Visible=false;maps.Parent=card;u.Maps=maps
    u.MapButtons={}
    for i,pair in {{'TwoBridges','Two Crossings'},{'LandFrontiers','Land Frontiers'},{'RiverPass','River Pass'},{'Random','Random Map'},{'Custom','Saved Map'}}do
        u.MapButtons[pair[1]]=UI.Button(maps,pair[1],pair[2],UDim2.new(1,-6,0,40),UDim2.fromOffset(0,(i-1)*48),function()call('SelectMap',pair[1])end)
    end
    UI.Button(maps,'Back','Back',UDim2.new(1,-6,0,36),UDim2.fromOffset(0,244),function()call('Back')end)
    for i,pair in {{'Easy','Easy'},{'Normal','Normal'},{'Hard','Hard'}}do
        local b=UI.Button(dif,pair[1],pair[2],UDim2.new(1,0,0,48),UDim2.fromOffset(0,(i-1)*58),function()call('Start',pair[1])end);if pair[1]=='Hard'then b.BackgroundColor3=C.Blue end
    end
    UI.Button(dif,'Back','Back',UDim2.new(1,0,0,38),UDim2.fromOffset(0,181),function()call('Back')end)
    local settings=Instance.new('ScrollingFrame');settings.Name='Settings';settings.Size=UDim2.new(1,-40,1,-94);settings.Position=UDim2.fromOffset(20,76);settings.BackgroundTransparency=1;settings.BorderSizePixel=0;settings.ScrollBarThickness=3;settings.CanvasSize=UDim2.fromOffset(0,395);settings.Visible=false;settings.Parent=card;u.Settings=settings
    u.Music=UI.Slider(settings,'Music','Music Volume',UDim2.fromOffset(0,0),.22,function(v,done)call('Music',v,done)end)
    u.Effects=UI.Slider(settings,'Effects','Sound Effects Volume',UDim2.fromOffset(0,66),.55,function(v,done)call('Effects',v,done)end)
    u.Camera=UI.Slider(settings,'Camera','Camera Speed',UDim2.fromOffset(0,132),1/3,function(v,done)call('Camera',.5+v*1.5,done)end)
    u.Zoom=UI.Slider(settings,'Zoom','Zoom Speed',UDim2.fromOffset(0,198),1/3,function(v,done)call('Zoom',.5+v*1.5,done)end)
    u.Grid=UI.Button(settings,'Grid','Grid: Off',UDim2.new(1,0,0,40),UDim2.fromOffset(0,269),function()call('Grid')end)
    u.Labels=UI.Button(settings,'Labels','Building Counts: On',UDim2.new(1,0,0,40),UDim2.fromOffset(0,318),function()call('Labels')end)
    UI.Button(settings,'Back','Done',UDim2.new(1,0,0,40),UDim2.fromOffset(0,367),function()call('Back')end)
    UI.Button(settings,'BattleGuide','Replay Battle Guide',UDim2.new(1,0,0,40),UDim2.fromOffset(0,416),function()call('BattleGuideReplay')end)
    local credits=UI.Label(settings,'Credits','Original music: Frontier Dawn / March of the Banners\nOriginal game sound effects\nFallback audio: APM Music · Creator Store / 0FFZ3TI',UDim2.new(1,0,0,48),UDim2.fromOffset(0,466),10);credits.TextColor3=C.Muted;credits.TextWrapped=true;settings.CanvasSize=UDim2.fromOffset(0,522)
    local editor=UI.Frame(gui,'Editor',UDim2.fromScale(1,1),UDim2.fromScale(0,0));editor.BackgroundTransparency=1;editor.Visible=false;u.Editor=editor
    local toolbar=UI.Frame(editor,'Toolbar',UDim2.new(1,-24,0,98),UDim2.fromOffset(12,10));corner(toolbar);border(toolbar);toolbar.Active=true
    u.MapName=UI.TextBox(toolbar,'Name','My Map',UDim2.new(1,-274,0,36),UDim2.fromOffset(10,8));u.MapName.TextXAlignment=Enum.TextXAlignment.Left
    UI.Button(toolbar,'Save','Save',UDim2.fromOffset(84,36),UDim2.new(1,-254,0,8),function()call('SaveMap')end)
    UI.Button(toolbar,'Test','Play',UDim2.fromOffset(78,36),UDim2.new(1,-162,0,8),function()call('TestMap')end).BackgroundColor3=C.Blue
    UI.Button(toolbar,'Back','Menu',UDim2.fromOffset(66,36),UDim2.new(1,-76,0,8),function()call('ExitEditor')end)
    local tools=Instance.new('ScrollingFrame');tools.Name='Tools';tools.Active=true;tools.Size=UDim2.new(1,-20,0,42);tools.Position=UDim2.fromOffset(10,50);tools.BackgroundTransparency=1;tools.BorderSizePixel=0;tools.ScrollBarThickness=2;tools.ScrollingDirection=Enum.ScrollingDirection.X;tools.CanvasSize=UDim2.fromOffset(780,0);tools.Parent=toolbar
    local x=0
    for _,pair in {{'Road','Roads',82},{'Move','Move',92},{'Erase','Delete',82},{'Owner','Team: Blue',142},{'River','River: On',106},{'New','New',72},{'Undo','Undo',78},{'Export','Map Code',88},{'Import','Import',88}}do
        local b=UI.Button(tools,pair[1],pair[2],UDim2.fromOffset(pair[3],36),UDim2.fromOffset(x,0),function()call('EditorTool',pair[1])end);x+=pair[3]+6;if pair[1]=='Owner'then u.Owner=b end
    end
    local palette=UI.Frame(editor,'Palette',UDim2.new(1,-24,0,86),UDim2.new(0,12,1,-98));corner(palette);border(palette);palette.Active=true;u.Palette=palette
    u.EditorHint=UI.Label(palette,'Hint','',UDim2.new(1,-20,0,23),UDim2.fromOffset(10,4),12);u.EditorHint.TextColor3=C.Gold
    local scroll=Instance.new('ScrollingFrame');scroll.Name='Buildings';scroll.Active=true;scroll.Size=UDim2.new(1,-20,0,50);scroll.Position=UDim2.fromOffset(10,29);scroll.BackgroundTransparency=1;scroll.BorderSizePixel=0;scroll.ScrollBarThickness=2;scroll.ScrollingDirection=Enum.ScrollingDirection.X;scroll.CanvasSize=UDim2.fromOffset(808,0);scroll.Parent=palette
    u.KindButtons={}
    for i,pair in {{'Castle','Castle'},{'Village','Village'},{'Barracks','Barracks'},{'Archery','Archery Range'},{'Camp','Camp'},{'Tower','Tower'},{'Farm','Farm'},{'Junction','Road Junction'}}do
        u.KindButtons[pair[1]]=UI.Button(scroll,pair[1],pair[2],UDim2.fromOffset(94,42),UDim2.fromOffset((i-1)*101,0),function()call('EditorKind',pair[1])end);u.KindButtons[pair[1]].TextSize=12
    end
    local code=UI.Frame(overlay,'MapCode',UDim2.fromScale(1,1),UDim2.fromScale(0,0));code.BackgroundTransparency=.18;code.Visible=false;code.Active=true;u.Code=code
    local codeCard=UI.Frame(code,'Card',UDim2.fromOffset(600,340),UDim2.new(.5,-300,.5,-170));corner(codeCard);border(codeCard);u.CodeCard=codeCard
    u.CodeTitle=UI.Label(codeCard,'Title','Map Code',UDim2.new(1,-30,0,28),UDim2.fromOffset(15,12),19)
    u.CodeHint=UI.Label(codeCard,'Hint','',UDim2.new(1,-30,0,40),UDim2.fromOffset(15,47),12);u.CodeHint.TextWrapped=true
    u.CodeText=UI.TextBox(codeCard,'Text','',UDim2.new(1,-30,1,-156),UDim2.fromOffset(15,90));u.CodeText.MultiLine=true;u.CodeText.TextWrapped=true;u.CodeText.TextXAlignment=Enum.TextXAlignment.Left;u.CodeText.TextYAlignment=Enum.TextYAlignment.Top;u.CodeText.TextSize=11
    u.CodeApply=UI.Button(codeCard,'Apply','Import',UDim2.fromOffset(140,40),UDim2.new(0,15,1,-53),function()call('ImportApply')end)
    UI.Button(codeCard,'Close','Close',UDim2.fromOffset(110,40),UDim2.new(1,-125,1,-53),function()call('CodeClose')end)
    local tutorial=UI.Frame(overlay,'EditorTutorial',UDim2.fromScale(1,1),UDim2.fromScale(0,0));tutorial.BackgroundTransparency=.18;tutorial.Active=true;tutorial.Visible=false;u.Tutorial=tutorial
    local guide=UI.Frame(tutorial,'Card',UDim2.fromOffset(560,350),UDim2.new(.5,-280,.5,-175));corner(guide);border(guide);u.Guide=guide
    UI.Label(guide,'Title','How to Create a Map',UDim2.new(1,-32,0,30),UDim2.fromOffset(16,12),21)
    local instructions=Instance.new('ScrollingFrame');instructions.Name='Instructions';instructions.Size=UDim2.new(1,-32,1,-108);instructions.Position=UDim2.fromOffset(16,50);instructions.BackgroundTransparency=1;instructions.BorderSizePixel=0;instructions.ScrollBarThickness=3;instructions.AutomaticCanvasSize=Enum.AutomaticSize.Y;instructions.CanvasSize=UDim2.new();instructions.Parent=guide
    local text=UI.Label(instructions,'Text','1. Choose a building and a team, then select an empty cell. River: On / Off changes the terrain. Clear the central column before enabling the river.\n\n2. Roads: select the first point, then the second. Visible junctions and shared road sections connect automatically.\n\n3. Road Junction creates a branching point. Capture enemy or neutral buildings before passing through them. Units use an alternative route when one is available.\n\n4. Move: select a building, then an empty cell. Delete removes an object and its connected roads. Undo restores your last change.\n\n5. A playable map needs a castle for each team and connected buildings. Select Play, then choose an AI difficulty.\n\n6. Save stores your map. In local Studio sessions, copy the Map Code to use the map next time.',UDim2.new(1,-10,0,0),UDim2.fromOffset(0,0),14);text.TextWrapped=true;text.TextYAlignment=Enum.TextYAlignment.Top;text.AutomaticSize=Enum.AutomaticSize.Y
    UI.Button(guide,'Close','Got It',UDim2.new(1,-32,0,40),UDim2.new(0,16,1,-54),function()call('TutorialClose')end)
    local battleGuide=UI.Frame(gui,'BattleGuide',UDim2.fromOffset(330,116),UDim2.fromOffset(12,74));corner(battleGuide,10);border(battleGuide,C.Gold);battleGuide.Active=true;battleGuide.Visible=false;u.BattleGuide=battleGuide
    local guideTitle=UI.Label(battleGuide,'Title','YOUR FIRST BATTLE · 1 / 3',UDim2.new(1,-92,0,22),UDim2.fromOffset(14,10),12);guideTitle.TextColor3=C.Gold
    local guideText=UI.Label(battleGuide,'Hint','',UDim2.new(1,-28,0,70),UDim2.fromOffset(14,36),14);guideText.TextWrapped=true;guideText.TextYAlignment=Enum.TextYAlignment.Top
    UI.Button(battleGuide,'Skip','Skip',UDim2.fromOffset(58,30),UDim2.new(1,-72,0,8),function()call('BattleGuideSkip')end).TextSize=12
    function u.UpdateBattleGuide(active,step)
        battleGuide.Visible=active and not menu.Visible and not editor.Visible
        guideTitle.Text='YOUR FIRST BATTLE · '..step..' / 3'
        guideText.Text=({
            'Select your blue castle. Your army is blue; enemies are red and neutral buildings are gray.',
            UIS.TouchEnabled and 'Tap Order, then tap a connected gray or red building to send your troops.'or 'Right-click a connected gray or red building to send troops. The slider chooses how many.',
            'Watch your troops reach the building and capture it. Build your army, then take the enemy castle!',
        })[step]
        u.BattleGuideActive=active;u.BattleGuideStep=step
    end
    UI.Button(tools,'Help','?',UDim2.fromOffset(38,36),UDim2.fromOffset(x,0),function()call('EditorTool','Help')end);tools.CanvasSize=UDim2.fromOffset(x+44,0)
    function u.SyncHUD()
        u.InfoToggle.Visible=UIS.TouchEnabled
        u.Information.Visible=not UIS.TouchEnabled or u.InfoExpanded
        u.InfoToggle.BackgroundColor3=u.InfoExpanded and C.Blue or C.Inset
        u.Dock.Visible=not UIS.TouchEnabled and panel.Visible and not menu.Visible
        local v=workspace.CurrentCamera.ViewportSize;local tw=math.min(420,v.X-24)
        battleGuide.Visible=u.BattleGuideActive==true and not menu.Visible and not editor.Visible
        local compactInfo=not UIS.TouchEnabled and v.X<780 and u.Dock.Visible
        info.Size=UDim2.fromOffset(220,compactInfo and 80 or 104)
        info.Position=compactInfo and UDim2.new(0,12,1,-366)or UIS.TouchEnabled and UDim2.new(0,12,1,-170)or UDim2.new(0,12,1,-116)
        toast.Position=v.Y<480 and menu.Visible and UDim2.new(.5,-tw/2,1,-50)or UDim2.new(.5,-tw/2,0,64)
    end
    function u.Show(page,inGame)
        u.Page=page;menu.Visible=true;main.Visible=page=='Main';dif.Visible=page=='Difficulty';settings.Visible=page=='Settings';maps.Visible=page=='Maps';modes.Visible=page=='Mode';u.Result.Visible=page=='Main'
        u.Title.Text=page=='Main' and (inGame and 'Match Menu' or 'Frontier\nKingdoms') or ({Difficulty='Battle AI',Settings='Settings',Mode='Choose a Mode',Maps='Choose a Map'})[page]
        u.Title.TextSize=page=='Main' and 29 or 24;u.Play.Text=inGame and 'Resume' or u.InPrivate and 'Back to Lobby' or 'Play';u.Return.Visible=inGame and page=='Main';u.Return.Text=u.InPrivate and 'End Match & Return to Lobby' or 'End Match & Exit'
        u.EditorButton.Active=not inGame and not u.InPrivate;u.EditorButton.TextColor3=(inGame or u.InPrivate)and C.Muted or C.Text;u.MapChoice.Active=not inGame
        u.Layout()
    end
    function u.Layout()
        local v=workspace.CurrentCamera.ViewportSize;local short=v.Y<480
        local w=math.min(420,v.X-32);local height=short and math.min(276,v.Y-80) or (u.Page=='Settings' and 490 or u.Return.Visible and 440 or 402)
        height=math.min(height,v.Y-80);card.Size=UDim2.fromOffset(w,height);card.Position=UDim2.new(.5,-w/2,.5,-height/2)
        local top=short and 54 or 90;u.Title.Position=UDim2.fromOffset(20,12);u.Title.Size=UDim2.new(1,-40,0,short and 36 or 66)
        if short and u.Page=='Main'then u.Title.Text=u.Return.Visible and 'Match Menu' or 'Frontier Kingdoms';u.Title.TextSize=22 end
        u.Divider.Position=UDim2.fromOffset(20,top-4);main.Position=UDim2.fromOffset(20,top+5);main.Size=UDim2.new(1,-40,1,-top-40)
        dif.Position=UDim2.fromOffset(20,top+5);dif.Size=UDim2.new(1,-40,1,-top-15)
        u.MapChoice.Size=UDim2.new(1,0,0,short and 28 or 34)
        for i,name in {'Easy','Normal','Hard'}do dif[name].Size=short and UDim2.new(1/3,-4,0,40) or UDim2.new(1,0,0,48);dif[name].Position=short and UDim2.new((i-1)/3,0,0,38)or UDim2.fromOffset(0,46+(i-1)*58)end
        dif.Back.Size=UDim2.new(1,0,0,short and 34 or 38);dif.Back.Position=UDim2.fromOffset(0,short and 92 or 228)
        for _,page in {modes,maps}do page.Position=UDim2.fromOffset(20,top+5);page.Size=UDim2.new(1,-40,1,-top-20)end
        modes.AI.Size=short and UDim2.new(.5,-4,0,44)or UDim2.new(1,0,0,48);u.Online.Size=modes.AI.Size;u.Online.Position=short and UDim2.new(.5,4,0,0)or UDim2.fromOffset(0,60)
        u.QueueStatus.Position=UDim2.fromOffset(0,short and 50 or 120);modes.Back.Position=UDim2.fromOffset(0,short and 105 or 180)
        settings.Position=UDim2.fromOffset(20,top+5);settings.Size=UDim2.new(1,-40,1,-top-20)
        for i,b in buttons do b.Size=UDim2.new(1,0,0,short and 36 or 44);b.Position=UDim2.fromOffset(0,(i-1)*(short and 43 or 52))end
        u.Return.Position=UDim2.fromOffset(0,short and 132 or 166)
        local narrowTouch=UIS.TouchEnabled and v.X<550
        local panelWidth=math.min(310,v.X-(narrowTouch and 80 or 24))
        panel.Size=UDim2.fromOffset(panelWidth,UIS.TouchEnabled and 192 or 142)
        panel.Position=UIS.TouchEnabled and ((short or narrowTouch) and UDim2.new(1,-panelWidth-12,1,-204)or UDim2.new(.5,-panelWidth/2,1,-204))or UDim2.new(0,12,1,-270)
        local dockWidth=math.min(600,math.max(280,v.X-500));dock.Size=UDim2.fromOffset(dockWidth,88);dock.Position=UDim2.new(.5,-dockWidth/2,1,-100)
        u.Percent.Frame.Parent=UIS.TouchEnabled and panel or dock;u.Percent.Frame.Position=UDim2.fromOffset(UIS.TouchEnabled and 12 or 16,UIS.TouchEnabled and 88 or 9);u.Percent.Frame.Size=UDim2.new(1,UIS.TouchEnabled and -24 or -32,0,UIS.TouchEnabled and 47 or 72)
        local hit=u.Percent.Hit;hit.Position=UDim2.fromOffset(0,UIS.TouchEnabled and 22 or 26);hit.Size=UDim2.new(1,0,0,UIS.TouchEnabled and 32 or 44)
        hit.Track.Size=UDim2.new(1,0,0,UIS.TouchEnabled and 4 or 8);hit.Track.Position=UDim2.new(0,0,.5,UIS.TouchEnabled and -2 or -4)
        local thumbSize=UIS.TouchEnabled and 24 or 34;hit.Thumb.Size=UDim2.fromOffset(thumbSize,thumbSize);hit.Thumb.Position=UDim2.new(u.Percent.Value,-thumbSize/2,.5,-thumbSize/2)
        u.Percent.Text.TextSize=UIS.TouchEnabled and 13 or 18;u.Percent.Frame.Label.TextSize=UIS.TouchEnabled and 13 or 15
        u.Upgrade.Position=UDim2.fromOffset(12,UIS.TouchEnabled and 142 or 94)
        info.Position=UIS.TouchEnabled and UDim2.new(0,12,1,-170)or UDim2.new(0,12,1,-116)
        u.Building.Size=UDim2.new(1,UIS.TouchEnabled and -150 or -58,0,24)
        u.TouchOrder.Visible=UIS.TouchEnabled
        if u.Result.Text=='Left-click: select · Right-click: order' or u.Result.Text=='Tap: select · Order: send troops' then u.Result.Text=UIS.TouchEnabled and 'Tap: select · Order: send troops' or 'Left-click: select · Right-click: order' end
        local tw=math.min(420,v.X-24);toast.Size=UDim2.fromOffset(tw,34);toast.Position=short and menu.Visible and UDim2.new(.5,-tw/2,1,-50)or UDim2.new(.5,-tw/2,0,64)
        local cw=math.min(600,v.X-32);local ch=math.min(340,v.Y-82);codeCard.Size=UDim2.fromOffset(cw,ch);codeCard.Position=UDim2.new(.5,-cw/2,.5,-ch/2)
        u.MapName.Size=UDim2.new(1,-274,0,36)
        local gw=math.min(560,v.X-32);local gh=math.min(350,v.Y-88);guide.Size=UDim2.fromOffset(gw,gh);guide.Position=UDim2.new(.5,-gw/2,.5,-gh/2)
        battleGuide.Size=UDim2.fromOffset(math.min(330,v.X-24),116);battleGuide.Position=UDim2.fromOffset(12,short and 58 or 74)
        u.SyncHUD()
    end
    workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(function()u.Layout()end);u.Layout();return u
end
return UI

