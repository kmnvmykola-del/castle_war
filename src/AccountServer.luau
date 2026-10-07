local Players=game:GetService('Players')
local DSS=game:GetService('DataStoreService')
local Market=game:GetService('MarketplaceService')
local Run=game:GetService('RunService')
local P=require(script.Parent.Progression)
local Data=require(script.Parent.PlayerData)
local Account={};Account.__index=Account
function Account.new(root,notify)
    local function remote(name)local r=root:FindFirstChild(name)or Instance.new('RemoteEvent');r.Name=name;r.Parent=root;return r end
    local self=setmetatable({Changed=remote('Account'),Actions=remote('AccountAction'),Notify=notify,Pending={},Loading={},Owners={},Cooldown={},Names={},ChestEligibility={},PassPrompt={}},Account)
    local stores={}
    if not Run:IsStudio()then
        stores.Store=DSS:GetDataStore('KingdomsMapsV1');stores.Wins=DSS:GetOrderedDataStore('KingdomsWinsV1');stores.Rank=DSS:GetOrderedDataStore('KingdomsRankV1');stores.Inbox=DSS:GetDataStore('KingdomsResultInboxV1')
    end
    self.Data=Data.new(stores)
    self.Actions.OnServerEvent:Connect(function(player,action,payload)
        if typeof(action)~='string'or typeof(payload)~='table'then return end
        local now=os.clock();self.Cooldown[player]=self.Cooldown[player]or {}
        local cooldownKey=action=='Board'and action..tostring(payload.Kind)or action
        local previous=self.Cooldown[player][cooldownKey]or 0
        if now-previous<(action=='Board'and 5 or .4)then return end;self.Cooldown[player][cooldownKey]=now
        local d=self:Profile(player);if not d then self.Notify(player,'Your profile is still loading.');if action=='OpenChest'then self.Changed:FireClient(player,{ChestDone=true})end;return end
        if action=='Board'then
            local board,reason=self.Data:Board(payload.Kind,player.UserId)
            if board then
                local ids={};for _,entry in board.Entries do if entry.UserId>0 and not self.Names[entry.UserId]then table.insert(ids,entry.UserId)end end
                if #ids>0 then
                    local found,users=pcall(function()return game:GetService('UserService'):GetUserInfosByUserIdsAsync(ids)end)
                    if found then for _,user in users do self.Names[user.Id]=user.DisplayName end end
                end
                for _,entry in board.Entries do
                    local p=Players:GetPlayerByUserId(entry.UserId);entry.Name=p and p.DisplayName or self.Names[entry.UserId]or tostring(entry.UserId)
                end
                self.Changed:FireClient(player,{Board=board})
            else self.Notify(player,reason)end
        elseif action=='OpenChest'then
            local ok,result=self:OpenChest(player,payload)
            if ok then self:Publish(player,nil,result)else self.Notify(player,result);self:Publish(player);self.Changed:FireClient(player,{ChestDone=true})end
        elseif action=='Premium'then
            local ok,message=self:BuyPremium(player,payload.Skin);self.Notify(player,message)
        elseif action=='Buy'or action=='Equip'then
            if typeof(payload.Skin)~='string'then return end
            local ok,message
            if action=='Buy'then ok,message=self.Data:Buy(player.UserId,payload.Skin)else ok,message=self.Data:Equip(player.UserId,payload.Skin)end
            self.Notify(player,message);if ok then self:Publish(player)end
        elseif action=='Coins'then
            local product=P.Product(payload.Product)
            if not product or product.ProductId<=0 or Run:IsStudio()then self.Notify(player,'Robux purchases become available after the game is published.');return end
            local ok=pcall(function()Market:PromptProductPurchase(player,product.ProductId)end)
            if not ok then self.Notify(player,'The purchase window is temporarily unavailable.')end
        elseif action=='Refresh'then self:Publish(player);task.spawn(function()self:ReconcilePasses(player)end)end
    end)
    Market.PromptGamePassPurchaseFinished:Connect(function(player,passId,purchased)
        if self.PassPrompt[player]==passId then self.PassPrompt[player]=nil end
        if not purchased then return end
        for _,skin in P.Skins do if skin.GamePassId and skin.GamePassId>0 and skin.GamePassId==passId then
            task.spawn(function()
                for attempt=1,4 do
                    if not self:Profile(player)then return end
                    local ok=self:VerifyPass(player,skin.Id)
                    if ok then return end
                    task.wait(attempt*2)
                end
                if player.Parent then self.Notify(player,'Roblox saved your purchase. Refresh your profile to receive the set.')end
            end)
            break
        end end
    end)
    Market.ProcessReceipt=function(receipt)return self:ProcessReceipt(receipt)end
    game:BindToClose(function()local untilTime=os.clock()+25;while next(self.Pending)and os.clock()<untilTime do task.wait(.1)end end)
    return self
