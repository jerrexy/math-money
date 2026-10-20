--[[
	Money, rounds and progression tuning. Everything that affects how fast kids
	earn lives here so the game can be balanced in one place.

	Rough pacing: a round takes ~40s. A first-grader on Addition level 1 earns
	about $20 a round (a pack of Daisy seeds), a confident times-tables player on
	Division level 5 about $160. Shop prices in Catalog.luau go from $15 to $5,000
	so the big goals take a few hours of real math practice.
]]

local Economy = {}

Economy.RoundSeconds = 30
Economy.PlateJewels = 12 -- loot pieces on a fresh plate
Economy.MaxJewels = 18 -- streak bonuses can stack extra loot on top
Economy.JewelsLostPerWrong = 2
Economy.StreakForBonus = 3 -- every 3 correct answers in a row adds a bonus jewel
Economy.PerfectBonus = 0.2 -- +20% for a round with no wrong answers...
Economy.PerfectMinCorrect = 3 -- ...and at least this many right
Economy.LevelPayBonus = 0.25 -- each machine level adds 25% to the plate value
Economy.MaxPauseStack = 2 -- correct answers can stack the pause up to 2x pauseTime
Economy.WrongAnswerDelay = 1.4 -- seconds the right answer stays on screen after a miss
Economy.StartDelay = 1.2 -- "3-2-1" breathing room before the chain starts
Economy.ResetSeconds = 3
Economy.StartRange = 30 -- studs from the console to start a round
Economy.LeaveRange = 70 -- walking further than this away abandons the round

Economy.MaxLevel = 8
--- Net correct answers (right minus wrong) needed to finish ``level``.
function Economy.xpToLevelUp(level: number): number
	return 8 + 2 * level
end

--- Dollar value of a full plate on a machine at a given level.
function Economy.plateValue(basePlate: number, level: number): number
	return math.floor(basePlate * (1 + Economy.LevelPayBonus * (level - 1)) + 0.5)
end

Economy.MaxPlants = 40
Economy.StartingMoney = 0

return Economy
