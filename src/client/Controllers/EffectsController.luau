--[[
	Little client-side flourishes for shop items:
	  Rubber Chicken -> squash-and-stretch on every squeak
	  Confetti Cannon -> a blast of real paper confetti that flutters down and lands
	  Speed Sneakers -> sparkly trail
	  Spring Shoes   -> "boing" on every jump
	  Pet Rock       -> happy little hops
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EffectsController = {}
local controllers

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 84, 120),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(90, 220, 120),
	Color3.fromRGB(80, 170, 255),
	Color3.fromRGB(190, 110, 255),
	Color3.fromRGB(255, 150, 60),
	Color3.fromRGB(255, 255, 255),
}
local CONFETTI_PER_SHOT = 90
local CONFETTI_MAX = 400 -- across all players, so a confetti party can't lag anyone
local CONFETTI_REST = 4 -- seconds a piece lies on the ground before fading

type Piece = {
	part: BasePart,
	velocity: Vector3,
	spin: Vector3,
	phase: number,
	age: number,
	landedAt: number?,
	ground: number?,
	nextCheck: number,
}
local pieces: { Piece } = {}
local confettiFolder: Folder
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

--- Real paper confetti: little flat pieces that blast out of the cannon, flutter
--- down with air drag, land on the ground and fade away a few seconds later.
local function confetti(tool: Tool)
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	local character = tool.Parent
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not handle or not root then
		return
	end
	local look = root.CFrame.LookVector
	local up = Vector3.yAxis
	local origin = handle.Position + look * 1.4 + up * 0.6
	local aim = (look + up * 1.15).Unit
	local rng = Random.new()
	for _ = 1, CONFETTI_PER_SHOT do
		if #pieces >= CONFETTI_MAX then
			local oldest = table.remove(pieces, 1)
			if oldest then
				oldest.part:Destroy()
			end
		end
		local part = Instance.new("Part")
		part.Size = Vector3.new(rng:NextNumber(0.4, 0.58), 0.04, rng:NextNumber(0.26, 0.36))
		part.Color = CONFETTI_COLORS[rng:NextInteger(1, #CONFETTI_COLORS)]
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.CFrame = CFrame.new(origin)
			* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
		part.Parent = confettiFolder
		local spread = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 0.6
		table.insert(pieces, {
			part = part,
			velocity = (aim + spread).Unit * rng:NextNumber(36, 58),
			spin = Vector3.new(rng:NextNumber(-9, 9), rng:NextNumber(-9, 9), rng:NextNumber(-9, 9)),
			phase = rng:NextNumber(0, 6.28),
			age = 0,
			landedAt = nil,
			ground = nil,
			nextCheck = 0,
		})
	end
	controllers.MachineRenderer.smokePuff(origin, Color3.fromRGB(255, 255, 255), 8)
end

local function updateConfetti(dt: number)
	if #pieces == 0 then
		return
	end
	local world = workspace:FindFirstChild("World")
	groundParams.FilterDescendantsInstances = if world then { workspace.Terrain, world } else { workspace.Terrain }
	for i = #pieces, 1, -1 do
		local c = pieces[i]
		c.age += dt
		local part = c.part
		if c.landedAt then
			local resting = c.age - c.landedAt
			if resting > CONFETTI_REST then
				part.Transparency = math.min(1, (resting - CONFETTI_REST) / 1.5)
				if resting > CONFETTI_REST + 1.5 then
					part:Destroy()
					table.remove(pieces, i)
				end
			end
			continue
		end
		-- gravity + strong air drag makes paper float; a little sway makes it flutter
		c.velocity += Vector3.new(0, -30, 0) * dt
		c.velocity *= 1 - math.min(1, 1.9 * dt)
		local sway = Vector3.new(math.sin(c.age * 6 + c.phase), 0, math.cos(c.age * 5 + c.phase)) * 2
		local position = part.Position + (c.velocity + sway) * dt
		c.nextCheck -= dt
		if c.nextCheck <= 0 then
			c.nextCheck = 0.12
			local hit = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -80, 0), groundParams)
			c.ground = if hit then hit.Position.Y else nil
		end
		if c.ground and c.velocity.Y < 0 and position.Y <= c.ground + 0.04 then
			c.landedAt = c.age
			part.CFrame = CFrame.new(position.X, c.ground + 0.03, position.Z) * CFrame.Angles(0, c.phase, 0)
		elseif c.age > 12 then
			part:Destroy()
			table.remove(pieces, i)
		else
			local rotation = part.CFrame.Rotation * CFrame.Angles(c.spin.X * dt, c.spin.Y * dt, c.spin.Z * dt)
			part.CFrame = CFrame.new(position) * rotation
		end
	end
end

local function squash(tool: Tool)
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return
	end
	local size = handle:GetAttribute("BaseSize") or handle.Size
	handle:SetAttribute("BaseSize", size)
	task.spawn(function()
		for i = 1, 8 do
			local k = math.sin(i / 8 * math.pi)
			handle.Size = size * Vector3.new(1 + 0.25 * k, 1 - 0.3 * k, 1 + 0.25 * k)
			task.wait(0.02)
		end
		handle.Size = size
	end)
end

local function watchTool(tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("FxHooked") then
		return
	end
	tool:SetAttribute("FxHooked", true)
	tool:GetAttributeChangedSignal("Fire"):Connect(function()
		confetti(tool)
	end)
	tool:GetAttributeChangedSignal("Squeak"):Connect(function()
		squash(tool)
	end)
end

local function watchCharacter(character: Model, owner: Player)
	character.ChildAdded:Connect(watchTool)
	for _, child in character:GetChildren() do
		watchTool(child)
	end
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return
	end
	-- sparkle trail for speed sneakers
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, -2.6, 0.4)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.6, 0.4)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.LightEmission = 0.7
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(120, 220, 255))
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Parent = root
	local function refreshTrail()
		trail.Enabled = character:GetAttribute("SpeedSneakers") == true
	end
	character:GetAttributeChangedSignal("SpeedSneakers"):Connect(refreshTrail)
	refreshTrail()
	if owner == Players.LocalPlayer then
		humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping and character:GetAttribute("SpringShoes") then
				controllers.SoundController.play("Boing", root.Position, 0.5)
			end
		end)
	end
end

local function watchPlayer(p: Player)
	p.CharacterAdded:Connect(function(character)
		watchCharacter(character, p)
	end)
	if p.Character then
		task.spawn(watchCharacter, p.Character, p)
	end
end

function EffectsController:Start(all)
	controllers = all
	confettiFolder = Instance.new("Folder")
	confettiFolder.Name = "MM_Confetti"
	confettiFolder.Parent = workspace
	RunService.Heartbeat:Connect(updateConfetti)
	Players.PlayerAdded:Connect(watchPlayer)
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	-- pet rocks hop happily (purely visual, local to each client)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, child in workspace:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("PetOwner") then
				for _, part in child:GetDescendants() do
					if part:IsA("AlignPosition") then
						local att = part.Attachment1
						if att then
							att.Position = Vector3.new(2.6, -1.6 + math.abs(math.sin(t * 5)) * 0.8, 2.2)
						end
					end
				end
			end
		end
	end)
end

return EffectsController
