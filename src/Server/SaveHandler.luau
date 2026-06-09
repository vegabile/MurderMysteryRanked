--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ServerPackages = ServerScriptService:WaitForChild("ServerPackages")
local ProfileStore = require(ServerPackages:WaitForChild("ProfileStore"))

local Glicko2 =
	require(ReplicatedStorage:WaitForChild("ReplicatedModules"):WaitForChild("DataModules"):WaitForChild("Glicko2"))

export type ProfileData = {
	Elo: number,
}

local TEMPLATE: ProfileData = {
	Elo = Glicko2.DefaultRating,
}

local Store = ProfileStore.New("PlayerData", TEMPLATE)

local PlayerProfile = {}
PlayerProfile.__index = PlayerProfile

export type PlayerProfile = typeof(setmetatable({} :: { _profile: any }, PlayerProfile))

function PlayerProfile.new(profile: any): PlayerProfile
	return setmetatable({ _profile = profile }, PlayerProfile)
end

function PlayerProfile.getElo(self: PlayerProfile): number
	return self._profile.Data.Elo
end

function PlayerProfile.setElo(self: PlayerProfile, value: number)
	self._profile.Data.Elo = value
end

local Profiles: { [Player]: PlayerProfile } = {}

local SaveHandler = {}

local initialized = false

local function onPlayerAdded(player: Player)
	local profile = Store:StartSessionAsync("Player_" .. player.UserId, {})

	if profile == nil then
		player:Kick("Failed to load your data. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		Profiles[player] = nil
		player:Kick("Your data session has ended. Please rejoin.")
	end)

	if player.Parent == Players then
		Profiles[player] = PlayerProfile.new(profile)
	else
		profile:EndSession()
	end
end

local function onPlayerRemoving(player: Player)
	local playerProfile: PlayerProfile? = Profiles[player]
	if playerProfile ~= nil then
		playerProfile._profile:EndSession()
	end
end

function SaveHandler.Init()
	if initialized then
		return
	end
	initialized = true

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

function SaveHandler.GetProfile(player: Player): PlayerProfile?
	return Profiles[player]
end

return SaveHandler
