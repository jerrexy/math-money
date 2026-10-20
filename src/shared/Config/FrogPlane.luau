--[[
	The Frog Plane event: every few minutes Ribbit's plane flies over the island
	and drops frog safes on parachutes. Solving 3 math problems (one level above
	your own) finds a safe's 3-number combination. Inside: money, and sometimes an
	exclusive item that the shop doesn't sell.

	All of the event's tuning lives here.
]]

local FrogPlane = {}

FrogPlane.Interval = 8 * 60 -- seconds between flights
FrogPlane.FirstFlight = 150 -- seconds after a server starts
FrogPlane.Warning = 30 -- "the Frog Plane is coming!" heads-up before each flight

FrogPlane.Altitude = 115 -- studs above the island
FrogPlane.Span = 1150 -- length of the flight path (the island is about 580 wide)
FrogPlane.FlightTime = 24 -- seconds to cross
FrogPlane.FallTime = 7 -- seconds on the parachute (a little longer when it drifts far)

FrogPlane.ExtraSafes = 2 -- safes per flight = players + this...
FrogPlane.MinSafes = 3 -- ...but at least this many
FrogPlane.MaxSafes = 8 -- ...and at most this many
FrogPlane.SafeLifetime = 240 -- unopened safes vanish after this many seconds
FrogPlane.SafeSpacing = 30 -- studs between safes

FrogPlane.Problems = 3 -- digits in the combination
FrogPlane.CrackRange = 16 -- walking further than this away gives up
FrogPlane.CrackIdle = 120 -- seconds without an answer gives up
FrogPlane.WrongDelay = 1.6 -- the dial jams for a moment after a wrong answer

FrogPlane.PrizePlates = 1.5 -- money = this x the plate values of the safe's problems
FrogPlane.ItemChance = 0.4 -- chance of an exclusive item (your first safe always has one)
FrogPlane.ItemBonus = 0.5 -- extra money once you own every exclusive

--- Where safes may land, as { min, max, weight } rectangles of (x, z): open grass
--- and the avenue, never inside a plot. Every spot is also checked with a raycast.
FrogPlane.Zones = {
	{ min = Vector2.new(-215, -26), max = Vector2.new(215, 26), weight = 3 }, -- the avenue
	{ min = Vector2.new(-268, -150), max = Vector2.new(-228, 150), weight = 1 }, -- west end
	{ min = Vector2.new(228, -150), max = Vector2.new(268, 150), weight = 1 }, -- east end
	{ min = Vector2.new(-215, 156), max = Vector2.new(215, 192), weight = 1 }, -- north meadow
	{ min = Vector2.new(-215, -192), max = Vector2.new(215, -156), weight = 1 }, -- south meadow
}
FrogPlane.KeepClear = 24 -- studs from the shop, the spawn and the welcome sign

return FrogPlane
