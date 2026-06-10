--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MatchData = require(Shared:WaitForChild("MatchData"))

local MatchTeleport = {}

TeleportService.TeleportInitFailed:Connect(function(player, result, message)
	warn(`MatchTeleport: teleport init failed for {player.Name} ({result.Name}): {message}`)
end)

local function presentPlayers(snapshot: MatchData.Snapshot): { Player }
	local players: { Player } = {}
	for _, player in snapshot.side1 do
		if player.Parent == Players then
			table.insert(players, player)
		end
	end
	for _, player in snapshot.side2 do
		if player.Parent == Players then
			table.insert(players, player)
		end
	end
	return players
end

function MatchTeleport.teleportMatch(snapshot: MatchData.Snapshot, mode: string, perSide: number): boolean
	local players = presentPlayers(snapshot)
	if #players ~= perSide * 2 then
		warn(`MatchTeleport: roster for {mode} changed before teleport, aborting`)
		return false
	end

	local reserved, accessCode = pcall(function()
		return TeleportService:ReserveServer(Config.GameServerPlaceId)
	end)
	if not reserved then
		warn(`MatchTeleport: ReserveServer failed for {mode}: {accessCode}`)
		return false
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData(MatchData.build(snapshot, mode))

	local sent, err = pcall(function()
		TeleportService:TeleportAsync(Config.GameServerPlaceId, players, options)
	end)
	if not sent then
		warn(`MatchTeleport: TeleportAsync failed for {mode}: {err}`)
		return false
	end

	return true
end

return MatchTeleport
