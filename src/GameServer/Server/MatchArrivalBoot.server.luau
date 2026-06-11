--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MatchData = require(Shared:WaitForChild("MatchData"))
local RoundObject = require(Shared:WaitForChild("RoundSystem"):WaitForChild("RoundObject"))

local round = RoundObject.new()

local function seatPlayer(player: Player)
	if player.Parent ~= Players then
		warn(`MatchArrival: {player.Name} left before seating`)
		return
	end

	local joinData = player:GetJoinData()
	if joinData.SourcePlaceId ~= Config.LobbyPlaceId then
		warn(`MatchArrival: {player.Name} did not arrive from the lobby`)
		return
	end

	local teleportData = joinData.TeleportData
	if not MatchData.isValid(teleportData) then
		warn(`MatchArrival: {player.Name} arrived without valid match data`)
		return
	end

	local data = teleportData :: MatchData.MatchData
	local team = MatchData.teamOf(data, player.UserId)
	if team==  nil then
		warn(`MatchArrival: {player.Name} is not listed in the match teams`)
		return
	end

	if not round:AddPlayer(player, team) then
		warn(`MatchArrival: could not seat {player.Name} on team {team}`)
	end
end

Players.PlayerAdded:Connect(seatPlayer)
Players.PlayerRemoving:Connect(function(player)
	round:RemovePlayer(player)
end)
for _, player in Players:GetPlayers() do
	task.spawn(seatPlayer, player)
end
