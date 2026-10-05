local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local UIS=game:GetService('UserInputService')
local Run=game:GetService('RunService')
local Tween=game:GetService('TweenService')
local Debris=game:GetService('Debris')
local GuiService=game:GetService('GuiService')
local player=Players.LocalPlayer
local root=RS:WaitForChild('Kingdoms')
local Config=require(root.Config)
local Network=require(root.MapNetwork)
local Default=require(root.MapData)
local Catalog=require(root.MapCatalog)
local Scene=require(root.Scene)
local Art=require(root.Art)
local UI=require(root.UI)
local Editor=require(root.MapEditor)
local Music=require(root.Music)
local Meta=require(root.MetaUI)
local Progression=require(root.Progression)
local command=root:WaitForChild('Command')
local camera=workspace.CurrentCamera
local state,scene,editor=nil,nil,nil
local function viewSide()local side=state and state.ViewerSide or player:GetAttribute('KingdomSide');return side==2 and 2 or 1 end
local editorActive,loaded,custom=false,false,false
local tutorialShown=false
local savedMap,revision=nil,-1
local chosenMap='TwoBridges'
local selected,primary={},nil
local percent,orderMode=50,false
local prefs={Music=.22,Camera=1,Zoom=1,Grid=false,Labels=true}
local center,targetCenter=Vector3.zero,Vector3.zero
local zoom,targetZoom=300,300
local visuals,highlights,labels,previews={},{},{},{}
local ghost,previewUntil,toastUntil=nil,0,0
local hooks={}
local u=UI.Build(player,hooks)
local meta=Meta.Build(u,hooks)
if Run:IsStudio()then _G.KingdomsMeta=meta end
local accountAction=root:WaitForChild('AccountAction')
local sound=Music.Start()
local world=Instance.new('ScreenGui');world.Name='KingdomsWorldLabels';world.ResetOnSpawn=false;world.DisplayOrder=-1;world.Parent=player.PlayerGui
local function playing()return state and (state.Phase=='Preparation' or state.Phase=='Battle')end
local function canControl()return loaded and not u.Menu.Visible and not u.Code.Visible and not u.Tutorial.Visible and (playing() or editorActive)end
local function notify(text)u.ToastText.Text=tostring(text);u.Toast.Visible=true;toastUntil=os.clock()+5 end
local function clearPreviews()for _,p in previews do p:Destroy()end;previews={}end
local function clearHighlights()for _,h in highlights do h:Destroy()end;highlights={}end
local function mark(id,color)
    if not scene then return end
    local obj=scene.Nodes[id] and scene.Nodes[id].Model or scene.Junctions[id];if not obj then return end
    local h=Instance.new('Highlight');h.Adornee=obj;h.FillTransparency=.92;h.OutlineTransparency=.1;h.OutlineColor=color;h.Parent=world;table.insert(highlights,h)
end
local function selectionMarks()
    clearHighlights()
    for id in selected do mark(id,Config.Colors[1])end
    if primary and not selected[primary]then mark(primary,UI.Colors.Gold)end
    if editorActive and editor then if editor.From then mark(editor.From,UI.Colors.Gold)end;if editor.Moving then mark(editor.Moving,UI.Colors.Gold)end end
end
local function deselect()selected={};primary=nil;orderMode=false;u.Panel.Visible=false;u.SyncHUD();selectionMarks()end
local function ownedSelection()
    local list={};if state then for id in selected do if state.Sites[id] and state.Sites[id].Owner==viewSide() then table.insert(list,id)end end end;table.sort(list);return list
