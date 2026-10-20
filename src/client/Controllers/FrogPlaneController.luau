--[[
	Everything you see of the Frog Plane event:
	  * the "✈️ 4:12" countdown next to the money counter, and a heads-up toast
	  * Ribbit's plane crossing the sky, propellers spinning and wings rocking
	  * safes floating down on parachutes, landing with a thump, then a pulsing
	    beacon and a "🐸 SAFE!" marker you can spot from anywhere on the island
	  * the door swinging open (and loot + confetti bursting out) when someone
	    cracks one
	The server decides all the timings (FrogPlaneService); this only animates.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Theme = require(script.Parent.Parent.UI.Theme)

local FrogPlaneController = {}
local controllers
local C = Theme.Colors

local BEACON_COLOR = Color3.fromRGB(150, 255, 110)

type Flight = {
	model: Model,
	start: number,
	duration: number,
	from: Vector3,
	to: Vector3,
	heading: Vector3,
	props: { { part: BasePart, rel: CFrame, hub: CFrame } },
}

type Tracked = {
	model: Model,
	home: CFrame,
	phase: number,
	landed: boolean,
	chute: Model?,
	chuteOffset: CFrame,
	beam: BasePart?,
	ring: BasePart?,
	label: TextLabel?,
	billboard: BillboardGui?,
}

local flights: { Flight } = {}
local tracked: { [Model]: Tracked } = {}
local sky: Folder
local chip: Frame
local chipLabel: TextLabel

local function now(): number
	return workspace:GetServerTimeNow()
end

local function asset(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("FrogPlane")
	local found = folder and folder:FindFirstChild(name)
	return if found then found:Clone() :: Model else nil
end

local function markerCF(model: Model, name: string): CFrame?
	local markers = model:FindFirstChild("Markers")
	local value = markers and markers:FindFirstChild(name)
	return if value and value:IsA("CFrameValue") then value.Value else nil
end

local function ghostly(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

---------------------------------------------------------------------------
-- The plane
---------------------------------------------------------------------------

local function placeholderPlane(): Model
	local model = Instance.new("Model")
	local body = Instance.new("Part")
	body.Size = Vector3.new(10, 9, 30)
	body.Color = Color3.fromRGB(108, 200, 84)
	body.Parent = model
	local wing = Instance.new("Part")
	wing.Size = Vector3.new(48, 1, 7)
	wing.Color = Color3.fromRGB(246, 236, 200)
	wing.Parent = model
	model.WorldPivot = CFrame.new()
	return model
end

local function startFlight(payload)
	local model = asset("FrogPlane") or placeholderPlane()
	model.Name = "FrogPlane"
	ghostly(model)
	local pivot = model:GetPivot()
	local props = {}
	for _, name in { "PropLeft", "PropRight" } do
		local part = model:FindFirstChild(name, true)
		local axis = markerCF(model, name .. "Axis")
		if part and part:IsA("BasePart") and axis then
			table.insert(props, { part = part, rel = pivot:ToObjectSpace(part.CFrame), hub = CFrame.new(axis.Position) })
		end
	end
	local flight: Flight = {
		model = model,
		start = payload.start,
		duration = payload.duration,
		from = payload.from,
		to = payload.to,
		heading = (payload.to - payload.from).Unit,
		props = props,
	}
	model:PivotTo(CFrame.lookAt(flight.from, flight.from + flight.heading))
	model.Parent = sky
	local body = model:FindFirstChild("Fuselage", true) or model:FindFirstChildWhichIsA("BasePart")
	if body then
		local hum = controllers.SoundController.loop("PlaneEngine", body, 0.7)
		if hum then
			hum.RollOffMaxDistance = 600
			hum.RollOffMinDistance = 60
		end
	end
	table.insert(flights, flight)
end

local function updateFlights(t: number)
	for i = #flights, 1, -1 do
		local f = flights[i]
		local a = (t - f.start) / f.duration
		if a > 1.02 then
			f.model:Destroy()
			table.remove(flights, i)
			continue
		end
		local pos = f.from:Lerp(f.to, math.clamp(a, 0, 1)) + Vector3.new(0, math.sin(t * 1.3) * 1.5, 0)
		local cf = CFrame.lookAt(pos, pos + f.heading) * CFrame.Angles(0, 0, math.sin(t * 0.9) * math.rad(5))
		f.model:PivotTo(cf)
		local spin = CFrame.Angles(0, 0, t * 25)
		for _, prop in f.props do
			prop.part.CFrame = cf * prop.hub * spin * prop.hub:Inverse() * prop.rel
		end
	end
end

---------------------------------------------------------------------------
-- Safes: falling, landing, beacons
---------------------------------------------------------------------------

local function body(model: Model): BasePart?
	local part = model:FindFirstChild("Body")
	return if part and part:IsA("BasePart") then part else model:FindFirstChildWhichIsA("BasePart")
end

local function refreshMarker(st: Tracked)
	local stateName = st.model:GetAttribute("State")
	local open = stateName == "Open"
	if st.beam and open then
		st.beam.Transparency = 1
	end
	if st.billboard and st.label then
		st.billboard.Enabled = st.landed and not open
		if stateName == "Cracking" then
			st.label.Text = "🔒 " .. tostring(st.model:GetAttribute("Cracker") or "")
		else
			st.label.Text = "🐸 SAFE!"
		end
	end
end

local function startBeacon(st: Tracked)
	local pos = st.home.Position
	local beam = Instance.new("Part")
	beam.Name = "Beacon"
	beam.Shape = Enum.PartType.Cylinder
	beam.Material = Enum.Material.Neon
	beam.Color = BEACON_COLOR
	beam.Transparency = 0.55
	beam.Size = Vector3.new(170, 2.4, 2.4)
	beam.CFrame = CFrame.new(pos + Vector3.new(0, 90, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch, beam.CastShadow = true, false, false, false, false
	beam.Parent = sky
	local ring = beam:Clone()
	ring.Name = "BeaconRing"
	ring.Size = Vector3.new(0.2, 4, 4)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = sky
	st.beam, st.ring = beam, ring

	local part = body(st.model)
	if part then
		local billboard = Theme.new("BillboardGui", {
			Name = "SafeMarker",
			Size = UDim2.fromOffset(150, 46),
			StudsOffsetWorldSpace = Vector3.new(0, 8.5, 0),
			AlwaysOnTop = true,
			MaxDistance = 1200,
			LightInfluence = 0,
			Adornee = part,
			Parent = part,
		})
		local pill = Theme.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.Yellow,
			Parent = billboard,
			[Theme.Children] = { Theme.round(), Theme.stroke(C.Ink, 3) },
		})
		st.label = Theme.text({
			Size = UDim2.new(1, -16, 0.78, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = "🐸 SAFE!",
			Parent = pill,
		})
		st.billboard = billboard
	end
	refreshMarker(st)
end

local function land(st: Tracked)
	st.landed = true
	st.model:PivotTo(st.home)
	if st.chute then
		st.chute:Destroy()
		st.chute = nil
	end
	local pos = st.home.Position
	controllers.MachineRenderer.smokePuff(pos + Vector3.new(0, 0.5, 0), Color3.fromRGB(196, 170, 130), 14)
	controllers.SoundController.play("SafeLand", pos, 0.8)
	startBeacon(st)
end

local function untrack(model: Model)
	local st = tracked[model]
	if not st then
		return
	end
	tracked[model] = nil
	for _, thing in { st.chute, st.beam, st.ring } do
		if thing then
			thing:Destroy()
		end
	end
end

local function track(model: Model)
	if tracked[model] or not model:IsA("Model") then
		return
	end
	local st: Tracked = {
		model = model,
		home = model:GetPivot(),
		phase = math.random() * 10,
		landed = false,
		chute = nil,
		chuteOffset = markerCF(model, "Top") or CFrame.new(0, 4.7, 0),
		beam = nil,
		ring = nil,
		label = nil,
		billboard = nil,
	}
	tracked[model] = st
	model:GetAttributeChangedSignal("State"):Connect(function()
		refreshMarker(st)
	end)
	model:GetAttributeChangedSignal("Cracker"):Connect(function()
		refreshMarker(st)
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			untrack(model)
		end
	end)
	if (model:GetAttribute("LandAt") or 0) > now() then
		local chute = asset("Parachute")
		if chute then
			ghostly(chute)
			chute.Parent = sky
			st.chute = chute
		end
	else
		st.landed = true
		startBeacon(st)
	end
end

local function updateSafes(t: number)
	for _, st in tracked do
		local model = st.model
		if not st.landed then
			local dropAt = model:GetAttribute("DropAt") or t
			local landAt = model:GetAttribute("LandAt") or t
			local from = model:GetAttribute("DropFrom") or st.home.Position
			if t >= landAt then
				land(st)
			else
				local a = math.clamp((t - dropAt) / math.max(landAt - dropAt, 0.1), 0, 1)
				local home = st.home.Position
				-- drifts over quickly at first, then floats straight down
				local drift = 1 - (1 - a) ^ 2
				local x = from.X + (home.X - from.X) * drift
				local z = from.Z + (home.Z - from.Z) * drift
				local y = from.Y + (home.Y - from.Y) * a
				local sway = math.rad(math.sin(t * 2.2 + st.phase) * 6) * (1 - a * 0.7)
				local cf = CFrame.new(x, y, z) * st.home.Rotation * CFrame.Angles(sway, t * 0.4, sway * 0.6)
				model:PivotTo(cf)
				if st.chute then
					st.chute:PivotTo(cf * st.chuteOffset)
				end
			end
		elseif st.beam and st.ring and model:GetAttribute("State") ~= "Open" then
			st.beam.Transparency = 0.5 + math.sin(t * 4 + st.phase) * 0.18
			local grow = (t * 0.6 + st.phase) % 1
			st.ring.Size = Vector3.new(0.2, 4 + grow * 16, 4 + grow * 16)
			st.ring.Transparency = 0.25 + grow * 0.75
		elseif st.ring then
			st.ring.Transparency = 1
		end
	end
end

---------------------------------------------------------------------------
-- Opening (and vanishing)
---------------------------------------------------------------------------

local swingOwner: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any
local swings = 0

--- Turn parts of a safe together around a marker axis over ``seconds`` (client
--- only). A newer swing of the same part takes over from an older one.
local function swing(model: Model, partNames: { string }, markerName: string, rotation: (number) -> CFrame, seconds: number)
	local marker = markerCF(model, markerName)
	local st = tracked[model]
	if not marker then
		return
	end
	local axis = (if st then st.home else model:GetPivot()) * CFrame.new(marker.Position)
	swings += 1
	local id = swings
	local moving = {}
	for _, name in partNames do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			swingOwner[part] = id
			table.insert(moving, { part = part, rel = axis:ToObjectSpace(part.CFrame) })
		end
	end
	local begin = os.clock()
	task.spawn(function()
		while model.Parent do
			local a = math.min(1, (os.clock() - begin) / seconds)
			local turn = axis * rotation(a)
			for _, m in moving do
				if swingOwner[m.part] == id then
					m.part.CFrame = turn * m.rel
				end
			end
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

--- Spin the combination dial (a number was found).
function FrogPlaneController.spinDial(model: Model?)
	if not model then
		return
	end
	local turns = math.random(2, 4) * math.pi / 2
	swing(model, { "Dial" }, "DialAxis", function(a)
		return CFrame.Angles(0, 0, turns * (1 - (1 - a) ^ 3))
	end, 0.6)
	controllers.SoundController.play("Tick", model:GetPivot().Position, 0.6)
end

--- Golden treasure shining out of an open safe (sits just behind the door).
local function treasureGlow(model: Model, home: CFrame)
	local glow = Instance.new("Part")
	glow.Name = "TreasureGlow"
	glow.Size = Vector3.new(3.7, 3.6, 0.06)
	glow.CFrame = home * CFrame.new(0, 2.3, -2.6)
	glow.Material = Enum.Material.Neon
	glow.Color = Color3.fromRGB(255, 204, 72)
	glow.Anchored, glow.CanCollide, glow.CanQuery, glow.CanTouch, glow.CastShadow = true, false, false, false, false
	local light = Instance.new("PointLight")
	light.Color = glow.Color
	light.Brightness = 1.5
	light.Range = 12
	light.Parent = glow
	glow.Parent = model
end

local function burstLoot(origin: Vector3, forward: Vector3)
	local valuables = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Valuables")
	if not valuables then
		return
	end
	local kinds = valuables:GetChildren()
	for _ = 1, 16 do
		local source = kinds[math.random(1, #kinds)]
		local piece = source:Clone()
		if piece:IsA("Model") then
			ghostly(piece)
			piece:ScaleTo(1.4)
			piece:PivotTo(CFrame.new(origin))
			piece.Parent = sky
			local velocity = (forward * math.random(10, 22) + Vector3.new(math.random(-9, 9), math.random(22, 34), math.random(-9, 9)))
			local spin = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
			local born = os.clock()
			task.spawn(function()
				local pos = origin
				local rot = CFrame.new()
				while piece.Parent do
					local dt = RunService.RenderStepped:Wait()
					local age = os.clock() - born
					velocity += Vector3.new(0, -60, 0) * dt
					pos += velocity * dt
					rot *= CFrame.Angles(spin.X * dt, spin.Y * dt, spin.Z * dt)
					piece:PivotTo(CFrame.new(pos) * rot)
					if age > 1.4 then
						piece:Destroy()
					end
				end
			end)
		else
			piece:Destroy()
		end
	end
end

local function onFx(target: Instance, fx: string, _payload)
	if typeof(target) ~= "Instance" or not target:IsA("Model") or target.Name ~= "FrogSafe" then
		return
	end
	local st = tracked[target]
	local home = if st then st.home else target:GetPivot()
	if fx == "SafeOpen" then
		treasureGlow(target, home)
		swing(target, { "Door", "Dial" }, "Hinge", function(a)
			return CFrame.Angles(0, -math.rad(115) * (1 - (1 - a) ^ 3), 0)
		end, 0.7)
		local front = home.Position + home.LookVector * 3 + Vector3.new(0, 2.5, 0)
		burstLoot(front, home.LookVector)
		controllers.EffectsController.confettiBurst(front, (home.LookVector + Vector3.new(0, 1.6, 0)).Unit, 70)
		controllers.SoundController.play("SafeOpen", front, 0.9)
		controllers.SoundController.play("Coins", front, 0.6)
	elseif fx == "SafeGone" then
		controllers.MachineRenderer.smokePuff(home.Position + Vector3.new(0, 2.5, 0), Color3.fromRGB(255, 255, 255), 18)
		controllers.SoundController.play("Pop", home.Position, 0.6)
		if st then
			for _, thing in { st.beam, st.ring } do
				if thing then
					thing.Transparency = 1
				end
			end
			if st.billboard then
				st.billboard.Enabled = false
			end
		end
	end
end

---------------------------------------------------------------------------
-- Countdown chip + heads-up
---------------------------------------------------------------------------

local function buildChip()
	local gui = Theme.screen("FrogPlane", 5)
	chip = Theme.new("Frame", {
		Name = "Countdown",
		Size = UDim2.fromOffset(150, 46),
		Position = UDim2.new(0.5, 150, 0, 24),
		BackgroundColor3 = C.Paper,
		Parent = gui,
		[Theme.Children] = { Theme.round(), Theme.stroke(C.Ink, 3) },
	})
	chipLabel = Theme.text({
		Size = UDim2.new(1, -18, 0.72, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = "✈️ --:--",
		TextColor3 = C.GreenDark,
		Parent = chip,
	})
end

local function updateChip(t: number)
	for _, f in flights do
		if t >= f.start - 2 and t <= f.start + f.duration then
			chipLabel.Text = "✈️ NOW!"
			chipLabel.TextColor3 = C.RedDark
			return
		end
	end
	local nextAt = workspace:GetAttribute("NextFrogPlane")
	if typeof(nextAt) ~= "number" then
		chip.Visible = false
		return
	end
	chip.Visible = true
	local left = math.max(0, nextAt - t)
	chipLabel.Text = "✈️ " .. string.format("%d:%02d", left // 60, math.floor(left % 60))
	chipLabel.TextColor3 = if left <= 30 then C.Orange else C.GreenDark
end

function FrogPlaneController:Start(all)
	controllers = all
	sky = Instance.new("Folder")
	sky.Name = "MM_FrogSky"
	sky.Parent = workspace
	buildChip()

	Remotes.FrogPlane.OnClientEvent:Connect(function(event: string, payload)
		if event == "Soon" then
			controllers.NotifyController.show("🐸✈️ The Frog Plane is coming! Watch the sky for falling safes!", "money", 6)
			controllers.SoundController.play("Whoosh", nil, 0.6)
		elseif event == "Flight" then
			startFlight(payload)
		end
	end)
	Remotes.MachineFx.OnClientEvent:Connect(onFx)

	task.spawn(function()
		local drops = workspace:WaitForChild("FrogDrops")
		for _, child in drops:GetChildren() do
			track(child :: Model)
		end
		drops.ChildAdded:Connect(function(child)
			track(child :: Model)
		end)
	end)

	local lastChip = 0
	RunService.RenderStepped:Connect(function()
		local t = now()
		updateFlights(t)
		updateSafes(t)
		if os.clock() - lastChip > 0.2 then
			lastChip = os.clock()
			updateChip(t)
		end
	end)
end

return FrogPlaneController
