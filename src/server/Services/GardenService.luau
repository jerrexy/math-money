--[[
	Gardens: planting seeds / decor on your plot's soil beds and growing them.

	Plants are saved in plot space ({ id, item, x, y, z, r, t }) so a garden comes
	back exactly the same on whichever plot the player claims next time. Growth
	uses real time (os.time), so plants keep growing while you're away.

	Seeds and decor live in a "pouch" and show up as tools in the backpack; equip
	one and click your soil (GardenController shows a preview). The Shovel digs a
	plant back up into the pouch.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)
local Economy = require(Shared.Config.Economy)
local Remotes = require(Shared.Remotes)

local GardenService = {}
local services

local GROW_TICK = 3
local SPACING = 0.55 -- fraction of (r1 + r2) plants must be apart

type Loaded = { plot: any, player: Player, models: { [string]: Model } }
local loaded: { [any]: Loaded } = {} -- plot -> state

local function template(item): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local group = assets and assets:FindFirstChild(if item.kind == "Plant" then "Plants" else "Decor")
	local found = group and group:FindFirstChild(item.model)
	if found then
		return found :: Model
	end
	-- placeholder so the game still works before the art is imported
	local model = Instance.new("Model")
	model.Name = item.model
	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Size = Vector3.new(0.4, 3, 0.4)
	stem.CFrame = CFrame.new(0, 1.5, 0)
	stem.Color = Color3.fromRGB(80, 170, 70)
	stem.Parent = model
	local top = Instance.new("Part")
	top.Name = "Top"
	top.Shape = Enum.PartType.Ball
	top.Size = Vector3.new(2, 2, 2)
	top.CFrame = CFrame.new(0, 3.5, 0)
	top.Color = Color3.fromRGB(255, 120, 200)
	top.Parent = model
	model.WorldPivot = CFrame.new()
	return model
end

local function growthScale(item, plantedAt: number): (number, boolean)
	local grow = item.growSeconds or 0
	if grow <= 0 then
		return 1, true
	end
	local frac = math.clamp((os.time() - plantedAt) / grow, 0, 1)
	local small = if (item.radius or 2) >= 4 then 0.1 else 0.22
	local eased = 1 - (1 - frac) ^ 2
	return small + (1 - small) * eased, frac >= 1
end

local function plantCFrame(plot, record): CFrame
	return plot.origin * CFrame.new(record.x, record.y or 0, record.z) * CFrame.Angles(0, math.rad(record.r or 0), 0)
end

local function spawnPlant(state: Loaded, record)
	local item = Catalog.get(record.item)
	if not item then
		return
	end
	local model = template(item):Clone()
	model.Name = record.id
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = true
		end
	end
	model:SetAttribute("PlantId", record.id)
	model:SetAttribute("Item", record.item)
	model:SetAttribute("OwnerId", state.player.UserId)
	model:SetAttribute("PlantedAt", record.t)
	model:SetAttribute("GrowSeconds", item.growSeconds or 0)
	local scale, grown = growthScale(item, record.t)
	model:SetAttribute("Grown", grown)
	model:PivotTo(plantCFrame(state.plot, record))
	if scale < 0.999 then
		model:ScaleTo(scale)
	end
	model.Parent = state.plot.plantsFolder
	state.models[record.id] = model
end

--- Find the soil bed under a world position and turn it into plot space.
local function locate(plot, position: Vector3, radius: number): (Vector3?, string?)
	for _, bed in plot.beds do
		local localPos = bed.CFrame:PointToObjectSpace(position)
		local half = bed.Size / 2
		local margin = math.min(radius * 0.4, 1.5)
		if math.abs(localPos.X) <= half.X - margin and math.abs(localPos.Z) <= half.Z - margin and math.abs(localPos.Y) < half.Y + 3 then
			local top = bed.CFrame:PointToWorldSpace(Vector3.new(localPos.X, half.Y, localPos.Z))
			return plot.origin:PointToObjectSpace(top), nil
		end
	end
	return nil, "Plant on the brown soil in your garden!"
end

local function refreshTools(player: Player)
	local profile = services.DataService:Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not profile or not backpack then
		return
	end
	local character = player.Character
	local existing: { [string]: Tool } = {}
	for _, container in { backpack, character } do
		if container then
			for _, tool in container:GetChildren() do
				if tool:IsA("Tool") and tool:GetAttribute("PlaceItem") then
					existing[tool:GetAttribute("PlaceItem")] = tool
				end
			end
		end
	end
	for itemId, tool in existing do
		if (profile.pouch[itemId] or 0) <= 0 then
			tool:Destroy()
		end
	end
	for _, category in { "Seeds", "Decor" } do
		for _, item in Catalog.ByCategory[category] do
			local count = profile.pouch[item.id] or 0
			if count > 0 then
				local tool = existing[item.id]
				if not tool then
					tool = Instance.new("Tool")
					tool.RequiresHandle = false
					tool.CanBeDropped = false
					tool:SetAttribute("PlaceItem", item.id)
					tool.ToolTip = "Click your garden soil to place"
					tool.Parent = backpack
				end
				tool.Name = (if item.kind == "Plant" then "🌱 " else "🦩 ") .. item.name .. " x" .. count
			end
		end
	end
	if not backpack:FindFirstChild("Shovel") and not (character and character:FindFirstChild("Shovel")) then
		local shovel = Instance.new("Tool")
		shovel.Name = "Shovel"
		shovel.RequiresHandle = false
		shovel.CanBeDropped = false
		shovel.ToolTip = "Click one of your plants to dig it up"
		shovel:SetAttribute("Shovel", true)
		shovel.Parent = backpack
	end
end

local function plant(player: Player, itemId: any, position: any, rotation: any): (boolean, string)
	local item = typeof(itemId) == "string" and Catalog.get(itemId)
	if not item or not Catalog.isPlaceable(item) or typeof(position) ~= "Vector3" then
		return false, "That can't be planted."
	end
	local plot = services.PlotService:GetPlot(player)
	local state = plot and loaded[plot]
	local profile = services.DataService:Get(player)
	if not plot or not state or not profile then
		return false, "Claim a plot first!"
	end
	if (profile.pouch[item.id] or 0) <= 0 then
		return false, "You don't have any " .. item.name .. " left. Buy more at the shop!"
	end
	if #profile.garden >= Economy.MaxPlants then
		return false, "Your garden is full! Dig something up with the Shovel first."
	end
	local radius = item.radius or 2
	local spot, err = locate(plot, position, radius)
	if not spot then
		return false, err :: string
	end
	for _, other in profile.garden do
		local otherItem = Catalog.get(other.item)
		local need = (radius + (if otherItem then otherItem.radius or 2 else 2)) * SPACING
		if (Vector2.new(other.x, other.z) - Vector2.new(spot.X, spot.Z)).Magnitude < need then
			return false, "Too close to another plant. Give it some room!"
		end
	end
	local record = {
		id = string.sub(HttpService:GenerateGUID(false), 1, 8),
		item = item.id,
		x = math.floor(spot.X * 100 + 0.5) / 100,
		y = math.floor(spot.Y * 100 + 0.5) / 100,
		z = math.floor(spot.Z * 100 + 0.5) / 100,
		r = if typeof(rotation) == "number" and rotation == rotation then math.floor(rotation % 360) else math.random(0, 359),
		t = os.time(),
	}
	services.DataService:Update(player, function(p)
		p.pouch[item.id] -= 1
		if p.pouch[item.id] <= 0 then
			p.pouch[item.id] = nil
		end
		table.insert(p.garden, record)
	end)
	spawnPlant(state, record)
	refreshTools(player)
	Remotes.MachineFx:FireAllClients(state.models[record.id], "Planted", {})
	return true, if item.kind == "Plant" then item.name .. " planted! Watch it grow." else item.name .. " placed!"
end

local function dig(player: Player, plantId: any): (boolean, string)
	local plot = services.PlotService:GetPlot(player)
	local state = plot and loaded[plot]
	if not state or typeof(plantId) ~= "string" then
		return false, "Nothing to dig."
	end
	local found = nil
	services.DataService:Update(player, function(p)
		for i, record in p.garden do
			if record.id == plantId then
				found = table.remove(p.garden, i)
				p.pouch[found.item] = (p.pouch[found.item] or 0) + 1
				break
			end
		end
	end)
	if not found then
		return false, "That's not one of your plants."
	end
	local model = state.models[plantId]
	if model then
		Remotes.MachineFx:FireAllClients(model, "Dug", {})
		state.models[plantId] = nil
		task.delay(0.35, function()
			model:Destroy()
		end)
	end
	refreshTools(player)
	local item = Catalog.get(found.item)
	return true, (if item then item.name else "Plant") .. " went back into your pouch."
end

function GardenService:LoadFor(plot, player: Player)
	local profile = services.DataService:Get(player)
	if not profile then
		return
	end
	local state: Loaded = { plot = plot, player = player, models = {} }
	loaded[plot] = state
	for i, record in profile.garden do
		spawnPlant(state, record)
		if i % 8 == 0 then
			task.wait()
		end
	end
	refreshTools(player)
end

function GardenService:ClearFor(plot)
	local state = loaded[plot]
	loaded[plot] = nil
	if state then
		for _, model in state.models do
			model:Destroy()
		end
	end
	plot.plantsFolder:ClearAllChildren()
end

function GardenService:RefreshTools(player: Player)
	refreshTools(player)
end

function GardenService:Init(allServices)
	services = allServices
end

function GardenService:Start()
	Remotes.GardenRequest.OnServerInvoke = function(player: Player, action: string, ...)
		if action == "Plant" then
			return plant(player, ...)
		elseif action == "Dig" then
			return dig(player, ...)
		end
		return false, "Unknown request"
	end

	local function onCharacter(player: Player)
		task.wait(0.2)
		refreshTools(player)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	services.DataService.Loaded:Connect(function(player)
		refreshTools(player)
	end)

	-- grow!
	task.spawn(function()
		while true do
			task.wait(GROW_TICK)
			for _, state in loaded do
				for _, model in state.models do
					if model:GetAttribute("Grown") then
						continue
					end
					local item = Catalog.get(model:GetAttribute("Item"))
					if not item then
						continue
					end
					local scale, grown = growthScale(item, model:GetAttribute("PlantedAt"))
					if math.abs(model:GetScale() - scale) > 0.004 then
						model:ScaleTo(scale)
					end
					if grown then
						model:SetAttribute("Grown", true)
						Remotes.MachineFx:FireAllClients(model, "Grown", {})
						if state.player.Parent then
							Remotes.Notify:FireClient(state.player, "Your " .. item.name .. " is fully grown! 🌟", "success")
						end
					end
				end
			end
		end
	end)
end

return GardenService
