--[[
	Cracking a Frog Plane safe: the combination screen (three number slots, the
	current problem and the number pad) and the prize screen when it pops open.
	The server sends every problem and checks every answer (FrogPlaneService);
	each right answer is one number of the safe's combination.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)
local NumberPad = require(script.Parent.Parent.UI.NumberPad)
local Theme = require(script.Parent.Parent.UI.Theme)

local SafeController = {}
local controllers
local C = Theme.Colors
local player = Players.LocalPlayer

local gui: ScreenGui
local ui: { [string]: any } = {}
local state = {
	safe = nil :: Model?,
	qid = 0,
	typed = "",
	accepting = false,
	busy = false,
	savedMove = nil :: { number }?,
	spinning = nil :: { center: Vector3, distance: number }?,
}

local CLOSED_MESSAGES = {
	walked = "You walked away from the safe. Come back to try again!",
	idle = "The safe locked itself again. Come back and try!",
	gone = "That safe vanished! Watch for the next Frog Plane.",
}

function SafeController.isBusy(): boolean
	return state.busy
end

local function setBusy(busy: boolean)
	if state.busy == busy then
		return
	end
	state.busy = busy
	controllers.HudController.setSideVisible(not busy)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, not busy)
	end)
	-- the number pad replaces the thumbstick/jump buttons while cracking
	GuiService.TouchControlsEnabled = not busy
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if busy then
		state.savedMove = { humanoid.WalkSpeed, humanoid.JumpHeight }
		humanoid.WalkSpeed = 0
		humanoid.JumpHeight = 0
	elseif state.savedMove then
		humanoid.WalkSpeed = state.savedMove[1]
		humanoid.JumpHeight = state.savedMove[2]
		state.savedMove = nil
	end
end

local function pop(inst: GuiObject, to: number?)
	local scale = inst:FindFirstChildOfClass("UIScale") or Theme.new("UIScale", { Parent = inst })
	scale.Scale = 0.7 * (to or 1)
	Theme.tween(scale, 0.35, { Scale = to or 1 }, Enum.EasingStyle.Back)
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

local function setStatus(text: string, color: Color3)
	ui.status.Text = text
	ui.status.TextColor3 = color
end

local function refreshAnswer()
	ui.answer.Text = if state.typed == "" then "?" else state.typed
	ui.answer.TextColor3 = if state.typed == "" then C.Gray else C.Ink
	ui.answerBox.BackgroundColor3 = C.White
end

local function setQuestion(text: string)
	state.typed = ""
	ui.question.Text = text .. " ="
	refreshAnswer()
	ui.question.Visible = true
end

---------------------------------------------------------------------------
-- The three combination slots
---------------------------------------------------------------------------

local function highlightSlot(slot: number)
	for i, s in ui.slots do
		local current = i == slot and not s.solved
		s.stroke.Color = if current then C.Yellow else C.Ink
		s.stroke.Thickness = if current then 6 else 3
	end
end

local function resetSlots(count: number)
	for i, s in ui.slots do
		s.frame.Visible = i <= count
		s.solved = false
		s.frame.BackgroundColor3 = C.Ink
		s.label.Text = "?"
		s.label.TextColor3 = C.Gray
	end
	highlightSlot(1)
end

local function revealSlot(slot: number, value: number)
	local s = ui.slots[slot]
	if not s then
		return
	end
	s.solved = true
	s.frame.BackgroundColor3 = C.GreenDark
	s.label.Text = tostring(value)
	s.label.TextColor3 = C.White
	pop(s.frame)
	highlightSlot(slot + 1)
end

---------------------------------------------------------------------------
-- Answering
---------------------------------------------------------------------------

local function typeDigit(d: string)
	if state.accepting and #state.typed < 5 then
		state.typed ..= d
		refreshAnswer()
		controllers.SoundController.play("Tick", nil, 0.3, 1.2)
	end
end

local function backspace()
	if state.accepting and #state.typed > 0 then
		state.typed = string.sub(state.typed, 1, -2)
		refreshAnswer()
	end
