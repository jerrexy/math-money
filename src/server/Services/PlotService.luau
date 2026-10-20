--[[
	The 8 plots (4 on each side of the plaza).

	Workspace.World.Plots.PlotN is built in Studio (tools/studio/build_world.luau)
	and contains:
	  Origin      invisible part; its CFrame is "plot space" (LookVector faces the plaza)
	  Slots       one invisible part per machine kind, the machine's pivot
	  Beds        garden soil parts you can plant on
	  Spawn       where the owner appears
	  ClaimSign   board with a "Claim" ProximityPrompt
	  Gate        arch whose NameBoard shows the owner's name
	A player claims a free plot (or gets one from the HUD's Home button); their
	machines and saved garden load in, and everything is cleared when they leave.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Machines = require(Shared.Config.Machines)
local Remotes = require(Shared.Remotes)

local PlotService = {}
local services

export type Plot = {
	index: number,
	model: Model,
	origin: CFrame,
	slots: { [string]: BasePart },
	beds: { BasePart },
	spawn: BasePart?,
	owner: Player?,
	machinesFolder: Folder,
	plantsFolder: Folder,
	prompt: ProximityPrompt?,
}

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}

local function folder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f :: Folder
end

local function setBoard(board: Instance?, title: string, subtitle: string)
	if not board then
		return
	end
	for _, gui in board:GetDescendants() do
		if gui:IsA("TextLabel") then
			if gui.Name == "Title" then
				gui.Text = title
			elseif gui.Name == "Subtitle" then
				gui.Text = subtitle
			end
		end
	end
end

local function refreshSigns(plot: Plot)
	local claimSign = plot.model:FindFirstChild("ClaimSign")
	local gate = plot.model:FindFirstChild("Gate")
	if plot.owner then
		setBoard(claimSign, plot.owner.DisplayName .. "'s Plot", "Money machines + garden")
		setBoard(gate and gate:FindFirstChild("NameBoard"), plot.owner.DisplayName .. "'s Plot", "")
	else
		setBoard(claimSign, "FREE PLOT!", "Walk up to claim it!")
		setBoard(gate and gate:FindFirstChild("NameBoard"), "Plot " .. plot.index, "Free!")
	end
	if plot.prompt then
		plot.prompt.Enabled = plot.owner == nil
	end
	plot.model:SetAttribute("OwnerId", if plot.owner then plot.owner.UserId else 0)
	plot.model:SetAttribute("OwnerName", if plot.owner then plot.owner.DisplayName else "")
end

local function teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(cframe + Vector3.new(0, 3.5, 0))
	end
end

local function spawnCFrame(plot: Plot): CFrame
	return if plot.spawn then plot.spawn.CFrame else plot.origin
end

local function claim(plot: Plot, player: Player): boolean
	if plot.owner or byPlayer[player] then
		return false
	end
	local profile = services.DataService:WaitFor(player)
	if not profile or not player.Parent or plot.owner then
		return false
	end
	plot.owner = player
	byPlayer[player] = plot
	player:SetAttribute("PlotIndex", plot.index)
	refreshSigns(plot)
	services.MachineService:SpawnFor(plot, player)
	services.GardenService:LoadFor(plot, player)
	Remotes.Notify:FireClient(player, "Welcome to your plot! Walk up to a machine's computer to start earning money.", "success")
	return true
end

local function release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	services.MachineService:ClearFor(plot)
	services.GardenService:ClearFor(plot)
	plot.owner = nil
	refreshSigns(plot)
end

local function readPlot(model: Model, index: number): Plot?
	local origin = model:FindFirstChild("Origin") :: BasePart?
	if not origin then
		warn("[PlotService] " .. model:GetFullName() .. " has no Origin part")
		return nil
	end
	local slots = {}
	local slotFolder = model:FindFirstChild("Slots")
	for _, kind in Machines.Order do
		local slot = slotFolder and slotFolder:FindFirstChild(kind)
		if slot and slot:IsA("BasePart") then
			slots[kind] = slot
		end
	end
	local beds = {}
	local bedFolder = model:FindFirstChild("Beds")
	if bedFolder then
		for _, bed in bedFolder:GetChildren() do
			if bed:IsA("BasePart") then
				table.insert(beds, bed)
			end
		end
	end
	local plot: Plot = {
		index = index,
		model = model,
		origin = origin.CFrame,
		slots = slots,
		beds = beds,
		spawn = model:FindFirstChild("Spawn") :: BasePart?,
		owner = nil,
		machinesFolder = folder(model, "Machines"),
		plantsFolder = folder(model, "Plants"),
		prompt = nil,
	}
	local claimSign = model:FindFirstChild("ClaimSign")
	local prompt = claimSign and claimSign:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		plot.prompt = prompt
		prompt.Triggered:Connect(function(player)
			if byPlayer[player] then
				Remotes.Notify:FireClient(player, "You already have a plot! Press the 🏠 button to go home.", "info")
				return
			end
			claim(plot, player)
		end)
	end
	refreshSigns(plot)
	return plot
end

function PlotService:Init(allServices)
	services = allServices
	local world = workspace:WaitForChild("World", 30)
	local plotFolder = world and world:WaitForChild("Plots", 10)
	if not plotFolder then
		warn("[PlotService] Workspace.World.Plots not found; no plots this session")
		return
	end
	local models = plotFolder:GetChildren()
	table.sort(models, function(a, b)
		return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
	end)
	for i, model in models do
		if model:IsA("Model") then
			local plot = readPlot(model, model:GetAttribute("Index") or i)
			if plot then
				table.insert(plots, plot)
			end
		end
	end
end

function PlotService:Start()
	Players.PlayerRemoving:Connect(release)

	local function onCharacter(player: Player, character: Model)
		local plot = byPlayer[player]
		if plot then
			character:WaitForChild("HumanoidRootPart", 5)
			task.wait(0.1)
			teleport(player, spawnCFrame(plot))
		end
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	Remotes.PlayerAction.OnServerEvent:Connect(function(player: Player, action: string)
		if action == "Home" then
			local plot = byPlayer[player]
			if not plot then
				-- one-click for little players: grab the first free plot
				for _, candidate in plots do
					if not candidate.owner and claim(candidate, player) then
						plot = candidate
						break
					end
				end
			end
			if plot then
				teleport(player, spawnCFrame(plot))
			else
				Remotes.Notify:FireClient(player, "All plots are taken right now. Try another server!", "info")
			end
		elseif action == "Shop" then
			local world = workspace:FindFirstChild("World")
			local spot = world and world:FindFirstChild("ShopSpot", true) :: BasePart?
			if spot then
				teleport(player, spot.CFrame)
			end
		end
	end)
end

function PlotService:GetPlot(player: Player): Plot?
	return byPlayer[player]
end

function PlotService:GetPlots(): { Plot }
	return plots
end

return PlotService
