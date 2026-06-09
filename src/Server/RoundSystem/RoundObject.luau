local RoundObject = {}
RoundObject.__index = RoundObject

export type PlayerInfoObject = {
	Kills: number,
	Deaths: number,
	isAlive: boolean,
}

export type RoundState = "PRE_GAME" | "GAME" | "IN_BETWEEN" | "POST_GAME"

type RoundFields = {
	Team1: { [Player]: PlayerInfoObject },
	Team2: { [Player]: PlayerInfoObject },
	RoundUpdated: { Player },
	State: RoundState,
}

export type RoundObject = typeof(setmetatable({} :: RoundFields, RoundObject))

RoundObject.States = {
	PRE_GAME = "PRE_GAME" :: RoundState,
	GAME = "GAME" :: RoundState,
	IN_BETWEEN = "IN_BETWEEN" :: RoundState,
	POST_GAME = "POST_GAME" :: RoundState,
}

local TRANSITIONS: { [RoundState]: { [RoundState]: boolean } } = {
	PRE_GAME = { GAME = true },
	GAME = { IN_BETWEEN = true, POST_GAME = true },
	IN_BETWEEN = { GAME = true, POST_GAME = true },
	POST_GAME = { PRE_GAME = true },
}

function RoundObject.new(): RoundObject
	return setmetatable({
		Team1 = {},
		Team2 = {},
		RoundUpdated = {},
		State = "PRE_GAME" :: RoundState,
	}, RoundObject)
end

function RoundObject.GetState(self: RoundObject): RoundState
	return self.State
end

function RoundObject.CanTransition(self: RoundObject, target: RoundState): boolean
	return TRANSITIONS[self.State][target] == true
end

function RoundObject.Transition(self: RoundObject, target: RoundState): boolean
	if not self:CanTransition(target) then
		return false
	end
	self.State = target
	return true
end

function RoundObject.AddPlayer(self: RoundObject, player: Player, team: number): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	if team ~= 1 and team ~= 2 then
		return false
	end
	if self.Team1[player] or self.Team2[player] then
		return false
	end
	local info: PlayerInfoObject = {
		Kills = 0,
		Deaths = 0,
		isAlive = true,
	}
	if team == 1 then
		self.Team1[player] = info
	else
		self.Team2[player] = info
	end
	table.insert(self.RoundUpdated, player)
	return true
end

function RoundObject.RemovePlayer(self: RoundObject, player: Player): boolean
	if not (self.Team1[player] or self.Team2[player]) then
		return false
	end
	self.Team1[player] = nil
	self.Team2[player] = nil
	for index, rosterPlayer in self.RoundUpdated do
		if rosterPlayer == player then
			table.remove(self.RoundUpdated, index)
			break
		end
	end
	return true
end

function RoundObject.GetPlayerInfo(self: RoundObject, player: Player): PlayerInfoObject?
	return self.Team1[player] or self.Team2[player]
end

function RoundObject.LogPlayerInfo(self: RoundObject, player: Player, info: PlayerInfoObject): boolean
	local entry = self.Team1[player] or self.Team2[player]
	if not entry then
		return false
	end
	if type(info) ~= "table" then
		return false
	end
	if type(info.Kills) ~= "number" or type(info.Deaths) ~= "number" or type(info.isAlive) ~= "boolean" then
		return false
	end
	entry.Kills = info.Kills
	entry.Deaths = info.Deaths
	entry.isAlive = info.isAlive
	return true
end

return RoundObject
