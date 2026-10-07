-- Buildings occupy cells. Streets use empty cells and perimeter lanes.
local Config=require(script.Parent.Config)
local Map={CellSize=32,Bounds={MinX=-8,MaxX=8,MinZ=-5,MaxZ=5}}
local initial={Castle={Defender=50,Peasant=20},Village={Peasant=8},Barracks={Defender=12},Archery={Archer=12},Camp={Runner=12},Tower={Archer=15},Farm={}}
Map.EntranceRadius={Castle=13,Village=8,Barracks=8,Archery=8,Camp=8,Tower=4.5,Farm=8}
local dirs={{1,0},{0,1},{-1,0},{0,-1}}
local function integer(n)return typeof(n)=='number' and n==n and n%1==0 end
local function cell(x,z)return x..':'..z end
local function positionKey(p)return string.format('%.2f:%.2f',p.X,p.Z) end
local function gridPath(a,b,occupied,river)
    local start,finish=cell(a.X,a.Z),cell(b.X,b.Z)
    local costs={[start]=0};local positions={[start]={a.X,a.Z}};local previous,closed={},{}
    while true do
        local current,best=nil,math.huge
        for key,cost in costs do
            local p=positions[key]
            local score=cost+math.abs(p[1]-b.X)+math.abs(p[2]-b.Z)
            if not closed[key] and (score<best or score==best and (not current or key<current)) then current,best=key,score end
        end
        if not current then return nil end
        if current==finish then break end
        closed[current]=true
        local p=positions[current]
        for _,d in dirs do
            local x,z=p[1]+d[1],p[2]+d[2]
            local key=cell(x,z)
            local inside=x>=Map.Bounds.MinX and x<=Map.Bounds.MaxX and z>=Map.Bounds.MinZ and z<=Map.Bounds.MaxZ
            local landStep=not river or p[1]~=0 or d[2]==0
            local intoRiver=not river or x~=0 or d[2]==0
            if inside and landStep and intoRiver and (not occupied[key] or key==finish or key==start) then
                local cost=costs[current]+1
                if cost<(costs[key] or math.huge) then costs[key]=cost;positions[key]={x,z};previous[key]=current end
            end
        end
    end
    local result={positions[finish]};local key=finish
    while key~=start do key=previous[key];table.insert(result,1,positions[key]) end
    return result
