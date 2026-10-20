--[[
	Ribbit's Emporium: the shop UI. Opens from the frog merchant's prompt (or the
	HUD Shop button). Item cards show a slowly spinning 3D preview of the real
	model in a ViewportFrame.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)
local Theme = require(script.Parent.Parent.UI.Theme)

local ShopController = {}
local controllers
local C = Theme.Colors
local player = Players.LocalPlayer

local gui: ScreenGui
local panel: Frame
local grid: ScrollingFrame
local moneyLabel: TextLabel
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Seeds"
local spinners: { { model: Model, camera: Camera, center: Vector3, distance: number } } = {}
local cards: { [string]: { button: TextButton, info: TextLabel } } = {}

local GROUPS = { Plant = "Plants", Decor = "Decor", Costume = "Costumes", Tool = "Fun", Passive = "Fun", Pet = "Fun" }

local function previewModel(item): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local group = assets and assets:FindFirstChild(GROUPS[item.kind] or "")
	local source = group and group:FindFirstChild(item.model)
	if source then
		return source:Clone()
	end
	local model = Instance.new("Model")
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2, 2, 2)
	part.Color = Color3.fromRGB(255, 160, 200)
	part.Parent = model
	return model
end

local function cardState(item, profile): (string, Color3, string)
	if Catalog.isPlaceable(item) then
		local count = profile and profile.pouch[item.id] or 0
		return "Buy " .. Format.money(item.price), C.Green, (if count > 0 then "In your pouch: " .. count else item.description)
	end
	if profile and profile.owned[item.id] then
		local on
		if item.kind == "Costume" then
			on = profile.equipped[item.slot] == item.id
		elseif item.kind == "Passive" or item.kind == "Pet" then
			on = profile.toggles[item.id] == true
		else
			return "Owned ✓", C.Gray, "In your backpack!"
		end
		return if on then "Take off" else "Wear", if on then C.Orange else C.Blue, item.description
	end
	return "Buy " .. Format.money(item.price), C.Green, item.description
end

local function refreshCards()
	local profile = controllers.ClientData.profile
	for id, card in cards do
		local item = Catalog.get(id)
		local text, color, info = cardState(item, profile)
		Theme.setButtonText(card.button, text)
		Theme.setButtonColor(card.button, color)
		card.info.Text = info
	end
	if profile and moneyLabel then
		moneyLabel.Text = "💰 " .. Format.money(profile.money)
	end
end

local function onCardButton(item)
	local profile = controllers.ClientData.profile
	local action = "Buy"
	if profile and profile.owned[item.id] and not Catalog.isPlaceable(item) then
		if item.kind == "Costume" then
			action = if profile.equipped[item.slot] == item.id then "Unequip" else "Equip"
		elseif item.kind == "Passive" or item.kind == "Pet" then
			action = if profile.toggles[item.id] then "Unequip" else "Equip"
		else
			return
		end
	end
	local ok, message = Remotes.ShopRequest:InvokeServer(action, item.id)
	controllers.NotifyController.show(message, if ok then "success" else "error")
	controllers.SoundController.play(if ok then "Cash" else "Wrong", nil, 0.5)
end

local function buildCard(item, order: number)
	local card = Theme.new("Frame", {
		Name = item.id,
		LayoutOrder = order,
		BackgroundColor3 = C.White,
		Parent = grid,
		[Theme.Children] = { Theme.corner(18), Theme.stroke(C.Ink, 3) },
	})
	local viewport = Theme.new("ViewportFrame", {
		Size = UDim2.new(1, -16, 0, 120),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.fromRGB(226, 242, 255),
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1.5, -1),
		Parent = card,
		[Theme.Children] = { Theme.corner(14) },
	})
	local model = previewModel(item)
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local cf, size = model:GetBoundingBox()
	local distance = math.max(size.X, size.Y, size.Z) * 1.7 + 1
	table.insert(spinners, { model = model, camera = camera, center = cf.Position, distance = distance })

	Theme.text({
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 134),
		Text = item.name,
		Parent = card,
	})
	local info = Theme.text({
		Size = UDim2.new(1, -16, 0, 34),
		Position = UDim2.fromOffset(8, 162),
		FontFace = Theme.Body,
		TextColor3 = C.InkSoft,
		TextScaled = false,
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = item.description,
		Parent = card,
	})
	local button = Theme.button({
		Text = "Buy",
		Size = UDim2.new(1, -16, 0, 50),
		Position = UDim2.new(0, 8, 1, -58),
		Color = C.Green,
		Parent = card,
	})
	button.Activated:Connect(function()
		onCardButton(item)
	end)
	cards[item.id] = { button = button, info = info }
