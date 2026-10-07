local Config = {}
Config.PrepTime=60
Config.Step=.1
Config.SnapshotInterval=.25
Config.VillageInterval={5,3,2}
Config.RecruitInterval={20,15,12}
Config.UpgradeCost={0,50,100}
Config.UpgradeDuration={0,6,10}
Config.Defense={0,.1,.2}
Config.Capacity={80,160,260}
Config.CastleCapacity={120,240,400}
Config.TowerCapacity={60,140,220}
Config.TowerRange={26,32,38}
Config.TowerInterval={2,1.8,1.6}
Config.TowerRoofHeight={9.915,11.187,12.374}
Config.Food={Initial=100,FarmInterval=5,Production={10,15,20},ConsumptionInterval=30}
Config.BotInterval={Easy=7,Normal=4,Hard=2.5}
Config.FormationColumns=4
Config.FormationSpacing=1.15
Config.RankSpacing=1.4
Config.MeleeContact=.85
Config.MeleeInterval=1
Config.MeleeImpactDelay=.25
Config.ArcherInterval=2
Config.TowerHealth=100
Config.TowerRadius=3.2
Config.SwordTowerDamage=5
Config.ArrowTowerDamage=2
Config.Types={'Peasant','Defender','Archer','Runner'}
Config.Units={
    Peasant={Name='Peasants',Health=30,Damage=3,Interval=1.5,Speed=8,Range=2,Priority=3},
    Defender={Name='Defenders',Health=100,Damage=12,Interval=1.2,Speed=6,Range=2,Shield=.35,Priority=1},
    Archer={Name='Archers',Health=45,Damage=25,Interval=1.5,Speed=7,Range=22,Priority=4},
    Runner={Name='Runners',Health=60,Damage=8,Interval=1,Speed=12,Range=2,Priority=2},
}
Config.Buildings={
    Castle={Name='Castle',Recruit='Defender',Height=17},
    Village={Name='Village',Recruit='Peasant',Height=8},
    Barracks={Name='Barracks',Recruit='Defender',Height=8},
    Archery={Name='Archery Range',Recruit='Archer',Height=8},
    Camp={Name='Camp',Recruit='Runner',Height=7},
    Tower={Name='Tower',Recruit='Archer',Height=13},
    Farm={Name='Farm',Height=8},
}
-- Imported buildings face the game camera (+Z). Their runtime root turns 180°.
Config.BuildingYaw=math.pi
-- Front doors after the turn; off-centre doors also move to the opposite X side.
Config.DoorOffsets={
    Castle={Vector3.new(0,0,5.13),Vector3.new(0,0,9),Vector3.new(0,0,9)},
    Village=Vector3.new(0,0,3.04),Barracks=Vector3.new(0,0,3.54),
    Archery=Vector3.new(1,0,2.04),Camp=Vector3.new(0,0,2.06),
    Tower=Vector3.new(0,0,2.5),Farm=Vector3.new(2,0,.04),
}
-- Rear Z extents of the existing Blender building meshes, by level.
Config.GarrisonRear={
    Castle={7.22739,9.55,10.65463},Village={4.16,4.68,4.68},
    Barracks={3.9,4.72,6.95},Archery={4.4,4.72,6.95},
    Camp={4,4.72,6.95},Farm={4.4,5,5.3},
}
Config.Colors={Color3.fromRGB(65,145,224),Color3.fromRGB(222,72,78),Color3.fromRGB(155,160,163)}
function Config.TeamColor(owner,viewerSide)
    if owner==0 then return Config.Colors[3] end
    return Config.Colors[owner==(viewerSide or 1) and 1 or 2]
end
return Config
