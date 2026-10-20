--[[
	Server entry point. Each service in ./Services is a ModuleScript with optional
	:Init(services) and :Start() methods. Every service is Init-ed (in order)
	before any is Started, and services reach each other through the table
	passed to Init, so there are no circular requires.
]]

local ORDER = {
	"DataService",
	"PlotService",
	"MachineService",
	"GardenService",
	"AvatarService",
	"ShopService",
}

-- a place built straight from the repo has no terrain yet: grow the island first
require(script.IslandTerrain).ensure()

local services = {}
for _, name in ORDER do
	services[name] = require(script.Services:WaitForChild(name))
end
for _, name in ORDER do
	local service = services[name]
	if service.Init then
		service:Init(services)
	end
end
for _, name in ORDER do
	local service = services[name]
	if service.Start then
		task.spawn(service.Start, service)
	end
end

print("[MathMoney] server ready")
