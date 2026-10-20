--[[
	Toast messages that slide in under the money counter.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local Theme = require(script.Parent.Parent.UI.Theme)

local NotifyController = {}

local STYLES = {
	success = Theme.Colors.Green,
	info = Theme.Colors.Blue,
	error = Theme.Colors.Red,
	money = Theme.Colors.Yellow,
}

local holder: Frame

function NotifyController.show(text: string, style: string?, seconds: number?)
	if not holder then
		return
	end
	local color = STYLES[style or "info"] or Theme.Colors.Blue
	local toast = Theme.new("Frame", {
		Size = UDim2.fromOffset(560, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Paper,
		BackgroundTransparency = 0,
		Parent = holder,
		[Theme.Children] = {
			Theme.corner(14),
			Theme.stroke(color:Lerp(Theme.Colors.Ink, 0.35), 3),
			Theme.padding(10),
			Theme.new("Frame", {
				Size = UDim2.new(0, 10, 1, 0),
				BackgroundColor3 = color,
				[Theme.Children] = { Theme.round() },
			}),
			Theme.text({
				Size = UDim2.new(1, -22, 0, 0),
				Position = UDim2.fromOffset(20, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextScaled = false,
				TextSize = 22,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = text,
			}),
		},
	})
	local scale = Theme.new("UIScale", { Scale = 0.6, Parent = toast })
	Theme.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(seconds or 4, function()
		Theme.tween(scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.22)
		toast:Destroy()
	end)
end

function NotifyController:Start()
	local gui = Theme.screen("Toasts", 20)
	holder = Theme.new("Frame", {
		Name = "Holder",
		Size = UDim2.fromOffset(560, 400),
		Position = UDim2.new(0.5, 0, 0, 96),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = gui,
		[Theme.Children] = {
			Theme.new("UIListLayout", {
				Padding = UDim.new(0, 8),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		},
	})
	Remotes.Notify.OnClientEvent:Connect(function(text, style)
		NotifyController.show(text, style)
	end)
end

return NotifyController
