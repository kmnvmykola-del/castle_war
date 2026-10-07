-- Real Art/Music/UI modules with test-only imported templates. Exported vertex
-- colours are checked independently in tools/validate_static_meshes.py.
local q=game.ReplicatedStorage.Kingdoms
local Config=require(q.Config)
local Styles=require(q.SkinStyles)
local Art=require(q.Art);Art.Prepare()
local Catalog=require(q.AudioCatalog)
local client=true
services.RunService.IsClient=function()return client end
services.TweenService.Create=function(_,target,_,props)
    return {Play=function()for key,value in props do target[key]=value end end,Cancel=function()end}
end
services.ContentProvider={PreloadAsync=function(_,_,fn)fn('audio',Enum.AssetFetchStatus.Success)end}
function nodeMethods:Play()self.IsPlaying=true;self.Plays=(self.Plays or 0)+1 end
function nodeMethods:Stop()self.IsPlaying=false end
local function audioService()
    local service=Instance.new('SoundService');service.LocalPlays={}
    function service:PlayLocalSound(sound)table.insert(self.LocalPlays,{Id=sound.SoundId,Volume=sound.Volume*self.SoundVolume,Group=sound.SoundGroup})end
    service.SoundVolume=1
    return service
end
services.SoundService=audioService()
local firstService=services.SoundService
local Music=require(q.Music)
local controller=Music.Start()
local report={passed=0,failed=0,cases={}}
local function test(name,fn)local ok,result=pcall(fn);report[ok and 'passed'or 'failed']+=1;report.cases[name]={passed=ok,result=ok and result or tostring(result)}end

