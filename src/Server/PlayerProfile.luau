--!strict

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

return PlayerProfile
