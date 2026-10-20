--[[
	The money machines: spawning them on a claimed plot and running rounds.

	A round (server authoritative):
	  1. The owner presses E at the computer -> client gets an "Offer" dialog.
	  2. "Start": the plate starts lowering toward the acid and a 30s timer runs.
	  3. Every question: right answer -> chain pauses for pauseTime (stacks a bit);
	     wrong answer -> jewels fall off and the right answer is shown.
	  4. Timer runs out first -> the player keeps what's left on the plate.
	     Plate reaches the acid first -> everything melts, no money.

	The chain position is published as attributes (DropBase / DropStart / DropRate /
	PausedUntil, all in workspace:GetServerTimeNow() time) so every client can
	render the same smooth motion without the server streaming positions.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Util.Format)
local Machines = require(Shared.Config.Machines)
local MathQuestions = require(Shared.MathQuestions)
local Remotes = require(Shared.Remotes)

local TAG = "MathMachine"
local TICK = 0.1

local MachineService = {}
local services

type Rec = {
	model: Model,
	def: any,
	kind: string,
	plot: any,
	owner: Player,
	state: string,
	roundId: number,
	level: number,
	plateValue: number,
	jewelValue: number,
	jewels: number,
	dropBase: number,
	dropStart: number,
	dropRate: number,
	pausedUntil: number,
	startAt: number,
	endsAt: number,
	correct: number,
	wrong: number,
	streak: number,
	asked: number,
	question: any?,
	qid: number,
	recent: { string },
	retry: { { key: string, due: number } },
	rng: Random,
	screen: { [string]: TextLabel },
	prompt: ProximityPrompt,
	lastScreen: number,
	lastAnswer: number,
}

local records: { [Model]: Rec } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function markerCFrame(model: Model, name: string): CFrame
	local markers = model:FindFirstChild("Markers")
	local value = markers and markers:FindFirstChild(name)
	return if value then (value :: CFrameValue).Value else CFrame.new()
end

---------------------------------------------------------------------------
-- Building a machine
---------------------------------------------------------------------------

local function makeLabel(parent: Instance, name: string, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(150, 255, 150)
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

local function buildScreen(model: Model, def): { [string]: TextLabel }
	local screen = Instance.new("Part")
	screen.Name = "Screen"
	screen.Size = Vector3.new(4.3, 3.25, 0.08)
	screen.CFrame = markerCFrame(model, "Screen")
	screen.Anchored = true
	screen.CanCollide = false
	screen.CanTouch = false
	screen.CastShadow = false
	screen.Material = Enum.Material.SmoothPlastic
	screen.Color = Color3.fromRGB(10, 26, 18)
	screen.Parent = model

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 100
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.ClipsDescendants = true
	gui.Parent = screen

	local accent = def.themeColor:Lerp(Color3.new(1, 1, 1), 0.35)
	local labels = {
		Title = makeLabel(gui, "Title", {
			Size = UDim2.fromScale(0.92, 0.2),
			Position = UDim2.fromScale(0.04, 0.03),
			TextColor3 = accent,
			Text = def.op .. " " .. string.upper(def.displayName) .. " " .. def.op,
		}),
		Big = makeLabel(gui, "Big", {
			Size = UDim2.fromScale(0.92, 0.42),
			Position = UDim2.fromScale(0.04, 0.26),
			Text = "PLAY ME!",
		}),
		Info = makeLabel(gui, "Info", {
			Size = UDim2.fromScale(0.92, 0.2),
			Position = UDim2.fromScale(0.04, 0.74),
			TextColor3 = Color3.fromRGB(220, 255, 220),
			Text = "",
		}),
	}
	return labels
end

local function addFx(model: Model, def)
	local root = Instance.new("Part")
	root.Name = "FxRoot"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.CFrame = CFrame.new()
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = model

	local function attachment(name: string, markerName: string): Attachment
		local att = Instance.new("Attachment")
		att.Name = name
		att.CFrame = markerCFrame(model, markerName)
		att.Parent = root
		return att
	end

	local smoke = attachment("Smoke", "Smoke")
	local puff = Instance.new("ParticleEmitter")
	puff.Name = "Puff"
	puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
	puff.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
	puff.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.5) })
	puff.Lifetime = NumberRange.new(2.5, 3.5)
	puff.Speed = NumberRange.new(3, 5)
	puff.SpreadAngle = Vector2.new(12, 12)
	puff.Acceleration = Vector3.new(0.6, 1.2, 0)
	puff.RotSpeed = NumberRange.new(-30, 30)
	puff.Rate = 1.2
	puff.Parent = smoke

	local burst = puff:Clone()
	burst.Name = "Burst"
	burst.Color = ColorSequence.new(Color3.fromRGB(45, 45, 50))
	burst.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 6) })
	burst.Speed = NumberRange.new(6, 11)
	burst.SpreadAngle = Vector2.new(35, 35)
	burst.Rate = 0
	burst.Parent = smoke

	-- green fumes drifting off the acid + a spooky glow
	local acid = model:FindFirstChild("Acid") :: BasePart?
	if acid then
		local fumes = Instance.new("ParticleEmitter")
		fumes.Name = "Fumes"
		fumes.Texture = "rbxasset://textures/particles/smoke_main.dds"
		fumes.Color = ColorSequence.new(Color3.fromRGB(150, 255, 90))
		fumes.LightEmission = 0.6
		fumes.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		})
		fumes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.2) })
		fumes.Lifetime = NumberRange.new(2, 3)
		fumes.Speed = NumberRange.new(1, 2.5)
		fumes.EmissionDirection = Enum.NormalId.Top
		fumes.Rate = 3
		fumes.Parent = acid
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(140, 255, 90)
		glow.Range = 16
		glow.Brightness = 1.4
		glow.Parent = acid
	end

	-- invisible lid so nobody can hop into the acid
	local lid = Instance.new("Part")
	lid.Name = "AcidGuard"
	lid.Shape = Enum.PartType.Cylinder
	lid.Size = Vector3.new(8, 15.4, 15.4)
	lid.CFrame = CFrame.new(0, 10, 0) * CFrame.Angles(0, 0, math.rad(90))
	lid.Transparency = 1
	lid.Anchored = true
	lid.CanCollide = true
	lid.CanTouch = false
	lid.CanQuery = false
	lid.Parent = model

	-- the prompt sits just in front of the keyboard
	local anchor = Instance.new("Part")
	anchor.Name = "PromptAnchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = markerCFrame(model, "Prompt")
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PlayPrompt"
	prompt.ActionText = "Earn money!"
	prompt.ObjectText = def.displayName .. " Machine"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	return prompt
