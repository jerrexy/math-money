--[[
	Fire-and-forget sound effects (2D for UI, 3D at a world position) plus the
	background music loop. Ids live in Shared/Config/Sounds.luau.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage:WaitForChild("Shared").Config.Sounds)

local SoundController = {}

local function def(name: string)
	local entry = Sounds[name]
	if entry and entry.id ~= "" and entry.id ~= "rbxassetid://0" then
		return entry
	end
	return nil
end

--- Play a named sound. With ``position`` it plays in 3D at that spot.
function SoundController.play(name: string, position: Vector3?, volume: number?, pitch: number?)
	local entry = def(name)
	if not entry then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = entry.id
	sound.Volume = (volume or 0.6) * (entry.volume or 1) / 0.6
	sound.PlaybackSpeed = pitch or 1
	local holder: Instance
	if position then
		local att = Instance.new("Attachment")
		att.WorldPosition = position
		att.Parent = workspace.Terrain
		sound.RollOffMaxDistance = 140
		sound.RollOffMinDistance = 12
		sound.Parent = att
		holder = att
	else
		sound.Parent = SoundService
		holder = sound
	end
	sound.Ended:Once(function()
		holder:Destroy()
	end)
	local life = entry.max or 12
	task.delay(life, function()
		if holder.Parent then
			holder:Destroy()
		end
	end)
	sound:Play()
end

--- A looping sound attached to a part (chain rattling etc). Returns the Sound.
function SoundController.loop(name: string, parent: Instance, volume: number?): Sound?
	local entry = def(name)
	if not entry then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = entry.id
	sound.Looped = true
	sound.Volume = volume or entry.volume or 0.4
	sound.RollOffMaxDistance = 120
	sound.RollOffMinDistance = 10
	sound.Parent = parent
	sound:Play()
	return sound
end

function SoundController:Start()
	local music = def("Music")
	if music then
		local sound = Instance.new("Sound")
		sound.Name = "Music"
		sound.SoundId = music.id
		sound.Looped = true
		sound.Volume = music.volume or 0.16
		sound.Parent = SoundService
		sound:Play()
	end
end

return SoundController
