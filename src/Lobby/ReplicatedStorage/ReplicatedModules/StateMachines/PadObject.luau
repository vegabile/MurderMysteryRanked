local PadObject = {}
PadObject.__index = PadObject

export type State = "Open" | "Ready" | "Popped"

export type Snapshot = {
	side1: { Player },
	side2: { Player },
}

type Fields = {
	RequiredPerSide: number,
	Side1: { Player },
	Side2: { Player },
	State: State,
}

export type PadObject = typeof(setmetatable({} :: Fields, PadObject))

local function indexOf(array: { Player }, player: Player): number?
	for index, value in array do
		if value==  player then
			return index
		end
	end
	return nil
end

local function recomputeState(self: PadObject)
	if self.State==  "Popped" then
		return
	end
	if #self.Side1==  self.RequiredPerSide and #self.Side2==  self.RequiredPerSide then
		self.State = "Ready"
	else
		self.State = "Open"
	end
end

function PadObject.new(requiredPerSide: number): PadObject
	assert(
		type(requiredPerSide)==  "number" and requiredPerSide > 0 and requiredPerSide % 1==  0,
		"requiredPerSide must be a positive integer"
	)
	return setmetatable({
		RequiredPerSide = requiredPerSide,
		Side1 = {},
		Side2 = {},
		State = "Open" :: State,
	}, PadObject)
end

function PadObject:addPlayer(player: Player, side: number): boolean
	if self.State==  "Popped" then
		return false
	end
	if side ~= 1 and side ~= 2 then
		return false
	end

	local target = if side==  1 then self.Side1 else self.Side2
	local other = if side==  1 then self.Side2 else self.Side1

	if indexOf(target, player) then
		return true
	end
	if #target==  self.RequiredPerSide then
		return false
	end

	local otherIndex = indexOf(other, player)
	if otherIndex then
		table.remove(other, otherIndex)
	end

	table.insert(target, player)
	recomputeState(self)
	return true
end

function PadObject:removePlayer(player: Player): boolean
	if self.State==  "Popped" then
		return false
	end

	local index1 = indexOf(self.Side1, player)
	if index1 then
		table.remove(self.Side1, index1)
		recomputeState(self)
		return true
	end

	local index2 = indexOf(self.Side2, player)
	if index2 then
		table.remove(self.Side2, index2)
		recomputeState(self)
		return true
	end

	return false
end

function PadObject:Pop(): Snapshot?
	if self.State ~= "Ready" then
		return nil
	end

	self.State = "Popped"
	return {
		side1 = table.clone(self.Side1),
		side2 = table.clone(self.Side2),
	}
end

return PadObject
