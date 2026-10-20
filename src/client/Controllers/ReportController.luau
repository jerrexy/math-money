--[[
	📒 Report Card: progress on each machine plus a times-table grid that fills in
	green as facts are mastered. Great for showing a grown-up what you learned!
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Util.Format)
local Machines = require(Shared.Config.Machines)
local MathQuestions = require(Shared.MathQuestions)
local Theme = require(script.Parent.Parent.UI.Theme)

local ReportController = {}
local controllers
local C = Theme.Colors

local panel: Frame
local rows: { [string]: { level: TextLabel, fill: Frame, detail: TextLabel } } = {}
local cells: { [string]: Frame } = {}
local summary: TextLabel
local masteredLabel: TextLabel

local function factStats(facts, a: number, b: number): (number, number)
	local lo, hi = math.min(a, b), math.max(a, b)
	local c, w = 0, 0
	local function add(key: string)
		local f = facts[key]
		if f then
			c += f.c
			w += f.w
		end
	end
	add("M" .. lo .. "x" .. hi)
	add("D" .. (a * b) .. "/" .. a)
	if a ~= b then
		add("D" .. (a * b) .. "/" .. b)
	end
	return c, w
end

local function refresh()
	local profile = controllers.ClientData.profile
	if not profile or not panel.Visible then
		return
	end
	for _, id in Machines.Order do
		local m = profile.machines[id]
		local row = rows[id]
		local answered = m.correct + m.wrong
		local accuracy = if answered > 0 then math.floor(m.correct / answered * 100 + 0.5) else 0
		row.level.Text = string.format("Level %d / %d  •  %s", m.level, Economy.MaxLevel, MathQuestions.levelName(id, m.level))
		local need = Economy.xpToLevelUp(m.level)
		row.fill.Size = UDim2.fromScale(if m.level >= Economy.MaxLevel then 1 else math.clamp(m.xp / need, 0, 1), 1)
		row.detail.Text = string.format("%d%% correct  •  %d %s / %d %s  •  best plate %s", accuracy, m.wins,
			if m.wins == 1 then "win" else "wins", m.rounds, if m.rounds == 1 then "round" else "rounds", Format.money(m.best))
	end
	local mastered = 0
	for a = 1, 12 do
		for b = 1, 12 do
			local c, w = factStats(profile.facts, a, b)
			local color = Color3.fromRGB(226, 222, 236)
			if c >= 3 and c / (c + w) >= 0.8 then
				color = C.Green
				if a <= b then
					mastered += 1
				end
			elseif w > c then
				color = C.Red
			elseif c > 0 then
				color = C.Yellow
			end
			cells[a .. "x" .. b].BackgroundColor3 = color
		end
	end
	masteredLabel.Text = string.format("Times tables mastered: %d / 78", mastered)
	local s = profile.stats
	summary.Text = string.format("%s questions answered  •  %d%% correct  •  %s earned in total",
		Format.commas(s.questions), if s.questions > 0 then math.floor(s.correct / s.questions * 100 + 0.5) else 0,
		Format.money(profile.totalEarned))
end

function ReportController.toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		refresh()
		local scale = panel:FindFirstChildOfClass("UIScale") or Theme.new("UIScale", { Parent = panel })
		scale.Scale = 0.7
		Theme.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

function ReportController:Start(all)
	controllers = all
	local gui = Theme.screen("Report", 11)
	panel = Theme.new("Frame", {
		Size = UDim2.fromOffset(1000, 600),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Paper,
		Visible = false,
		Parent = gui,
		[Theme.Children] = { Theme.corner(26), Theme.stroke(C.Ink, 4) },
	})
	local header = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = C.Blue,
		Parent = panel,
		[Theme.Children] = { Theme.corner(26) },
	})
	Theme.text({
		Size = UDim2.new(0.7, 0, 0, 46),
		Position = UDim2.fromOffset(22, 12),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.White,
		Text = "📒 My Report Card",
		Parent = header,
		[Theme.Children] = { Theme.textStroke(C.Ink, 3) },
	})
	local close = Theme.button({ Text = "X", Size = UDim2.fromOffset(54, 50), Position = UDim2.new(1, -66, 0, 10), Color = C.Red, Parent = header })
	close.Activated:Connect(ReportController.toggle)

	-- machines (left)
	for i, id in Machines.Order do
		local def = Machines.get(id)
		local y = 84 + (i - 1) * 112
		local row = Theme.new("Frame", {
			Size = UDim2.fromOffset(500, 100),
			Position = UDim2.fromOffset(20, y),
			BackgroundColor3 = C.White,
			Parent = panel,
			[Theme.Children] = { Theme.corner(16), Theme.stroke(def.themeColor:Lerp(C.Ink, 0.3), 3) },
		})
		Theme.text({
			Size = UDim2.fromOffset(70, 70),
			Position = UDim2.fromOffset(12, 15),
			Text = def.op,
			TextColor3 = def.themeColor,
			Parent = row,
			[Theme.Children] = { Theme.textStroke(C.Ink, 3) },
		})
		local level = Theme.text({
			Size = UDim2.new(1, -100, 0, 28),
			Position = UDim2.fromOffset(92, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = def.displayName,
			Parent = row,
		})
		local bar = Theme.new("Frame", {
			Size = UDim2.new(1, -108, 0, 18),
			Position = UDim2.fromOffset(92, 42),
			BackgroundColor3 = C.PaperDark,
			Parent = row,
			[Theme.Children] = { Theme.round() },
		})
		local fill = Theme.new("Frame", {
			Size = UDim2.fromScale(0.2, 1),
			BackgroundColor3 = def.themeColor,
			Parent = bar,
			[Theme.Children] = { Theme.round() },
		})
		local detail = Theme.text({
			Size = UDim2.new(1, -100, 0, 22),
			Position = UDim2.fromOffset(92, 66),
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Theme.Body,
			TextColor3 = C.InkSoft,
			Parent = row,
		})
		rows[id] = { level = level, fill = fill, detail = detail }
	end

	-- times table grid (right)
	local gridFrame = Theme.new("Frame", {
		Size = UDim2.fromOffset(430, 430),
		Position = UDim2.fromOffset(548, 84),
		BackgroundColor3 = C.White,
		Parent = panel,
		[Theme.Children] = { Theme.corner(16), Theme.stroke(C.Ink, 3) },
	})
	local cell = 31
	for a = 0, 12 do
		for b = 0, 12 do
			local x, y = 12 + b * cell, 12 + a * cell
			if a == 0 and b == 0 then
				Theme.text({ Size = UDim2.fromOffset(cell - 2, cell - 2), Position = UDim2.fromOffset(x, y), Text = "×", Parent = gridFrame })
			elseif a == 0 or b == 0 then
				Theme.text({
					Size = UDim2.fromOffset(cell - 2, cell - 2),
					Position = UDim2.fromOffset(x, y),
					Text = tostring(if a == 0 then b else a),
					TextColor3 = C.BlueDark,
					Parent = gridFrame,
				})
			else
				local box = Theme.new("Frame", {
					Size = UDim2.fromOffset(cell - 3, cell - 3),
					Position = UDim2.fromOffset(x, y),
					BackgroundColor3 = Color3.fromRGB(226, 222, 236),
					Parent = gridFrame,
					[Theme.Children] = {
						Theme.corner(6),
						Theme.text({
							Size = UDim2.fromScale(0.8, 0.7),
							Position = UDim2.fromScale(0.5, 0.5),
							AnchorPoint = Vector2.new(0.5, 0.5),
							FontFace = Theme.Body,
							TextColor3 = C.Ink,
							TextTransparency = 0.35,
							Text = tostring(a * b),
						}),
					},
				})
				cells[a .. "x" .. b] = box
			end
		end
	end
	masteredLabel = Theme.text({
		Size = UDim2.fromOffset(430, 26),
		Position = UDim2.fromOffset(548, 520),
		Text = "Times tables mastered: 0 / 78",
		Parent = panel,
	})
	Theme.text({
		Size = UDim2.fromOffset(430, 20),
		Position = UDim2.fromOffset(548, 548),
		FontFace = Theme.Body,
		TextColor3 = C.InkSoft,
		Text = "🟩 mastered   🟨 learning   🟥 tricky   ⬜ not tried yet",
		Parent = panel,
	})
	summary = Theme.text({
		Size = UDim2.fromOffset(500, 24),
		Position = UDim2.fromOffset(20, 540),
		FontFace = Theme.Body,
		TextColor3 = C.InkSoft,
		Parent = panel,
	})

	controllers.ClientData.Changed:Connect(refresh)
end

return ReportController