end

local function setScreen(rec: Rec, big: string?, info: string?, color: Color3?)
	if big then
		rec.screen.Big.Text = big
	end
	if info then
		rec.screen.Info.Text = info
	end
	rec.screen.Big.TextColor3 = color or Color3.fromRGB(150, 255, 150)
end

local function idleScreen(rec: Rec)
	local profile = services.DataService:Get(rec.owner)
	local level = if profile then profile.machines[rec.kind].level else 1
	setScreen(rec, "PLAY ME!", string.format("Level %d  •  Plate %s", level,
		Format.money(Economy.plateValue(rec.def.basePlate, level))))
end

local function publish(rec: Rec)
	local m = rec.model
	m:SetAttribute("State", rec.state)
	m:SetAttribute("Jewels", rec.jewels)
	m:SetAttribute("DropBase", rec.dropBase)
	m:SetAttribute("DropStart", rec.dropStart)
	m:SetAttribute("DropRate", rec.dropRate)
	m:SetAttribute("PausedUntil", rec.pausedUntil)
	m:SetAttribute("StartAt", rec.startAt)
	m:SetAttribute("EndsAt", rec.endsAt)
	m:SetAttribute("Level", rec.level)
	m:SetAttribute("PlateValue", rec.plateValue)
	m:SetAttribute("RoundId", rec.roundId)
end

local function progressAt(rec: Rec, t: number): number
	if t < rec.pausedUntil then
		return rec.dropBase
	end
	local from = math.max(rec.dropStart, rec.pausedUntil)
	return rec.dropBase + rec.dropRate * math.max(0, t - from)
