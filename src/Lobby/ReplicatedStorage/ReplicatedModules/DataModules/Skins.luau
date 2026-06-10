local Skins = {}

Skins["KnifeDefault"] = {
	ItemName = "Default Knife",
	ItemType = "Knife",
	Rarity   = "Common",
	Image    = "rbxassetid://584555920",
	ItemID   = 196750384,
	Season   = 1,
}

Skins["GunDefault"] = {
	ItemName = "Default Gun",
	ItemType = "Gun",
	Rarity   = "Common",
	Image    = "rbxassetid://197518111",
	ItemID   = 196751820,
	Season   = 1,
}

Skins["RedLuger"] = {
	ItemName = "Red Luger",
	ItemType = "Gun",
	Rarity   = "Common",
	Image    = "http://www.roblox.com/Thumbs/Asset.ashx?format=png&width=250&height=250&assetId=332044583",
	ItemID   = 196751822,
	Season   = 1,
}

Skins["Candy"] = {
	ItemName = "Candy",
	ItemType = "Knife",
	Rarity   = "Common",
	Image    = "http://www.roblox.com/Thumbs/Asset.ashx?format=png&width=250&height=250&assetId=332021011",
	ItemID   = 196751823,
	Season   = 1,
}

function Skins.GetByType(itemType)
	local result = {}
	for key, data in pairs(Skins) do
		if type(data) == "table" and data.ItemType == itemType then
			result[key] = data
		end
	end
	return result
end

function Skins.Get(key)
	local data = Skins[key]
	if type(data) == "table" then
		return data
	end
	return nil
end

return Skins