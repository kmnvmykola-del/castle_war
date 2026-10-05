local Config=require(script.Parent.Config)
local Map=require(script.Parent.MapData)
local Art=require(script.Parent.Art)
local RoadCosmetics=require(script.Parent.RoadCosmetics)
local Scene={}
local function part(parent,name,size,cf,color,material)
    local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Parent=parent;return p
end
function Scene.Build(parent,activeMap,viewerSide)
    activeMap=activeMap or Map;Art.Prepare()
    for _,p in parent:GetChildren() do
        if p:IsA('SpawnLocation') or p.Name=='Baseplate' and p:IsA('BasePart') then
            p.Transparency=1;p.CanCollide=false;p.CanQuery=false
            for _,d in p:GetDescendants() do if d:IsA('Decal') or d:IsA('Texture') then d.Transparency=1 end end
        end
    end
    local old=parent:FindFirstChild('KingdomsScene');if old then old:Destroy() end
    Art.Prune()
    local folder=Instance.new('Folder');folder.Name='KingdomsScene';folder.Parent=parent
    local grid=Instance.new('Folder');grid.Name='Сетка';grid.Parent=folder
    local h=activeMap.CellSize/2;local b=activeMap.Bounds
    local extent=(b.MaxX+.5)*activeMap.CellSize;local depth=(b.MaxZ-b.MinZ+1)*activeMap.CellSize
    if activeMap.River then for _,side in {-1,1} do
        part(folder,'Берег',Vector3.new(extent-h,3,depth),CFrame.new(side*(extent+h)/2,-1.5,0),Color3.fromRGB(120,147,92),Enum.Material.Grass)
    end
    local water=part(folder,'Река',Vector3.new(activeMap.CellSize,.15,depth),CFrame.new(0,-.12,0),Color3.fromRGB(77,143,164),Enum.Material.Glass);water.Transparency=.12
    else part(folder,'Равнина',Vector3.new(extent*2,3,depth),CFrame.new(0,-1.5,0),Color3.fromRGB(120,147,92),Enum.Material.Grass)end
    for x=b.MinX,b.MaxX do for z=b.MinZ,b.MaxZ do
        if activeMap.River and x==0 then continue end
        local shade=(x+z)%2==0 and Color3.fromRGB(149,170,121) or Color3.fromRGB(130,154,107)
        local tile=part(grid,'Клетка',Vector3.new(activeMap.CellSize-.35,.025,activeMap.CellSize-.35),CFrame.new(x*32,.017,z*32),shade)
        tile:SetAttribute('CellX',x);tile:SetAttribute('CellZ',z);tile.Transparency=1
    end end
    local roads=Instance.new('Folder');roads.Name='Дороги';roads.Parent=folder
    local roadRecords={}
    for index,edge in activeMap.Edges do
        local a,c=activeMap.GraphPoints[edge[1]],activeMap.GraphPoints[edge[2]]
        local center=(a+c)/2+Vector3.new(0,.075,0)
        local road=part(roads,'Дорога',Vector3.new(4.6,.12,(a-c).Magnitude+.08),CFrame.lookAt(center,c+Vector3.new(0,.075,0)),Color3.fromRGB(202,183,137),Enum.Material.Sand)
        road:SetAttribute('From',edge[1]);road:SetAttribute('To',edge[2])
        roadRecords[index]={Base=road,Edge=edge,A=a,B=c,Parts={},Skin=nil}
    end
    for _,p in activeMap.GraphPoints do
        part(roads,'Перекрёсток',Vector3.new(4.6,.12,4.6),CFrame.new(p.X,.075,p.Z),Color3.fromRGB(202,183,137),Enum.Material.Sand)
    end
    for _,bridge in activeMap.Bridges do
        Art.Clone('Bridge',folder,CFrame.new(bridge.Position.X,-.1,bridge.Position.Z))
        local gate=part(folder,'Переправа',Vector3.new(1.1,4.2,7),CFrame.new(bridge.Position.X,2,bridge.Position.Z),Color3.fromRGB(83,53,32),Enum.Material.WoodPlanks);gate:SetAttribute('Gate',true)
    end
    local nodes={}
    for _,site in activeMap.Sites do
        local model=Instance.new('Model');model.Name=site.Id;model:SetAttribute('SiteId',site.Id);model.Parent=folder
        local foundation=part(model,'Площадка',Vector3.new(27,.16,27),CFrame.new(site.Position.X,.035,site.Position.Z),Color3.fromRGB(157,157,128),Enum.Material.Cobblestone)
        local teamColor=Config.TeamColor(site.Owner,viewerSide)
        local borders={}
        for _,edge in {{0,-13.15,27,.7},{0,13.15,27,.7},{-13.15,0,.7,27},{13.15,0,.7,27}}do
            table.insert(borders,part(model,'Сторона',Vector3.new(edge[3],.06,edge[4]),CFrame.new(site.Position.X+edge[1],.145,site.Position.Z+edge[2]),teamColor))
        end
        foundation.Color=Color3.fromRGB(157,157,140):Lerp(teamColor,.18)
        local base=Art.Bounds(site.Kind..'_Base');local ground=.115-base.Minimum.Y
        local root=CFrame.new(site.Position.X,ground,site.Position.Z)
        local pick=part(model,'Выбор',Vector3.new(29,Config.Buildings[site.Kind].Height,29),CFrame.new(site.Position.X,Config.Buildings[site.Kind].Height/2,site.Position.Z),Color3.new(1,1,1))
        pick.Transparency=1;pick.CanQuery=true;pick:SetAttribute('SiteId',site.Id);model.PrimaryPart=pick
        local pieces,roots,heights={},{},{}
        for level=1,3 do
            local name=site.Kind..(level==1 and '_Base' or '_Upgrade'..level)
            local template=Art.Bounds(name);local min,max=template.Minimum,template.Maximum
            roots[level]=CFrame.new(site.Position.X,.115-min.Y,site.Position.Z);heights[level]=.115+max.Y-min.Y
            if level==1 then local mesh=Art.Clone(name,model,roots[level]);mesh:SetAttribute('RequiredLevel',level);table.insert(pieces,mesh)end
        end
        pick.Size=Vector3.new(29,heights[3]+4,29);pick.CFrame=CFrame.new(site.Position.X,(heights[3]+4)/2,site.Position.Z)
        local ruins=site.Kind=='Tower' and Art.Clone('Tower_Ruins',model,root) or nil;if ruins then ruins.Transparency=1 end
        local height=heights[1]
        local pole=Art.Clone('FlagPole',model,CFrame.new(site.Position.X,height-.9,site.Position.Z))
        local flag=Art.Clone('FlagCloth',model,CFrame.new(site.Position.X,height+1.4,site.Position.Z),teamColor)
        local labelPoint=site.Position+Vector3.new(0,height+4,0)
        nodes[site.Id]={Model=model,Pick=pick,Parts=pieces,Level=1,Flag=flag,Pole=pole,Heights=heights,Kind=site.Kind,Ruins=ruins,Position=site.Position,LabelPoint=labelPoint,Foundation=foundation,Borders=borders}
    end
    local junctions={}
    for _,n in activeMap.Definition.Nodes do
        if n.Kind=='Junction' then
            local pick=part(folder,n.Id,Vector3.new(8,.35,8),CFrame.new(n.X*32,.15,n.Z*32),Color3.fromRGB(211,191,143),Enum.Material.Cobblestone)
            pick.CanQuery=true;pick:SetAttribute('SiteId',n.Id);junctions[n.Id]=pick
        end
    end
    for i=1,34 do
        local side=i%2==0 and -1 or 1
        Art.Clone('Tree',folder,CFrame.new(side*(42+(i*43)%220),0,(i%3==0 and -1 or 1)*(146+(i*7)%19))*CFrame.Angles(0,i*1.23,0))
    end
    for _,p in {{-244,-145},{244,145},{-220,160},{220,-160},{-24,-161},{24,161}} do Art.Clone('Rock',folder,CFrame.new(p[1],0,p[2])) end
    local units=Instance.new('Folder');units.Name='Армии';units.Parent=folder
    return {Folder=folder,Nodes=nodes,Junctions=junctions,Units=units,Grid=grid,Map=activeMap,ViewerSide=viewerSide or 1,Roads=roads,RoadRecords=roadRecords}
