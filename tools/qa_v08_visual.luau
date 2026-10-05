-- Temporary server Script for visual inspection in Play. Never included in the place export.
local rs=game.ReplicatedStorage.Kingdoms
local player=game.Players:GetPlayers()[1] or game.Players.PlayerAdded:Wait()
repeat task.wait(.1) until _G.KingdomsLobby and _G.KingdomsLobby.Players[player]
local lobby=_G.KingdomsLobby
local scenario=script:GetAttribute('Scenario') or 'Village'
workspace:SetAttribute('VisualV08',nil)
local map=assert(require(rs.MapNetwork).Create({Name='Visual QA',River=false,Nodes={
    {Id='L',Kind='Castle',X=-3,Z=2,Owner=1},
    {Id='V',Kind=scenario=='Tower' and 'Tower' or 'Village',X=-1,Z=2,Owner=0},
    {Id='R',Kind='Castle',X=5,Z=-3,Owner=2},
},Roads={{'L','V'},{'V','R'}}}))
lobby.Players[player].State.Phase='Ended'
assert(lobby:StartAI(player,map,'Easy'))
local match=lobby.Players[player];match.Mode='PvP'
local g=match.State;g.Time=61;g.Phase='Battle'
local old={};for _,u in g.Units do table.insert(old,u) end
for _,u in old do g:RemoveUnit(u) end
for _=1,40 do g:CreateUnit('Defender',1,g.Sites.L) end
for _=1,12 do g:CreateUnit('Peasant',1,g.Sites.L) end
if scenario=='Village' then for _=1,60 do g:CreateUnit('Defender',0,g.Sites.V) end
elseif scenario=='Archers' then for _=1,16 do g:CreateUnit('Archer',0,g.Sites.V) end end
assert(g:Send(1,{'L'},'V',100,'All','Auto'))
local deadline=os.clock()+45
local inspected={}
repeat
    task.wait(.05)
    local ready=g.Time>(scenario=='Village' and 79 or 70) and #g.Impacts==0
    if scenario=='Tower' then ready=ready and g.Sites.V.Health<100 and g.Sites.V.Health>0 end
    if scenario=='Village' then
        local soldiers=0;for _,u in g.Active do if u.Side==1 and u.Kind=='Defender' then soldiers+=1 end end
        ready=ready and soldiers<=38
    end
    inspected={}
    for _,f in g.Formations do if f.Hold and f.RoadCenter then
        if f.Reforming then ready=false end
        local rows={}
        for _,u in g.Active do if u.Formation==f and u.MarchRank<=3 and not u.Dying then
            table.insert(rows,{Column=u.MarchColumn,Rank=u.MarchRank,X=u.Position.X,Z=u.Position.Z})
        end end
        table.insert(inspected,{Columns=f.Columns,Rows=rows,Center=tostring(f.RoadCenter),Heading=tostring(f.RoadHeading)})
    end end
    if ready and #inspected>0 then break end
until os.clock()>deadline
g.Step=function()end
workspace:SetAttribute('VisualV08',game.HttpService:JSONEncode({Scenario=scenario,Time=g.Time,Formations=inspected}))