end

---------------------------------------------------------------------------
-- Rounds
---------------------------------------------------------------------------

local function fx(rec: Rec, name: string, payload: { [string]: any }?)
	Remotes.MachineFx:FireAllClients(rec.model, name, payload or {})
end

local function nextQuestion(rec: Rec)
	if rec.state ~= "Running" then
		return
	end
	local q
	for i, entry in rec.retry do
		if entry.due <= rec.asked then
			table.remove(rec.retry, i)
			q = MathQuestions.fromKey(entry.key)
			break
		end
	end
	q = q or MathQuestions.generate(rec.kind, rec.level, rec.rng, rec.recent)
	rec.asked += 1
	rec.qid += 1
	rec.question = q
	table.insert(rec.recent, q.key)
	if #rec.recent > 5 then
		table.remove(rec.recent, 1)
	end
	setScreen(rec, q.text .. " = ?")
	Remotes.RoundEvent:FireClient(rec.owner, "Question", {
		machine = rec.model,
		roundId = rec.roundId,
		qid = rec.qid,
		text = q.text,
		digits = #tostring(q.answer),
	})
end

local function recordAnswer(rec: Rec, q, correct: boolean): boolean
	local leveledUp = false
	services.DataService:Update(rec.owner, function(profile)
		profile.stats.questions += 1
		local m = profile.machines[rec.kind]
		if correct then
			profile.stats.correct += 1
			m.correct += 1
		else
			m.wrong += 1
		end
		-- only remember "facts" kids memorise (sums to 20, all times tables)
		local isFact = q.kind == "Multiplication" or q.kind == "Division" or (q.a <= 20 and q.b <= 20)
		if isFact then
			local fact = profile.facts[q.key] or { c = 0, w = 0 }
			if correct then
				fact.c += 1
			else
				fact.w += 1
			end
			profile.facts[q.key] = fact
		end
		-- XP only counts on the hardest level you've unlocked
		if rec.level == m.level then
			m.xp = if correct then m.xp + 1 else math.max(0, m.xp - 1)
			if m.level < Economy.MaxLevel and m.xp >= Economy.xpToLevelUp(m.level) then
				m.level += 1
				m.xp = 0
				leveledUp = true
			end
		end
	end)
	return leveledUp
end

local endRound -- forward declaration

local function onAnswer(rec: Rec, qid: number, value: number)
	local q = rec.question
	if rec.state ~= "Running" or not q or qid ~= rec.qid then
		return
	end
	local t = now()
	if t - rec.lastAnswer < 0.15 then
		return -- ignore button mashing
	end
	rec.lastAnswer = t
	rec.question = nil
	local correct = value == q.answer
	local leveledUp = recordAnswer(rec, q, correct)
	local bonus = false

	if correct then
		rec.correct += 1
		rec.streak += 1
		if t < rec.pausedUntil then
			rec.pausedUntil = math.min(rec.pausedUntil + rec.def.pauseTime, t + rec.def.pauseTime * Economy.MaxPauseStack)
		else
			rec.dropBase = progressAt(rec, t)
			rec.dropStart = t
			rec.pausedUntil = math.max(t, rec.startAt) + rec.def.pauseTime
		end
		if rec.streak % Economy.StreakForBonus == 0 and rec.jewels < Economy.MaxJewels then
			rec.jewels += 1
			bonus = true
		end
		publish(rec)
		fx(rec, "Correct", { streak = rec.streak, bonus = bonus })
		Remotes.RoundEvent:FireClient(rec.owner, "Answer", {
			machine = rec.model,
			correct = true,
			pausedUntil = rec.pausedUntil,
			streak = rec.streak,
			bonus = bonus,
			jewels = rec.jewels,
			leveledUp = leveledUp,
		})
		nextQuestion(rec)
	else
		rec.wrong += 1
		rec.streak = 0
		local lost = math.min(Economy.JewelsLostPerWrong, rec.jewels)
		rec.jewels -= lost
		table.insert(rec.retry, { key = q.key, due = rec.asked + 2 })
		publish(rec)
		fx(rec, "Wrong", { lost = lost })
		setScreen(rec, q.text .. " = " .. q.answer, nil, Color3.fromRGB(255, 120, 120))
		Remotes.RoundEvent:FireClient(rec.owner, "Answer", {
			machine = rec.model,
			correct = false,
			answer = q.answer,
			explain = MathQuestions.explain(q),
			jewels = rec.jewels,
			lost = lost,
			leveledUp = leveledUp,
		})
		local roundId = rec.roundId
		if rec.jewels <= 0 then
			task.delay(Economy.WrongAnswerDelay, function()
				if rec.roundId == roundId then
					endRound(rec, "Empty")
				end
			end)
		else
			task.delay(Economy.WrongAnswerDelay, function()
				if rec.roundId == roundId then
					nextQuestion(rec)
				end
			end)
		end
	end
