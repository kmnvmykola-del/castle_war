-- Focused regression checks for ownership gates, departure queues and combat ranks.
local rs=game.ReplicatedStorage
local q=Instance.new('Folder');q.Name='Version07QA';q.Parent=rs
for _,name in {'Config','MapNetwork','MapData','Engine'} do rs.Kingdoms[name]:Clone().Parent=q end
local C=require(q.Config);local N=require(q.MapNetwork);local E=require(q.Engine)
local report={}
local function empty(map)
    local g=E.new(map);g:Start();g.Time=61;g.Phase='Battle'
    local list={};for _,u in g.Units do table.insert(list,u) end
    for _,u in list do g:RemoveUnit(u) end
    return g
end
local function tick(g,seconds,guards)
    for _=1,math.floor(seconds*10+.5) do
        g.Time+=.1;if guards then g:WakeGuards() end;g:CombatAndMove(.1)
    end
end
local ok,err=pcall(function()
    assert(C.MeleeInterval==1 and C.MeleeImpactDelay==.25 and C.ArcherInterval==2)
    local chain={River=false,Nodes={
        {Id='A',Kind='Castle',X=-6,Z=0,Owner=1},
        {Id='V',Kind='Village',X=-4,Z=0,Owner=0},
        {Id='B',Kind='Village',X=-2,Z=0,Owner=0},
        {Id='C',Kind='Castle',X=2,Z=0,Owner=2},
    },Roads={{'A','V'},{'V','B'},{'B','C'}}}
    local map=assert(N.Create(chain));local g=empty(map)
    local u=g:CreateUnit('Peasant',1,g.Sites.A)
    assert(map.Route('A','B',true),'Geometry should still validate independently of owners')
    local allowed,reason=g:Send(1,{'A'},'B',100,'All','Auto')
    assert(not allowed and reason:find('intermediate') and reason:find('alternative'))
    assert(u.State=='Garrison' and u.Home=='A' and #g:Snapshot().Units==0)
    g.Sites.V.Owner=2;assert(not g:RouteForSide(1,'A','B'))
    assert(g:RouteForSide(1,'A','V'),'Enemy final destination must be attackable')
    g:Capture(g.Sites.V,1);assert(g:RouteForSide(1,'A','B'))
    g:Capture(g.Sites.V,0);assert(not g:RouteForSide(1,'A','B'),'Ownership changes must not use a stale cached route')
    table.insert(chain.Nodes,{Id='J1',Kind='Junction',X=-6,Z=2})
    table.insert(chain.Nodes,{Id='J2',Kind='Junction',X=-2,Z=2})
    table.insert(chain.Roads,{'A','J1'});table.insert(chain.Roads,{'J1','J2'});table.insert(chain.Roads,{'J2','B'})
    map=assert(N.Create(chain));g=empty(map)
    local path,ids=g:RouteForSide(1,'A','B')
    assert(path and not table.find(ids,'V') and table.find(ids,'J1'))
    report.ownership={neutralAndEnemyBlock=true,finalTargetAllowed=true,alternative=ids,cacheUpdates=true}

    g=empty();for _,site in g.Sites do site.Owner=1;site.Level=3 end
    local source=g.Sites.ACastle
    for _=1,200 do g:CreateUnit('Defender',1,source) end
    for _=1,60 do g:CreateUnit('Peasant',1,source) end
    for _=1,40 do g:CreateUnit('Archer',1,source) end
    local origin=source.Position+C.DoorOffsets.Castle[3]
    assert(g:Send(1,{source.Id},'BCastle',100,'All','Auto'))
    assert(#g:Snapshot().Units==0 and #g:Available(source,'All')==0)
    assert(g:Population(source)==300,'People waiting to leave still occupy the garrison')
    assert(not g:Send(1,{source.Id},'AFarm',100,'All','Auto'),'A queued unit was sent twice')
    local visible={};local births=0;local maxBirthGap=0
    for _=1,50 do
        tick(g,.1)
        for id,unit in g.Active do if not visible[id] then
            local gap=(unit.Position-origin).Magnitude
            maxBirthGap=math.max(maxBirthGap,gap)
            assert(gap<1.1,'Unit materialized outside its front door: '..gap)
            visible[id]=true;births+=1
        end end
        for _,unit in g.Units do if unit.State=='Deploying' then
            assert(unit.Home==source.Id and not g.Active[unit.Id])
        end end
    end
    assert(births>40 and births<300 and g:Population(source)>0,'The large army did not leave progressively')
    tick(g,225)
    local marching=0;for _,unit in g.Units do if unit.State=='Marching' or unit.State=='Deploying' then marching+=1 end end
    assert(marching==0 and g:Population(g.Sites.BCastle)==300)
    report.departures={people=300,initialVisible=0,bornInFirstFiveSeconds=births,maxDoorDistance=maxBirthGap,allArrived=true,noDuplicateOrders=true}

    -- Two full formations meet on a straight road; rear ranks must follow the actual front.
    local duel={River=false,Nodes={
        {Id='L',Kind='Castle',X=-4,Z=0,Owner=1},
        {Id='R',Kind='Castle',X=4,Z=0,Owner=2},
    },Roads={{'L','R'}}}
    g=empty(assert(N.Create(duel)))
    for side=1,2 do for _=1,40 do g:CreateUnit('Defender',side,g.Sites[side==1 and 'L' or 'R']) end end
    assert(g:Send(1,{'L'},'R',100,'All','Auto'));assert(g:Send(2,{'R'},'L',100,'All','Auto'))
    local held=false;local secondRankGap=nil;local firstLoss=nil;local losses={}
    for _=1,700 do
        tick(g,.1)
        local count={0,0};for _,unit in g.Units do count[unit.Side]+=1 end
        if count[1]<40 then firstLoss=firstLoss or g.Time end
        if firstLoss and #losses<5 then
            local last=losses[#losses]
            if not last or last.count~=count[1] then table.insert(losses,{at=g.Time,count=count[1]}) end
        end
        for _,f in g.Formations do if f.Hold then
            held=true
            local rows={};for _,unit in g.Active do if unit.Formation==f and not unit.Dying then
                rows[unit.MarchColumn]=rows[unit.MarchColumn] or {};rows[unit.MarchColumn][unit.MarchRank]=unit
            end end
            for _,lane in rows do if lane[0] and lane[1] and firstLoss and g.Time>firstLoss+3 then
                local gap=(lane[0].Position-lane[1].Position).Magnitude
                assert(gap<3,'Rear fighters stayed far from the fighting row: '..gap)
                secondRankGap=math.max(secondRankGap or 0,gap)
            end end
        end end
        assert(count[1]==count[2],'Sword exchange lost symmetric casualties')
        if firstLoss and g.Time>firstLoss+8 then break end
    end
    assert(held and firstLoss and secondRankGap and #losses==5)
    for i=2,#losses do assert(losses[i].at-losses[i-1].at<1.7,'Melee exchanges did not speed up') end
    report.combat={rearGap=secondRankGap,firstFiveLosses=losses,interval=1,impactDelay=.25}

    -- Defensive melee fighters remain inside, rather than deploying automatically.
    g=empty();local village=g.Sites.AVillage1;village.Owner=1
    for _=1,80 do g:CreateUnit('Defender',1,village) end
    local enemy=g:CreateUnit('Defender',2,g.Sites.BCastle);g:Detach(enemy)
    enemy.State='Marching';enemy.Target=village.Id;enemy.Position=village.Entrance+Vector3.new(0,0,18)
    enemy.Path={enemy.Position,enemy.Position};enemy.PathIndex=2;enemy.Column=0;g.Active[enemy.Id]=enemy
    g:WakeGuards();assert(#g:Snapshot().Units==1,'The whole garrison appeared outside at once')
    local guardDoor=village.Position+C.DoorOffsets.Village;local guardsSeen={};local guardBirths=0
    for _=1,25 do
        tick(g,.1,true)
        for id,unit in g.Active do if unit.Side==1 and not guardsSeen[id] then
            assert((unit.Position-guardDoor).Magnitude<1.1,'A guard appeared behind the building')
            guardsSeen[id]=true;guardBirths+=1
        end end
    end
    assert(guardBirths==0 and g:Population(village)==80)
    for _,id in village.Garrison do assert(g.Units[id].State=='Garrison' and not g.Active[id]) end
    report.guards={inside=80,visibleAfter2point5Seconds=guardBirths,meleeStaysInside=true}
end)
q:Destroy();if not ok then error(err) end
return report
