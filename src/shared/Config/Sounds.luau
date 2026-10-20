--[[
	Sound effects and music. All ids are from Roblox's licensed libraries
	(Pro Sound Effects / APM Music) or Roblox's own packs, so they're free to use.

	Each entry is { id, max = seconds to play (long clips get cut), volume }.
	Leave id empty to mute a sound; swap in your own uploads any time.
]]

export type SoundDef = { id: string, max: number?, volume: number? }

local Sounds: { [string]: SoundDef } = {
	Splash = { id = "rbxassetid://9125703162", volume = 0.8 }, -- Mud Puddle Splash (Pro Sound Effects)
	Sizzle = { id = "rbxassetid://9119165650", max = 1.4 }, -- Sizzle Short And Explosive Sear (PSE)
	Chug = { id = "rbxassetid://9113760225", volume = 0.35 }, -- Chain Movement: rattles while the plate lowers
	Grind = { id = "rbxassetid://9116893222", max = 1.3, volume = 0.6 }, -- Metal Tank Scrape (PSE)
	Coins = { id = "rbxassetid://9113381863", max = 0.9, volume = 0.5 }, -- Beads Pick Up: coin-like jingle (PSE)
	Cash = { id = "rbxassetid://9047214582", volume = 0.6 }, -- "Party In The Wild" tag (APM): win jingle
	LevelUp = { id = "rbxassetid://9045129322", volume = 0.6 }, -- "It's All A Big Joke" tag (APM)
	Squeak = { id = "rbxassetid://111237552536869", volume = 0.7 }, -- rubber duck spring (Roblox essentials)
	Boing = { id = "rbxassetid://111237552536869", volume = 0.5 },
	Music = { id = "rbxassetid://1848294293", volume = 0.16 }, -- "Runaway Carousel" (APM): quirky, bouncy

	-- not set yet: add ids here to give these moments a sound
	Correct = { id = "" },
	Wrong = { id = "" },
	Pop = { id = "" },
	Click = { id = "" },
	Confetti = { id = "" },
	Tick = { id = "" },
	Whoosh = { id = "" },
	PlaneEngine = { id = "" }, -- looping propeller hum while the Frog Plane flies over
	SafeLand = { id = "" }, -- a safe thumps onto the grass
	SafeOpen = { id = "" }, -- the safe door creaks open
}

return Sounds
