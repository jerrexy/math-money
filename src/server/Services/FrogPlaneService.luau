--[[
	The Frog Plane event. Every FrogPlane.Interval seconds Ribbit's plane crosses
	the island and drops frog safes on parachutes (players + 2 of them). Walk up to
	one and crack its 3-number combination: each number is the answer to a math
	problem one level above your own, on the machines you play. Inside: money, and
	sometimes an exclusive item the shop doesn't sell.

	Like the machines, the server decides everything (flight path, landing spots,
	timing, problems, prizes) and the clients animate the plane, the falling safes,
	parachutes and beacons from those numbers (FrogPlaneController).

	  workspace @NextFrogPlane       server time of the next flight (HUD countdown)
	  safe @State                    "Falling" | "Ready" | "Cracking" | "Open"
	  safe @DropFrom/@DropAt/@LandAt where and when it left the plane, when it lands
	  safe @Cracker                  display name of whoever is cracking (or opened) it
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)
local Economy = require(Shared.Config.Economy)
local FrogPlane = require(Shared.Config.FrogPlane)
local Machines = require(Shared.Config.Machines)
local MathQuestions = require(Shared.MathQuestions)
local Remotes = require(Shared.Remotes)

local FrogPlaneService = {}
local services

type Session = {
	player: Player,
	safe: any,
	problems: { MathQuestions.Question },
	levels: { number },
	digits: { number },
	qid: number,
	lastActive: number,
	jammedUntil: number,
}

type SafeRec = {
	model: Model,
	prompt: ProximityPrompt,
	state: string,
	expiresAt: number,
	session: Session?,
}

local rng = Random.new()
local safes: { [Model]: SafeRec } = {}
local sessions: { [Player]: Session } = {}
local folder: Folder
local keepClear: { Vector3 } = {}
local nextFlight = 0
local warned = false

local function now(): number
	return workspace:GetServerTimeNow()
end

local function notify(player: Player, text: string)
	Remotes.Notify:FireClient(player, text, "info")
end

---------------------------------------------------------------------------
-- Cracking a safe
---------------------------------------------------------------------------

--- Three problems, one level above the player's own, from the machines they play.
local function makeProblems(profile): ({ MathQuestions.Question }, { number })
	local kinds = {}
	for _, kind in Machines.Order do
		if profile.machines[kind].rounds > 0 then
			table.insert(kinds, kind)
		end
	end
	if #kinds == 0 then
		kinds = { "Addition" }
	end
	for i = #kinds, 2, -1 do
		local j = rng:NextInteger(1, i)
		kinds[i], kinds[j] = kinds[j], kinds[i]
	end
	local problems, levels, recent = {}, {}, {}
	for i = 1, FrogPlane.Problems do
		local kind = kinds[(i - 1) % #kinds + 1]
		local level = math.min(Economy.MaxLevel, profile.machines[kind].level + 1)
		local q = MathQuestions.generate(kind, level, rng, recent, true)
		table.insert(recent, q.key)
		table.insert(problems, q)
		table.insert(levels, level)
	end
	return problems, levels
end

local function release(session: Session, reason: string)
	local safe = session.safe
	sessions[session.player] = nil
	if safe.session == session then
		safe.session = nil
	end
	if safe.state == "Cracking" then
		safe.state = "Ready"
		safe.model:SetAttribute("State", "Ready")
		safe.model:SetAttribute("Cracker", nil)
		safe.prompt.Enabled = true
	end
	if session.player.Parent then
		Remotes.SafeEvent:FireClient(session.player, "Closed", { safe = safe.model, reason = reason })
	end
end

local function startCracking(safe: SafeRec, player: Player)
	if safe.state == "Cracking" and safe.session and safe.session.player ~= player then
		notify(player, safe.session.player.DisplayName .. " is cracking this one. Find another safe! 🐸")
		return
	end
	if safe.state ~= "Ready" or sessions[player] then
		return
	end
	if services.MachineService:HasRunningRound(player) then
		notify(player, "Finish your machine round first!")
		return
	end
	local profile = services.DataService:Get(player)
	if not profile then
		return
	end
	local problems, levels = makeProblems(profile)
	local session: Session = {
		player = player,
		safe = safe,
		problems = problems,
		levels = levels,
		digits = {},
		qid = 1,
		lastActive = now(),
		jammedUntil = 0,
	}
	sessions[player] = session
	safe.session = session
	safe.state = "Cracking"
	safe.model:SetAttribute("State", "Cracking")
	safe.model:SetAttribute("Cracker", player.DisplayName)
	safe.prompt.Enabled = false
	Remotes.SafeEvent:FireClient(player, "Open", {
		safe = safe.model,
		count = #problems,
		qid = session.qid,
		question = problems[1].text,
	})
end

--- An exclusive the player doesn't have yet (always on their very first safe).
local function pickItem(profile): Catalog.Item?
	local missing = {}
	for _, item in Catalog.exclusives() do
		if not profile.owned[item.id] then
			table.insert(missing, item)
		end
	end
	if #missing == 0 then
		return nil
	end
	if (profile.stats.safes or 0) == 0 or rng:NextNumber() < FrogPlane.ItemChance then
		return missing[rng:NextInteger(1, #missing)]
	end
	return nil
end

--- Put a prize on (or in the seed pouch) so it shows up straight away.
local function grant(p, item: Catalog.Item)
	p.owned[item.id] = true
	if Catalog.isPlaceable(item) then
		p.pouch[item.id] = (p.pouch[item.id] or 0) + 1
	elseif item.kind == "Costume" and item.slot then
		p.equipped[item.slot] = item.id
	elseif item.kind == "Pet" then
		for _, other in Catalog.ByCategory[item.category] do
			if other.kind == "Pet" then
				p.toggles[other.id] = nil
			end
		end
		p.toggles[item.id] = true
	end
end

local function removeSafe(safe: SafeRec, fx: string?)
	if safes[safe.model] ~= safe then
		return
	end
	safes[safe.model] = nil
	if safe.session then
		release(safe.session, "gone")
	end
	if fx then
		Remotes.MachineFx:FireAllClients(safe.model, fx, {})
	end
	task.delay(if fx then 1.5 else 0, function()
		safe.model:Destroy()
	end)
end

local function crack(session: Session)
	local safe, player = session.safe, session.player
	sessions[player] = nil
	safe.session = nil
	safe.state = "Open"
	safe.model:SetAttribute("State", "Open")
	safe.model:SetAttribute("Cracker", player.DisplayName)
	Remotes.MachineFx:FireAllClients(safe.model, "SafeOpen", { by = player.DisplayName })
	task.delay(10, removeSafe, safe, "SafeGone")

	local profile = services.DataService:Get(player)
	if not profile then
		return
	end
	local plates = 0
	for i, q in session.problems do
		plates += Economy.plateValue(Machines.get(q.kind).basePlate, session.levels[i])
	end
	local money = plates * FrogPlane.PrizePlates
	local ownsAll = true
	for _, item in Catalog.exclusives() do
		if not profile.owned[item.id] then
			ownsAll = false
		end
	end
	if ownsAll then
		money *= 1 + FrogPlane.ItemBonus
	end
	money = math.max(5, math.floor(money / 5 + 0.5) * 5)
	local item = pickItem(profile)
	services.DataService:AddMoney(player, money)
	services.DataService:Update(player, function(p)
		p.stats.safes = (p.stats.safes or 0) + 1
		if item then
			grant(p, item)
		end
	end)
	if item then
		if Catalog.isPlaceable(item) then
			services.GardenService:RefreshTools(player)
		else
			services.AvatarService:Apply(player)
		end
	end
	Remotes.SafeEvent:FireClient(player, "Cracked", {
		safe = safe.model,
		money = money,
		item = if item then item.id else nil,
		combination = session.digits,
	})
end

local function onAnswer(player: Player, model: any, qid: any, value: any)
	local session = sessions[player]
	if not session or session.safe.model ~= model or qid ~= session.qid then
		return
	end
	local t = now()
	value = tonumber(value)
	if t < session.jammedUntil or not value or value ~= value then
		return
	end
	session.lastActive = t
	local slot = #session.digits + 1
	local q = session.problems[slot]
	local correct = math.floor(value) == q.answer
	services.MachineService:RecordPractice(player, q, correct)
	session.qid += 1
	if correct then
		table.insert(session.digits, q.answer)
		local done = #session.digits >= #session.problems
		Remotes.SafeEvent:FireClient(player, "Correct", {
			safe = model,
			slot = slot,
			value = q.answer,
			done = done,
			qid = session.qid,
			question = if done then nil else session.problems[slot + 1].text,
		})
		if done then
			crack(session)
		end
	else
		-- show the right answer, then a fresh problem for the same number
		local fresh = MathQuestions.generate(q.kind, session.levels[slot], rng, { q.key }, true)
		session.problems[slot] = fresh
		session.jammedUntil = t + FrogPlane.WrongDelay
		Remotes.SafeEvent:FireClient(player, "Wrong", {
			safe = model,
			slot = slot,
			answer = q.answer,
			explain = MathQuestions.explain(q),
			qid = session.qid,
			question = fresh.text,
			delay = FrogPlane.WrongDelay,
		})
	end
end

---------------------------------------------------------------------------
-- Flights and drops
---------------------------------------------------------------------------

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

--- Open, flat ground at (x, z): terrain only, so trees, lamps and fences don't count.
local function groundAt(x: number, z: number): Vector3?
	groundParams.FilterDescendantsInstances = { workspace.Terrain, workspace:FindFirstChild("World") :: Instance }
	local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -500, 0), groundParams)
	if hit and hit.Instance == workspace.Terrain and hit.Normal.Y > 0.85 and hit.Material ~= Enum.Material.Water then
		return hit.Position
	end
	return nil
end

local function pickSpots(count: number): { Vector3 }
	local total = 0
	for _, zone in FrogPlane.Zones do
		total += zone.weight
	end
	local taken = {}
	for model in safes do
		table.insert(taken, model:GetPivot().Position)
	end
	local spots = {}
	for _ = 1, count * 40 do
		if #spots >= count then
			break
		end
		local roll = rng:NextNumber() * total
		local zone = FrogPlane.Zones[1]
		for _, z in FrogPlane.Zones do
			roll -= z.weight
			if roll <= 0 then
				zone = z
				break
			end
		end
		local spot = Vector2.new(rng:NextNumber(zone.min.X, zone.max.X), rng:NextNumber(zone.min.Y, zone.max.Y))
		local clear = true
		for _, p in keepClear do
			if (spot - Vector2.new(p.X, p.Z)).Magnitude < FrogPlane.KeepClear then
				clear = false
			end
		end
		for _, list in { spots, taken } do
			for _, p in list do
				if (spot - Vector2.new(p.X, p.Z)).Magnitude < FrogPlane.SafeSpacing then
					clear = false
				end
			end
		end
		local ground = if clear then groundAt(spot.X, spot.Y) else nil
		if ground then
			table.insert(spots, ground)
		end
	end
	return spots
end

local function safeTemplate(): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local group = assets and assets:FindFirstChild("FrogPlane")
	local found = group and group:FindFirstChild("FrogSafe")
	if found then
		return found:Clone() :: Model
	end
	-- placeholder so the event still works before the art is imported
	local model = Instance.new("Model")
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(5, 4.6, 5)
	body.CFrame = CFrame.new(0, 2.3, 0)
	body.Color = Color3.fromRGB(108, 200, 84)
	body.Parent = model
	model.WorldPivot = CFrame.new()
	return model
end

local function spawnSafe(drop)
	local model = safeTemplate()
	model.Name = "FrogSafe"
	local spot: Vector3 = drop.spot
	-- the door faces the middle of the island, where most players are
	local flat = Vector3.new(spot.X, 0, spot.Z)
	model:PivotTo(if flat.Magnitude > 1 then CFrame.lookAt(spot, Vector3.new(0, spot.Y, 0)) else CFrame.new(spot))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	model:SetAttribute("State", "Falling")
	model:SetAttribute("DropFrom", drop.from)
	model:SetAttribute("DropAt", drop.dropAt)
	model:SetAttribute("LandAt", drop.landAt)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Crack the safe!"
	prompt.ObjectText = "Frog Safe"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = model:FindFirstChild("Body") or model:FindFirstChildWhichIsA("BasePart")
	local rec: SafeRec = {
		model = model,
		prompt = prompt,
		state = "Falling",
		expiresAt = drop.landAt + FrogPlane.SafeLifetime,
		session = nil,
	}
	safes[model] = rec
	prompt.Triggered:Connect(function(player)
		startCracking(rec, player)
	end)
	model.Parent = folder
	task.delay(math.max(0, drop.landAt - now()), function()
		if safes[model] == rec and rec.state == "Falling" then
			rec.state = "Ready"
			model:SetAttribute("State", "Ready")
			prompt.Enabled = true
		end
	end)
end

local function launch()
	local start = now() + 1.5 -- a moment for every client to hear about it
	local dir = if rng:NextNumber() < 0.5 then 1 else -1
	local angle = math.rad(rng:NextNumber(-12, 12))
	local heading = Vector3.new(math.cos(angle) * dir, 0, math.sin(angle) * dir)
	local center = Vector3.new(rng:NextNumber(-60, 60), FrogPlane.Altitude, rng:NextNumber(-25, 25))
	local from = center - heading * FrogPlane.Span / 2
	local to = center + heading * FrogPlane.Span / 2
	local count = math.clamp(#Players:GetPlayers() + FrogPlane.ExtraSafes, FrogPlane.MinSafes, FrogPlane.MaxSafes)
	Remotes.FrogPlane:FireAllClients("Flight", { start = start, from = from, to = to, duration = FrogPlane.FlightTime })
	for _, spot in pickSpots(count) do
		-- each safe leaves the plane when the plane is closest to its landing spot
		local along = math.clamp((spot - from):Dot(heading) / FrogPlane.Span, 0.05, 0.95)
		local dropFrom = from:Lerp(to, along) + Vector3.new(0, -6, 0)
		local drift = (Vector2.new(dropFrom.X, dropFrom.Z) - Vector2.new(spot.X, spot.Z)).Magnitude
		local dropAt = start + along * FrogPlane.FlightTime
		local drop = { spot = spot, from = dropFrom, dropAt = dropAt, landAt = dropAt + FrogPlane.FallTime + drift / 45 }
		task.delay(math.max(0, dropAt - now()), spawnSafe, drop)
	end
end

local function update()
	local t = now()
	if not warned and t >= nextFlight - FrogPlane.Warning then
		warned = true
		Remotes.FrogPlane:FireAllClients("Soon", { at = nextFlight })
	end
	if t >= nextFlight then
		launch()
		nextFlight = t + FrogPlane.Interval
		warned = false
		workspace:SetAttribute("NextFrogPlane", nextFlight)
	end
	for _, safe in safes do
		local session = safe.session
		if session then
			local character = session.player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not session.player.Parent then
				release(session, "left")
			elseif not root or (root.Position - safe.model:GetPivot().Position).Magnitude > FrogPlane.CrackRange then
				release(session, "walked")
			elseif t - session.lastActive > FrogPlane.CrackIdle then
				release(session, "idle")
			end
		elseif safe.state ~= "Open" and t > safe.expiresAt then
			removeSafe(safe, "SafeGone")
		end
	end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function FrogPlaneService:IsCracking(player: Player): boolean
	return sessions[player] ~= nil
end

--- Send the plane right now (the !plane admin command).
function FrogPlaneService:LaunchNow()
	nextFlight = now()
	warned = true
end

function FrogPlaneService:Init(allServices)
	services = allServices
end

function FrogPlaneService:Start()
	folder = Instance.new("Folder")
	folder.Name = "FrogDrops"
	folder.Parent = workspace

	local world = workspace:WaitForChild("World", 30)
	local plaza = world and world:FindFirstChild("Plaza")
	if plaza then
		for _, name in { "Shop", "Spawn", "WelcomeSign" } do
			local thing = plaza:FindFirstChild(name)
			if thing and thing:IsA("Model") then
				table.insert(keepClear, thing:GetPivot().Position)
			elseif thing and thing:IsA("BasePart") then
				table.insert(keepClear, thing.Position)
			end
		end
	end

	Remotes.SafeAction.OnServerEvent:Connect(function(player: Player, action: any, model: any, ...)
		if action == "Answer" then
			onAnswer(player, model, ...)
		elseif action == "Quit" then
			local session = sessions[player]
			if session and session.safe.model == model then
				release(session, "quit")
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			release(session, "left")
		end
	end)

	-- Studio-only testing hook: ServerStorage.MM_DevGiveItem:Invoke(userId, itemId)
	if RunService:IsStudio() then
		local give = Instance.new("BindableFunction")
		give.Name = "MM_DevGiveItem"
		give.OnInvoke = function(userId: number, itemId: string)
			local player = Players:GetPlayerByUserId(userId)
			local item = Catalog.get(itemId)
			if not player or not item or not services.DataService:Get(player) then
				return false
			end
			services.DataService:Update(player, function(p)
				grant(p, item)
			end)
			if Catalog.isPlaceable(item) then
				services.GardenService:RefreshTools(player)
			else
				services.AvatarService:Apply(player)
			end
			return true
		end
		give.Parent = game:GetService("ServerStorage")
	end

	nextFlight = now() + FrogPlane.FirstFlight
	workspace:SetAttribute("NextFrogPlane", nextFlight)
	task.spawn(function()
		while true do
			task.wait(1)
			update()
		end
	end)
end

return FrogPlaneService
