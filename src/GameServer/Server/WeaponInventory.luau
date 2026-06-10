--!strict

local Players = game:GetService("Players")

local WeaponInventory = {}

export type Slot = "Gun" | "Knife"

type Loadout = { [Slot]: Instance? }

local WEAPONS_SOURCE: Instance? = nil

local SLOTS: { Slot } = { "Gun", "Knife" }
local inventories: { [Player]: Loadout } = {}

local initialized = false

local function getLoadout(player: Player): Loadout
	local loadout = inventories[player]
	if loadout == nil then
		loadout = {}
		inventories[player] = loadout
	end
	return loadout
end

local function getBackpack(player: Player): Instance?
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack == nil then
		warn(`WeaponInventory: {player.Name} has no Backpack`)
		return nil
	end
	return backpack
end

local function getTemplate(slot: Slot): Instance?
	local source = WEAPONS_SOURCE
	if source == nil then
		warn(`WeaponInventory: WEAPONS_SOURCE is not set, cannot give {slot}`)
		return nil
	end
	local template = source:FindFirstChild(slot)
	if template == nil then
		warn(`WeaponInventory: no template named "{slot}" in WEAPONS_SOURCE`)
		return nil
	end
	return template
end

local function clearSlot(loadout: Loadout, slot: Slot)
	local existing = loadout[slot]
	if existing ~= nil then
		existing:Destroy()
		loadout[slot] = nil
	end
end

function WeaponInventory.Get(player: Player): Loadout?
	return inventories[player]
end

function WeaponInventory.Has(player: Player, slot: Slot): boolean
	local loadout = inventories[player]
	return loadout ~= nil and loadout[slot] ~= nil
end

function WeaponInventory.Give(player: Player, slot: Slot): boolean
	local backpack = getBackpack(player)
	if backpack == nil then
		return false
	end
	local template = getTemplate(slot)
	if template == nil then
		return false
	end
	local loadout = getLoadout(player)
	clearSlot(loadout, slot)
	local clone = template:Clone()
	clone.Parent = backpack
	loadout[slot] = clone
	return true
end

function WeaponInventory.GiveAll(player: Player): boolean
	local backpack = getBackpack(player)
	if backpack == nil then
		return false
	end

	local pending: { { slot: Slot, template: Instance } } = {}
	for i = 1, #SLOTS do
		local slot: Slot = SLOTS[i]
		local template = getTemplate(slot)
		if template == nil then
			return false
		end
		table.insert(pending, { slot = slot, template = template })
	end

	local loadout = getLoadout(player)
	for _, entry in pending do
		clearSlot(loadout, entry.slot)
		local clone = entry.template:Clone()
		clone.Parent = backpack
		loadout[entry.slot] = clone
	end
	return true
end

function WeaponInventory.Take(player: Player, slot: Slot)
	local loadout = inventories[player]
	if loadout ~= nil then
		clearSlot(loadout, slot)
	end
end

function WeaponInventory.TakeAll(player: Player)
	local loadout = inventories[player]
	if loadout ~= nil then
		for i = 1, #SLOTS do
			clearSlot(loadout, SLOTS[i])
		end
		inventories[player] = nil
	end
end

function WeaponInventory.Init()
	if initialized then
		return
	end
	initialized = true

	Players.PlayerRemoving:Connect(function(player)
		WeaponInventory.TakeAll(player)
	end)
end

return WeaponInventory
