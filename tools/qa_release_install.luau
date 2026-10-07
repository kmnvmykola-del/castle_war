local report={passed=0,failed=0,cases={}}
local function test(name,fn)local ok,result=pcall(fn);report[ok and 'passed'or 'failed']+=1;report.cases[name]={passed=ok,result=ok and result or tostring(result)}end
local rs=Instance.new('Folder');root.Parent=rs
local ss=Instance.new('Folder');local scripts=Instance.new('Folder');local starter=Instance.new('Folder')
local ps=Instance.new('StarterPlayerScripts');ps.Parent=starter
services.ReplicatedStorage=rs;services.ServerStorage=ss;services.ServerScriptService=scripts;services.StarterPlayer=starter
root.MeshTemplates:SetAttribute('Complete',true)
local mesh=root.MeshTemplates;local original=root.Config
local serverFolder=Instance.new('Folder');serverFolder.Name='KingdomsServer';serverFolder.Parent=scripts
local clientFolder=Instance.new('Folder');clientFolder.Name='KingdomsClient';clientFolder.Parent=ps
local s=Instance.new('Script');s.Name='Server';s.Disabled=false;s.Parent=serverFolder
local c=Instance.new('LocalScript');c.Name='Client';c.Disabled=false;c.Parent=clientFolder
local setup=Instance.new('Model');setup.Name='KingdomsReleaseSetup';setup.Parent=workspace
local runtime=Instance.new('Folder');runtime.Name='Runtime';runtime.Parent=setup
for _,source in root:GetChildren()do if source:IsA('ModuleScript')then source:Clone().Parent=runtime end end
for _,item in {{'Script','Server'},{'LocalScript','Client'}}do local source=Instance.new(item[1]);source.Name=item[2];source.Disabled=true;source.Parent=runtime end
local mod=Instance.new('ModuleScript');mod.Name='ReleaseInstaller';mod.Parent=setup
local Installer=require(mod)
local running=false;services.RunService.IsRunning=function()return running end
local function untouched()assert(root.Parent==rs and root.Config==original and root.MeshTemplates==mesh and s.Parent==serverFolder and c.Parent==clientFolder and not s.Disabled and not c.Disabled and #ss:GetChildren()==0 and setup.Parent==workspace)end
test('Release update refuses an active match',function()running=true;assert(not pcall(Installer.Install));running=false;untouched();return true end)
test('Release staging failures preserve all active sources and meshes',function()
    runtime.Config.Clone=function()error('Simulated source clone failure')end
    local ok,reason=pcall(Installer.Install);runtime.Config.Clone=nil
    assert(not ok and tostring(reason):find('Simulated source clone failure',1,true));untouched();return true
end)
test('Release commit failure restores moved modules and executable state',function()
    local previous=nodeMeta.__newindex
    nodeMeta.__newindex=function(self,key,value)
        if key=='Parent'and value==root and self.Name=='Config'and self~=original then error('Simulated release commit failure')end
        return previous(self,key,value)
    end
    local ok,reason=pcall(Installer.Install);nodeMeta.__newindex=previous
    assert(not ok and tostring(reason):find('Simulated release commit failure',1,true));untouched();return true
end)
test('Release installs current sources without replacing uploaded meshes',function()
    Installer.Install()
    assert(root.MeshTemplates==mesh and root.Config~=original and root.BattleGuide)
    assert(root:GetAttribute('ReleaseVersion')=='0.15')
    assert(serverFolder.Server~=s and clientFolder.Client~=c and not serverFolder.Server.Disabled and not clientFolder.Client.Disabled)
    local backup=ss:GetChildren()[1];assert(backup and original.Parent==backup and s.Parent==backup and c.Parent==backup and setup.Parent==backup)
    assert(s.Disabled and c.Disabled);return true
end)
return report
