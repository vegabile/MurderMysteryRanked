--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchData = require(Shared:WaitForChild("MatchData"))
local RoundObject = require(Shared:WaitForChild("RoundSystem"):WaitForChild("RoundObject"))

local round = RoundObject.new()

local function seatPlayer(player: Player)
	local teleportData = player:GetJoinData().TeleportData
	if not MatchData.isValid(teleportData) then
		warn(`MatchArrival: {player.Name} arrived without valid match data`)
		return
	end

	local data = teleportData :: MatchData.MatchData
	local team = MatchData.teamOf(data, player.UserId)
	if team == nil then
		warn(`MatchArrival: {player.Name} is not listed in the match teams`)
		return
	end

	if not round:AddPlayer(player, team) then
		warn(`MatchArrival: could not seat {player.Name} on team {team}`)
	end
end

Players.PlayerAdded:Connect(seatPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(seatPlayer, player)
end
