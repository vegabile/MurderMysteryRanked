--!strict

local MatchData = {}

export type MatchData = {
	mode: string,
	team1: { number },
	team2: { number },
}

export type Snapshot = {
	side1: { Player },
	side2: { Player },
}

local PAD_NAME_PATTERN = "^(%d+)v(%d+)Pad%d*$"

function MatchData.fromPadName(name: string): (string?, number?)
	local first, second = string.match(name, PAD_NAME_PATTERN)
	if first == nil or second == nil or first ~= second then
		return nil, nil
	end
	local perSide = tonumber(first)
	if perSide == nil or perSide <= 0 then
		return nil, nil
	end
	return `{first}v{second}`, perSide
end

function MatchData.build(snapshot: Snapshot, mode: string): MatchData
	local team1: { number } = {}
	local team2: { number } = {}
	for _, player in snapshot.side1 do
		table.insert(team1, player.UserId)
	end
	for _, player in snapshot.side2 do
		table.insert(team2, player.UserId)
	end
	return { mode = mode, team1 = team1, team2 = team2 }
end

local function isNumberArray(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	for index, item in value :: { [any]: any } do
		if type(index) ~= "number" or type(item) ~= "number" then
			return false
		end
	end
	return true
end

function MatchData.isValid(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	local candidate = value :: { [any]: any }
	if type(candidate.mode) ~= "string" then
		return false
	end
	return isNumberArray(candidate.team1) and isNumberArray(candidate.team2)
end

function MatchData.teamOf(data: MatchData, userId: number): number?
	for _, id in data.team1 do
		if id == userId then
			return 1
		end
	end
	for _, id in data.team2 do
		if id == userId then
			return 2
		end
	end
	return nil
end

return MatchData
