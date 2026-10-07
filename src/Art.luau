-- Ordinary uploaded MeshParts; geometry is never generated during gameplay.
local Styles=require(script.Parent.SkinStyles)
local Catalog=require(script.Parent.MeshCatalog)
local Config=require(script.Parent.Config)
local Art={Cache={},Modules=Catalog.Models,Clones={},BoundsCache={}}
local function vector(v)return Vector3.new(v[1],v[2],v[3])end
-- glTF import changes the handedness of Z; retain authored pivots and origins.
local function importedOffset(v)return Vector3.new(v.X,v.Y,-v.Z)end
local function hex(s)return Color3.fromRGB(tonumber(s:sub(2,3),16),tonumber(s:sub(4,5),16),tonumber(s:sub(6,7),16))end
function Art.Prepare()
    local templates=script.Parent:FindFirstChild('MeshTemplates')
    assert(templates and templates:GetAttribute('CatalogSignature')==Catalog.Signature and templates:GetAttribute('Complete')==true,
        'Imported models are not installed. Run KingdomsMeshSetup.Installer in Studio before publishing.')
    Art.Templates=templates
end
function Art.TeamKey(name,color)
    if not Catalog.Models[name].Team then return name end
    for i,label in {'Blue','Red','Neutral'}do
        local team=Config.Colors[i]
        if (i<3 or Catalog.Models[name].Neutral)and math.abs(color.R-team.R)<.0001 and math.abs(color.G-team.G)<.0001 and math.abs(color.B-team.B)<.0001 then return name..'__'..label end
    end
    error('Unsupported army team colour for '..name)
end
function Art.Ensure(name,skin,teamColor,unitSkin)
    local data=Catalog.Models[name];assert(data,'Missing model metadata: '..name)
    local key=unitSkin and teamColor and Art.TeamKey(name,teamColor)or name
    if Art.Cache[key]then return Art.Cache[key]end
    if not Art.Templates then Art.Prepare()end
    local part=Art.Templates:FindFirstChild(key)
    assert(part and part:IsA('MeshPart'),'Missing imported model: '..key)
    assert(part.MeshId~='','Mesh has not been uploaded: '..key)
    Art.Cache[key]=part;Art.Clones[key]={}
    return part
end
function Art.Bounds(name)
    if Art.BoundsCache[name]then return Art.BoundsCache[name]end
    local data=Catalog.Models[name];assert(data,'Missing model metadata: '..name)
    local low,high=vector(data.Minimum),vector(data.Maximum)
    local result={Minimum=Vector3.new(low.X,low.Y,-high.Z),Maximum=Vector3.new(high.X,high.Y,-low.Z)}
    Art.BoundsCache[name]=result;return result
end
function Art.Prune()
    -- Templates stay intact; Roblox shares their uploaded meshes across clones.
    for key in Art.Cache do
        local used=false
        for clone in Art.Clones[key]or {}do
            if clone.Parent then used=true else Art.Clones[key][clone]=nil end
        end
        if not used then Art.Cache[key]=nil;Art.Clones[key]=nil end
    end
end
function Art.Clone(name,parent,root,teamColor,skin,unitSkin)
    local template=Art.Ensure(name,skin,teamColor,unitSkin)
    local part=template:Clone();local key=template.Name
    Art.Clones[key][part]=true
    part:SetAttribute('Center',importedOffset(part:GetAttribute('Center')))
    part:SetAttribute('Joint',importedOffset(part:GetAttribute('Joint')))
    part.CFrame=(root or CFrame.identity)*CFrame.new(part:GetAttribute('Joint')+part:GetAttribute('Center'))*(part:GetAttribute('MeshRotation')or CFrame.identity)
    if teamColor and part:GetAttribute('Tint')then part.Color=teamColor end
    if skin and skin~='Default'and not name:match('^'..skin..'_')then part.Color=hex(Styles.Get(skin).Cloth):Lerp(Color3.new(1,1,1),.45)end
    part.Name=name;part.Parent=parent
    return part
end
function Art.Unit(kind,parent,color,skin)
    local model=Instance.new('Model');model.Name=kind
    local ok,reason=pcall(function()
        for _,limb in {'Torso','Head','LeftArm','RightArm','LeftLeg','RightLeg'}do
            local prefix=skin and skin~='Default'and skin..'_'or ''
            local name=prefix..kind..'_'..limb
            if not Art.Modules[name]then name=kind..'_'..limb end
            local part=Art.Clone(name,model,CFrame.identity,color,nil,skin or 'Default');part.Name=limb
        end
        local badgeName=(skin and skin~='Default'and skin..'_'or '')..kind..'_Insignia'
        if Art.Modules[badgeName]then local badge=Art.Clone(badgeName,model,CFrame.identity,color);badge.Name='Insignia'end
    end)
    if not ok then model:Destroy();Art.Prune();error(reason)end
    model.Parent=parent;return model
end
function Art.Pose(model,root,phase,moving,attacking)
    -- Studio's imported characters face -Z, the direction of CFrame.lookAt.
    for _,part in model:GetChildren()do
        if not part:IsA('BasePart')then continue end
        local angle=0
        if moving then
            if part.Name=='LeftLeg'or part.Name=='RightArm'then angle=math.sin(phase)*.38
            elseif part.Name=='RightLeg'or part.Name=='LeftArm'then angle=-math.sin(phase)*.38 end
        end
        if attacking and part.Name=='RightArm'then angle=-1.1+math.sin(phase*2)*.5 end
        part.CFrame=root*CFrame.new(part:GetAttribute('Joint'))*CFrame.Angles(angle,0,0)*CFrame.new(part:GetAttribute('Center'))*(part:GetAttribute('MeshRotation')or CFrame.identity)
    end
end
return Art
