-- Run the real installer with imported fixtures; does not claim native rendering.
local rs=Instance.new('Folder');root.Parent=rs
local ss=Instance.new('Folder');local sss=Instance.new('Folder');local sps=Instance.new('Folder');local starter=Instance.new('Folder')
sps.Name='StarterPlayerScripts';sps.Parent=starter
local server=Instance.new('Folder');server.Name='KingdomsServer';server.Parent=sss
local client=Instance.new('Folder');client.Name='KingdomsClient';client.Parent=sps
for _,record in {{server,'Script','Server'},{client,'LocalScript','Client'}}do local s=Instance.new(record[2]);s.Name=record[3];s.Disabled=false;s.Parent=record[1]end
services.ReplicatedStorage=rs;services.ServerStorage=ss;services.ServerScriptService=sss;services.StarterPlayer=starter
local running=false;services.RunService.IsRunning=function()return running end
local catalog=require(root.MeshCatalog)
local manifest={BaseSignature='qa-before-premium',ChangedModels={},MeshCount=#root.MeshTemplates:GetChildren()}
root.MeshTemplates:SetAttribute('CatalogSignature',manifest.BaseSignature)
local setup=Instance.new('Model');setup.Name='KingdomsPremiumSetup';setup.Parent=workspace
local runtime=Instance.new('Folder');runtime.Name='Runtime';runtime.Parent=setup
for _,source in root:GetChildren()do if source:IsA('ModuleScript')then source:Clone().Parent=runtime end end
for _,record in {{'Script','Server'},{'LocalScript','Client'}}do local s=Instance.new(record[1]);s.Name=record[2];s.Disabled=true;s.Parent=runtime end
local manifestModule=Instance.new('ModuleScript');manifestModule.Name='Manifest';manifestModule.Parent=setup
factories.Manifest=function()return manifest end
local module=Instance.new('ModuleScript');module.Name='PremiumInstaller';module.Parent=setup
local installer=require(module)
local uploads={};local catalogues={}
for _,skin in {'Storm','Dragon','Oracle'}do local model=Instance.new('Model');model.Name='KingdomsPremium'..skin;model.Parent=workspace;catalogues[skin]=model end
for name in catalog.Models do
    local skin=name:match('^(%w+)_')
    if catalogues[skin]then
        table.insert(manifest.ChangedModels,name)
        local keys={name};if catalog.Models[name].Team then table.insert(keys,name..'__Blue');table.insert(keys,name..'__Red')end
        for _,key in keys do local p=root.MeshTemplates[key]:Clone();p.MeshId='rbxassetid://987654';p.Parent=catalogues[skin];uploads[key]=p end
    end
end
local function untouched()assert(root.Parent==rs and server.Parent==sss and client.Parent==sps and #ss:GetChildren()==0)end
local report={passed=0,failed=0,cases={}}
local function test(name,fn)local ok,result=pcall(fn);report[ok and 'passed'or 'failed']+=1;report.cases[name]={passed=ok,result=ok and result or tostring(result)}end
test('Premium installation refuses a running match',function()
    running=true;assert(not pcall(installer.Install));running=false;untouched();return true
end)
test('Missing premium uploads retain every active root',function()
    local p=uploads.Oracle_Gateway;local parent=p.Parent;p.Parent=nil
    assert(not pcall(installer.Install));untouched();p.Parent=parent;return true
end)
test('Unsaved mesh IDs cannot become active premium models',function()
    local p=uploads.Dragon_RoadTile;local id=p.MeshId;p.MeshId=''
    assert(not pcall(installer.Install));untouched();p.MeshId=id;return true
end)
test('Unexpected catalogue signatures cannot replace another game',function()
    root.MeshTemplates:SetAttribute('CatalogSignature','unexpected');assert(not pcall(installer.Install));untouched()
    root.MeshTemplates:SetAttribute('CatalogSignature',manifest.BaseSignature);return true
end)
test('A complete install retains ordinary IDs and swaps only premium models',function()
    local ordinary=root.MeshTemplates.Village_Base.MeshId
    local result=installer.Install();local active=rs.Kingdoms
    assert(#active.MeshTemplates:GetChildren()==manifest.MeshCount)
    assert(active.MeshTemplates:GetAttribute('CatalogSignature')==catalog.Signature)
    assert(active.MeshTemplates.Village_Base.MeshId==ordinary)
    assert(active.MeshTemplates.Storm_Defender_Torso.MeshId=='rbxassetid://987654')
    assert(root.Parent==ss[result.Backup]and setup.Parent==ss[result.Backup])
    assert(server.Server.Disabled and client.Client.Disabled)
    assert(not sss.KingdomsServer.Server.Disabled and not sps.KingdomsClient.Client.Disabled)
    for _,record in active.MeshTemplates:GetChildren()do assert(record.CanCollide==false and record.CanQuery==false)end
    return true
end)
return report
