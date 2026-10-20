--[[
	Everything the player sees while playing a machine:
	  * the "Want to try to earn money?" offer dialog (with level picker)
	  * the question card: timer, question, typed answer, acid meter, loot count
	  * a big number pad (mouse / touch) plus keyboard digits, Backspace, Enter
	  * a cinematic camera on the machine while the round runs
	  * results: winnings (coins fly into the money counter) or the sad melt screen
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Util.Format)
local Machines = require(Shared.Config.Machines)
local Remotes = require(Shared.Remotes)
local Theme = require(script.Parent.Parent.UI.Theme)

local RoundController = {}
local controllers
local player = Players.LocalPlayer
local C = Theme.Colors

local gui: ScreenGui
local ui: { [string]: any } = {}

local round = {
	busy = false, -- dialog or round on screen
	active = false, -- a round is running
	machine = nil :: Model?,
	kind = "Addition",
	roundId = 0,
	qid = 0,
	typed = "",
	accepting = false,
	endsAt = 0,
	startAt = 0,
	pausedUntil = 0,
	pauseTime = 3,
	jewels = 0,
	plateValue = 0,
	streak = 0,
	offer = nil :: any,
	offerLevel = 1,
	savedCamera = nil :: any,
	savedMove = nil :: any,
	statusUntil = 0,
}

function RoundController.isBusy(): boolean
	return round.busy
end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

local function setBusy(busy: boolean)
	round.busy = busy
	controllers.MachineRenderer.refreshPrompts()
	controllers.HudController.setSideVisible(not busy)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, not busy)
	end)
	-- the number pad replaces the thumbstick/jump buttons while answering
	GuiService.TouchControlsEnabled = not busy
end

