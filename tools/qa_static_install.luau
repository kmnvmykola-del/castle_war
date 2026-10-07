local q=root
local report={passed=0,failed=0,cases={}}
local function test(name,fn)local ok,result=pcall(fn);report[ok and 'passed'or 'failed']+=1;report.cases[name]={passed=ok,result=ok and result or tostring(result)}end
local rs=Instance.new('Folder');rs.Name='ReplicatedStorage';q.Parent=rs
local ss=Instance.new('Folder');ss.Name='ServerStorage'
local scripts=Instance.new('Folder');scripts.Name='ServerScriptService'
local starter=Instance.new('Folder');starter.Name='StarterPlayer'
local playerscripts=Instance.new('StarterPlayerScripts');playerscripts.Parent=starter
local server=Instance.new('Folder');server.Name='KingdomsServer';server.Parent=scripts
local client=Instance.new('Folder');client.Name='KingdomsClient';client.Parent=playerscripts
for _,item in {{server,'Script','Server'},{client,'LocalScript','Client'}}do local s=Instance.new(item[2]);s.Name=item[3];s.Disabled=false;s.Parent=item[1]end
services.ReplicatedStorage=rs;services.ServerStorage=ss;services.ServerScriptService=scripts;services.StarterPlayer=starter
local running=false;services.RunService.IsRunning=function()return running end
local setup=Instance.new('Model');setup.Name='KingdomsMeshSetup';setup.Parent=workspace
local runtime=Instance.new('Folder');runtime.Name='Runtime';runtime.Parent=setup
for _,source in q:GetChildren()do if source:IsA('ModuleScript')then source:Clone().Parent=runtime end end
for _,item in {{'Script','Server'},{'LocalScript','Client'}}do local s=Instance.new(item[1]);s.Name=item[2];s.Disabled=true;s.Parent=runtime end
local module=Instance.new('ModuleScript');module.Name='Installer';module.Parent=setup
local Installer=require(module)
local catalogue=Instance.new('Model');catalogue.Name='KingdomsMeshCatalogue';catalogue.Parent=workspace
local imported={}
for _,template in q.MeshTemplates:GetChildren()do local part=template:Clone();part.Parent=catalogue;imported[part.Name]=part end
local total=#catalogue:GetChildren()
local function untouched()assert(q.Parent==rs and server.Parent==scripts and client.Parent==playerscripts and #ss:GetChildren()==0)end

test('Installer refuses to mutate a running match',function()
    running=true;assert(not pcall(Installer.Install));running=false;untouched();return true
end)
test('An incomplete import leaves every existing game root untouched',function()
    local part=imported.Castle_Base;part.Parent=nil
    assert(not pcall(Installer.Install));untouched();part.Parent=catalogue;return true
end)
test('An unuploaded mesh cannot be installed as a working asset',function()
    local part=imported.Castle_Base;local previous=part.MeshId;part.MeshId=''
    assert(not pcall(Installer.Install));untouched();part.MeshId=previous;return true
end)
test('Duplicate imported names are rejected before any replacement',function()
    local duplicate=imported.Castle_Base:Clone();duplicate.Parent=catalogue
    assert(not pcall(Installer.Install));untouched();duplicate:Destroy();return true
end)
test('A staging failure preserves original scripts and imported meshes',function()
    local source=runtime.Config;source.Clone=function()error('Simulated copy failure')end
    assert(not pcall(Installer.Install));untouched()
    source.Clone=nil;assert(#catalogue:GetChildren()==total and setup.Parent==workspace);return true
end)
test('A replacement failure restores roots already moved into the backup',function()
    local previous=nodeMeta.__newindex
    nodeMeta.__newindex=function(self,key,value)
        if key=='Parent'and value==rs and self.Name=='Kingdoms'and self~=q then error('Simulated replacement failure')end
        return previous(self,key,value)
    end
    local ok=pcall(Installer.Install)
    nodeMeta.__newindex=previous
    assert(not ok);untouched()
    assert(#rs:GetChildren()==1 and catalogue.Parent==workspace and setup.Parent==workspace)
    assert(not server.Server.Disabled and not client.Client.Disabled);return true
end)
test('Complete installation preserves asset IDs, joints, backups and game roots',function()
    local result=Installer.Install()
    local installed=rs.Kingdoms
    assert(result.Models==total and installed~=q and not installed:FindFirstChild('Geometry'))
    assert(#installed.MeshTemplates:GetChildren()==total and installed.MeshTemplates:GetAttribute('Complete'))
    for name,source in imported do
        local part=installed.MeshTemplates[name]
        assert(part.MeshId==source.MeshId and part:GetAttribute('MeshKey')==name)
        assert(part:GetAttribute('Joint')and part:GetAttribute('Center')and part.Anchored and not part.CanQuery)
    end
    local backup=ss[result.Backup]
    assert(q.Parent==backup and server.Parent==backup and client.Parent==backup)
    assert(catalogue.Parent==backup and setup.Parent==backup)
    assert(server.Server.Disabled and client.Client.Disabled)
    assert(server.Server:GetAttribute('DisabledBeforeMeshImport')==false and client.Client:GetAttribute('DisabledBeforeMeshImport')==false)
    assert(not scripts.KingdomsServer.Server.Disabled and not playerscripts.KingdomsClient.Client.Disabled)
    assert(installed:FindFirstChild('MeshCatalog')and installed:FindFirstChild('Art'))
    return true
end)
return report
