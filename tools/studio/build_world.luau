--[[
	Builds Workspace.World (and the island terrain) for Math Money in Studio.

	Run through the dev server from the MCP / command bar:
	    local Build = loadstring(game:GetService("HttpService"):GetAsync(
	        "http://127.0.0.1:8765/tools/studio/build_world.luau"))()
	    Build.run({ terrain = true })

	Layout (studs): a grassy island with a long plaza running along X. Four plots
	face it from the north (z = +90) and four from the south (z = -90). Plot space:
	origin at the plot center, local -Z faces the plaza (the gate), machines sit
	in a row near the back, two soil beds fill the front.
	Decorative meshes come from ServerStorage.WorldProps when they exist (see
	tools/pipeline); otherwise simple parts stand in.
]]

local ServerStorage = game:GetService("ServerStorage")

local Build = {}

local PLOT_W, PLOT_D = 100, 112
local PLOT_X = { -168, -56, 56, 168 }
local PLOT_Z = 90
local MACHINE_Z = 30
local MACHINE_X = { Addition = 36, Subtraction = 12, Multiplication = -12, Division = -36 }

local WOOD = Color3.fromRGB(150, 104, 64)
local WOOD_DARK = Color3.fromRGB(110, 76, 46)
local SOIL = Color3.fromRGB(104, 72, 48)

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function propFolder(): Instance?
	local prefabs = ServerStorage:FindFirstChild("Prefabs")
	return ServerStorage:FindFirstChild("WorldProps") or (prefabs and prefabs:FindFirstChild("WorldProps"))
end

local function prop(name: string): Model?
	local folder = propFolder()
	local found = folder and folder:FindFirstChild(name)
	return if found then found:Clone() :: Model else nil
end

local function asset(group: string, name: string): Model?
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(group)
	local found = folder and folder:FindFirstChild(name)
	return if found then found:Clone() :: Model else nil
end

