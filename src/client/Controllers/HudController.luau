--[[
	Always-on HUD: the money counter (with a rolling count-up), the Home / Shop /
	My Stuff / Report Card buttons and a hint banner until the player owns a plot.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)
local Theme = require(script.Parent.Parent.UI.Theme)

local HudController = {}
local controllers

local player = Players.LocalPlayer
local moneyLabel: TextLabel
local moneyPill: Frame
local hint: Frame
local shown = 0
local target = 0
local holdUntil = 0

--- Delay the counter (e.g. while loot is flying toward the player).
function HudController.hold(seconds: number)
	holdUntil = os.clock() + seconds
end

--- Little bounce + "+$X" floating text on the money pill.
function HudController.celebrate(amount: number)
	local pop = Theme.text({
		Size = UDim2.fromOffset(220, 46),
		Position = UDim2.new(0.5, 0, 1, 4),
		AnchorPoint = Vector2.new(0.5, 0),
		Text = "+" .. Format.money(amount),
		TextColor3 = Theme.Colors.Yellow,
		ZIndex = 5,
		Parent = moneyPill,
		[Theme.Children] = { Theme.textStroke(Theme.Colors.Ink, 3) },
	})
	Theme.tween(pop, 1.2, { Position = UDim2.new(0.5, 0, 1, 50), TextTransparency = 1 })
	task.delay(1.25, function()
		pop:Destroy()
	end)
	local scale = moneyPill:FindFirstChildOfClass("UIScale") or Theme.new("UIScale", { Parent = moneyPill })
	scale.Scale = 1.18
	Theme.tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Elastic)
end

local sideButtons: Frame

--- Hide the Home/Shop/Report column (e.g. while answering questions).
function HudController.setSideVisible(visible: boolean)
	if sideButtons then
		sideButtons.Visible = visible
	end
end

--- Screen position of the money counter (for coins flying into it).
function HudController.moneyTarget(): Vector2
	return moneyPill.AbsolutePosition + moneyPill.AbsoluteSize / 2
end

local function sideButton(parent: Instance, name: string, text: string, color: Color3, order: number, onClick: () -> ())
	local button = Theme.button({
		Name = name,
		Text = text,
		Size = UDim2.fromOffset(150, 62),
		Color = color,
		LayoutOrder = order,
		Parent = parent,
	})
	button.Activated:Connect(function()
		controllers.SoundController.play("Click")
		onClick()
	end)
	return button
end

function HudController:Start(all)
	controllers = all
	local gui = Theme.screen("Hud", 5)

	moneyPill = Theme.new("Frame", {
		Name = "Money",
		Size = UDim2.fromOffset(270, 66),
		Position = UDim2.new(0.5, 0, 0, 14),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Colors.Paper,
		Parent = gui,
		[Theme.Children] = {
			Theme.round(),
			Theme.stroke(Theme.Colors.Ink, 4),
			Theme.text({
				Size = UDim2.fromOffset(56, 56),
				Position = UDim2.fromOffset(8, 5),
				Text = "💰",
			}),
		},
	})
	moneyLabel = Theme.text({
		Name = "Amount",
		Size = UDim2.new(1, -80, 0.74, 0),
		Position = UDim2.new(0, 68, 0.13, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "$0",
		TextColor3 = Theme.Colors.GreenDark,
		Parent = moneyPill,
	})

	local column = Theme.new("Frame", {
		Name = "Buttons",
		Size = UDim2.fromOffset(150, 300),
		Position = UDim2.new(0, 16, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Parent = gui,
		[Theme.Children] = {
			Theme.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		},
	})
	sideButtons = column
	sideButton(column, "HomeButton", "🏠 Home", Theme.Colors.Green, 1, function()
		Remotes.PlayerAction:FireServer("Home")
	end)
	sideButton(column, "ShopButton", "🛒 Shop", Theme.Colors.Orange, 2, function()
		Remotes.PlayerAction:FireServer("Shop")
		task.delay(0.35, controllers.ShopController.open)
	end)
	sideButton(column, "StuffButton", "🎒 My Stuff", Theme.Colors.Purple, 3, function()
		controllers.ShopController.open("wardrobe")
	end)
	sideButton(column, "ReportButton", "📒 Report", Theme.Colors.Blue, 4, function()
		controllers.ReportController.toggle()
	end)

	hint = Theme.new("Frame", {
		Name = "PlotHint",
		Size = UDim2.fromOffset(640, 58),
		Position = UDim2.new(0.5, 0, 0, 92),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Colors.Yellow,
		Visible = false,
		Parent = gui,
		[Theme.Children] = {
			Theme.corner(16),
			Theme.stroke(Theme.Colors.Ink, 3),
			Theme.text({
				Size = UDim2.new(1, -24, 0.7, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Text = "👉 Find a FREE PLOT sign and press E — or tap 🏠 Home!",
			}),
		},
	})
	local function refreshHint()
		hint.Visible = (player:GetAttribute("PlotIndex") or 0) == 0
	end
	player:GetAttributeChangedSignal("PlotIndex"):Connect(refreshHint)
	refreshHint()

	controllers.ClientData.Changed:Connect(function(profile)
		target = profile.money
	end)
	RunService.RenderStepped:Connect(function(dt)
		if os.clock() < holdUntil or shown == target then
			return
		end
		local diff = target - shown
		local step = math.max(1, math.abs(diff) * math.min(1, dt * 6))
		if math.abs(diff) <= step then
			shown = target
		else
			shown += math.sign(diff) * step
		end
		moneyLabel.Text = Format.money(math.floor(shown + 0.5))
	end)
end

return HudController
