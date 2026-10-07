-- Guarded, reversible source update. Uploaded meshes and remotes stay in place.
local Setup={}
function Setup.Install()
    local run=game:GetService('RunService')
    assert(run:IsStudio()and not run:IsRunning(),'Stop the playtest before installing the release.')
    local root=game:GetService('ReplicatedStorage'):FindFirstChild('Kingdoms')
    assert(root and root:FindFirstChild('MeshTemplates')and root.MeshTemplates:GetAttribute('Complete')==true,'Install the uploaded mesh catalogue first.')
    local server=game:GetService('ServerScriptService'):FindFirstChild('KingdomsServer')
    local client=game:GetService('StarterPlayer').StarterPlayerScripts:FindFirstChild('KingdomsClient')
    assert(server and client,'Missing active script containers.')
    local payload=script.Parent:FindFirstChild('Runtime');assert(payload,'Missing release source payload.')
    local changes={};local seen={}
    for _,source in payload:GetChildren()do
        assert(source:IsA('LuaSourceContainer')and not seen[source.Name],'Invalid or duplicate release module.')
        seen[source.Name]=true
        local parent=source.Name=='Server'and server or source.Name=='Client'and client or root
        local name=source.Name
        local previous=parent:FindFirstChild(name)
        if previous then assert(previous.ClassName==source.ClassName,'Source type mismatch: '..name)end
        local copy=source:Clone();copy.Name=name
        if copy:IsA('Script')or copy:IsA('LocalScript')then copy.Disabled=true end
        local wasDisabled=nil
        if previous and (previous:IsA('Script')or previous:IsA('LocalScript'))then wasDisabled=previous.Disabled end
        table.insert(changes,{Parent=parent,Previous=previous,Copy=copy,Disabled=wasDisabled})
    end
    assert(seen.Server and seen.Client and seen.BattleGuide and seen.Progression and seen.SkinStyles and seen.AudioCatalog,'Incomplete release source payload.')
    local backup=Instance.new('Folder');backup.Name='KingdomsBeforeRelease_'..game:GetService('HttpService'):GenerateGUID(false);backup.Parent=game:GetService('ServerStorage')
    local ok,reason=pcall(function()
        for _,change in changes do
            if change.Previous then
                if change.Previous:IsA('Script')or change.Previous:IsA('LocalScript')then change.Previous.Disabled=true end
                change.Previous.Parent=backup
            end
            change.Copy.Parent=change.Parent
        end
        for _,change in changes do if change.Copy:IsA('Script')or change.Copy:IsA('LocalScript')then change.Copy.Disabled=false end end
    end)
    if not ok then
        for _,change in changes do
            change.Copy:Destroy()
            if change.Previous then
                change.Previous.Parent=change.Parent
                if change.Disabled~=nil then change.Previous.Disabled=change.Disabled end
            end
        end
        backup:Destroy();error(reason)
    end
    root:SetAttribute('ReleaseVersion','0.15')
    script.Parent.Parent=backup
    print('KINGDOMS_RELEASE_INSTALLED '..#changes..' sources; uploaded meshes preserved. Backup: ServerStorage.'..backup.Name)
end
return Setup
