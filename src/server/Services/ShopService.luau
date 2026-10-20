--[[
	The shop: buying, equipping and toggling items from Catalog.luau.

	Seeds / decor go into the garden pouch (many at a time). Everything else is
	owned once: costumes equip into their slot, passives and pets switch on, tools
	appear in the backpack. The merchant's ProximityPrompt is added here and the
	client opens the shop UI when it's triggered.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared.Config.Catalog)
local Format = require(Shared.Util.Format)
local Remotes = require(Shared.Remotes)

local ShopService = {}
local services

--- Switch a passive / pet on; items sharing a slot (both pairs of shoes, the pets) swap.
local function wear(p, item)
	if item.slot then
		for _, other in Catalog.ByCategory[item.category] do
			if other.slot == item.slot and other.id ~= item.id then
				p.toggles[other.id] = nil
			end
		end
	end
	p.toggles[item.id] = true
end

local function buy(player: Player, item): (boolean, string)
	if item.exclusive then
		return false, "The " .. item.name .. " is only found inside Frog Plane safes! 🐸✈️"
	end
	local profile = services.DataService:Get(player)
	if not profile then
		return false, "Still loading, try again in a second!"
	end
	local placeable = Catalog.isPlaceable(item)
	if not placeable and profile.owned[item.id] then
		return false, "You already own the " .. item.name .. "!"
	end
	if not services.DataService:Spend(player, item.price) then
		return false, string.format("You need %s more. Go win some at your machines!", Format.money(item.price - profile.money))
	end
	services.DataService:Update(player, function(p)
		if placeable then
			p.pouch[item.id] = (p.pouch[item.id] or 0) + 1
		else
			p.owned[item.id] = true
			if item.kind == "Costume" and item.slot then
				p.equipped[item.slot] = item.id
			elseif item.kind == "Passive" or item.kind == "Pet" then
				wear(p, item)
			end
		end
	end)
	if placeable then
		services.GardenService:RefreshTools(player)
		local verb = if item.kind == "Plant" then "Plant" else "Place"
		return true, string.format("%s added to your pouch! %s it from 🎒 My Stuff.", item.name, verb)
	end
	services.AvatarService:Apply(player)
	return true, "You got the " .. item.name .. "!"
end

local function setEquipped(player: Player, item, on: boolean): (boolean, string)
	local profile = services.DataService:Get(player)
	if not profile or not profile.owned[item.id] then
		return false, "Buy it first!"
	end
	services.DataService:Update(player, function(p)
		if item.kind == "Costume" and item.slot then
			if on then
				p.equipped[item.slot] = item.id
			elseif p.equipped[item.slot] == item.id then
				p.equipped[item.slot] = nil
			end
		elseif item.kind == "Passive" or item.kind == "Pet" then
			if on then
				wear(p, item)
			else
				p.toggles[item.id] = nil
			end
		end
	end)
	services.AvatarService:Apply(player)
	return true, if on then (item.name .. " on!") else (item.name .. " off.")
end

local function addMerchantPrompt()
	local world = workspace:WaitForChild("World", 30)
	local anchor = world and world:FindFirstChild("ShopPrompt", true)
	if not anchor or not anchor:IsA("BasePart") then
		warn("[ShopService] World is missing a ShopPrompt part")
		return
	end
	local prompt = anchor:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.ActionText = "Shop"
	prompt.ObjectText = "Ribbit's Emporium"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpenShop", true)
	prompt.Parent = anchor
end

function ShopService:Init(allServices)
	services = allServices
end

function ShopService:Start()
	Remotes.ShopRequest.OnServerInvoke = function(player: Player, action: any, itemId: any)
		local item = typeof(itemId) == "string" and Catalog.get(itemId)
		if not item then
			return false, "That item doesn't exist."
		end
		if action == "Buy" then
			return buy(player, item)
		elseif action == "Equip" then
			return setEquipped(player, item, true)
		elseif action == "Unequip" then
			return setEquipped(player, item, false)
		end
		return false, "Unknown request"
	end
	task.spawn(addMerchantPrompt)
end

return ShopService
