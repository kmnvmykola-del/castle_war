-- Test-only imported assets, never written into the deliverable place.
local meshCatalog=require(root.MeshCatalog)
local meshTemplates=Instance.new('Folder');meshTemplates.Name='MeshTemplates';meshTemplates.Parent=root
meshTemplates:SetAttribute('CatalogSignature',meshCatalog.Signature);meshTemplates:SetAttribute('Complete',true)
local fixtureId=0
for name,data in meshCatalog.Models do
    local names={name};if data.Team then table.insert(names,name..'__Blue');table.insert(names,name..'__Red')end
    if data.Neutral then table.insert(names,name..'__Neutral')end
    for _,key in names do
        fixtureId+=1
        local mesh=Instance.new('MeshPart');mesh.Name=key;mesh.MeshId='rbxassetid://'..fixtureId
        local function vector(v)return Vector3.new(v[1],v[2],v[3])end
        mesh.Size=vector(data.Maximum)-vector(data.Minimum);mesh.CFrame=CFrame.identity;mesh.Color=Color3.new(1,1,1)
        mesh.Anchored=true;mesh.CanCollide=false;mesh.CanTouch=false;mesh.CanQuery=false
        mesh:SetAttribute('Center',(vector(data.Maximum)+vector(data.Minimum))/2)
        mesh:SetAttribute('Minimum',vector(data.Minimum));mesh:SetAttribute('Maximum',vector(data.Maximum))
        mesh:SetAttribute('Joint',vector(data.Joint));mesh:SetAttribute('Tint',data.Tint)
        mesh:SetAttribute('MeshKey',key);mesh:SetAttribute('MeshRotation',CFrame.identity);mesh.Parent=meshTemplates
    end
end
services.AssetService={
    CreateEditableMesh=function()error('The published game must not generate geometry')end,
    CreateEditableMeshAsync=function()error('The published game must not generate geometry')end,
    CreateMeshPartAsync=function()error('The published game must clone imported MeshParts')end,
}
