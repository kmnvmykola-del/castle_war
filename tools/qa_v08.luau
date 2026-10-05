-- Verify combat formation geometry and complete attacks, not just configured column counts.
local rs=game.ReplicatedStorage
local q=Instance.new('Folder');q.Name='Version08QA';q.Parent=rs
for _,name in {'Config','MapNetwork','MapData','Engine'} do rs.Kingdoms[name]:Clone().Parent=q end
local C=require(q.Config);local N=require(q.MapNetwork);local E=require(q.Engine)
local report={}
local function arena(map)
    local g=E.new(map);g:Start();g.Time=61;g.Phase='Battle'
    local units={};for _,u in g.Units do table.insert(units,u) end
    for _,u in units do g:RemoveUnit(u) end
    return g
end
local function tick(g,guards)
    g.Time+=.1;if guards then g:WakeGuards() end;g:CombatAndMove(.1)
end
local function alive(g,side,kind)
    local n=0;for _,u in g.Units do if u.Side==side and (not kind or u.Kind==kind) then n+=1 end end
    return n
end
local function rowGeometry(g,f)
    local rows={}
    if f.Reforming then return 0,0 end
    for _,u in g.Active do if u.Formation==f and not u.Dying then
        rows[u.MarchRank]=rows[u.MarchRank] or {};rows[u.MarchRank][u.MarchColumn]=u
    end end
    local pairs=0;local worstGap=0
    for rank,columns in rows do if rank<=3 then
        for i=2,f.Columns do if columns[i-1] and columns[i] then
            local delta=columns[i].Position-columns[i-1].Position
            assert(delta.Magnitude>=C.FormationSpacing-.12 and delta.Magnitude<1.85,'Columns collapsed into a single file')
            pairs+=1
        end end
    end end
    for _,columns in rows do for column,u in columns do
        local nextRow=rows[u.MarchRank+1]
        if u.MarchRank<=3 and nextRow and nextRow[column] then
            local gap=(u.Position-nextRow[column].Position).Magnitude
            assert(gap<2.4,'Rear rank stopped far away from combat: '..gap..', rank '..u.MarchRank..', columns '..f.Columns)
            worstGap=math.max(worstGap,gap)
        end
    end end
    return pairs,worstGap
end
local function roadDistance(map,position)
    local best=math.huge
    for _,edge in map.Edges do
        local a,b=map.GraphPoints[edge[1]],map.GraphPoints[edge[2]]
        local delta=b-a
        local t=math.clamp((position-a):Dot(delta)/delta:Dot(delta),0,1)
        best=math.min(best,(position-(a+delta*t)).Magnitude)
    end
    return best
