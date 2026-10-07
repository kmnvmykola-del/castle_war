-- Temporary native Studio probe. Disable and archive before saving.
assert(game:GetService('RunService'):IsStudio())
task.wait(3)
local root=game:GetService('ReplicatedStorage'):WaitForChild('Kingdoms')
local Art=require(root.Art);local Config=require(root.Config);Art.Prepare()
local report={NativeStudio=true,Version=root:GetAttribute('ReleaseVersion'),MeshParts=#root.MeshTemplates:GetChildren(),Skins={},Failures={}}
local fixture=Instance.new('Folder');fixture.Name='KingdomsPremiumQAObjects'
local loads={}
for _,skin in {'Storm','Dragon','Oracle'}do
    local record={Units=0,Blue=0,Red=0,HeadingChecks=0,Parts=0};report.Skins[skin]=record
    for _,kind in Config.Types do
        for side=1,2 do
            local unit=Art.Unit(kind,fixture,Config.Colors[side],skin)
            local heading=Vector3.new(.6,0,.8)
            Art.Pose(unit,CFrame.lookAt(Vector3.zero,heading),0,true,false)
            local torso=unit.Torso;local label=side==1 and 'Blue'or 'Red'
            assert(torso:GetAttribute('MeshKey'):find('__'..label,1,true),skin..' team variant missing')
            local rotation=torso:GetAttribute('MeshRotation')or CFrame.identity
            assert((torso.CFrame.Rotation*rotation:Inverse()).LookVector:Dot(heading)>.999,'Incorrect movement facing')
            record.Units+=1;record[label]+=1;record.HeadingChecks+=1
            for _,part in unit:GetChildren()do
                assert(part:IsA('MeshPart')and part.MeshId~=''and not part.CanCollide and not part.CanQuery)
                table.insert(loads,part);record.Parts+=1
            end
        end
    end
    for _,suffix in {'RoadTile','Gateway'}do local part=Art.Clone(skin..'_'..suffix,fixture);table.insert(loads,part);record[suffix]=part.MeshId end
end
local statuses={}
game:GetService('ContentProvider'):PreloadAsync(loads,function(id,status)
    statuses[id]=status.Name
    if status~=Enum.AssetFetchStatus.Success then table.insert(report.Failures,{Asset=id,Status=status.Name})end
end)
report.LoadedAssets=0;for _,status in statuses do if status=='Success'then report.LoadedAssets+=1 end end
fixture:Destroy();Art.Prune()
assert(report.Version=='0.16'and report.MeshParts==1969)
print('KINGDOMS_NATIVE_PREMIUM_QA '..game:GetService('HttpService'):JSONEncode(report))
assert(#report.Failures==0,'Premium assets did not all load')
script:SetAttribute('QAReport',game:GetService('HttpService'):JSONEncode(report))
