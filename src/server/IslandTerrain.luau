--[[
	The island: ocean, beach, grass, dirt paths to every plot, soil under the
	planter beds and rolling hills around the edge.

	Terrain can't live in a .rbxm, so it's code: the server calls ensure() at
	startup (instant if the place already has it) and tools/studio/build_world.luau
	calls build() when (re)building the world in Studio. The plot positions here
	must match the world builder.
]]

local IslandTerrain = {}

local PLOT_X = { -168, -56, 56, 168 }
local PLOT_Z = 90
local MARKER = "MathMoneyTerrain"

function IslandTerrain.build()
	local terrain = workspace.Terrain
	terrain:Clear()
	-- ocean, beach, island
	terrain:FillBlock(CFrame.new(0, -14, 0), Vector3.new(1100, 20, 900), Enum.Material.Water)
	terrain:FillBlock(CFrame.new(0, -26, 0), Vector3.new(1100, 8, 900), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(600, 12, 460), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, -5, 0), Vector3.new(580, 10, 440), Enum.Material.Grass)
	-- the plaza: cobblestone circle in the middle and a dirt avenue to every gate
	terrain:FillBlock(CFrame.new(0, -2, 0), Vector3.new(460, 4, 22), Enum.Material.Ground)
	terrain:FillCylinder(CFrame.new(0, -2, 0), 4, 30, Enum.Material.Cobblestone)
	for _, x in PLOT_X do
		for _, side in { 1, -1 } do
			terrain:FillBlock(CFrame.new(x, -2, side * 22), Vector3.new(14, 4, 26), Enum.Material.Ground)
			-- path inside the plot to the machines + walkway in front of them
			terrain:FillBlock(CFrame.new(x, -2, side * (PLOT_Z - 22)), Vector3.new(12, 4, 68), Enum.Material.Ground)
			terrain:FillBlock(CFrame.new(x, -2, side * (PLOT_Z + 12)), Vector3.new(96, 4, 8), Enum.Material.Ground)
			-- bare soil under the planter beds so grass blades don't poke through them
			for _, bx in { 25, -25 } do
				terrain:FillBlock(CFrame.new(x - side * bx, -2, side * (PLOT_Z - 20)), Vector3.new(40, 4, 54), Enum.Material.Mud)
			end
		end
	end
	-- rolling hills around the edge for a cosy backdrop
	local rng = Random.new(42)
	for _ = 1, 26 do
		local angle = rng:NextNumber() * math.pi * 2
		local x = math.cos(angle) * rng:NextNumber(265, 300)
		local z = math.sin(angle) * rng:NextNumber(185, 215)
		terrain:FillBall(Vector3.new(x, -4, z), rng:NextNumber(18, 34), Enum.Material.Grass)
	end
	for _ = 1, 14 do
		local x = rng:NextNumber(-250, 250)
		local z = (if rng:NextNumber() < 0.5 then 1 else -1) * rng:NextNumber(160, 200)
		terrain:FillBall(Vector3.new(x, -6, z), rng:NextNumber(12, 22), Enum.Material.Grass)
	end
	terrain.WaterColor = Color3.fromRGB(40, 160, 190)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.12
	terrain.WaterReflectance = 0.6
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(110, 178, 72))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(150, 118, 82))
	terrain:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(160, 154, 146))
	terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(96, 70, 50))
	terrain:SetAttribute(MARKER, 1)
end

--- Build the island only if this place doesn't have it yet (e.g. a fresh `rojo build`).
function IslandTerrain.ensure()
	if not workspace.Terrain:GetAttribute(MARKER) then
		IslandTerrain.build()
	end
end

return IslandTerrain
