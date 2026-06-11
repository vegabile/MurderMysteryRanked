local RoundObject = {}
RoundObject.__index = RoundObject

export type PlayerInfoObject = {
	Kills: number,
	Deaths: number,
	isAlive: boolean,
}

export type RoundState = "PRE_GAME" | "GAME" | "IN_BETWEEN" | "POST_GAME"

export type Mode = "1v1" | "2v2" | "3v3" | "4v4" | "FFA"

export type RoundStatus = "Ongoing" | "Awarded"

export type RoundOutcome = {
	Status: RoundStatus,
	TeamIndex: number?,
}

type TeamState = {
	Eliminated: boolean,
	EliminationOrder: number?,
}

type Team = { [Player]: PlayerInfoObject }

type RoundFields = {
	Teams: { Team },
	Points: { number },
	RoundUpdated: { Player },
	State: RoundState,
	WinningScore: number,
	DeathCounter: number,
	LastDeathOrder: { number? },
}

export type RoundObject = typeof(setmetatable({} :: RoundFields, RoundObject))

RoundObject.DefaultTeamCount = 2
RoundObject.DefaultWinningScore = 5
RoundObject.DefaultMapLoadTimeout = 10
RoundObject.MapLoadGateEnabled = false

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

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value > 0 and value % 1 == 0
end

local function isPositiveNumber(value: any): boolean
	return type(value) == "number" and value > 0 and value == value and value ~= math.huge
end