end
local function refreshPanel()
    if not playing() or not primary or not scene.Nodes[primary] or not state.Sites[primary]then u.Panel.Visible=false;u.SyncHUD();return end
    u.Panel.Visible=not u.Menu.Visible and not (UIS.TouchEnabled and camera.ViewportSize.X<550 and u.InfoExpanded)
    u.SyncHUD()
    local s=state.Sites[primary];local ids=ownedSelection();local counts={Peasant=0,Defender=0,Archer=0,Runner=0};local waiting,inside,capacity=0,0,0
    local showIds=#ids>1 and ids or {primary}
    for _,id in showIds do local t=state.Sites[id];inside+=t.Population;capacity+=t.Capacity
        for _,kind in Config.Types do counts[kind]+=t.Inside[kind];waiting+=t.Counts[kind]-t.Inside[kind]end
    end
    u.Building.Text=#showIds>1 and 'Здания: '..#showIds or Config.Buildings[scene.Nodes[primary].Kind].Name..' '..({'I','II','III'})[s.Level]
    u.Building.TextSize=15
    for _,kind in Config.Types do u.Roster[kind].Text=Config.Units[kind].Name..': '..counts[kind]end
    u.Percent.Frame.Label.Text='Отправить · '..inside..'/'..capacity..(waiting>0 and ' · ждут '..waiting or '')
    local cost=Config.UpgradeCost[s.Level+1]
    local possible=#showIds==1 and s.Owner==viewSide() and cost and not s.Upgrade and s.Population>=cost and (not s.Health or s.Health>0)
    if #showIds>1 then u.Upgrade.Text='Для улучшения выбери одно здание'
    elseif s.Owner~=viewSide() then u.Upgrade.Text=s.Owner==0 and 'Нейтральное здание' or 'Здание противника'
    elseif s.Health and s.Health<=0 then u.Upgrade.Text='Разрушена · отправь отряд'
    elseif s.Upgrade then u.Upgrade.Text='Улучшение · '..math.ceil(s.Upgrade)..' с'
    elseif not cost then u.Upgrade.Text='Уровень III'
    else u.Upgrade.Text='Улучшить · '..cost..' чел.'end
    u.Upgrade.Active=possible==true;u.Upgrade.AutoButtonColor=u.Upgrade.Active;u.Upgrade.BackgroundColor3=possible and UI.Colors.Blue or UI.Colors.Inset
    u.TouchOrder.Active=#ids>0;u.TouchOrder.BackgroundColor3=orderMode and UI.Colors.Blue or UI.Colors.Inset;u.TouchOrder.Text=orderMode and 'Выбери цель' or 'Приказ →'
end
local function choose(id,add)
    if not id or not state or not state.Sites[id]then deselect();return end
    local own=state.Sites[id].Owner==viewSide()
    if not add or not own then selected={}end
    if own then if add and selected[id]then selected[id]=nil;primary=next(selected)else selected[id]=true;primary=id end else primary=id end
    orderMode=false;selectionMarks();refreshPanel()
end
local function atScreen(p)
    if not scene then return nil end
    local ray=camera:ScreenPointToRay(p.X,p.Y)
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={scene.Folder}
    local hit=workspace:Raycast(ray.Origin,ray.Direction*2500,params)
    return hit and hit.Instance:GetAttribute('SiteId')
end
local function ground(p)
    local ray=camera:ScreenPointToRay(p.X,p.Y)
    if math.abs(ray.Direction.Y)<.001 then return nil end
    local t=-ray.Origin.Y/ray.Direction.Y;if t<0 then return nil end;return ray.Origin+ray.Direction*t
end
local function send(id)
    local sources=ownedSelection()
    if not playing() or #sources==0 or not state.Sites[id] or percent==0 then return end
    command:FireServer('Send',{Sources=sources,Target=id,Percent=percent,Filter='All',Route='Auto'})
    clearPreviews()
    for _,source in sources do
        local points=scene.Map.Route(source,id,state.Time>=Config.PrepTime,'Auto',function(via)
            return state.Sites[via] and state.Sites[via].Owner==viewSide()
        end)
        if points then for i=2,#points do
            local a,b=points[i-1],points[i]
            local p=Instance.new('Part');p.Name='Маршрут';p.Anchored=true;p.CanQuery=false;p.CanCollide=false;p.CanTouch=false;p.Material=Enum.Material.Neon;p.Color=UI.Colors.Gold;p.Transparency=.25;p.Size=Vector3.new(.25,.08,(a-b).Magnitude)
            p.CFrame=CFrame.lookAt((a+b)/2+Vector3.new(0,.4,0),b+Vector3.new(0,.4,0));p.Parent=scene.Folder;table.insert(previews,p)
        end end
    end
    previewUntil=os.clock()+2.5;orderMode=false;selectionMarks();mark(id,UI.Colors.Gold);refreshPanel()
end
local function rebuild(map)
    clearPreviews();clearHighlights();visuals={};labels={};ghost=nil
    for _,p in world:GetChildren()do p:Destroy()end
    scene=Scene.Build(workspace,map,editorActive and 1 or viewSide());Scene.GridVisible(scene,editorActive or prefs.Grid)
    for id in scene.Nodes do
        local l=UI.Label(world,id,'',UDim2.fromOffset(50,22),UDim2.fromOffset(0,0),12);l.TextXAlignment=Enum.TextXAlignment.Center;l.BackgroundColor3=UI.Colors.Panel;l.BackgroundTransparency=.12
        local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,4);c.Parent=l;labels[id]=l
    end
    selectionMarks()
