--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MatchData = require(Shared:WaitForChild("MatchData"))

local MatchTeleport = {}

local RETRYABLE_RESULTS: { [Enum.TeleportResult]: boolean } = {
	[Enum.TeleportResult.Failure] = true,
	[Enum.TeleportResult.Flooded] = true,
}

type Pending = {
	options: TeleportOptions,
	attempts: number,
}

local pending: { [Player]: Pending } = {}

local function sendToReserved(players: { Player }, options: TeleportOptions): (boolean, string?)
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(Config.GameServerPlaceId, players, options)
	end)
	return ok, err
end

local function presentPlayers(snapshot: MatchData.Snapshot): { Player }
	local players: { Player } = {}
	for _, player in snapshot.side1 do
		if player.Parent==  Players then
			table.insert(players, player)
		end
	end
	for _, player in snapshot.side2 do
		if player.Parent==  Players then
			table.insert(players, player)
		end
	end
	return players
end

TeleportService.TeleportInitFailed:Connect(function(player, result, message)
	local entry = pending[player]
	if entry==  nil then
		return
	end

	if not RETRYABLE_RESULTS[result] or entry.attempts >= Config.MaxTeleportAttempts then
		pending[player] = nil
		warn(`MatchTeleport: giving up teleport for {player.Name} ({result.Name}): {message}`)
		return
	end

	entry.attempts + = 1
	task.wait(Config.TeleportRetryBackoff)
	if pending[player] ~= entry or player.Parent ~= Players then
		return
	end

	local ok, err = sendToReserved({ player }, entry.options)
	if not ok then
		pending[player] = nil
		warn(`MatchTeleport: retry teleport failed for {player.Name}: {err}`)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	pending[player] = nil
end)

function MatchTeleport.isPending(player: Player): boolean
	return pending[player] ~= nil
end

function MatchTeleport.teleportMatch(snapshot: MatchData.Snapshot, mode: string, perSide: number): boolean
	local players = presentPlayers(snapshot)
	if #players ~= perSide * 2 then
		warn(`MatchTeleport: roster for {mode} changed before teleport, aborting`)
		return false
	end

	local reserved, accessCode = pcall(function()
		return TeleportService:ReserveServerAsync(Config.GameServerPlaceId)
	end)
	if not reserved then
		warn(`MatchTeleport: ReserveServerAsync failed for {mode}: {accessCode}`)
		return false
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData(MatchData.build(snapshot, mode))

	for _, player in players do
		pending[player] = { options = options, attempts = 0 }
	end

	local sent, err = sendToReserved(players, options)
	if not sent then
		for _, player in players do
			pending[player] = nil
		end
		warn(`MatchTeleport: TeleportAsync failed for {mode}: {err}`)
		return false
	end

	return true
end

return MatchTeleport