local function isNonNegativeInteger(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value >= 0 and value % 1 == 0
end

local function findTeamIndex(self: RoundObject, player: Player): number?
	for index, team in self.Teams do
		if team[player] then
			return index
		end
	end
	return nil
end

function RoundObject.new(teamCount: number?, winningScore: number?): RoundObject
	local resolvedTeamCount = RoundObject.DefaultTeamCount
	if teamCount ~= nil then
		if isPositiveInteger(teamCount) and teamCount >= 2 then
			resolvedTeamCount = teamCount
		else
			warn("RoundObject.new ignored a teamCount that was not an integer >= 2; using the default of two")
		end
	end

	local resolvedWinningScore = RoundObject.DefaultWinningScore
	if winningScore ~= nil then
		if isPositiveInteger(winningScore) then
			resolvedWinningScore = winningScore
		else
			warn("RoundObject.new ignored a winningScore that was not a positive integer; using the default")
		end
	end

	local teams: { Team } = {}
	local points: { number } = {}
	for index = 1, resolvedTeamCount do
		teams[index] = {}
		points[index] = 0
	end

	return setmetatable({
		Teams = teams,
		Points = points,
		RoundUpdated = {},
		State = "PRE_GAME" :: RoundState,
		WinningScore = resolvedWinningScore,
		DeathCounter = 0,
		LastDeathOrder = {},
	}, RoundObject)
end

function RoundObject:GetState(): RoundState
	return self.State
end

function RoundObject:GetTeamCount(): number
	return #self.Teams
end

function RoundObject:CanTransition(target: RoundState): boolean
	return TRANSITIONS[self.State][target] == true
end

function RoundObject:Transition(target: RoundState): boolean
	if not self:CanTransition(target) then
		warn("RoundObject:Transition refused an invalid transition from " .. self.State .. " to " .. tostring(target))
		return false
	end
	self.State = target
	return true
end

function RoundObject:AddPlayer(player: Player, team: number): boolean
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

function RoundObject:RemovePlayer(player: Player): boolean
	local index = findTeamIndex(self, player)
	if not index then
		warn("RoundObject:RemovePlayer ignored a player who is not in the round")
		return false
	end
	local wasAlive = self.Teams[index][player].isAlive
	self.Teams[index][player] = nil
	for rosterIndex, rosterPlayer in self.RoundUpdated do
		if rosterPlayer == player then
			table.remove(self.RoundUpdated, rosterIndex)
			break
		end
	end
	if wasAlive and self:IsTeamEliminated(index) then
		self.DeathCounter += 1
		self.LastDeathOrder[index] = self.DeathCounter
	end
	return true
end

function RoundObject:GetPlayerInfo(player: Player): PlayerInfoObject?
	local index = findTeamIndex(self, player)
	if not index then
		warn("RoundObject:GetPlayerInfo asked for a player who is not in the round")
		return nil
	end
	local info = self.Teams[index][player]
	return {
		Kills = info.Kills,
		Deaths = info.Deaths,
		isAlive = info.isAlive,
	}
end

function RoundObject:LogPlayerInfo(player: Player, info: { Kills: number, Deaths: number }): boolean
	local index = findTeamIndex(self, player)
	if not index then
		warn("RoundObject:LogPlayerInfo ignored a player who is not in the round")
		return false
	end
	if type(info) ~= "table" then
		warn("RoundObject:LogPlayerInfo received info that was not a table")
		return false
	end
	if not isNonNegativeInteger(info.Kills) or not isNonNegativeInteger(info.Deaths) then
		warn("RoundObject:LogPlayerInfo received Kills or Deaths that were not non-negative integers")
		return false
	end
	local entry = self.Teams[index][player]
	entry.Kills = info.Kills
	entry.Deaths = info.Deaths
	return true
end

function RoundObject:MarkDead(player: Player): boolean
	local index = findTeamIndex(self, player)
	if not index then
		warn("RoundObject:MarkDead ignored a player who is not in the round")
		return false
	end
	local info = self.Teams[index][player]
	if not info.isAlive then
		warn("RoundObject:MarkDead ignored a player who is already dead")
		return false
	end
	info.isAlive = false
	self.DeathCounter += 1
	self.LastDeathOrder[index] = self.DeathCounter
	return true
end

function RoundObject:ResetRound()
	for _, team in self.Teams do
		for _, info in team do
			info.isAlive = true
		end
	end
	self.DeathCounter = 0
	self.LastDeathOrder = {}
end

function RoundObject:IsTeamEliminated(teamIndex: number): boolean
	local team = self.Teams[teamIndex]
	if not team then
		warn("RoundObject:IsTeamEliminated received a team index outside the valid range")
		return false
	end
	for _, info in team do
		if info.isAlive then
			return false
		end
	end
	return true
end

function RoundObject:GetLivingTeams(): { number }
	local living: { number } = {}
	for index = 1, #self.Teams do
		if not self:IsTeamEliminated(index) then
			table.insert(living, index)
		end
	end
	return living
end

function RoundObject:GetRoundOutcome(): RoundOutcome
	local teamStates: { TeamState } = {}
	for index = 1, #self.Teams do
		local eliminated = self:IsTeamEliminated(index)
		local eliminationOrder: number? = nil
		if eliminated then
			eliminationOrder = self.LastDeathOrder[index]
		end
		teamStates[index] = {
			Eliminated = eliminated,
			EliminationOrder = eliminationOrder,
		}
	end
	return RoundObject.DecideOutcome(teamStates)
end

function RoundObject:AwardPoint(teamIndex: number): boolean
	if self.Points[teamIndex] == nil then
		warn("RoundObject:AwardPoint received a team index outside the valid range")
		return false
	end
	self.Points[teamIndex] += 1
	return true
end

function RoundObject:GetPoints(teamIndex: number): number?
	local points = self.Points[teamIndex]
	if points == nil then
		warn("RoundObject:GetPoints received a team index outside the valid range")
		return nil
	end
	return points
end

function RoundObject:GetWinner(): number?
	return RoundObject.FindWinner(self.Points, self.WinningScore)
end

function RoundObject:IsOver(): boolean
	return self:GetWinner() ~= nil
end

function RoundObject:BeginGame(loadMap: (() -> boolean)?, timeout: number?): boolean
	if self.State ~= "PRE_GAME" then
		warn("RoundObject:BeginGame can only start the game from PRE_GAME")
		return false
	end

	if RoundObject.MapLoadGateEnabled and loadMap ~= nil then
		local loader = loadMap
		local resolvedTimeout = RoundObject.DefaultMapLoadTimeout
		if isPositiveNumber(timeout) then
			resolvedTimeout = timeout :: number
		elseif timeout ~= nil then
			warn("RoundObject:BeginGame ignored a timeout that was not a positive number; using the default")
		end

		local finished = false
		local succeeded = false
		task.spawn(function()
			local ok, result = pcall(loader)
			if not ok then
				warn("RoundObject:BeginGame map loader raised an error: " .. tostring(result))
			end
			succeeded = ok and result == true
			finished = true
		end)

		local elapsed = 0
		while not finished and elapsed < resolvedTimeout do
			elapsed += task.wait()
		end

		if not finished then
			warn("RoundObject:BeginGame proceeding to GAME after the map load timeout elapsed")
		elseif not succeeded then
			warn("RoundObject:BeginGame proceeding to GAME after the map failed to load")
		end
	end

	return self:Transition("GAME")
end

function RoundObject.ClassifyMode(teamSizes: { number }): Mode?
	local teamCount = #teamSizes

	if teamCount == 2 and teamSizes[1] == teamSizes[2] then
		local size = teamSizes[1]
		if size == 1 then
			return "1v1"
		elseif size == 2 then
			return "2v2"
		elseif size == 3 then
			return "3v3"
		elseif size == 4 then
			return "4v4"
		end
	end

	if teamCount >= 3 then
		local allSolo = true
		for index = 1, teamCount do
			if teamSizes[index] ~= 1 then
				allSolo = false
				break
			end
		end
		if allSolo then
			return "FFA"
		end
	end

	warn("RoundObject.ClassifyMode could not classify the given team sizes")
	return nil
end

function RoundObject.DecideOutcome(teamStates: { TeamState }): RoundOutcome
	local living: { number } = {}
	for index = 1, #teamStates do
		if not teamStates[index].Eliminated then
			table.insert(living, index)
		end
	end

	if #living >= 2 then
		return { Status = "Ongoing" :: RoundStatus }
	end
	if #living == 1 then
		return { Status = "Awarded" :: RoundStatus, TeamIndex = living[1] }
	end

	local bestIndex: number? = nil
	local bestOrder: number? = nil
	local tied = false
	for index = 1, #teamStates do
		local order = teamStates[index].EliminationOrder
		if order ~= nil then
			if bestOrder == nil or order > bestOrder then
				bestOrder = order
				bestIndex = index
				tied = false
			elseif order == bestOrder then
				tied = true
			end
		end
	end

	if bestIndex == nil then
		warn("RoundObject.DecideOutcome found no living teams and no recorded deaths; leaving the round ongoing")
		return { Status = "Ongoing" :: RoundStatus }
	end

	if tied then
		warn("RoundObject.DecideOutcome found tied elimination ordering; awarding the lowest team index")
	end

	return { Status = "Awarded" :: RoundStatus, TeamIndex = bestIndex }
end

function RoundObject.FindWinner(points: { number }, winningScore: number): number?
	if not isPositiveInteger(winningScore) then
		warn("RoundObject.FindWinner received a winningScore that was not a positive integer")
		return nil
	end
	for index = 1, #points do
		if points[index] >= winningScore then
			return index
		end
	end
	return nil
end

return RoundObject
