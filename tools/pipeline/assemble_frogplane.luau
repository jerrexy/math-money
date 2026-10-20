--[[
	The Frog Plane event's models (tools/blender/build_frogplane.py) are their own
	FBX bundle, so adding them never re-uploads the rest of the game. After
	importing assets/meshes/MathMoney_FrogPlane.fbx with Studio's 3D Importer, run
	this through the dev server (see tools/pipeline/README.md):

	    loadstring(game:GetService("HttpService"):GetAsync(
	        "http://127.0.0.1:8765/tools/pipeline/assemble_frogplane.luau"))().run()

	It writes assets/models/replicated/FrogPlane.rbxm, which Rojo syncs to
	ReplicatedStorage.Assets.FrogPlane, and removes the raw import afterwards.
]]

local HttpService = game:GetService("HttpService")
local BASE = "http://127.0.0.1:8765/"

local Assemble = loadstring(HttpService:GetAsync(BASE .. "tools/pipeline/assemble_import.luau", true))()

local OUTPUTS = {
	["assets/models/replicated/FrogPlane.rbxm"] = {
		folder = "FrogPlane",
		prefabs = { "FrogPlane", "FrogSafe", "Parachute", "FrogPilotCap", "ParachutePack", "BabyFrog", "GoldenFrogStatue", "LilyPond" },
	},
}

return {
	OUTPUTS = OUTPUTS,
	run = function(options: { keepImport: boolean? }?)
		local results, report, imported = Assemble.run("MathMoney_FrogPlane", OUTPUTS)
		local missing = 0
		for _, line in report do
			if string.sub(line, 1, 7) == "MISSING" then
				missing += 1
			end
		end
		if missing == 0 and not (options and options.keepImport) then
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