end
function Scene.GridVisible(scene,visible)
    for _,p in scene.Grid:GetChildren() do p.Transparency=visible and .5 or 1 end
end
function Scene.Update(scene,state)
    for id,s in state.Sites do
        local n=scene.Nodes[id];if not n then continue end
        local color=Config.TeamColor(s.Owner,scene.ViewerSide);n.Flag.Color=color
        n.Foundation.Color=Color3.fromRGB(157,157,140):Lerp(color,.18)
        for _,p in n.Borders do p.Color=color end
        local collapsed=n.Kind=='Tower' and s.Health and s.Health<=0
        if n.Level~=s.Level then
            for _,p in n.Parts do p:Destroy()end;n.Parts={};n.Level=s.Level
            local name=n.Kind..(s.Level==1 and '_Base'or '_Upgrade'..s.Level);local bounds=Art.Bounds(name)
            local mesh=Art.Clone(name,n.Model,CFrame.new(n.Position.X,.115-bounds.Minimum.Y,n.Position.Z));mesh:SetAttribute('RequiredLevel',s.Level);table.insert(n.Parts,mesh)
        end
        for _,p in n.Parts do p.Transparency=not collapsed and p:GetAttribute('RequiredLevel')==s.Level and 0 or 1 end
        local height=collapsed and 1.8 or n.Heights[s.Level]
        local skin=s.Owner>0 and state.Skins and state.Skins[s.Owner]or 'Default'
        local appearance=skin..':'..s.Owner..':'..s.Level..':'..tostring(collapsed)
        if n.Appearance~=appearance then
            if n.Decor then n.Decor:Destroy()end;if n.Styled then n.Styled:Destroy();n.Styled=nil end
            if skin~='Default'and not collapsed then
                for _,p in n.Parts do p.Transparency=1 end
                local name=n.Kind..(s.Level==1 and '_Base'or '_Upgrade'..s.Level)
                local template=Art.Bounds(name);local ground=.115-template.Minimum.Y
                n.Styled=Art.Clone(name,n.Model,CFrame.new(n.Position.X,ground,n.Position.Z),nil,skin)
            end
            n.Decor=Instance.new('Folder');n.Decor.Name='Оформление';n.Decor.Parent=n.Model
            if s.Owner>0 and not collapsed then
                local front=({Village=3.32,Castle=s.Level==1 and 5.50 or 9.75,Barracks=3.82,Archery=2.4,Camp=2.3,Tower=2.78,Farm=.25})[n.Kind]
                local dx=n.Kind=='Archery'and -1 or n.Kind=='Farm'and -2 or 0
                local y=n.Kind=='Castle'and (s.Level==1 and 4.3 or 3.0)or n.Kind=='Tower'and 4.1 or n.Kind=='Camp'and 2.3 or 2.1
                local plaque=Art.Clone(skin..'_Herald',n.Decor,CFrame.new(n.Position.X+dx,y,n.Position.Z+front))
                plaque.Name='Герб'
                Art.Clone(skin..'_RoofCrest',n.Decor,CFrame.new(n.Position.X,height-.1,n.Position.Z))
            end
            n.Appearance=appearance
        elseif n.Styled then for _,p in n.Parts do p.Transparency=1 end end
        n.Pole.CFrame=CFrame.new(n.Position.X,height-.9,n.Position.Z)*CFrame.new(Art.Cache.FlagPole:GetAttribute('Center'))
        n.Flag.CFrame=CFrame.new(n.Position.X,height+1.4,n.Position.Z)*CFrame.new(Art.Cache.FlagCloth:GetAttribute('Center'))
        n.LabelPoint=n.Position+Vector3.new(0,height+4,0)
        if n.Ruins then n.Ruins.Transparency=collapsed and 0 or 1 end
    end
    local signature={};for _,site in scene.Map.Sites do local s=state.Sites[site.Id];table.insert(signature,site.Id..':'..(s and s.Owner or 0))end
    for side=1,2 do table.insert(signature,state.Skins and state.Skins[side]or 'Default')end
    signature=table.concat(signature,'|')
    if scene.RoadAppearance~=signature then
        local owners=RoadCosmetics.Owners(scene.Map,state.Sites)
        for i,record in scene.RoadRecords do
            local side=owners[i];local skin=side>0 and not record.Edge.Crossing and (state.Skins and state.Skins[side]or 'Default')or nil
            if record.Skin~=skin or record.Owner~=side then
                for _,p in record.Parts do p:Destroy()end;record.Parts={};record.Base.Transparency=skin and 1 or 0
                if skin then
                    local length=(record.B-record.A).Magnitude;local count=math.max(1,math.ceil(length/4))
                    for tile=1,count do
                        local position=record.A:Lerp(record.B,(tile-.5)/count)+Vector3.new(0,.08,0)
                        local p=Art.Clone(skin..'_RoadTile',scene.Roads,CFrame.lookAt(position,position+(record.B-record.A)))
                        p.Size=Vector3.new(4.60,p.Size.Y,length/count+.055);p.Name='Своя дорога';p:SetAttribute('Owner',side)
                        table.insert(record.Parts,p)
                    end
                end
                record.Skin=skin;record.Owner=side
            end
        end
        scene.RoadAppearance=signature
    end
    for _,p in scene.Folder:GetChildren() do if p:GetAttribute('Gate') then p.Transparency=state.Time>=Config.PrepTime and 1 or 0 end end
end
return Scene