local function freezeCharacter(freeze: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if freeze then
		round.savedMove = { humanoid.WalkSpeed, humanoid.JumpHeight }
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
	elseif round.savedMove then
		humanoid.WalkSpeed = round.savedMove[1]
		humanoid.JumpHeight = round.savedMove[2]
		round.savedMove = nil
	end
end

local function cinematic(on: boolean)
	local camera = workspace.CurrentCamera
	if on and round.machine then
		local shot = controllers.MachineRenderer.getCameraShot(round.machine)
		if shot then
			-- slide the camera left so the machine sits on the right; the question
			-- card and number pad live on the left
			shot *= CFrame.new(-13, 0, 0)
			camera.CameraType = Enum.CameraType.Scriptable
			Theme.tween(camera, 1.1, { CFrame = shot }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		end
	else
		camera.CameraType = Enum.CameraType.Custom
	end
end

local function pop(inst: GuiObject, from: number?)
	local scale = inst:FindFirstChildOfClass("UIScale") or Theme.new("UIScale", { Parent = inst })
	scale.Scale = from or 0.7
	Theme.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

local function shake(inst: GuiObject)
	local origin = inst.Position
	task.spawn(function()
		for i = 1, 6 do
			inst.Position = origin + UDim2.fromOffset((if i % 2 == 0 then 1 else -1) * (14 - i * 2), 0)
			task.wait(0.04)
		end
		inst.Position = origin
	end)
end

---------------------------------------------------------------------------
-- Offer dialog
---------------------------------------------------------------------------

local function refreshOffer()
	local offer = round.offer
	if not offer then
		return
	end
	local def = Machines.get(offer.kind)
	local level = round.offerLevel
	local info = offer.levels[level]
	ui.offerTitle.Text = def.op .. "  " .. def.displayName .. " Machine  " .. def.op
	ui.offerHeader.BackgroundColor3 = def.themeColor
	ui.offerLevel.Text = string.format("Level %d  •  %s", level, info.name)
	ui.offerPlate.Text = "Plate worth: " .. Format.money(info.plate) .. " 💎"
	ui.offerPrev.Visible = level > 1
	ui.offerNext.Visible = level < #offer.levels
	if offer.level >= offer.maxLevel then
		ui.offerXp.Text = "⭐ Max level! You're a " .. def.displayName .. " champion!"
		ui.offerXpFill.Size = UDim2.fromScale(1, 1)
	else
		ui.offerXp.Text = string.format("Next level: %d / %d right answers  →  %s", offer.xp, offer.xpNeeded, offer.nextLevelName or "")
		ui.offerXpFill.Size = UDim2.fromScale(math.clamp(offer.xp / offer.xpNeeded, 0, 1), 1)
	end
	ui.offerNote.Visible = level < offer.level
end

local function showOffer(offer)
	round.offer = offer
	round.offerLevel = offer.level
	round.machine = offer.machine
	round.kind = offer.kind
	refreshOffer()
	ui.offer.Visible = true
	pop(ui.offer)
	setBusy(true)
end

local function closeOffer()
	ui.offer.Visible = false
	round.offer = nil
	if not round.active then
		setBusy(false)
	end
end

---------------------------------------------------------------------------
-- Question card + number pad
---------------------------------------------------------------------------

local function refreshAnswer()
	ui.answer.Text = if round.typed == "" then "?" else round.typed
	ui.answer.TextColor3 = if round.typed == "" then C.Gray else C.Ink
end

local function submit()
	if not round.accepting or round.typed == "" then
		return
	end
	round.accepting = false
	Remotes.RoundAction:FireServer("Answer", round.machine, round.qid, tonumber(round.typed))
	controllers.SoundController.play("Click", nil, 0.4)
end

local function typeDigit(d: string)
	if not round.accepting then
		return
	end
	if #round.typed < 5 then
		round.typed ..= d
		refreshAnswer()
		controllers.SoundController.play("Tick", nil, 0.3, 1.2)
	end
end

local function backspace()
	if round.accepting and #round.typed > 0 then
		round.typed = string.sub(round.typed, 1, -2)
		refreshAnswer()
	end
end

local function setStatus(text: string, color: Color3, hold: number?)
	ui.status.Text = text
	ui.status.TextColor3 = color
	round.statusUntil = os.clock() + (hold or 1.2)
end

local function showRound(show: boolean)
	ui.card.Visible = show
	ui.pad.Visible = show
	if show then
		pop(ui.card, 0.8)
		pop(ui.pad, 0.8)
	end
end

local function updateLoot()
	local each = round.plateValue / Economy.PlateJewels
	ui.loot.Text = string.format("💎 %d  •  %s", round.jewels, Format.money(math.floor(round.jewels * each + 0.5)))
end

---------------------------------------------------------------------------
-- Results
---------------------------------------------------------------------------

local function flyCoins(amount: number)
	local target = controllers.HudController.moneyTarget()
	local count = math.clamp(math.floor(amount / 5), 4, 14)
	local center = gui.AbsoluteSize / 2
	for i = 1, count do
		local coin = Theme.text({
			Size = UDim2.fromOffset(46, 46),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(center.X + math.random(-140, 140), center.Y + math.random(-40, 80)),
			Text = "🪙",
			ZIndex = 20,
			Parent = gui,
		})
		local scale = gui:FindFirstChildOfClass("UIScale")
		local s = if scale then scale.Scale else 1
		task.delay(0.15 + i * 0.05, function()
			Theme.tween(coin, 0.6, { Position = UDim2.fromOffset(target.X / s, target.Y / s) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.6)
			coin:Destroy()
		end)
	end
	task.delay(0.9, function()
		controllers.HudController.celebrate(amount)
		controllers.SoundController.play("Cash", nil, 0.6)
	end)
end

local function endRound(payload)
	round.active = false
	round.accepting = false
	showRound(false)
	local result = payload.result
	local title, subtitle, color
	if result == "Win" then
		title = "YOU WON " .. Format.money(payload.payout) .. "!"
		subtitle = string.format("%d right, %d wrong%s", payload.correct, payload.wrong,
			if payload.perfect then "   ⭐ PERFECT ROUND +20%!" else "")
		color = C.Green
		controllers.HudController.hold(1.3)
		task.delay(0.6, function()
			flyCoins(payload.payout)
		end)
	elseif result == "Melt" then
		title = "MELTED! 😱"
		subtitle = "The acid got your loot! Answer faster to stop the chain."
		color = C.Red
	elseif result == "Empty" then
		title = "PLATE EMPTY! 😵"
		subtitle = "All the loot fell off. Take your time — right answers matter most!"
		color = C.Red
	else
		title = "Round over"
		subtitle = "You walked away from the machine."
		color = C.Gray
	end
	ui.resultTitle.Text = title
	ui.resultTitle.TextColor3 = color
	ui.resultSub.Text = subtitle
	ui.result.Visible = result ~= "Abandon"
	if ui.result.Visible then
		pop(ui.result)
	end
	if result == "Abandon" then
		task.delay(0.5, function()
			RoundController.close()
		end)
	end
end

function RoundController.close()
	ui.result.Visible = false
	ui.offer.Visible = false
	showRound(false)
	round.active = false
	round.offer = nil
	cinematic(false)
	freezeCharacter(false)
	setBusy(false)
end

local function playAgain()
	local machine = round.machine
	ui.result.Visible = false
	if not machine then
		RoundController.close()
		return
	end
	-- wait for the machine to finish resetting, then ask for the offer again
	Theme.setButtonText(ui.again, "Resetting...")
	task.spawn(function()
		local started = os.clock()
		while machine.Parent and machine:GetAttribute("State") ~= "Idle" and os.clock() - started < 10 do
			task.wait(0.1)
		end
		Theme.setButtonText(ui.again, "Play again!")
		cinematic(false)
		freezeCharacter(false)
		setBusy(false)
		local prompt = machine:FindFirstChild("PromptAnchor") and machine.PromptAnchor:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			-- re-open the offer exactly like pressing E again
			Remotes.RoundAction:FireServer("Offer", machine)
		end
	end)
end

---------------------------------------------------------------------------
-- Server events
---------------------------------------------------------------------------

local function onRoundEvent(event: string, payload)
	if event == "Offer" then
		if round.active then
			return
		end
		showOffer(payload)
	elseif event == "Started" then
		ui.offer.Visible = false
		round.active = true
		round.machine = payload.machine
		round.kind = payload.kind
		round.endsAt = payload.endsAt
		round.startAt = payload.startAt
		round.pausedUntil = 0
		round.pauseTime = payload.pauseTime
		round.jewels = payload.jewels
		round.plateValue = payload.plateValue
		round.streak = 0
		local def = Machines.get(payload.kind)
		ui.cardHeader.BackgroundColor3 = def.themeColor
		ui.cardTitle.Text = def.op .. " " .. def.displayName .. "  •  Level " .. payload.level
		updateLoot()
		setStatus("Get ready...", C.InkSoft)
		showRound(true)
		setBusy(true)
		freezeCharacter(true)
		cinematic(true)
		ui.countdown.Text = "READY?"
		ui.countdown.Visible = true
		pop(ui.countdown)
		task.delay(math.max(0.2, payload.startAt - workspace:GetServerTimeNow() - 0.1), function()
			ui.countdown.Text = "GO!"
			pop(ui.countdown, 1.6)
			task.wait(0.6)
			ui.countdown.Visible = false
		end)
	elseif event == "Question" then
		if payload.machine ~= round.machine then
			return
		end
		round.qid = payload.qid
		round.typed = ""
		round.accepting = true
		ui.question.Text = payload.text .. " = "
		ui.answerBox.BackgroundColor3 = C.White
		refreshAnswer()
		pop(ui.question, 0.85)
	elseif event == "Answer" then
		round.jewels = payload.jewels
		updateLoot()
		if payload.correct then
			round.streak = payload.streak
			round.pausedUntil = payload.pausedUntil
			ui.answerBox.BackgroundColor3 = Color3.fromRGB(200, 255, 200)
			local text = "✅ Correct! Chain stopped!"
			if payload.bonus then
				text = "🔥 " .. payload.streak .. " in a row! Bonus loot!"
			elseif payload.streak >= 2 then
				text = "✅ Correct! " .. payload.streak .. " in a row!"
			end
			setStatus(text, C.GreenDark)
		else
			round.streak = 0
			ui.answerBox.BackgroundColor3 = Color3.fromRGB(255, 205, 205)
			ui.answer.Text = tostring(payload.answer)
			ui.answer.TextColor3 = C.RedDark
			setStatus("❌ " .. payload.explain, C.RedDark)
			shake(ui.card)
		end
		if payload.leveledUp then
			ui.levelUp.Visible = true
			pop(ui.levelUp, 0.4)
			controllers.SoundController.play("LevelUp", nil, 0.7)
			task.delay(3, function()
				ui.levelUp.Visible = false
			end)
		end
	elseif event == "End" then
		if payload.machine == round.machine then
			endRound(payload)
		end
	end
end

---------------------------------------------------------------------------
-- Building the UI
---------------------------------------------------------------------------

local function buildOffer()
	local offer = Theme.new("Frame", {
		Name = "Offer",
		Size = UDim2.fromOffset(600, 470),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Paper,
		Visible = false,
		Parent = gui,
		[Theme.Children] = { Theme.corner(24), Theme.stroke(C.Ink, 4) },
	})
	ui.offer = offer
	ui.offerHeader = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = C.Green,
		Parent = offer,
		[Theme.Children] = { Theme.corner(24) },
	})
	ui.offerTitle = Theme.text({
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.fromOffset(20, 10),
		TextColor3 = C.White,
		Parent = ui.offerHeader,
		[Theme.Children] = { Theme.textStroke(C.Ink, 3) },
	})
	Theme.text({
		Size = UDim2.new(1, -40, 0, 44),
		Position = UDim2.fromOffset(20, 84),
		Text = "Want to try to earn money? 💰",
		Parent = offer,
	})
	local row = Theme.new("Frame", {
		Size = UDim2.new(1, -40, 0, 56),
		Position = UDim2.fromOffset(20, 138),
		BackgroundColor3 = C.PaperDark,
		Parent = offer,
		[Theme.Children] = { Theme.corner(14) },
	})
	ui.offerPrev = Theme.button({ Text = "◀", Size = UDim2.fromOffset(56, 52), Color = C.Blue, Parent = row })
	ui.offerNext = Theme.button({
		Text = "▶",
		Size = UDim2.fromOffset(56, 52),
		Position = UDim2.new(1, -56, 0, 0),
		Color = C.Blue,
		Parent = row,
	})
	ui.offerLevel = Theme.text({
		Size = UDim2.new(1, -140, 0, 40),
		Position = UDim2.fromOffset(70, 8),
		Parent = row,
	})
	ui.offerPrev.Activated:Connect(function()
		round.offerLevel = math.max(1, round.offerLevel - 1)
		refreshOffer()
	end)
	ui.offerNext.Activated:Connect(function()
		round.offerLevel = math.min(#round.offer.levels, round.offerLevel + 1)
		refreshOffer()
	end)
	ui.offerPlate = Theme.text({
		Size = UDim2.new(1, -40, 0, 38),
		Position = UDim2.fromOffset(20, 202),
		TextColor3 = C.GreenDark,
		Parent = offer,
	})
	ui.offerNote = Theme.text({
		Size = UDim2.new(1, -40, 0, 20),
		Position = UDim2.fromOffset(20, 240),
		TextColor3 = C.InkSoft,
		FontFace = Theme.Body,
		Text = "Practice level: pays less and doesn't count towards levelling up",
		Parent = offer,
	})
	local xpBar = Theme.new("Frame", {
		Size = UDim2.new(1, -40, 0, 26),
		Position = UDim2.fromOffset(20, 266),
		BackgroundColor3 = C.PaperDark,
		Parent = offer,
		[Theme.Children] = { Theme.round(), Theme.stroke(C.Ink, 2) },
	})
	ui.offerXpFill = Theme.new("Frame", {
		Size = UDim2.fromScale(0.3, 1),
		BackgroundColor3 = C.Yellow,
		Parent = xpBar,
		[Theme.Children] = { Theme.round() },
	})
	ui.offerXp = Theme.text({
		Size = UDim2.new(1, -16, 0.8, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		FontFace = Theme.Body,
		ZIndex = 2,
		Parent = xpBar,
	})
	Theme.text({
		Size = UDim2.new(1, -40, 0, 72),
		Position = UDim2.fromOffset(20, 300),
		FontFace = Theme.Body,
		TextColor3 = C.InkSoft,
		TextScaled = false,
		TextSize = 19,
		TextWrapped = true,
		Text = "✅ Right answer = the chain STOPS\n❌ Wrong answer = loot falls in the acid\n⏱ Keep the plate out of the acid for 30 seconds to win it!",
		Parent = offer,
	})
	local yes = Theme.button({
		Name = "YesButton",
		Text = "YES! Let's go!",
		Size = UDim2.fromOffset(300, 72),
		Position = UDim2.new(0, 20, 1, -88),
		Color = C.Green,
		Parent = offer,
	})
	local no = Theme.button({
		Name = "NoButton",
		Text = "Not now",
		Size = UDim2.fromOffset(240, 72),
		Position = UDim2.new(1, -260, 1, -88),
		Color = C.Gray,
		Parent = offer,
	})
	yes.Activated:Connect(function()
		if round.offer then
			controllers.SoundController.play("Click")
			Remotes.RoundAction:FireServer("Start", round.offer.machine, round.offerLevel)
			ui.offer.Visible = false
		end
	end)
	no.Activated:Connect(function()
		controllers.SoundController.play("Click")
		closeOffer()
	end)
end

local function buildCard()
	local card = Theme.new("Frame", {
		Name = "QuestionCard",
		Size = UDim2.fromOffset(600, 270),
		Position = UDim2.new(0, 20, 0, 92),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = C.Paper,
		Visible = false,
		Parent = gui,
		[Theme.Children] = { Theme.corner(24), Theme.stroke(C.Ink, 4) },
	})
	ui.card = card
	ui.cardHeader = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = C.Green,
		Parent = card,
		[Theme.Children] = { Theme.corner(24) },
	})
	ui.cardTitle = Theme.text({
		Size = UDim2.new(1, -150, 0, 34),
		Position = UDim2.fromOffset(18, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.White,
		Parent = ui.cardHeader,
		[Theme.Children] = { Theme.textStroke(C.Ink, 2) },
	})
	ui.timerText = Theme.text({
		Size = UDim2.fromOffset(120, 34),
		Position = UDim2.new(1, -132, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.White,
		Text = "⏱ 30",
		Parent = ui.cardHeader,
		[Theme.Children] = { Theme.textStroke(C.Ink, 2) },
	})
	local timerBar = Theme.new("Frame", {
		Size = UDim2.new(1, -36, 0, 14),
		Position = UDim2.fromOffset(18, 54),
		BackgroundColor3 = C.PaperDark,
		Parent = card,
		[Theme.Children] = { Theme.round() },
	})
	ui.timerFill = Theme.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Blue,
		Parent = timerBar,
		[Theme.Children] = { Theme.round() },
	})
	ui.question = Theme.text({
		Size = UDim2.new(0.62, -20, 0, 96),
		Position = UDim2.fromOffset(18, 78),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "7 × 8 = ",
		Parent = card,
	})
	ui.answerBox = Theme.new("Frame", {
		Size = UDim2.new(0.3, 0, 0, 92),
		Position = UDim2.new(0.62, 0, 0, 80),
		BackgroundColor3 = C.White,
		Parent = card,
		[Theme.Children] = { Theme.corner(18), Theme.stroke(C.Ink, 3) },
	})
	ui.answer = Theme.text({
		Size = UDim2.new(1, -16, 0.86, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = "?",
		Parent = ui.answerBox,
	})
	ui.status = Theme.text({
		Size = UDim2.new(1, -110, 0, 34),
		Position = UDim2.fromOffset(18, 184),
		FontFace = Theme.Body,
		Text = "",
		Parent = card,
	})
	ui.loot = Theme.text({
		Size = UDim2.new(1, -110, 0, 34),
		Position = UDim2.fromOffset(18, 222),
		TextColor3 = C.GreenDark,
		Text = "",
		Parent = card,
	})
	-- acid meter: how close the plate is to the acid
	local meter = Theme.new("Frame", {
		Size = UDim2.fromOffset(46, 92),
		Position = UDim2.new(1, -66, 0, 172),
		BackgroundColor3 = Color3.fromRGB(220, 236, 255),
		Parent = card,
		[Theme.Children] = { Theme.corner(10), Theme.stroke(C.Ink, 2) },
	})
	Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -18),
		BackgroundColor3 = Color3.fromRGB(130, 236, 60),
		Parent = meter,
		[Theme.Children] = { Theme.corner(10) },
	})
	ui.meterPlate = Theme.text({
		Size = UDim2.fromOffset(40, 26),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 12),
		Text = "🍽️",
		Parent = meter,
	})
	local quit = Theme.button({
		Text = "X",
		Size = UDim2.fromOffset(52, 48),
		Position = UDim2.new(1, 12, 0, 0),
		AnchorPoint = Vector2.new(0, 0),
		Color = C.Red,
		Parent = card,
	})
	quit.Activated:Connect(function()
		if round.active then
			Remotes.RoundAction:FireServer("Quit", round.machine)
		end
	end)

	ui.countdown = Theme.text({
		Size = UDim2.fromOffset(500, 140),
		Position = UDim2.new(0, 610, 0, 300),
		AnchorPoint = Vector2.new(0, 0.5),
		Text = "GO!",
		TextColor3 = C.Yellow,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
		[Theme.Children] = { Theme.textStroke(C.Ink, 5) },
	})
	ui.levelUp = Theme.new("Frame", {
		Size = UDim2.fromOffset(520, 90),
		Position = UDim2.new(0, 360, 1, -110),
		AnchorPoint = Vector2.new(0, 0),
		BackgroundColor3 = C.Yellow,
		Visible = false,
		ZIndex = 8,
		Parent = gui,
		[Theme.Children] = {
			Theme.corner(20),
			Theme.stroke(C.Ink, 4),
			Theme.text({
				Size = UDim2.new(1, -30, 0.7, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Text = "⭐ LEVEL UP! Harder maths = bigger plates! ⭐",
				ZIndex = 9,
			}),
		},
	})
end

local function buildPad()
	local pad = Theme.new("Frame", {
		Name = "NumberPad",
		Size = UDim2.fromOffset(330, 340),
		Position = UDim2.new(0, 20, 1, -16),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = gui,
		[Theme.Children] = {
			Theme.corner(22),
			Theme.padding(10),
			Theme.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(98, 72),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
		},
	})
	ui.pad = pad
	local keys = { "7", "8", "9", "4", "5", "6", "1", "2", "3", "⬅️", "0", "✓" }
	for i, key in keys do
		local color = if key == "✓" then C.Green elseif key == "⬅️" then C.Orange else C.Blue
		local button = Theme.button({ Text = key, Size = UDim2.fromOffset(98, 72), Color = color, LayoutOrder = i, Parent = pad })
		button.Activated:Connect(function()
			if key == "✓" then
				submit()
			elseif key == "⬅️" then
				backspace()
			else
				typeDigit(key)
			end
		end)
	end
end

local function buildResult()
	local result = Theme.new("Frame", {
		Name = "Result",
		Size = UDim2.fromOffset(600, 300),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Paper,
		Visible = false,
		Parent = gui,
		[Theme.Children] = { Theme.corner(24), Theme.stroke(C.Ink, 4) },
	})
	ui.result = result
	ui.resultTitle = Theme.text({
		Size = UDim2.new(1, -40, 0, 80),
		Position = UDim2.fromOffset(20, 24),
		Parent = result,
		[Theme.Children] = { Theme.textStroke(C.Ink, 3) },
	})
	ui.resultSub = Theme.text({
		Size = UDim2.new(1, -40, 0, 60),
		Position = UDim2.fromOffset(20, 112),
		FontFace = Theme.Body,
		TextColor3 = C.InkSoft,
		TextWrapped = true,
		Parent = result,
	})
	ui.again = Theme.button({
		Name = "AgainButton",
		Text = "Play again!",
		Size = UDim2.fromOffset(280, 72),
		Position = UDim2.new(0, 20, 1, -92),
		Color = C.Green,
		Parent = result,
	})
	local done = Theme.button({
		Name = "DoneButton",
		Text = "Done",
		Size = UDim2.fromOffset(240, 72),
		Position = UDim2.new(1, -260, 1, -92),
		Color = C.Blue,
		Parent = result,
	})
	ui.again.Activated:Connect(playAgain)
	done.Activated:Connect(function()
		RoundController.close()
	end)
end

---------------------------------------------------------------------------

function RoundController:Start(all)
	controllers = all
	gui = Theme.screen("Round", 10)
	buildOffer()
	buildCard()
	buildPad()
	buildResult()

	Remotes.RoundEvent.OnClientEvent:Connect(onRoundEvent)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not round.active or processed then
			return
		end
		local code = input.KeyCode
		local digit = string.match(code.Name, "^Keypad(%a+)$") or code.Name
		local map = { Zero = "0", One = "1", Two = "2", Three = "3", Four = "4", Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9" }
		if map[digit] then
			typeDigit(map[digit])
		elseif code == Enum.KeyCode.Backspace then
			backspace()
		elseif code == Enum.KeyCode.Return or code == Enum.KeyCode.KeypadEnter then
			submit()
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not round.active then
			return
		end
		local t = workspace:GetServerTimeNow()
		local left = math.max(0, round.endsAt - t)
		ui.timerText.Text = "⏱ " .. math.ceil(left)
		ui.timerFill.Size = UDim2.fromScale(math.clamp(left / Economy.RoundSeconds, 0, 1), 1)
		ui.timerFill.BackgroundColor3 = if left < 6 then C.Green else C.Blue
		local machine = round.machine
		if machine then
			local base = machine:GetAttribute("DropBase") or 0
			local start = machine:GetAttribute("DropStart") or 0
			local rate = machine:GetAttribute("DropRate") or 0
			local paused = machine:GetAttribute("PausedUntil") or 0
			local progress = if t < paused then base else base + rate * math.max(0, t - math.max(start, paused))
			progress = math.clamp(progress, 0, 1)
			ui.meterPlate.Position = UDim2.new(0.5, 0, 0, 12 + progress * 52)
			if t < paused and round.accepting and os.clock() > (round.statusUntil or 0) then
				ui.status.Text = string.format("⏸ Chain stopped! %.1fs", paused - t)
				ui.status.TextColor3 = C.GreenDark
			end
		end
	end)

end

return RoundController
