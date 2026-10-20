--[[
	Admin chat commands, for the game's owner and the ADMINS below.

	  !cash 5000    give yourself money ("$5,000", "2.5k" and "1m" work too)
	  !plane        send the Frog Plane right now

	Each command is a TextChatCommand, so the message is never shown in anyone's
	chat. Admin money doesn't count as "earned" on the Report Card.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

-- UserIds that can use admin commands (the game's owner always can)
local ADMINS = {
	[201700669] = true, -- jerxyyi
}
local MAX_CASH = 1000000000 -- per command, so the money counter stays readable
local SUFFIXES = { k = 1000, m = 1000000 }

local AdminService = {}
local services

--- "$5,000" / "5000" / "2.5k" / "1m" -> 5000 / 5000 / 2500 / 1000000
local function parseAmount(text: string): number?
	local cleaned = text:lower():gsub("[%$,]", "")
	local digits, suffix = cleaned:match("^(%d*%.?%d+)([km]?)$")
	local amount = digits and math.floor(tonumber(digits) * (SUFFIXES[suffix] or 1))
	if not amount or amount < 1 then
		return nil
	end
	return math.min(amount, MAX_CASH)
end

local function cash(player: Player, text: string)
	local amount = parseAmount(text:match("^%S+%s+(.-)%s*$") or "")
	if not amount then
		Remotes.Notify:FireClient(player, "Try: !cash 5000  (or $5,000, 2.5k, 1m)", "info")
		return
	end
	if not services.DataService:Get(player) then
		Remotes.Notify:FireClient(player, "Still loading, try again in a second!", "info")
		return
	end
	services.DataService:AddMoney(player, amount, false)
	Remotes.Notify:FireClient(player, "💸 Admin cash: +" .. Format.money(amount), "money")
	print(string.format("[Admin] %s gave themselves %s", player.Name, Format.money(amount)))
end

local function plane(player: Player)
	services.FrogPlaneService:LaunchNow()
	Remotes.Notify:FireClient(player, "🐸✈️ Frog Plane on its way!", "success")
	print(string.format("[Admin] %s sent the Frog Plane", player.Name))
end

function AdminService:IsAdmin(player: Player): boolean
	if ADMINS[player.UserId] then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		return ok and rank == 255
	end
	return game.CreatorId > 0 and player.UserId == game.CreatorId
end

--- An admin-only chat command; anyone else just gets ``nope``.
local function addCommand(name: string, alias: string, nope: string, run: (Player, string) -> ())
	local command = Instance.new("TextChatCommand")
	command.Name = name
	command.PrimaryAlias = alias
	command.AutocompleteVisible = false
	command.Triggered:Connect(function(source: TextSource, text: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		if not player then
			return
		end
		if not AdminService:IsAdmin(player) then
			Remotes.Notify:FireClient(player, nope, "info")
			return
		end
		run(player, text)
	end)
	command.Parent = TextChatService
end

function AdminService:Init(allServices)
	services = allServices
end

function AdminService:Start()
	addCommand("MM_CashCommand", "!cash", "Nice try! 😄 Money comes from the math machines.", cash)
	addCommand("MM_PlaneCommand", "!plane", "Nice try! 😄 Watch the sky, the Frog Plane comes every few minutes.", plane)
end

return AdminService
