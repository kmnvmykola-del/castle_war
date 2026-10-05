-- Behavior checks for archer escorts and combat against hidden garrisons. Run in Studio Play on Server.
local q=Instance.new('Folder');q.Name='Version09QA';q.Parent=game.ReplicatedStorage
for _,name in {'Config','MapNetwork','MapData','Engine'} do game.ReplicatedStorage.Kingdoms[name]:Clone().Parent=q end
local C=require(q.Config);local N=require(q.MapNetwork);local E=require(q.Engine)
local report={passed=0,failed=0,cases={}}
local function test(name,fn)
    local started=os.clock();local ok,result=pcall(fn)
    report[ok and 'passed' or 'failed']+=1
    report.cases[name]={passed=ok,result=ok and result or tostring(result),seconds=os.clock()-started}
end
local function arena(kind,owner)
    local map=assert(N.Create({River=false,Nodes={{Id='L',Kind='Castle',X=-5,Z=0,Owner=1},{Id='V',Kind=kind or 'Village',X=-1,Z=-2,Owner=owner or 2},{Id='R',Kind='Castle',X=5,Z=0,Owner=2}},Roads={{'L','V'},{'V','R'}}}))
    local g=E.new(map);g:Start();g.Time=61;g.Phase='Battle'
    local old={};for _,u in g.Units do table.insert(old,u) end
    for _,u in old do g:RemoveUnit(u) end
    return g
end
local function tick(g)
    g.Time+=.1;g:WakeGuards();g:CombatAndMove(.1)
end
local function count(g,side,kind)
    local n=0;for _,u in g.Units do if u.Side==side and (not kind or u.Kind==kind) then n+=1 end end;return n
end
local function add(g,site,kind,side,n)
    local list={};for _=1,n do table.insert(list,g:CreateUnit(kind,side,g.Sites[site])) end;return list
