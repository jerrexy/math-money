--[[
	Sanity test for the question generator. Paste into the Studio command bar
	(or run through the MCP) with the game synced:

	    loadstring(game:GetService("HttpService"):GetAsync(
	        "http://127.0.0.1:8765/tools/studio/test_math.luau"))()

	Generates 600 questions for every level of every machine and checks that
	answers are whole, never negative, divisions are exact and every fact key
	round-trips. Prints a table of answer ranges per level.
]]

local MathQuestions = require(game:GetService("ReplicatedStorage").Shared.MathQuestions)

local rng = Random.new(1234)
local problems = {}
local lines = {}

for _, kind in { "Addition", "Subtraction", "Multiplication", "Division" } do
	for level = 1, MathQuestions.MaxLevel do
		local lo, hi, distinct, seen = math.huge, -math.huge, 0, {}
		local recent = {}
		for _ = 1, 600 do
			local q = MathQuestions.generate(kind, level, rng, recent)
			table.insert(recent, q.key)
			if #recent > 5 then
				table.remove(recent, 1)
			end
			if q.answer < 0 or q.answer ~= math.floor(q.answer) then
				table.insert(problems, kind .. " L" .. level .. ": bad answer for " .. q.text)
			end
			if kind == "Division" and (q.b == 0 or q.a % q.b ~= 0) then
				table.insert(problems, "inexact division " .. q.text)
			end
			local back = MathQuestions.fromKey(q.key)
			if not back or back.answer ~= q.answer then
				table.insert(problems, "fact key does not round-trip: " .. q.key)
			end
			if not seen[q.key] then
				seen[q.key] = true
				distinct += 1
			end
			lo, hi = math.min(lo, q.answer), math.max(hi, q.answer)
		end
		table.insert(lines, string.format("%-15s L%d  %-26s answers %d..%d  (%d different facts)", kind, level,
			MathQuestions.levelName(kind, level), lo, hi, distinct))
	end
end

print(table.concat(lines, "\n"))
if #problems == 0 then
	print("MathQuestions: all checks passed")
else
	warn("MathQuestions: " .. #problems .. " problems\n" .. table.concat(problems, "\n"))
end
return #problems == 0
