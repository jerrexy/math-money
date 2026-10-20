--[[
	Studio-side helpers for the Blender -> Roblox pipeline (run through the dev
	server from the MCP / command bar):

	  previewPrefab(name)      the prefab built from in-memory EditableMeshes; nothing
	                           is uploaded, so it's a quick visual check (not savable)
	  placeholderPrefab(name)  box-shaped stand-in with the real part names/markers,
	                           for testing gameplay before the art is imported
	  importPrefab(name)       rebuild a prefab from the mesh ids recorded in
	                           assets/meshes/asset_ids.json (after an Import 3D run)
	  saveRbxm(instances, path)  serialize instances into a .rbxm file in the repo
]]

local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")

local BASE = "http://127.0.0.1:8765/"
local ID_FILE = "assets/meshes/asset_ids.json"

local function get(path: string): string
	return HttpService:GetAsync(BASE .. path, true)
end

local function getJson(path: string): any
	return HttpService:JSONDecode(get(path))
end

local function loadIds(): { [string]: { id: number, name: string } }
	local ok, result = pcall(getJson, ID_FILE)
	return if ok and type(result) == "table" then result else {}
end

local function buildEditableMesh(data): EditableMesh
	local em = AssetService:CreateEditableMesh()
	local pos, nrm, uv, col, tri = data.pos, data.nrm, data.uv, data.col, data.tri
	local count = #pos // 3
	local positions, normals, uvs = table.create(count), table.create(count), table.create(count)
	for i = 0, count - 1 do
		positions[i + 1] = Vector3.new(pos[3 * i + 1], pos[3 * i + 2], pos[3 * i + 3])
		normals[i + 1] = Vector3.new(nrm[3 * i + 1], nrm[3 * i + 2], nrm[3 * i + 3])
		uvs[i + 1] = Vector2.new(uv[2 * i + 1], uv[2 * i + 2])
	end
	local vIds = em:BatchAdd(Enum.MeshAttribute.Vertex, positions)
	local nIds = em:BatchAdd(Enum.MeshAttribute.Normal, normals)
	local uIds = em:BatchAdd(Enum.MeshAttribute.UV, uvs)
	local cIds
	if col then
		local colors, alphas = table.create(count), table.create(count, 1)
		for i = 0, count - 1 do
			colors[i + 1] = Color3.fromRGB(col[3 * i + 1], col[3 * i + 2], col[3 * i + 3])
		end
		cIds = em:BatchAdd(Enum.MeshAttribute.Color, colors, alphas)
	end
	for t = 0, #tri // 3 - 1 do
		local a, b, c = tri[3 * t + 1] + 1, tri[3 * t + 2] + 1, tri[3 * t + 3] + 1
		local face = em:AddTriangle(vIds[a], vIds[b], vIds[c])
		em:SetFaceNormals(face, { nIds[a], nIds[b], nIds[c] })
		em:SetFaceUVs(face, { uIds[a], uIds[b], uIds[c] })
		if cIds then
			em:SetFaceColors(face, { cIds[a], cIds[b], cIds[c] })
		end
		if t % 3000 == 2999 then
			task.wait()
		end
	end
	return em
end

local function newMeshPart(assetId: number, collision: string): MeshPart
	local lastErr
	for _ = 1, 15 do
		local ok, part = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromAssetId(assetId), {
				CollisionFidelity = Enum.CollisionFidelity[collision] or Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Precise,
			})
		end)
		if ok then
			return part
		end
		lastErr = part
		task.wait(2)
	end
	error("CreateMeshPartAsync failed for " .. assetId .. ": " .. tostring(lastErr))
end

--- Build the Model for a prefab. Returns the (unparented) Model.
local function assemble(manifest, ids): Model
	local model = Instance.new("Model")
	model.Name = manifest.name
	local groups: { [string]: Model } = {}
	local function groupFor(name: string): Instance
		if name == "" then
			return model
		end
		local g = groups[name]
		if not g then
			g = Instance.new("Model")
			g.Name = name
			g.Parent = model
			groups[name] = g
		end
		return g
	end
	for _, p in manifest.parts do
		local entry = ids[p.hash]
		assert(entry, "missing asset id for " .. p.name)
		local mp = newMeshPart(entry.id, p.collision)
		mp.Name = p.name
		mp.Anchored = true
		mp.CanCollide = p.canCollide
		mp.CanTouch = false
		mp.CastShadow = p.castShadow
		mp.Material = Enum.Material[p.material]
		mp.Color = Color3.fromRGB(p.color[1], p.color[2], p.color[3])
		mp.Transparency = p.transparency
		mp.Reflectance = p.reflectance
		mp.CFrame = CFrame.new(p.center[1], p.center[2], p.center[3])
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

