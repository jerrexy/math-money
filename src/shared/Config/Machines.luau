--[[
	The four money machines on every plot, cheapest to richest.

	Harder math pays more: a full Division plate is worth four times an Addition
	plate, and every machine level adds Economy.LevelPayBonus on top.

	dropTime   seconds of lowering before the plate reaches the acid
	pauseTime  seconds a correct answer stops the chain
	With a 30 second round, a player needs (30 - dropTime) / pauseTime correct
	answers to keep the loot out of the acid: about three on every machine.
]]

export type MachineDef = {
	id: string,
	displayName: string,
	op: string,
	verb: string,
	symbolPart: string,
	themeColor: Color3,
	plateColor: Color3,
	basePlate: number,
	dropTime: number,
	pauseTime: number,
	loot: { string },
	gemColors: { Color3 },
}

local Machines = {}

Machines.Order = { "Addition", "Subtraction", "Multiplication", "Division" }

Machines.Defs = {
	Addition = {
		id = "Addition",
		displayName = "Addition",
		op = "+",
		verb = "Add",
		symbolPart = "SymbolPlus",
		themeColor = Color3.fromRGB(86, 198, 96),
		plateColor = Color3.fromRGB(205, 132, 66),
		basePlate = 20,
		dropTime = 20,
		pauseTime = 3.5,
		loot = { "Coin", "Coin", "Coin", "Coin", "GemRound", "Pearl" },
		gemColors = { Color3.fromRGB(60, 205, 100), Color3.fromRGB(255, 205, 50) },
	},
	Subtraction = {
		id = "Subtraction",
		displayName = "Subtraction",
		op = "−",
		verb = "Subtract",
		symbolPart = "SymbolMinus",
		themeColor = Color3.fromRGB(74, 150, 236),
		plateColor = Color3.fromRGB(196, 204, 216),
		basePlate = 35,
		dropTime = 19,
		pauseTime = 4,
		loot = { "Coin", "Coin", "Coin", "GemRound", "GemSquare", "Pearl", "MoneyBag" },
		gemColors = { Color3.fromRGB(60, 120, 245), Color3.fromRGB(110, 220, 255) },
	},
	Multiplication = {
		id = "Multiplication",
		displayName = "Multiplication",
		op = "×",
		verb = "Multiply",
		symbolPart = "SymbolTimes",
		themeColor = Color3.fromRGB(248, 150, 46),
		plateColor = Color3.fromRGB(255, 204, 64),
		basePlate = 55,
		dropTime = 18,
		pauseTime = 4.5,
		loot = { "Coin", "Coin", "GoldBar", "GemRound", "GemHeart", "GemSquare", "MoneyBag" },
		gemColors = { Color3.fromRGB(232, 32, 64), Color3.fromRGB(255, 96, 176) },
	},
	Division = {
		id = "Division",
		displayName = "Division",
		op = "÷",
		verb = "Divide",
		symbolPart = "SymbolDivide",
		themeColor = Color3.fromRGB(172, 92, 232),
		plateColor = Color3.fromRGB(236, 214, 255),
		basePlate = 80,
		dropTime = 17,
		pauseTime = 5,
		loot = { "GoldBar", "GoldBar", "Diamond", "GemSquare", "GemRound", "MoneyBag", "Coin", "MiniCrown" },
		gemColors = { Color3.fromRGB(150, 70, 240), Color3.fromRGB(205, 240, 255) },
	},
} :: { [string]: MachineDef }

function Machines.get(id: string): MachineDef
	return assert(Machines.Defs[id], "unknown machine " .. tostring(id))
end

return Machines
