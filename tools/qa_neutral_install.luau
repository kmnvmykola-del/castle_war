local q=root
local rs=Instance.new('Folder');rs.Name='ReplicatedStorage';q.Parent=rs;services.ReplicatedStorage=rs
local report={passed=0,failed=0,cases={}}
local function test(name,fn)local ok,result=pcall(fn);report[ok and 'passed'or 'failed']+=1;report.cases[name]={passed=ok,result=ok and result or tostring(result)}end
local ss=Instance.new('Folder');services.ServerStorage=ss
local setup=Instance.new('Model');setup.Name='KingdomsNeutralSetup';setup.Parent=workspace
local runtime=Instance.new('Folder');runtime.Name='Runtime';runtime.Parent=setup
for _,name in {'Art','MeshCatalog'}do q[name]:Clone().Parent=runtime end
local module=Instance.new('ModuleScript');module.Name='NeutralInstaller';module.Parent=setup
local installer=require(module)
local catalogue=Instance.new('Model');catalogue.Name='KingdomsMeshCatalogue';catalogue.Parent=workspace
local templates=q.MeshTemplates;local originals={};local imported={}
for _,part in templates:GetChildren()do
    if part.Name:match('__Neutral$')then part.Parent=catalogue;imported[part.Name]=part
    else originals[part.Name]=part end
end
local previousSignature='previous-installed-catalogue'
templates:SetAttribute('CatalogSignature',previousSignature);templates:SetAttribute('MeshCount',#templates:GetChildren())
local oldArt=q.Art;local oldCatalog=q.MeshCatalog
local function untouched()
    assert(q.Art==oldArt and q.MeshCatalog==oldCatalog and #ss:GetChildren()==0)
    assert(templates:GetAttribute('CatalogSignature')==previousSignature)
    for name,part in originals do assert(templates[name]==part)end
    for name in imported do assert(not templates:FindFirstChild(name))end
end
local running=false;services.RunService.IsRunning=function()return running end
test('Neutral repair rejects a running match and incomplete imports',function()
    running=true;assert(not pcall(installer.Install));running=false;untouched()
    local name,part=next(imported);part.Parent=nil;assert(not pcall(installer.Install));part.Parent=catalogue;untouched();return true
end)
test('Neutral repair validates new and previously uploaded asset IDs',function()
    local _,part=next(imported);local id=part.MeshId;part.MeshId='';assert(not pcall(installer.Install));part.MeshId=id;untouched()
    local original=originals.Castle_Base;local previous=original.MeshId;original.MeshId='';assert(not pcall(installer.Install));original.MeshId=previous;untouched();return true
end)
test('Neutral repair rolls back a partial module replacement',function()
    local previous=nodeMeta.__newindex
    nodeMeta.__newindex=function(self,key,value)
        if key=='Parent'and value==q and self.Name=='MeshCatalog'and self~=oldCatalog then error('Simulated replacement failure')end
        return previous(self,key,value)
    end
    local ok=pcall(installer.Install);nodeMeta.__newindex=previous;assert(not ok);untouched();return true
end)
test('Neutral repair preserves every existing mesh instance and ID and archives old modules',function()
    local result=installer.Install();local newCount=0
    for name,part in originals do assert(templates[name]==part and templates[name].MeshId==part.MeshId)end
    for name,part in imported do newCount+=1;assert(templates[name].MeshId==part.MeshId and templates[name]:GetAttribute('MeshKey')==name)end
    assert(result.Added==newCount and result.Models==#templates:GetChildren())
    assert(templates:GetAttribute('CatalogSignature')==require(runtime.MeshCatalog).Signature)
    assert(templates:GetAttribute('MeshCount')==result.Models and templates:GetAttribute('Complete'))
    local backup=ss[result.Backup];assert(oldArt.Parent==backup and oldCatalog.Parent==backup)
    assert(setup.Parent==backup and catalogue.Parent==backup and q.Art~=oldArt and q.MeshCatalog~=oldCatalog)
    return true
end)
return report