--- Serialize instances to .rbxm and write them into the repo through the dev server.
local function saveRbxm(instances: { Instance }, repoPath: string)
	local SerializationService = game:GetService("SerializationService")
	local EncodingService = game:GetService("EncodingService")
	local data = SerializationService:SerializeInstancesAsync(instances)
	local b64 = buffer.tostring(EncodingService:Base64Encode(data))
	HttpService:PostAsync(
		BASE .. "save?b64=1&path=" .. HttpService:UrlEncode(repoPath),
		b64,
		Enum.HttpContentType.TextPlain
	)
	return buffer.len(data)
end

return {
	get = get,
	getJson = getJson,
	loadIds = loadIds,

	--- importPrefab("Apparatus") -> Model rebuilt from recorded mesh ids
	importPrefab = function(name: string)
		local manifest = getJson("build/prefabs/" .. name .. ".json")
		local ids = loadIds()
		for _, part in manifest.parts do
			if not ids[part.hash] then
				error(name .. "." .. part.name .. " has no recorded mesh id; import the FBX and run assemble_all first")
			end
		end
		return assemble(manifest, ids)
	end,

	saveRbxm = saveRbxm,

	--- placeholderPrefab("Apparatus") -> the prefab rebuilt from plain box Parts (each
	--- mesh's bounding box) with the real names, groups and markers. Lets gameplay
	--- code be tested in Play mode before the meshes are imported.
	placeholderPrefab = function(name: string): Model
		local manifest = getJson("build/prefabs/" .. name .. ".json")
		local model = Instance.new("Model")
		model.Name = name
		local groups = {}
		for _, p in manifest.parts do
			local part = Instance.new("Part")
			part.Name = p.name
			part.Anchored = true
			part.Size = Vector3.new(p.size[1], p.size[2], p.size[3])
			part.CFrame = CFrame.new(p.center[1], p.center[2], p.center[3])
			part.Material = Enum.Material[p.material]
			part.Color = Color3.fromRGB(p.color[1], p.color[2], p.color[3])
			part.CanCollide = false
			part.Transparency = math.max(p.transparency, if p.name == "FrameWood" or p.name == "Vat" then 0.6 else 0)
			local parent: Instance = model
			if p.group ~= "" then
				groups[p.group] = groups[p.group] or Instance.new("Model")
				groups[p.group].Name = p.group
				groups[p.group].Parent = model
				parent = groups[p.group]
			end
			part.Parent = parent
		end
		local folder = Instance.new("Folder")
		folder.Name = "Markers"
		for markerName, m in manifest.markers do
			local value = Instance.new("CFrameValue")
			value.Name = markerName
			value.Value = CFrame.new(table.unpack(m))
			value.Parent = folder
		end
		folder.Parent = model
		model.WorldPivot = CFrame.new()
		return model
	end,

	--- previewPrefab("Apparatus") -> Model built from in-memory EditableMeshes (nothing
	--- is uploaded). Handy for checking a model before spending uploads on it; the
	--- preview can't be saved with the place.
	previewPrefab = function(name: string): Model
		local manifest = getJson("build/prefabs/" .. name .. ".json")
		local model = Instance.new("Model")
		model.Name = name .. "_Preview"
		for _, p in manifest.parts do
			local em = buildEditableMesh(getJson(p.mesh))
			local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
			mp.Name = p.name
			mp.Anchored = true
			mp.Material = Enum.Material[p.material]
			mp.Color = Color3.fromRGB(p.color[1], p.color[2], p.color[3])
			mp.Transparency = p.transparency
			mp.CFrame = CFrame.new(p.center[1], p.center[2], p.center[3])
			mp.Parent = model
		end
		model.WorldPivot = CFrame.new()
		return model
	end,
}