end

local function showTab(id: string)
	currentTab = id
	for _, child in grid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(spinners)
	table.clear(cards)
	for i, item in Catalog.ByCategory[id] or {} do
		buildCard(item, i)
	end
	for tabId, button in tabButtons do
		Theme.setButtonColor(button, if tabId == id then C.Orange else C.Gray)
	end
	refreshCards()
	grid.CanvasPosition = Vector2.zero
end

function ShopController.open()
	if panel.Visible then
		return
	end
	panel.Visible = true
	showTab(currentTab)
	local scale = panel:FindFirstChildOfClass("UIScale") or Theme.new("UIScale", { Parent = panel })
	scale.Scale = 0.7
	Theme.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

function ShopController.close()
	panel.Visible = false
	table.clear(spinners)
end

function ShopController:Start(all)
	controllers = all
	gui = Theme.screen("Shop", 12)
	panel = Theme.new("Frame", {
		Name = "Panel",
		Size = UDim2.fromOffset(900, 580),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Paper,
		Visible = false,
		Parent = gui,
		[Theme.Children] = { Theme.corner(26), Theme.stroke(C.Ink, 4) },
	})
	local header = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundColor3 = C.Green,
		Parent = panel,
		[Theme.Children] = { Theme.corner(26) },
	})
	Theme.text({
		Size = UDim2.new(0.6, 0, 0, 48),
		Position = UDim2.fromOffset(22, 12),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.White,
		Text = "🐸 Ribbit's Emporium",
		Parent = header,
		[Theme.Children] = { Theme.textStroke(C.Ink, 3) },
	})
	moneyLabel = Theme.text({
		Size = UDim2.new(0.3, 0, 0, 40),
		Position = UDim2.new(0.62, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.Yellow,
		Text = "💰 $0",
		Parent = header,
		[Theme.Children] = { Theme.textStroke(C.Ink, 3) },
	})
	local close = Theme.button({
		Text = "X",
		Size = UDim2.fromOffset(54, 50),
		Position = UDim2.new(1, -66, 0, 10),
		Color = C.Red,
		Parent = header,
	})
	close.Activated:Connect(function()
		controllers.SoundController.play("Click")
		ShopController.close()
	end)

	local tabs = Theme.new("Frame", {
		Size = UDim2.new(1, -40, 0, 58),
		Position = UDim2.fromOffset(20, 84),
		BackgroundTransparency = 1,
		Parent = panel,
		[Theme.Children] = {
			Theme.new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		},
	})
	for i, category in Catalog.Categories do
		local button = Theme.button({
			Text = category.icon .. " " .. category.label,
			Size = UDim2.fromOffset(200, 56),
			Color = C.Gray,
			LayoutOrder = i,
			Parent = tabs,
		})
		button.Activated:Connect(function()
			controllers.SoundController.play("Click")
			showTab(category.id)
		end)
		tabButtons[category.id] = button
	end

	grid = Theme.new("ScrollingFrame", {
		Size = UDim2.new(1, -40, 1, -166),
		Position = UDim2.fromOffset(20, 152),
		BackgroundTransparency = 1,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = C.InkSoft,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
		[Theme.Children] = {
			Theme.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(196, 262),
				CellPadding = UDim2.fromOffset(14, 14),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Theme.new("UIPadding", {
				PaddingTop = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			}),
		},
	})

	controllers.ClientData.Changed:Connect(function()
		if panel.Visible then
			refreshCards()
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and prompt:GetAttribute("OpenShop") then
			ShopController.open()
		end
	end)
	-- walking away closes the shop
	task.spawn(function()
		while true do
			task.wait(0.5)
			if panel.Visible then
				local world = workspace:FindFirstChild("World")
				local spot = world and world:FindFirstChild("ShopPrompt", true) :: BasePart?
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if spot and root and (root.Position - spot.Position).Magnitude > 40 then
					ShopController.close()
				end
			end
		end
	end)

	local angle = 0
	RunService.RenderStepped:Connect(function(dt)
		if not panel.Visible then
			return
		end
		angle += dt * 0.8
		for _, spinner in spinners do
			local offset = CFrame.Angles(0, angle, 0) * CFrame.new(0, spinner.distance * 0.25, spinner.distance)
			spinner.camera.CFrame = CFrame.lookAt(spinner.center + offset.Position, spinner.center)
		end
	end)
end

return ShopController
