--[[
	Everything the shop puts on (or next to) your character:
	  costumes  -> Accessories in the Hat / Face / Waist slots
	  tools     -> Rubber Chicken, Confetti Cannon (in the backpack)
	  passives  -> Speed Sneakers (faster), Spring Shoes (higher jumps)
	  pets      -> Pet Rock that follows you around
	Re-applied every time the character spawns or the player changes something.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)
local Sounds = require(Shared.Config.Sounds)

local AvatarService = {}
local services

local SLOT_ATTACHMENT = {
	Hat = "HatAttachment",
	Face = "FaceFrontAttachment",
	Waist = "WaistCenterAttachment",
}
local SLOT_REPLACES = {
	Hat = Enum.AccessoryType.Hat,
	Face = Enum.AccessoryType.Face,
}
local BASE_WALK_SPEED = 20
local FAST_WALK_SPEED = 30
local BASE_JUMP = 7.2
local SPRING_JUMP = 16

local function assetModel(group: string, name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(group)
	local found = folder and folder:FindFirstChild(name)
	return if found then found:Clone() :: Model else nil
end

--- Weld a template model's parts to a handle (all unanchored, massless, no collisions).
local function prepareParts(model: Model): BasePart?
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		return nil
	end
	-- the biggest part becomes the handle
	table.sort(parts, function(a, b)
		return a.Size.Magnitude > b.Size.Magnitude
	end)
	local handle = parts[1]
	for _, part in parts do
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		if part ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
		end
	end
	return handle
end

local function buildAccessory(item): Accessory?
	local model = assetModel("Costumes", item.model)
	if not model then
		return nil
	end
	local origin = model:GetPivot()
	local handle = prepareParts(model)
	if not handle then
		return nil
	end
	local accessory = Instance.new("Accessory")
	accessory.Name = "MM_" .. item.id
	accessory:SetAttribute("MMCostume", item.id)
	local attachment = Instance.new("Attachment")
	attachment.Name = SLOT_ATTACHMENT[item.slot] or "HatAttachment"
	attachment.CFrame = handle.CFrame:ToObjectSpace(origin)
	attachment.Parent = handle
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= handle then
			part.Parent = handle
		end
	end
	handle.Name = "Handle"
	handle.Parent = accessory
	model:Destroy()
	return accessory
end

local function playSound(parent: Instance, id: string, volume: number)
	if id == "" or id == "rbxassetid://0" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.RollOffMaxDistance = 90
	sound.Parent = parent
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local function buildTool(item): Tool
	local tool = Instance.new("Tool")
	tool.Name = item.name
	tool.CanBeDropped = false
	tool.ToolTip = item.description
	tool:SetAttribute("MMTool", item.id)
	local model = assetModel("Fun", item.model)
	local handle = model and prepareParts(model)
	if model and handle then
		local origin = model:GetPivot()
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part ~= handle then
				part.Parent = handle
			end
		end
		handle.Name = "Handle"
		tool.Grip = handle.CFrame:ToObjectSpace(origin)
		handle.Parent = tool
		model:Destroy()
	else
		local part = Instance.new("Part")
		part.Name = "Handle"
		part.Size = Vector3.new(0.6, 0.6, 2)
		part.Color = Color3.fromRGB(255, 220, 60)
		part.CanCollide = false
		part.Massless = true
		part.Parent = tool
	end
	local cooldown = 0
	tool.Activated:Connect(function()
		if os.clock() - cooldown < 0.45 then
			return
		end
		cooldown = os.clock()
		local h = tool:FindFirstChild("Handle")
		if not h then
			return
		end
		if item.id == "RubberChicken" then
			playSound(h, Sounds.Squeak, 0.8)
			tool:SetAttribute("Squeak", os.clock())
		elseif item.id == "ConfettiCannon" then
			playSound(h, Sounds.Confetti, 0.7)
			tool:SetAttribute("Fire", os.clock())
		end
	end)
	return tool
end

local function clearCostumes(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") and child:GetAttribute("MMCostume") then
			child:Destroy()
		end
	end
end

local function applyPet(player: Player, character: Model, enabled: boolean)
	local existing = workspace:FindFirstChild("MM_Pet_" .. player.UserId)
	if existing then
		existing:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not enabled or not root then
		return
	end
	local model = assetModel("Fun", "PetRock")
	local body: BasePart
	if model then
		body = prepareParts(model) :: BasePart
	else
		model = Instance.new("Model")
		body = Instance.new("Part")
		body.Shape = Enum.PartType.Ball
		body.Size = Vector3.new(1.6, 1.6, 1.6)
		body.Material = Enum.Material.Slate
		body.Color = Color3.fromRGB(130, 128, 124)
		body.CanCollide = false
		body.Parent = model
	end
	model.Name = "MM_Pet_" .. player.UserId
	model:SetAttribute("PetOwner", player.UserId)
	local follow = root:FindFirstChild("MM_PetSpot") :: Attachment?
	if not follow then
		follow = Instance.new("Attachment")
		follow.Name = "MM_PetSpot"
		follow.Position = Vector3.new(2.6, -1.6, 2.2)
		follow.Parent = root
	end
	local att = Instance.new("Attachment")
	att.Parent = body
	local align = Instance.new("AlignPosition")
	align.Attachment0 = att
	align.Attachment1 = follow
	align.MaxForce = 25000
	align.Responsiveness = 18
	align.Parent = body
	local orient = Instance.new("AlignOrientation")
	orient.Attachment0 = att
	orient.Attachment1 = follow
	orient.MaxTorque = 25000
	orient.Responsiveness = 12
	orient.Parent = body
	model:PivotTo(root.CFrame * CFrame.new(2.6, -1.6, 2.2))
	model.Parent = workspace
	pcall(function()
		body:SetNetworkOwner(player)
	end)
end

function AvatarService:Apply(player: Player)
	local profile = services.DataService:Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not character or not humanoid then
		return
	end

	clearCostumes(character)
	for slot, itemId in profile.equipped do
		local item = Catalog.get(itemId)
		if item and profile.owned[itemId] and item.slot == slot then
			local replaces = SLOT_REPLACES[slot]
			if replaces then
				for _, acc in humanoid:GetAccessories() do
					if acc.AccessoryType == replaces and not acc:GetAttribute("MMCostume") then
						acc:Destroy()
					end
				end
			end
			local accessory = buildAccessory(item)
			if accessory then
				humanoid:AddAccessory(accessory)
			end
		end
	end

	local fast = profile.toggles.SpeedSneakers and profile.owned.SpeedSneakers
	local springy = profile.toggles.SpringShoes and profile.owned.SpringShoes
	humanoid.WalkSpeed = if fast then FAST_WALK_SPEED else BASE_WALK_SPEED
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = if springy then SPRING_JUMP else BASE_JUMP
	character:SetAttribute("SpeedSneakers", fast == true)
	character:SetAttribute("SpringShoes", springy == true)

	applyPet(player, character, profile.toggles.PetRock == true and profile.owned.PetRock == true)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, item in Catalog.ByCategory.Fun do
			if item.kind == "Tool" and profile.owned[item.id] then
				local has = false
				for _, container in { backpack, character } do
					for _, tool in container:GetChildren() do
						if tool:GetAttribute("MMTool") == item.id then
							has = true
						end
					end
				end
				if not has then
					buildTool(item).Parent = backpack
				end
			end
		end
	end
end

function AvatarService:Init(allServices)
	services = allServices
end

function AvatarService:Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			task.wait(0.3) -- let the avatar's own accessories load first
			self:Apply(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	services.DataService.Loaded:Connect(function(player)
		self:Apply(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local pet = workspace:FindFirstChild("MM_Pet_" .. player.UserId)
		if pet then
			pet:Destroy()
		end
	end)
end

return AvatarService
