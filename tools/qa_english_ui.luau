-- Construct the real main UI and all account pages, including editor help.
local q=game.ReplicatedStorage.Kingdoms
local P=require(q.Progression)
local UI=require(q.UI)
local player={PlayerGui=Instance.new('Folder')}
local u=UI.Build(player,{})
local m=require(q.MetaUI).Build(u,{})
local report={passed=0,failed=0,cases={}}
local function test(name,fn)
    local ok,result=pcall(fn);report[ok and 'passed'or 'failed']+=1
    report.cases[name]={passed=ok,result=ok and result or tostring(result)}
end
test('Main menu, editor instructions and all page titles use English',function()
    u.Show('Main',false);assert(u.Title.Text=='Frontier\nKingdoms'and u.Play.Text=='Play')
    assert(u.Editor.Toolbar.Save.Text=='Save'and u.Owner.Text=='Team: Blue')
    assert(u.Guide.Title.Text=='How to Create a Map'and string.find(u.Guide.Instructions.Text.Text,'Choose a building'))
    for page,title in {Inventory='Inventory',Shop='Shop',Chests='Kingdom Chest',Profile='Your Profile',Leaders='Leaderboards',Settings='Settings',Difficulty='Battle AI',Mode='Choose a Mode',Maps='Choose a Map'}do
        u.Show(page,false);assert(u.Title.Text==title,page)
    end
    return true
end)
test('Automatic localization cannot replace authored English game UI',function()
    assert(u.Gui.AutoLocalize==false and u.Overlay.AutoLocalize==false)
    assert(u.Main.Parent==u.Card and u.Card.Parent.Parent==u.Overlay)
    assert(m.Pages.Inventory.Parent==u.Card and u.Code.Parent==u.Overlay)
    return true
end)
test('Dynamic profile, chest and reward messages retain English text',function()
    local d=P.Public(P.Normalize({Coins=399}));m.Apply({Profile=d,Persistent=false})
    assert(string.find(m.Stats.Text,'Placement matches:')and string.find(m.Persistence.Text,'Studio:'))
    assert(string.find(m.ChestRewards.Text,'All possible rewards and exact odds:'))
    m.Apply({Reward={Won=true,XP=100,Coins=100,Mode='Ranked',Rank=25}})
    assert(string.find(m.Reward.Text,'Victory!')and string.find(m.Reward.Text,'Rank: %+25'))
    m.Apply({Chest={Skin='Dragon',Duplicate=true,Refund=250},ChestDone=true})
    assert(m.ChestResult.Text=='Duplicate: Dragon Order\nRefunded: 250 coins')
    return true
end)
return report
