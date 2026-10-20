--[[
	Everything the shop puts on (or next to) your character:
	  costumes  -> Accessories in the Hat / Face / Waist / Back slots
	  tools     -> Rubber Chicken, Confetti Cannon (in the backpack)
	  shoes     -> Speed Sneakers (faster) / Spring Shoes (higher jumps), built onto
	               the feet; only one pair at a time (the Feet slot)
	  pets      -> the Pet Rock or the Baby Frog follows you around (one at a time)
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
	Back = "BodyBackAttachment",
}
local SLOT_REPLACES = {
	Hat = Enum.AccessoryType.Hat,
	Face = Enum.AccessoryType.Face,
	Back = Enum.AccessoryType.Back,
}
local BASE_WALK_SPEED = 20
local FAST_WALK_SPEED = 30
local BASE_JUMP = 7.2
local SPRING_JUMP = 16
local SPRING_LIFT = 1.0 -- R15 characters stand this much taller on their springs

local SHOE_STYLES = {
	SpeedSneakers = {
		upper = Color3.fromRGB(232, 54, 66),
		toe = Color3.fromRGB(250, 250, 250),
		stripe = Color3.fromRGB(255, 212, 50),
		spring = false,
	},
	SpringShoes = {
		upper = Color3.fromRGB(70, 140, 240),
		toe = Color3.fromRGB(250, 250, 250),
		stripe = Color3.fromRGB(255, 255, 255),
		spring = true,
	},
}

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
	local model = assetModel(item.assetFolder or "Costumes", item.model)
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

local function playSound(parent: Instance, name: string, volume: number)
	local def = Sounds[name]
	if not def or def.id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.id
	sound.Volume = volume * (def.volume or 1)
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
			playSound(h, "Squeak", 0.8)
			tool:SetAttribute("Squeak", os.clock())
		elseif item.id == "ConfettiCannon" then
			playSound(h, "Confetti", 0.7)
			tool:SetAttribute("Fire", os.clock())
		end
	end)
	return tool
end

--- Cartoon shoes built from parts and welded to each foot (they follow the walk
--- animation). Spring shoes add a coil under each sole.
local function shoePart(parent: Instance, foot: BasePart, name: string, size: Vector3, cf: CFrame, color: Color3,
	sphere: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	if sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = foot
	weld.Part1 = part
	weld.Parent = part
	part.Parent = parent
	return part
end

local function buildShoe(parent: Instance, foot: BasePart, style, r15: boolean)
	local width = (if r15 then math.max(foot.Size.X, 0.7) else 1) * 1.18
	local length = (if r15 then math.max(foot.Size.Z, 0.8) else 1) * 1.4
	local base = foot.CFrame * CFrame.new(0, -foot.Size.Y / 2, -length * 0.1)
	local white = Color3.fromRGB(250, 250, 250)
	local sole = shoePart(parent, foot, "Sole", Vector3.new(width, 0.24, length), base * CFrame.new(0, 0.12, 0), white)
	shoePart(parent, foot, "Upper", Vector3.new(width * 0.96, 0.72, length * 0.92), base * CFrame.new(0, 0.4, 0.06), style.upper, true)
	shoePart(parent, foot, "Toe", Vector3.new(width * 0.84, 0.44, length * 0.44), base * CFrame.new(0, 0.3, -length * 0.3), style.toe, true)
	for _, side in { -1, 1 } do
		shoePart(parent, foot, "Stripe", Vector3.new(0.05, 0.14, length * 0.5),
			base * CFrame.new(side * width * 0.47, 0.42, 0.02) * CFrame.Angles(0.35, 0, 0), style.stripe)
	end
	for k = 0, 2 do
		shoePart(parent, foot, "Lace", Vector3.new(width * 0.42, 0.05, 0.07), base * CFrame.new(0, 0.74 - k * 0.02, -length * 0.05 + k * 0.17), white)
	end
	if style.spring and r15 then
		local pad = shoePart(parent, foot, "SpringPad", Vector3.new(0.12, width * 0.72, width * 0.72),
			base * CFrame.new(0, -SPRING_LIFT + 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 70, 80))
		pad.Shape = Enum.PartType.Cylinder
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, -0.12, 0)
		top.Parent = sole
		local bottomAtt = Instance.new("Attachment")
		bottomAtt.Parent = pad
		bottomAtt.WorldPosition = (base * CFrame.new(0, -SPRING_LIFT + 0.12, 0)).Position
		local coil = Instance.new("SpringConstraint")
		coil.Attachment0 = top
		coil.Attachment1 = bottomAtt
		coil.Visible = true
		coil.Coils = 6
		coil.Radius = 0.3
		coil.Thickness = 0.08
		coil.Color = BrickColor.new("Medium stone grey")
		coil.Stiffness = 0
		coil.Parent = sole
	end
end

local function applyShoes(character: Model, humanoid: Humanoid, itemId: string?)
	local old = character:FindFirstChild("MM_Shoes")
	if old then
		old:Destroy()
	end
	local r15 = humanoid.RigType == Enum.HumanoidRigType.R15
	-- springs need room under the feet: raise R15 characters a little
	local baseHip = humanoid:GetAttribute("MMBaseHip")
	if baseHip == nil then
		baseHip = humanoid.HipHeight
		humanoid:SetAttribute("MMBaseHip", baseHip)
	end
	local style = itemId and SHOE_STYLES[itemId]
	humanoid.HipHeight = if style and style.spring and r15 then baseHip + SPRING_LIFT else baseHip
	if not style then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "MM_Shoes"
	local names = if r15 then { "LeftFoot", "RightFoot" } else { "Left Leg", "Right Leg" }
	for _, name in names do
		local foot = character:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			buildShoe(folder, foot, style, r15)
		end
	end
	folder.Parent = character
end

local function clearCostumes(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") and child:GetAttribute("MMCostume") then
			child:Destroy()
		end
	end
end

local function applyPet(player: Player, character: Model, pet)
	local existing = workspace:FindFirstChild("MM_Pet_" .. player.UserId)
	if existing then
		existing:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not pet or not root then
		return
	end
	local model = assetModel(pet.assetFolder or "Fun", pet.model)
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
	-- line up the whole model (not just its biggest part, which may be turned
	-- inside it) with the player, so the pet faces where you're going
	att.CFrame = body.CFrame:ToObjectSpace(model:GetPivot()).Rotation
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

	-- one pair of shoes at a time (Spring Shoes win if an old save has both on)
	local shoes = nil
	if profile.toggles.SpringShoes and profile.owned.SpringShoes then
		shoes = "SpringShoes"
	elseif profile.toggles.SpeedSneakers and profile.owned.SpeedSneakers then
		shoes = "SpeedSneakers"
	end
	applyShoes(character, humanoid, shoes)
	local fast = shoes == "SpeedSneakers"
	local springy = shoes == "SpringShoes"
	humanoid.WalkSpeed = if fast then FAST_WALK_SPEED else BASE_WALK_SPEED
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = if springy then SPRING_JUMP else BASE_JUMP
	character:SetAttribute("SpeedSneakers", fast)
	character:SetAttribute("SpringShoes", springy)

	local pet = nil
	for _, item in Catalog.ByCategory.Fun do
		if item.kind == "Pet" and profile.owned[item.id] and profile.toggles[item.id] then
			pet = item
			break
		end
	end
	applyPet(player, character, pet)

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