end
local function previewMap()
    if custom and savedMap then return assert(Network.Create(savedMap))end
    return chosenMap=='Random' and Default or assert(Catalog.Create(chosenMap))
end
local function mapName()
    local name=chosenMap=='Random' and 'Случайная карта' or 'Две переправы'
    for _,item in Catalog.Items do if item.Id==chosenMap then name=item.Name end end
    if custom and savedMap then name=savedMap.Name end
    u.MapChoice.Text='Карта: '..name..'  ▾';u.MapButtons.Custom.Active=savedMap~=nil;u.MapButtons.Custom.TextColor3=savedMap and UI.Colors.Text or UI.Colors.Muted
    u.MapButtons.Custom.Text=savedMap and 'Моя: '..savedMap.Name or 'Сохранённая карта отсутствует'
    for id,b in u.MapButtons do b.BackgroundColor3=id==(custom and 'Custom' or chosenMap)and UI.Colors.Blue or UI.Colors.Inset end
end
local function editorUpdate(definition,hint)
    local map,reason=Network.Create(definition,{AllowIncomplete=true});if not map then notify(reason);return end
    rebuild(map);u.EditorHint.Text=hint;u.MapName.Text=definition.Name or 'Моя карта'
    u.Owner.Text='Сторона: '..(editor.Owner==1 and 'синие' or editor.Owner==2 and 'красные' or 'нейтральные')
    u.Owner.BackgroundColor3=Config.Colors[editor.Owner==0 and 3 or editor.Owner]
    u.Editor.Toolbar.Tools.River.Text='Река: '..(definition.River~=false and 'да' or 'нет')
    for kind,b in u.KindButtons do b.BackgroundColor3=editor.Tool=='Place' and editor.Kind==kind and UI.Colors.Blue or UI.Colors.Inset end
    for _,b in u.Editor.Toolbar.Tools:GetChildren()do if b:IsA('TextButton') and b~=u.Owner then b.BackgroundColor3=b.Name==editor.Tool and UI.Colors.Blue or UI.Colors.Inset end end
    selectionMarks()
end
local function exitEditor()
    editorActive=false;u.Editor.Visible=false;u.Code.Visible=false;u.Tutorial.Visible=false;if ghost then ghost:Destroy();ghost=nil end
    deselect();Scene.GridVisible(scene,prefs.Grid);u.Show('Main',false);mapName()
end
local function codeWindow(importing)
    u.Code.Visible=true;u.CodeApply.Visible=importing;u.CodeTitle.Text=importing and 'Загрузить карту' or 'Код карты'
    u.CodeHint.Text=importing and 'Вставь сохранённый код карты.' or 'Скопируй весь код и сохрани его в текстовом файле. Он позволяет перенести карту между запусками.'
    u.CodeText.Text=importing and '' or editor:Export();u.Layout()
end
local function savePrefs()command:FireServer('Prefs',prefs)end
local function refreshSettings()
    sound.Volume=prefs.Music;u.Music.Set(prefs.Music);u.Camera.Set((prefs.Camera-.5)/1.5);u.Zoom.Set((prefs.Zoom-.5)/1.5)
    u.Camera.Text.Text=string.format('%.1f×',prefs.Camera);u.Zoom.Text.Text=string.format('%.1f×',prefs.Zoom)
    u.Grid.Text='Сетка: '..(prefs.Grid and 'включена' or 'выключена');u.Labels.Text='Численность зданий: '..(prefs.Labels and 'включена' or 'выключена')
    if scene then Scene.GridVisible(scene,editorActive or prefs.Grid)end
end
hooks.Menu=function()u.Show('Main',playing());u.Panel.Visible=false;u.SyncHUD()end
hooks.Info=function()u.InfoExpanded=not u.InfoExpanded;refreshPanel();u.SyncHUD()end
hooks.TutorialClose=function()u.Tutorial.Visible=false end
hooks.Deselect=deselect
hooks.Percent=function(v)percent=v end
hooks.Upgrade=function()if #ownedSelection()==1 and primary and u.Upgrade.Active then command:FireServer('Upgrade',{Site=primary})end end
hooks.TouchOrder=function()if #ownedSelection()>0 then orderMode=not orderMode;refreshPanel();if orderMode then notify('Коснись здания, куда отправить отряд.')end end end
hooks.MapChoice=function()if not playing()then u.Show('Maps',false);mapName()end end
hooks.SelectMap=function(id)
    if id=='Custom' and not savedMap then return end
    custom=id=='Custom';if not custom then chosenMap=id end
    mapName();rebuild(previewMap());u.Show('Difficulty',false)