end
local ok,err=pcall(function()
    local function duelMap(river)
        return assert(N.Create({River=river,Nodes={{Id='L',Kind='Castle',X=-4,Z=0,Owner=1},{Id='R',Kind='Castle',X=4,Z=0,Owner=2}},Roads={{'L','R'}}}))
    end
    for _,river in {false,true} do
        local g=arena(duelMap(river));local pairs,largestGap,samples=0,0,0
        for side=1,2 do for _=1,40 do g:CreateUnit('Defender',side,g.Sites[side==1 and 'L' or 'R']) end end
        assert(g:Send(1,{'L'},'R',100,'All','Auto'));assert(g:Send(2,{'R'},'L',100,'All','Auto'))
        local firstLoss=nil;local previous=40;local waves={}
        for _=1,500 do
            tick(g)
            local remaining=alive(g,1)
            if remaining<previous then
                assert(previous-remaining==(river and 2 or 4),'Only one pair fought instead of the entire front row')
                table.insert(waves,g.Time);previous=remaining
            end
            if alive(g,1)<40 then firstLoss=firstLoss or g.Time end
            if firstLoss and g.Time>firstLoss+3 then
                assert(alive(g,1)==alive(g,2),'Asymmetric sword casualties')
                for _,f in g.Formations do if f.Hold and not f.Reforming then
                    assert(f.Columns==(river and 2 or 4),'Wrong width during bridge combat')
                    local n,gap=rowGeometry(g,f);pairs+=n;largestGap=math.max(largestGap,gap);samples+=1
                    local foeGap=math.huge
                    for _,u in g.Active do if u.Formation==f and u.MarchRank==0 and not u.Dying then
                        for _,v in g.Active do if v.Side~=u.Side and not v.Dying then foeGap=math.min(foeGap,(u.Position-v.Position).Magnitude) end end
                    end end
                    if foeGap<math.huge then assert(foeGap<1.1,'Sword formations did not make close contact') end
                end end
            end
            if firstLoss and g.Time>firstLoss+5 then break end
        end
        assert(firstLoss and pairs>30 and samples>10)
        for i=2,#waves do assert(waves[i]-waves[i-1]<1.7,'Front-row exchanges stalled') end
        report[river and 'bridgeBattle' or 'swordBattle']={columns=river and 2 or 4,simultaneousPairs=river and 2 or 4,spacing=C.FormationSpacing,rearGap=largestGap,rowPairsChecked=pairs,symmetricLosses=true,waves=waves}
    end

    -- Village guards leave through their door, then keep a wide fighting row on a curved approach.
    local map=assert(N.Create({River=false,Nodes={{Id='L',Kind='Castle',X=-3,Z=2,Owner=1},{Id='V',Kind='Village',X=-1,Z=2},{Id='R',Kind='Castle',X=5,Z=-3,Owner=2}},Roads={{'L','V'},{'V','R'}}}))
    local g=arena(map);for _=1,40 do g:CreateUnit('Defender',1,g.Sites.L) end
    for _=1,12 do g:CreateUnit('Peasant',1,g.Sites.L) end
    for _=1,60 do g:CreateUnit('Defender',0,g.Sites.V) end
    assert(g:Send(1,{'L'},'V',100,'All','Auto'))
    local checked=0;local since=nil;local previous=40;local waves={}
    for _=1,350 do
        tick(g,true)
        local remaining=alive(g,1,'Defender')
        if remaining<previous then
            assert(previous-remaining==4,'Corner combat only involved the innermost pair')
            table.insert(waves,g.Time);previous=remaining
        end
        if remaining<40 then since=since or g.Time end
        if since and g.Time>since+2 then
            for _,f in g.Formations do if f.Hold then local n=rowGeometry(g,f);checked+=n end end
            for _,u in g.Active do if u.Formation and not u.Dying then
                local offset=u.Position-g.Sites.V.Position
                local onFoundation=math.abs(offset.X)<=13.5 and math.abs(offset.Z)<=13.5
                assert(roadDistance(map,u.Position)<=2.3 or onFoundation,'Army left the road and target foundation while fighting: '..tostring(u.Position))
            end end
        end
        if since and g.Time>since+5 then break end
    end
    assert(checked>30 and alive(g,1,'Defender')<=37 and alive(g,0,'Defender')<=57,'Mixed army stalled at the road bend')
    assert(#waves>=4,'The next four fighters failed to join corner combat')
    for i=2,#waves do assert(waves[i]-waves[i-1]<1.7,'Corner combat stalled between ranks') end
    report.villageBattle={rowPairsChecked=checked,columns=4,simultaneousPairs=4,onRoadOrTargetFoundation=true,defendersInside=true,soldiers=40,peasantsBehind=12,casualties=40-alive(g,1,'Defender'),waves=waves}

    -- A last row of two must face its two opponents, rather than waiting in opposite empty lanes.
    local partial={}
    for _,corner in {false,true} do
        local small=arena(corner and map or duelMap(false))
        for _=1,6 do small:CreateUnit('Defender',1,small.Sites.L) end
        for _=1,6 do small:CreateUnit('Defender',corner and 0 or 2,small.Sites[corner and 'V' or 'R']) end
        assert(small:Send(1,{'L'},corner and 'V' or 'R',100,'All','Auto'))
        if not corner then assert(small:Send(2,{'R'},'L',100,'All','Auto')) end
        local losses={};local previous=6
        for _=1,500 do
            tick(small,corner)
            local remaining=alive(small,1)
            if remaining<previous then table.insert(losses,previous-remaining);previous=remaining end
            if remaining==0 then break end
        end
        assert(alive(small,1)==0 and alive(small,corner and 0 or 2)==0,'The incomplete last row stalled')
        assert(losses[1]==4 and losses[2]==2 and #losses==2,'Incomplete row lost its simultaneous pairs')
        partial[corner and 'corner' or 'straight']=losses
    end
    report.incompleteRanks=partial

    -- A lone stationary archer must still be reachable by a wide row.
    g=arena();g.Map={River=false,Route=function()return {Vector3.new(-120,0,120),Vector3.new(-120,0,20)} end}
    for _=1,12 do g:CreateUnit('Defender',1,g.Sites.ACastle) end
    local bow=g:CreateUnit('Archer',2,g.Sites.BCastle);g:Detach(bow)
    bow.Position=Vector3.new(-120,0,80);bow.State='Defending';bow.Cooldown=100
    g.Active[bow.Id]=bow
    assert(g:Send(1,{'ACastle'},'AFarm',100,'All','Auto'))
    for _=1,150 do tick(g);if not g.Units[bow.Id] then break end end
    assert(not g.Units[bow.Id],'Wide melee row could not reach a lone archer')
    report.singleArcher='Reached and defeated at melee contact without collapsing the columns'

    -- The full body follows its front towards a tower; the tower survives multiple swings.
    map=assert(N.Create({River=false,Nodes={{Id='L',Kind='Castle',X=-4,Z=0,Owner=1},{Id='T',Kind='Tower',X=-1,Z=0},{Id='R',Kind='Castle',X=4,Z=0,Owner=2}},Roads={{'L','T'},{'T','R'}}}))
    g=arena(map);for _=1,24 do g:CreateUnit('Defender',1,g.Sites.L) end
    assert(g:Send(1,{'L'},'T',100,'All','Auto'))
    local damageAt=nil;local siegePairs=0;local lastCenter=nil;local advanced=false
    for _=1,800 do
        tick(g)
        local tower=g.Sites.T
        if tower.Health<100 and not damageAt then damageAt=g.Time end
        for _,f in g.Formations do if f.Hold and f.RoadCenter then
            if lastCenter and (f.RoadCenter-lastCenter).Magnitude>.02 then advanced=true end
            lastCenter=f.RoadCenter
            if damageAt then local n=rowGeometry(g,f);siegePairs+=n end
        end end
        if tower.Owner==1 and g:Population(tower)==24 then break end
    end
    assert(damageAt and advanced and siegePairs>0 and g.Sites.T.Owner==1 and g:Population(g.Sites.T)==24)
    report.tower={fullArmy=24,allArrived=true,rowPairsChecked=siegePairs,continuedAdvance=true}

    -- A long army still inside the castle must resume after a siege, with strict target capacity.
    g=arena(map);g.Sites.L.Level=3
    for _=1,300 do g:CreateUnit('Defender',1,g.Sites.L) end
    assert(g:Send(1,{'L'},'T',100,'All','Auto'))
    local born={};local origin=g.Sites.L.Position+C.DoorOffsets.Castle[3]
    for _=1,1800 do
        tick(g)
        for id,u in g.Active do if not born[id] then
            assert((u.Position-origin).Magnitude<1.1,'A reinforcement appeared beyond its building door')
            born[id]=true
        end end
    end
    local waiting,moving=0,0
    for _,u in g.Units do if u.State=='Overflow' then waiting+=1 elseif u.State=='Marching' or u.State=='Deploying' then moving+=1 end end
    assert(moving==0 and g.Sites.T.Owner==1 and g:Population(g.Sites.T)==60 and waiting==240)
    report.longSiege={army=300,inside=60,waitingOutside=240,stuck=0}
end)
q:Destroy();if not ok then error(err) end
return report
