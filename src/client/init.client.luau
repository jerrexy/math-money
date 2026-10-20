--[[
	Client entry point. Every controller in ./Controllers gets :Start(controllers)
	in the order below and can reach the others through that table.
]]

local ORDER = {
	"ClientData",
	"SoundController",
	"NotifyController",
	"HudController",
	"MachineRenderer",
	"RoundController",
	"ShopController",
	"GardenController",
	"ReportController",
	"EffectsController",
	"SafeController",
	"FrogPlaneController",
}

local controllers = {}
for _, name in ORDER do
	controllers[name] = require(script.Controllers:WaitForChild(name))
end
for _, name in ORDER do
	local controller = controllers[name]
	if controller.Start then
		local ok, err = pcall(controller.Start, controller, controllers)
		if not ok then
			warn("[MathMoney] " .. name .. " failed to start: " .. tostring(err))
		end
	end
end
