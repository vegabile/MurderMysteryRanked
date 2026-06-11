--!strict

local Players = game:GetService("Players")

local WeaponInventory = {}

export type Slot = "Gun" | "Knife"

type Loadout = { [Slot]: Instance? }

local weaponsSource: Instance? = nil

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
	local source = weaponsSource
	if source == nil then
		warn(`WeaponInventory: weapon source is not set, cannot give {slot}`)
		return nil
	end
	local template = source:FindFirstChild(slot)
	if template == nil then
		warn(`WeaponInventory: no template named "{slot}" in weapon source`)
		return nil
	end
	if not template:IsA("Tool") then
		warn(`WeaponInventory: template "{slot}" is not a Tool`)
		return nil
	end
	return template
end

local function clearSlot(loadout: Loadout, slot: Slot)
	local existing = loadout[slot]
	if existing ~= nil then
		loadout[slot] = nil
		existing:Destroy()
	end
end

function WeaponInventory.SetSource(source: Instance?)
	weaponsSource = source
end

function WeaponInventory.Get(player: Player): Loadout?
	local loadout = inventories[player]
	if loadout == nil then
		return nil
	end
	return table.clone(loadout)
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
	local clone: Instance? = template:Clone()
	if clone == nil then
		warn(`WeaponInventory: failed to clone template for {slot}`)
		return false
	end
	local loadout = getLoadout(player)
	local previous = loadout[slot]
	local clone = template:Clone()
	loadout[slot] = clone
	clone.Parent = backpack
	if previous ~= nil then
		previous:Destroy()
	end
	return true
end

function WeaponInventory.GiveAll(player: Player): boolean
	local backpack = getBackpack(player)
	if backpack == nil then
		return false
	end

	local pending: { { slot: Slot, clone: Instance } } = {}
	for i = 1, #SLOTS do
		local slot: Slot = SLOTS[i]
		local template = getTemplate(slot)
		if template == nil then
			for _, entry in pending do
				entry.clone:Destroy()
			end
			return false
		end
		local clone: Instance? = template:Clone()
		if clone == nil then
			warn(`WeaponInventory: failed to clone template for {slot}`)
			for _, entry in pending do
				entry.clone:Destroy()
			end
			return false
		end
		table.insert(pending, { slot = slot, clone = clone })
	end

	local loadout = getLoadout(player)
	for _, entry in pending do
		local previous = loadout[entry.slot]
		local clone = entry.template:Clone()
		loadout[entry.slot] = clone
		clone.Parent = backpack
		if previous ~= nil then
			previous:Destroy()
		end
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
