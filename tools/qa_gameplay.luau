-- Run in Studio Edit with execute_luau after deploying the current sources.
local rs=game:GetService('ReplicatedStorage')
local q=Instance.new('Folder');q.Name='GameplayQA';q.Parent=rs
for _,name in {'Config','MapNetwork','MapData','Engine','MapEditor'} do rs.Kingdoms[name]:Clone().Parent=q end
local E=require(q.Engine)
local M=require(q.MapData)
local C=require(q.Config)
local report={}
local function arena()
    local g=E.new();g:Start();g.Time=61;g.Phase='Battle'
    local list={};for _,u in g.Units do table.insert(list,u) end
    for _,u in list do g:RemoveUnit(u) end
    return g
end
local function count(g,side,kind)
    local n=0;for _,u in g.Units do if u.Side==side and (not kind or u.Kind==kind) then n+=1 end end;return n
end
local function tickCombat(g,seconds,withGuards)
    local events={}
    for _=1,math.floor(seconds*10+.5) do
        g.Time+=.1
        if withGuards then g:WakeGuards() end
        g:CombatAndMove(.1)
        for _,e in g.Events do table.insert(events,e) end;g.Events={}
    end
    return events
end
local function fighter(g,kind,side,i,position,group,target)
    local u=g:CreateUnit(kind,side,g.Sites[side==1 and 'ACastle' or 'BCastle']);g:Detach(u)
    u.State='Marching';u.Squad=group;u.FormationIndex=i;u.Column=((i-1)%4-1.5)*.8
    u.Position=position;u.Path={position,g.Sites[target].Position};u.PathIndex=2;u.Target=target
    g.Active[u.Id]=u;return u