end
hooks.Play=function()if not loaded then return end;if playing()then u.Menu.Visible=false;refreshPanel()elseif state and state.PrivateMatch then command:FireServer('ReturnMenu',{})else u.Show('Mode',false)end end
hooks.AI=function()if state and state.Queueing then command:FireServer('CancelPvP',{})end;u.Show('Difficulty',false);mapName()end
hooks.Online=function()if not loaded then return end;command:FireServer(state and state.Queueing and 'CancelPvP' or 'JoinPvP',{})end
hooks.Ranked=function()if not loaded then return end;command:FireServer(state and state.Queueing and 'CancelPvP'or 'JoinRanked',{})end
hooks.Profile=function()u.Show('Profile',playing())end
hooks.Shop=function()if not loaded then return end;u.Show('Shop',playing());meta.SelectSkin(meta.Profile and meta.Profile.Equipped or 'Default')end
hooks.PreviewSkin=function(id)meta.SelectSkin(id)end
hooks.Chests=function()u.Show('Chests',playing());meta.ChestPreview();meta.RefreshChest()end
hooks.OpenChest=function()
    if not meta.ChestBuy.Active or not meta.ChestInfo then return end
    meta.ChestPending=true;meta.ChestRequest=game:GetService('HttpService'):GenerateGUID(false)
    local request=meta.ChestRequest;local signature=meta.ChestInfo.Signature
    meta.RefreshChest();accountAction:FireServer('OpenChest',{RequestId=request,Signature=signature})
    task.delay(6,function()if meta.ChestPending and meta.ChestRequest==request then accountAction:FireServer('OpenChest',{RequestId=request,Signature=signature})end end)
end
hooks.BuySkin=function(id)if meta.Buy.Active then accountAction:FireServer('Buy',{Skin=id})end end
hooks.EquipSkin=function(id)if meta.Equip.Active then accountAction:FireServer('Equip',{Skin=id})end end
hooks.CoinPack=function(id)accountAction:FireServer('Coins',{Product=id})end
hooks.Board=function(kind)meta.BoardKind=kind;if meta.Boards[kind]then meta.Apply({Board=meta.Boards[kind]})else meta.Mine.Text='Загружаем таблицу…'end;accountAction:FireServer('Board',{Kind=kind})end
hooks.Leaders=function()u.Show('Leaders',playing());hooks.Board('Rank')end
hooks.MetaBack=function()u.Show('Main',playing())end
hooks.RefreshProfile=function()command:FireServer('Ready',{});accountAction:FireServer('Refresh',{})end
root:WaitForChild('Account').OnClientEvent:Connect(function(data)
    meta.Apply(data)
    if data.Reward and not data.Reward.AlreadyApplied then notify('Матч учтён: +'..data.Reward.XP..' опыта'..(data.Reward.Coins>0 and ', +'..data.Reward.Coins..' монет'or ''))end
end)
task.spawn(function()
    for _,pack in Progression.Products do if pack.ProductId>0 then
        local ok,info=pcall(function()return game:GetService('MarketplaceService'):GetProductInfoAsync(pack.ProductId,Enum.InfoType.Product)end)
        local button=meta.Products[pack.Id]
        if ok and info.IsForSale then button.Text=pack.Coins..' монет\n'..info.PriceInRobux..' Robux'else button.Active=false;button.Text=pack.Coins..' монет\nНедоступно'end
    end end
end)
hooks.Editor=function()
    if not loaded or playing()then return end
    deselect();editorActive=true;u.Menu.Visible=false;u.HUD.Visible=false;u.Editor.Visible=true
    if state and state.Queueing then command:FireServer('CancelPvP',{})end
    editor=Editor.new(previewMap().Definition,editorUpdate,notify);editor:Refresh();targetCenter=Vector3.zero;targetZoom=300
    if not tutorialShown then tutorialShown=true;u.Tutorial.Visible=true end
end
hooks.Settings=function()u.Show('Settings',playing())end
hooks.Return=function()deselect();command:FireServer('ReturnMenu',{});u.Show('Main',false)end
hooks.Start=function(difficulty)
    if not loaded then return end
    deselect();command:FireServer('Start',{Difficulty=difficulty,MapId=not custom and chosenMap or nil,Definition=custom and savedMap or nil})
end
hooks.Back=function()
    if u.Page=='Settings'then savePrefs()end
    if u.Page=='Mode'and state and state.Queueing then command:FireServer('CancelPvP',{})end
    u.Show(u.Page=='Maps'and 'Difficulty' or u.Page=='Difficulty'and 'Mode' or 'Main',playing())
