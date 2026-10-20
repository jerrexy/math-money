--[[
	The big 3x4 number pad used for machine rounds and Frog Plane safes (mouse and
	touch), plus the matching keyboard keys.

	NumberPad.new({ Position = ..., Parent = ... }, function(key) ... end)
	    key is "0".."9", "back" or "enter"
]]

local Theme = require(script.Parent.Theme)

local NumberPad = {}

local KEYS = { "7", "8", "9", "4", "5", "6", "1", "2", "3", "⬅️", "0", "✓" }
local DIGITS = {
	Zero = "0",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
}

function NumberPad.new(props: { [string]: any }, onKey: (string) -> ()): Frame
	local C = Theme.Colors
	local pad = Theme.new("Frame", {
		Name = props.Name or "NumberPad",
		Size = UDim2.fromOffset(330, 340),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.25,
		Visible = props.Visible ~= false,
		Parent = props.Parent,
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
	for i, key in KEYS do
		local color = if key == "✓" then C.Green elseif key == "⬅️" then C.Orange else C.Blue
		local button = Theme.button({ Text = key, Size = UDim2.fromOffset(98, 72), Color = color, LayoutOrder = i, Parent = pad })
		button.Activated:Connect(function()
			onKey(if key == "✓" then "enter" elseif key == "⬅️" then "back" else key)
		end)
	end
	return pad
end

--- The pad key for a keyboard key (digits, number pad, Backspace, Enter), or nil.
function NumberPad.fromKeyCode(code: Enum.KeyCode): string?
	local name = string.match(code.Name, "^Keypad(%a+)$") or code.Name
	if DIGITS[name] then
		return DIGITS[name]
	elseif code == Enum.KeyCode.Backspace then
		return "back"
	elseif code == Enum.KeyCode.Return or code == Enum.KeyCode.KeypadEnter then
		return "enter"
	end
	return nil
end

return NumberPad
