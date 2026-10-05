-- Appearance only. This never changes the path graph or combat rules.
local R={}
function R.Owners(map,sites)
    local named={};for _,node in map.Definition.Nodes do named[node.Id]=node end
    local neighbors={};for _,road in map.Roads do
        neighbors[road.A]=neighbors[road.A]or {};neighbors[road.B]=neighbors[road.B]or {}
        table.insert(neighbors[road.A],road.B);table.insert(neighbors[road.B],road.A)
    end
    local endpoint={}
    local function owner(id)
        if endpoint[id]~=nil then return endpoint[id]end
        if sites[id]then endpoint[id]=sites[id].Owner;return endpoint[id]end
        local seen,queue,result={[id]=true},{id},nil
        for _,key in queue do
            for _,nextId in neighbors[key]or {}do
                if sites[nextId]then
                    local side=sites[nextId].Owner
                    if side==0 or result and result~=side then endpoint[id]=0;return 0 end
                    result=side
                elseif not seen[nextId]then seen[nextId]=true;table.insert(queue,nextId)end
            end
        end
        endpoint[id]=result or 0;return endpoint[id]
    end
    local claimed={}
    for _,road in map.Roads do local a,b=owner(road.A),owner(road.B);claimed[road]=a>0 and a==b and a or 0 end
    local result={}
    for i,edge in map.Edges do
        local side=nil
        for _,road in edge.Roads do local o=claimed[road];if o==0 or side and side~=o then side=0;break end;side=o end
        for _,id in edge.Controls do if not sites[id]or sites[id].Owner~=side then side=0;break end end
        result[i]=side or 0
    end
    return result
end
return R
