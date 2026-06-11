local ServerScriptService = game:GetService("ServerScriptService")

local ServerPackages = ServerScriptService:WaitForChild("ServerPackages")
local Promise = require(ServerPackages:WaitForChild("Promise"))

local SLOTS = 3

local MapVote = {}
MapVote.__index = MapVote

type Fields = {
	Votes: { [number]: number },
	Closed: boolean,
	_winner: number?,
	_waiters: { (number) -> () },
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
		_waiters = {},
	}, MapVote)

	task.delay(duration, function()
		local winner = tally(self.Votes)
		self._winner = winner
		self.Closed = true
		for _, resolve in self._waiters do
			resolve(winner)
		end
		table.clear(self._waiters)
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
	if self.Closed then
		return Promise.resolve(self._winner)
	end
	return Promise.new(function(resolve)
		table.insert(self._waiters, resolve)
	end)
end

return MapVote