end
hooks.Music=function(v,done)prefs.Music=v;sound.Volume=v;if done then savePrefs()end end
hooks.Camera=function(v,done)prefs.Camera=v;u.Camera.Text.Text=string.format('%.1f×',v);if done then savePrefs()end end
hooks.Zoom=function(v,done)prefs.Zoom=v;u.Zoom.Text.Text=string.format('%.1f×',v);if done then savePrefs()end end
hooks.Grid=function()prefs.Grid=not prefs.Grid;refreshSettings();savePrefs()end
hooks.Labels=function()prefs.Labels=not prefs.Labels;refreshSettings();savePrefs()end
local function validatedEditor()
    editor.Definition.Name=u.MapName.Text
    local map,reason=editor:Validate();if not map then notify(reason);return nil end;return map
end
hooks.SaveMap=function()local map=validatedEditor();if map then command:FireServer('SaveMap',{Definition=map.Definition})end end
hooks.TestMap=function()
    local map=validatedEditor();if not map then return end
    savedMap=map.Definition;custom=true;exitEditor();u.Show('Difficulty',false)
end
hooks.ExitEditor=exitEditor
hooks.EditorTool=function(tool)
    editor.Definition.Name=u.MapName.Text
    if tool=='Owner'then editor:CycleOwner()
    elseif tool=='River'then editor:ToggleRiver()
    elseif tool=='New'then editor:New()
    elseif tool=='Undo'then editor:Undo()
    elseif tool=='Export'then codeWindow(false)
    elseif tool=='Import'then codeWindow(true)
    elseif tool=='Help'then u.Tutorial.Visible=true
    else editor:SetTool(tool)end
end
hooks.EditorKind=function(kind)editor.Definition.Name=u.MapName.Text;editor:SetKind(kind)end
hooks.ImportApply=function()local ok,reason=editor:Import(u.CodeText.Text);if ok then u.Code.Visible=false;notify('Карта загружена.')else notify(reason)end end
hooks.CodeClose=function()u.Code.Visible=false end
local function arrow(e)
    local p=Instance.new('Part');p.Name='Стрела';p.Size=Vector3.new(.07,.07,1.1);p.Material=Enum.Material.Wood;p.Color=UI.Colors.Gold;p.Anchored=true;p.CanQuery=false;p.CanCollide=false;p.CanTouch=false;p.CFrame=CFrame.lookAt(e.From,e.To);p.Parent=scene.Folder
    Tween:Create(p,TweenInfo.new(.3,Enum.EasingStyle.Linear),{CFrame=CFrame.lookAt(e.To,e.To+(e.To-e.From))}):Play();Debris:AddItem(p,.33)
end
local function garrisonSwing(e)
    local blade=Instance.new('Part');blade.Name='Удар гарнизона';blade.Size=Vector3.new(.09,.09,Config.MeleeContact)
    blade.Material=Enum.Material.Metal;blade.Color=Color3.fromRGB(224,228,229)
    blade.Anchored=true;blade.CanQuery=false;blade.CanCollide=false;blade.CanTouch=false
    local center=(e.From+e.To)/2;local facing=CFrame.lookAt(center,e.To)
    blade.CFrame=facing*CFrame.Angles(0,-math.pi/3,0);blade.Parent=scene.Folder
    Tween:Create(blade,TweenInfo.new(Config.MeleeImpactDelay),{CFrame=facing*CFrame.Angles(0,math.pi/3,0),Transparency=1}):Play()
    Debris:AddItem(blade,Config.MeleeImpactDelay+.1)
