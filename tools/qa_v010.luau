-- Shared road geometry, automatic junctions, ownership gates and actual arrivals.
local q=Instance.new('Folder');q.Name='Version010QA';q.Parent=game.ReplicatedStorage
for _,name in {'Config','MapNetwork','MapData','MapCatalog','MapEditor','Engine'} do game.ReplicatedStorage.Kingdoms[name]:Clone().Parent=q end
local N=require(q.MapNetwork);local E=require(q.Engine);local Catalog=require(q.MapCatalog)
local report={passed=0,failed=0,cases={}}
local function test(name,fn)
    local at=os.clock();local ok,result=pcall(fn)
    report[ok and 'passed' or 'failed']+=1;report.cases[name]={passed=ok,result=ok and result or tostring(result),seconds=os.clock()-at}
end
local function length(path)
    local total=0;for i=2,#path do total+=(path[i]-path[i-1]).Magnitude end;return total
end
local function pointKey(p)return string.format('%.2f:%.2f',p.X,p.Z)end
local function drawnPath(map,path)
    for i=2,#path do
        local a,b=pointKey(path[i-1]),pointKey(path[i]);local linked=false
        for _,edge in map.Edges do if edge[1]==a and edge[2]==b or edge[1]==b and edge[2]==a then linked=true;break end end
        assert(linked,'A route segment was not present in the visible road network')
    end
end
local function star()
    return {River=false,Nodes={{Id='C',Kind='Castle',X=-4,Z=0,Owner=1},{Id='B',Kind='Barracks',X=-2,Z=-1,Owner=1},{Id='A',Kind='Archery',X=-2,Z=1,Owner=1},{Id='R',Kind='Castle',X=4,Z=0,Owner=2}},Roads={{'C','B'},{'C','A'},{'A','R'}}}
end
local function empty(map)
    local g=E.new(map);g:Start();g.Time=61;g.Phase='Battle'
    local old={};for _,u in g.Units do table.insert(old,u)end;for _,u in old do g:RemoveUnit(u)end;return g
