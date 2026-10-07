-- Studio-only, atomic replacement of the three premium collections.
local Setup={}
function Setup.Install()
    assert(game:GetService('RunService'):IsStudio()and not game:GetService('RunService'):IsRunning(),'Stop Play first.')
    local rs=game:GetService('ReplicatedStorage');local ss=game:GetService('ServerStorage')
    local sss=game:GetService('ServerScriptService');local sps=game:GetService('StarterPlayer').StarterPlayerScripts
    local old={rs.Kingdoms,sss.KingdomsServer,sps.KingdomsClient};local parents={rs,sss,sps}
    local runtime=script.Parent.Runtime;local catalog=require(runtime.MeshCatalog)
    local manifest=require(script.Parent.Manifest)
    assert(old[1].MeshTemplates:GetAttribute('CatalogSignature')==manifest.BaseSignature,'Unexpected installed catalogue.')
    local changed={};for _,name in manifest.ChangedModels do changed[name]=true end
    local expected={};local count=0
    for name,data in catalog.Models do
        expected[name]={Data=data,Changed=changed[name]};count+=1
        if data.Team then for _,suffix in {'Blue','Red'}do expected[name..'__'..suffix]={Data=data,Changed=changed[name]};count+=1 end end
        if data.Neutral then expected[name..'__Neutral']={Data=data,Changed=changed[name]};count+=1 end
    end
    assert(count==manifest.MeshCount,'Catalogue count mismatch.')
    local imported={};local importedRoots={}
    for _,part in workspace:GetDescendants()do
        local record=expected[part.Name]
        if part:IsA('MeshPart')and record and record.Changed then
            assert(not imported[part.Name],'Duplicate premium mesh: '..part.Name)
            imported[part.Name]=part
            for _,skin in {'Storm','Dragon','Oracle'}do local ancestor=part:FindFirstAncestor('KingdomsPremium'..skin);if ancestor then importedRoots[ancestor]=true end end
        end
    end
    local function uploaded(part,name)
        assert(part and part:IsA('MeshPart'),'Missing uploaded mesh: '..name)
        local id=part.MeshId:match('rbxassetid://(%d+)')or part.MeshId:match('[?&]id=(%d+)')
        assert(id and tonumber(id)>0,'Premium mesh is not uploaded: '..name)
    end
    -- Validate every new upload before allocating or moving any game objects.
    for name,record in expected do
        local source
        if record.Changed then source=imported[name]else source=old[1].MeshTemplates:FindFirstChild(name)end
        uploaded(source,name);record.Source=source
    end
    local staged={};local templates=Instance.new('Folder');templates.Name='MeshTemplates'
    local function vector(v)return Vector3.new(v[1],v[2],v[3])end
    for name,record in expected do
        local source=record.Source
        local part=source:Clone();local data=record.Data
        if record.Changed then
            part.Size=vector(data.Maximum)-vector(data.Minimum)
            part:SetAttribute('Center',(vector(data.Maximum)+vector(data.Minimum))/2)
            part:SetAttribute('Minimum',vector(data.Minimum));part:SetAttribute('Maximum',vector(data.Maximum))
            part:SetAttribute('Joint',vector(data.Joint));part:SetAttribute('Tint',data.Tint)
            part:SetAttribute('MeshKey',name);part:SetAttribute('MeshRotation',source.CFrame.Rotation)
            part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
            part.Transparency=0;part.Color=Color3.new(1,1,1);part.Material=Enum.Material.SmoothPlastic;part.CFrame=CFrame.identity
        end
        part.Parent=templates
    end
    templates:SetAttribute('CatalogSignature',catalog.Signature);templates:SetAttribute('Complete',true);templates:SetAttribute('MeshCount',count)
    local ok,reason=pcall(function()
        for i,root in old do staged[i]=root:Clone()end
        staged[1].MeshTemplates:Destroy();templates.Parent=staged[1]
        for _,source in runtime:GetChildren()do
            local target=source.Name=='Server'and staged[2]or source.Name=='Client'and staged[3]or staged[1]
            local previous=target:FindFirstChild(source.Name);if previous then previous:Destroy()end
            local copy=source:Clone();if copy:IsA('Script')or copy:IsA('LocalScript')then copy.Disabled=false end;copy.Parent=target
        end
        staged[1]:SetAttribute('ReleaseVersion','0.16')
    end)
    if not ok then for _,root in staged do root:Destroy()end;templates:Destroy();error(reason)end
    local backup=Instance.new('Folder');backup.Name='KingdomsBeforePremium16_'..game:GetService('HttpService'):GenerateGUID(false);backup.Parent=ss
    local moved=false
    ok,reason=pcall(function()
        moved=true;for i,root in old do root.Parent=backup;staged[i].Parent=parents[i]end
    end)
    if not ok then
        if moved then for i,root in old do root.Parent=parents[i]end end
        for _,root in staged do root:Destroy()end;backup:Destroy();error(reason)
    end
    for _,root in old do for _,item in root:GetDescendants()do if item:IsA('Script')or item:IsA('LocalScript')then item.Disabled=true end end end
    for root in importedRoots do root.Parent=backup end
    script.Parent.Parent=backup
    print('KINGDOMS_PREMIUM16_INSTALLED',count,catalog.Signature,backup.Name)
    return {Models=count,Signature=catalog.Signature,Backup=backup.Name}
end
return Setup
