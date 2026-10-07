local Http=game:GetService('HttpService')
local Network=require(script.Parent.MapNetwork)
local Config=require(script.Parent.Config)
local Editor={};Editor.__index=Editor
local function copy(d)return Http:JSONDecode(Http:JSONEncode(d))end
function Editor.new(definition,changed,notify)
    return setmetatable({Definition=copy(definition),History={},Kind='Castle',Tool='Place',Owner=1,From=nil,Moving=nil,Changed=changed,Notify=notify,Counter=0,GeometryRevision=0},Editor)
end
function Editor:Find(id)for _,n in self.Definition.Nodes do if n.Id==id then return n end end end
function Editor:Cell(x,z)for _,n in self.Definition.Nodes do if n.X==x and n.Z==z then return n end end end
function Editor:Remember()
    table.insert(self.History,copy(self.Definition));if #self.History>50 then table.remove(self.History,1)end
end
function Editor:Refresh(mapChanged,compiled)
    if mapChanged then self.GeometryRevision+=1 end
    self.Changed(self.Definition,self:Hint(),self.GeometryRevision,compiled)
end
function Editor:Hint()
    if self.Tool=='Road'then return self.From and 'Road: select the second point. Right-click to cancel.' or 'Road: select the first point, then the second.'
    elseif self.Tool=='Move'then return self.Moving and 'Move: select an empty cell.' or 'Move: select a building.'
    elseif self.Tool=='Erase'then return 'Delete: select an object. Its connected roads will also be removed.' end
    local name=self.Kind=='Junction'and 'Road Junction' or Config.Buildings[self.Kind].Name
    return name..' · '..({'Blue','Red','Neutral'})[self.Owner==0 and 3 or self.Owner]..' · select an empty cell'
end
function Editor:SetKind(kind)self.Kind=kind;self.Tool='Place';self.From=nil;self.Moving=nil;self:Refresh()end
function Editor:SetTool(tool)self.Tool=tool;self.From=nil;self.Moving=nil;self:Refresh()end
function Editor:CycleOwner()self.Owner=self.Owner==1 and 2 or self.Owner==2 and 0 or 1;self:Refresh()end
function Editor:CanPlace(x,z,ignore)
    local b=Network.Bounds
    if self.Definition.River~=false and x==0 or x<b.MinX or x>b.MaxX or z<b.MinZ or z>b.MaxZ then return false end
    local n=self:Cell(x,z);return not n or n.Id==ignore
end
function Editor:Click(id,x,z)
    if self.Tool=='Road'then
        if not id or not self:Find(id)then self.Notify('Select a building or a road junction.');return end
        if not self.From then self.From=id;self:Refresh();return end
        if self.From==id then self.From=nil;self:Refresh();return end
        for _,e in self.Definition.Roads do if e[1]==id and e[2]==self.From or e[2]==id and e[1]==self.From then self.From=nil;self:Refresh();return end end
        local nextMap=copy(self.Definition);table.insert(nextMap.Roads,{self.From,id})
        local valid,reason=Network.Create(nextMap,{AllowIncomplete=true})
        if not valid then self.Notify(reason);return end
        self:Remember();self.Definition=valid.Definition;self.From=nil;self:Refresh(true,valid)
    elseif self.Tool=='Erase'then
        if not id or not self:Find(id)then return end;self:Remember()
        for i=#self.Definition.Nodes,1,-1 do if self.Definition.Nodes[i].Id==id then table.remove(self.Definition.Nodes,i)end end
        for i=#self.Definition.Roads,1,-1 do local e=self.Definition.Roads[i];if e[1]==id or e[2]==id then table.remove(self.Definition.Roads,i)end end
        self:Refresh(true)
    elseif self.Tool=='Move'then
        if not self.Moving then if id then self.Moving=id;self:Refresh()end;return end
        if not self:CanPlace(x,z,self.Moving)then self.Notify('This cell is occupied or in the river.');return end
        local moving=self:Find(self.Moving)
        if moving and moving.X==x and moving.Z==z then self.Moving=nil;self:Refresh();return end
        local nextMap=copy(self.Definition)
        for _,n in nextMap.Nodes do if n.Id==self.Moving then n.X=x;n.Z=z end end
        local valid,reason=Network.Create(nextMap,{AllowIncomplete=true});if not valid then self.Notify(reason);return end
        self:Remember();self.Definition=valid.Definition;self.Moving=nil;self:Refresh(true,valid)
    else
        if not self:CanPlace(x,z)then self.Notify('Select an empty cell on land.');return end
        if self.Kind=='Castle' and self.Owner~=0 then for _,n in self.Definition.Nodes do if n.Kind=='Castle'and n.Owner==self.Owner then self.Notify('This team already has a castle. Move it or select another team.');return end end end
        if #self.Definition.Nodes>=80 then self.Notify('The map has reached its object limit.');return end
        repeat self.Counter+=1 until not self:Find('N'..self.Counter)
        self:Remember();table.insert(self.Definition.Nodes,{Id='N'..self.Counter,Kind=self.Kind,X=x,Z=z,Owner=self.Owner});self:Refresh(true)
    end
end
function Editor:Undo()
    local last=table.remove(self.History);if last then self.Definition=last;self.From=nil;self.Moving=nil;self:Refresh(true)end
end
function Editor:New()self:Remember();self.Definition={Name='My Map',River=self.Definition.River~=false,Nodes={},Roads={}};self.From=nil;self.Moving=nil;self:Refresh(true)end
function Editor:ToggleRiver()
    local nextMap=copy(self.Definition);nextMap.River=self.Definition.River==false
    local valid,reason=Network.Create(nextMap,{AllowIncomplete=true})
    if not valid then self.Notify('Move objects out of the central column first. '..reason);return false end
    self:Remember();self.Definition=valid.Definition;self.From=nil;self.Moving=nil;self:Refresh(true,valid);return true
end
function Editor:Validate()return Network.Create(self.Definition)end
function Editor:Export()return Http:JSONEncode(self.Definition)end
function Editor:Import(text)
    if #text>40000 then return false,'Map code is too large.' end
    local ok,d=pcall(function()return Http:JSONDecode(text)end);if not ok then return false,'Could not read the map code.' end
    local map,reason=Network.Create(d,{AllowIncomplete=true});if not map then return false,reason end
    self:Remember();self.Definition=map.Definition;self.From=nil;self.Moving=nil;self:Refresh(true,map);return true
end
return Editor

