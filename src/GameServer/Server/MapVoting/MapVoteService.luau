local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapVote = require(script.Parent:WaitForChild("MapVote"))

local RemoteFunctions = 
	ReplicatedStorage:WaitForChild("GameServer"):WaitForChild("Remotes"):WaitForChild("RemoteFunctions")
local CastVote = RemoteFunctions:WaitForChild("CastVote")

local MapVoteService = {}

local currentVote: MapVote.VoteObject? = nil

function MapVoteService.start(duration: number): MapVote.VoteObject?
	if currentVote and not currentVote.Closed then
		warn("MapVoteService.start: a vote is already in progress")
		return nil
	end

	local vote = MapVote.newVoteObject(duration)
	if not vote then
		warn("MapVoteService.start: failed to create vote")
		return nil
	end

	currentVote = vote
	return vote
end

CastVote.OnServerInvoke = function(player: Player, slot: any): boolean
	if not currentVote or currentVote.Closed then
		warn("CastVote: no active vote")
		return false
	end
	return currentVote:vote(player, slot)
end

return MapVoteService
