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

function PlayerProfile.setElo(self: PlayerProfile, value: number): boolean
	if not self._profile:IsActive() then
		return false
	end
	self._profile.Data.Elo = value
	return true
end

return PlayerProfile
