-- Exercise real editor/scene with imported MeshPart fixtures. AssetService
-- generation calls throw, including when a scene is built or edited.
local q=game.ReplicatedStorage.Kingdoms
local Editor=require(q.MapEditor)
local Network=require(q.MapNetwork)
local Art=require(q.Art)
local Scene=require(q.Scene)
local definition={Name='Editor QA',River=false,Nodes={
    {Id='Blue',Kind='Castle',X=-4,Z=0,Owner=1},
    {Id='Red',Kind='Castle',X=4,Z=0,Owner=2},
    {Id='Village',Kind='Village',X=-4,Z=3,Owner=1},
    {Id='Junction',Kind='Junction',X=-2,Z=3,Owner=0},
},Roads={{'Blue','Village'}}}
local parent=Instance.new('Folder')
local initial=assert(Network.Create(definition,{AllowIncomplete=true}))
local scene=Scene.Build(parent,initial,1)
local report={passed=0,failed=0,cases={}}
local function test(name,fn)
    local ok,result=pcall(fn);report[ok and 'passed'or 'failed']+=1
    report.cases[name]={passed=ok,result=ok and result or tostring(result)}
end
test('Choosing tools, teams and first road/move points leaves geometry unchanged',function()
    local revisions={}
    local editor=Editor.new(definition,function(_,_,revision)table.insert(revisions,revision)end,function()end)
    editor:Refresh();editor:SetKind('Village');editor:CycleOwner();editor:SetTool('Road');editor:Click('Blue',-4,0)
    editor.From=nil;editor:Refresh();editor:SetTool('Move');editor:Click('Village',-4,3)
    assert(#revisions==8,'Expected all UI hints to update')
    for _,revision in revisions do assert(revision==0,'A selection triggered geometry work')end
    return true
end)
test('Rebuilding a warm map reuses ordinary uploaded meshes',function()
    local before=Art.Cache.Tree
    local previous=scene
    scene=Scene.Build(parent,initial,1)
    assert(Art.Cache.Tree==before,'Warm rebuild replaced its template')
    assert(previous.Folder.Destroyed and scene.Folder.Parent==parent)
    return true
end)
test('Placement, movement, roads and undo reuse unchanged buildings and terrain',function()
    local retained=scene.Nodes.Blue.Model
    local terrain=scene.Grid
    local count=0
    local lastRevision=0
    local editor=Editor.new(definition,function(d,_,revision,compiled)
        if revision==lastRevision then return end
        lastRevision=revision;count+=1
        scene=Scene.SyncEditor(scene,compiled or assert(Network.Create(d,{AllowIncomplete=true})))
    end,function(reason)error(reason)end)
    editor:SetKind('Village');editor:Click(nil,-6,3)
    assert(scene.Nodes.N1 and scene.Nodes.Blue.Model==retained and scene.Grid==terrain)
    editor:SetTool('Move');editor:Click('N1',-6,3);editor:Click(nil,-6,4)
    assert(scene.Nodes.N1.Position.Z==128 and scene.Nodes.Blue.Model==retained)
    editor:SetTool('Road');editor:Click('Village',-4,3);editor:Click('Junction',-2,3)
    assert(#scene.Map.Definition.Roads==2 and scene.Nodes.Blue.Model==retained)
    editor:Undo();assert(#scene.Map.Definition.Roads==1 and scene.Nodes.N1)
    editor:SetTool('Erase');editor:Click('N1',-6,4)
    assert(not scene.Nodes.N1 and scene.Grid==terrain and count==5)
    return true
end)
test('Rejected placement and move to the same cell do not rebuild or add history',function()
    local editor=Editor.new(definition,function()end,function()end)
    editor:SetKind('Village');editor:Click(nil,-4,0)
    editor:SetTool('Move');editor:Click('Village',-4,3);editor:Click(nil,-4,3)
    assert(editor.GeometryRevision==0 and #editor.History==0)
    return true
end)
test('River toggle and undo retain mesh cache while changing the ground',function()
    local editor=Editor.new(definition,function(d,_,revision,compiled)
        if revision==0 then return end
        scene=Scene.SyncEditor(scene,compiled or assert(Network.Create(d,{AllowIncomplete=true})))
        Scene.GridVisible(scene,true)
    end,function(reason)error(reason)end)
    assert(editor:ToggleRiver());assert(scene.Map.River)
    for _,tile in scene.Grid:GetChildren()do assert(tile:GetAttribute('CellX')~=0 and tile.Transparency==.5)end
    editor:Undo();assert(not scene.Map.River)
    return true
end)
test('Failed full or incremental rendering retains the displayed scene',function()
    local previous=scene
    local retained=scene.Nodes.Blue.Model
    local altered=deepCopy(definition);table.insert(altered.Nodes,{Id='Tower',Kind='Tower',X=-7,Z=-3,Owner=0})
    local map=assert(Network.Create(altered,{AllowIncomplete=true}))
    local missing=q.MeshTemplates.Tower_Base;missing.Parent=nil
    assert(not pcall(function()Scene.Build(parent,map,1)end))
    assert(previous.Folder.Parent==parent and not previous.Folder.Destroyed,'Failed rebuild removed the map')
    assert(not pcall(function()Scene.SyncEditor(previous,map)end))
    assert(previous.Nodes.Blue.Model==retained and not retained.Destroyed)
    assert(#parent:GetChildren()==1,'Partial scene leaked')
    missing.Parent=q.MeshTemplates
    return true
end)
test('Crossing gates open in battle and road deletion removes bridge objects',function()
    local crossing=deepCopy(definition);crossing.River=true;crossing.Roads={{'Blue','Red'}}
    scene=Scene.SyncEditor(scene,assert(Network.Create(crossing,{AllowIncomplete=true})))
    assert(#scene.Gates==1 and scene.Gates[1].Parent==scene.Roads)
    local state={Time=0,Sites={},Skins={'Default','Default'}}
    for _,site in scene.Map.Sites do state.Sites[site.Id]={Owner=site.Owner,Level=1}end
    Scene.Update(scene,state);assert(scene.Gates[1].Transparency==0)
    state.Time=60;Scene.Update(scene,state);assert(scene.Gates[1].Transparency==1)
    local roads=scene.Roads
    crossing.Roads={}
    scene=Scene.SyncEditor(scene,assert(Network.Create(crossing,{AllowIncomplete=true})))
    assert(roads.Destroyed and #scene.Gates==0)
    for _,part in scene.Folder:GetDescendants()do assert(not part:GetAttribute('Gate')and part.Name~='Bridge')end
    return true
end)
test('Clearing a map releases unused references and retains imported assets',function()
    local templates=#q.MeshTemplates:GetChildren()
    scene=Scene.SyncEditor(scene,assert(Network.Create({Name='Empty',River=false,Nodes={},Roads={}},{AllowIncomplete=true})))
    assert(not next(scene.Nodes)and not next(scene.Junctions))
    assert(not Art.Cache.Castle_Base and not Art.Cache.Village_Base and not Art.Cache.FlagPole)
    assert(Art.Cache.Tree and Art.Cache.Rock,'Scenery references were lost')
    assert(#q.MeshTemplates:GetChildren()==templates,'Imported assets were destroyed')
    return true
end)
return report