end

local function submit()
	if not state.accepting or state.typed == "" or not state.safe then
		return
	end
	state.accepting = false
	Remotes.SafeAction:FireServer("Answer", state.safe, state.qid, tonumber(state.typed))
	controllers.SoundController.play("Click", nil, 0.4)
end

local function onPadKey(key: string)
	if key == "enter" then
		submit()
	elseif key == "back" then
		backspace()
	else
		typeDigit(key)
	end
end

local function openPanel(payload)
	state.safe = payload.safe
	state.qid = payload.qid
	state.accepting = true
	resetSlots(payload.count)
	setQuestion(payload.question)
	setStatus("Every right answer is one number of the safe's combination!", C.InkSoft)
	ui.panel.Visible = true
	pop(ui.panel, Theme.fitBelowTopbar(ui.panel, gui, 0.5))
	setBusy(true)
end

local function closePanel()
	ui.panel.Visible = false
	state.safe = nil
	state.accepting = false
end

---------------------------------------------------------------------------
-- The prize
---------------------------------------------------------------------------

local function itemModel(item): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local group = assets and assets:FindFirstChild(item.assetFolder or "")
	local source = group and group:FindFirstChild(item.model)
	return if source then source:Clone() :: Model else nil
end

local function itemHint(item): string
	if Catalog.isPlaceable(item) then
		return "Put it in your garden: it's in 🎒 My Stuff!"
	elseif item.kind == "Pet" then
		return "It's following you around! Find it in 🎒 My Stuff."
	end
	return "You're wearing it! Find it in 🎒 My Stuff."
end

local function showPrize(payload)
	local item = if payload.item then Catalog.get(payload.item) else nil
	local combo = {}
	for _, n in payload.combination or {} do
		table.insert(combo, tostring(n))
	end
	ui.prizeCombo.Text = "The combination was " .. table.concat(combo, " – ")
	ui.prizeMoney.Text = "+" .. Format.money(payload.money) .. " 💰"
	for _, child in ui.prizeView:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
	state.spinning = nil
	ui.prizeItem.Visible = item ~= nil
	ui.prizeNothing.Visible = item == nil
	if item then
		ui.prizeItemName.Text = "NEW! " .. item.name
		ui.prizeItemHint.Text = itemHint(item)
		local model = itemModel(item)
		if model then
			model.Parent = ui.prizeView
			local cf, size = model:GetBoundingBox()
			state.spinning = { center = cf.Position, distance = math.max(size.X, size.Y, size.Z) * 1.7 + 1 }
		end
	end
	ui.prize.Visible = true
	pop(ui.prize, Theme.fitBelowTopbar(ui.prize, gui, 0.5))
	controllers.HudController.hold(1.2)
	task.delay(0.8, function()
		controllers.HudController.celebrate(payload.money)
		controllers.SoundController.play("Cash", nil, 0.7)
	end)
end

local function closePrize()
	ui.prize.Visible = false
	state.spinning = nil
	setBusy(false)
end

---------------------------------------------------------------------------
-- Server events
---------------------------------------------------------------------------

local function onSafeEvent(event: string, payload)
	if event == "Open" then
		openPanel(payload)
		return
	end
	if not state.safe or payload.safe ~= state.safe then
		return
	end
	if event == "Correct" then
		revealSlot(payload.slot, payload.value)
		controllers.FrogPlaneController.spinDial(state.safe)
		controllers.SoundController.play("Coins", nil, 0.5)
		state.qid = payload.qid
		if payload.done then
			state.accepting = false
			setStatus("✅ Click! Click! CLICK! It's opening...", C.GreenDark)
		else
			setQuestion(payload.question)
			setStatus(string.format("✅ Click! Number %d is %d. Keep going!", payload.slot, payload.value), C.GreenDark)
			state.accepting = true
		end
	elseif event == "Wrong" then
		state.accepting = false
		state.qid = payload.qid
		ui.answer.Text = tostring(payload.answer)
		ui.answer.TextColor3 = C.RedDark
		ui.answerBox.BackgroundColor3 = Color3.fromRGB(255, 205, 205)
		setStatus("❌ " .. payload.explain, C.RedDark)
		shake(ui.panel)
		controllers.SoundController.play("Grind", nil, 0.4)
		local safe, qid = state.safe, payload.qid
		task.delay(payload.delay or 1.5, function()
			if state.safe == safe and state.qid == qid then
				setQuestion(payload.question)
				setStatus("The dial jammed! Here's a new one:", C.InkSoft)
				state.accepting = true
			end
		end)
	elseif event == "Cracked" then
		closePanel()
		showPrize(payload)
	elseif event == "Closed" then
		closePanel()
		setBusy(false)
		local message = CLOSED_MESSAGES[payload.reason]
		if message then
			controllers.NotifyController.show(message, "info", 3)
		end
	end
