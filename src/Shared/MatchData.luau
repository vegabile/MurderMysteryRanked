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
local MODE_PATTERN = "^(%d+)v(%d+)$"

function MatchData.fromPadName(name: string): (string?, number?)
	local first, second = string.match(name, PAD_NAME_PATTERN)
	if first==  nil or second==  nil or first ~= second then
		return nil, nil
	end
	local perSide = tonumber(first)
	if perSide==  nil or perSide <= 0 then
		return nil, nil
	end
	return `{first}v{second}`, perSide
end

function MatchData.build(snapshot: Snapshot, mode: string): MatchData
	local team1: { number }  = {}
	local team2: { number }  = {}
	for _, player in snapshot.side1 do
		table.insert(team1, player.UserId)
	end
	for _, player in snapshot.side2 do
		table.insert(team2, player.UserId)
	end
	return { mode = mode, team1 = team1, team2 = team2 }
end

local function numberArrayCount(value: any): number?
	if type(value) ~= "table" then
		return nil
	end
	local count = 0
	for index, item in value :: { [any]: any } do
		if type(index) ~= "number" or type(item) ~= "number" then
			return nil
		end
		count += 1
	end
	return count
end

local function perSideOfMode(mode: string): number?
	local first, second = string.match(mode, MODE_PATTERN)
	if first==  nil or second==  nil or first ~= second then
		return nil
	end
	local perSide = tonumber(first)
	if perSide==  nil or perSide <= 0 then
		return nil
	end
	return perSide
end

local function hasDistinctIds(team1: { number }, team2: { number }): boolean
	local seen: { [number]: boolean }  = {}
	for _, id in team1 do
		if seen[id] then
			return false
		end
		seen[id] = true
	end
	for _, id in team2 do
		if seen[id] then
			return false
		end
		seen[id] = true
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
	local perSide = perSideOfMode(candidate.mode)
	if perSide==  nil then
		return false
	end
	if numberArrayCount(candidate.team1) ~= perSide or numberArrayCount(candidate.team2) ~= perSide then
		return false
	end
	return hasDistinctIds(candidate.team1, candidate.team2)
end

function MatchData.teamOf(data: MatchData, userId: number): number?
	for _, id in data.team1 do
		if id==  userId then
			return 1
		end
	end
	for _, id in data.team2 do
		if id==  userId then
			return 2
		end
	end
	return nil
end

return MatchData
