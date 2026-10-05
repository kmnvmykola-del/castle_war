local SoundService=game:GetService('SoundService')
local Music={}
function Music.Start()
    local old=SoundService:FindFirstChild('KingdomsMusic');if old then old:Destroy() end
    local sound=script.Parent:WaitForChild('Medieval_Ambient_Lute'):Clone()
    sound.Name='KingdomsMusic';sound.Volume=.22;sound.Looped=true;sound.Parent=SoundService
    sound:Play()
    return sound
end
return Music