end

---------------------------------------------------------------------------
-- Building the UI
---------------------------------------------------------------------------

local function buildPanel()
	local panel = Theme.new("Frame", {
		Name = "SafePanel",
		Size = UDim2.fromOffset(880, 450),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Paper,
		Visible = false,
		Parent = gui,
		[Theme.Children] = { Theme.corner(26), Theme.stroke(C.Ink, 4) },
	})
	ui.panel = panel
	local header = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundColor3 = C.Green,
		Parent = panel,
		[Theme.Children] = { Theme.corner(26) },
	})
	Theme.text({
		Size = UDim2.new(1, -120, 0, 46),
		Position = UDim2.fromOffset(22, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.White,
		Text = "🐸 Crack the Frog Safe!",
		Parent = header,
		[Theme.Children] = { Theme.textStroke(C.Ink, 3) },
	})
	local quit = Theme.button({
		Name = "QuitButton",
		Text = "X",
		Size = UDim2.fromOffset(54, 50),
		Position = UDim2.new(1, -66, 0, 8),
		Color = C.Red,
		Parent = header,
	})
	quit.Activated:Connect(function()
		if state.safe then
			Remotes.SafeAction:FireServer("Quit", state.safe)
			closePanel()
			setBusy(false)
		end
	end)

	Theme.text({
		Size = UDim2.fromOffset(482, 24),
		Position = UDim2.fromOffset(24, 80),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Body,
		TextColor3 = C.InkSoft,
		Text = "THE COMBINATION",
		Parent = panel,
	})
	ui.slots = {}
	for i = 1, 3 do
		local x = 24 + (i - 1) * 168
		local stroke = Theme.stroke(C.Ink, 3)
		local frame = Theme.new("Frame", {
			Name = "Slot" .. i,
			Size = UDim2.fromOffset(136, 104),
			Position = UDim2.fromOffset(x, 110),
			BackgroundColor3 = C.Ink,
			Parent = panel,
			[Theme.Children] = { Theme.corner(18), stroke },
		})
		local label = Theme.text({
			Size = UDim2.new(1, -16, 0.8, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = "?",
			TextColor3 = C.Gray,
			Parent = frame,
		})
		ui.slots[i] = { frame = frame, label = label, stroke = stroke, solved = false }
		if i < 3 then
			Theme.text({
				Size = UDim2.fromOffset(32, 60),
				Position = UDim2.fromOffset(x + 136, 132),
				Text = "–",
				TextColor3 = C.InkSoft,
				Parent = panel,
			})
		end
	end

	ui.question = Theme.text({
		Size = UDim2.fromOffset(300, 86),
		Position = UDim2.fromOffset(24, 232),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "7 × 8 =",
		Parent = panel,
	})
	ui.answerBox = Theme.new("Frame", {
		Size = UDim2.fromOffset(170, 86),
		Position = UDim2.fromOffset(336, 232),
		BackgroundColor3 = C.White,
		Parent = panel,
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
		Size = UDim2.fromOffset(482, 70),
		Position = UDim2.fromOffset(24, 340),
		FontFace = Theme.Body,
		TextWrapped = true,
		Text = "",
		Parent = panel,
	})
	NumberPad.new({ Position = UDim2.fromOffset(530, 88), Parent = panel }, onPadKey)
end

local function buildPrize()
	local prize = Theme.new("Frame", {
		Name = "SafePrize",
		Size = UDim2.fromOffset(620, 430),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Paper,
		Visible = false,
		Parent = gui,
		[Theme.Children] = { Theme.corner(26), Theme.stroke(C.Ink, 4) },
	})
	ui.prize = prize
	Theme.text({
		Size = UDim2.new(1, -40, 0, 70),
		Position = UDim2.fromOffset(20, 18),
		Text = "🎉 SAFE CRACKED! 🎉",
		TextColor3 = C.Green,
		Parent = prize,
		[Theme.Children] = { Theme.textStroke(C.Ink, 3) },
	})
	ui.prizeCombo = Theme.text({
		Size = UDim2.new(1, -40, 0, 28),
		Position = UDim2.fromOffset(20, 92),
		FontFace = Theme.Body,
		TextColor3 = C.InkSoft,
		Parent = prize,
	})
	ui.prizeMoney = Theme.text({
		Size = UDim2.new(1, -40, 0, 62),
		Position = UDim2.fromOffset(20, 124),
		TextColor3 = C.GreenDark,
		Parent = prize,
	})
	ui.prizeItem = Theme.new("Frame", {
		Size = UDim2.new(1, -60, 0, 124),
		Position = UDim2.fromOffset(30, 196),
		BackgroundColor3 = C.White,
		Parent = prize,
		[Theme.Children] = { Theme.corner(18), Theme.stroke(C.Yellow, 4) },
	})
	ui.prizeView = Theme.new("ViewportFrame", {
		Size = UDim2.fromOffset(108, 108),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.fromRGB(226, 242, 255),
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1.5, -1),
		Parent = ui.prizeItem,
		[Theme.Children] = { Theme.corner(14) },
	})
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = ui.prizeView
	ui.prizeView.CurrentCamera = camera
	ui.prizeCamera = camera
	ui.prizeItemName = Theme.text({
		Size = UDim2.new(1, -140, 0, 46),
		Position = UDim2.fromOffset(128, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.PurpleDark,
		Parent = ui.prizeItem,
	})
	ui.prizeItemHint = Theme.text({
		Size = UDim2.new(1, -140, 0, 48),
		Position = UDim2.fromOffset(128, 62),
		TextXAlignment = Enum.TextXAlignment.Left,
		FontFace = Theme.Body,
		TextColor3 = C.InkSoft,
		TextWrapped = true,
		Parent = ui.prizeItem,
	})
	ui.prizeNothing = Theme.text({
		Size = UDim2.new(1, -60, 0, 64),
		Position = UDim2.fromOffset(30, 224),
		FontFace = Theme.Body,
		TextColor3 = C.InkSoft,
		TextWrapped = true,
		Text = "No surprise inside this time. Keep cracking safes to find exclusive prizes! 🐸",
		Parent = prize,
	})
	local ok = Theme.button({
		Name = "AwesomeButton",
		Text = "Awesome!",
		Size = UDim2.fromOffset(260, 72),
		Position = UDim2.new(0.5, 0, 1, -92),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = C.Green,
		Parent = prize,
	})
	ok.Activated:Connect(function()
		controllers.SoundController.play("Click")
		closePrize()
	end)
end

function SafeController:Start(all)
	controllers = all
	gui = Theme.screen("Safe", 13)
	buildPanel()
	buildPrize()

	Remotes.SafeEvent.OnClientEvent:Connect(onSafeEvent)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not state.safe then
			return
		end
		local key = NumberPad.fromKeyCode(input.KeyCode)
		if key then
			onPadKey(key)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local spin = state.spinning
		if spin and ui.prize.Visible then
			local offset = CFrame.Angles(0, os.clock() * 0.9, 0) * Vector3.new(0, spin.distance * 0.25, spin.distance)
			ui.prizeCamera.CFrame = CFrame.lookAt(spin.center + offset, spin.center)
		end
	end)
end

return SafeController
