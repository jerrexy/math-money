--[[
	Player save data.

	One DataStore key per player, written with UpdateAsync and a simple session
	lock so two servers never fight over the same save. Data autosaves, saves on
	leave and on shutdown. In Studio without API access (e.g. an unpublished
	place) it falls back to in-memory data so the game is still playable.

	Other services change data only through DataService:Update(player, fn), which
	also pushes the public copy to the client and refreshes leaderstats.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Machines = require(Shared.Config.Machines)
local Remotes = require(Shared.Remotes)

local STORE_NAME = "MathMoney_Players_v1"
local AUTOSAVE_SECONDS = 90
local LOCK_STALE_SECONDS = 600
local SAVE_VERSION = 1

local DataService = {}

type Profile = { [string]: any }

local profiles: { [Player]: Profile } = {}
local loading: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}
local pushQueued: { [Player]: boolean } = {}
local store: DataStore? = nil
local memoryOnly = false

local changedEvent = Instance.new("BindableEvent")
--- Fires (player, profile) after any change.
DataService.Changed = changedEvent.Event
local loadedEvent = Instance.new("BindableEvent")
--- Fires (player, profile) once a player's data is ready.
DataService.Loaded = loadedEvent.Event

local function defaultProfile(): Profile
	local machines = {}
	for _, id in Machines.Order do
		machines[id] = { level = 1, xp = 0, correct = 0, wrong = 0, rounds = 0, wins = 0, best = 0 }
	end
	return {
		version = SAVE_VERSION,
		money = Economy.StartingMoney,
		totalEarned = 0,
		machines = machines,
		pouch = {}, -- seeds / decor waiting to be planted: [itemId] = count
		owned = {}, -- one-off purchases: [itemId] = true
		equipped = {}, -- costume slots: Hat / Face / Waist -> itemId
		toggles = {}, -- passives & pets switched on: [itemId] = true
		garden = {}, -- { id, item, x, z, r, t } in plot space
		facts = {}, -- [factKey] = { c = correct, w = wrong }
		stats = { questions = 0, correct = 0, rounds = 0, safes = 0 },
		firstJoin = os.time(),
	}
end

--- Fill in anything missing from an older save without touching existing values.
local function reconcile(target: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if target[key] == nil then
			target[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(target[key]) == "table" then
			reconcile(target[key], value)
		end
	end
end

local function publicCopy(profile: Profile): Profile
	local copy = table.clone(profile)
	copy.lock = nil
	return copy
end

local function updateLeaderstats(player: Player, profile: Profile)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local money = Instance.new("IntValue")
		money.Name = "Money"
		money.Parent = stats
		stats.Parent = player
	end
	stats.Money.Value = profile.money
	player:SetAttribute("Money", profile.money)
end

local function pushToClient(player: Player)
	if pushQueued[player] then
		return
	end
	pushQueued[player] = true
	task.defer(function()
		pushQueued[player] = nil
		local profile = profiles[player]
		if profile and player.Parent then
			Remotes.DataChanged:FireClient(player, publicCopy(profile))
			updateLeaderstats(player, profile)
		end
	end)
end

local function withRetries<T>(label: string, fn: () -> T): (boolean, T?)
	local lastErr
	for attempt = 1, 4 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(attempt * 1.5)
	end
	warn("[DataService] " .. label .. " failed: " .. tostring(lastErr))
	return false, nil
end

local function key(player: Player): string
	return "player_" .. player.UserId
end

local function loadFromStore(player: Player): Profile?
	if memoryOnly or not store then
		return defaultProfile()
	end
	local result: Profile? = nil
	for attempt = 1, 5 do
		local lockedElsewhere = false
		local ok = withRetries("load " .. player.Name, function()
			return (store :: DataStore):UpdateAsync(key(player), function(old: Profile?)
				local data = old or defaultProfile()
				local lock = data.lock
				local stale = lock == nil or os.time() - (lock.time or 0) > LOCK_STALE_SECONDS
				if lock and lock.job ~= game.JobId and not stale and attempt < 5 then
					lockedElsewhere = true
					return nil -- keep the other server's lock; we'll retry
				end
				data.lock = { job = game.JobId, time = os.time() }
				result = data
				return data
			end)
		end)
		if not ok then
			return nil
		end
		if not lockedElsewhere then
			break
		end
		task.wait(3) -- the previous server is probably still saving
	end
	return result
end

local function saveToStore(player: Player, release: boolean)
	local profile = profiles[player]
	if not profile or memoryOnly or not store then
		return
	end
	local snapshot = table.clone(profile)
	withRetries("save " .. player.Name, function()
		return (store :: DataStore):UpdateAsync(key(player), function(old: Profile?)
			if old and old.lock and old.lock.job ~= game.JobId then
				return nil -- another server owns this save now; don't clobber it
			end
			snapshot.lock = if release then nil else { job = game.JobId, time = os.time() }
			return snapshot
		end)
	end)
	dirty[player] = nil
end

local function onPlayerAdded(player: Player)
	loading[player] = true
	local profile = loadFromStore(player)
	loading[player] = nil
	if not player.Parent then
		return
	end
	if not profile then
		player:Kick("Math Money couldn't load your save right now. Please try again in a minute!")
		return
	end
	reconcile(profile, defaultProfile())
	profile.version = SAVE_VERSION
	profile.lastJoin = os.time()
	profiles[player] = profile
	updateLeaderstats(player, profile)
	pushToClient(player)
	loadedEvent:Fire(player, profile)
end

local function onPlayerRemoving(player: Player)
	if profiles[player] then
		saveToStore(player, true)
	end
	profiles[player] = nil
	dirty[player] = nil
end

function DataService:Init()
	local ok, result = pcall(function()
		local ds = DataStoreService:GetDataStore(STORE_NAME)
		ds:GetAsync("__probe") -- fails fast in Studio when API access is off
		return ds
	end)
	if ok then
		store = result
	else
		memoryOnly = true
		warn(
			"[DataService] DataStores unavailable (" .. tostring(result) .. ").\n"
				.. "Progress won't be saved in this session. Publish the place and turn on "
				.. "'Enable Studio Access to API Services' to test saving in Studio."
		)
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player in profiles do
				if dirty[player] then
					task.spawn(saveToStore, player, false)
				end
			end
		end
	end)

	-- Studio-only testing hook: ServerStorage.MM_DevGrant:Invoke(userId, amount)
	if RunService:IsStudio() then
		local grant = Instance.new("BindableFunction")
		grant.Name = "MM_DevGrant"
		grant.OnInvoke = function(userId: number, amount: number)
			local player = Players:GetPlayerByUserId(userId)
			if player and profiles[player] then
				self:AddMoney(player, amount)
				return profiles[player].money
			end
			return nil
		end
		grant.Parent = game:GetService("ServerStorage")
	end

	game:BindToClose(function()
		if RunService:IsStudio() and memoryOnly then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				saveToStore(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

--- The player's live profile table (read-only use; write through Update).
function DataService:Get(player: Player): Profile?
	return profiles[player]
end

--- Wait until a player's data is loaded (or they leave). Returns the profile or nil.
function DataService:WaitFor(player: Player): Profile?
	while player.Parent and not profiles[player] do
		task.wait(0.1)
	end
	return profiles[player]
end

--- Change a player's data. ``fn`` receives the profile and may return a value.
function DataService:Update(player: Player, fn: (Profile) -> any): any
	local profile = profiles[player]
	if not profile then
		return nil
	end
	local result = fn(profile)
	dirty[player] = true
	changedEvent:Fire(player, profile)
	pushToClient(player)
	return result
end

--- Pay a player. Pass ``earned = false`` for money that wasn't won at a machine
--- (admin gifts), so the Report Card's "earned in total" stays honest.
function DataService:AddMoney(player: Player, amount: number, earned: boolean?)
	amount = math.floor(amount)
	if amount <= 0 then
		return
	end
	self:Update(player, function(profile)
		profile.money += amount
		if earned ~= false then
			profile.totalEarned += amount
		end
	end)
end

--- Take money if the player can afford it. Returns true on success.
function DataService:Spend(player: Player, amount: number): boolean
	return self:Update(player, function(profile)
		if profile.money < amount then
			return false
		end
		profile.money -= amount
		return true
	end) == true
end

function DataService:IsMemoryOnly(): boolean
	return memoryOnly
end

return DataService