end
local function applySnapshot(snapshot)
    local previous=state and state.Phase;state=snapshot;if not loaded then return end
    u.InPrivate=state.PrivateMatch;u.Connecting=state.Connecting
    local active=playing()
    if active and revision~=state.MapRevision then
        local map,reason=Network.Create(state.Map);if not map then notify(reason);return end
        revision=state.MapRevision;rebuild(map);deselect()
        local castle=scene.Nodes[map.Castles[viewSide()]];targetCenter=castle.Position+Vector3.new(viewSide()==1 and 45 or -45,0,0);targetZoom=UIS.TouchEnabled and 210 or 180
    end
    if active and previous~='Preparation' and previous~='Battle'then meta.HidePreviews();u.Menu.Visible=false;u.Editor.Visible=false;editorActive=false;u.Code.Visible=false end
    u.HUD.Visible=active and not editorActive
    if active then
        Scene.Update(scene,state)
        local alive={}
        for _,d in state.Units do
            local id,kind,side,x,z=d[1],d[2],d[3],d[4],d[5];alive[id]=true
            local skin=state.Skins and state.Skins[side]or 'Default'
            if not visuals[id] or visuals[id].Kind~=kind or visuals[id].Skin~=skin then if visuals[id]then visuals[id].Model:Destroy()end;visuals[id]={Kind=kind,Skin=skin,Model=Art.Unit(kind,scene.Units,Config.TeamColor(side,viewSide()),skin),Position=Vector3.new(x,.25,z)}end
            local v=visuals[id];local y=d[11]or .25
            for _,b in scene.Map.Bridges do if math.abs(x)<17 and math.abs(z-b.Position.Z)<4 then y=.7;break end end
            v.Goal=Vector3.new(x,y,z);v.Heading=Vector3.new(d[7],0,d[8]);v.Attacking=d[9]
        end
        for id,v in visuals do if not alive[id]then v.Model:Destroy();visuals[id]=nil end end
        for _,e in state.Events do if e.Type=='Arrow'then arrow(e)elseif e.Type=='GarrisonSwing'then garrisonSwing(e)elseif e.Type=='Capture'and e.Side==viewSide() and scene.Nodes[e.Site]then notify('Захвачено: '..Config.Buildings[scene.Nodes[e.Site].Kind].Name)end end
        for id,s in state.Sites do local l=labels[id];if l then l.Text=tostring(s.Population);l.TextColor3=Config.TeamColor(s.Owner,viewSide())end end
        local total=state.Totals[viewSide()];local time=string.format('%02d:%02d',math.floor(state.Time/60),math.floor(state.Time%60))
        u.Summary.Text='Еда: '..math.floor(state.Food[viewSide()])..'\nСеляне: '..total.Peasant..'\nВремя: '..time..'\n'..(scene.Map.River and (state.Time<60 and 'Мосты: '..math.ceil(60-state.Time)..' с' or 'Мосты открыты')or 'Карта без реки')
    elseif previous=='Preparation' or previous=='Battle'then
        deselect();for _,v in visuals do v.Model:Destroy()end;visuals={};u.Show('Main',false)
        u.Result.Text=state.Phase=='Ended'and (state.Winner==0 and 'Ничья' or state.Winner==viewSide() and 'Победа' or 'Поражение') or ''
        targetCenter=Vector3.zero;targetZoom=300
    end
    meta.QueueMode=state.Queueing and state.QueueMode or nil
    u.Online.Text=state.Connecting and 'Подключаемся…' or state.Queueing and state.QueueMode~='Ranked'and 'Отменить поиск' or 'Обычный · 1 на 1'
    u.Online.Active=not state.Connecting
    u.Ranked.Active=not state.Connecting
    u.Ranked.Text=state.Queueing and state.QueueMode=='Ranked'and 'Отменить ранговый поиск'or 'Ранговый · '..(meta.Profile and meta.Profile.Rank or 0)
    u.QueueStatus.Text=state.Connecting and 'Подключаемся к отдельному серверу матча…' or state.Queueing and (state.Studio and 'Studio: ждём второго тестового игрока.'or state.QueueMode=='Ranked'and 'Подбираем соперника по рангу среди всех лобби…'or 'Ищем соперника своего уровня…') or 'Карта в матче с игроком выбирается случайно.'
    if state.PrivateMatch and not active then u.Play.Text='В лобби';u.EditorButton.Active=false;u.EditorButton.TextColor3=UI.Colors.Muted
        if state.Phase=='Waiting'then u.Result.Text='Ожидаем подключения участников матча…'end
    end
    refreshPanel()
end
-- Lazy mesh creation yields. Apply snapshots serially so a slow first load
-- cannot create duplicate armies or buildings from concurrent network updates.
local snapshotBusy,pendingSnapshot,pendingEvents=false,nil,{}
local function receiveSnapshot(snapshot)
    pendingSnapshot=snapshot
    for _,event in snapshot.Events or {}do table.insert(pendingEvents,event)end
    if snapshotBusy then return end
    snapshotBusy=true
    while pendingSnapshot do
        local newest=pendingSnapshot;pendingSnapshot=nil
        newest.Events=pendingEvents;pendingEvents={}
        local ok,reason=pcall(applySnapshot,newest)
        if not ok then warn('Kingdoms snapshot: '..tostring(reason));notify('Не удалось обновить модели. '..tostring(reason))end
    end
    snapshotBusy=false
