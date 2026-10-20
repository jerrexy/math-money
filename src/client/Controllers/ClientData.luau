--[[
	Client copy of the player's save data (sent by DataService on every change).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local ClientData = {}
ClientData.profile = nil :: { [string]: any }?

local changed = Instance.new("BindableEvent")
--- Fires (profile, previousProfile) whenever new data arrives.
ClientData.Changed = changed.Event

function ClientData:Start()
	Remotes.DataChanged.OnClientEvent:Connect(function(profile)
		local previous = self.profile
		self.profile = profile
		changed:Fire(profile, previous)
	end)
end

--- Waits for the first copy of the data.
function ClientData:Wait(): { [string]: any }
	while not self.profile do
		ClientData.Changed:Wait()
	end
	return self.profile :: { [string]: any }
end

return ClientData