end
local function compile(definition,options)
    local incomplete=options and options.AllowIncomplete
    if typeof(definition)~='table' or typeof(definition.Nodes)~='table' or typeof(definition.Roads)~='table' then return nil,'Buildings and roads are required.' end
    if #definition.Nodes>80 or #definition.Roads>160 then return nil,'The map is too large.' end
    local river=definition.River~=false
    local M={Sites={},Points={},Edges={},Bridges={},River=river,CellSize=Map.CellSize,Bounds=Map.Bounds,Definition={Name=typeof(definition.Name)=='string' and string.sub(definition.Name,1,60) or 'My Map',River=river,Nodes={},Roads={}}}
    local known,occupied,buildings={}, {},{}
    local castles={}
    for _,n in definition.Nodes do
        if typeof(n)~='table' or typeof(n.Id)~='string' or #n.Id>40 or not n.Id:match('^[%w_]+$') or known[n.Id] then return nil,'Each point must have a unique ID.' end
        if not integer(n.X) or not integer(n.Z) or n.X<Map.Bounds.MinX or n.X>Map.Bounds.MaxX or n.Z<Map.Bounds.MinZ or n.Z>Map.Bounds.MaxZ then return nil,'Place the object in a cell within the map.' end
        if river and n.X==0 then return nil,'Only road bridges can cross the riverbed.' end
        if n.Kind~='Junction' and not Config.Buildings[n.Kind] then return nil,'Unknown building type.' end
        local key=cell(n.X,n.Z)
        if occupied[key] then return nil,'This cell is already occupied.' end
        local owner=n.Owner or 0
        if owner~=0 and owner~=1 and owner~=2 then return nil,'Unknown team.' end
        local copy={Id=n.Id,Kind=n.Kind,X=n.X,Z=n.Z,Owner=owner}
        table.insert(M.Definition.Nodes,copy);known[n.Id]=copy;occupied[key]=true
        local center=Vector3.new(n.X*Map.CellSize,0,n.Z*Map.CellSize)
        M.Points[n.Id]=center
        if n.Kind~='Junction' then
            buildings[key]=true
            local entrance=center+Vector3.new(0,0,Map.EntranceRadius[n.Kind])
            M.Points[n.Id]=entrance
            table.insert(M.Sites,{Id=n.Id,Kind=n.Kind,Position=center,Entrance=entrance,Owner=owner,Zone=n.X<0 and 1 or 2,Initial=initial[n.Kind]})
            if n.Kind=='Castle' and owner~=0 then
                if castles[owner] and not incomplete then return nil,'Each team needs exactly one castle.' end
                castles[owner]=n.Id
            end
        end
    end
    if not incomplete then
        local counts={0,0}
        for _,s in M.Sites do if s.Kind=='Castle' and s.Owner~=0 then counts[s.Owner]+=1 end end
        if counts[1]~=1 or counts[2]~=1 then return nil,'Place one Blue castle and one Red castle.' end
    end
    local vertices,adjacency,segments,bridgeKeys={},{},{},{}
    local raw={}
    local roads={};M.Roads=roads;M.Crossings={}
    local function append(points,p)if not points[#points] or (points[#points]-p).Magnitude>.01 then table.insert(points,p)end end
    local function distance(points)local n=0;for i=2,#points do n+=(points[i]-points[i-1]).Magnitude end;return n end
    local function approach(n,port)
        if n.Kind=='Junction'then return {port}end
        local c=Vector3.new(n.X*32,0,n.Z*32)
        local offsets={{0,16},{16,16},{16,0},{16,-16},{0,-16},{-16,-16},{-16,0},{-16,16}}
        local target=1
        for i,o in offsets do if (c+Vector3.new(o[1],0,o[2])-port).Magnitude<.1 then target=i;break end end
        local forward=(target-1)%8;local backward=(1-target)%8;local step=forward<=backward and 1 or -1
        local points={c+Vector3.new(0,0,16)};local index=1
        while index~=target do index=(index-1+step)%8+1;local o=offsets[index];table.insert(points,c+Vector3.new(o[1],0,o[2]))end
        return points
    end
    local function vertex(p)
        local k=positionKey(p);vertices[k]=p;adjacency[k]=adjacency[k] or {};return k
    end
    local function link(a,b,road,control)
        if (a-b).Magnitude<.01 then vertex(a);return end
        local ka,kb=vertex(a),vertex(b);local key=ka<kb and ka..'|'..kb or kb..'|'..ka
        local edge=segments[key]
        if not edge then
            edge={A=a,B=b,Roads={},Controls={},Cuts={[ka]=a,[kb]=b}};segments[key]=edge;table.insert(raw,edge)
        end
        if not table.find(edge.Roads,road) then table.insert(edge.Roads,road) end
        if control and known[control].Kind~='Junction' then edge.Controls[control]=true else edge.Public=true end
    end
    local seen={}
    for _,edge in definition.Roads do
        if typeof(edge)~='table' or not known[edge[1]] or not known[edge[2]] or edge[1]==edge[2] then return nil,'A road must connect two different existing points.' end
        local a,b=known[edge[1]],known[edge[2]]
        local key=a.Id<b.Id and a.Id..'|'..b.Id or b.Id..'|'..a.Id
        if seen[key] then continue end;seen[key]=true
        local cells=gridPath(a,b,buildings,river)
        if not cells then return nil,'Road '..a.Id..' → '..b.Id..' has no free cells.' end
        table.insert(M.Definition.Roads,{a.Id,b.Id})
        local points={}
        for i,p in cells do
            local v=Vector3.new(p[1]*32,0,p[2]*32)
            if i==1 and a.Kind~='Junction' then local nextCell=cells[2];v+=Vector3.new(nextCell[1]-p[1],0,nextCell[2]-p[2])*16
            elseif i==#cells and b.Kind~='Junction' then local previousCell=cells[i-1];v+=Vector3.new(previousCell[1]-p[1],0,previousCell[2]-p[2])*16 end
            table.insert(points,v)
            if river and p[1]==0 and not bridgeKeys[p[2]] then
                bridgeKeys[p[2]]=true
                table.insert(M.Bridges,{Position=Vector3.new(0,0,p[2]*32),Direction=Vector3.new(1,0,0)})
            end
        end
        local crossingRows={};for _,p in points do if river and math.abs(p.X)<.01 then table.insert(crossingRows,p.Z)end end
        local road={A=a.Id,B=b.Id,Points=points,ApproachA=approach(a,points[1]),ApproachB=approach(b,points[#points]),Crossing=#crossingRows>0,CrossingRows=crossingRows}
        road.Cost=distance(points)+distance(road.ApproachA)+distance(road.ApproachB);table.insert(roads,road)
        local reverse={};for i=#points,1,-1 do append(reverse,points[i])end
        local drawing={M.Points[a.Id]}
        local function draw(p,control)
            link(drawing[#drawing],p,road,control);append(drawing,p)
        end
        for _,p in road.ApproachA do draw(p,a.Id)end
        for _,p in points do draw(p,nil)end
        for i=#road.ApproachB,1,-1 do draw(road.ApproachB[i],b.Id)end
        draw(M.Points[b.Id],b.Id);road.Drawing=drawing
    end
    -- Split the drawn segments at every crossing, T junction and overlap endpoint.
    -- Both the scene and routing consume these exact edges.
    for i,a in raw do for j=i+1,#raw do
        local b=raw[j];local p,q,r,s=a.A,a.B,b.A,b.B
        local horizontalA=math.abs(p.Z-q.Z)<.01;local horizontalB=math.abs(r.Z-s.Z)<.01
        if horizontalA~=horizontalB then
            local h1,h2,v1,v2=p,q,r,s;if not horizontalA then h1,h2,v1,v2=r,s,p,q end
            local x,z=v1.X,h1.Z
            if x>=math.min(h1.X,h2.X)-.01 and x<=math.max(h1.X,h2.X)+.01 and z>=math.min(v1.Z,v2.Z)-.01 and z<=math.max(v1.Z,v2.Z)+.01 then
                local at=Vector3.new(x,0,z);local key=positionKey(at);a.Cuts[key]=at;b.Cuts[key]=at
            end
        else
            local sameLine=horizontalA and math.abs(p.Z-r.Z)<.01 or not horizontalA and math.abs(p.X-r.X)<.01
            if not sameLine then continue end
            for _,at in {p,q,r,s} do
                local v=horizontalA and at.X or at.Z
                local pa,qa=horizontalA and p.X or p.Z,horizontalA and q.X or q.Z
                local ra,sa=horizontalA and r.X or r.Z,horizontalA and s.X or s.Z
                if v>=math.max(math.min(pa,qa),math.min(ra,sa))-.01 and v<=math.min(math.max(pa,qa),math.max(ra,sa))+.01 then
                    local key=positionKey(at);a.Cuts[key]=at;b.Cuts[key]=at
                end
            end
        end
    end end
    segments={}
    for _,source in raw do
        local cuts={};for _,p in source.Cuts do table.insert(cuts,p)end
        local horizontal=math.abs(source.A.Z-source.B.Z)<.01
        table.sort(cuts,function(a,b)return (horizontal and a.X or a.Z)<(horizontal and b.X or b.Z)end)
        for i=2,#cuts do
            local a,b=cuts[i-1],cuts[i];local ka,kb=vertex(a),vertex(b)
            local key=ka<kb and ka..'|'..kb or kb..'|'..ka
            local edge=segments[key]
            if not edge then
                edge={ka,kb,Cost=(a-b).Magnitude,Crossing=river and (math.abs(a.X)<.01 or math.abs(b.X)<.01 or a.X*b.X<0),Roads={},Controls={}}
                segments[key]=edge;table.insert(M.Edges,edge)
            end
            edge.Public=edge.Public or source.Public
            for id in source.Controls do edge.Controls[id]=true end
            for _,road in source.Roads do if not table.find(edge.Roads,road)then table.insert(edge.Roads,road)end end
        end
    end
    local named={};local transitIds={}
    for id,n in known do
        local key=vertex(M.Points[id]);named[key]=id
        if n.Kind~='Junction' then table.insert(transitIds,id)end
    end
    table.sort(transitIds)
    for _,edge in M.Edges do
        local controls={};for id in edge.Controls do table.insert(controls,id)end;table.sort(controls);edge.Controls=controls
        table.insert(adjacency[edge[1]],{Id=edge[2],Edge=edge})
        table.insert(adjacency[edge[2]],{Id=edge[1],Edge=edge})
    end
    for _,neighbors in adjacency do table.sort(neighbors,function(a,b)return a.Id<b.Id end)end
    M.GraphPoints=vertices;M.Adjacency=adjacency;M.Castles=castles
    local routeCache,cacheCount={},0
    function M.Route(from,to,open,preferred,canTransit)
        local cacheKey=tostring(from)..'|'..tostring(to)..'|'..tostring(open)..'|'..tostring(preferred)
        local transit={}
        if canTransit then
            local bits={}
            for _,id in transitIds do transit[id]=id==from or id==to or not not canTransit(id);table.insert(bits,transit[id] and '1' or '0')end
            cacheKey..='|'..table.concat(bits)
        end
        local cached=routeCache[cacheKey]
        if cached==false then return nil elseif cached then return cached[1],cached[2] end
        local a,b=M.Points[from],M.Points[to]
        if not a or not b then return nil end
        local start,finish=positionKey(a),positionKey(b)
        if not adjacency[start] or not adjacency[finish] then return nil end
        local function remember(value)
            if cacheCount>=2048 then table.clear(routeCache);cacheCount=0 end
            routeCache[cacheKey]=value;cacheCount+=1
        end
        local distance,previous,visited={[start]=0},{},{}
        while true do
            local current,best=nil,math.huge
            for id,d in distance do if not visited[id] and (d<best or d==best and (not current or id<current)) then current,best=id,d end end
            if not current then remember(false);return nil end
            if current==finish then break end;visited[current]=true
            for _,neighbor in adjacency[current] do
                local edge=neighbor.Edge;local allowed=not edge.Crossing or open;local gate=nil
                if allowed and not edge.Public then
                    allowed=false
                    for _,id in edge.Controls do if not canTransit or transit[id] then allowed=true;gate=id;break end end
                end
                if allowed and edge.Crossing and preferred and preferred~='Auto'then
                    local z=vertices[edge[1]].Z
                    if preferred=='North'and z>=0 or preferred=='South'and z<0 then allowed=false end
                end
                if allowed then local d=best+edge.Cost;if d<(distance[neighbor.Id] or math.huge) then distance[neighbor.Id]=d;previous[neighbor.Id]={Id=current,Gate=gate}end end
            end
        end
        local keys={finish}
        while keys[1]~=start do table.insert(keys,1,previous[keys[1]].Id)end
        local points,ids,listed={},{from},{[from]=true,[to]=true}
        local function visit(id)
            if id and not listed[id]then table.insert(ids,id);listed[id]=true end
        end
        for i,key in keys do
            append(points,vertices[key]);if i>1 then visit(previous[key].Gate)end;visit(named[key])
        end
        if to~=from then table.insert(ids,to)end
        remember({points,ids});return points,ids
    end
    if not incomplete then
        if not M.Route(castles[1],castles[2],true) then return nil,'Connect the castles with roads and a crossing.' end
        for _,s in M.Sites do if not M.Route(castles[1],s.Id,true) then return nil,'Building '..s.Id..' is disconnected from the road network.' end end
    end
    return M
end
Map.Create=compile
function Map.DefaultDefinition()
    local d={Name='Two Crossings',River=true,Nodes={},Roads={}}
    local function add(id,kind,x,z,owner) table.insert(d.Nodes,{Id=id,Kind=kind,X=x,Z=z,Owner=owner or 0}) end
    for side=1,2 do
        local s=side==1 and -1 or 1
        local p=side==1 and 'A' or 'B'
        add(p..'Castle','Castle',s*6,0,side)
        add(p..'Farm','Farm',s*7,0,side)
        table.insert(d.Roads,{p..'Castle',p..'Farm'})
        add(p..'Village1','Village',s*6,-3);add(p..'Village2','Village',s*4,-3)
        add(p..'Village3','Village',s*6,3);add(p..'Village4','Village',s*4,3)
        add(p..'Barracks','Barracks',s*4,-1);add(p..'Archery','Archery',s*4,1);add(p..'Camp','Camp',s*2,0)
        for _,v in {{'Castle','Village1'},{'Castle','Village3'},{'Village1','Village2'},{'Village3','Village4'},{'Castle','Barracks'},{'Castle','Archery'},{'Village2','Barracks'},{'Village4','Archery'},{'Barracks','Camp'},{'Archery','Camp'}} do table.insert(d.Roads,{p..v[1],p..v[2]}) end
    end
    add('NorthTower','Tower',-1,-2);add('NorthEast','Junction',1,-2)
    add('SouthTower','Tower',1,2);add('SouthWest','Junction',-1,2)
    for _,e in {{'AVillage2','NorthTower'},{'ABarracks','NorthTower'},{'ACamp','NorthTower'},{'ACamp','SouthWest'},{'AArchery','SouthWest'},{'AVillage4','SouthWest'},{'NorthTower','NorthEast'},{'SouthWest','SouthTower'},{'NorthEast','BVillage2'},{'NorthEast','BBarracks'},{'NorthEast','BCamp'},{'SouthTower','BCamp'},{'SouthTower','BArchery'},{'SouthTower','BVillage4'}} do table.insert(d.Roads,e) end
    return d
end
return Map