end
local ok,err=pcall(function()
    assert(C.TeamColor(1,1)==C.Colors[1] and C.TeamColor(2,1)==C.Colors[2] and C.TeamColor(0,1)==C.Colors[3])
    assert(C.TeamColor(2,2)==C.Colors[1] and C.TeamColor(1,2)==C.Colors[2] and C.TeamColor(0,2)==C.Colors[3])
    report.colors='Own blue, opponent red, neutral gray from either side'
    assert(#M.Sites==20 and #M.Bridges==2)
    assert(not M.Route('ACastle','BCastle',false))
    assert(M.Route('ACastle','BCastle',true))
    local bad=M.DefaultDefinition();table.insert(bad.Nodes,{Id='Duplicate',Kind='Village',X=-6,Z=0})
    assert(not M.Create(bad),'Overlapping cells accepted')
    bad=M.DefaultDefinition();table.insert(bad.Roads,{'ACastle','Missing'})
    assert(not M.Create(bad),'Disconnected endpoint accepted')
    report.map={cellSize=M.CellSize,roads=#M.Definition.Roads,physicalSegments=#M.Edges,bridges=#M.Bridges}
    local crossing={Nodes={{Id='Left',Kind='Junction',X=-6,Z=-4},{Id='Right',Kind='Junction',X=-2,Z=-4},{Id='Up',Kind='Junction',X=-4,Z=-5},{Id='Down',Kind='Junction',X=-4,Z=-3}},Roads={{'Left','Right'},{'Up','Down'}}}
    local separate=assert(M.Create(crossing,{AllowIncomplete=true}))
    assert(separate.Route('Left','Right',true) and separate.Route('Up','Down',true))
    assert(separate.Route('Left','Up',true),'A visible crossing did not permit changing roads')
    assert(#separate.Crossings==0,'Connected roads retained an obsolete overpass marker')
    table.insert(crossing.Nodes,{Id='Join',Kind='Junction',X=-4,Z=-4});crossing.Roads={{'Left','Join'},{'Right','Join'},{'Up','Join'},{'Down','Join'}}
    local joined=assert(M.Create(crossing,{AllowIncomplete=true}));assert(joined.Route('Left','Up',true) and #joined.Crossings==0)
    report.visibleRoads='Visible crossings and named junctions both permit changing roads'
    local arrivals={}
    for _,target in {'AFarm','AArchery','ABarracks','AVillage4','BCastle'}do
        local moving=E.new();moving:Start();moving.Time=61
        for _,s in moving.Sites do s.Owner=1;s.Level=3 end
        assert(moving:Send(1,{'ACastle'},target,100,'All','Auto'))
        for _=1,1800 do moving.Time+=.1;moving:CombatAndMove(.1)end
        for _,unit in moving.Active do assert(unit.State~='Marching','A formation jammed on the route to '..target)end
        assert(moving:Population(moving.Sites[target])==(target=='BCastle' and 140 or target=='AFarm' and 70 or target=='AVillage4' and 78 or 82))
        arrivals[target]=70
    end
    report.movement={mixedArmy=70,curvedRoutes=arrivals,stuckMarchers=0}
    for _,a in M.Sites do for _,b in M.Sites do if a.Id~=b.Id then
        local path=M.Route(a.Id,b.Id,true)
        for _,s in M.Sites do if s.Id~=a.Id and s.Id~=b.Id then
            for i=2,#path do
                local p,r=path[i-1]-s.Position,path[i]-s.Position
                local overlaps=math.min(p.X,r.X)<13.5 and math.max(p.X,r.X)>-13.5 and math.min(p.Z,r.Z)<13.5 and math.max(p.Z,r.Z)>-13.5
                assert(not overlaps,'Transit road entered '..s.Id..' between '..a.Id..' and '..b.Id)
            end
        end end
    end end end
    report.transit='All building pairs route around every intermediate footprint'
    local ED=require(q.MapEditor)
    local ed=ED.new(M.Definition,function()end,function(reason)error(reason)end)
    ed:SetKind('Village');ed:Click(nil,-7,-4);local added=ed:Cell(-7,-4).Id
    ed:SetTool('Road');ed:Click('ACastle',0,0);ed:Click(added,0,0);assert(ed:Validate())
    ed:SetTool('Move');ed:Click(added,0,0);ed:Click(nil,-8,-4);assert(ed:Cell(-8,-4).Id==added and ed:Validate())
    local code=ed:Export();ed:SetTool('Erase');ed:Click(added,0,0);assert(not ed:Find(added));ed:Undo();assert(ed:Find(added))
    ed:New();assert(not ed:Validate());assert(ed:Import(code));assert(ed:Validate());assert(not ed:Import('{invalid}'))
    report.editor='Place, link, move, erase, undo, new, code export/import and full validation'
    local full=arena();local archery=full.Sites.AArchery;archery.Owner=1
    for _=1,80 do full:CreateUnit('Archer',1,archery)end
    local arriving=full:CreateUnit('Peasant',1,full.Sites.ACastle);full:Deposit(arriving,archery)
    assert(full:Population(archery)==80 and arriving.State=='Overflow' and arriving.Kind=='Peasant')
    local snap=full:Snapshot();assert(snap.Sites.AArchery.Counts.Peasant==1 and snap.Sites.AArchery.Inside.Peasant==0 and #snap.Units==1)
    full:RemoveUnit(full.Units[archery.Garrison[1]]);full:Produce(.1)
    assert(full:Population(archery)==80 and arriving.State=='Garrison' and arriving.Kind=='Archer' and #full:Snapshot().Units==0)
    report.capacity='Strict limit; visible waiting peasants train and disappear only after space opens'
    local g=E.new();g:Start()
    for _=1,31 do g:Step(.1,true) end
    assert(g:Counts(g.Sites.ACastle).Peasant==20)
    local ar=g.Sites.AArchery;ar.Owner=1
    local p=g:CreateUnit('Peasant',1,g.Sites.ACastle);g:Deposit(p,ar);assert(p.Kind=='Archer')
    g:Deposit(p,g.Sites.AFarm);assert(p.Kind=='Archer','A trained archer was retrained')
    g.Food[1]=0
    local p2=g:CreateUnit('Peasant',1,g.Sites.ACastle);g:Deposit(p2,ar)
    assert(p2.Kind=='Peasant' and p2.PendingTraining)
    for _=1,50 do g:Step(.1,true) end
    assert(p2.Kind=='Archer' and g.Food[1]>0)
    local pe=g:CreateUnit('Peasant',1,g.Sites.ACastle);g:Deposit(pe,g.Sites.AFarm);assert(pe.Kind=='Peasant')
    report.training='Immediate on arrival; trained types preserved; food pause and resume'
    g=E.new();g:Start();g.Food[1]=100;g.FoodClock=29.9;g:Produce(.1)
    assert(g.Food[1]==50,'Only 50 warriors should consume food; 20 peasants are exempt')
    local n=g:Population(g.Sites.ACastle);assert(g:Upgrade(1,'ACastle'));assert(g:Population(g.Sites.ACastle)==n-50)
    for _=1,61 do g:Step(.1,true) end;assert(g.Sites.ACastle.Level==2)
    local castle=g.Sites.ACastle
    for _=1,100 do g:CreateUnit('Peasant',1,castle) end
    n=g:Population(castle);assert(g:Upgrade(1,castle.Id));assert(g:Population(castle)==n-100)
    for _=1,101 do g:Step(.1,true) end;assert(castle.Level==3)
    g=arena();g.Sites.AFarm.Level=2;g:Produce(5)
    assert(g.Food[1]==115 and g.Food[2]==110)
    g.Sites.AFarm.Level=3;g:Produce(5);assert(g.Food[1]==135)
    assert(g:Population(g.Sites.AFarm)==0,'Farms must not produce people')
    report.economy='Food consumption, farm levels, and 50/100-person upgrades verified'
    g=arena();g.Time=0
    for side=1,2 do for i=1,4 do
        fighter(g,'Defender',side,i,Vector3.new(-60+(i-2.5)*.8,0,side==1 and -.425 or .425),side,side==1 and 'BVillage1' or 'AVillage1')
    end end
    tickCombat(g,.2)
    assert(count(g,1)==4 and count(g,2)==4,'Sword casualties occurred before the impact delay')
    tickCombat(g,.2)
    assert(count(g,1)==0 and count(g,2)==0,'All four frontline pairs must strike in the same exchange')
    report.swords='Four versus four simultaneously; impact delay 0.25 seconds'
    g=arena();g.Time=0
    local bow=g:CreateUnit('Archer',1,g.Sites.ACastle);bow.State='Defending';bow.Position=Vector3.zero;g.Active[bow.Id]=bow
    for i=1,3 do local u=g:CreateUnit('Defender',2,g.Sites.BCastle);u.State='Defending';u.Position=Vector3.new(i*.5,0,20);g.Active[u.Id]=u end
    local events=tickCombat(g,1)
    assert(count(g,2)==3,'First arrow must not kill a healthy defender')
    local wounded=false;for _,u in g.Units do if u.Side==2 and u.Health<100 then wounded=true end end;assert(wounded,'Arrow damage was not applied')
    for _,e in tickCombat(g,43)do table.insert(events,e)end
    local arrows=0;for _,e in events do if e.Type=='Arrow' then arrows+=1 end end
    assert(arrows>3 and count(g,2)==0 and bow.Position==Vector3.zero)
    report.archers={damage=C.Units.Archer.Damage,arrowsForThreeDefenders=arrows,firstHitSurvived=true,reloadSeconds=2,noRetreat=true}
    local formationGame=arena();local home=formationGame.Sites.ACastle;local destination=formationGame.Sites.AVillage4;destination.Owner=1
    for _,site in formationGame.Sites do site.Owner=1 end
    for _=1,12 do formationGame:CreateUnit('Defender',1,home)end
    for _=1,8 do formationGame:CreateUnit('Archer',1,home)end
    assert(formationGame:Send(1,{home.Id},destination.Id,100,'All','Auto'))
    for _=1,80 do formationGame.Time+=.1;formationGame:CombatAndMove(.1)
        local front={}
        for _,u in formationGame.Active do if u.Kind=='Defender'and u.MarchRank==0 then front[u.MarchColumn]=u end end
        if front[4] and (not front[4].Formation.ExitLength or front[4].Formation.Progress>=front[4].Formation.ExitLength)then
            for i=2,4 do local delta=front[i].Position-front[i-1].Position
                assert(math.abs(delta.Magnitude-C.FormationSpacing)<.001 and math.abs(delta:Dot(front[1].Heading))<.001,'Melee row lost its four-column alignment')
            end
        end
    end
    for _,u in formationGame.Units do if u.Kind=='Archer'then assert(not u.Formation,'An archer was constrained by the melee formation')end end
    report.formation='Melee rows keep four aligned lanes through turns; archers move freely through them'
    local passing=arena();passing.Sites.AFarm.Owner=1
    passing.Map={Route=function()return {Vector3.new(-120,0,120),Vector3.new(-120,0,-120)}end}
    for _=1,20 do passing:CreateUnit('Defender',1,passing.Sites.ACastle)end
    for _=1,8 do passing:CreateUnit('Archer',1,passing.Sites.ACastle)end
    assert(passing:Send(1,{'ACastle'},'AFarm',100,'All','Auto'));tickCombat(passing,8)
    local firstMelee,firstArcher=math.huge,math.huge
    for _,u in passing.Active do if u.Kind=='Archer'then firstArcher=math.min(firstArcher,u.Position.Z)else firstMelee=math.min(firstMelee,u.Position.Z)end end
    assert(firstArcher>firstMelee+1 and firstArcher<firstMelee+2,'Archers did not stay slightly behind the front melee rank')
    report.archerEscort='Archers move freely through rear ranks while staying behind their own front melee rank'
    local duel=arena();local soldier=duel:CreateUnit('Defender',1,duel.Sites.ACastle);soldier.State='Defending';soldier.Position=Vector3.zero;duel.Active[soldier.Id]=soldier
    local vulnerable=duel:CreateUnit('Archer',2,duel.Sites.BCastle);duel:Detach(vulnerable);vulnerable.State='Defending';vulnerable.Position=Vector3.new(0,0,1);duel.Active[vulnerable.Id]=vulnerable
    tickCombat(duel,1);assert(not duel.Units[vulnerable.Id],'A melee fighter must defeat an archer on its first sword swing')
    report.archerMelee='Defeated by the first melee swing'
    g=arena();g.Time=0
    local started=os.clock()
    g.Sites.BVillage1.Position=Vector3.new(-130,0,140)
    g.Sites.AVillage1.Position=Vector3.new(-130,0,-140)
    for side=1,2 do
        local number=side==1 and 50 or 100
        for i=1,number do
            local column=((i-1)%4-1.5)*.8
            local rank=math.floor((i-1)/4)*.95
            local position=Vector3.new(-130+(side==1 and -column or column),0,side==1 and -20-rank or 18+rank)
            local u=fighter(g,side==1 and 'Archer' or 'Defender',side,i,position,side,side==1 and 'BVillage1' or 'AVillage1')
            u.Path={Vector3.new(-130,0,side==1 and -20 or 18),Vector3.new(-130,0,side==1 and 140 or -140)}
            u.LastZ=position.Z
        end
    end
    local shots=0
    for _=1,600 do
        for _,e in tickCombat(g,.1) do if e.Type=='Arrow' then shots+=1 end end
        for _,u in g.Units do if u.Kind=='Archer' then assert(u.Position.Z>=u.LastZ-1e-5,'An archer retreated: '..u.State..' from '..u.LastZ..' to '..u.Position.Z..' at '..g.Time);u.LastZ=u.Position.Z end end
    end
    assert(shots>0 and count(g,2)<100,'Large armies did not engage')
    report.largeBattle={archers=50,defenders=100,shots=shots,remainingArchers=count(g,1),remainingDefenders=count(g,2),simulationSeconds=60,executionSeconds=os.clock()-started}
    g=arena();g.Time=0
    local tower=g.Sites.NorthTower
    for i=1,4 do fighter(g,'Defender',1,i,tower.Position+Vector3.new((i-2.5)*.8,0,4.8),11,tower.Id) end
    events=tickCombat(g,12)
    local collapsed=false;for _,e in events do if e.Type=='Collapse' then collapsed=true end end
    assert(collapsed and tower.Owner==1 and tower.Health==100,'Tower should collapse before occupation and restoration')
    report.tower='100 durability, siege over multiple swings, ruins then capture/restoration'
    g=arena();g.Time=0;tower=g.Sites.NorthTower
    local guard=g:CreateUnit('Archer',0,tower)
    fighter(g,'Defender',1,1,tower.Position+Vector3.new(0,0,12),11,tower.Id)
    events=tickCombat(g,.2,true)
    assert(guard.Home==tower.Id and guard.Height==C.TowerRoofHeight[tower.Level] and g:Protected(guard))
    local fired=false;for _,e in events do if e.Type=='Arrow' then fired=true end end;assert(fired)
    tickCombat(g,.5,true);assert(guard.Home==tower.Id and g:Protected(guard))
    report.towerGarrison='Archers fire from inside and are protected by the structure'
    g=E.new();g:Start()
    for _=1,600 do g:Step(.1);g.Events={} end
    local villages=0;for _,s in g.Sites do if s.Owner==2 and s.Kind=='Village' then villages+=1 end end
    assert(villages>=3,'Hard bot did not claim its starting villages')
    report.bot={villagesAt60=villages,food=g.Food[2]}
    g=arena()
    for _,s in g.Sites do if s.Owner==1 then s.Owner=2 end end
    local survivor=g:CreateUnit('Peasant',1,g.Sites.ACastle)
    g:CheckVictory();assert(g.Phase~='Ended','Last living peasant must prevent defeat')
    g:RemoveUnit(survivor);g:CheckVictory();assert(g.Phase=='Ended' and g.Winner==2)
    report.victory='Last building or living unit prevents defeat'
end)
q:Destroy()
if not ok then error(err) end
return report
