-- Studio-only incremental repair. Existing uploaded meshes keep their IDs.
local Setup={}
function Setup.Install()
    local Run=game:GetService('RunService')
    assert(Run:IsStudio()and not Run:IsRunning(),'Stop the playtest before installing models.')
    local root=game:GetService('ReplicatedStorage'):FindFirstChild('Kingdoms')
    local templates=root and root:FindFirstChild('MeshTemplates')
    assert(templates and templates:GetAttribute('Complete'),'Install the main mesh catalogue first.')
    local runtime=script.Parent.Runtime
    local catalog=require(runtime.MeshCatalog)
    local expected={};local count=0
    local function uploaded(part)
        if not part or not part:IsA('MeshPart')then return false end
        local id=part.MeshId:match('rbxassetid://(%d+)')or part.MeshId:match('[?&]id=(%d+)')
        return id and tonumber(id)>0
    end
    for name,data in catalog.Models do
        local keys={name};if data.Team then table.insert(keys,name..'__Blue');table.insert(keys,name..'__Red')end
        for _,key in keys do assert(uploaded(templates:FindFirstChild(key)),'Existing mesh missing: '..key);count+=1 end
        if data.Neutral then expected[name..'__Neutral']=data;count+=1 end
    end
    local found={};local roots={}
    for _,part in workspace:GetDescendants()do
        if part:IsA('MeshPart')and expected[part.Name]then
            assert(not found[part.Name],'Duplicate neutral mesh: '..part.Name)
            assert(not templates:FindFirstChild(part.Name),'Neutral mesh already installed: '..part.Name)
            assert(uploaded(part),'Neutral mesh not uploaded: '..part.Name)
            found[part.Name]=part
            local ancestor=part:FindFirstAncestor('KingdomsMeshCatalogue');if ancestor then roots[ancestor]=true end
        end
    end
    for key in expected do assert(found[key],'Missing neutral mesh: '..key)end
    local names={'Art','MeshCatalog'};local old={};local copies={}
    for i,name in names do old[i]=root:FindFirstChild(name);assert(old[i]and runtime:FindFirstChild(name),'Missing game module: '..name)end
    local attributes={CatalogSignature=templates:GetAttribute('CatalogSignature'),Complete=templates:GetAttribute('Complete'),MeshCount=templates:GetAttribute('MeshCount')}
    local backup=Instance.new('Folder');backup.Name='KingdomsBeforeNeutralFix_'..game:GetService('HttpService'):GenerateGUID(false)
    local stage=Instance.new('Folder');local parts={}
    local function vector(v)return Vector3.new(v[1],v[2],v[3])end
    local moved=false
    local ok,reason=pcall(function()
        for key,data in expected do
            local source=found[key];local part=source:Clone();part.Parent=stage;table.insert(parts,part)
            part.Size=vector(data.Maximum)-vector(data.Minimum)
            part:SetAttribute('Center',(vector(data.Minimum)+vector(data.Maximum))/2)
            part:SetAttribute('Minimum',vector(data.Minimum));part:SetAttribute('Maximum',vector(data.Maximum))
            part:SetAttribute('Joint',vector(data.Joint));part:SetAttribute('Tint',data.Tint)
            part:SetAttribute('MeshKey',key);part:SetAttribute('MeshRotation',source.CFrame.Rotation)
            part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
            part.Transparency=0;part.Color=Color3.new(1,1,1);part.Material=Enum.Material.SmoothPlastic;part.CFrame=CFrame.identity
        end
        for i,name in names do copies[i]=runtime[name]:Clone();copies[i].Parent=stage end
        backup.Parent=game:GetService('ServerStorage');moved=true
        for i,item in old do item.Parent=backup;copies[i].Parent=root end
        for _,part in parts do part.Parent=templates end
        templates:SetAttribute('CatalogSignature',catalog.Signature);templates:SetAttribute('Complete',true);templates:SetAttribute('MeshCount',count)
    end)
    if not ok then
        if moved then
            for _,item in old do item.Parent=root end
            for key,value in attributes do templates:SetAttribute(key,value)end
        end
        for _,copy in copies do copy:Destroy()end
        for _,part in parts do part:Destroy()end
        stage:Destroy();backup:Destroy();error(reason)
    end
    stage:Destroy()
    for ancestor in roots do ancestor.Parent=backup end
    script.Parent.Parent=backup
    print('Neutral repair installed: '..#parts..' new meshes; '..count..' total. Backup: ServerStorage.'..backup.Name)
    return {Added=#parts,Models=count,Backup=backup.Name,Signature=catalog.Signature}
end
return Setup