end
test('Barracks and archery use their visible common road without entering the castle',function()
    local map=assert(N.Create(star()));local path,ids=assert(map.Route('B','A',true,'Auto',function(id)return id=='C' end))
    drawnPath(map,path)
    assert(length(path)<208,'The army still took the old logical detour')
    for _,p in path do assert((p-map.Points.C).Magnitude>.1,'A transit route entered the castle')end
    local g=empty(map);local peasant=g:CreateUnit('Peasant',1,g.Sites.B)
    assert(g:Send(1,{'B'},'A',100,'All','Auto'))
    for _=1,1400 do
        g.Time+=.1;g:WakeGuards();g:CombatAndMove(.1)
        if peasant.State=='Marching' then assert(peasant.Kind=='Peasant' and not peasant.Home,'A transit building trained or deposited the villager')end
        if peasant.Home=='A' then break end
    end
    assert(peasant.Home=='A' and peasant.Kind=='Archer' and g:Population(g.Sites.C)==0)
    return {oldLength=208,newLength=length(path),arrival='Archer at final archery',castleNotEntered=true}
end)
test('Two independent roads intersect and create one traversable four-way junction',function()
    local map=assert(N.Create({River=false,Nodes={{Id='Left',Kind='Junction',X=-6,Z=-4},{Id='Right',Kind='Junction',X=-2,Z=-4},{Id='Up',Kind='Junction',X=-4,Z=-5},{Id='Down',Kind='Junction',X=-4,Z=-3}},Roads={{'Left','Right'},{'Up','Down'}}},{AllowIncomplete=true}))
    local path=assert(map.Route('Left','Up',true));drawnPath(map,path)
    local at=pointKey(Vector3.new(-128,0,-128));assert(#map.Adjacency[at]==4)
    assert(#map.Crossings==0)
    return {junctionDegree=4,turnAllowed=true,length=length(path)}
end)
test('A T junction and collinear overlap endpoints connect without duplicate road segments',function()
    local map=assert(N.Create({River=false,Nodes={{Id='L',Kind='Junction',X=-6,Z=-4},{Id='R',Kind='Junction',X=-2,Z=-4},{Id='U',Kind='Junction',X=-4,Z=-5},{Id='T',Kind='Junction',X=-4,Z=-4},{Id='M',Kind='Junction',X=-5,Z=-4}},Roads={{'L','R'},{'U','T'},{'L','T'},{'M','R'}}},{AllowIncomplete=true}))
    drawnPath(map,assert(map.Route('U','R',true)))
    assert(#map.Adjacency[pointKey(map.Points.T)]==3)
    local seen={};for _,edge in map.Edges do local key=edge[1]<edge[2] and edge[1]..'|'..edge[2] or edge[2]..'|'..edge[1];assert(not seen[key],'An overlap duplicated a physical road');seen[key]=true end
    local direct=assert(map.Route('M','T',true));assert(math.abs(length(direct)-32)<.001)
    return {junctionDegree=3,overlapLength=32,noDuplicateEdges=true}
end)
test('Physically disconnected nearby points remain unreachable',function()
    local map=assert(N.Create({River=false,Nodes={{Id='A',Kind='Junction',X=-6,Z=-4},{Id='B',Kind='Junction',X=-5,Z=-4},{Id='C',Kind='Junction',X=-4,Z=-4},{Id='D',Kind='Junction',X=-3,Z=-4}},Roads={{'A','B'},{'C','D'}}},{AllowIncomplete=true}))
    assert(map.Route('A','B',true) and not map.Route('A','D',true))
    return 'Separated visible road components did not gain a hidden connection'
end)
test('Map validation and editor import accept a network connected only by a visible crossing',function()
    local definition={River=false,Nodes={{Id='L',Kind='Castle',X=-6,Z=-4,Owner=1},{Id='R',Kind='Junction',X=-2,Z=-4},{Id='U',Kind='Castle',X=-4,Z=-5,Owner=2},{Id='D',Kind='Junction',X=-4,Z=-3}},Roads={{'L','R'},{'U','D'}}}
    local map=assert(N.Create(definition));drawnPath(map,assert(map.Route('L','U',true)))
    local editor=require(q.MapEditor).new(definition,function()end,function()end)
    assert(editor:Import(editor:Export()) and editor:Validate())
    return 'A visible crossing joins both castles for validation and saved map import'
end)
test('Neutral and enemy intermediate approaches block passage until capture, with cache invalidation',function()
    local definition=star();definition.Nodes[1].Owner=0;definition.Nodes[2].Kind='Castle';definition.Nodes[2].Owner=1
    definition.Nodes[2].X=-6;definition.Nodes[2].Z=0;definition.Nodes[3].X=-2;definition.Nodes[3].Z=0
    local g=empty(assert(N.Create(definition)))
    local path=g:RouteForSide(1,'B','A');assert(not path,'A neutral intermediate castle allowed transit')
    g.Sites.C.Owner=2;assert(not g:RouteForSide(1,'B','A'))
    assert(g:RouteForSide(1,'B','C'),'An enemy final destination could not be attacked')
    g:Capture(g.Sites.C,1);local captured=assert(g:RouteForSide(1,'B','A'));drawnPath(g.Map,captured)
    g:Capture(g.Sites.C,0);assert(not g:RouteForSide(1,'B','A'),'Cached passage stayed open after ownership changed')
    return 'Shared approaches respect intermediate ownership; capture opens and loss closes the path'
end)
test('An external common street remains usable when its nearby castle is neutral',function()
    local definition=star();definition.Nodes[1].Owner=0;definition.Nodes[2].Kind='Castle';definition.Nodes[2].Owner=1
    local g=empty(assert(N.Create(definition)));local path=assert(g:RouteForSide(1,'B','A'))
    drawnPath(g.Map,path)
    for _,p in path do assert((p-g.Map.Points.C).Magnitude>.1)end
    return 'The physical bypass stays open without entering or crossing the neutral castle approach'
end)
test('Every returned baseline-map segment is visible, bridges obey preparation and route preferences',function()
    local maps={}
    for _,item in Catalog.Items do
        local map=assert(Catalog.Create(item.Id));local checked=0
        for _,a in map.Sites do for _,b in map.Sites do if a.Id~=b.Id then
            local path=assert(map.Route(a.Id,b.Id,true,'Auto'));drawnPath(map,path);checked+=1
        end end end
        if map.River then
            assert(not map.Route(map.Castles[1],map.Castles[2],false,'Auto'),'Closed bridges allowed passage')
            for _,preference in {'North','South'} do
                local path=map.Route(map.Castles[1],map.Castles[2],true,preference)
                if path then for i=2,#path do local a,b=path[i-1],path[i];if math.abs(a.X)<.01 or math.abs(b.X)<.01 or a.X*b.X<0 then
                    assert(preference=='North' and a.Z<0 or preference=='South' and a.Z>=0,'A bridge ignored its selected direction')
                end end end
            end
        end
        maps[item.Id]={pairs=checked,visibleEdges=#map.Edges}
    end
    return maps
end)
q:Destroy();return report