end

local function resetMachine(rec: Rec)
	if not rec.model.Parent then
		return
	end
	rec.state = "Resetting"
	rec.jewels = Economy.PlateJewels
	rec.dropBase, rec.dropStart, rec.dropRate, rec.pausedUntil = 0, 0, 0, 0
	rec.model:SetAttribute("ResetAt", now())
	rec.model:SetAttribute("LootSeed", rec.rng:NextInteger(1, 1e6))
	publish(rec)
	setScreen(rec, "RESETTING...", "")
	task.delay(Economy.ResetSeconds, function()
		if rec.model.Parent and rec.state == "Resetting" then
			rec.state = "Idle"
			publish(rec)
			idleScreen(rec)
		end
	end)
end

endRound = function(rec: Rec, result: string)
	if rec.state ~= "Running" then
		return
	end
	rec.state = result
	rec.question = nil
	local payout, perfect = 0, false
	if result == "Win" then
		payout = math.floor(rec.jewels * rec.jewelValue + 0.5)
		if rec.wrong == 0 and rec.correct >= Economy.PerfectMinCorrect then
			perfect = true
			payout = math.floor(payout * (1 + Economy.PerfectBonus) + 0.5)
		end
	end
	-- freeze the chain where it is
	local t = now()
	rec.dropBase = math.min(progressAt(rec, t), 1)
	rec.dropStart = t
	rec.dropRate = 0
	rec.pausedUntil = 0
	rec.model:SetAttribute("Payout", payout)
	publish(rec)

	local owner = rec.owner
	if owner.Parent then
		if payout > 0 then
			services.DataService:AddMoney(owner, payout)
		end
		services.DataService:Update(owner, function(profile)
			local m = profile.machines[rec.kind]
			m.rounds += 1
			profile.stats.rounds += 1
			if result == "Win" then
				m.wins += 1
				m.best = math.max(m.best, payout)
			end
		end)
	end
	fx(rec, result, { payout = payout, userId = owner.UserId, perfect = perfect })
	if result == "Win" then
		setScreen(rec, "YOU WIN!", "+" .. Format.money(payout), Color3.fromRGB(255, 230, 90))
	elseif result == "Melt" then
		setScreen(rec, "MELTED!", "Try again!", Color3.fromRGB(255, 120, 120))
	elseif result == "Empty" then
		setScreen(rec, "PLATE EMPTY!", "Try again!", Color3.fromRGB(255, 120, 120))
	else
		setScreen(rec, "ROUND OVER", "")
	end
	Remotes.RoundEvent:FireClient(owner, "End", {
		machine = rec.model,
		result = result,
		payout = payout,
		perfect = perfect,
		correct = rec.correct,
		wrong = rec.wrong,
	})
	task.delay(if result == "Win" then 3.2 elseif result == "Melt" then 3 else 1.5, function()
		resetMachine(rec)
	end)
end

