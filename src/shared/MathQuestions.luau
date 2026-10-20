--[[
	Question generator for the four machines. Pure functions: pass in a Random so
	the server stays authoritative and tests are repeatable.

	Each machine has 8 levels that follow a typical elementary progression:
	  Addition / Subtraction: facts to 10 -> to 20 -> 2-digit (no carry / carry) -> 3-digit
	  Multiplication / Division: times tables in teaching order
	     (x1 x2 x10) -> x5 -> x3 -> x4 -> x6 -> x7 -> x8 x9 -> x11 x12 + mix
	About 30% of questions review earlier levels so facts stay fresh.
]]

export type Question = {
	kind: string,
	a: number,
	b: number,
	answer: number,
	text: string, -- "7 × 8"
	key: string, -- stable fact id for stats, e.g. "M7x8"
}

local MathQuestions = {}

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

----------------------------------------------------------------------------
-- Addition
----------------------------------------------------------------------------
local addition = {
	{
		name = "Sums to 10",
		gen = function(rng)
			local total = rng:NextInteger(3, 10)
			local a = rng:NextInteger(1, total - 1)
			return a, total - a
		end,
	},
	{
		name = "Sums to 20",
		gen = function(rng)
			local a, b
			repeat
				a, b = rng:NextInteger(2, 10), rng:NextInteger(2, 10)
			until a + b >= 11 or rng:NextNumber() < 0.25
			return a, b
		end,
	},
	{
		name = "Big + small",
		gen = function(rng)
			local a, b
			repeat
				a, b = rng:NextInteger(10, 89), rng:NextInteger(1, 9)
			until a % 10 + b <= 9
			return a, b
		end,
	},
	{
		name = "Carry the one",
		gen = function(rng)
			local a, b
			repeat
				a, b = rng:NextInteger(11, 89), rng:NextInteger(2, 9)
			until a % 10 + b >= 10
			return a, b
		end,
	},
	{
		name = "Adding tens",
		gen = function(rng)
			local a, b
			repeat
				a, b = rng:NextInteger(10, 89), 10 * rng:NextInteger(1, 8)
			until a + b <= 99
			return a, b
		end,
	},
	{
		name = "Two-digit sums",
		gen = function(rng)
			local a, b
			repeat
				a, b = rng:NextInteger(11, 79), rng:NextInteger(11, 79)
			until a % 10 + b % 10 <= 9 and a + b <= 99
			return a, b
		end,
	},
	{
		name = "Two-digit with carrying",
		gen = function(rng)
			local a, b
			repeat
				a, b = rng:NextInteger(15, 89), rng:NextInteger(15, 89)
			until a % 10 + b % 10 >= 10
			return a, b
		end,
	},
	{
		name = "Hundreds!",
		gen = function(rng)
			return rng:NextInteger(100, 599), rng:NextInteger(12, 99)
		end,
	},
}

