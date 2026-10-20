--[[
	Rebuild prefabs from a 3D-Importer import of an FBX bundle written by
	tools/blender (mm_lib.export_fbx_bundle).

	The importer uploads every mesh and drops MeshParts named "<Prefab>__<Part>"
	into the place. For each prefab this script clones those MeshParts into a fresh
	Model laid out exactly like build/prefabs/<Prefab>.json (sizes, positions,
	materials, colors, collision, markers), records the mesh ids in
	assets/meshes/asset_ids.json and saves the result as .rbxm into the repo, where
	Rojo picks it up.

	Meshes missing from the scene are rebuilt from assets/meshes/asset_ids.json, and
	the importer's orientation is detected automatically (see detectTurn).

	Usage (loaded through the dev server, see tools/pipeline/README.md):
	    local Assemble = loadstring(HttpService:GetAsync(BASE .. "tools/pipeline/assemble_import.luau"))()
	    Assemble.run("MathMoney_All", { ["assets/models/server/Apparatus.rbxm"] = "Apparatus", ... })
]]

local HttpService = game:GetService("HttpService")

local BASE = "http://127.0.0.1:8765/"
local ID_FILE = "assets/meshes/asset_ids.json"

local function getJson(path: string): any
	return HttpService:JSONDecode(HttpService:GetAsync(BASE .. path, true))
end

local function post(path: string, body: string, b64: boolean?)
	HttpService:PostAsync(
		BASE .. "save?" .. (if b64 then "b64=1&" else "") .. "path=" .. HttpService:UrlEncode(path),
		body,
		Enum.HttpContentType.TextPlain
	)
end

local function findImported(prefixes: { [string]: boolean }): { [string]: MeshPart }
	local found = {}
	for _, root in { workspace, game:GetService("ServerStorage"), game:GetService("ReplicatedStorage") } do
		for _, inst in root:GetDescendants() do
			if inst:IsA("MeshPart") then
				local prefab = string.match(inst.Name, "^(.-)__")
				if prefab and prefixes[prefab] and not found[inst.Name] then
					found[inst.Name] = inst
				end
			end
		end
	end
	return found
end

local function idOf(meshPart: MeshPart): number?
	return tonumber(string.match(meshPart.MeshId, "%d+"))
end