end
test('Bows follow the front through bends, then continue when all melee escorts die',function()
    local g=arena('Farm',1);add(g,'L','Defender',1,20);add(g,'L','Peasant',1,12);local bows=add(g,'L','Archer',1,8)
    assert(g:Send(1,{'L'},'V',100,'All','Auto'))
    local samples,bends=0,{}
    for _=1,280 do
        tick(g)
        for _,bow in bows do if bow.State=='Marching' and bow.Escort then
            local f=bow.Escort
            if f.Progress>(f.ExitLength or 0)+C.RankSpacing+1 then
                assert(bow.LooseProgress<=f.Progress-C.RankSpacing+.16,'A bow overtook its own front row')
                local ahead=(bow.Position-f.RoadCenter):Dot(f.RoadHeading)
                assert(ahead<.25,'A bow moved ahead of the physical front at a bend')
                assert(not bow.Formation,'A bow was locked into a melee column')
                samples+=1;bends[bow.PathIndex]=true
            end
        end end
    end
    assert(samples>100 and #g.Sites.V.Garrison==0,'Test did not exercise the route before arrival')
    local visited=0;for _ in bends do visited+=1 end;assert(visited>=3,'No road bends were exercised')
    local dead={};for _,u in g.Units do if u.Kind=='Defender' then table.insert(dead,u) end end
    for _,u in dead do g:RemoveUnit(u) end
    local previous={}
    for _=1,1300 do
        for _,bow in bows do previous[bow.Id]=bow.Position end
        tick(g)
        for _,bow in bows do if bow.State=='Marching' then
            assert((bow.Position-previous[bow.Id]).Magnitude<=C.Units.Archer.Speed*.1+.02,'A bow teleported after losing its escort')
        end end
        if g:Population(g.Sites.V)==20 then break end
    end
    assert(g:Counts(g.Sites.V).Archer==8 and g:Counts(g.Sites.V).Peasant==12)
    for _,bow in bows do assert(bow.Home=='V' and not bow.Escort and not g.Active[bow.Id]) end
    return {samples=samples,roadSegmentsVisited=visited,allEightBowsArrived=true,peasantsArrived=12}
end)
test('An archer-only squad arrives without waiting for nonexistent swordsmen',function()
    local g=arena('Farm',1);local bows=add(g,'L','Archer',1,8)
    assert(g:Send(1,{'L'},'V',100,'All','Auto'))
    for _=1,1400 do tick(g);if g:Population(g.Sites.V)==8 then break end end
    for _,bow in bows do assert(bow.State=='Garrison' and bow.Home=='V' and not bow.Escort) end
    return 'All eight bows arrived and entered the garrison'
end)
test('Surviving archers finish a real building attack after all their swordsmen fall',function()
    local g=arena();add(g,'L','Defender',1,12);local bows=add(g,'L','Archer',1,4)
    add(g,'V','Defender',2,20);local protected=add(g,'V','Archer',2,4)
    for _,bow in protected do bow.Cooldown=10000 end
    assert(g:Send(1,{'L'},'V',100,'All','Auto'))
    local lostEscort=false
    for _=1,2200 do
        tick(g)
        if count(g,1,'Defender')==0 then lostEscort=true end
        for _,bow in bows do assert(g.Units[bow.Id] and bow.Health==45,'A bow took the first melee blow through its escort') end
        if g.Sites.V.Owner==1 and g:Population(g.Sites.V)==4 then break end
    end
    assert(lostEscort and g.Sites.V.Owner==1 and g:Population(g.Sites.V)==4 and count(g,2)==0)
    return 'Twelve swordsmen fell; four archers continued firing, advanced and occupied the village'
end)
test('A village exchanges four simultaneous melee pairs while every melee guard remains hidden',function()
    local g=arena();add(g,'L','Defender',1,20);local guards=add(g,'V','Defender',2,12);local bows=add(g,'V','Archer',2,4)
    for _,bow in bows do bow.Cooldown=10000 end
    assert(g:Send(1,{'L'},'V',100,'All','Auto'))
    local previousLeft,previousRight=20,12;local waves={};local exposedBows=false
    for _=1,1400 do
        tick(g)
        for _,guard in guards do if g.Units[guard.Id] then
            assert(guard.State=='Garrison' and not g.Active[guard.Id] and guard.Home=='V','A melee guard left its building')
        end end
        if g.Sites.V.Owner==2 then for _,bow in bows do
            assert(g.Units[bow.Id] and not bow.Dying and bow.Health==45,'A protected bow was harmed before capture')
            if bow.State=='Defending' then
                exposedBows=true;assert(g:Protected(bow) and bow.Position.Z<g.Sites.V.Position.Z-C.GarrisonRear.Village[1])
            end
        end end
        local left,right=count(g,1,'Defender'),count(g,2,'Defender')
        if right<previousRight then
            assert(previousLeft-left==4 and previousRight-right==4,'The building fought fewer than four simultaneous pairs')
            table.insert(waves,g.Time);previousLeft,previousRight=left,right
        end
        if g.Sites.V.Owner==1 and g:Population(g.Sites.V)==8 then break end
    end
    assert(exposedBows and #waves==3 and g.Sites.V.Owner==1 and g:Population(g.Sites.V)==8 and count(g,2)==0)
    for i=2,#waves do assert(waves[i]-waves[i-1]>=.9 and waves[i]-waves[i-1]<1.7,'Garrison exchanges stalled') end
    return {waves=waves,simultaneousPairs=4,hiddenDefenders=12,survivorsInside=8,protectedBowsFellAtCapture=4}
end)
test('Protected bows shoot from behind the model and cannot be selected as targets',function()
    local g=arena();add(g,'V','Defender',2,4);local bow=add(g,'V','Archer',2,1)[1]
    local enemy=add(g,'L','Defender',1,1)[1];g:Detach(enemy)
    enemy.Position=g.Sites.V.Entrance+Vector3.new(0,0,1);enemy.State='Marching';enemy.Target='V'
    enemy.Path={enemy.Position,enemy.Position};enemy.PathIndex=2;enemy.Column=0;enemy.Cooldown=1000;g.Active[enemy.Id]=enemy
    tick(g)
    assert(bow.State=='Defending' and g:Protected(bow) and bow.Position.Z<g.Sites.V.Position.Z)
    local target=g:NearestEnemy(enemy,g:BuildSpatial(),100,{})
    assert(not target,'An attacker targeted a protected guard bow')
    local shot=false;for _,event in g.Events do if event.Type=='Arrow' and event.Side==2 then shot=true end end
    assert(shot,'The protected bow did not shoot')
    for _=1,4 do tick(g) end;assert(enemy.Health<100 and enemy.Health>0)
    g:RemoveUnit(enemy);g:WakeGuards();assert(bow.State=='Garrison' and not g.Active[bow.Id])
    return 'Protected shot landed; the bow returned inside after the threat disappeared'
end)
test('A building containing only protected archers is still capturable',function()
    local g=arena('Archery');add(g,'L','Defender',1,8);local bows=add(g,'V','Archer',2,4)
    for _,bow in bows do bow.Cooldown=10000 end
    assert(g:Send(1,{'L'},'V',100,'All','Auto'))
    for _=1,1400 do tick(g);if g.Sites.V.Owner==1 and g:Population(g.Sites.V)==8 then break end end
    assert(g.Sites.V.Owner==1 and g:Population(g.Sites.V)==8 and count(g,2)==0)
    for _,bow in bows do assert(not g.Units[bow.Id]) end
    return 'Eight attackers occupied the archery; its four protected archers fell at capture'
end)
test('Tower melee guards exchange losses inside before the remaining attackers destroy the walls',function()
    local g=arena('Tower');add(g,'L','Defender',1,8);local guards=add(g,'V','Defender',2,4);local bows=add(g,'V','Archer',2,4)
    for _,bow in bows do bow.Cooldown=10000 end
    assert(g:Send(1,{'L'},'V',100,'All','Auto'))
    local firstLoss=false;local collapsed=false
    for _=1,1600 do
        tick(g)
        for _,guard in guards do if g.Units[guard.Id] then assert(guard.State=='Garrison' and not g.Active[guard.Id]) end end
        if not firstLoss and count(g,2,'Defender')==0 then
            firstLoss=true;assert(count(g,1)==4 and g.Sites.V.Health==100,'Sword losses did not occur before wall damage')
        end
        if g.Sites.V.Owner==2 and g.Sites.V.Health>0 then for _,bow in bows do
            assert(g.Units[bow.Id] and bow.Health==45)
            if bow.State=='Defending' then assert(bow.Height==C.TowerRoofHeight[1] and g:Protected(bow)) end
        end end
        for _,event in g.Events do if event.Type=='Collapse' then collapsed=true end end;g.Events={}
        if g.Sites.V.Owner==1 and g:Population(g.Sites.V)==4 then break end
    end
    assert(firstLoss and collapsed and g.Sites.V.Owner==1 and g.Sites.V.Health==100 and g:Population(g.Sites.V)==4)
    return {hiddenGuards=4,mutualLosses=4,wallCollapsed=true,restoredHealth=100,survivors=4}
end)
test('Attacking archers can damage hidden ordinary defenders and eventually occupy the building',function()
    local g=arena('Barracks');add(g,'V','Defender',2,4);add(g,'L','Archer',1,8)
    assert(g:Send(1,{'L'},'V',100,'All','Auto'))
    local hits=false
    for _=1,1800 do
        tick(g)
        for _,id in g.Sites.V.Garrison do local u=g.Units[id];if u and u.Side==2 then
            assert(u.State=='Garrison' and not g.Active[id]);if u.Health<100 then hits=true end
        end end
        if g.Sites.V.Owner==1 and g:Population(g.Sites.V)==8 then break end
    end
    assert(hits and g.Sites.V.Owner==1 and g:Counts(g.Sites.V).Archer==8 and count(g,2)==0)
    return 'Hidden defenders took arrow damage; eight surviving attackers occupied the barracks'
end)
test('An exposed archer at the door loses immediately to an internal swordsman',function()
    local g=arena('Barracks');local guard=add(g,'V','Defender',2,1)[1];local bow=add(g,'L','Archer',1,1)[1]
    g:Detach(bow);bow.Position=g.Sites.V.Position+C.DoorOffsets.Barracks+Vector3.new(0,0,.6)
    bow.State='Marching';bow.Target='V';bow.Path={bow.Position,bow.Position};bow.PathIndex=2;bow.Column=0;bow.Cooldown=10000;g.Active[bow.Id]=bow
    for _=1,5 do tick(g) end
    assert(not g.Units[bow.Id] and g.Units[guard.Id] and not g.Active[guard.Id])
    return 'The unescorted archer fell to the first garrison swing'
end)
test('Sending a protected guard archer redeploys it from the front door',function()
    local g=arena('Barracks');local bow=add(g,'V','Archer',2,1)[1]
    local enemy=add(g,'L','Defender',1,1)[1];g:Detach(enemy)
    enemy.Position=g.Sites.V.Entrance+Vector3.new(0,0,2);enemy.State='Overflow';enemy.Target='V';g.Active[enemy.Id]=enemy
    g:WakeGuards();assert(bow.State=='Defending' and g:Protected(bow))
    assert(g:Send(2,{'V'},'R',100,'All','Auto'))
    assert(bow.State=='Deploying' and not g.Active[bow.Id] and bow.Home=='V' and not g:Protected(bow))
    g:RemoveUnit(enemy);local appeared=false
    for _=1,1800 do
        tick(g)
        if not appeared and g.Active[bow.Id] then
            appeared=true;assert((bow.Position-(g.Sites.V.Position+C.DoorOffsets.Barracks)).Magnitude<1.1,'The bow appeared behind its building on departure')
        end
        if bow.Home=='R' then break end
    end
    assert(appeared and bow.Home=='R' and bow.State=='Garrison')
    return 'The protected bow returned inside, emerged from the door and reached its destination'
end)
test('A reinforcement waiting outside a lost building can reach the new hidden garrison',function()
    local g=arena('Village',1)
    add(g,'V','Archer',1,80);local u=add(g,'L','Defender',1,1)[1];g:Deposit(u,g.Sites.V)
    assert(u.State=='Overflow');g:Capture(g.Sites.V,2);g:Produce(.1)
    assert(u.State=='Marching' and #u.Path==3,'The reinforcement path stopped at the old outer entrance')
    for _=1,400 do tick(g);if g.Sites.V.Owner==1 and u.Home=='V' then break end end
    assert(g.Sites.V.Owner==1 and u.Home=='V')
    return 'The waiting survivor advanced to the door and recaptured the building'
end)
test('A ruined tower recruits nobody until it is occupied and restored',function()
    local g=arena('Tower');g.Sites.V.Health=0
    for _=1,300 do g.Time+=.1;g:Produce(.1);g:WakeGuards() end
    assert(g:Population(g.Sites.V)==0,'A destroyed tower created a new protected archer')
    return 'No recruitment or roof defenders appeared on a ruined tower'
end)
q:Destroy();return report
