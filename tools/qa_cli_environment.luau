-- Test-only Roblox substitutes for deterministic Luau CLI checks.
local function deepCopy(v)
    if type(v)~='table'then return v end
    local out={};for k,x in v do out[k]=deepCopy(x)end;return out
end
local originalTypeof=typeof
local function typeof(v)return type(v)=='table'and rawget(v,'__type')or originalTypeof(v)end
local vec={};vec.__index=function(v,k)
    if k=='Magnitude'then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)end
    if k=='Unit'then return v/v.Magnitude end
    return vec[k]
end
local Vector3={}
function Vector3.new(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,__type='Vector3'},vec)end
vec.__add=function(a,b)return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vec.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vec.__unm=function(a)return Vector3.new(-a.X,-a.Y,-a.Z)end
vec.__mul=function(a,b)if type(a)=='number'then a,b=b,a end;return Vector3.new(a.X*b,a.Y*b,a.Z*b)end
vec.__div=function(a,b)return Vector3.new(a.X/b,a.Y/b,a.Z/b)end
function vec:Dot(b)return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
function vec:Cross(b)return Vector3.new(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X)end
function vec:Lerp(b,t)return self+(b-self)*t end
function vec:Min(b)return Vector3.new(math.min(self.X,b.X),math.min(self.Y,b.Y),math.min(self.Z,b.Z))end
function vec:Max(b)return Vector3.new(math.max(self.X,b.X),math.max(self.Y,b.Y),math.max(self.Z,b.Z))end
Vector3.zero=Vector3.new();Vector3.yAxis=Vector3.new(0,1,0)
local rgb={};rgb.__index=rgb
local Color3={new=function(r,g,b)return setmetatable({R=r,G=g,B=b,__type='Color3'},rgb)end}
function Color3.fromRGB(r,g,b)return Color3.new(r/255,g/255,b/255)end
function rgb:Lerp(b,t)return Color3.new(self.R+(b.R-self.R)*t,self.G+(b.G-self.G)*t,self.B+(b.B-self.B)*t)end
local UDim={new=function(s,o)return {Scale=s or 0,Offset=o or 0}end}
local Vector2={new=function(x,y)return {X=x or 0,Y=y or 0}end}
local ColorSequence={new=function(a,b)return {a,b}end}
local UDim2={new=function(xs,xo,ys,yo)return {X=UDim.new(xs,xo),Y=UDim.new(ys,yo)}end}
function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
function UDim2.fromScale(x,y)return UDim2.new(x,0,y,0)end
local cf={};cf.__index=cf;cf.__mul=function(a,b)return a end
local CFrame={new=function(...)return setmetatable({},cf)end,Angles=function(...)return setmetatable({},cf)end,lookAt=function(...)return setmetatable({},cf)end}
CFrame.identity=CFrame.new()
local Enum=setmetatable({},{__index=function(t,k)local values=setmetatable({},{__index=function(s,key)rawset(s,key,k..'.'..key);return s[key]end});rawset(t,k,values);return values end})
local function signal()return {Connect=function(self,fn)self.Callback=fn;return {Disconnect=function()end}end}end
local nodeMethods={}
local nodeMeta={__index=function(t,k)
    if nodeMethods[k]then return nodeMethods[k]end
    if k=='Activated'or k=='MouseButton1Click'or k=='InputBegan'or k=='InputChanged'or k=='InputEnded'then local s=signal();rawset(t,k,s);return s end
    for _,child in t.ChildList do if child.Name==k then return child end end
end,__newindex=function(t,k,v)
    if k=='Parent'then
        local old=rawget(t,'_parent')
        if old and old.Children then
            if old.Children[t.Name]==t then old.Children[t.Name]=nil end
            local index=table.find(old.ChildList,t);if index then table.remove(old.ChildList,index)end
        end
        rawset(t,'_parent',v)
        if v and v.Children then v.Children[t.Name]=t;table.insert(v.ChildList,t)end
    else rawset(t,k,v)end
end}
local Instance={new=function(kind)return setmetatable({ClassName=kind,Name=kind,Children={},ChildList={}},nodeMeta)end}
nodeMeta.__index=function(t,k)
    if k=='Parent'then return rawget(t,'_parent')end
    if nodeMethods[k]then return nodeMethods[k]end
    if k=='Activated'or k=='MouseButton1Click'or k=='InputBegan'or k=='InputChanged'or k=='InputEnded'then local s=signal();rawset(t,k,s);return s end
    for _,child in t.ChildList do if child.Name==k then return child end end