----------------------------------------------------------------------------
-- Subtraction
----------------------------------------------------------------------------
local subtraction = {
	{
		name = "Take away within 10",
		gen = function(rng)
			local a = rng:NextInteger(3, 10)
			return a, rng:NextInteger(1, a - 1)
		end,
	},
	{
		name = "Within 20",
		gen = function(rng)
			local a, b
			repeat
				a, b = rng:NextInteger(11, 20), rng:NextInteger(2, 9)
			until a % 10 < b or rng:NextNumber() < 0.3
			return a, b
		end,
	},
	{
		name = "Big − small",
		gen = function(rng)
			local a, b
			repeat
				a, b = rng:NextInteger(21, 99), rng:NextInteger(1, 9)
			until a % 10 >= b
			return a, b
		end,
	},
	{
		name = "Borrowing",
		gen = function(rng)
			local a, b
			repeat
				a, b = rng:NextInteger(21, 99), rng:NextInteger(2, 9)
			until a % 10 < b
			return a, b
		end,
	},
	{
		name = "Taking away tens",
		gen = function(rng)
			local a = rng:NextInteger(25, 99)
			return a, 10 * rng:NextInteger(1, a // 10)
		end,
	},
	{
		name = "Two-digit differences",
		gen = function(rng)
			local a, b
			repeat
				a, b = rng:NextInteger(31, 99), rng:NextInteger(11, 88)
			until b < a and a % 10 >= b % 10
			return a, b
		end,
	},
	{
		name = "Two-digit with borrowing",
		gen = function(rng)
			local a, b
			repeat
				a, b = rng:NextInteger(31, 99), rng:NextInteger(12, 89)
			until b < a and a % 10 < b % 10
			return a, b
		end,
	},
	{
		name = "Hundreds!",
		gen = function(rng)
			if rng:NextNumber() < 0.5 then
				return 100, rng:NextInteger(5, 95)
			end
			local a = rng:NextInteger(120, 600)
			return a, rng:NextInteger(12, 99)
		end,
	},
}

----------------------------------------------------------------------------
-- Times tables (shared by multiplication and division)
----------------------------------------------------------------------------
local TABLES = {
	{ 1, 2, 10 },
	{ 5 },
	{ 3 },
	{ 4 },
	{ 6 },
	{ 7 },
	{ 8, 9 },
	{ 11, 12 },
}

local function tableName(tables: { number }, symbol: string): string
	local parts = {}
	for _, n in tables do
		table.insert(parts, symbol .. n)
	end
	return table.concat(parts, " ")
end

--- Pick which times table to practise: mostly this level's, sometimes review.
local function chooseTable(rng: Random, level: number): number
	local roll = rng:NextNumber()
	if level == 8 and roll < 0.5 then
		return rng:NextInteger(1, 12)
	end
	if level > 1 and roll < 0.3 then
		return pick(rng, TABLES[rng:NextInteger(1, level - 1)])
	end
	return pick(rng, TABLES[level])
end

local LEVELS = {
	Addition = addition,
	Subtraction = subtraction,
	Multiplication = {},
	Division = {},
}
for level, tables in TABLES do
	LEVELS.Multiplication[level] = { name = tableName(tables, "×") .. (if level == 8 then " + mix" else "") }
	LEVELS.Division[level] = { name = tableName(tables, "÷") .. (if level == 8 then " + mix" else "") }
end

MathQuestions.MaxLevel = 8

local function build(kind: string, a: number, b: number): Question
	if kind == "Addition" then
		return { kind = kind, a = a, b = b, answer = a + b, text = a .. " + " .. b, key = "A" .. math.min(a, b) .. "+" .. math.max(a, b) }
	elseif kind == "Subtraction" then
		return { kind = kind, a = a, b = b, answer = a - b, text = a .. " − " .. b, key = "S" .. a .. "-" .. b }
	elseif kind == "Multiplication" then
		return { kind = kind, a = a, b = b, answer = a * b, text = a .. " × " .. b, key = "M" .. math.min(a, b) .. "x" .. math.max(a, b) }
	else
		return { kind = kind, a = a, b = b, answer = a // b, text = a .. " ÷ " .. b, key = "D" .. a .. "/" .. b }
	end
end

local function generateOnce(kind: string, level: number, rng: Random): Question
	level = math.clamp(level, 1, MathQuestions.MaxLevel)
	if kind == "Addition" or kind == "Subtraction" then
		local levels = LEVELS[kind]
		-- occasional review of an easier level keeps old facts fresh
		local useLevel = if level > 1 and rng:NextNumber() < 0.3 then rng:NextInteger(1, level - 1) else level
		local a, b = levels[useLevel].gen(rng)
		if kind == "Addition" and rng:NextNumber() < 0.5 and a < 100 and b < 100 then
			a, b = b, a
		end
		return build(kind, a, b)
	elseif kind == "Multiplication" then
		local t = chooseTable(rng, level)
		local other = if rng:NextNumber() < 0.04 then 0 else rng:NextInteger(1, 12)
		if rng:NextNumber() < 0.5 then
			return build(kind, t, other)
		end
		return build(kind, other, t)
	elseif kind == "Division" then
		local divisor = chooseTable(rng, level)
		local quotient = rng:NextInteger(1, 12)
		return build(kind, divisor * quotient, divisor)
	end
	error("unknown machine kind " .. tostring(kind))
end

--- Next question, avoiding anything in ``recent`` (a list of fact keys).
function MathQuestions.generate(kind: string, level: number, rng: Random, recent: { string }?): Question
	local q = generateOnce(kind, level, rng)
	if recent then
		for _ = 1, 12 do
			if not table.find(recent, q.key) then
				break
			end
			q = generateOnce(kind, level, rng)
		end
	end
	return q
end

--- Rebuild a question from its fact key (used to re-ask missed facts).
function MathQuestions.fromKey(key: string): Question?
	local tag = string.sub(key, 1, 1)
	local x, sep, y = string.match(key, "^%a(%d+)([%+%-x/])(%d+)$")
	if not x then
		return nil
	end
	local a, b = tonumber(x) :: number, tonumber(y) :: number
	local kind = ({ A = "Addition", S = "Subtraction", M = "Multiplication", D = "Division" })[tag]
	if not kind or (sep == "/" and b == 0) then
		return nil
	end
	return build(kind, a, b)
end

function MathQuestions.levelName(kind: string, level: number): string
	local levels = LEVELS[kind]
	local entry = levels and levels[math.clamp(level, 1, MathQuestions.MaxLevel)]
	return if entry then entry.name else ("Level " .. level)
end

--- Friendly explanation shown after a wrong answer.
function MathQuestions.explain(q: Question): string
	if q.kind == "Multiplication" and q.a ~= q.b and q.a > 0 and q.b > 0 then
		return string.format("%s = %d  (and %d × %d is %d too!)", q.text, q.answer, q.b, q.a, q.answer)
	elseif q.kind == "Division" then
		return string.format("%s = %d  because %d × %d = %d", q.text, q.answer, q.answer, q.b, q.a)
	elseif q.kind == "Subtraction" then
		return string.format("%s = %d  because %d + %d = %d", q.text, q.answer, q.answer, q.b, q.a)
	end
	return string.format("%s = %d", q.text, q.answer)
end

return MathQuestions