--[[
	The 3D Importer may turn meshes around the vertical axis relative to how
	tools/blender exported them (it turned them 180 degrees for this project's FBX).
	Sizes can't reveal a half-turn, so compare each mesh's vertex "center of mass"
	(relative to its bounding-box center) with the exported JSON and pick the
	quarter-turn about Y that best explains the import. One answer for the whole
	bundle, since every mesh went through the same export/import.
]]
local function detectTurn(manifests, imported: { [string]: MeshPart }, report: { string }): number
	local AssetService = game:GetService("AssetService")
	local samples = {}
	for _, manifest in manifests do
		for _, p in manifest.parts do
			local source = imported[manifest.name .. "__" .. p.name]
			if source then
				table.insert(samples, { part = p, source = source })
			end
		end
	end
	local errors = { 0, 0, 0, 0 }
	local used = 0
	for _, sample in samples do
		if used >= 30 then
			break
		end
		local ok, em = pcall(function()
			return AssetService:CreateEditableMeshAsync(Content.fromAssetId(idOf(sample.source) :: number))
		end)
		if not ok or not em then
			continue
		end
		local data = getJson(sample.part.mesh)
		local count = #data.pos // 3
		local expected = Vector3.zero
		for i = 0, count - 1 do
			expected += Vector3.new(data.pos[3 * i + 1], data.pos[3 * i + 2], data.pos[3 * i + 3])
		end
		expected /= count
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		local sum, n = Vector3.zero, 0
		for _, v in em:GetVertices() do
			local pos = em:GetPosition(v)
			sum += pos
			n += 1
			lo, hi = lo:Min(pos), hi:Max(pos)
		end
		em:Destroy()
		if n == 0 then
			continue
		end
		local got = sum / n - (lo + hi) / 2
		local flat = Vector3.new(expected.X, 0, expected.Z)
		if flat.Magnitude < 0.05 then
			continue -- symmetric mesh: tells us nothing
		end
		used += 1
		for k = 0, 3 do
			local turned = CFrame.Angles(0, k * math.pi / 2, 0):VectorToWorldSpace(expected)
			errors[k + 1] += (turned - got).Magnitude
		end
	end
	local best = 1
	for k = 2, 4 do
		if errors[k] < errors[best] then
			best = k
		end
	end
	table.insert(report, string.format("orientation: imported meshes are turned %d degrees (checked %d meshes)", (best - 1) * 90, used))
	return (best - 1) * math.pi / 2
end

local function buildPrefab(manifest, imported: { [string]: MeshPart }, report: { string }, turn: number)
	local model = Instance.new("Model")
	model.Name = manifest.name
	local groups = {}
	local function groupFor(name: string): Instance
		if name == "" then
			return model
		end
		if not groups[name] then
			local g = Instance.new("Model")
			g.Name = name
			g.Parent = model
			groups[name] = g
		end
		return groups[name]
	end
	for _, p in manifest.parts do
		local source = imported[manifest.name .. "__" .. p.name]
		if not source then
			table.insert(report, "MISSING " .. manifest.name .. "__" .. p.name)
			continue
		end
		local want = Vector3.new(p.size[1], p.size[2], p.size[3])
		local got = source.Size
		local ratio = Vector3.new(got.X / math.max(want.X, 1e-3), got.Y / math.max(want.Y, 1e-3), got.Z / math.max(want.Z, 1e-3))
		local spread = math.max(ratio.X, ratio.Y, ratio.Z) - math.min(ratio.X, ratio.Y, ratio.Z)
		if spread > 0.05 * math.max(ratio.X, ratio.Y, ratio.Z) and math.min(want.X, want.Y, want.Z) > 0.05 then
			table.insert(report, string.format("AXIS? %s imported %s want %s", source.Name, tostring(got), tostring(want)))
		end
		local mp = source:Clone()
		mp:ClearAllChildren()
		mp.Name = p.name
		-- undo the importer's turn; quarter turns swap the part's local X/Z extents
		local quarter = math.floor(turn / (math.pi / 2) + 0.5) % 2 == 1
		mp.Size = if quarter then Vector3.new(want.Z, want.Y, want.X) else want
		mp.CFrame = CFrame.new(p.center[1], p.center[2], p.center[3]) * CFrame.Angles(0, -turn, 0)
		mp.Anchored = true
		mp.CanCollide = p.canCollide
		mp.CanTouch = false
		mp.CanQuery = p.canCollide
		mp.CastShadow = p.castShadow
		mp.Material = Enum.Material[p.material]
		mp.Color = Color3.fromRGB(p.color[1], p.color[2], p.color[3])
		mp.Transparency = p.transparency
		mp.Reflectance = p.reflectance
		mp.DoubleSided = false
		pcall(function()
			mp.CollisionFidelity = Enum.CollisionFidelity[p.collision]
		end)
		mp.RenderFidelity = Enum.RenderFidelity.Precise
		for key, value in p.attributes do
			mp:SetAttribute(key, value)
		end
		mp.Parent = groupFor(p.group)
	end
	local names = {}
	for name in manifest.markers do
		table.insert(names, name)
	end
	if #names > 0 then
		table.sort(names)
		local folder = Instance.new("Folder")
		folder.Name = "Markers"
		for _, name in names do
			local value = Instance.new("CFrameValue")
			value.Name = name
			value.Value = CFrame.new(table.unpack(manifest.markers[name]))
			value.Parent = folder
		end
		folder.Parent = model
	end
	for _, g in groups do
		g.WorldPivot = CFrame.new()
	end
	model.WorldPivot = CFrame.new()
	return model
end

local function saveRbxm(instances: { Instance }, repoPath: string): number
	local data = game:GetService("SerializationService"):SerializeInstancesAsync(instances)
	post(repoPath, buffer.tostring(game:GetService("EncodingService"):Base64Encode(data)), true)
	return buffer.len(data)
end

local function recordIds(manifests, imported)
	local ok, ids = pcall(getJson, ID_FILE)
	ids = if ok and type(ids) == "table" then ids else {}
	for _, manifest in manifests do
		for _, p in manifest.parts do
			local mp = imported[manifest.name .. "__" .. p.name]
			local id = mp and idOf(mp)
			if id then
				ids[p.hash] = { id = id, name = manifest.name .. "__" .. p.name }
			end
		end
	end
	local keys = {}
	for k in ids do
		table.insert(keys, k)
	end
	table.sort(keys)
	local lines = {}
	for _, k in keys do
		table.insert(lines, string.format('  "%s": {"id": %d, "name": "%s"}', k, ids[k].id, ids[k].name))
	end
	post(ID_FILE, "{\n" .. table.concat(lines, ",\n") .. "\n}\n")
end

return {
	findImported = findImported,
	buildPrefab = buildPrefab,
	saveRbxm = saveRbxm,

	--- Build prefabs from an imported bundle. ``outputs`` maps an output .rbxm path to
	--- either a prefab name (saved as that Model) or {folder = "Name", prefabs = {...}}
	--- (saved as a Folder of Models). Returns built instances + a report.
	run = function(bundle: string, outputs: { [string]: any })
		local info = getJson("build/fbx_" .. bundle .. ".json")
		local prefixes = {}
		for _, name in info.prefabs do
			prefixes[name] = true
		end
		local imported = findImported(prefixes)
		local report = {}
		local manifests, built = {}, {}
		for _, name in info.prefabs do
			manifests[name] = getJson("build/prefabs/" .. name .. ".json")
		end
		-- anything not in the scene comes from the recorded mesh ids, so prefabs can be
		-- re-assembled (new colors, materials, markers...) without importing again
		local AssetService = game:GetService("AssetService")
		local okIds, ids = pcall(getJson, ID_FILE)
		ids = if okIds and type(ids) == "table" then ids else {}
		local rebuilt = 0
		for _, manifest in manifests do
			for _, p in manifest.parts do
				local key = manifest.name .. "__" .. p.name
				if not imported[key] and ids[p.hash] then
					local ok, part = pcall(function()
						return AssetService:CreateMeshPartAsync(Content.fromAssetId(ids[p.hash].id))
					end)
					if ok then
						part.Name = key
						imported[key] = part
						rebuilt += 1
					end
				end
			end
		end
		if rebuilt > 0 then
			table.insert(report, rebuilt .. " meshes rebuilt from assets/meshes/asset_ids.json")
		end
		local turn = detectTurn(manifests, imported, report)
		for _, name in info.prefabs do
			built[name] = buildPrefab(manifests[name], imported, report, turn)
		end
		recordIds(manifests, imported)
		local results = {}
		for path, spec in outputs do
			local root
			if type(spec) == "string" then
				root = built[spec]
			else
				root = Instance.new("Folder")
				root.Name = spec.folder
				for _, name in spec.prefabs do
					built[name].Parent = root
				end
			end
			local bytes = saveRbxm({ root }, path)
			table.insert(report, string.format("saved %s (%d bytes)", path, bytes))
			results[path] = root
		end
		return results, report, imported
	end,
}
