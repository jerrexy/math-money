--[[
	Little client-side flourishes for shop items:
	  Rubber Chicken -> squash-and-stretch on every squeak
	  Confetti Cannon -> a burst of confetti from the barrel
	  Speed Sneakers -> sparkly trail
	  Spring Shoes   -> "boing" on every jump
	  Pet Rock       -> happy little hops
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EffectsController = {}
local controllers

local CONFETTI_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 120)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 220, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 110, 255)),
})

local function confetti(tool: Tool)
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return
	end
	local att = Instance.new("Attachment")
	att.CFrame = CFrame.new(0, 0, -handle.Size.Z / 2)
	att.Parent = handle
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = CONFETTI_COLORS
	emitter.Size = NumberSequence.new(0.35)
	emitter.Lifetime = NumberRange.new(1.2, 2)
	emitter.Speed = NumberRange.new(18, 30)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Acceleration = Vector3.new(0, -25, 0)
	emitter.RotSpeed = NumberRange.new(-300, 300)
	emitter.EmissionDirection = Enum.NormalId.Front
	emitter.Rate = 0
	emitter.Parent = att
	emitter:Emit(60)
	task.delay(2.5, function()
		att:Destroy()
	end)
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
