-- Approved progression and cosmetic economy. Combat never reads these values.
local P={XPPerLevel=200,CoinsPerLevel=100,CalibrationMatches=10,CalibrationWin=100,CalibrationLoss=25,RankWin=25,RankLoss=25}
local Styles=require(script.Parent.SkinStyles)
P.Skins=Styles.Items
P.Rarities=Styles.Rarities
P.ChestPrice=300
-- Developer products belonging to Frontier Kingdoms (universe 10769541065).
P.Products={{Id='Small',Coins=500,Price=49,ProductId=3716851182},{Id='Medium',Coins=1500,Price=129,ProductId=3716851330},{Id='Large',Coins=3500,Price=249,ProductId=3716851499}}
local function number(value,default)
    return typeof(value)=='number' and value==value and value~=math.huge and value~=-math.huge and math.max(0,math.floor(value)) or default or 0
end
function P.Skin(id)for _,skin in P.Skins do if skin.Id==id then return skin end end end
function P.Product(id)for _,product in P.Products do if product.Id==id then return product end end end
function P.Band(level)
    level=number(level,1);return level<10 and '1–9' or level<25 and '10–24' or level<50 and '25–49' or '50+'
end
function P.Normalize(d)
    d=typeof(d)=='table' and d or {}
    for _,key in {'XP','Coins','Rank','RankedGames','WinStreak','Wins','Losses','RankedWins','AIWins','AILosses','Revision'}do d[key]=number(d[key])end
    d.Level=1+math.floor(d.XP/P.XPPerLevel)
    d.Skins=typeof(d.Skins)=='table' and d.Skins or {};d.Skins.Default=true
    d.Equipped=P.Skin(d.Equipped) and d.Skins[d.Equipped]==true and d.Equipped or 'Default'
    d.Matches=typeof(d.Matches)=='table' and d.Matches or {};d.Receipts=typeof(d.Receipts)=='table' and d.Receipts or {};d.Chests=typeof(d.Chests)=='table'and d.Chests or {}
    return d
end
function P.Public(d)
    local result={};for _,key in {'XP','Level','Coins','Rank','RankedGames','WinStreak','Wins','Losses','RankedWins','AIWins','AILosses','Equipped','Revision'}do result[key]=d[key]end
    result.LevelXP=d.XP%P.XPPerLevel;result.LobbyBand=P.Band(d.Level);result.Skins=table.clone(d.Skins);return result
end
function P.ChestPool(d)
    -- Odds stay fixed when the inventory changes; owning commons never makes
    -- a mythic guaranteed. Duplicates give the advertised coin compensation.
    local pool,signature,total={}, {'v013',tostring(P.ChestPrice)},0
    for _,skin in P.Skins do if skin.Id~='Default'then
        table.insert(pool,skin.Id);table.insert(signature,skin.Id..':'..skin.Weight..':'..skin.DuplicateCoins);total+=skin.Weight
    end end
    return pool,table.concat(signature,'|'),total
end
function P.CollectionCount(d)
    local count=0;for _,skin in P.Skins do if d.Skins[skin.Id]==true then count+=1 end end;return count
end
function P.ChestRewards(d)
    local pool,signature,total=P.ChestPool(d);local rewards={}
    for _,id in pool do local skin=P.Skin(id);table.insert(rewards,{Id=id,Weight=skin.Weight,Total=total,Chance=skin.Weight/total*100,Owned=d.Skins[id]==true,Refund=skin.DuplicateCoins})end
    return rewards,signature
end
function P.DrawChest(roll)
    local pool,_,total=P.ChestPool();local cursor=math.clamp(roll,0,1)*total
    for _,id in pool do cursor-=P.Skin(id).Weight;if cursor<0 then return id end end
    return pool[#pool]
end
function P.Apply(d,result)
    if d.Matches[result.Id]then return nil end
    local beforeLevel,beforeRank=d.Level,d.Rank;local won=result.Won==true;local xp=0
    if result.Mode=='AI'then
        if won then d.AIWins+=1;xp=({Easy=20,Normal=35,Hard=50})[result.Difficulty]or 50 else d.AILosses+=1 end
    else
        if won then d.Wins+=1;xp=100 else d.Losses+=1;xp=result.Forfeit and 0 or 40 end
        if result.Mode=='Ranked'then
            local calibrating=d.RankedGames<P.CalibrationMatches
            d.RankedGames+=1;d.WinStreak=won and d.WinStreak+1 or 0
            if won then
                d.RankedWins+=1
                local gain=calibrating and P.CalibrationWin or d.WinStreak>=5 and 50 or d.WinStreak==4 and 45 or d.WinStreak==3 and 35 or P.RankWin
                d.Rank+=gain
            else d.Rank=math.max(0,d.Rank-(calibrating and P.CalibrationLoss or P.RankLoss))end
        end
    end
    d.XP+=xp;d.Level=1+math.floor(d.XP/P.XPPerLevel)
    local coins=(d.Level-beforeLevel)*P.CoinsPerLevel;d.Coins+=coins;d.Matches[result.Id]=true
    return {XP=xp,Coins=coins,Levels=d.Level-beforeLevel,Rank=d.Rank-beforeRank,Won=won,Mode=result.Mode}
end
return P