end
function Account:VerifyPass(player,skinId)
    local skin=P.Skin(skinId)
    if not skin or not skin.GamePassId or skin.GamePassId<=0 then return false,'This set will be available for purchase soon.'end
    if not self:Profile(player)then return false,'Your profile is still loading.'end
    local market=self.Market or Market
    local ok,owned=pcall(function()return market:UserOwnsGamePassAsync(player.UserId,skin.GamePassId)end)
    if not ok then return false,'Could not verify your Roblox purchase. Please try again.'end
    if not owned then return false,'Roblox has not confirmed this purchase yet.'end
    if not self:Profile(player)then return false,'Your profile is still loading.'end
    local saved,result=self.Data:GrantPass(player.UserId,skinId)
    if saved then self:Publish(player);if not result.AlreadyApplied then self.Notify(player,'Full set unlocked: '..skin.Name)end end
    return saved,result
end
function Account:ReconcilePasses(player)
    for _,skin in P.Skins do
        local d=self:Profile(player);if not d then return end
        if skin.GamePassId and skin.GamePassId>0 and not d.Skins[skin.Id]then self:VerifyPass(player,skin.Id)end
    end
end
function Account:BuyPremium(player,skinId)
    local skin=P.Skin(skinId);local d=self:Profile(player)
    if not skin or not skin.RobuxPrice or not d then return false,'Select a premium set.'end
    if d.Skins[skinId]then return false,'This set is already in your inventory.'end
    if self.PassPrompt[player]then return false,'Finish the current purchase first.'end
    if Run:IsStudio()or not skin.GamePassId or skin.GamePassId<=0 then return false,'Robux purchases are coming soon. You can already unlock this set from a chest.'end
    local ok,owned=pcall(function()return Market:UserOwnsGamePassAsync(player.UserId,skin.GamePassId)end)
    if not ok then return false,'Could not verify your Roblox purchase.'end
    if owned then local saved=self:VerifyPass(player,skinId);return saved,saved and 'Set added to your inventory.'or 'Your purchase is waiting to be saved. Refresh your profile.'end
    if not self:Profile(player)or self:Profile(player).Skins[skinId]then return false,'This set is already unlocked or your profile is unavailable.'end
    self.PassPrompt[player]=skin.GamePassId
    local prompted=pcall(function()Market:PromptGamePassPurchase(player,skin.GamePassId)end)
    if not prompted then self.PassPrompt[player]=nil;return false,'The purchase window is temporarily unavailable.'end
    return true,'Confirm your purchase in the Roblox window.'
end
function Account:OpenChest(player,payload)
    if self.PassPrompt and self.PassPrompt[player]then return false,'Finish the Roblox purchase first.'end
    if self.ChestEligibility[player]~=true then return false,'Random purchases are unavailable for this account.'end
    if not self:Profile(player)then return false,'Your profile is still loading.'end
    return self.Data:OpenChest(player.UserId,payload.RequestId,payload.Signature)
end
function Account:ProcessReceipt(receipt)
    local product
    for _,item in P.Products do if item.ProductId>0 and item.ProductId==receipt.ProductId then product=item;break end end
    local player=self.FindPlayer and self.FindPlayer(receipt.PlayerId)or Players:GetPlayerByUserId(receipt.PlayerId)
    if not product or not player or not self.Data.Profiles[receipt.PlayerId]or self.Owners and self.Owners[receipt.PlayerId]~=player or not self.Data.S.Store then return Enum.ProductPurchaseDecision.NotProcessedYet end
    local ok,result=self.Data:Receipt(receipt.PlayerId,tostring(receipt.PurchaseId),product.Coins)
    if not ok then return Enum.ProductPurchaseDecision.NotProcessedYet end
    self:Publish(player);if not result.AlreadyApplied then self.Notify(player,'Coins added: '..product.Coins)end
    return Enum.ProductPurchaseDecision.PurchaseGranted