--- Glowing lamp post (mesh prop when available).
local function lampAt(parent: Instance, cf: CFrame)
	local lamp = prop("Lamp")
	if lamp then
		lamp:PivotTo(cf)
		local bulb = lamp:FindFirstChild("Bulb", true)
		if bulb then
			local light = Instance.new("PointLight")
			light.Range = 20
			light.Brightness = 1.1
			light.Color = Color3.fromRGB(255, 220, 160)
			light.Parent = bulb
		end
		lamp.Parent = parent
		return
	end
	part({
		Name = "LampPost",
		Size = Vector3.new(0.6, 9, 0.6),
		CFrame = cf * CFrame.new(0, 4.5, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(60, 60, 66),
		Parent = parent,
	})
	local bulb = part({
		Name = "Lamp",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.6, 1.6, 1.6),
		CFrame = cf * CFrame.new(0, 9.4, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 226, 150),
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 220, 160)
	light.Parent = bulb
end

local function board(parent: Instance, cf: CFrame, size: Vector3, title: string, subtitle: string, color: Color3, name: string?)
	local b = part({
		Name = name or "Board",
		Size = size,
		CFrame = cf,
		Material = Enum.Material.Wood,
		Color = color,
		Parent = parent,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.4
		gui.Parent = b
		local t = Instance.new("TextLabel")
		t.Name = "Title"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.92, 0.56)
		t.Position = UDim2.fromScale(0.04, 0.06)
		t.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(255, 255, 255)
		t.Text = title
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(46, 36, 72)
		stroke.Parent = t
		t.Parent = gui
		local s = t:Clone()
		s.Name = "Subtitle"
		s.Size = UDim2.fromScale(0.92, 0.3)
		s.Position = UDim2.fromScale(0.04, 0.64)
		s.Text = subtitle
		s.Parent = gui
	end
	return b
end

local function fenceLine(parent: Instance, a: Vector3, b: Vector3, cf: CFrame)
	-- a picket fence from a to b (plot space)
	local dir = b - a
	local length = dir.Magnitude
	local unit = dir.Unit
	local look = CFrame.lookAt(Vector3.zero, unit)
	local section = prop("FenceSection")
	if section then
		local _, size = section:GetBoundingBox()
		local count = math.max(1, math.floor(length / size.Z + 0.5))
		local step = length / count
		for i = 0, count - 1 do
			local s = if i == 0 then section else section:Clone()
			local mid = a + unit * (step * (i + 0.5))
			s:PivotTo(cf * CFrame.new(mid) * look)
			s.Parent = parent
		end
		return
	end
	local mid = (a + b) / 2
	for _, y in { 1.2, 2.6 } do
		part({
			Name = "Rail",
			Size = Vector3.new(0.35, 0.45, length),
			CFrame = cf * CFrame.new(mid + Vector3.new(0, y, 0)) * look,
			Material = Enum.Material.Wood,
			Color = WOOD,
			Parent = parent,
		})
	end
	local posts = math.max(1, math.floor(length / 8))
	for i = 0, posts do
		local p = a + unit * (length * i / posts)
		part({
			Name = "Post",
			Size = Vector3.new(0.7, 3.6, 0.7),
			CFrame = cf * CFrame.new(p + Vector3.new(0, 1.8, 0)),
			Material = Enum.Material.Wood,
			Color = WOOD_DARK,
			Parent = parent,
		})
	end
end

local function buildPlot(index: number, origin: CFrame, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model:SetAttribute("Index", index)

	part({
		Name = "Origin",
		Size = Vector3.new(2, 0.2, 2),
		CFrame = origin,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})

	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = model
	for kind, x in MACHINE_X do
		part({
			Name = kind,
			Size = Vector3.new(4, 0.2, 4),
			CFrame = origin * CFrame.new(x, 0, MACHINE_Z),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = slots,
		})
	end

	-- garden beds with log borders
	local beds = Instance.new("Folder")
	beds.Name = "Beds"
	beds.Parent = model
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	for side, x in { Left = 25, Right = -25 } do
		local bedCF = origin * CFrame.new(x, 0.6, -20)
		part({
			Name = "Bed" .. side,
			Size = Vector3.new(38, 1.2, 52),
			CFrame = bedCF,
			Material = Enum.Material.Ground,
			Color = SOIL,
			Parent = beds,
		})
		for _, edge in {
			{ Vector3.new(0, 0.2, 26.6), Vector3.new(39.6, 1.8, 1.2) },
			{ Vector3.new(0, 0.2, -26.6), Vector3.new(39.6, 1.8, 1.2) },
			{ Vector3.new(19.6, 0.2, 0), Vector3.new(1.2, 1.8, 52) },
			{ Vector3.new(-19.6, 0.2, 0), Vector3.new(1.2, 1.8, 52) },
		} do
			part({
				Name = "Border",
				Size = edge[2],
				CFrame = bedCF * CFrame.new(edge[1]),
				Material = Enum.Material.Wood,
				Color = WOOD_DARK,
				Parent = decor,
			})
		end
	end

	-- fence with a gap for the gate
	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = model
	local hw, hd = PLOT_W / 2, PLOT_D / 2
	fenceLine(fence, Vector3.new(-hw, 0, -hd), Vector3.new(-9, 0, -hd), origin)
	fenceLine(fence, Vector3.new(9, 0, -hd), Vector3.new(hw, 0, -hd), origin)
	fenceLine(fence, Vector3.new(hw, 0, -hd), Vector3.new(hw, 0, hd), origin)
	fenceLine(fence, Vector3.new(hw, 0, hd), Vector3.new(-hw, 0, hd), origin)
	fenceLine(fence, Vector3.new(-hw, 0, hd), Vector3.new(-hw, 0, -hd), origin)

	-- gate arch with the owner's name
	local gate = prop("GateArch") or Instance.new("Model")
	gate.Name = "Gate"
	if #gate:GetChildren() == 0 then
		for _, x in { -8.5, 8.5 } do
			part({
				Name = "Pillar",
				Size = Vector3.new(1.6, 13, 1.6),
				CFrame = origin * CFrame.new(x, 6.5, -hd),
				Material = Enum.Material.Wood,
				Color = WOOD_DARK,
				Parent = gate,
			})
		end
		part({
			Name = "Beam",
			Size = Vector3.new(19.5, 1.4, 1.8),
			CFrame = origin * CFrame.new(0, 13, -hd),
			Material = Enum.Material.Wood,
			Color = WOOD,
			Parent = gate,
		})
	else
		gate:PivotTo(origin * CFrame.new(0, 0, -hd))
	end
	board(gate, origin * CFrame.new(0, 10.75, -hd - 1.05) * CFrame.Angles(0, math.pi, 0), Vector3.new(15, 3.6, 0.4),
		"Plot " .. index, "Free!", Color3.fromRGB(96, 170, 90), "NameBoard")
	gate.Parent = model

	-- the claim sign out on the plaza
	local sign = Instance.new("Model")
	sign.Name = "ClaimSign"
	local signCF = origin * CFrame.new(-17, 0, -hd - 5) * CFrame.Angles(0, math.pi, 0)
	for _, x in { -3.6, 3.6 } do
		part({
			Name = "Leg",
			Size = Vector3.new(0.7, 7, 0.7),
			CFrame = signCF * CFrame.new(x, 3.5, 0),
			Material = Enum.Material.Wood,
			Color = WOOD_DARK,
			Parent = sign,
		})
	end
	local claimBoard = board(sign, signCF * CFrame.new(0, 5.2, 0), Vector3.new(9, 4.4, 0.4), "FREE PLOT!",
		"Press E to make it yours", Color3.fromRGB(236, 170, 60), "Board")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ClaimPrompt"
	prompt.ActionText = "Claim Plot"
	prompt.ObjectText = "Plot " .. index
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = claimBoard
	sign.Parent = model

	part({
		Name = "Spawn",
		Size = Vector3.new(4, 0.2, 4),
		CFrame = origin * CFrame.new(0, 0.2, -hd + 8) * CFrame.Angles(0, math.pi, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})

	-- lamp posts at the gate
	for _, x in { -12, 12 } do
		lampAt(decor, origin * CFrame.new(x, 0, -hd - 2) * CFrame.Angles(0, math.pi, 0))
	end

	model.WorldPivot = origin
	model.Parent = parent
	return model
end

local function buildTerrain()
	-- the island lives in game code so a fresh server can grow it too
	local server = game:GetService("ServerScriptService"):WaitForChild("Server")
	require(server:WaitForChild("IslandTerrain")).build()
end

local function groundY(): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(-120, 100, 40), Vector3.new(0, -200, 0), params)
	return if hit then math.floor(hit.Position.Y * 100 + 0.5) / 100 else 0
end

local function buildPlaza(world: Instance, g: number)
	local plaza = Instance.new("Model")
	plaza.Name = "Plaza"

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(-36, 0.1, 0) * CFrame.Angles(0, -math.pi / 2, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Material = Enum.Material.Cobblestone
	spawn.Color = Color3.fromRGB(255, 214, 90)
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = plaza

	-- the shop (Ribbit's Emporium) faces -X, toward the spawn
	local shop = Instance.new("Model")
	shop.Name = "Shop"
	local stallCF = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
	local stall = prop("ShopStall")
	if stall then
		stall:PivotTo(stallCF)
		stall.Parent = shop
		local markers = stall:FindFirstChild("Markers")
		local signMarker = markers and markers:FindFirstChild("Sign")
		if signMarker then
			board(shop, stallCF * signMarker.Value * CFrame.new(0, 0, -0.05), Vector3.new(6.6, 2.0, 0.1), "SHOP",
				"Ribbit's Emporium", Color3.fromRGB(200, 150, 98), "ShopSign")
		end
	else
		part({ Name = "Counter", Size = Vector3.new(16, 4, 3), CFrame = stallCF * CFrame.new(0, 2, -1.8), Material = Enum.Material.Wood, Color = WOOD, Parent = shop })
		for _, x in { -7.6, 7.6 } do
			for _, z in { -1.6, 3.6 } do
				part({ Name = "Post", Size = Vector3.new(0.8, 12, 0.8), CFrame = stallCF * CFrame.new(x, 6, z), Material = Enum.Material.Wood, Color = WOOD_DARK, Parent = shop })
			end
		end
		board(shop, stallCF * CFrame.new(0, 13.5, -1.8), Vector3.new(12, 3.5, 0.5), "SHOP", "Ribbit's Emporium",
			Color3.fromRGB(240, 120, 60), "ShopSign")
	end
	local frog = prop("Frog")
	if frog then
		frog:PivotTo(stallCF * CFrame.new(0, 1.0, 1.1)) -- standing on a stool behind the counter
		frog.Name = "Merchant"
		frog.Parent = shop
	end
	part({
		Name = "ShopPrompt",
		Size = Vector3.new(1, 1, 1),
		CFrame = stallCF * CFrame.new(0, 3, -4.2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = shop,
	})
	part({
		Name = "ShopSpot",
		Size = Vector3.new(2, 0.2, 2),
		CFrame = stallCF * CFrame.new(0, 0.2, -12) * CFrame.Angles(0, math.pi, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = shop,
	})
	shop.Parent = plaza

	-- welcome sign by the spawn
	local welcome = Instance.new("Model")
	welcome.Name = "WelcomeSign"
	for _, z in { -6, 6 } do
		part({ Name = "Leg", Size = Vector3.new(0.8, 10, 0.8), CFrame = CFrame.new(-52, 5, z), Material = Enum.Material.Wood, Color = WOOD_DARK, Parent = welcome })
	end
	board(welcome, CFrame.new(-52, 8, 0) * CFrame.Angles(0, -math.pi / 2, 0), Vector3.new(13, 5, 0.5), "MATH MONEY",
		"Solve math • Save the loot • Grow a garden!", Color3.fromRGB(90, 150, 230), "Board")
	welcome.Parent = plaza

	-- flowers by the welcome sign
	for i, spot in { Vector3.new(-50, 0, -10), Vector3.new(-54, 0, 9), Vector3.new(-46, 0, 12), Vector3.new(-45, 0, -13) } do
		local f = asset("Plants", if i % 2 == 0 then "Tulip" else "Daisy")
		if f then
			f:PivotTo(CFrame.new(spot) * CFrame.Angles(0, i * 1.7, 0))
			f.Parent = plaza
		end
	end

	plaza:PivotTo(plaza:GetPivot() + Vector3.new(0, g, 0))
	plaza.Parent = world
end

--- Trees, rocks, bushes and avenue lamps around the island.
local function buildScenery(world: Instance, g: number)
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	local rng = Random.new(7)
	local function place(model: Model?, pos: Vector3, scale: number)
		if not model then
			return
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanTouch = false
			end
		end
		model:PivotTo(CFrame.new(pos + Vector3.new(0, g, 0)) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0))
		if math.abs(scale - 1) > 0.01 then
			model:ScaleTo(scale)
		end
		model.Parent = scenery
	end
	local function ringSpot(): Vector3
		while true do
			local x = rng:NextNumber(-282, 282)
			local z = rng:NextNumber(-205, 205)
			if math.abs(x) > 226 or math.abs(z) > 154 then
				return Vector3.new(x, 0, z)
			end
		end
	end
	local trees = { "PineTree", "PineTree", "OakTree", "OakTree", "CherryTree" }
	for _ = 1, 44 do
		place(asset("Plants", trees[rng:NextInteger(1, #trees)]), ringSpot(), rng:NextNumber(0.85, 1.35))
	end
	for _ = 1, 26 do
		place(prop("Rock" .. rng:NextInteger(1, 3)), ringSpot(), rng:NextNumber(0.7, 1.6))
		place(prop("Bush"), ringSpot(), rng:NextNumber(0.8, 1.3))
	end
	-- bushes in the gaps between plots, lamps along the avenue
	for _, x in { -112, 0, 112 } do
		for _, side in { 1, -1 } do
			for k = 0, 2 do
				place(prop("Bush"), Vector3.new(x + rng:NextNumber(-2, 2), 0, side * (48 + k * 40)), rng:NextNumber(0.8, 1.1))
			end
		end
	end
	for x = -200, 200, 40 do
		if math.abs(x) > 30 then
			for _, side in { 1, -1 } do
				lampAt(scenery, CFrame.new(x, g, side * 15) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0))
			end
		end
	end
	scenery.Parent = world
end

--- Rebuild World (and optionally the terrain). Returns a short report.
function Build.run(options: { terrain: boolean? }?)
	options = options or {}
	local old = workspace:FindFirstChild("World")
	if old then
		old:Destroy()
	end
	for _, name in { "Baseplate", "SpawnLocation" } do
		local d = workspace:FindFirstChild(name)
		if d then
			d:Destroy()
		end
	end
	if options.terrain then
		buildTerrain()
	end
	local g = groundY()
	local world = Instance.new("Folder")
	world.Name = "World"
	world:SetAttribute("GroundY", g)
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = world
	local index = 0
	for _, side in { 1, -1 } do
		for _, x in PLOT_X do
			index += 1
			-- north plots face -Z, south plots face +Z (toward the plaza)
			local origin = CFrame.lookAt(Vector3.new(x, g, side * PLOT_Z), Vector3.new(x, g, 0))
			buildPlot(index, origin, plots)
			task.wait()
		end
	end
	buildPlaza(world, g)
	buildScenery(world, g)
	world.Parent = workspace
	return string.format("World built: %d plots (ground at y=%.2f)", index, g)
end

return Build
