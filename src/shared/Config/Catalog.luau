--[[
	Everything the frog shopkeeper sells.

	kind:
	  Plant     seed packet; planted in your garden and grows over growSeconds
	  Decor     garden ornament; placed like a seed but never grows
	  Costume   worn on the avatar in ``slot`` (Hat / Face / Waist)
	  Tool      goes in the backpack
	  Passive   toggled on/off (effect = "Speed" | "Jump")
	  Pet       follows you around

	Plants and decor are bought one at a time and kept in your seed pouch until
	planted; everything else is bought once and can be equipped forever.
]]

export type Item = {
	id: string,
	kind: string,
	category: string,
	name: string,
	price: number,
	model: string,
	description: string,
	growSeconds: number?,
	radius: number?,
	slot: string?,
	effect: string?,
}

local Catalog = {}

Catalog.Categories = {
	{ id = "Seeds", label = "Seeds", icon = "🌱" },
	{ id = "Decor", label = "Decor", icon = "🦩" },
	{ id = "Costumes", label = "Costumes", icon = "🎩" },
	{ id = "Fun", label = "Fun Stuff", icon = "🎉" },
}

local items: { Item } = {
	-- Seeds -------------------------------------------------------------------
	{ id = "Daisy", kind = "Plant", category = "Seeds", name = "Daisy", price = 15, model = "Daisy", growSeconds = 120, radius = 1.8,
		description = "Happy little flowers. Grow in 2 minutes!" },
	{ id = "Tulip", kind = "Plant", category = "Seeds", name = "Tulips", price = 30, model = "Tulip", growSeconds = 180, radius = 1.8,
		description = "Fancy cups of colour for your garden." },
	{ id = "Sunflower", kind = "Plant", category = "Seeds", name = "Sunflower", price = 60, model = "Sunflower", growSeconds = 300, radius = 2.2,
		description = "A tall flower with a big sunny smile." },
	{ id = "Mushroom", kind = "Plant", category = "Seeds", name = "Giant Toadstool", price = 90, model = "Mushroom", growSeconds = 360, radius = 3,
		description = "A huge spotty mushroom. Do NOT eat it." },
	{ id = "BerryBush", kind = "Plant", category = "Seeds", name = "Berry Bush", price = 120, model = "BerryBush", growSeconds = 480, radius = 3.2,
		description = "Bursting with berries. Birds love it." },
	{ id = "Cactus", kind = "Plant", category = "Seeds", name = "Cactus", price = 160, model = "Cactus", growSeconds = 480, radius = 2.6,
		description = "Prickly but friendly. Wears a flower." },
	{ id = "PineTree", kind = "Plant", category = "Seeds", name = "Pine Tree", price = 250, model = "PineTree", growSeconds = 720, radius = 4.5,
		description = "Smells like adventure. Plant lots for a forest!" },
	{ id = "OakTree", kind = "Plant", category = "Seeds", name = "Oak Tree", price = 400, model = "OakTree", growSeconds = 900, radius = 6,
		description = "A big leafy oak. The king of the forest." },
	{ id = "CherryTree", kind = "Plant", category = "Seeds", name = "Cherry Blossom", price = 650, model = "CherryTree", growSeconds = 1200, radius = 5.5,
		description = "Pink blossoms that drift on the breeze." },
	{ id = "RainbowTree", kind = "Plant", category = "Seeds", name = "Rainbow Tree", price = 1500, model = "RainbowTree", growSeconds = 1800, radius = 6,
		description = "The rarest tree in Math Money. It sparkles!" },

	-- Decor -------------------------------------------------------------------
	{ id = "RubberDuck", kind = "Decor", category = "Decor", name = "Giant Rubber Duck", price = 75, model = "RubberDuck", radius = 2.2,
		description = "Quack." },
	{ id = "Flamingo", kind = "Decor", category = "Decor", name = "Pink Flamingo", price = 150, model = "Flamingo", radius = 1.6,
		description = "Stands on one leg. Very balanced, like an equation." },
	{ id = "Gnome", kind = "Decor", category = "Decor", name = "Garden Gnome", price = 300, model = "Gnome", radius = 1.6,
		description = "A tiny guardian for your garden." },
	{ id = "GoldenToilet", kind = "Decor", category = "Decor", name = "Golden Toilet", price = 5000, model = "GoldenToilet", radius = 2.6,
		description = "Solid gold. Totally useless. Absolutely legendary." },

	-- Costumes ----------------------------------------------------------------
	{ id = "TrafficCone", kind = "Costume", category = "Costumes", name = "Traffic Cone", price = 50, model = "TrafficCone", slot = "Hat",
		description = "Safety first! Wear it on your head." },
	{ id = "PartyHat", kind = "Costume", category = "Costumes", name = "Party Hat", price = 100, model = "PartyHat", slot = "Hat",
		description = "Every round is a party!" },
	{ id = "NerdGlasses", kind = "Costume", category = "Costumes", name = "Nerd Glasses", price = 200, model = "NerdGlasses", slot = "Face",
		description = "+10 smartness. (Not really, but you look smart!)" },
	{ id = "ChefHat", kind = "Costume", category = "Costumes", name = "Chef Hat", price = 350, model = "ChefHat", slot = "Hat",
		description = "Cooking up some fresh maths." },
	{ id = "PirateHat", kind = "Costume", category = "Costumes", name = "Pirate Hat", price = 500, model = "PirateHat", slot = "Hat",
		description = "Arrr! A true treasure hunter." },
	{ id = "DuckFloaty", kind = "Costume", category = "Costumes", name = "Duck Floaty", price = 750, model = "DuckFloaty", slot = "Waist",
		description = "Just in case you fall in. (Don't fall in.)" },
	{ id = "VikingHelmet", kind = "Costume", category = "Costumes", name = "Viking Helmet", price = 800, model = "VikingHelmet", slot = "Hat",
		description = "For brave maths warriors." },
	{ id = "DinoHood", kind = "Costume", category = "Costumes", name = "Dino Hood", price = 1200, model = "DinoHood", slot = "Hat",
		description = "RAWR means 'I love maths' in dinosaur." },
	{ id = "WizardHat", kind = "Costume", category = "Costumes", name = "Wizard Hat", price = 2000, model = "WizardHat", slot = "Hat",
		description = "Maths is basically magic." },
	{ id = "RoyalCrown", kind = "Costume", category = "Costumes", name = "Royal Crown", price = 4000, model = "RoyalCrown", slot = "Hat",
		description = "For the ruler of all numbers." },

	-- Fun stuff ---------------------------------------------------------------
	{ id = "RubberChicken", kind = "Tool", category = "Fun", name = "Rubber Chicken", price = 250, model = "RubberChicken",
		description = "Squeak it at your friends!" },
	{ id = "ConfettiCannon", kind = "Tool", category = "Fun", name = "Confetti Cannon", price = 600, model = "ConfettiCannon",
		description = "Celebrate every right answer. POP!" },
	{ id = "SpeedSneakers", kind = "Passive", category = "Fun", name = "Speed Sneakers", price = 900, model = "SpeedSneakers", effect = "Speed",
		description = "Zoom between your machines!" },
	{ id = "SpringShoes", kind = "Passive", category = "Fun", name = "Spring Shoes", price = 1200, model = "SpringShoes", effect = "Jump",
		description = "Boing! Jump way, way higher." },
	{ id = "PetRock", kind = "Pet", category = "Fun", name = "Pet Rock", price = 1800, model = "PetRock",
		description = "The best pet ever. Never needs feeding." },
}

Catalog.Items = {} :: { [string]: Item }
Catalog.ByCategory = {} :: { [string]: { Item } }
for _, item in items do
	Catalog.Items[item.id] = item
	Catalog.ByCategory[item.category] = Catalog.ByCategory[item.category] or {}
	table.insert(Catalog.ByCategory[item.category], item)
end
for _, list in Catalog.ByCategory do
	table.sort(list, function(a, b)
		return a.price < b.price
	end)
end

function Catalog.get(id: string): Item?
	return Catalog.Items[id]
end

--- Seeds and decor are counted in the pouch; everything else is owned once.
function Catalog.isPlaceable(item: Item): boolean
	return item.kind == "Plant" or item.kind == "Decor"
end

return Catalog