end
function Account:Load(player)
    if self.Loading[player]then return nil end;self.Loading[player]=true
    local d,reason=self.Data:Load(player.UserId,true)
    if d then
        if self.Data:Recover(player.UserId)then d=self.Data.Profiles[player.UserId]
        else d=nil;reason='Could not restore your rewards. Select Refresh Profile.'end
    end
    self.Loading[player]=nil
    if d then
        self.Owners[player.UserId]=player
        if Run:IsStudio()then self.ChestEligibility[player]=true
        else
            self.ChestEligibility[player]=nil
            task.spawn(function()
                local ok,policy=pcall(function()return game:GetService('PolicyService'):GetPolicyInfoForPlayerAsync(player)end)
                self.ChestEligibility[player]=ok and policy.ArePaidRandomItemsRestricted==false
                self:Publish(player)
            end)
        end
        self:Publish(player);task.spawn(function()self.Data:Project(player.UserId)end);task.spawn(function()self:ReconcilePasses(player)end)
    else self.Notify(player,reason)end
    return d
end
function Account:Profile(player)
    return self.Owners[player.UserId]==player and not self.Loading[player]and self.Data.Profiles[player.UserId]or nil
end
function Account:Publish(player,reward,chest)
    if not player.Parent then return end
    local d=self.Data.Profiles[player.UserId];if not d then return end
    local leader=player:FindFirstChild('leaderstats')or Instance.new('Folder');leader.Name='leaderstats';leader.Parent=player
    for name,value in {['Level']=d.Level,['Rank']=d.Rank,['Wins']=d.Wins}do
        local item=leader:FindFirstChild(name)or Instance.new('IntValue');item.Name=name;item.Value=value;item.Parent=leader
    end
    player:SetAttribute('KingdomLevel',d.Level);player:SetAttribute('KingdomRank',d.Rank)
    local pool,signature=P.ChestPool(d);local rewards=P.ChestRewards(d)
    self.Changed:FireClient(player,{Profile=P.Public(d),Reward=reward,Persistent=self.Data.S.Store~=nil,Chest=chest,ChestDone=chest~=nil,ChestInfo={Allowed=self.ChestEligibility[player]==true,Pending=self.ChestEligibility[player]==nil,Pool=pool,Rewards=rewards,Signature=signature,Price=P.ChestPrice,Complete=P.CollectionCount(d)==#P.Skins}})
end
function Account:Complete(session)
    for player,side in session.Participants do
        local result={Id=session.Id,At=os.time(),Won=session.State.Winner==side,Mode=session.Mode,Difficulty=session.State.Difficulty,Forfeit=session.Forfeits[side]==true}
        local key=player.UserId..':'..result.Id;self.Pending[key]=player.UserId
        task.spawn(function()
            local delay=1
            while self.Pending[key]do
                local ok,reward=self.Data:Deliver(player.UserId,result)
                if ok then
                    self.Pending[key]=nil;self:Publish(Players:GetPlayerByUserId(player.UserId)or player,reward);self.Data:Project(player.UserId)
                    if not Players:GetPlayerByUserId(player.UserId)then self:Release(player)end
                    break
                end
                if player.Parent then self.Notify(player,'Saving your reward. Retrying…')end
                task.wait(delay);delay=math.min(delay*2,30)
            end
        end)
    end
end
function Account:Release(player)
    for _,id in self.Pending do if id==player.UserId then return end end
    if Players:GetPlayerByUserId(player.UserId)then return end
    self.Data.Profiles[player.UserId]=nil;self.Owners[player.UserId]=nil;self.Cooldown[player]=nil
    self.ChestEligibility[player]=nil;self.PassPrompt[player]=nil
end
function Account:Await(player)
    local untilTime=os.clock()+10
    repeat
        local pending=false;for _,id in self.Pending do if id==player.UserId then pending=true;break end end
        if not pending then return true end;task.wait(.1)
    until os.clock()>=untilTime
    return false
end
return Account
