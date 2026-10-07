-- Client-only onboarding observes real actions without changing the match.
local Guide={};Guide.__index=Guide
function Guide.new()
    return setmetatable({Active=false,Step=1,Target=nil,Baseline={}},Guide)
end
function Guide:Begin(snapshot)
    if self.Active then return end
    self.Active=true;self.Step=1;self.Target=nil;self.Side=snapshot.ViewerSide
    self.Baseline={};for id,site in snapshot.Sites do self.Baseline[id]=site.Owner end
end
function Guide:Select(owner)
    if self.Active and self.Step==1 and owner==self.Side then self.Step=2 end
end
function Guide:Order(id,owner)
    if self.Active and self.Step==2 and owner~=self.Side then self.Target=id end
end
function Guide:Observe(snapshot)
    if not self.Active then return false end
    if self.Target and self.Step==2 then
        for _,unit in snapshot.Units do if unit[3]==self.Side then self.Step=3;break end end
    end
    if self.Target and self.Baseline[self.Target]~=self.Side and snapshot.Sites[self.Target]and snapshot.Sites[self.Target].Owner==self.Side then
        self.Active=false;return true
    end
    return false
end
function Guide:Close()self.Active=false;self.Target=nil end
return Guide
