local SoundService=game:GetService('SoundService')
local Run=game:GetService('RunService')
local Tween=game:GetService('TweenService')
local ContentProvider=game:GetService('ContentProvider')
local Catalog=require(script.Parent.AudioCatalog)
local Music={}
function Music.Start()
    assert(Run:IsClient(),'Game audio must be created on the local client.')
    local old=SoundService:FindFirstChild('KingdomsAudio');if old then old:Destroy()end
    local legacy=SoundService:FindFirstChild('KingdomsMusic');if legacy then legacy:Destroy()end
    local folder=Instance.new('Folder');folder.Name='KingdomsAudio';folder.Parent=SoundService
    local musicGroup=Instance.new('SoundGroup');musicGroup.Name='Music';musicGroup.Volume=.22;musicGroup.Parent=folder
    local effectsGroup=Instance.new('SoundGroup');effectsGroup.Name='Interface';effectsGroup.Volume=.55;effectsGroup.Parent=folder
    local controller={Folder=folder,MusicGroup=musicGroup,EffectsGroup=effectsGroup,Tracks={},Effects={},Tweens={},LastEffect={},Serial=0}
    for name,track in Catalog.Music do
        local sound=Instance.new('Sound');sound.Name=name;sound.SoundId='rbxassetid://'..(track.Id>0 and track.Id or track.FallbackId)
        sound.Volume=0;sound.Looped=true;sound.SoundGroup=musicGroup;sound.Parent=folder
        controller.Tracks[name]=sound
        -- Loading runs independently of UI and editor updates. A revoked or
        -- unavailable track falls back without blocking gameplay.
        task.spawn(function()
            local failed=false
            local ok=pcall(function()ContentProvider:PreloadAsync({sound},function(_,status)
                if status~=Enum.AssetFetchStatus.Success then failed=true end
            end)end)
            if (not ok or failed)and not controller.Destroyed and sound.Parent then
                warn('Kingdoms audio: could not load '..track.Name..'; using the fallback track.')
                sound.SoundId='rbxassetid://'..Catalog.FallbackMusic
                if controller.Context==name then sound:Play()end
            end
        end)
    end
    for name,effect in Catalog.Effects do
        local sound=Instance.new('Sound');sound.Name=name;sound.SoundId='rbxassetid://'..(effect.Id>0 and effect.Id or effect.FallbackId)
        sound.Volume=effect.Gain;sound.PlaybackSpeed=effect.Id>0 and 1 or effect.Speed;sound.SoundGroup=effectsGroup;sound.Parent=folder
        controller.Effects[name]=sound
    end
    function controller.SetVolume(value)musicGroup.Volume=math.clamp(value,0,1)end
    function controller.SetEffectsVolume(value)effectsGroup.Volume=math.clamp(value,0,1)end
    function controller.PlayEffect(name)
        local sound=controller.Effects[name];local effect=Catalog.Effects[name]
        if controller.Destroyed or not sound or effectsGroup.Volume<=0 then return false end
        local now=os.clock()
        if now-(controller.LastEffect[name]or -math.huge)<effect.Gap or now-(controller.LastAnyEffect or -math.huge)<.06 then return false end
        controller.LastEffect[name]=now;controller.LastAnyEffect=now
        -- This API plays only for this player; no sound request is sent to
        -- the server, buildings, or the opponent's client.
        SoundService:PlayLocalSound(sound)
        return true
    end
    function controller.SetContext(name)
        name=name=='Battle'and 'Battle'or 'Menu'
        if controller.Destroyed or controller.Context==name then return end
        controller.Context=name;controller.Serial+=1;local serial=controller.Serial
        for key,sound in controller.Tracks do
            if controller.Tweens[key]then controller.Tweens[key]:Cancel()end
            if key==name and not sound.IsPlaying then sound:Play()end
            local target=key==name and Catalog.Music[key].Gain or 0
            local tween=Tween:Create(sound,TweenInfo.new(.8,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{Volume=target})
            controller.Tweens[key]=tween;tween:Play()
            if key~=name then task.delay(.85,function()
                if not controller.Destroyed and controller.Serial==serial and controller.Context~=key then sound:Stop()end
            end)end
        end
    end
    function controller.Destroy()
        if controller.Destroyed then return end
        controller.Destroyed=true;controller.Serial+=1
        for _,tween in controller.Tweens do tween:Cancel()end
        folder:Destroy()
    end
    controller.SetContext('Menu')
    return controller
end
return Music