end
function nodeMethods:GetChildren()return table.clone(self.ChildList)end
function nodeMethods:FindFirstChild(name)for _,child in self.ChildList do if child.Name==name then return child end end end
function nodeMethods:GetDescendants()local out={};for _,child in self.ChildList do table.insert(out,child);for _,nested in child:GetDescendants()do table.insert(out,nested)end end;return out end
function nodeMethods:Destroy()for _,child in self:GetChildren()do child:Destroy()end;self.Parent=nil;self.Destroyed=true end
function nodeMethods:Clone()
    local n=Instance.new(self.ClassName)
    for key,value in self do
        if key~='Children'and key~='ChildList'and key~='_parent'and key~='Attributes'then n[key]=value end
    end
    if self.Attributes then n.Attributes=table.clone(self.Attributes)end
    for _,child in self:GetChildren()do child:Clone().Parent=n end
    return n
end
function nodeMethods:IsA(kind)return self.ClassName==kind or kind=='BasePart'and (self.ClassName=='Part'or self.ClassName=='MeshPart'or self.ClassName=='SpawnLocation')or kind=='LuaSourceContainer'and(self.ClassName=='ModuleScript'or self.ClassName=='Script'or self.ClassName=='LocalScript')end
function nodeMethods:FindFirstChildOfClass(kind)for _,child in self.ChildList do if child.ClassName==kind then return child end end end
function nodeMethods:FindFirstAncestor(name)local p=self.Parent;while p do if p.Name==name then return p end;p=p.Parent end end
function nodeMethods:IsDescendantOf(parent)local p=self.Parent;while p do if p==parent then return true end;p=p.Parent end;return false end
function nodeMethods:SetAttribute(k,v)self.Attributes=self.Attributes or {};self.Attributes[k]=v end
function nodeMethods:GetAttribute(k)return self.Attributes and self.Attributes[k]end
function nodeMethods:GetPropertyChangedSignal(k)return signal()end
local Random={new=function()return {NextNumber=function()return math.random()end,NextInteger=function(_,a,b)return math.random(a,b)end}end}
local task={wait=function()return 0 end,spawn=function(fn)fn()end,delay=function(_,fn)fn()end,defer=function(fn)fn()end}
local TweenInfo={new=function()return {}end}
local Content={fromObject=function(value)return value end}
local warn=print
local Http={JSONEncode=function(_,v)return deepCopy(v)end,JSONDecode=function(_,v)return deepCopy(v)end,GenerateGUID=function()return 'qa-'..tostring(math.random(100000,999999))end}
local Run={IsStudio=function()return true end}
local Tween={Create=function()return {Play=function()end}end}
local services={HttpService=Http,RunService=Run,TweenService=Tween,UserInputService={TouchEnabled=false,InputChanged=signal(),InputEnded=signal()},MarketplaceService={},DataStoreService={},Players={GetPlayerByUserId=function()end}}
local root=Instance.new('Folder');root.Name='Kingdoms'
local game={ReplicatedStorage={Kingdoms=root},GetService=function(_,name)return services[name]or {}end}
local workspace=Instance.new('Workspace');workspace.CurrentCamera=Instance.new('Camera');workspace.CurrentCamera.ViewportSize={X=1280,Y=720}
local factories,cache={},{}
local function require(module)
    if cache[module]then return cache[module]end
    local value=factories[module.Name](module,require);cache[module]=value;return value
end