local function startRound(rec: Rec, level: number)
	local profile = services.DataService:Get(rec.owner)
	if not profile then
		return
	end
	local unlocked = profile.machines[rec.kind].level
	level = math.clamp(math.floor(tonumber(level) or unlocked), 1, unlocked)
	local t = now()
	rec.state = "Running"
	rec.roundId += 1
	rec.level = level
	rec.plateValue = Economy.plateValue(rec.def.basePlate, level)
	rec.jewelValue = rec.plateValue / Economy.PlateJewels
	rec.jewels = Economy.PlateJewels
	rec.correct, rec.wrong, rec.streak, rec.asked = 0, 0, 0, 0
	rec.recent, rec.retry = {}, {}
	rec.startAt = t + Economy.StartDelay
	rec.endsAt = rec.startAt + Economy.RoundSeconds
	rec.dropBase, rec.dropStart, rec.pausedUntil = 0, rec.startAt, 0
	rec.dropRate = 1 / rec.def.dropTime
	publish(rec)
	setScreen(rec, "GET READY!", string.format("Level %d  •  %s", level, Format.money(rec.plateValue)))
	Remotes.RoundEvent:FireClient(rec.owner, "Started", {
		machine = rec.model,
		kind = rec.kind,
		level = level,
		plateValue = rec.plateValue,
		jewels = rec.jewels,
		startAt = rec.startAt,
		endsAt = rec.endsAt,
		pauseTime = rec.def.pauseTime,
	})
	fx(rec, "Start", {})
	nextQuestion(rec)
end

local function ownerHasRunningRound(player: Player): boolean
	for _, rec in records do
		if rec.owner == player and rec.state == "Running" then
			return true
		end
	end
	return false
end

local function distanceTo(rec: Rec, player: Player): number
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return math.huge
	end
	local console = rec.model:GetPivot() * markerCFrame(rec.model, "Prompt")
	return (root.Position - console.Position).Magnitude
end

