local Config=require(script.Parent.Config)
local Map=require(script.Parent.MapData)
local Engine={}
Engine.__index=Engine
local function flat(v) return Vector3.new(v.X,0,v.Z) end
local function length(a,b) return (flat(a)-flat(b)).Magnitude end
local function direction(a,b)
    local d=flat(b-a)
    return d.Magnitude>.001 and d.Unit or Vector3.new(1,0,0)
end
local function roster()
    return {Peasant=0,Defender=0,Archer=0,Runner=0}
end
local function melee(u)return u.Kind=='Defender' or u.Kind=='Runner'end
local function formation(path)
    local f={Path=path,Progress=0,Ids={},Cumulative={0},Hold=false,Columns=4,BridgeSpans={}}
    for i=2,#path do f.Cumulative[i]=f.Cumulative[i-1]+length(path[i-1],path[i])end
    f.Length=f.Cumulative[#path]
    return f
end
local function pathPoint(f,progress,offset)
    local path=f.Path
    if f.ExitLength and progress<f.ExitLength then offset*=math.clamp(progress/f.ExitLength,0,1) end
    local function point(p,d)return p+Vector3.new(-d.Z,0,d.X)*offset end
    if progress<=0 then local d=direction(path[1],path[2]);return point(path[1],d),2,d,false end
    for i=2,#path do if progress<f.Cumulative[i]then
        local begin,finish=f.Cumulative[i-1],f.Cumulative[i];local t=(progress-begin)/(finish-begin)
        local d=direction(path[i-1],path[i]);local blended=d
        if i>2 and progress-begin<3 then blended=direction(path[i-2],path[i-1]):Lerp(d,.5+(progress-begin)/6)
        elseif i<#path and finish-progress<3 then blended=d:Lerp(direction(path[i],path[i+1]),.5-(finish-progress)/6)end
        if blended.Magnitude>.01 then d=blended.Unit end
        return point(path[i-1]:Lerp(path[i],t),d),i,d,false
    end end
    local d=direction(path[#path-1],path[#path]);return point(path[#path],d),#path,d,true
end
local function formationPoint(f,u)
    return pathPoint(f,f.Progress-u.MarchRank*Config.RankSpacing,(u.MarchColumn-(f.Columns+1)/2)*Config.FormationSpacing)
end
local function door(site)
    local offset=Config.DoorOffsets[site.Kind]
    if typeof(offset)=='table' then offset=offset[site.Level] end
    return site.Position+(offset or Vector3.zero)
end
local function exitPath(site,points,useModel)
    local path=table.clone(points)
    if useModel then table.insert(path,1,door(site)) end
    return path
end
local function pathProgress(f,position)
    local best,bestGap=0,math.huge
    for i=2,#f.Path do
        local a,b=f.Path[i-1],f.Path[i];local d=direction(a,b)
        local t=math.clamp(flat(position-a):Dot(d),0,length(a,b))
        local gap=length(a+d*t,position)
        if gap<bestGap then bestGap=gap;best=f.Cumulative[i-1]+t end
    end
    return best
end
local function compact(f,live,reflow)
    local soldiers,peasants={},{}
    for _,u in live do table.insert(u.Kind=='Peasant' and peasants or soldiers,u) end
    f.MeleeCount=#soldiers;f.HasMelee=#soldiers>0
    local ranks=table.create(f.Columns,0)
    for i,u in soldiers do
        if reflow then u.MarchColumn=(i-1)%f.Columns+1 end
        u.MarchRank=ranks[u.MarchColumn];ranks[u.MarchColumn]+=1
    end
    local rear=0;for _,n in ranks do rear=math.max(rear,n) end
    for c=1,f.Columns do ranks[c]=rear end
    for i,u in peasants do
        if reflow then u.MarchColumn=(i-1)%f.Columns+1 end
        u.MarchRank=ranks[u.MarchColumn];ranks[u.MarchColumn]+=1
    end
    for _,u in live do u.Column=(u.MarchColumn-(f.Columns+1)/2)*Config.FormationSpacing end
    local frontColumns={}
    for _,u in soldiers do if u.MarchRank==0 then table.insert(frontColumns,u.MarchColumn) end end
    table.sort(frontColumns)
    f.FrontCount=#frontColumns;f.FrontColumns={}
    for slot,column in frontColumns do f.FrontColumns[column]=slot end
end
local function contactPoint(f,u)
    local contact=f.Contact
    local facing=contact.A==f and contact.Axis or -contact.Axis
    local center=contact.Center-facing*Config.MeleeContact*.5
    local column,columns=u.MarchColumn,f.Columns
    if u.MarchRank==0 then
        column=f.FrontColumns[u.MarchColumn]
        columns=math.max(contact.A.FrontCount,contact.B.FrontCount)
    end
    local offset=(column-(columns+1)/2)*Config.FormationSpacing
    return center-facing*u.MarchRank*Config.RankSpacing+Vector3.new(-facing.Z,0,facing.X)*offset,facing
end
local function clearContact(f)
    local contact=f.Contact
    if not contact then return end
    for _,other in {contact.A,contact.B} do
        if other.Contact==contact then other.Contact=nil;other.Reforming=true end
    end
end
function Engine.new(activeMap,options)
    local self=setmetatable({Time=0,Phase='Waiting',Sites={},Units={},Active={},NextId=0,NextSquad=0,Events={},BotClock=0,Winner=nil,LastBotTarget=nil},Engine)
    self.Map=activeMap or Map
    self.Difficulty=options and options.Difficulty or 'Hard'
    self.Food={Config.Food.Initial,Config.Food.Initial}
    self.FoodClock=0
    self.Impacts={}
    self.RowReady={}
    self.Formations={}
    for _,data in self.Map.Sites do
        local site={Id=data.Id,Kind=data.Kind,Position=data.Position,Entrance=data.Entrance,Owner=data.Owner,Zone=data.Zone,Level=1,Garrison={},RecruitClock=0,TrainClock=0,TowerClock=0,UpgradeUntil=nil,Supply=nil,Health=data.Kind=='Tower' and Config.TowerHealth or nil}
        self.Sites[site.Id]=site
        for _,kind in Config.Types do
            for _=1,(data.Initial[kind] or 0) do self:CreateUnit(kind,site.Owner,site) end
        end
    end
    return self
end
function Engine:Start()
    if self.Phase=='Waiting' then self.Phase='Preparation' end
end
function Engine:Capacity(site)
    local caps=site.Kind=='Castle' and Config.CastleCapacity or (site.Kind=='Tower' and Config.TowerCapacity or Config.Capacity)
    return caps[site.Level]
end
function Engine:CreateUnit(kind,side,site)
    self.NextId+=1
    local u={Id=self.NextId,Kind=kind,Side=side,Health=Config.Units[kind].Health,Position=site.Position,Home=site.Id,State='Garrison',Cooldown=0,Heading=Vector3.new(0,0,-1),AttackUntil=0}
    self.Units[u.Id]=u
    table.insert(site.Garrison,u.Id)
    return u
end
function Engine:Counts(site,includeOutside)
    local c=roster()
    for _,id in site.Garrison do
        local u=self.Units[id]
        if u then c[u.Kind]+=1 end
    end
    if includeOutside then
        for _,u in self.Active do if u.State=='Overflow' and u.Target==site.Id and u.Side==site.Owner then c[u.Kind]+=1 end end
    end
    return c
end
function Engine:Population(site,includeOutside)
    local c=self:Counts(site,includeOutside)
    return c.Peasant+c.Defender+c.Archer+c.Runner
end
function Engine:Detach(u)
    if u.Home and self.Sites[u.Home] then
        local list=self.Sites[u.Home].Garrison
        local index=table.find(list,u.Id)
        if index then table.remove(list,index) end
    end
    u.Home=nil
end
function Engine:TrainArrival(u,site)
    if u.Kind~='Peasant' then return end
    local kind=Config.Buildings[site.Kind].Recruit
    if not kind or kind=='Peasant' then u.PendingTraining=nil;return end
    if site.Owner~=u.Side then return end
    if u.Side~=0 and self.Food[u.Side]<=0 then u.PendingTraining=site.Id;return end
    u.Kind=kind;u.Health=Config.Units[kind].Health;u.PendingTraining=nil
end
function Engine:Deposit(u,site)
    self:Detach(u)
    u.Formation=nil;u.Escort=nil;u.LoosePath=nil;u.LooseProgress=nil;u.MarchFinished=nil
    if self:Population(site)>=self:Capacity(site) then
        u.State='Overflow'
        u.Target=site.Id
        u.Home=nil
        self.Active[u.Id]=u
        local waiting=0
        for _,v in self.Active do if v~=u and v.State=='Overflow' and v.Target==site.Id and v.Side==site.Owner then waiting+=1 end end
        local entry=site.Entrance or site.Position+Vector3.new(0,0,8)
        u.Position=entry+Vector3.new((waiting%4-1.5)*.95,0,2+math.floor(waiting/4)*.95)
        u.Height=.25
        return
    end
    self:TrainArrival(u,site)
    u.Home=site.Id
    u.Target=nil
    u.Path=nil
    u.State='Garrison'
    u.Position=site.Position
    self.Active[u.Id]=nil
    table.insert(site.Garrison,u.Id)
end
function Engine:Capture(site,side)
    -- Protected archers fall with the occupied building, rather than blocking capture forever.
    for _,id in table.clone(site.Garrison) do
        local guard=self.Units[id]
        if guard and guard.Side~=side then self:RemoveUnit(guard) end
    end
    site.Owner=side
    site.UpgradeUntil=nil
    site.RecruitClock=0
    site.TrainClock=0
    site.Supply=nil
    if site.Kind=='Tower' then site.Health=Config.TowerHealth end
    for _,s in self.Sites do if s.Supply and s.Supply.Target==site.Id then s.Supply=nil end end
    table.insert(self.Events,{Type='Capture',Site=site.Id,Side=side})
end
function Engine:Available(site,filter)
    local list={}
    for _,id in site.Garrison do
        local u=self.Units[id]
        if u and u.State~='Deploying' and (not filter or filter=='All' or u.Kind==filter) then table.insert(list,u) end
    end
    for _,u in self.Active do
        if u.State=='Overflow' and u.Target==site.Id and u.Side==site.Owner and (not filter or filter=='All' or u.Kind==filter) then table.insert(list,u) end
    end
    table.sort(list,function(a,b)
        local x,y=Config.Units[a.Kind].Priority,Config.Units[b.Kind].Priority
        return x==y and a.Id<b.Id or x<y
    end)
    return list
end
function Engine:RouteForSide(side,from,to,preferred)
    local open=self.Time>=Config.PrepTime
    local points,ids=self.Map.Route(from,to,open,preferred or 'Auto',function(id)
        return self.Sites[id] and self.Sites[id].Owner==side
    end)
    if points then return points,ids end
    local _,blocked=self.Map.Route(from,to,open,preferred or 'Auto')
    for i=2,#(blocked or {})-1 do
        local s=self.Sites[blocked[i]]
        if s and s.Owner~=side then return nil,nil,'Route blocked: capture the intermediate '..Config.Buildings[s.Kind].Name..' first. No alternative route is available.' end
    end
    return nil
end
function Engine:BeginDeparture(u)
    if not u.GuardDeparture then self:Detach(u) end
    u.State=u.GuardDeparture and 'Defending' or 'Marching'
    u.DeployAt=nil;self.Active[u.Id]=u
end
function Engine:ReleaseArchers()
    for _,u in self.Units do
        if u.State=='Deploying' and not u.Formation and self.Time>=(u.DeployAt or math.huge) then self:BeginDeparture(u) end
    end
end
function Engine:Send(side,sources,targetId,percent,filter,preferred)
    if self.Phase=='Waiting' or self.Phase=='Ended' then return false,'The battle has not started or has already ended.' end
    local target=self.Sites[targetId]
    if not target then return false,'Select a building on the map.' end
    if typeof(percent)~='number' or percent~=percent then return false,'Invalid troop percentage.' end
    percent=math.clamp(percent,1,100)
    if filter~='All' and not Config.Units[filter] then return false,'Invalid unit type.' end
    if preferred~='North' and preferred~='South' then preferred='Auto' end
    if typeof(sources)~='table' or #sources>80 then return false,'Invalid building list.' end
    local sent=0
    local blockedReason=nil
    local seen={}
    for _,sourceId in sources do
        local source=self.Sites[sourceId]
        if source and not seen[sourceId] and source.Owner==side and source.Id~=target.Id then
            seen[sourceId]=true
            local points,routeIds,reason=self:RouteForSide(side,source.Id,target.Id,preferred)
            blockedReason=blockedReason or reason
            if points then
                local available=self:Available(source,filter)
                local selected={}
                if filter=='All' then
                    for _,kind in Config.Types do
                        local group={}
                        for _,u in available do if u.Kind==kind then table.insert(group,u) end end
                        for i=1,math.floor(#group*percent/100+1e-7) do table.insert(selected,group[i]) end
                    end
                    table.sort(selected,function(a,b) return Config.Units[a.Kind].Priority<Config.Units[b.Kind].Priority end)
                else
                    for i=1,math.floor(#available*percent/100+1e-7) do table.insert(selected,available[i]) end
                end
                local n=#selected
                self.NextSquad+=1
                points=exitPath(source,points,self.Map.Sites~=nil)
                if target.Owner~=side and self.Map.Sites then
                    local finish=target.Kind=='Tower' and target.Position or door(target)
                    if length(points[#points],finish)>.01 then table.insert(points,finish) end
                elseif target.Kind=='Tower' and target.Owner~=side and target.Health>0 then table.insert(points,target.Position) end
                local heading=direction(points[1],points[2])
                local f=formation(points);local orderedCount,looseCount=0,0
                f.ExitLength=self.Map.Sites and length(points[1],points[2]) or nil
                f.RouteIds=routeIds;f.Side=side;f.Source=source.Id;f.Target=target.Id
                f.MeleeCount=0;for _,unit in selected do if melee(unit)then f.MeleeCount+=1 end end
                if self.Map.River then
                    for j=2,#points do
                        local a,b=points[j-1],points[j]
                        if math.abs(a.Z-b.Z)<.01 and math.min(a.X,b.X)<16 and math.max(a.X,b.X)>-16 then
                            local begin=f.Cumulative[j-1]+math.max(0,math.min(-16,16)-math.min(a.X,b.X))
                            local finish=f.Cumulative[j]-math.max(0,math.max(a.X,b.X)-16)
                            if a.X>b.X then begin=f.Cumulative[j-1]+math.max(0,a.X-16);finish=f.Cumulative[j]-math.max(0,-16-b.X)end
                            if finish>begin then table.insert(f.BridgeSpans,{begin,finish})end
                        end
                    end
                end
                for i=1,n do
                    local u=selected[i]
                    local inside=u.Home==source.Id and (u.State=='Garrison' or u.State=='Defending')
                    if not inside then self:Detach(u) end
                    u.State=inside and 'Deploying' or 'Marching'
                    u.GuardDeparture=nil;u.ExitTravel=nil;u.Escort=nil;u.LoosePath=nil;u.LooseProgress=nil
                    u.Target=target.Id
                    u.Path=points
                    u.PathIndex=2
                    u.Squad=self.NextSquad
                    u.Height=.25
                    if u.Kind~='Archer'then
                        orderedCount+=1;u.Formation=f;table.insert(f.Ids,u.Id)
                        local slot=u.Kind=='Peasant'and math.ceil(f.MeleeCount/4)*4+orderedCount-f.MeleeCount or orderedCount
                        u.MarchColumn=(slot-1)%Config.FormationColumns+1;u.MarchRank=math.floor((slot-1)/Config.FormationColumns)
                        u.Column=(u.MarchColumn-(Config.FormationColumns+1)/2)*Config.FormationSpacing;u.FormationIndex=orderedCount
                        if not inside then
                            f.Progress=math.max(f.Progress,pathProgress(f,u.Position)+u.MarchRank*Config.RankSpacing)
                            f.Reforming=true
                        end
                    else
                        looseCount+=1;u.Formation=nil;u.Column=((looseCount*7)%9-4)*.35;u.FormationIndex=i
                        u.Escort=f.MeleeCount>0 and f or nil
                        u.LoosePath=f;u.LooseProgress=inside and 0 or pathProgress(f,u.Position)
                        u.DeployAt=self.Time+math.floor((looseCount-1)/Config.FormationColumns)*Config.RankSpacing/Config.Units.Archer.Speed
                    end
                    if inside then u.Position=points[1];self.Active[u.Id]=nil end
                    u.Heading=heading
                    if not inside then self.Active[u.Id]=u end
                    sent+=1
                end
                if orderedCount>0 then self.Formations[self.NextSquad]=f end
            end
        end
    end
    if sent==0 then return false,blockedReason or (self.Time<Config.PrepTime and 'Crossings stay closed during preparation, or no selected units are available.' or 'No available units or route to the target.') end
    return true,'Units sent: '..sent
end
function Engine:UpgradeCost(site)
    if site.Level>=3 then return nil end
    local result=roster()
    local remaining=Config.UpgradeCost[site.Level+1]
    local c=self:Counts(site)
    for _,kind in {'Peasant','Runner','Defender','Archer'} do
        result[kind]=math.min(c[kind],remaining)
        remaining-=result[kind]
    end
    return result,remaining==0
end
function Engine:Upgrade(side,id)
    local site=self.Sites[id]
    if not site or site.Owner~=side then return false,'You can only upgrade your own buildings.' end
    if self.Phase=='Waiting' or self.Phase=='Ended' then return false,'Upgrades are available during battle.' end
    if site.Level>=3 then return false,'Maximum level reached.' end
    if site.Kind=='Tower' and site.Health<=0 then return false,'Send troops to rebuild the tower.' end
    if site.UpgradeUntil then return false,'Construction is already in progress.' end
    local consume,affordable=self:UpgradeCost(site)
    if not affordable then return false,'The garrison needs '..Config.UpgradeCost[site.Level+1]..' units.' end
    local list=table.clone(site.Garrison)
    for _,kind in {'Peasant','Runner','Defender','Archer'} do
        local left=consume[kind]
        for _,unitId in list do
            local u=self.Units[unitId]
            if left>0 and u and u.Kind==kind then self:RemoveUnit(u); left-=1 end
        end
    end
    site.TrainClock=0
    site.UpgradeUntil=self.Time+Config.UpgradeDuration[site.Level+1]
    return true,'Upgrading to level '..(site.Level+1)
end
function Engine:SetSupply(side,id,targetId,reserve,filter)
    local site,target=self.Sites[id],self.Sites[targetId]
    if not site or site.Owner~=side then return false,'Select one of your buildings.' end
    if not targetId then site.Supply=nil return true,'Auto-supply disabled.' end
    if not target or target.Owner~=side or target==site then return false,'Select another friendly building to supply.' end
    if typeof(reserve)~='number' or reserve~=reserve then return false,'Set a reserve amount.' end
    filter=filter or 'All'
    if filter~='All' and not Config.Units[filter] then return false,'Invalid unit type.' end
    reserve=math.clamp(math.floor(reserve),0,400)
    local clock=site.Supply and site.Supply.Clock or 0
    site.Supply={Target=target.Id,Reserve=reserve,Filter=filter,Clock=clock}
    return true,'Supply line enabled.'
end
function Engine:RemoveUnit(u)
    self:Detach(u)
    self.Active[u.Id]=nil
    self.Units[u.Id]=nil
end
function Engine:Produce(dt)
    local waiting={}
    for _,u in self.Active do if u.State=='Overflow' then table.insert(waiting,u) end end
    table.sort(waiting,function(a,b)return a.Id<b.Id end)
    for _,u in waiting do
        local site=self.Sites[u.Target]
        if site and site.Owner==u.Side and self:Population(site)<self:Capacity(site) then self:Deposit(u,site)
        elseif site and site.Owner~=u.Side then
            u.State='Marching';u.Path={u.Position,site.Entrance or site.Position};u.PathIndex=2;u.Column=0
            local finish=site.Kind=='Tower' and site.Position or door(site)
            if length(u.Path[#u.Path],finish)>.01 then table.insert(u.Path,finish) end
        end
    end
    for _,site in self.Sites do
        if site.Owner==0 then continue end
        if site.Kind=='Tower' and site.Health<=0 then site.RecruitClock=0;continue end
        if site.UpgradeUntil then
            if self.Time>=site.UpgradeUntil then site.Level+=1 site.UpgradeUntil=nil end
            continue
        end
        if site.Kind=='Farm' then
            site.RecruitClock+=dt
            while site.RecruitClock+1e-7>=Config.Food.FarmInterval do
                site.RecruitClock-=Config.Food.FarmInterval
                self.Food[site.Owner]+=Config.Food.Production[site.Level]
            end
        elseif self:Population(site)<self:Capacity(site) and (site.Kind=='Village' or self.Food[site.Owner]>0) then
            local interval=site.Kind=='Village' and Config.VillageInterval[site.Level] or Config.RecruitInterval[site.Level]
            site.RecruitClock+=dt
            while site.RecruitClock>=interval and self:Population(site)<self:Capacity(site) do
                site.RecruitClock-=interval
                self:CreateUnit(Config.Buildings[site.Kind].Recruit,site.Owner,site)
            end
        else site.RecruitClock=0 end
        if site.Supply then
            local s=site.Supply
            local target=self.Sites[s.Target]
            if not target or target.Owner~=site.Owner then site.Supply=nil continue end
            s.Clock+=dt
            if s.Clock>=5 then
                s.Clock=0
                local list=self:Available(site,s.Filter)
                local excess=#list-s.Reserve
                if excess>0 then
                    self:Send(site.Owner,{site.Id},s.Target,math.min(100,(excess+.01)/#list*100),s.Filter,'Auto')
                end
            end
        end
    end
    for _,u in self.Units do
        if u.PendingTraining then
            local site=self.Sites[u.PendingTraining]
            if site and site.Owner==u.Side and u.Home==site.Id then self:TrainArrival(u,site) end
        end
    end
    self.FoodClock+=dt
    if self.FoodClock+1e-7>=Config.Food.ConsumptionInterval then
        self.FoodClock-=Config.Food.ConsumptionInterval
        local cost={0,0}
        for _,u in self.Units do if u.Side~=0 and u.Kind~='Peasant' then cost[u.Side]+=1 end end
        for side=1,2 do self.Food[side]=math.max(0,self.Food[side]-cost[side]) end
    end
end
function Engine:WakeGuards()
    for _,site in self.Sites do
        local tower=site.Kind=='Tower' and site.Health>0
        if site.Kind=='Tower' and not tower then continue end
        local closest,distance=nil,tower and Config.TowerRange[site.Level] or 29
        for _,u in self.Active do
            if u.Side~=site.Owner and not u.Dying and u.State~='Defending' and (site.Owner~=0 or tower or u.Target==site.Id) then
                local d=length(u.Position,site.Position)
                if d<distance then closest,distance=u,d end
            end
        end
        if closest then
            local dir=direction(site.Position,closest.Position);local archers={}
            for _,id in site.Garrison do
                local u=self.Units[id]
                if u and u.Kind=='Archer' and (u.State=='Garrison' or u.State=='Defending') then table.insert(archers,u) end
            end
            for i,u in archers do
                local column=((i-1)%Config.FormationColumns-(Config.FormationColumns-1)/2)*Config.FormationSpacing
                local row=math.floor((i-1)/Config.FormationColumns)*Config.RankSpacing
                if tower then
                    u.Position=site.Position+Vector3.new(column,0,row-1.2)
                    u.Height=Config.TowerRoofHeight[site.Level]
                else
                    -- Every incoming road ends at the front door; the rear emplacement is behind the model.
                    local rear=Config.GarrisonRear[site.Kind][site.Level]
                    u.Position=site.Position+Vector3.new(column,0,-rear-Config.RankSpacing-row)
                    u.Height=.25
                end
                u.State='Defending';u.Heading=dir;u.FormationIndex=i;u.Formation=nil;u.Squad=nil
                self.Active[u.Id]=u
            end
        else
            for _,id in site.Garrison do
                local u=self.Units[id]
                if u and u.State=='Defending' then
                    u.State='Garrison';u.Position=site.Position;u.Height=.25;u.Formation=nil;u.GuardDeparture=nil;u.ExitTravel=nil;u.DeployAt=nil;self.Active[id]=nil
                end
            end
        end
    end
end
function Engine:BuildSpatial()
    local spatial={}
    for _,u in self.Active do
        local key=math.floor(u.Position.X/24)..':'..math.floor(u.Position.Z/24)
        if not spatial[key] then spatial[key]={} end
        table.insert(spatial[key],u)
    end
    return spatial
end
function Engine:Protected(u)
    local home=u.Home and self.Sites[u.Home]
    return home and home.Owner==u.Side and u.State=='Defending' and u.Kind=='Archer'
        and (home.Kind~='Tower' or home.Health>0)
end
function Engine:NearestEnemy(u,spatial,range,pending)
    local cx,cz=math.floor(u.Position.X/24),math.floor(u.Position.Z/24)
    local steps=math.ceil(range/24)
    local best,distance=nil,range
    for x=cx-steps,cx+steps do for z=cz-steps,cz+steps do
        for _,v in (spatial[x..':'..z] or {}) do
            local rearSword=melee(u) and melee(v) and v.Formation and v.MarchRank~=0
            if v.Side~=u.Side and not rearSword and not self:Protected(v) and v.Health-(v.IncomingDamage or 0)>0 and not v.Dying and not pending[v.Id] then
                local d=length(u.Position,v.Position)
                if d<distance then best,distance=v,d end
            end
        end
    end end
    return best,distance
end
function Engine:Damage(u,amount,arrow)
    if arrow then amount*=1-(Config.Units[u.Kind].Shield or 0) end
    if (u.State=='Defending' or u.State=='Garrison') and u.Home then
        local home=self.Sites[u.Home]
        if home and home.Owner==u.Side and length(home.Position,u.Position)<=10 then amount*=1-Config.Defense[home.Level] end
    end
    return amount
end
local function sword(u) return u.Kind=='Defender' or u.Kind=='Runner' end
local function groupKey(u) return u.Side..':'..tostring(u.Squad or u.Home or u.Id) end
function Engine:OccupationBlocked(site)
    if site.Kind=='Tower' and site.Health>0 then return true end
    for _,id in site.Garrison do
        local u=self.Units[id]
        if u and u.Kind~='Archer' then return true end
    end
    return false
end
function Engine:GarrisonDefenders(site)
    local guards={}
    for _,id in site.Garrison do
        local u=self.Units[id]
        if u and u.Kind~='Archer' and u.State=='Garrison' and not u.Dying
            and u.Health-(u.IncomingDamage or 0)>0 then table.insert(guards,u) end
    end
    table.sort(guards,function(a,b)
        local x,y=Config.Units[a.Kind].Priority,Config.Units[b.Kind].Priority
        return x==y and a.Id<b.Id or x<y
    end)
    return guards
end
function Engine:GarrisonDistance(u,site)
    local f=u.Formation
    if f and f.Target==site.Id then
        return math.max(0,f.Length-f.Progress+(u.MarchRank or 0)*Config.RankSpacing-(site.Kind=='Tower' and Config.TowerRadius or 0))
    end
    local anchor=site.Kind=='Tower' and site.Position or door(site)
    return math.max(0,length(u.Position,anchor)-(site.Kind=='Tower' and Config.TowerRadius or 0))
end
function Engine:TowerTarget(u,range)
    local best,distance=nil,range+Config.TowerRadius
    for _,s in self.Sites do
        if s.Kind=='Tower' and s.Owner~=u.Side and s.Health>0 then
            local d=length(u.Position,s.Position)
            if d<distance then best,distance=s,d end
        end
    end
    return best,distance
end
function Engine:QueueHit(u,delay,kind,amount)
    table.insert(self.Impacts,{At=self.Time+delay,Unit=u.Id,Kind=kind,Amount=amount})
    if kind=='Kill' then u.Dying=true end
    if kind=='Damage'then u.IncomingDamage=(u.IncomingDamage or 0)+amount end
end
function Engine:ResolveImpacts()
    for i=#self.Impacts,1,-1 do
        local hit=self.Impacts[i]
        if hit.At>self.Time then continue end
        table.remove(self.Impacts,i)
        if hit.Tower then
            local tower=self.Sites[hit.Tower]
            if tower and tower.Owner==hit.Owner and tower.Health>0 then
                tower.Health=math.max(0,tower.Health-hit.Amount*(1-Config.Defense[tower.Level]))
                if tower.Health<=0 then
                    local list=table.clone(tower.Garrison)
                    for _,id in list do if self.Units[id] then self:RemoveUnit(self.Units[id]) end end
                    tower.UpgradeUntil=nil;tower.Supply=nil
                    table.insert(self.Events,{Type='Collapse',Site=tower.Id})
                end
            end
        else
            local u=self.Units[hit.Unit]
            if u then
                if hit.Kind=='Kill' then self:RemoveUnit(u)
                else u.IncomingDamage=math.max(0,(u.IncomingDamage or 0)-hit.Amount);u.Health-=hit.Amount;if u.Health<=0 then self:RemoveUnit(u) end end
            end
        end
    end
end
function Engine:MoveFormations(dt,spatial)
    for id,f in self.Formations do
        if f.Contact then
            local other=f.Contact.A==f and f.Contact.B or f.Contact.A
            local present=false
            for _,unitId in other.Ids do
                local u=self.Units[unitId]
                if u and u.Formation==other and melee(u) and not u.Dying then present=true;break end
            end
            if not present then clearContact(f) end
        end
        local live={};local speed=math.huge
        for _,unitId in f.Ids do
            local u=self.Units[unitId]
            if u and u.Formation==f and (u.State=='Marching' or u.State=='Deploying' or f.GuardHome and u.State=='Defending') and not u.Dying then
                table.insert(live,u);speed=math.min(speed,Config.Units[u.Kind].Speed)
            end
        end
        if #live==0 then
            clearContact(f)
            self.Formations[id]=nil
            if f.GuardHome and self.Sites[f.GuardHome].GuardFormation==f then self.Sites[f.GuardHome].GuardFormation=nil end
            continue
        end
        local columns=4
        for _,span in f.BridgeSpans do
            if f.Progress>=span[1]-22 and f.Progress<=span[2]+math.ceil(#live/2)*Config.RankSpacing+22 then columns=2;break end
        end
        local changed=columns~=f.Columns
        f.Columns=columns
        if changed or f.LiveCount~=#live or f.LayoutDirty then
            compact(f,live,changed or f.LayoutDirty)
            if f.LiveCount or changed then f.Reforming=true end
            f.LiveCount=#live;f.LayoutDirty=nil
        end
        f.Hold=false
        local advance=speed*dt
        local siegeGap=nil
        for _,u in live do
            if u.MarchRank~=0 or u.State=='Deploying' then continue end
            if f.ExitLength and f.Progress<f.ExitLength then continue end
            local range=melee(u) and Config.MeleeContact or Config.Units[u.Kind].Range
            local enemy,distance=self:NearestEnemy(u,spatial,12,{})
            local tower,towerDistance=self:TowerTarget(u,12)
            if enemy and (not tower or distance<=towerDistance) then
                f.Hold=true
                advance=math.min(advance,math.max(0,distance-range))
            elseif tower then
                f.Hold=true
                siegeGap=math.max(siegeGap or 0,towerDistance-range-Config.TowerRadius)
            end
        end
        if siegeGap then advance=math.min(advance,math.max(0,siegeGap)) end
        local destination=self.Sites[f.Target]
        if destination and destination.Owner~=f.Side and destination.Kind~='Tower' and self:OccupationBlocked(destination) then
            f.Hold=true
            advance=math.min(advance,math.max(0,f.Length-f.Progress-Config.MeleeContact))
        end
        if f.Contact then f.Hold=true;advance=0 end
        if f.Reforming then advance=0 end
        -- Combat closes the gap by advancing along the existing road.
        -- Every rank keeps its own position on that curved path; the army never straightens across the map.
        f.Progress+=advance
        if f.GuardHome then f.Progress=math.min(f.Progress,f.Length) end
        local center,_,heading=formationPoint(f,{MarchRank=0,MarchColumn=(columns+1)/2})
        f.RoadCenter=center;f.RoadHeading=heading
        local complete=true
        for _,u in live do
            local progress=f.Progress-u.MarchRank*Config.RankSpacing
            if u.State=='Deploying' then
                if progress<0 then continue end
                self:BeginDeparture(u)
                if f.ExitLength and progress>f.ExitLength then
                    local heading=direction(f.Path[1],f.Path[2])
                    u.ExitTravel=f.Path[2]+Vector3.new(-heading.Z,0,heading.X)*u.Column
                end
            end
            local target,index,facing,finished=formationPoint(f,u)
            local staging=f.Contact and melee(u) and u.MarchRank<=2
            if staging then
                local contactTarget,contactFacing=contactPoint(f,u)
                local blend=u.MarchRank==0 and 1 or (u.MarchRank==1 and .6 or .3)
                target=target:Lerp(contactTarget,blend);facing=facing:Lerp(contactFacing,blend).Unit;finished=false
            end
            if u.ExitTravel then
                target=u.ExitTravel;facing=direction(u.Position,target);finished=false
                if length(u.Position,target)<=Config.Units[u.Kind].Speed*dt then u.ExitTravel=nil end
            end
            if f.Reforming or u.ExitTravel or staging then
                local gap=length(u.Position,target)
                if gap>.04 then complete=false;u.Position+=direction(u.Position,target)*math.min(Config.Units[u.Kind].Speed*dt,gap)end
            else u.Position=target end
            u.Heading=facing;u.PathIndex=index;u.MarchFinished=finished and not f.Reforming
        end
        if f.Reforming and complete then f.Reforming=false end
    end
end
function Engine:Advance(u,dt,spatial)
    if u.State~='Marching' or u.Dying then return end
    if u.Formation then
        if not u.MarchFinished then return end
        local site=self.Sites[u.Target]
        if site.Owner==u.Side then if site.Kind=='Tower'and site.Health<=0 then site.Health=Config.TowerHealth end;self:Deposit(u,site)
        elseif not self:OccupationBlocked(site) then self:Capture(site,u.Side);self:Deposit(u,site)end
        return
    end
    if u.LoosePath then
        local path=u.LoosePath
        local progress=math.min(path.Length,u.LooseProgress+Config.Units[u.Kind].Speed*dt)
        if u.Escort then
            local f=u.Escort
            if self.Formations[u.Squad]~=f or not f.HasMelee then u.Escort=nil
            else progress=math.max(u.LooseProgress,math.min(progress,math.max(0,f.Progress-Config.RankSpacing))) end
        end
        local target,index,facing,finished=pathPoint(path,progress,u.Column)
        local gap=length(u.Position,target);local step=Config.Units[u.Kind].Speed*dt
        if gap>.001 then u.Position+=direction(u.Position,target)*math.min(step,gap) end
        if gap<=step+.001 then u.LooseProgress=progress end
        u.Heading=facing;u.PathIndex=index
        if finished and gap<=step+.001 then
            local site=self.Sites[u.Target]
            if site.Owner==u.Side then
                if site.Kind=='Tower' and site.Health<=0 then site.Health=Config.TowerHealth end
                self:Deposit(u,site)
            elseif not self:OccupationBlocked(site) then self:Capture(site,u.Side);self:Deposit(u,site) end
        end
        return
    end
    local waypoint=u.Path[u.PathIndex]
    if not waypoint then return end
    local d=direction(u.Path[u.PathIndex-1],waypoint)
    local destination=waypoint+Vector3.new(-d.Z,0,d.X)*u.Column
    local gap=length(u.Position,destination)
    u.Heading=direction(u.Position,destination)
    local step=math.min(Config.Units[u.Kind].Speed*dt,gap)
    -- A rear rank waits behind its own front rank instead of walking through it.
    local cx,cz=math.floor(u.Position.X/24),math.floor(u.Position.Z/24)
    for x=cx-1,cx+1 do for z=cz-1,cz+1 do
        for _,v in spatial[x..':'..z] or {} do
            if melee(u) and melee(v) and v~=u and v.Side==u.Side and v.Squad==u.Squad and v.State=='Marching'
                and (v.FormationIndex or v.Id)<(u.FormationIndex or u.Id) and math.abs((v.Column or 0)-(u.Column or 0))<.1 and v.PathIndex==u.PathIndex then
                local offset=flat(v.Position-u.Position)
                local forward=offset:Dot(u.Heading)
                local lateral=math.abs(offset:Dot(Vector3.new(-u.Heading.Z,0,u.Heading.X)))
                if forward>0 and forward<1.05 and lateral<.45 then step=math.min(step,math.max(0,forward-.95)) end
            end
        end
    end end
    u.Position+=u.Heading*step
    if gap<=step+.15 then
        if u.PathIndex<#u.Path then u.PathIndex+=1
        else
            local site=self.Sites[u.Target]
            if site.Owner==u.Side then
                if site.Kind=='Tower' and site.Health<=0 then site.Health=Config.TowerHealth end
                self:Deposit(u,site)
            elseif not self:OccupationBlocked(site) then self:Capture(site,u.Side);self:Deposit(u,site) end
        end
    end
end
function Engine:GarrisonSwing(site,attacker)
    local forward=attacker.Heading
    local from=attacker.Position+forward*Config.MeleeContact+Vector3.new(0,1.4,0)
    table.insert(self.Events,{Type='GarrisonSwing',Site=site.Id,From=from,To=attacker.Position+Vector3.new(0,1.4,0),Side=site.Owner})
end
function Engine:CombatGarrison(u,site,front,inFront,pending)
    local guards=self:GarrisonDefenders(site)
    if #guards==0 then return false end
    local distance=self:GarrisonDistance(u,site)
    local guardKey='garrison:'..site.Id
    if u.Kind=='Archer' then
        -- A bowman that reaches the door without an escort still loses to a melee defender immediately.
        if distance<=Config.MeleeContact+.15 and melee(guards[1]) then
            if self.Time+1e-7>=(self.RowReady[guardKey] or 0) then
                self.RowReady[guardKey]=self.Time+Config.MeleeInterval
                self:GarrisonSwing(site,u);self:QueueHit(u,Config.MeleeImpactDelay,'Kill');pending[u.Id]=true
            end
            return true
        end
        if site.Kind=='Tower' then return false end
        if distance<=Config.Units.Archer.Range+.15 then
            if u.Cooldown<=0 then
                local defender=guards[1]
                u.Cooldown=Config.ArcherInterval;u.AttackUntil=self.Time+.35
                self:QueueHit(defender,.3,'Damage',self:Damage(defender,Config.Units.Archer.Damage,true))
                table.insert(self.Events,{Type='Arrow',From=u.Position+Vector3.new(0,(u.Height or .25)+1.4,0),To=door(site)+Vector3.new(0,1.1,0),Side=u.Side})
            end
            return true
        end
        return false
    end
    if not inFront(u) or (u.Formation and u.Formation.Reforming) or distance>Config.MeleeContact+.15 then return false end
    local key=groupKey(u)
    if self.Time+1e-7<(self.RowReady[key] or 0) or self.Time+1e-7<(self.RowReady[guardKey] or 0) then return true end
    local attackers=sword(u) and front[key] or {u};local pairs={}
    for _,attacker in attackers do
        if #pairs>=#guards then break end
        if attacker.Target==site.Id and inFront(attacker) and not attacker.Dying and not pending[attacker.Id]
            and not attacker.ExitTravel and not (attacker.Formation and attacker.Formation.Reforming)
            and self:GarrisonDistance(attacker,site)<=Config.MeleeContact+.15 then
            table.insert(pairs,{attacker,guards[#pairs+1]})
        end
    end
    if #pairs==0 then return true end
    self.RowReady[key]=self.Time+Config.MeleeInterval;self.RowReady[guardKey]=self.Time+Config.MeleeInterval
    for _,pair in pairs do
        local attacker,defender=pair[1],pair[2]
        attacker.Cooldown=Config.MeleeInterval;attacker.AttackUntil=self.Time+.55
        if sword(attacker) then
            self:QueueHit(defender,Config.MeleeImpactDelay,'Kill');pending[defender.Id]=true
        else
            attacker.Cooldown=Config.Units[attacker.Kind].Interval
            self:QueueHit(defender,.3,'Damage',self:Damage(defender,Config.Units[attacker.Kind].Damage,false))
        end
        if sword(defender) then
            self:GarrisonSwing(site,attacker);self:QueueHit(attacker,Config.MeleeImpactDelay,'Kill');pending[attacker.Id]=true
        elseif self.Time+1e-7>=(defender.NextGuardAttack or 0) then
            defender.NextGuardAttack=self.Time+Config.Units[defender.Kind].Interval
            self:GarrisonSwing(site,attacker)
            self:QueueHit(attacker,.3,'Damage',self:Damage(attacker,Config.Units[defender.Kind].Damage,false))
        end
    end
    return true
end
function Engine:CombatAndMove(dt)
    self:ResolveImpacts()
    self:ReleaseArchers()
    local spatial=self:BuildSpatial()
    self:MoveFormations(dt,spatial);spatial=self:BuildSpatial()
    local pending={}
    local active={}
    for _,u in self.Active do table.insert(active,u) end
    table.sort(active,function(a,b)return a.Id<b.Id end)
    local front={}
    local meleeTargets={}
    for _,u in active do
        if sword(u) and not u.Dying then
            local key=groupKey(u);front[key]=front[key] or {}
            table.insert(front[key],u)
        end
    end
    for _,list in front do
        table.sort(list,function(a,b)return (a.FormationIndex or a.Id)<(b.FormationIndex or b.Id) end)
    end
    local function inFront(u)
        if u.Formation then return u.MarchRank==0 end
        local list=front[groupKey(u)]
        if not list then return true end
        local index=table.find(list,u)
        local columns=u.Formation and u.Formation.Columns or (self.Map.River and math.abs(u.Position.X)<17 and 2 or Config.FormationColumns)
        return index and index<=columns
    end
    -- Only the two front rows turn to face each other at a bend. Rear ranks keep following their road.
    for _,u in active do
        local f=u.Formation
        if not sword(u) or u.Dying or not f or f.Contact or not inFront(u) or u.ExitTravel then continue end
        if f.ExitLength and f.Progress<f.ExitLength then continue end
        local foe,gap=nil,Config.MeleeContact+.4
        for _,v in active do
            local other=v.Formation
            if sword(v) and not v.Dying and other and other~=f and not other.Contact and v.Side~=u.Side
                and inFront(v) and not v.ExitTravel and not self:Protected(v)
                and (not other.ExitLength or other.Progress>=other.ExitLength) then
                local d=length(u.Position,v.Position)
                if d<gap then foe=v;gap=d end
            end
        end
        if foe then
            local other=foe.Formation
            local a,b=f.RoadCenter,other.RoadCenter
            local contact={A=f,B=other,Center=(a+b)*.5,Axis=direction(a,b)}
            f.Contact=contact;other.Contact=contact
            f.Hold=true;other.Hold=true
        end
    end
    local function frontReady(f,list)
        if not f or not f.Contact then return true end
        if f.Reforming then return false end
        for _,u in list do if inFront(u) and not u.Dying then
            if u.ExitTravel or length(u.Position,contactPoint(f,u))>.06 then return false end
        end end
        return true
    end
    local function exchange(u,enemy)
        local a,b=groupKey(u),groupKey(enemy)
        if not inFront(enemy) or self.Time+1e-7<(self.RowReady[a] or 0) or self.Time+1e-7<(self.RowReady[b] or 0) then return end
        local left,right=front[a] or {},front[b] or {}
        if not frontReady(u.Formation,left) or not frontReady(enemy.Formation,right) then return end
        local pairs,claimed={},{}
        for _,v in left do if inFront(v) and not v.Dying and not pending[v.Id] then
            local target,gap=nil,Config.MeleeContact+.15
            for _,w in right do
                if inFront(w) and not w.Dying and not pending[w.Id] and not claimed[w.Id] and w.Health-(w.IncomingDamage or 0)>0 then
                    local d=length(v.Position,w.Position)
                    if d<=gap then target=w;gap=d end
                end
            end
            if target then table.insert(pairs,{v,target});claimed[target.Id]=true end
        end end
        if #pairs==0 then return end
        self.RowReady[a]=self.Time+Config.MeleeInterval;self.RowReady[b]=self.Time+Config.MeleeInterval
        for _,pair in pairs do for _,v in pair do
            v.AttackUntil=self.Time+.55
            self:QueueHit(v,Config.MeleeImpactDelay,'Kill');pending[v.Id]=true
        end end
    end
    for _,u in active do
        if not self.Units[u.Id] or u.Dying then continue end
        u.Cooldown=math.max(0,u.Cooldown-dt)
        local stats=Config.Units[u.Kind]
        local host=u.Home and self.Sites[u.Home]
        local mounted=host and host.Kind=='Tower' and host.Health>0
        if u.ExitTravel then
            if u.Formation then continue end
            local gap=length(u.Position,u.ExitTravel);u.Heading=direction(u.Position,u.ExitTravel)
            u.Position+=u.Heading*math.min(stats.Speed*dt,gap)
            if gap<=stats.Speed*dt+.04 then u.ExitTravel=nil end
            continue
        end
        if u.Formation and u.Formation.ExitLength and u.Formation.Progress-u.MarchRank*Config.RankSpacing<u.Formation.ExitLength then continue end
        if mounted and u.Kind~='Archer' then continue end
        local range=mounted and Config.TowerRange[host.Level] or (sword(u) and Config.MeleeContact or stats.Range)
        local enemy,dist=self:NearestEnemy(u,spatial,math.max(12,range),pending)
        if sword(u) and inFront(u)then
            local claimed=meleeTargets[u.Side]or {};meleeTargets[u.Side]=claimed
            local separate,separateDist=self:NearestEnemy(u,spatial,math.max(12,range),claimed)
            if separate and (separateDist<=range+.15 or dist>range+.15) then enemy,dist=separate,separateDist end
            if enemy and dist<=range+.15 then claimed[enemy.Id]=true end
        end
        local destination=u.Target and self.Sites[u.Target]
        if u.State=='Marching' and destination and destination.Owner~=u.Side
            and (not enemy or self:GarrisonDistance(u,destination)<=dist)
            and self:CombatGarrison(u,destination,front,inFront,pending) then continue end
        local tower,towerDist=self:TowerTarget(u,math.max(12,range))
        if tower and (not enemy or towerDist<dist) then
            u.Heading=direction(u.Position,tower.Position)
            if towerDist<=range+Config.TowerRadius+.15 and (u.Kind=='Archer' or inFront(u)) then
                if u.Cooldown<=0 then
                    u.Cooldown=u.Kind=='Archer' and (mounted and Config.TowerInterval[host.Level] or Config.ArcherInterval) or Config.MeleeInterval
                    u.AttackUntil=self.Time+.55
                    table.insert(self.Impacts,{At=self.Time+(u.Kind=='Archer' and .3 or Config.MeleeImpactDelay),Tower=tower.Id,Owner=tower.Owner,Amount=u.Kind=='Archer' and Config.ArrowTowerDamage or Config.SwordTowerDamage})
                    if u.Kind=='Archer' then table.insert(self.Events,{Type='Arrow',From=u.Position+Vector3.new(0,(u.Height or .25)+1.4,0),To=tower.Position+Vector3.new(0,6,0),Side=u.Side}) end
                end
                continue
            elseif not mounted and u.Kind~='Archer' and not (u.Formation and u.Formation.Hold) and not (u.Kind=='Peasant' and u.Formation and u.Formation.HasMelee) and inFront(u)then
                u.Position+=u.Heading*math.min(stats.Speed*dt,math.max(0,towerDist-range-Config.TowerRadius));continue
            end
        end
        if enemy then
            u.Heading=direction(u.Position,enemy.Position)
            if dist<=range+.15 and (not sword(u) or inFront(u)) then
                if u.Cooldown<=0 then
                    if u.Kind=='Archer' then
                        u.Cooldown=mounted and Config.TowerInterval[host.Level] or Config.ArcherInterval
                        u.AttackUntil=self.Time+.35
                        self:QueueHit(enemy,.3,'Damage',self:Damage(enemy,stats.Damage,true));pending[enemy.Id]=enemy.Health<=(enemy.IncomingDamage or 0)
                        table.insert(self.Events,{Type='Arrow',From=u.Position+Vector3.new(0,(u.Height or .25)+1.4,0),To=enemy.Position+Vector3.new(0,(enemy.Height or .25)+1.1,0),Side=u.Side})
                    elseif sword(u) and sword(enemy) then
                        exchange(u,enemy)
                    elseif sword(u) then
                        u.Cooldown=Config.MeleeInterval;u.AttackUntil=self.Time+.55
                        self:QueueHit(enemy,Config.MeleeImpactDelay,'Kill');pending[enemy.Id]=true
                    else
                        u.Cooldown=stats.Interval;u.AttackUntil=self.Time+.3
                        self:QueueHit(enemy,.3,'Damage',self:Damage(enemy,stats.Damage,false))
                    end
                end
                continue
            elseif not mounted and u.Kind~='Archer' and not (u.Formation and u.Formation.Hold) and not (u.Kind=='Peasant' and u.Formation and u.Formation.HasMelee) and inFront(u) and u.State~='Overflow' and (u.State~='Defending' or length(host.Position,enemy.Position)<29) then
                -- Melee fighters close the last gap. Archers only advance on their road.
                u.Position+=u.Heading*math.min(stats.Speed*dt,math.max(0,dist-range))
                continue
            end
        end
        if not mounted then self:Advance(u,dt,spatial) end
        if u.State=='Overflow' then
            local site=self.Sites[u.Target]
            if site and site.Owner==u.Side and self:Population(site)<self:Capacity(site) then self:Deposit(u,site) end
        end
    end
end
function Engine:BotPower(site,filter)
    local power=0
    for _,u in self:Available(site,filter or 'All') do power+=({Peasant=.2,Defender=1.2,Archer=.9,Runner=.75})[u.Kind] end
    return power
end
function Engine:Bot()
    local owned={}
    for _,site in self.Sites do if site.Owner==2 then table.insert(owned,site) end end
    local foodDemand,foodIncome,farm=0,0,nil
    for _,u in self.Units do if u.Side==2 and u.Kind~='Peasant' then foodDemand+=1 end end
    for _,s in owned do
        if s.Kind=='Farm' then
            foodIncome+=Config.Food.Production[s.Level]*Config.Food.ConsumptionInterval/Config.Food.FarmInterval
            if s.Level<3 and not s.UpgradeUntil then farm=s end
        end
    end
    local farmVillage=nil
    if farm and self.Difficulty~='Easy' and (foodDemand>foodIncome or self.Food[2]<foodDemand) then
        local nearest=math.huge
        for _,s in owned do if s.Kind=='Village' then local d=length(s.Position,farm.Position);if d<nearest then nearest=d;farmVillage=s.Id end end end
    end
    -- Supply routes use earned villagers and the same queues as the human player.
    for _,site in owned do
        if site.Kind=='Village' and self:Counts(site).Peasant>=12 then
            local best,score=nil,math.huge
            for _,target in owned do
                if Config.Buildings[target.Kind].Recruit and target.Kind~='Village' and target.Id~=site.Id then
                    local d=length(site.Position,target.Position)+self:Population(target)*1.2
                    if d<score then best,score=target,d end
                end
            end
            if site.Id==farmVillage then best=farm end
            if best then self:SetSupply(2,site.Id,best.Id,6,'Peasant') end
        end
    end
    local missions={}
    for _,site in self.Sites do
        if site.Owner==2 then continue end
        if self.Time<Config.PrepTime and site.Zone~=2 then continue end
        local assigned=0
        for _,u in self.Units do if u.Side==2 and u.Target==site.Id and (u.State=='Marching' or u.State=='Deploying') then assigned+=({Peasant=.2,Defender=1.2,Archer=.9,Runner=.75})[u.Kind] end end
        local defense=self:BotPower(site)*(1+Config.Defense[site.Level])
        if assigned>defense*1.2+4 then continue end
        local value=site.Kind=='Village' and 95 or (site.Kind=='Tower' and 74 or 68)
        if site.Zone==2 then value+=25 end
        if site.Owner==1 then value+=8 end
        local supply=self.Difficulty=='Hard' and site.Supply and 30 or 0
        table.insert(missions,{Site=site,Defense=defense,Value=value+supply})
    end
    table.sort(missions,function(a,b) return a.Value>b.Value end)
    for _,mission in missions do
        local target=mission.Site
        local sources={}
        for _,site in owned do
            local path=self:RouteForSide(2,site.Id,target.Id,'Auto')
            local power=self:BotPower(site)
            if path and power>5 then table.insert(sources,{Site=site,Power=power,Distance=length(site.Position,target.Position)}) end
        end
        table.sort(sources,function(a,b) return a.Distance<b.Distance end)
        local selected,total,fullPower={},0,0
        for _,source in sources do
            table.insert(selected,source.Site.Id)
            total+=source.Power*.65
            fullPower+=source.Power
            if total>mission.Defense*1.4+5 then break end
        end
        if total>mission.Defense*1.4+5 and #selected>0 then
            local share=math.clamp((mission.Defense*1.4+9)/fullPower*100,20,65)
            self:Send(2,selected,target.Id,share,'All','Auto')
            self.LastBotTarget=target.Id
            break
        end
    end
    -- Upgrade only with a reserve and no nearby assault; no extra resources.
    for _,site in owned do
        if site.Level>=3 or site.UpgradeUntil then continue end
        local cost=Config.UpgradeCost[site.Level+1]
        if self:Population(site)<cost+(site.Kind=='Farm' and 0 or 25) then continue end
        local threatened=false
        for _,u in self.Active do if u.Side==1 and length(u.Position,site.Position)<38 then threatened=true break end end
        if not threatened then self:Upgrade(2,site.Id) break end
    end
end
function Engine:CheckVictory()
    local alive={[1]=false,[2]=false}
    for _,site in self.Sites do if site.Owner~=0 then alive[site.Owner]=true end end
    for _,u in self.Units do if u.Side~=0 then alive[u.Side]=true end end
    if not alive[1] or not alive[2] then
        self.Phase='Ended'
        self.Winner=alive[1] and 1 or (alive[2] and 2 or 0)
    end
end
function Engine:Step(dt,skipBot)
    if self.Phase=='Waiting' or self.Phase=='Ended' then return end
    self.Time+=dt
    if self.Time>=Config.PrepTime then self.Phase='Battle' end
    self:Produce(dt)
    self:WakeGuards()
    self:CombatAndMove(dt)
    self.BotClock+=dt
    if self.BotClock>=(Config.BotInterval[self.Difficulty] or 2.5) and not skipBot then self.BotClock=0;self:Bot() end
    self:CheckVictory()
end
function Engine:Snapshot()
    local sites,units,totals={}, {},{roster(),roster()}
    local owned={0,0}
    for _,site in self.Sites do
        local counts=self:Counts(site,true)
        local inside=self:Counts(site)
        sites[site.Id]={Owner=site.Owner,Level=site.Level,Counts=counts,Inside=inside,Population=self:Population(site),Capacity=self:Capacity(site),Upgrade=site.UpgradeUntil and math.max(0,site.UpgradeUntil-self.Time),Supply=site.Supply and {Target=site.Supply.Target,Reserve=site.Supply.Reserve,Filter=site.Supply.Filter},Health=site.Health}
        if site.Owner~=0 then owned[site.Owner]+=1 end
    end
    for _,u in self.Units do
        if u.Side~=0 then totals[u.Side][u.Kind]+=1 end
        if self.Active[u.Id] then
            table.insert(units,{u.Id,u.Kind,u.Side,u.Position.X,u.Position.Z,u.Health,u.Heading.X,u.Heading.Z,self.Time<u.AttackUntil,u.State,u.Height or .25})
        end
    end
    local events=self.Events
    self.Events={}
    return {Time=self.Time,Phase=self.Phase,Winner=self.Winner,Sites=sites,Units=units,Totals=totals,Owned=owned,Events=events,Difficulty=self.Difficulty,Map=self.Map.Definition,Food={self.Food[1],self.Food[2]}}
end
return Engine
