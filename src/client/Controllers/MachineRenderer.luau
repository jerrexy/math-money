--[[
	Client-side visuals for every money machine (and garden sparkles).

	The server only publishes numbers (attributes + MachineFx events). Each client
	turns them into motion:
	  * the plate + loot pile lowering toward the acid (DropBase/DropStart/...)
	  * a real 3D chain whose links run from the plate, over both pulleys, down to
	    the engine's drum, with pulleys / drum / gears spinning to match
	  * the engine's gauge "eyes" reacting (happy wiggle / angry spin), shakes,
	    black smoke, loot flying off into the acid, melting, and the loot flying
	    to the winner
	  * machines bouncing into place when a plot is claimed
	Geometry constants mirror tools/blender/build_apparatus.py.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Machines = require(Shared.Config.Machines)
local Remotes = require(Shared.Remotes)

local MachineRenderer = {}
local controllers
local player = Players.LocalPlayer

local TAG = "MathMachine"
local PLATE_TOP_Y = 22
local HOOK_Y = 28.4
local ACID_Y = 4.85
local DROP_DISTANCE = 16.25 -- plate top 22 -> 5.75, where the plate's belly touches the acid
local MELT_SINK = 2.4
local PULLEY_A = Vector3.new(0, 31.5, 1.6)
local PULLEY_B = Vector3.new(0, 31.5, 10.4)
local PULLEY_R = 1.6
local DRUM_DOWN_LENGTH = 31.5 - 10.6
local LINK_PITCH = 1.54
local LINK_COUNT = 38
local DRUM_R = 1.05
local LOOT_SCALE = 1.3
local UPDATE_RANGE = 320

-- loot slots on the plate: {x, z, layer} filled in this order
local SLOTS = {}
do
	table.insert(SLOTS, { 0, 0, 0 })
	for i = 0, 3 do
		local a = math.rad(45 + 90 * i)
		table.insert(SLOTS, { 1.65 * math.cos(a), 1.65 * math.sin(a), 0 })
	end
	for i = 0, 7 do
		local a = math.rad(22.5 + 45 * i)
		table.insert(SLOTS, { 3.25 * math.cos(a), 3.25 * math.sin(a), 0 })
	end
	for i = 0, 3 do
		local a = math.rad(90 * i)
		table.insert(SLOTS, { 1.3 * math.cos(a), 1.3 * math.sin(a), 1 })
	end
	table.insert(SLOTS, { 0, 0, 2 })
end

type Loot = { part: BasePart, model: Model, offset: CFrame, slot: number }
type Anim = { update: (t: number) -> boolean } -- return true when finished

local states: { [Model]: any } = {}
local anims: { Anim } = {}
local templateCache: { [string]: { model: Model, lift: number } } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function markerCF(model: Model, name: string): CFrame
	local markers = model:FindFirstChild("Markers")
	local v = markers and markers:FindFirstChild(name)
	return if v then (v :: CFrameValue).Value else CFrame.new()
end

local function assets(group: string): Instance?
	local root = ReplicatedStorage:FindFirstChild("Assets")
	return root and root:FindFirstChild(group)
end

---------------------------------------------------------------------------
-- Templates
---------------------------------------------------------------------------

local function lootTemplate(name: string)
	local cached = templateCache[name]
	if cached then
		return cached
	end
	local folder = assets("Valuables")
	local source = folder and folder:FindFirstChild(name)
	local model: Model
	if source then
		model = source:Clone()
	else
		model = Instance.new("Model")
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.2, 1.5, 1.5)
		p.CFrame = CFrame.Angles(0, 0, math.rad(90))
		p.Color = Color3.fromRGB(255, 200, 50)
		p.Material = Enum.Material.Metal
		p.Parent = model
		model.WorldPivot = CFrame.new()
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	model:ScaleTo(LOOT_SCALE)
	local cf, size = model:GetBoundingBox()
	local bottom = (cf.Position.Y - size.Y / 2) - model:GetPivot().Position.Y
	cached = { model = model, lift = -bottom }
	templateCache[name] = cached
	return cached
end

local function newLink(parent: Instance): BasePart
	local source = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("ChainLink")
	local link: BasePart
	local mesh = source and source:FindFirstChildWhichIsA("BasePart", true)
	if mesh then
		link = mesh:Clone()
	else
		link = Instance.new("Part")
		link.Size = Vector3.new(0.35, 2.2, 1.2)
		link.Color = Color3.fromRGB(80, 84, 94)
		link.Material = Enum.Material.Metal
	end
	link.Anchored = true
	link.CanCollide = false
	link.CanQuery = false
	link.CanTouch = false
	link.Parent = parent
	return link
end

---------------------------------------------------------------------------
-- Chain path (model space): hook -> up -> over pulley A -> across -> over B -> down
---------------------------------------------------------------------------

local ARC = PULLEY_R * math.pi / 2
local SPAN = PULLEY_B.Z - PULLEY_A.Z

local function chainPoint(s: number, hookY: number): (Vector3?, Vector3?)
	local l1 = (PULLEY_A.Y - hookY)
	if s <= l1 then
		return Vector3.new(0, hookY + s, 0), Vector3.yAxis
	end
	s -= l1
	if s <= ARC then
		local phi = s / PULLEY_R
		return PULLEY_A + Vector3.new(0, PULLEY_R * math.sin(phi), -PULLEY_R * math.cos(phi)),
			Vector3.new(0, math.cos(phi), math.sin(phi))
	end
	s -= ARC
	if s <= SPAN then
		return Vector3.new(0, PULLEY_A.Y + PULLEY_R, PULLEY_A.Z + s), Vector3.zAxis
	end
	s -= SPAN
	if s <= ARC then
		local psi = s / PULLEY_R
		return PULLEY_B + Vector3.new(0, PULLEY_R * math.cos(psi), PULLEY_R * math.sin(psi)),
			Vector3.new(0, -math.sin(psi), math.cos(psi))
	end
	s -= ARC
	if s <= DRUM_DOWN_LENGTH then
		return Vector3.new(0, PULLEY_B.Y - s, PULLEY_B.Z + PULLEY_R), -Vector3.yAxis
	end
	return nil, nil
end

---------------------------------------------------------------------------
-- Per-machine state
---------------------------------------------------------------------------

local function plateFrame(st, drop: number): CFrame
	return st.pivot * CFrame.new(0, -drop, 0)
end

local function placeLoot(st, slotIndex: number, name: string, rng: Random): Loot?
	local info = lootTemplate(name)
	local slot = SLOTS[slotIndex]
	if not slot then
		return nil
	end
	local model = info.model:Clone()
	local part = model:FindFirstChildWhichIsA("BasePart") :: BasePart
	if not part then
		model:Destroy()
		return nil
	end
	local tint = st.def.gemColors[rng:NextInteger(1, #st.def.gemColors)]
	if name == "Diamond" then
		part.Color = Color3.fromRGB(200, 240, 255)
	elseif string.sub(name, 1, 3) == "Gem" then
		part.Color = tint
	end
	local baseY = 0.12 + slot[3] * 0.85
	local yaw = rng:NextNumber() * math.pi * 2
	local tilt = if slot[3] == 0 then 0 else (rng:NextNumber() - 0.5) * 0.25
	local offset = CFrame.new(slot[1], PLATE_TOP_Y + baseY + info.lift, slot[2]) * CFrame.Angles(tilt, yaw, 0)
	-- each template's part pivot is the model pivot; keep the part's own offset
	local partOffset = model:GetPivot():ToObjectSpace(part.CFrame)
	model.Parent = st.folder
	return { part = part, model = model, offset = offset * partOffset, slot = slotIndex }
end

local function lootNameFor(st, slot: number, rng: Random): string
	local loot = st.def.loot
	if slot == #SLOTS and st.kind == "Division" then
		return "MiniCrown"
	end
	return loot[rng:NextInteger(1, #loot)]
end

local function rebuildLoot(st)
	for _, item in st.loot do
		item.model:Destroy()
	end
	st.loot = {}
	st.lootRng = Random.new(st.model:GetAttribute("LootSeed") or 1)
	local count = st.model:GetAttribute("Jewels") or Economy.PlateJewels
	for slot = 1, math.min(count, #SLOTS) do
		local item = placeLoot(st, slot, lootNameFor(st, slot, st.lootRng), st.lootRng)
		if item then
			table.insert(st.loot, item)
		end
	end
	st.shownJewels = count
	st.dirty = true
end

local function smokePuff(position: Vector3, color: Color3, count: number)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.4
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.2) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count)
	task.delay(2, function()
		holder:Destroy()
	end)
end

local function sparkle(position: Vector3, color: Color3, count: number)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count)
	task.delay(2, function()
		holder:Destroy()
	end)
end
MachineRenderer.sparkle = sparkle
MachineRenderer.smokePuff = smokePuff

--- Move a loot piece along an arc to a target (a Vector3 or a function returning one).
local function flyLoot(item: Loot, target: any, duration: number, delay: number, onDone: (() -> ())?)
	local startCF = item.part.CFrame
	local started = os.clock() + delay
	local spin = (math.random() - 0.5) * 12
	table.insert(anims, {
		update = function(t)
			local a = (t - started) / duration
			if a < 0 then
				return false
			end
			if not item.part.Parent then
				return true
			end
			local goal = if typeof(target) == "function" then target() else target
			if not goal then
				item.model:Destroy()
				return true
			end
			a = math.min(a, 1)
			local pos = startCF.Position:Lerp(goal, a) + Vector3.new(0, math.sin(a * math.pi) * 6, 0)
			local rot = startCF.Rotation * CFrame.Angles(a * spin, a * spin * 0.5, 0)
			item.part.CFrame = CFrame.new(pos) * rot
			if a >= 1 then
				if onDone then
					onDone()
				end
				item.model:Destroy()
				return true
			end
			return false
		end,
	})
end

--- Shrink + sink a loot piece into the acid with a green fizz.
local function dissolve(item: Loot, delay: number)
	local startCF = item.part.CFrame
	local startSize = item.part.Size
	local started = os.clock() + delay
	local fizzed = false
	table.insert(anims, {
		update = function(t)
			local a = (t - started) / 1.1
			if a < 0 then
				return false
			end
			if not item.part.Parent then
				return true
			end
			if not fizzed then
				fizzed = true
				smokePuff(startCF.Position, Color3.fromRGB(150, 255, 90), 6)
			end
			a = math.min(a, 1)
			item.part.Size = startSize * math.max(0.02, 1 - a)
			item.part.CFrame = startCF * CFrame.new(0, -a * 1.2, 0)
			if a >= 1 then
				item.model:Destroy()
				return true
			end
			return false
		end,
	})
end

local function acidLevelAt(st): number
	return (st.pivot * CFrame.new(0, ACID_Y, 0)).Position.Y
end

local function dropOff(st, count: number)
	st.dirty = true
	for _ = 1, count do
		local item = table.remove(st.loot)
		if not item then
			break
		end
		-- knock it outwards from the vat's center, but always land in the acid
		local center = Vector3.new(st.pivot.Position.X, acidLevelAt(st), st.pivot.Position.Z)
		local flat = Vector3.new(item.part.Position.X, center.Y, item.part.Position.Z) - center
		local dir = if flat.Magnitude > 0.1 then flat.Unit else st.pivot.RightVector
		local radius = math.min(flat.Magnitude + 1.5 + math.random() * 1.5, 5.2)
		local landing = center + dir * radius
		flyLoot(item, landing, 0.65, 0, function()
			smokePuff(landing, Color3.fromRGB(150, 255, 90), 8)
			controllers.SoundController.play("Sizzle", landing, 0.5, 0.9 + math.random() * 0.3)
		end)
	end
end

local function dropIn(st, count: number)
	for _ = 1, count do
		local slot = #st.loot + 1
		local item = placeLoot(st, slot, lootNameFor(st, slot, st.lootRng), st.lootRng)
		if not item then
			break
		end
		table.insert(st.loot, item)
		local started = os.clock()
		local fall = 9
		table.insert(anims, {
			update = function(t)
				local a = math.min((t - started) / 0.45, 1)
				st.dirty = true
				st.dropInOffset = st.dropInOffset or {}
				st.dropInOffset[item] = (1 - a * a) * fall
				if a >= 1 then
					st.dropInOffset[item] = nil
					sparkle(item.part.Position, Color3.fromRGB(255, 240, 150), 10)
					return true
				end
				return false
			end,
		})
	end
end

local function setupMachine(model: Model)
	if states[model] then
		return
	end
	local kind = model:GetAttribute("Kind")
	local def = Machines.Defs[kind]
	if not def then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "ClientVisuals"
	folder.Parent = model
	local pivot = model:GetPivot()
	local plate = model:FindFirstChild("Plate")
	local st = {
		model = model,
		kind = kind,
		def = def,
		pivot = pivot,
		folder = folder,
		plateParts = {},
		engineParts = {},
		base = {},
		links = {},
		loot = {},
		shownJewels = 0,
		lootRng = Random.new(1),
		shakeUntil = 0,
		shakeAmp = 0,
		mood = "idle",
		moodUntil = 0,
		meltStart = nil,
		resetFrom = 0,
		lastDrop = 0,
		dirty = true,
		chug = nil,
	}
	local function remember(part: Instance?)
		if part and part:IsA("BasePart") then
			st.base[part] = pivot:ToObjectSpace(part.CFrame)
			return part
		end
		return nil
	end
	if plate then
		for _, p in plate:GetDescendants() do
			if remember(p) then
				table.insert(st.plateParts, p)
			end
		end
	end
	for _, name in { "EngineBody", "EngineTrim", "GaugeFaces", "EngineStack" } do
		local p = remember(model:FindFirstChild(name))
		if p then
			table.insert(st.engineParts, p)
		end
	end
	st.pulleyA = remember(model:FindFirstChild("PulleyA"))
	st.pulleyB = remember(model:FindFirstChild("PulleyB"))
	st.drum = remember(model:FindFirstChild("Drum"))
	st.gear = remember(model:FindFirstChild("Gear"))
	st.gearSmall = remember(model:FindFirstChild("GearSmall"))
	st.needleL = remember(model:FindFirstChild("NeedleL"))
	st.needleR = remember(model:FindFirstChild("NeedleR"))
	st.gaugeL = markerCF(model, "GaugeL")
	st.gaugeR = markerCF(model, "GaugeR")
	st.gearC = markerCF(model, "Gear")
	st.gearSmallC = markerCF(model, "GearSmall")
	st.drumC = markerCF(model, "Drum")
	st.phase = math.random() * 10

	for i = 1, LINK_COUNT do
		st.links[i] = newLink(folder)
	end
	rebuildLoot(st)
	states[model] = st

	-- prompt only for the owner, and only while idle
	local anchor = model:FindFirstChild("PromptAnchor")
	local prompt = anchor and anchor:FindFirstChildOfClass("ProximityPrompt")
	local function refreshPrompt()
		if prompt then
			prompt.Enabled = model:GetAttribute("OwnerId") == player.UserId
				and model:GetAttribute("State") == "Idle"
				and not (controllers.RoundController and controllers.RoundController.isBusy())
		end
	end
	st.refreshPrompt = refreshPrompt
	refreshPrompt()

	model:GetAttributeChangedSignal("State"):Connect(function()
		st.dirty = true
		local state = model:GetAttribute("State")
		refreshPrompt()
		if state == "Resetting" then
			st.resetFrom = st.lastDrop
			st.meltStart = nil
		elseif state == "Idle" then
			st.lastDrop = 0
		end
		if state ~= "Running" and st.chug then
			st.chug:Destroy()
			st.chug = nil
		end
	end)
	model:GetAttributeChangedSignal("Jewels"):Connect(function()
		st.dirty = true
		local jewels = model:GetAttribute("Jewels") or 0
		local state = model:GetAttribute("State")
		if state == "Resetting" or state == "Idle" then
			return -- the reset rebuilds the whole pile
		end
		if jewels < #st.loot then
			dropOff(st, #st.loot - jewels)
		elseif jewels > #st.loot then
			dropIn(st, jewels - #st.loot)
		end
	end)
	model:GetAttributeChangedSignal("LootSeed"):Connect(function()
		-- new plate of loot after a reset: pop it in once the plate is back up
		task.delay(Economy.ResetSeconds * 0.75, function()
			if states[model] then
				rebuildLoot(st)
				for _, item in st.loot do
					sparkle(item.part.Position, Color3.fromRGB(255, 236, 140), 3)
				end
				controllers.SoundController.play("Pop", st.pivot.Position + Vector3.new(0, PLATE_TOP_Y, 0), 0.5)
			end
		end)
	end)

	-- bounce into place when the plot was just claimed
	local spawnedAt = model:GetAttribute("SpawnedAt") or 0
	if now() - spawnedAt < 3 then
		local index = model:GetAttribute("SpawnIndex") or 1
		local parts = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and not d:IsDescendantOf(folder) and d.Transparency < 1 then
				table.insert(parts, d)
			end
		end
		table.sort(parts, function(a, b)
			return a.Position.Y < b.Position.Y
		end)
		st.loadingUntil = os.clock() + 2.6
		folder.Parent = nil -- chain + loot appear once the machine has landed
		for i, part in parts do
			local final = part.CFrame
			local finalT = part.Transparency
			part.CFrame = final + Vector3.new(0, 45, 0)
			part.Transparency = 1
			local delay = (index - 1) * 0.25 + (i / #parts) * 1.2
			task.delay(delay, function()
				if not part.Parent then
					return
				end
				part.Transparency = finalT
				TweenService:Create(part, TweenInfo.new(0.55, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { CFrame = final }):Play()
			end)
		end
		task.delay((index - 1) * 0.25 + 1.4, function()
			controllers.SoundController.play("Pop", st.pivot.Position, 0.6, 0.8 + index * 0.1)
			sparkle(st.pivot.Position + Vector3.new(0, 8, 0), def.themeColor, 25)
		end)
	end
end

local function teardown(model: Model)
	local st = states[model]
	if st then
		states[model] = nil
		if st.chug then
			st.chug:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- Frame update
---------------------------------------------------------------------------

local function progressOf(model: Model, t: number): number
	local base = model:GetAttribute("DropBase") or 0
	local start = model:GetAttribute("DropStart") or 0
	local rate = model:GetAttribute("DropRate") or 0
	local paused = model:GetAttribute("PausedUntil") or 0
	if t < paused then
		return base
	end
	return base + rate * math.max(0, t - math.max(start, paused))
end

local partsBuffer: { BasePart } = {}
local cframeBuffer: { CFrame } = {}

local function push(part: BasePart?, cf: CFrame)
	if part then
		table.insert(partsBuffer, part)
		table.insert(cframeBuffer, cf)
	end
end

local function updateMachine(st, t: number, clock: number)
	local model = st.model
	local state = model:GetAttribute("State")
	local drop: number
	if state == "Resetting" then
		local a = math.clamp((t - (model:GetAttribute("ResetAt") or t)) / (Economy.ResetSeconds * 0.7), 0, 1)
		a = 1 - (1 - a) ^ 3
		drop = st.resetFrom * (1 - a)
	elseif state == "Idle" then
		drop = 0
	else
		drop = math.clamp(progressOf(model, t), 0, 1) * DROP_DISTANCE
		if st.meltStart then
			drop += MELT_SINK * math.clamp((clock - st.meltStart) / 1.2, 0, 1)
		end
	end
	st.lastDrop = drop

	local moving = state == "Running" or state == "Resetting" or st.meltStart ~= nil
	local shaking = clock < st.shakeUntil
	if not moving and not shaking and not st.dirty and clock > st.moodUntil and #anims == 0 then
		-- idle machines only wiggle their gauge needles
		local wobble = math.sin(clock * 1.5 + st.phase) * 0.12
		if st.needleL then
			push(st.needleL, st.pivot * st.gaugeL * CFrame.Angles(0, 0, wobble) * st.gaugeL:Inverse() * st.base[st.needleL])
		end
		if st.needleR then
			push(st.needleR, st.pivot * st.gaugeR * CFrame.Angles(0, 0, -wobble) * st.gaugeR:Inverse() * st.base[st.needleR])
		end
		return
	end
	st.dirty = false

	local shake = CFrame.new()
	if shaking then
		local k = (st.shakeUntil - clock) / 0.7
		shake = CFrame.new(
			(math.noise(clock * 30, st.phase) * 0.8) * k,
			(math.noise(st.phase, clock * 30) * 0.3) * k,
			(math.noise(clock * 30, st.phase + 3) * 0.8) * k
		)
	end

	-- plate + loot
	local frame = plateFrame(st, drop) * shake
	for _, part in st.plateParts do
		push(part, frame * st.base[part])
	end
	for _, item in st.loot do
		local extra = st.dropInOffset and st.dropInOffset[item]
		if item.part.Parent then
			push(item.part, (if extra then frame * CFrame.new(0, extra, 0) else frame) * item.offset)
		end
	end

	-- chain links follow the path from the hook
	local hookY = HOOK_Y - drop
	for i, link in st.links do
		local s = (i - 0.5) * LINK_PITCH
		local pos, tangent = chainPoint(s, hookY)
		if pos then
			local right = if i % 2 == 1 then Vector3.xAxis:Cross(tangent).Unit else Vector3.xAxis
			local cf = CFrame.fromMatrix(pos, right, tangent)
			if i <= 3 then
				cf = shake * cf
			end
			link.Transparency = 0
			push(link, st.pivot * cf)
		else
			link.Transparency = 1
		end
	end

	-- spinning wheels (the chain feeds out as the plate drops)
	local turn = drop / PULLEY_R
	if st.pulleyA then
		push(st.pulleyA, st.pivot * st.base[st.pulleyA] * CFrame.Angles(-turn, 0, 0))
	end
	if st.pulleyB then
		push(st.pulleyB, st.pivot * st.base[st.pulleyB] * CFrame.Angles(-turn, 0, 0))
	end
	local engineShake = if shaking then shake else CFrame.new()
	if state == "Running" and t >= (model:GetAttribute("PausedUntil") or 0) then
		engineShake *= CFrame.new(0, math.sin(clock * 40) * 0.03, 0)
	end
	if st.drum then
		push(st.drum, st.pivot * engineShake * st.drumC * CFrame.Angles(drop / DRUM_R, 0, 0) * st.drumC:Inverse() * st.base[st.drum])
	end
	if st.gear then
		push(st.gear, st.pivot * engineShake * st.gearC * CFrame.Angles(drop * 0.55, 0, 0) * st.gearC:Inverse() * st.base[st.gear])
	end
	if st.gearSmall then
		push(st.gearSmall, st.pivot * engineShake * st.gearSmallC * CFrame.Angles(-drop * 1.13, 0, 0) * st.gearSmallC:Inverse() * st.base[st.gearSmall])
	end
	for _, part in st.engineParts do
		push(part, st.pivot * engineShake * st.base[part])
	end

	-- gauge "eyes"
	local mood = if clock < st.moodUntil then st.mood else (if state == "Running" then "work" else "idle")
	local angle
	if mood == "happy" then
		angle = 1.1 + math.sin(clock * 14) * 0.15
	elseif mood == "angry" then
		angle = clock * 14
	elseif mood == "work" then
		angle = math.sin(clock * 6 + st.phase) * 0.35
	else
		angle = math.sin(clock * 1.5 + st.phase) * 0.12
	end
	if st.needleL then
		push(st.needleL, st.pivot * engineShake * st.gaugeL * CFrame.Angles(0, 0, angle) * st.gaugeL:Inverse() * st.base[st.needleL])
	end
	if st.needleR then
		push(st.needleR, st.pivot * engineShake * st.gaugeR * CFrame.Angles(0, 0, -angle) * st.gaugeR:Inverse() * st.base[st.needleR])
	end
end

local function onFx(target: Instance, fx: string, payload)
	if typeof(target) ~= "Instance" then
		return
	end
	-- garden effects reuse this channel
	if fx == "Planted" or fx == "Dug" or fx == "Grown" then
		if target:IsA("Model") then
			local pos = target:GetPivot().Position
			if fx == "Grown" then
				local _, size = target:GetBoundingBox()
				sparkle(pos + Vector3.new(0, size.Y * 0.6, 0), Color3.fromRGB(255, 240, 120), 30)
				controllers.SoundController.play("LevelUp", pos, 0.35, 1.4)
			else
				smokePuff(pos + Vector3.new(0, 0.5, 0), Color3.fromRGB(140, 104, 70), 10)
				controllers.SoundController.play("Pop", pos, 0.5)
			end
		end
		return
	end
	local st = states[target :: Model]
	if not st then
		return
	end
	st.dirty = true
	local clock = os.clock()
	local enginePos = (st.pivot * st.gaugeL).Position
	local platePos = (st.pivot * CFrame.new(0, PLATE_TOP_Y - st.lastDrop, 0)).Position
	if fx == "Start" then
		local body = st.model:FindFirstChild("EngineBody")
		if body and not st.chug then
			st.chug = controllers.SoundController.loop("Chug", body, 0.35)
		end
	elseif fx == "Correct" then
		st.mood, st.moodUntil = "happy", clock + 1.2
		sparkle(platePos + Vector3.new(0, 1.5, 0), Color3.fromRGB(140, 255, 140), 18)
		controllers.SoundController.play("Correct", enginePos, 0.6)
	elseif fx == "Wrong" then
		st.mood, st.moodUntil = "angry", clock + 1.4
		st.shakeUntil = clock + 0.7
		local smoke = st.model:FindFirstChild("FxRoot")
		local burst = smoke and smoke:FindFirstChild("Burst", true)
		if burst then
			(burst :: ParticleEmitter):Emit(30)
		end
		controllers.SoundController.play("Grind", enginePos, 0.7)
		controllers.SoundController.play("Wrong", enginePos, 0.4)
	elseif fx == "Melt" then
		st.meltStart = clock
		for i, item in st.loot do
			dissolve(item, 0.35 + i * 0.04)
		end
		st.loot = {}
		local acidPos = (st.pivot * CFrame.new(0, ACID_Y + 0.5, 0)).Position
		smokePuff(acidPos, Color3.fromRGB(150, 255, 90), 30)
		controllers.SoundController.play("Splash", acidPos, 0.8)
		controllers.SoundController.play("Sizzle", acidPos, 0.7)
	elseif fx == "Win" then
		local winner = Players:GetPlayerByUserId(payload.userId or 0)
		local function targetPos(): Vector3?
			local character = winner and winner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			return root and root.Position
		end
		local isMe = winner == player
		for i, item in st.loot do
			flyLoot(item, targetPos, 0.75, 0.25 + i * 0.06, function()
				if isMe then
					controllers.SoundController.play("Coins", nil, 0.35, 0.9 + math.random() * 0.3)
				end
			end)
		end
		st.loot = {}
		sparkle(platePos + Vector3.new(0, 2, 0), Color3.fromRGB(255, 220, 90), 40)
		controllers.SoundController.play("Cash", platePos, 0.8)
	end
end

--- A big model can arrive in pieces: setting up before the Plate, PromptAnchor or
--- Markers exist would leave the plate frozen (and the prompt never hidden), so
--- wait until everything the server built is here.
local function setupWhenReplicated(model: Model)
	local expected = model:GetAttribute("DescendantCount") or 0
	local started = os.clock()
	while model.Parent and #model:GetDescendants() < expected and os.clock() - started < 15 do
		task.wait(0.1)
	end
	if model.Parent then
		setupMachine(model)
	end
end

function MachineRenderer:Start(all)
	controllers = all
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
		task.spawn(setupWhenReplicated, model)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(teardown)
	for _, model in CollectionService:GetTagged(TAG) do
		task.spawn(setupWhenReplicated, model)
	end
	Remotes.MachineFx.OnClientEvent:Connect(onFx)

	RunService.RenderStepped:Connect(function()
		local t = now()
		local clock = os.clock()
		local camPos = workspace.CurrentCamera.CFrame.Position
		table.clear(partsBuffer)
		table.clear(cframeBuffer)
		for i = #anims, 1, -1 do
			local ok, finished = pcall(anims[i].update, clock)
			if not ok or finished then
				table.remove(anims, i)
			end
		end
		for model, st in states do
			if not model.Parent then
				teardown(model)
				continue
			end
			if st.loadingUntil then
				if clock < st.loadingUntil then
					continue
				end
				st.loadingUntil = nil
				st.folder.Parent = model
				st.dirty = true
			end
			if (st.pivot.Position - camPos).Magnitude > UPDATE_RANGE then
				continue
			end
			updateMachine(st, t, clock)
		end
		if #partsBuffer > 0 then
			workspace:BulkMoveTo(partsBuffer, cframeBuffer, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

--- Refresh prompt visibility on all machines (e.g. when a round UI opens/closes).
function MachineRenderer.refreshPrompts()
	for _, st in states do
		if st.refreshPrompt then
			st.refreshPrompt()
		end
	end
end

function MachineRenderer.getCameraShot(model: Model): (CFrame?, Vector3?)
	local st = states[model]
	local pivot = if st then st.pivot else model:GetPivot()
	local eye = (pivot * markerCF(model, "CameraEye")).Position
	local focus = (pivot * markerCF(model, "CameraFocus")).Position
	return CFrame.lookAt(eye, focus), focus
end

return MachineRenderer
