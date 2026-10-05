-- Geometry was authored and exported by tools/build_models.py in Blender.
local AS=game:GetService('AssetService')
local Styles=require(script.Parent.SkinStyles)
local Art={Cache={},Editable={},Modules={},Loading={},Clones={},BoundsCache={}}
local function vector(v) return Vector3.new(v[1],v[2],v[3]) end
local function hex(s)return Color3.fromRGB(tonumber(s:sub(2,3),16),tonumber(s:sub(4,5),16),tonumber(s:sub(6,7),16))end
local function recolor(c,skin)
    if not skin or skin=='Default'then return Color3.new(c[1],c[2],c[3])end
    local style=Styles.Get(skin);local cloth,armor,trim=hex(style.Cloth),hex(style.Armor),hex(style.Trim)
    local function same(r,g,b)return math.abs(c[1]-r)<.0002 and math.abs(c[2]-g)<.0002 and math.abs(c[3]-b)<.0002 end
    if same(.48,.20,.13)or same(.27,.41,.22)then return cloth
    elseif same(.64,.31,.19)then return cloth:Lerp(Color3.new(1,1,1),.18)
    elseif same(.29,.11,.08)then return cloth:Lerp(Color3.new(0,0,0),.32)
    elseif same(.87,.80,.62)then return armor:Lerp(Color3.fromRGB(245,235,213),.65)
    elseif same(.58,.56,.49)then return armor:Lerp(Color3.new(1,1,1),.22)
    elseif same(.76,.72,.61)then return armor:Lerp(Color3.new(1,1,1),.50)
    elseif same(.32,.33,.31)then return armor:Lerp(Color3.new(0,0,0),.42)
    elseif same(.78,.57,.23)or same(.73,.55,.22)then return trim end
    return Color3.new(c[1],c[2],c[3])
end
function Art.Ensure(name,skin)
    -- Structural geometry is shared by all building themes. Per-instance tint
    -- and the authored herald/roof ornaments provide the cosmetic appearance.
    skin=nil
    local key=name
    while Art.Loading[key]do task.wait()end
    if Art.Cache[key]then return Art.Cache[key]end
    local module=Art.Modules[name]or script.Parent.Geometry:FindFirstChild(name);assert(module,'Нет модели '..name)
    Art.Prune()
    Art.Loading[key]=true
    local editable,fixed
    local ok,result=pcall(function()
        local data=require(module)
        editable=AS:CreateEditableMesh()
        assert(editable,'Недостаточно памяти для меша '..data.Name)
        local vertices,colors={},{}
        local minimum,maximum=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
        for _,p in data.Vertices do
            local v=vector(p)
            minimum=minimum:Min(v);maximum=maximum:Max(v)
        end
        local center=(minimum+maximum)/2
        for i,p in data.Vertices do vertices[i]=editable:AddVertex(vector(p)-center) end
        for i,c in data.Palette do colors[i]=editable:AddColor(recolor(c,skin),1) end
        local normals={}
        for _,f in data.Faces do
            local face=editable:AddTriangle(vertices[f[1]+1],vertices[f[2]+1],vertices[f[3]+1])
            local color=colors[f[4]]
            editable:SetFaceColors(face,{color,color,color})
            local a,b,c=vector(data.Vertices[f[1]+1]),vector(data.Vertices[f[2]+1]),vector(data.Vertices[f[3]+1])
            local n=(b-a):Cross(c-a);n=n.Magnitude>0 and n.Unit or Vector3.yAxis
            local normalKey=string.format('%.4f:%.4f:%.4f',n.X,n.Y,n.Z)
            local normal=normals[normalKey]
            if not normal then normal=editable:AddNormal(n);normals[normalKey]=normal end
            editable:SetFaceNormals(face,{normal,normal,normal})
        end
        -- Keep compact fixed topology; dynamic meshes reserve a large memory pool.
        fixed=AS:CreateEditableMeshAsync(Content.fromObject(editable),{FixedSize=true})
        assert(fixed,'Недостаточно памяти для модели '..data.Name)
        editable:Destroy();editable=nil
        local part=AS:CreateMeshPartAsync(Content.fromObject(fixed))
        part.Name=data.Name
        part.Anchored=true
        part.CanCollide=false
        part.CanTouch=false
        part.CanQuery=false
        part.Material=Enum.Material.SmoothPlastic
        part.Color=Color3.new(1,1,1)
        part:SetAttribute('Center',center)
        part:SetAttribute('Minimum',minimum)
        part:SetAttribute('Maximum',maximum)
        part:SetAttribute('Joint',vector(data.Joint))
        part:SetAttribute('Tint',data.Tint)
        Art.Cache[key]=part
        Art.Editable[key]=fixed;Art.Clones[key]={}
        return part
    end)
    Art.Loading[key]=nil
    if not ok then if editable then editable:Destroy()end;if fixed then fixed:Destroy()end;error(result)end
    return result
