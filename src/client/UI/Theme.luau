--[[
	Tiny UI kit: colors, fonts and helpers for building bubbly, kid-friendly UI
	in code (no binary UI files to merge).

	Theme.new("Frame", { Size = ..., [Theme.Children] = {...} })
]]

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Font = Font.fromEnum(Enum.Font.FredokaOne)
Theme.Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

Theme.Colors = {
	Ink = Color3.fromRGB(46, 36, 72),
	InkSoft = Color3.fromRGB(96, 84, 126),
	Paper = Color3.fromRGB(255, 249, 236),
	PaperDark = Color3.fromRGB(244, 232, 206),
	White = Color3.fromRGB(255, 255, 255),
	Green = Color3.fromRGB(76, 204, 98),
	GreenDark = Color3.fromRGB(42, 150, 66),
	Red = Color3.fromRGB(244, 84, 84),
	RedDark = Color3.fromRGB(184, 46, 56),
	Yellow = Color3.fromRGB(255, 206, 64),
	YellowDark = Color3.fromRGB(214, 150, 22),
	Blue = Color3.fromRGB(80, 164, 255),
	BlueDark = Color3.fromRGB(44, 108, 204),
	Purple = Color3.fromRGB(170, 104, 240),
	PurpleDark = Color3.fromRGB(118, 62, 186),
	Orange = Color3.fromRGB(255, 152, 56),
	Gray = Color3.fromRGB(170, 166, 184),
	GrayDark = Color3.fromRGB(118, 112, 136),
}

Theme.Children = newproxy(false) -- key for child lists in Theme.new props

function Theme.new(className: string, props: { [any]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local kids = children
	if props then
		for key, value in props do
			if key == Theme.Children then
				kids = value
			elseif key ~= "Parent" then
				(inst :: any)[key] = value
			end
		end
	end
	if inst:IsA("GuiObject") and not (props and props.BorderSizePixel) then
		(inst :: any).BorderSizePixel = 0
	end
	if kids then
		for _, child in kids do
			child.Parent = inst
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Theme.corner(radius: number?): UICorner
	return Theme.new("UICorner", { CornerRadius = UDim.new(0, radius or 14) })
end

function Theme.round(): UICorner
	return Theme.new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function Theme.stroke(color: Color3?, thickness: number?): UIStroke
	return Theme.new("UIStroke", {
		Color = color or Theme.Colors.Ink,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.textStroke(color: Color3?, thickness: number?): UIStroke
	return Theme.new("UIStroke", {
		Color = color or Theme.Colors.Ink,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Theme.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return Theme.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Theme.gradient(top: Color3, bottom: Color3): UIGradient
	return Theme.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
	})
end

function Theme.text(props: { [any]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextColor3 = Theme.Colors.Ink,
		TextScaled = true,
	}
	for k, v in props do
		defaults[k] = v
	end
	return Theme.new("TextLabel", defaults)
end

function Theme.tween(inst: Instance, time: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goals
	)
	tween:Play()
	return tween
end

--- Chunky cartoon button. ``color`` is the face, the darker shade is the "3D" lip.
function Theme.button(props: {
	Text: string,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Shade: Color3?,
	TextColor: Color3?,
	LayoutOrder: number?,
	Name: string?,
	Parent: Instance?,
}): TextButton
	local color = props.Color or Theme.Colors.Green
	local shade = props.Shade or color:Lerp(Color3.new(0, 0, 0), 0.3)
	local button = Theme.new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = shade,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.LayoutOrder or 0,
		[Theme.Children] = { Theme.corner(16) },
	})
	local face = Theme.new("Frame", {
		Name = "Face",
		Size = UDim2.new(1, 0, 1, -6),
		BackgroundColor3 = color,
		[Theme.Children] = {
			Theme.corner(16),
			Theme.stroke(Theme.Colors.Ink, 3),
			Theme.text({
				Name = "Label",
				Size = UDim2.new(1, -16, 0.72, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Text = props.Text,
				TextColor3 = props.TextColor or Theme.Colors.White,
				[Theme.Children] = { Theme.textStroke(Theme.Colors.Ink, 2) },
			}),
		},
	})
	face.Parent = button
	local function press(down: boolean)
		face.Position = if down then UDim2.fromOffset(0, 4) else UDim2.new()
	end
	button.MouseButton1Down:Connect(function()
		press(true)
	end)
	button.MouseButton1Up:Connect(function()
		press(false)
	end)
	button.MouseLeave:Connect(function()
		press(false)
	end)
	button.MouseEnter:Connect(function()
		Theme.tween(face, 0.12, { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.15) })
	end)
	button.MouseLeave:Connect(function()
		Theme.tween(face, 0.12, { BackgroundColor3 = color })
	end)
	if props.Parent then
		button.Parent = props.Parent
	end
	return button
end

function Theme.setButtonText(button: TextButton, text: string)
	local face = button:FindFirstChild("Face")
	local label = face and face:FindFirstChild("Label")
	if label then
		(label :: TextLabel).Text = text
	end
end

function Theme.setButtonColor(button: TextButton, color: Color3)
	local face = button:FindFirstChild("Face") :: Frame?
	if face then
		face.BackgroundColor3 = color
	end
	button.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.3)
end

--- True on phones and tablets (a touchscreen and no keyboard): use "tap" instead
--- of "click" / "press E" in hints.
function Theme.isTouch(): boolean
	local UserInputService = game:GetService("UserInputService")
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

--- Phones shrink the 1280x720 design to about half size; small print needs help there.
function Theme.isSmall(gui: ScreenGui): boolean
	local scale = gui:FindFirstChildOfClass("UIScale")
	return scale ~= nil and scale.Scale < 0.75
end

--- Keep a centered panel clear of Roblox's top bar (menu / chat buttons) on short
--- phone screens: moves it down and returns the scale (<= 1) it needs to still fit.
--- Where there's room it stays at its designed spot (``centerY``).
function Theme.fitBelowTopbar(panel: GuiObject, gui: ScreenGui, centerY: number): number
	local base = gui:FindFirstChildOfClass("UIScale")
	local s = if base then base.Scale else 1
	local height = gui.AbsoluteSize.Y / s
	local top = game:GetService("GuiService"):GetGuiInset().Y / s + 6
	local panelHeight = panel.Size.Y.Offset
	if centerY * height - panelHeight / 2 >= top then
		panel.Position = UDim2.fromScale(0.5, centerY)
		return 1
	end
	local fit = math.min(1, (height - top - 10) / panelHeight)
	panel.Position = UDim2.new(0.5, 0, 0, top + panelHeight * fit / 2)
	return fit
end

--- A full-screen ScreenGui with a UIScale that keeps a 1280x720 design readable
--- on phones and big monitors alike.
function Theme.screen(name: string, displayOrder: number?): ScreenGui
	local player = game:GetService("Players").LocalPlayer
	local gui = Theme.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
	})
	local scale = Theme.new("UIScale", { Parent = gui })
	local camera = workspace.CurrentCamera
	local function update()
		local size = camera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.35)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

return Theme
