-- Additional contract checks for the game. Run on Server in Studio Play.
local rs=game.ReplicatedStorage
local q=Instance.new('Folder');q.Name='FullGameQA';q.Parent=rs
for _,name in {'Config','MapNetwork','MapData','MapCatalog','MapEditor','Engine'} do rs.Kingdoms[name]:Clone().Parent=q end
local C=require(q.Config);local N=require(q.MapNetwork);local Catalog=require(q.MapCatalog);local E=require(q.Engine)
local report={passed=0,failed=0,cases={},soak={}}
local function test(name,fn)
    local started=os.clock();local ok,result=pcall(fn)
    report[ok and 'passed' or 'failed']+=1
    report.cases[name]={passed=ok,seconds=os.clock()-started,result=ok and result or tostring(result)}
end
local function finite(n)return typeof(n)=='number' and n==n and math.abs(n)<math.huge end
local function audit(g)
    local seen={};local total,active=0,0
    for _,site in g.Sites do
        assert(site.Level>=1 and site.Level<=3)
        assert(g:Population(site)<=g:Capacity(site),'Strict building capacity exceeded')
        for _,id in site.Garrison do
            assert(not seen[id],'Person occupies two garrisons');seen[id]=true
            local u=assert(g.Units[id],'Garrison retained a removed person')
            assert(u.Home==site.Id and u.Side==site.Owner,'Garrison ownership or home is incorrect')
        end
    end
    for id,u in g.Units do
        total+=1
        assert(u.Health>0 and u.Health<=C.Units[u.Kind].Health,'Invalid health')
        assert(finite(u.Position.X) and finite(u.Position.Y) and finite(u.Position.Z),'Non-finite position')
        assert(not u.Home or seen[id],'Person has no matching garrison')
        if u.State=='Garrison' or u.State=='Deploying' then assert(not g.Active[id],'Hidden person appeared on the field')
        else assert(g.Active[id]==u,'A field unit was not tracked') end
    end
    for id,u in g.Active do active+=1;assert(g.Units[id]==u,'Removed field unit remained active') end
    for _,food in g.Food do assert(finite(food) and food>=0,'Invalid food balance') end
    local s=g:Snapshot();assert(#s.Units==active,'Snapshot lost or duplicated field units')
    local sum=0;for _,r in s.Totals do for _,n in r do sum+=n end end
    local neutral=0;for _,u in g.Units do if u.Side==0 then neutral+=1 end end
    assert(sum+neutral==total,'Population totals are incorrect')
    return total,active
end
local function empty(map)
    local g=E.new(map);g:Start();g.Time=61;g.Phase='Battle'
    local old={};for _,u in g.Units do table.insert(old,u) end
    for _,u in old do g:RemoveUnit(u) end
    return g
end
test('All maps and all AI difficulties remain consistent for three simulated minutes',function()
    for _,item in Catalog.Items do for _,difficulty in {'Easy','Normal','Hard'} do
        local g=E.new(assert(Catalog.Create(item.Id)),{Difficulty=difficulty});g:Start()
        local peakPeople,peakActive=0,0
        for step=1,1800 do
            g:Step(.1)
            if step%50==0 then local people,active=audit(g);peakPeople=math.max(peakPeople,people);peakActive=math.max(peakActive,active) end
            if step%100==0 then task.wait() end
        end
        local villages=0;for _,s in g.Sites do if s.Owner==2 and s.Kind=='Village' then villages+=1 end end
        assert(villages>0,'AI never captured any village')
        table.insert(report.soak,{map=item.Id,difficulty=difficulty,time=g.Time,phase=g.Phase,villages=villages,peakPeople=peakPeople,peakActive=peakActive,food=g.Food})
    end end
    return 'Nine sessions: economy, capacity, garrison ownership, unit lifecycle, positions and snapshots'
end)
test('A routed villager bypasses a friendly military building and trains only at the final destination',function()
    local m=assert(N.Create({River=false,Nodes={{Id='A',Kind='Castle',X=-5,Z=0,Owner=1},{Id='M',Kind='Barracks',X=-2,Z=0,Owner=1},{Id='B',Kind='Archery',X=2,Z=0,Owner=1},{Id='R',Kind='Castle',X=5,Z=0,Owner=2}},Roads={{'A','M'},{'M','B'},{'B','R'}}}))
    local g=empty(m);local p=g:CreateUnit('Peasant',1,g.Sites.A)
    assert(g:Send(1,{'A'},'B',100,'Peasant','Auto'))
    local bypassed=false
    for _=1,2000 do
        g.Time+=.1;g:CombatAndMove(.1)
        if p.Position.X>g.Sites.M.Position.X+16 and p.State=='Marching' then assert(p.Kind=='Peasant');bypassed=true end
        if p.State=='Garrison' then break end
    end
    assert(bypassed and p.Home=='B' and p.Kind=='Archer' and not g.Active[p.Id])
    return 'Became an archer at the final archery and disappeared into its garrison'
end)
test('Famine blocks training and military production while villagers continue',function()
    local g=empty();for _,s in g.Sites do if s.Kind=='Farm' then s.Owner=0 end end
    local castle=g.Sites.ACastle;local village=g.Sites.AVillage1;local barracks=g.Sites.ABarracks
    village.Owner=1;barracks.Owner=1;g.Food[1]=0
    local p=g:CreateUnit('Peasant',1,castle);g:Deposit(p,barracks)
    for _=1,250 do g.Time+=.1;g:Produce(.1) end
    assert(p.Kind=='Peasant' and p.PendingTraining and g:Counts(castle).Defender==0 and g:Counts(village).Peasant>=4)
    g.Food[1]=10;g:Produce(.1);assert(p.Kind=='Defender')
    return 'Villagers continue; queued training resumes when food returns'
end)
test('An unequal last fighting row remains reachable',function()
    local m=assert(N.Create({River=false,Nodes={{Id='L',Kind='Castle',X=-4,Z=0,Owner=1},{Id='R',Kind='Castle',X=4,Z=0,Owner=2}},Roads={{'L','R'}}}))
    local g=empty(m)
    for _=1,7 do g:CreateUnit('Defender',1,g.Sites.L) end
    for _=1,10 do g:CreateUnit('Defender',2,g.Sites.R) end
    assert(g:Send(1,{'L'},'R',100,'All','Auto'));assert(g:Send(2,{'R'},'L',100,'All','Auto'))
    for _=1,700 do g.Time+=.1;g:CombatAndMove(.1) end
    local left,right=0,0;for _,u in g.Units do if u.Side==1 then left+=1 else right+=1 end end
    assert(left==0 and right==3,'Unequal front rows stalled or produced asymmetric losses')
    return {remaining=3,side=2}
end)
test('Mixed defenders and runners fight and retain their identities',function()
    local m=assert(N.Create({River=false,Nodes={{Id='L',Kind='Castle',X=-4,Z=0,Owner=1},{Id='R',Kind='Castle',X=4,Z=0,Owner=2}},Roads={{'L','R'}}}))
    local g=empty(m)
    for side=1,2 do for _,kind in {'Defender','Runner'} do for _=1,6 do g:CreateUnit(kind,side,g.Sites[side==1 and 'L' or 'R']) end end end
    assert(g:Send(1,{'L'},'R',100,'All','Auto'));assert(g:Send(2,{'R'},'L',100,'All','Auto'))
    for _=1,800 do g.Time+=.1;g:CombatAndMove(.1) end
    assert(next(g.Units)==nil,'Mixed melee groups never finished their fight')
    return 'All three full rows exchanged symmetrically'
end)
test('Invalid map inputs and orders fail without altering the game',function()
    for _,value in {false,'map',{}, {Nodes={},Roads={}}} do local ok,map=pcall(N.Create,value);assert(ok and not map,'Malformed map raised or was accepted') end
    local d=N.DefaultDefinition();d.Nodes[1].X=0/0;local ok,map=pcall(N.Create,d);assert(ok and not map)
    d=N.DefaultDefinition();d.Nodes[1].X=math.huge;ok,map=pcall(N.Create,d);assert(ok and not map)
    local g=E.new();g:Start();local before=g:Population(g.Sites.ACastle)
    for _,args in {{1,{},'AFarm',50,'All','Auto'},{1,{'BCastle'},'AFarm',50,'All','Auto'},{1,{'ACastle'},'Missing',50,'All','Auto'},{1,{'ACastle'},'AFarm',0/0,'All','Auto'},{1,{'ACastle'},'AFarm',50,'Unknown','Auto'}} do assert(not g:Send(table.unpack(args))) end
    assert(g:Population(g.Sites.ACastle)==before and next(g.Active)==nil)
    return 'Rejected malformed maps, NaN/infinity coordinates, empty/foreign sources and invalid orders'
end)
q:Destroy()
return report