test('All 25 sets and four army types show own blue and enemy red from either side',function()
    local parent=Instance.new('Folder')
    for _,skin in Styles.Items do for _,kind in Config.Types do
        local name=(skin.Id=='Default'and ''or skin.Id..'_')..kind..'_Torso'
        assert(Art.Modules[name].Team,name)
        local models={}
        for _,viewer in {1,2}do for _,owner in {1,2}do
            local colour=Config.TeamColor(owner,viewer)
            local model=Art.Unit(kind,parent,colour,skin.Id);table.insert(models,model)
            for _,limb in {'Torso','Head','LeftArm','RightArm','LeftLeg','RightLeg'}do
                local limbName=(skin.Id=='Default'and ''or skin.Id..'_')..kind..'_'..limb
                if not Art.Modules[limbName]then limbName=kind..'_'..limb end
                local key=limbName..(Art.Modules[limbName].Team and (owner==viewer and '__Blue'or '__Red')or '')
                assert(model[limb]:GetAttribute('MeshKey')==key,limbName..' incorrect team asset')
                assert(model[limb].MeshId==q.MeshTemplates[key].MeshId,limbName..' incorrect uploaded mesh')
            end
            assert(model.Insignia.Color==colour,name..' team badge')
        end end
        for _,model in models do model:Destroy()end
        Art.Prune()
    end end
    return true
end)
test('Neutral garrisons render all four standard army types in grey from either viewer side',function()
    local parent=Instance.new('Folder')
    for _,kind in Config.Types do for _,viewer in {1,2}do
        local model=Art.Unit(kind,parent,Config.TeamColor(0,viewer),'Default')
        for _,limb in {'Torso','Head','LeftArm','RightArm','LeftLeg','RightLeg'}do
            local name=kind..'_'..limb
            local key=name..(Art.Modules[name].Team and '__Neutral'or '')
            assert(model[limb]:GetAttribute('MeshKey')==key,name..' neutral colour')
            assert(model[limb].MeshId==q.MeshTemplates[key].MeshId,name..' neutral asset')
        end
        assert(model.Insignia.Color==Config.Colors[3]);model:Destroy()
    end end
    parent:Destroy();Art.Prune();return true
end)
test('Unit team variants reuse cached geometry and never recolour another army',function()
    local parent=Instance.new('Folder')
    local blue=Art.Unit('Defender',parent,Config.Colors[1],'Royal')
    local red=Art.Unit('Defender',parent,Config.Colors[2],'Royal')
    local second=Art.Unit('Defender',parent,Config.Colors[1],'Royal')
    assert(blue.Torso.MeshId==second.Torso.MeshId and blue.Torso~=second.Torso)
    assert(blue.Torso:GetAttribute('MeshKey')~=red.Torso:GetAttribute('MeshKey'))
    assert(blue.Head:GetAttribute('MeshKey')==red.Head:GetAttribute('MeshKey'),'Neutral head geometry should remain shared')
    assert(blue.Torso.MeshId~=red.Torso.MeshId)
    local templates=#q.MeshTemplates:GetChildren()
    parent:Destroy();Art.Prune();assert(not next(Art.Cache),'Unused references leaked')
    assert(#q.MeshTemplates:GetChildren()==templates,'Pruning destroyed imported templates')
    return true
end)
test('Music changes for battle, fades by context and uses the configured audio',function()
    assert(controller.Context=='Menu'and controller.Tracks.Menu.IsPlaying)
    local menu=Catalog.Music.Menu
    assert(controller.Tracks.Menu.SoundId=='rbxassetid://'..(menu.Id>0 and menu.Id or menu.FallbackId))
    controller.SetContext('Battle');assert(controller.Tracks.Battle.IsPlaying and not controller.Tracks.Menu.IsPlaying)
    local plays=controller.Tracks.Battle.Plays
    controller.SetContext('Battle');assert(controller.Tracks.Battle.Plays==plays,'Snapshots restarted music')
    controller.SetContext('Menu');assert(controller.Tracks.Menu.IsPlaying and not controller.Tracks.Battle.IsPlaying)
    return true
end)
test('Music and sound-effects volumes are independent and rapid clicks are bounded',function()
    controller.SetVolume(.31);controller.SetEffectsVolume(.42)
    assert(controller.MusicGroup.Volume==.31 and controller.EffectsGroup.Volume==.42)
    assert(controller.PlayEffect('Select'));assert(not controller.PlayEffect('Select'))
    local count=#firstService.LocalPlays
    controller.SetEffectsVolume(0);assert(not controller.PlayEffect('Order'))
    assert(#firstService.LocalPlays==count and controller.MusicGroup.Volume==.31)
    controller.SetEffectsVolume(1.8);assert(controller.EffectsGroup.Volume==1)
    controller.SetVolume(-1);assert(controller.MusicGroup.Volume==0 and controller.EffectsGroup.Volume==1)
    return true
end)
test('A second client never hears first-client interface events or volume changes',function()
    local secondRoot=Instance.new('Folder')
    q.AudioCatalog:Clone().Parent=secondRoot;q.Music:Clone().Parent=secondRoot
    services.SoundService=audioService();local secondService=services.SoundService
    local other=require(secondRoot.Music).Start()
    controller.LastAnyEffect=nil;controller.LastEffect.Click=nil
    assert(controller.PlayEffect('Click'))
    assert(#secondService.LocalPlays==0 and #firstService.LocalPlays>0)
    controller.SetEffectsVolume(.17);assert(other.EffectsGroup.Volume==.55)
    other.Destroy();return true
end)
test('Disabled UI buttons stay silent; settings expose separate audio controls',function()
    local UI=require(q.UI);UI.PlaySound=controller.PlayEffect
    local player={PlayerGui=Instance.new('Folder')};local calls=0
    local u=UI.Build(player,{Play=function()calls+=1 end})
    assert(u.Music.Frame.Label.Text=='Music Volume'and u.Effects.Frame.Label.Text=='Sound Effects Volume')
    local before=#firstService.LocalPlays
    u.Play.Active=false;u.Play.Activated.Callback();assert(calls==0 and #firstService.LocalPlays==before)
    controller.LastAnyEffect=nil;controller.LastEffect.Click=nil
    u.Play.Active=true;u.Play.Activated.Callback();assert(calls==1 and #firstService.LocalPlays==before+1)
    UI.PlaySound=nil;return true
end)
test('Uploaded original IDs take precedence and server execution cannot create audio',function()
    local previous=Catalog.Music.Menu.Id;Catalog.Music.Menu.Id=123456789
    local fresh=Music.Start();assert(fresh.Tracks.Menu.SoundId=='rbxassetid://123456789');fresh.Destroy();Catalog.Music.Menu.Id=previous
    client=false;assert(not pcall(Music.Start));client=true
    return true
end)
test('Unavailable original music falls back without blocking the client',function()
    local previous=services.ContentProvider.PreloadAsync
    services.ContentProvider.PreloadAsync=function()error('Unavailable audio')end
    local fresh=Music.Start()
    services.ContentProvider.PreloadAsync=previous
    assert(fresh.Tracks.Menu.SoundId=='rbxassetid://'..Catalog.FallbackMusic and fresh.Tracks.Menu.IsPlaying)
    fresh.Destroy();return true
end)
return report
