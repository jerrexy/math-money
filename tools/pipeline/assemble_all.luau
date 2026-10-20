--[[
	After importing assets/meshes/MathMoney_All.fbx with Studio's 3D Importer,
	run this (through the dev server) to turn the imported MeshParts into every
	prefab the game uses and save them into the repo as .rbxm files:

	    loadstring(game:GetService("HttpService"):GetAsync(
	        "http://127.0.0.1:8765/tools/pipeline/assemble_all.luau"))().run()

	Rojo then syncs the .rbxm files into ServerStorage.Prefabs and
	ReplicatedStorage.Assets. The imported model is removed afterwards (the mesh
	ids live on in the prefabs and in assets/meshes/asset_ids.json).
]]

local HttpService = game:GetService("HttpService")
local BASE = "http://127.0.0.1:8765/"

local Assemble = loadstring(HttpService:GetAsync(BASE .. "tools/pipeline/assemble_import.luau", true))()

local OUTPUTS = {
	["assets/models/server/Apparatus.rbxm"] = "Apparatus",
	["assets/models/server/WorldProps.rbxm"] = {
		folder = "WorldProps",
		prefabs = { "ShopStall", "Frog", "FenceSection", "GateArch", "Lamp", "Rock1", "Rock2", "Rock3", "Bush" },
	},
	["assets/models/replicated/ChainLink.rbxm"] = "ChainLink",
	["assets/models/replicated/Valuables.rbxm"] = {
		folder = "Valuables",
		prefabs = { "Coin", "GoldBar", "GemRound", "GemSquare", "GemHeart", "Diamond", "Pearl", "MiniCrown", "MoneyBag" },
	},
	["assets/models/replicated/Plants.rbxm"] = {
		folder = "Plants",
		prefabs = { "Daisy", "Tulip", "Sunflower", "Mushroom", "BerryBush", "Cactus", "PineTree", "OakTree", "CherryTree", "RainbowTree" },
	},
	["assets/models/replicated/Decor.rbxm"] = {
		folder = "Decor",
		prefabs = { "RubberDuck", "Flamingo", "Gnome", "GoldenToilet" },
	},
	["assets/models/replicated/Costumes.rbxm"] = {
		folder = "Costumes",
		prefabs = { "TrafficCone", "PartyHat", "NerdGlasses", "ChefHat", "PirateHat", "DuckFloaty", "VikingHelmet", "DinoHood", "WizardHat", "RoyalCrown" },
	},
	["assets/models/replicated/Fun.rbxm"] = {
		folder = "Fun",
		prefabs = { "RubberChicken", "ConfettiCannon", "SpeedSneakers", "SpringShoes", "PetRock" },
	},
}

return {
	OUTPUTS = OUTPUTS,
	run = function(options: { keepImport: boolean? }?)
		local results, report, imported = Assemble.run("MathMoney_All", OUTPUTS)
		local missing = 0
		for _, line in report do
			if string.sub(line, 1, 7) == "MISSING" then
				missing += 1
			end
		end
		if missing == 0 and not (options and options.keepImport) then
			-- remove the raw import (top-level model the importer created)
			local roots = {}
			for _, part in imported do
				local top = part
				while top.Parent and top.Parent ~= workspace do
					top = top.Parent
				end
				roots[top] = true
			end
			for root in roots do
				if root ~= workspace and root.Parent == workspace then
					root:Destroy()
				end
			end
		end
		return results, report
	end,
}
