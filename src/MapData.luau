local Network=require(script.Parent.MapNetwork)
local Map=assert(Network.Create(Network.DefaultDefinition()))
Map.Create=Network.Create
Map.DefaultDefinition=Network.DefaultDefinition
return Map
