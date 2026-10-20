--[[
	All networking in one place. The server creates the remotes at startup and the
	client waits for them, so either side can just do ``Remotes.RoundEvent``.

	Server -> client
	  DataChanged(profile)                 the player's public save data
	  Notify(text, style)                  toast message
	  RoundEvent(event, payload)           offer / question / answer / end for the owner
	  MachineFx(machine, fx, payload)      visual effects everyone sees

	Client -> server
	  RoundAction(action, machine, ...)    "Start" level | "Answer" qid value | "Cancel"
	  PlayerAction(action, ...)            "Home" | "Shop" | "Toggle" itemId
	  ShopRequest(action, itemId)          -> ok, message   ("Buy" | "Equip" | "Unequip")
	  GardenRequest(action, ...)           -> ok, message   ("Plant" itemId cframe | "Dig" plantId)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFINITIONS = {
	DataChanged = "RemoteEvent",
	Notify = "RemoteEvent",
	RoundEvent = "RemoteEvent",
	MachineFx = "RemoteEvent",
	RoundAction = "RemoteEvent",
	PlayerAction = "RemoteEvent",
	ShopRequest = "RemoteFunction",
	GardenRequest = "RemoteFunction",
}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
	end
	for name, className in DEFINITIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Remotes = {}

return setmetatable(Remotes, {
	__index = function(_, name: string)
		assert(DEFINITIONS[name], "unknown remote " .. tostring(name))
		local remote = folder:WaitForChild(name)
		rawset(Remotes, name, remote)
		return remote
	end,
}) :: any