end
root:WaitForChild('Snapshot').OnClientEvent:Connect(receiveSnapshot)
root:WaitForChild('Feedback').OnClientEvent:Connect(notify)
root:WaitForChild('EditorData').OnClientEvent:Connect(function(data)
    if data.Map then savedMap=data.Map;if data.Saved then custom=true end;mapName()end
    if data.Prefs then for k,v in data.Prefs do if prefs[k]~=nil then prefs[k]=v end end;refreshSettings()end
    if data.Saved then
        if data.Persistent then notify('Карта сохранена.')else notify('Карта сохранена в этом запуске. Скопируй код для следующих запусков.');if editorActive then codeWindow(false)end end
    end
end)
local pointer,panMouse,pinch=nil,false,false
local function pan(a,b)local old,new=ground(a),ground(b);if old and new then targetCenter+=old-new end end
local function editorClick(p)
    local hit=ground(p);if not hit then return end
    editor.Definition.Name=u.MapName.Text;editor:Click(atScreen(p),math.round(hit.X/32),math.round(hit.Z/32))
end
local function dragSelect(a,b,add)
    if not add then selected={};primary=nil end
    for id,node in scene.Nodes do
        local p,visible=camera:WorldToScreenPoint(node.Position)
        if visible and state.Sites[id].Owner==viewSide() and p.X>=math.min(a.X,b.X)and p.X<=math.max(a.X,b.X)and p.Y>=math.min(a.Y,b.Y)and p.Y<=math.max(a.Y,b.Y)then selected[id]=true;primary=primary or id end
    end
    orderMode=false;selectionMarks();refreshPanel()
end
UIS.InputBegan:Connect(function(input,processed)
    if UIS:GetFocusedTextBox()then return end
    if input.KeyCode==Enum.KeyCode.Escape and loaded then
        if u.Tutorial.Visible then u.Tutorial.Visible=false
        elseif u.Code.Visible then u.Code.Visible=false
        elseif editorActive then exitEditor()
        elseif u.Menu.Visible and playing()then u.Menu.Visible=false;refreshPanel()
        elseif primary then deselect()else hooks.Menu()end;return
    end
    if processed or not canControl()then return end
    if editorActive and input.KeyCode==Enum.KeyCode.Z and (UIS:IsKeyDown(Enum.KeyCode.LeftControl)or UIS:IsKeyDown(Enum.KeyCode.RightControl))then editor:Undo();return end
    local p=Vector2.new(input.Position.X,input.Position.Y)
    if input.UserInputType==Enum.UserInputType.MouseButton3 then panMouse=p
    elseif input.UserInputType==Enum.UserInputType.MouseButton2 then
        if editorActive then editor.From=nil;editor.Moving=nil;editor:Refresh()else local id=atScreen(p);if id then send(id)end end
    elseif input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        if not pointer then pointer={Input=input,Start=p,Last=p,Touch=input.UserInputType==Enum.UserInputType.Touch,Moved=false,Time=os.clock()}
        elseif input.UserInputType==Enum.UserInputType.Touch then pinch=true end
    end
end)
UIS.InputChanged:Connect(function(input,processed)
    if not canControl()then return end
    local p=Vector2.new(input.Position.X,input.Position.Y)
    if input.UserInputType==Enum.UserInputType.MouseWheel and not processed then targetZoom=math.clamp(targetZoom-input.Position.Z*14*prefs.Zoom,35,400)
    elseif input.UserInputType==Enum.UserInputType.MouseMovement then
        if panMouse then pan(panMouse,p);panMouse=p end
        if pointer and not pointer.Touch then pointer.Last=p;pointer.Moved=pointer.Moved or (p-pointer.Start).Magnitude>8
            if pointer.Moved and not editorActive then u.SelectionBox.Visible=true;u.SelectionBox.Position=UDim2.fromOffset(math.min(p.X,pointer.Start.X),math.min(p.Y,pointer.Start.Y));u.SelectionBox.Size=UDim2.fromOffset(math.abs(p.X-pointer.Start.X),math.abs(p.Y-pointer.Start.Y))end
        end
    elseif pointer and pointer.Touch and input==pointer.Input and not pinch then
        pointer.Moved=pointer.Moved or (p-pointer.Start).Magnitude>8
        if pointer.Moved then pan(pointer.Last,p)end;pointer.Last=p
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton3 then panMouse=false end
    if pointer and input==pointer.Input then
        local p=Vector2.new(input.Position.X,input.Position.Y)
        if canControl() and not pinch then
            if not pointer.Moved and (p-pointer.Start).Magnitude<8 then
                if editorActive then editorClick(p)
                else local id=atScreen(p)
                    if pointer.Touch and orderMode and os.clock()-pointer.Time<.45 and id then send(id)
                    else choose(id,not pointer.Touch and (UIS:IsKeyDown(Enum.KeyCode.LeftShift)or UIS:IsKeyDown(Enum.KeyCode.RightShift)))end
                end
            elseif not pointer.Touch and not editorActive then dragSelect(pointer.Start,p,UIS:IsKeyDown(Enum.KeyCode.LeftShift)or UIS:IsKeyDown(Enum.KeyCode.RightShift))end
        end
        pointer=nil;pinch=false;u.SelectionBox.Visible=false
    end
end)
local pinchZoom=zoom
UIS.TouchPinch:Connect(function(_,scale,_,phase,processed)
    if processed or not canControl()then return end
    pinch=true;if phase==Enum.UserInputState.Begin then pinchZoom=targetZoom end
    targetZoom=math.clamp(pinchZoom/math.max(scale,.1),35,400)
    if phase==Enum.UserInputState.End then pointer=nil;pinch=false end
end)
local function updateGhost()
    if not editorActive or u.Code.Visible or u.Tutorial.Visible or not editor or editor.Tool~='Place' and not editor.Moving then if ghost then ghost.Transparency=1 end;return end
    local p=UIS:GetMouseLocation()-GuiService:GetGuiInset();if pointer and pointer.Touch then p=pointer.Last end
    local hit=ground(p);if not hit then return end
    local x,z=math.round(hit.X/32),math.round(hit.Z/32)
    if not ghost then ghost=Instance.new('Part');ghost.Name='Клетка размещения';ghost.Size=Vector3.new(29,.08,29);ghost.Anchored=true;ghost.CanQuery=false;ghost.CanTouch=false;ghost.CanCollide=false;ghost.Material=Enum.Material.Neon;ghost.Parent=scene.Folder end
    ghost.Transparency=.65;ghost.Position=Vector3.new(x*32,.18,z*32);ghost.Color=editor:CanPlace(x,z,editor.Moving)and Color3.fromRGB(106,190,135)or Color3.fromRGB(220,100,83)
