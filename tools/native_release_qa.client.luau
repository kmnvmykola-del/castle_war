-- Temporary Studio probe. Archive disabled before saving or publishing.
local Run=game:GetService('RunService');assert(Run:IsStudio()and Run:IsClient())
local Players=game:GetService('Players');local player=Players.LocalPlayer
local root=game:GetService('ReplicatedStorage'):WaitForChild('Kingdoms')
local Http=game:GetService('HttpService');local latest;local sent=false
local report={Player=player.Name,UserId=player.UserId,Studio=true,Audio={},OwnBlue=0,EnemyRed=0,ColourErrors=0}
local Network=require(root.MapNetwork)
root:WaitForChild('Snapshot').OnClientEvent:Connect(function(snapshot)
    latest=snapshot
    if not sent and snapshot.Mode=='PvP'and snapshot.Map and (snapshot.Phase=='Preparation'or snapshot.Phase=='Battle')then
        local map=Network.Create(snapshot.Map)
        if map then
            local source=map.Castles[snapshot.ViewerSide];local best,bestCount
            for id,site in snapshot.Sites do if site.Owner==0 and site.Population>0 then
                local path=map.Route(source,id,true,'Auto',function(via)return snapshot.Sites[via]and snapshot.Sites[via].Owner==snapshot.ViewerSide end)
                if path and(not bestCount or #path<bestCount)then best=id;bestCount=#path end
            end end
            if best then sent=true;root.Command:FireServer('Send',{Sources={source},Target=best,Percent=90,Filter='All',Route='Auto'});report.Target=best end
        end
    end
end)
task.wait(5)
root.Command:FireServer('JoinPvP',{})
local frames,elapsed=0,0
local measure=Run.RenderStepped:Connect(function(dt)frames+=1;elapsed+=dt end)
task.wait(10);measure:Disconnect();report.FPS=frames/math.max(elapsed,.001)
local audio=game:GetService('SoundService'):WaitForChild('KingdomsAudio',10)
if audio then
    for _,sound in audio:GetChildren()do if sound:IsA('Sound')then report.Audio[sound.Name]={Id=sound.SoundId,Loaded=sound.IsLoaded,Length=sound.TimeLength}end end
    if player.UserId==-1 then audio.Interface.Volume=.173;report.LocalVolumeChanged=true end
end
local deadline=os.clock()+25
while os.clock()<deadline and (report.OwnBlue==0 or report.EnemyRed==0)do
    task.wait(.12)
    local scene=workspace:FindFirstChild('KingdomsScene');local armies=scene and scene:FindFirstChild('Armies')
    if latest and armies then
        report.Side=latest.ViewerSide
        for _,model in armies:GetChildren()do
            local torso=model:FindFirstChild('Torso')
            if torso then
                local nearest,distance
                for _,unit in latest.Units do if unit[3]==1 or unit[3]==2 then
                    local delta=Vector2.new(torso.Position.X-unit[4],torso.Position.Z-unit[5]).Magnitude
                    if not distance or delta<distance then nearest=unit;distance=delta end
                end end
                if nearest and distance<1.7 then
                    local own=nearest[3]==latest.ViewerSide;local key=torso:GetAttribute('MeshKey')or ''
                    if key:find(own and '__Blue'or '__Red',1,true)then
                        report[own and 'OwnBlue'or 'EnemyRed']+=1
                    else report.ColourErrors+=1 end
                end
            end
        end
    end
end
task.wait(3)
report.InterfaceVolume=audio and audio.Interface.Volume
report.AudioLocalOnly=audio and audio.Parent==game:GetService('SoundService')
script:SetAttribute('QAReport',Http:JSONEncode(report))
print(string.format('KINGDOMS_NATIVE_RELEASE_SUMMARY %s side=%s ownBlue=%d enemyRed=%d errors=%d volume=%.3f fps=%.1f',player.Name,tostring(report.Side),report.OwnBlue,report.EnemyRed,report.ColourErrors,report.InterfaceVolume or -1,report.FPS))
for name,value in report.Audio do print('KINGDOMS_NATIVE_AUDIO '..player.Name..' '..name..' loaded='..tostring(value.Loaded)..' '..value.Id)end
print('KINGDOMS_NATIVE_RELEASE_QA '..Http:JSONEncode(report))
