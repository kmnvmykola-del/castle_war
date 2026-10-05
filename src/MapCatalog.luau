local Network=require(script.Parent.MapNetwork)
local Catalog={Items={{Id='TwoBridges',Name='Две переправы'},{Id='LandFrontiers',Name='Сухопутные рубежи'},{Id='RiverPass',Name='Речной проход'}}}
function Catalog.Definition(id)
    local d=Network.DefaultDefinition()
    if id=='LandFrontiers' then
        d.Name='Сухопутные рубежи';d.River=false
        for _,n in d.Nodes do
            if n.Kind=='Castle' or n.Kind=='Farm' then n.Z=1
            elseif n.Kind=='Camp' then n.Z=-1 end
            if n.Id=='NorthTower' then n.X=0;n.Z=-2
            elseif n.Id=='NorthEast' then n.X=2;n.Z=-2
            elseif n.Id=='SouthTower' then n.X=0;n.Z=2
            elseif n.Id=='SouthWest' then n.X=-2;n.Z=2 end
        end
    elseif id=='RiverPass' then
        d.Name='Речной проход'
        for _,n in d.Nodes do
            if n.Id=='NorthTower' then n.X=-1;n.Z=0
            elseif n.Id=='NorthEast' then n.X=1;n.Z=0
            elseif n.Id=='SouthTower' then n.X=2;n.Z=2
            elseif n.Id=='SouthWest' then n.X=-2;n.Z=2 end
        end
        for i=#d.Roads,1,-1 do
            local e=d.Roads[i]
            if e[1]=='SouthWest' and e[2]=='SouthTower' then table.remove(d.Roads,i) end
        end
        table.insert(d.Roads,{'SouthWest','NorthTower'})
        table.insert(d.Roads,{'NorthEast','SouthTower'})
    end
    return d
end
function Catalog.Create(id)return Network.Create(Catalog.Definition(id))end
function Catalog.Random(random)
    local item=Catalog.Items[(random or Random.new()):NextInteger(1,#Catalog.Items)]
    return assert(Catalog.Create(item.Id)),item.Id
end
return Catalog
