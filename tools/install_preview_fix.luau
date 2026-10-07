local Setup={}
function Setup.Install()
    local run=game:GetService('RunService')
    assert(run:IsStudio()and not run:IsRunning(),'Stop the playtest before installing the preview fix.')
    local root=game:GetService('ReplicatedStorage').Kingdoms
    local old=root.CollectionUI;local copy=script.Parent.Runtime.CollectionUI:Clone()
    local backup=Instance.new('Folder');backup.Name='KingdomsBeforePreviewFix_'..game:GetService('HttpService'):GenerateGUID(false)
    backup.Parent=game:GetService('ServerStorage')
    local ok,reason=pcall(function()old.Parent=backup;copy.Parent=root end)
    if not ok then old.Parent=root;copy:Destroy();backup:Destroy();error(reason)end
    script.Parent.Parent=backup
    print('KINGDOMS_PREVIEW_FIX installed; previous module saved in ServerStorage.'..backup.Name)
end
return Setup
