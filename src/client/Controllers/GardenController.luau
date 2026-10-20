--[[
	Planting and digging in your garden.

	Equip a seed / decor tool from the backpack: a see-through preview follows
	the mouse (green on your soil, red elsewhere; R rotates it). Click (or tap) to
	plant. Equip the Shovel and click one of your plants to dig it back into the pouch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)
local Remotes = require(Shared.Remotes)
local Theme = require(script.Parent.Parent.UI.Theme)

local GardenController = {}
local controllers
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local ghost: Model? = nil
local ghostItem: string? = nil
local highlight: Highlight
local rotation = 0
local busy = false

local function myPlot(): Instance?
	local index = player:GetAttribute("PlotIndex") or 0
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerId") == player.UserId or plot:GetAttribute("Index") == index and index > 0 then
			return plot
		end
	end
	return nil
end

local function onMyBed(part: Instance?): boolean
	local plot = myPlot()
	local beds = plot and plot:FindFirstChild("Beds")
	return beds ~= nil and part ~= nil and part:IsDescendantOf(beds)
end

local function templateFor(item): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local group = assets and assets:FindFirstChild(item.assetFolder or (if item.kind == "Plant" then "Plants" else "Decor"))
	local source = group and group:FindFirstChild(item.model)
	if source then
		return source:Clone()
	end
	local model = Instance.new("Model")
	local part = Instance.new("Part")
	part.Size = Vector3.new(2, 3, 2)
	part.CFrame = CFrame.new(0, 1.5, 0)
	part.Parent = model
	model.WorldPivot = CFrame.new()
	return model
end

local function clearGhost()
	if ghost then
		ghost:Destroy()
	end
	ghost = nil
	ghostItem = nil
end

local function makeGhost(itemId: string)
	clearGhost()
	local item = Catalog.get(itemId)
	if not item then
		return
	end
	local model = templateFor(item)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Transparency = math.max(d.Transparency, 0.45)
			d.CastShadow = false
		end
	end
	if item.kind == "Plant" then
		model:ScaleTo(0.5)
	end
	model.Parent = workspace.CurrentCamera
	ghost = model
	ghostItem = itemId
	highlight.Adornee = model
	highlight.Enabled = true
end

local function equippedTool(): Tool?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Tool")
end

local function plantHere(itemId: string)
	if busy then
		return
	end
	local hit = mouse.Hit
	if not hit then
		return
	end
	busy = true
	local ok, message = Remotes.GardenRequest:InvokeServer("Plant", itemId, hit.Position, rotation)
	busy = false
	controllers.NotifyController.show(message, if ok then "success" else "error", 3)
	if ok then
		rotation = (rotation + 37) % 360 -- next one faces a different way: looks more natural
	end
end

local function plantUnderMouse(): Model?
	local target = mouse.Target
	while target and target ~= workspace do
		if target:IsA("Model") and target:GetAttribute("PlantId") then
			return if target:GetAttribute("OwnerId") == player.UserId then target else nil
		end
		target = target.Parent
	end
	return nil
end

local function onToolActivated(tool: Tool)
	local itemId = tool:GetAttribute("PlaceItem")
	if itemId then
		plantHere(itemId)
	elseif tool:GetAttribute("Shovel") then
		local plant = plantUnderMouse()
		if not plant then
			local verb = if Theme.isTouch() then "Tap" else "Click"
			controllers.NotifyController.show(verb .. " one of YOUR plants to dig it up.", "info", 2.5)
			return
		end
		local ok, message = Remotes.GardenRequest:InvokeServer("Dig", plant:GetAttribute("PlantId"))
		controllers.NotifyController.show(message, if ok then "success" else "error", 3)
	end
end

local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function watchCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and not hooked[child] then
			hooked[child] = true -- tools are re-parented on every equip; hook once
			child.Activated:Connect(function()
				onToolActivated(child)
			end)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			clearGhost()
			highlight.Enabled = false
		end
	end)
end

function GardenController:Start(all)
	controllers = all
	highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = workspace.CurrentCamera

	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.R and ghost then
			rotation = (rotation + 45) % 360
		end
	end)

	RunService.RenderStepped:Connect(function()
		local tool = equippedTool()
		local itemId = tool and tool:GetAttribute("PlaceItem")
		if itemId then
			if ghostItem ~= itemId then
				makeGhost(itemId)
			end
			if ghost then
				mouse.TargetFilter = ghost
				local valid = onMyBed(mouse.Target)
				ghost:PivotTo(CFrame.new(mouse.Hit.Position) * CFrame.Angles(0, math.rad(rotation), 0))
				highlight.Adornee = ghost
				highlight.FillColor = if valid then Color3.fromRGB(90, 255, 120) else Color3.fromRGB(255, 80, 80)
				highlight.OutlineColor = highlight.FillColor
				highlight.Enabled = true
			end
		elseif tool and tool:GetAttribute("Shovel") then
			if ghost then
				clearGhost()
			end
			mouse.TargetFilter = nil
			local plant = plantUnderMouse()
			highlight.Adornee = plant
			highlight.FillColor = Color3.fromRGB(255, 200, 60)
			highlight.OutlineColor = Color3.fromRGB(255, 160, 0)
			highlight.Enabled = plant ~= nil
		else
			if ghost then
				clearGhost()
			end
			highlight.Enabled = false
		end
	end)
end

return GardenController
