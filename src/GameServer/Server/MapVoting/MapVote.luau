local ServerScriptService = game:GetService("ServerScriptService")

local ServerPackages = ServerScriptService:WaitForChild("ServerPackages")
local Promise = require(ServerPackages:WaitForChild("Promise"))

local SLOTS = 3

local MapVote = {}
MapVote.__index = MapVote

type Fields = {
	Votes: { [number]: number },
	Closed: boolean,
	_promise: any,
}

export type VoteObject = typeof(setmetatable({} :: Fields, MapVote))

local function tally(votes: { [number]: number }): number
	local counts = table.create(SLOTS, 0)
	for _, slot in votes do
		counts[slot] += 1
	end

	local winner = 1
	for slot = 2, SLOTS do
		if counts[slot] > counts[winner] then
			winner = slot
		end
	end
	return winner
end

function MapVote.newVoteObject(duration: number): VoteObject?
	if type(duration) ~= "number" or duration <= 0 then
		warn("MapVote.newVoteObject: duration must be a positive number")
		return nil
	end

	local self = setmetatable({
		Votes = {},
		Closed = false,
	}, MapVote)

	self._promise = Promise.new(function(resolve)
		task.delay(duration, function()
			self.Closed = true
			resolve(tally(self.Votes))
		end)
	end)

	return self
end

function MapVote:vote(player: Player, slot: number): boolean
	if self.Closed then
		warn("MapVote:vote: voting is closed")
		return false
	end
	if not player then
		warn("MapVote:vote: player is required")
		return false
	end
	if type(slot) ~= "number" or slot < 1 or slot > SLOTS or slot % 1 ~= 0 then
		warn(`MapVote:vote: slot must be an integer in 1..{SLOTS}`)
		return false
	end

	self.Votes[player.UserId] = slot
	return true
end

function MapVote:getWinner(): any
	return self._promise
end

return MapVote