end
function Art.Bounds(name)
    if Art.BoundsCache[name]then return Art.BoundsCache[name]end
    local data=require(Art.Modules[name]or script.Parent.Geometry[name])
    local low,high=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
    for _,v in data.Vertices do local p=vector(v);low=low:Min(p);high=high:Max(p)end
    local result={Minimum=low,Maximum=high};Art.BoundsCache[name]=result;return result
end
function Art.Prune()
    for key,part in Art.Cache do
        local used=false
        for clone in Art.Clones[key]or {}do
            if clone.Parent then used=true else Art.Clones[key][clone]=nil end
        end
        if not used and not Art.Loading[key]then part:Destroy();Art.Cache[key]=nil;Art.Editable[key]:Destroy();Art.Editable[key]=nil;Art.Clones[key]=nil end
    end
end
function Art.Prepare()
    if next(Art.Modules)then return end
    for _,module in script.Parent.Geometry:GetChildren()do Art.Modules[module.Name]=module end
    -- The complete catalogue is indexed; geometry is allocated only when visible.
end
function Art.Clone(name,parent,root,teamColor,skin)
    local part=Art.Ensure(name,skin):Clone()
    local key=name
    Art.Clones[key][part]=true
    part.CFrame=(root or CFrame.identity)*CFrame.new(part:GetAttribute('Joint')+part:GetAttribute('Center'))
    if teamColor and part:GetAttribute('Tint') then part.Color=teamColor end
    if skin and skin~='Default'then part.Color=hex(Styles.Get(skin).Cloth):Lerp(Color3.new(1,1,1),.45)end
    part.Parent=parent
    return part
end
function Art.Unit(kind,parent,color,skin)
    local model=Instance.new('Model')
    model.Name=kind
    local ok,reason=pcall(function()
    for _,limb in {'Torso','Head','LeftArm','RightArm','LeftLeg','RightLeg'} do
        local prefix=skin and skin~='Default'and skin..'_'or ''
        local name=prefix..kind..'_'..limb
        if not Art.Modules[name]then name=kind..'_'..limb end
        local part=Art.Clone(name,model,CFrame.identity,color)
        part.Name=limb
    end
    local badgeName=(skin and skin~='Default'and skin..'_'or '')..kind..'_Insignia'
    if Art.Modules[badgeName]then local badge=Art.Clone(badgeName,model,CFrame.identity,color);badge.Name='Insignia'end
    end)
    if not ok then model:Destroy();Art.Prune();error(reason)end
    model.Parent=parent
    return model
end
function Art.Pose(model,root,phase,moving,attacking)
    root*=CFrame.Angles(0,math.pi,0)
    for _,part in model:GetChildren() do
        if not part:IsA('BasePart') then continue end
        local angle=0
        if moving then
            if part.Name=='LeftLeg' or part.Name=='RightArm' then angle=math.sin(phase)*.38
            elseif part.Name=='RightLeg' or part.Name=='LeftArm' then angle=-math.sin(phase)*.38 end
        end
        if attacking and part.Name=='RightArm' then angle=-1.1+math.sin(phase*2)*.5 end
        part.CFrame=root*CFrame.new(part:GetAttribute('Joint'))*CFrame.Angles(angle,0,0)*CFrame.new(part:GetAttribute('Center'))
    end
end
return Art
