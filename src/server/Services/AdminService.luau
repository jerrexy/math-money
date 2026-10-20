--[[
	Admin chat commands, for the game's owner and the ADMINS below.

	  !cash 5000    give yourself money ("$5,000", "2.5k" and "1m" work too)

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
	if not AdminService:IsAdmin(player) then
		Remotes.Notify:FireClient(player, "Nice try! 😄 Money comes from the math machines.", "info")
		return
	end
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

function AdminService:Init(allServices)
	services = allServices
end

function AdminService:Start()
	local command = Instance.new("TextChatCommand")
	command.Name = "MM_CashCommand"
	command.PrimaryAlias = "!cash"
	command.AutocompleteVisible = false
	command.Triggered:Connect(function(source: TextSource, text: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		if player then
			cash(player, text)
		end
	end)
	command.Parent = TextChatService
end

return AdminService