local function offer(rec: Rec, player: Player)
	if player ~= rec.owner then
		Remotes.Notify:FireClient(player, "This machine belongs to " .. rec.owner.DisplayName .. ". Find a FREE PLOT sign to get your own!", "info")
		return
	end
	if rec.state ~= "Idle" then
		return
	end
	if ownerHasRunningRound(player) then
		Remotes.Notify:FireClient(player, "Finish your other round first!", "info")
		return
	end
	local profile = services.DataService:Get(player)
	if not profile then
		return
	end
	local m = profile.machines[rec.kind]
	local levels = {}
	for level = 1, m.level do
		levels[level] = {
			name = MathQuestions.levelName(rec.kind, level),
			plate = Economy.plateValue(rec.def.basePlate, level),
		}
	end
	Remotes.RoundEvent:FireClient(player, "Offer", {
		machine = rec.model,
		kind = rec.kind,
		level = m.level,
		levels = levels,
		xp = m.xp,
		xpNeeded = Economy.xpToLevelUp(m.level),
		maxLevel = Economy.MaxLevel,
		nextLevelName = if m.level < Economy.MaxLevel then MathQuestions.levelName(rec.kind, m.level + 1) else nil,
	})
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Clone the four machines onto a freshly claimed plot.
function MachineService:SpawnFor(plot, player: Player)
	local prefab = ServerStorage:FindFirstChild("Prefabs") and ServerStorage.Prefabs:FindFirstChild("Apparatus")
	if not prefab then
		warn("[MachineService] ServerStorage.Prefabs.Apparatus is missing")
		return
	end
	local profile = services.DataService:Get(player)
	for index, kind in Machines.Order do
		local slot = plot.slots[kind]
		if not slot then
			continue
		end
		local def = Machines.get(kind)
		local model = prefab:Clone() :: Model
		model.Name = kind .. "Machine"
		local symbols = model:FindFirstChild("Symbols")
		if symbols then
			for _, symbol in symbols:GetChildren() do
				if symbol.Name ~= def.symbolPart then
					symbol:Destroy()
				elseif symbol:IsA("BasePart") then
					symbol.Color = def.themeColor
				end
			end
		end
		local body = model:FindFirstChild("EngineBody") :: BasePart?
		if body then
			body.Color = def.themeColor
		end
		local plate = model:FindFirstChild("Plate")
		local platter = plate and plate:FindFirstChild("Platter") :: BasePart?
		if platter then
			platter.Color = def.plateColor
		end
		local screen = buildScreen(model, def)
		local prompt = addFx(model, def)
		model:SetAttribute("Kind", kind)
		model:SetAttribute("OwnerId", player.UserId)
		model:SetAttribute("LootSeed", math.random(1, 1e6))
		model:SetAttribute("SpawnIndex", index)
		model:SetAttribute("SpawnedAt", now())
		model:PivotTo(slot.CFrame)
		local rec: Rec = {
			model = model,
			def = def,
			kind = kind,
			plot = plot,
			owner = player,
			state = "Idle",
			roundId = 0,
			level = if profile then profile.machines[kind].level else 1,
			plateValue = 0,
			jewelValue = 0,
			jewels = Economy.PlateJewels,
			dropBase = 0,
			dropStart = 0,
			dropRate = 0,
			pausedUntil = 0,
			startAt = 0,
			endsAt = 0,
			correct = 0,
			wrong = 0,
			streak = 0,
			asked = 0,
			question = nil,
			qid = 0,
			recent = {},
			retry = {},
			rng = Random.new(),
			screen = screen,
			prompt = prompt,
			lastScreen = 0,
			lastAnswer = 0,
		}
		rec.plateValue = Economy.plateValue(def.basePlate, rec.level)
		publish(rec)
		idleScreen(rec)
		records[model] = rec
		prompt.Triggered:Connect(function(who)
			offer(rec, who)
		end)
		CollectionService:AddTag(model, TAG)
		-- clients wait until every piece has arrived before animating the machine
		model:SetAttribute("DescendantCount", #model:GetDescendants())
		model.Parent = plot.machinesFolder
	end
end

--- Remove a plot's machines (owner left).
function MachineService:ClearFor(plot)
	for model, rec in records do
		if rec.plot == plot then
			records[model] = nil
			model:Destroy()
		end
	end
end

function MachineService:Init(allServices)
	services = allServices
end

function MachineService:Start()
	Remotes.RoundAction.OnServerEvent:Connect(function(player: Player, action: string, model: Model, ...)
		local rec = typeof(model) == "Instance" and records[model]
		if not rec or rec.owner ~= player then
			return
		end
		if action == "Start" then
			local level = ...
			if rec.state ~= "Idle" or ownerHasRunningRound(player) then
				return
			end
			if distanceTo(rec, player) > Economy.StartRange then
				Remotes.Notify:FireClient(player, "Walk back to the computer to start!", "info")
				return
			end
			startRound(rec, tonumber(level) or 1)
		elseif action == "Answer" then
			local qid, value = ...
			qid, value = tonumber(qid), tonumber(value)
			if qid and value and value == value and math.abs(value) < 1e7 then
				onAnswer(rec, qid, math.floor(value))
			end
		elseif action == "Offer" then
			offer(rec, player)
		elseif action == "Quit" then
			if rec.state == "Running" then
				endRound(rec, "Abandon")
			end
		end
	end)

	-- keep machines' level display fresh when a player levels up or loads in
	services.DataService.Changed:Connect(function(player)
		for _, rec in records do
			if rec.owner == player and rec.state == "Idle" then
				idleScreen(rec)
			end
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < TICK then
			return
		end
		accumulator = 0
		local t = now()
		for _, rec in records do
			if rec.state ~= "Running" then
				continue
			end
			local character = rec.owner.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not rec.owner.Parent or not humanoid or humanoid.Health <= 0 or distanceTo(rec, rec.owner) > Economy.LeaveRange then
				endRound(rec, "Abandon")
			elseif progressAt(rec, t) >= 1 then
				endRound(rec, "Melt")
			elseif t >= rec.endsAt then
				endRound(rec, "Win")
			elseif t - rec.lastScreen > 0.5 then
				rec.lastScreen = t
				setScreen(rec, nil, string.format("⏱ %ds   💎 %d", math.max(0, math.ceil(rec.endsAt - t)), rec.jewels))
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, rec in records do
			if rec.owner == player and rec.state == "Running" then
				endRound(rec, "Abandon")
			end
		end
	end)
end

return MachineService