end
Run.RenderStepped:Connect(function(dt)
    camera.CameraType=Enum.CameraType.Scriptable;camera.FieldOfView=50
    if canControl() and not UIS:GetFocusedTextBox()then
        local d=Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W)then d+=Vector3.new(0,0,-1)end;if UIS:IsKeyDown(Enum.KeyCode.S)then d+=Vector3.new(0,0,1)end
        if UIS:IsKeyDown(Enum.KeyCode.A)then d+=Vector3.new(-1,0,0)end;if UIS:IsKeyDown(Enum.KeyCode.D)then d+=Vector3.new(1,0,0)end
        if d.Magnitude>0 then targetCenter+=d.Unit*dt*targetZoom*.45*prefs.Camera end
    end
    targetCenter=Vector3.new(math.clamp(targetCenter.X,-256,256),0,math.clamp(targetCenter.Z,-170,170))
    center=center:Lerp(targetCenter,math.min(1,dt*12));zoom+=(targetZoom-zoom)*math.min(1,dt*12)
    camera.CFrame=CFrame.lookAt(center+Vector3.new(0,zoom,zoom*.83),center)
    world.Enabled=loaded and playing() and prefs.Labels and not u.Menu.Visible and not editorActive
    if scene then for id,l in labels do
        local node=scene.Nodes[id];local p,visible=camera:WorldToScreenPoint(node.LabelPoint);l.Visible=visible and p.Z>0
        l.Position=UDim2.fromOffset(p.X-25,p.Y-22)
    end end
    for _,v in visuals do if v.Goal then
        local moving=(v.Goal-v.Position).Magnitude>.12;v.Position=v.Position:Lerp(v.Goal,math.min(1,dt*12))
        local h=v.Heading.Magnitude>.01 and v.Heading or Vector3.new(0,0,-1);Art.Pose(v.Model,CFrame.lookAt(v.Position,v.Position+h),os.clock()*8,moving,v.Attacking)
    end end
    if os.clock()>toastUntil then u.Toast.Visible=false end
    if #previews>0 and os.clock()>previewUntil then clearPreviews();selectionMarks()end
    updateGhost()
end)
u.Play.Active=false;u.EditorButton.Active=false
local ok,reason=pcall(function()rebuild(Default)end)
if not ok then u.Result.Text='Ошибка загрузки моделей';notify(reason);warn('Kingdoms: '..tostring(reason));return end
loaded=true;u.Play.Active=true;u.EditorButton.Active=true;u.Result.Text='ЛКМ — выбрать · ПКМ — приказ';refreshSettings();mapName();u.Show('Main',false)
command:FireServer('Ready',{})
if state then receiveSnapshot(state)end
