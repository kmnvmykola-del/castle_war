-- Studio-only migration. Import the glTF into this experience first, then run:
-- require(workspace.KingdomsMeshSetup.Installer).Install()
local Run=game:GetService('RunService')
local Setup={}
function Setup.Install()
    assert(Run:IsStudio()and not Run:IsRunning(),'Stop the playtest before installing models.')
    local runtime=script.Parent.Runtime
    local catalog=require(runtime.MeshCatalog)
    local expected={}
    for name,data in catalog.Models do
        expected[name]=data
        if data.Team then expected[name..'__Blue']=data;expected[name..'__Red']=data end
        if data.Neutral then expected[name..'__Neutral']=data end
    end
    local found={};local roots={}
    for _,part in workspace:GetDescendants()do
        if part:IsA('MeshPart')and expected[part.Name]then
            assert(not found[part.Name],'Duplicate imported mesh: '..part.Name..'. Keep only one imported catalogue in Workspace.')
            found[part.Name]=part
            local root=part:FindFirstAncestor('KingdomsMeshCatalogue')
            if root then roots[root]=true end
        end
    end
    local missing={};local count=0
    for name in expected do
        local part=found[name]
        if not part then table.insert(missing,name)
        else
            local id=part.MeshId:match('rbxassetid://(%d+)')or part.MeshId:match('[?&]id=(%d+)')
            assert(id and tonumber(id)>0,'Mesh is not uploaded: '..name..'. Import with Upload to Roblox enabled.')
            count+=1
        end
    end
    table.sort(missing)
    assert(#missing==0,'Import the complete KingdomsMeshCatalogue.gltf first. Missing '..#missing..' mesh(es), starting with '..tostring(missing[1]))
    local RS=game:GetService('ReplicatedStorage')
    local SS=game:GetService('ServerStorage')
    local scripts=game:GetService('ServerScriptService')
    local starter=game:GetService('StarterPlayer'):FindFirstChildOfClass('StarterPlayerScripts')
    local old={RS:FindFirstChild('Kingdoms'),scripts:FindFirstChild('KingdomsServer'),starter and starter:FindFirstChild('KingdomsClient')}
    assert(old[1]and old[2]and old[3],'Open the existing Frontier Kingdoms experience before installing.')
    local templates=Instance.new('Folder');templates.Name='MeshTemplates'
    local function vector(v)return Vector3.new(v[1],v[2],v[3])end
    local staged={}
    local backup=Instance.new('Folder');backup.Name='KingdomsBeforeMeshImport_'..game:GetService('HttpService'):GenerateGUID(false)
    local parents={RS,scripts,starter}
    local moved=false
    local ok,reason=pcall(function()
        for name,data in expected do
            local source=found[name]
            local part=source:Clone()
            -- Mesh data and asset IDs are retained; placement/scale come from
            -- the authored catalogue, independent of the import scene position.
            part.Size=vector(data.Maximum)-vector(data.Minimum)
            part:SetAttribute('Center',(vector(data.Minimum)+vector(data.Maximum))/2)
            part:SetAttribute('Minimum',vector(data.Minimum));part:SetAttribute('Maximum',vector(data.Maximum))
            part:SetAttribute('Joint',vector(data.Joint));part:SetAttribute('Tint',data.Tint)
            part:SetAttribute('MeshKey',name);part:SetAttribute('MeshRotation',source.CFrame.Rotation)
            part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
            part.Transparency=0;part.Color=Color3.new(1,1,1);part.Material=Enum.Material.SmoothPlastic
            part.CFrame=CFrame.identity;part.Parent=templates
        end
        templates:SetAttribute('CatalogSignature',catalog.Signature)
        templates:SetAttribute('Complete',true);templates:SetAttribute('MeshCount',count)
        for i,root in old do staged[i]=root:Clone()end
        local geometry=staged[1]:FindFirstChild('Geometry');if geometry then geometry:Destroy()end
        local previous=staged[1]:FindFirstChild('MeshTemplates');if previous then previous:Destroy()end
        templates.Parent=staged[1]
        for _,source in runtime:GetChildren()do
            local dest=source:IsA('ModuleScript')and staged[1]or source.Name=='Server'and staged[2]or staged[3]
            local previous=dest:FindFirstChild(source.Name);if previous then previous:Destroy()end
            local copy=source:Clone()
            if copy:IsA('Script')or copy:IsA('LocalScript')then copy.Disabled=false end
            copy.Parent=dest
        end
        -- All validation and staging finish before the existing roots move.
        backup.Parent=SS;moved=true
        for i,root in old do root.Parent=backup;staged[i].Parent=parents[i]end
    end)
    if not ok then
        if moved then for i,root in old do root.Parent=parents[i]end end
        for _,root in staged do root:Destroy()end
        if not templates.Parent then templates:Destroy()end
        backup:Destroy();error(reason)
    end
    for _,root in old do for _,item in root:GetDescendants()do
        if item:IsA('Script')or item:IsA('LocalScript')then
            item:SetAttribute('DisabledBeforeMeshImport',item.Disabled);item.Disabled=true
        end
    end end
    for root in roots do if root:IsDescendantOf(workspace)then root.Parent=backup end end
    script.Parent.Parent=backup
    print('Installed '..count..' ordinary MeshParts. Backup: ServerStorage.'..backup.Name..'. Press F5 to test, then Publish to Roblox.')
    return {Models=count,Backup=backup.Name,Signature=catalog.Signature}
end
return Setup
