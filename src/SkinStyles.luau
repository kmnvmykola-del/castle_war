local S={Items={{Id="Default",Name="Standard Army",Price=0,Cloth="#704E38",Armor="#ADAB9C",Trim="#B69159",Motif="cross"},{Id="Veteran",Name="Veterans",Cloth="#526347",Armor="#7D8780",Trim="#B88445",Motif="harness",Price=400,ChestOnly=false},{Id="Royal",Name="Royal Guard",Cloth="#ECE3C3",Armor="#CBD3D7",Trim="#DAB053",Motif="crown",Price=800,ChestOnly=false},{Id="Dark",Name="Dark Knights",Cloth="#342F45",Armor="#414D60",Trim="#B1ADB9",Motif="raven",Price=1200,ChestOnly=false},{Id="Forest",Name="Forest Wardens",Cloth="#355942",Armor="#879B72",Trim="#D0AF74",Motif="leaf",Price=0,ChestOnly=true},{Id="Sun",Name="Order of the Sun",Cloth="#A95330",Armor="#D7C8A0",Trim="#E5B54C",Motif="sun",Price=0,ChestOnly=true},{Id="Moon",Name="Moon Watch",Cloth="#454B76",Armor="#A7B3CB",Trim="#D1CFEB",Motif="moon",Price=0,ChestOnly=true},{Id="Frost",Name="Frost Guard",Cloth="#66A5B2",Armor="#CCE4E5",Trim="#89C7DC",Motif="ice",Price=0,ChestOnly=true},{Id="Ember",Name="Ashen Legion",Cloth="#733928",Armor="#595052",Trim="#E8944E",Motif="flame",Price=0,ChestOnly=true},{Id="Grove",Name="Oak Guard",Cloth="#6C7744",Armor="#9B9A72",Trim="#A57C4C",Motif="antler",Price=0,ChestOnly=true},{Id="Storm",Name="Storm Knights",Cloth="#3D6479",Armor="#9AB4C4",Trim="#EBD172",Motif="bolt",Price=0,ChestOnly=true},{Id="Iron",Name="Iron Bastion",Cloth="#68635B",Armor="#7C8587",Trim="#C6B39A",Motif="rivets",Price=0,ChestOnly=true},{Id="Rose",Name="Order of the Rose",Cloth="#86495D",Armor="#CDC1B8",Trim="#E5AA99",Motif="rose",Price=0,ChestOnly=true},{Id="Sapphire",Name="Sapphire Crown",Cloth="#294D79",Armor="#ADBCCF",Trim="#D4C2A3",Motif="gem",Price=0,ChestOnly=true},{Id="Amber",Name="Amber Guard",Cloth="#95663B",Armor="#AC9A80",Trim="#E8B450",Motif="amber",Price=0,ChestOnly=true},{Id="Raven",Name="Raven Cloaks",Cloth="#34383F",Armor="#6C7886",Trim="#B8BEC6",Motif="feathers",Price=0,ChestOnly=true},{Id="Lion",Name="Lion Guard",Cloth="#8A3C33",Armor="#C8B494",Trim="#E0BC59",Motif="lion",Price=0,ChestOnly=true},{Id="Griffin",Name="Griffin Wardens",Cloth="#667986",Armor="#D7D5C5",Trim="#D6AD66",Motif="wings",Price=0,ChestOnly=true},{Id="Dragon",Name="Dragon Order",Cloth="#506452",Armor="#738780",Trim="#C09851",Motif="scales",Price=0,ChestOnly=true},{Id="Rune",Name="Rune Keepers",Cloth="#5B5277",Armor="#939CAD",Trim="#C2B2D2",Motif="runes",Price=0,ChestOnly=true},{Id="Oracle",Name="Star Keepers",Cloth="#605482",Armor="#C3B9CF",Trim="#E2CCA2",Motif="star",Price=0,ChestOnly=true},{Id="Crusader",Name="White Banners",Cloth="#DFD5BE",Armor="#B9C5CE",Trim="#AA8960",Motif="cross",Price=0,ChestOnly=true},{Id="Mariner",Name="Coastal Guard",Cloth="#3E6D74",Armor="#91A8A6",Trim="#D6B078",Motif="anchor",Price=0,ChestOnly=true},{Id="Nomad",Name="Steppe Riders",Cloth="#AB7950",Armor="#9E8D73",Trim="#DCCCA5",Motif="scarf",Price=0,ChestOnly=true},{Id="Stag",Name="Silver Stag",Cloth="#597067",Armor="#D4DCD2",Trim="#C4CFB7",Motif="stag",Price=0,ChestOnly=true}}}
S.Rarities={
    Default={Name='Starter',Color='#AEB7BC',Weight=0,Price=0,Refund=0},
    Common={Name='Common',Color='#AEB7BC',Weight=7200,Price=400,Refund=100},
    Rare={Name='Rare',Color='#66ABEB',Weight=3150,Price=800,Refund=150},
    Epic={Name='Epic',Color='#BC8BE4',Weight=1260,Price=1200,Refund=200},
    Mythic={Name='Mythic',Color='#E9BD61',Price=0,Refund=250},
}
local tiers={
    Common={'Veteran','Forest','Grove','Iron','Amber','Mariner','Nomad'},
    Rare={'Royal','Sun','Moon','Frost','Rose','Raven','Crusader','Stag'},
    Epic={'Dark','Ember','Sapphire','Lion','Griffin','Rune'},
}
local premium={Storm={Price=199,Weight=420,GamePassId=2006883740},Dragon={Price=399,Weight=252,GamePassId=2005989756},Oracle={Price=699,Weight=168,GamePassId=2005239786}}
for _,skin in S.Items do
    skin.Rarity='Default'
    for tier,ids in tiers do if table.find(ids,skin.Id)then skin.Rarity=tier;break end end
    local offer=premium[skin.Id]
    if offer then
        skin.Rarity='Mythic';skin.RobuxPrice=offer.Price;skin.Weight=offer.Weight
        -- Permanent cosmetic passes for Frontier Kingdoms, universe 10769541065.
        skin.GamePassId=offer.GamePassId
    end
    local rarity=S.Rarities[skin.Rarity]
    skin.Price=rarity.Price;skin.Weight=skin.Weight or rarity.Weight;skin.DuplicateCoins=rarity.Refund
    skin.ChestOnly=false
end
S.Items[1].Name='Standard Set'
function S.Get(id)for _,v in S.Items do if v.Id==id then return v end end;return S.Items[1]end
return S
