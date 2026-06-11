local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local Debris = game:GetService("Debris")

local ReplicatedAssets = ReplicatedStorage:WaitForChild("Lobby"):WaitForChild("ReplicatedAssets")
local WeldTemplates = ReplicatedAssets:WaitForChild("WeaponModels"):WaitForChild("Welds")

local Remotes = ReplicatedStorage:WaitForChild("Lobby"):WaitForChild("Remotes")
local RemoteEvents = Remotes:WaitForChild("RemoteEvents")
local RemoteFunctions = Remotes:WaitForChild("RemoteFunctions")
local ApplyItem = RemoteEvents:WaitForChild("ApplyInventoryItem")
local GetHandleData = RemoteFunctions:WaitForChild("GetHandleData")

local SkinAssets = ServerStorage:WaitForChild("ServerDatabase"):WaitForChild("SkinAssets")

local Skins = require(ReplicatedStorage:WaitForChild("Lobby"):WaitForChild("ReplicatedModules")
	:WaitForChild("DataModules"):WaitForChild("Skins"))

local KNIFE_OFFSET = Vector3.new(-1.1, -0.6, 0.3)
local KNIFE_ROTATION = Vector3.new(120, -180, 0)
local GUN_OFFSET = Vector3.new(1.2, -0.3, 0)
local GUN_ROTATION = Vector3.new(162, -2, -2)
local DROP_LIFETIME = 4
local COOLDOWN = 0.4
local SAVE_DELAY = 8
local DS_RETRIES = 3

local SLOTS = {
	{ partName = "HandleKnife", offset = KNIFE_OFFSET, rotation = KNIFE_ROTATION, defaultSkin = "KnifeDefault" },
	{ partName = "HandleGun",   offset = GUN_OFFSET,   rotation = GUN_ROTATION,   defaultSkin = "GunDefault"   },
}

local SLOT_TYPE = {
	HandleKnife = "Knife",
	HandleGun = "Gun",
}

local activeSkins = {}
local equipCooldowns = {}
local saveQueued = {}

local EquipStore = DataStoreService:GetDataStore("WeldSkins_v2")

local function buildC0(offset, rotationDeg, anglesOverride)
	if anglesOverride
		and type(anglesOverride.X)==  "number"
		and type(anglesOverride.Y)==  "number"
		and type(anglesOverride.Z)==  "number"
	then
		return CFrame.new(offset) * CFrame.Angles(anglesOverride.X, anglesOverride.Y, anglesOverride.Z)
	end
	return CFrame.new(offset) * CFrame.Angles(
		math.rad(rotationDeg.X),
		math.rad(rotationDeg.Y),
		math.rad(rotationDeg.Z)
	)
end

local function packC0(cf)
	return { cf:GetComponents() }
end

local function unpackC0(t)
	if type(t) ~= "table" or #t ~= 12 then return nil end
	return CFrame.new(t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9],t[10],t[11],t[12])
end

local function getSlot(slotName)
	for _, slot in ipairs(SLOTS) do
		if slot.partName==  slotName then return slot end
	end
end

local function tagHandle(handle, slotName)
	local tagName = (slotName==  "HandleGun") and "IsGun" or "IsKnife"
	if not handle:FindFirstChild(tagName) then
		local flag = Instance.new("BoolValue")
		flag.Name = tagName
		flag.Value = true
		flag.Parent = handle
	end
end

local function weldHandle(character, slotName, handle, c0)
	local torso = character:FindFirstChild("LowerTorso")
	if not torso then
		warn("[CharacterWelding] No LowerTorso found on", character.Name)
		return
	end

	local old = character:FindFirstChild(slotName)
	if old then old:Destroy() end

	local oldMotor = torso:FindFirstChild(slotName .. "_Weld")
	if oldMotor then oldMotor:Destroy() end

	handle.Name = slotName
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = character

	tagHandle(handle, slotName)

	local motor = Instance.new("Motor6D")
	motor.Name = slotName .. "_Weld"
	motor.Part0 = torso
	motor.Part1 = handle
	motor.C0 = c0 or CFrame.new()
	motor.Parent = torso
end

local function weldSkinByKey(character, slotName, assetKey, savedC0)
	local skinData = Skins.Get(assetKey)
	if not skinData then
		warn("[CharacterWelding] Unknown assetKey:", assetKey)
		return false
	end

	local skinFolder = SkinAssets:FindFirstChild(assetKey)
	if not skinFolder then
		warn("[CharacterWelding] SkinAssets missing folder:", assetKey)
		return false
	end

	local handle = skinFolder:FindFirstChild("Handle")
	if not handle then
		warn("[CharacterWelding] No Handle inside SkinAssets/" .. assetKey)
		return false
	end

	local c0 = unpackC0(savedC0)
	if not c0 then
		local slot = getSlot(slotName)
		c0 = slot and buildC0(slot.offset, slot.rotation, skinData.Angles) or CFrame.new()
	end

	weldHandle(character, slotName, handle:Clone(), c0)
	return true
end

local function dropWeaponsOnDeath(character)
	local torso = character:FindFirstChild("LowerTorso")
	for _, slot in ipairs(SLOTS) do
		local handle = character:FindFirstChild(slot.partName)
		if torso then
			local motor = torso:FindFirstChild(slot.partName .. "_Weld")
			if motor then motor:Destroy() end
		end
		if handle then
			handle.Parent = workspace
			handle.Anchored = false
			handle.CanCollide = false
			handle.Massless = false
			handle.AssemblyLinearVelocity = Vector3.new(
				math.random(-5, 5), math.random(3, 7), math.random(-5, 5)
			)
			Debris:AddItem(handle, DROP_LIFETIME)
		end
	end
end

local function setupCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.Died:Connect(function()
		dropWeaponsOnDeath(character)
	end)

	character:WaitForChild("LowerTorso")
	task.wait(0.1)

	local playerSkins = activeSkins[player.UserId] or {}

	for _, slot in ipairs(SLOTS) do
		local slotName = slot.partName
		local skinEntry = playerSkins[slotName]
		local assetKey = skinEntry and skinEntry.assetKey or slot.defaultSkin
		local savedC0 = skinEntry and skinEntry.savedC0  or nil

		local welded = weldSkinByKey(character, slotName, assetKey, savedC0)
		if not welded then
			warn("[CharacterWelding] Failed to weld", assetKey, "for slot", slotName)
		end
	end
end

local function dsCall(fn)
	local result, err
	for attempt = 1, DS_RETRIES do
		local ok
		ok, result = pcall(fn)
		if ok then return result, nil end
		err = result
		if attempt < DS_RETRIES then task.wait(2 ^ attempt) end
	end
	return nil, err
end

local function savePlayerData(player)
	local userId = player.UserId
	local skins = activeSkins[userId]
	if not skins then return end

	local serialised = {}
	for slotName, entry in pairs(skins) do
		serialised[slotName] = { assetKey = entry.assetKey, savedC0 = entry.savedC0 }
	end

	local _, err = dsCall(function()
		EquipStore:SetAsync(tostring(userId), serialised)
	end)

	if err then warn("[CharacterWelding] Save failed for", player.Name, "-", err) end
end

local function loadPlayerData(player)
	local userId = player.UserId
	activeSkins[userId] = {}

	local loaded, err = dsCall(function()
		return EquipStore:GetAsync(tostring(userId))
	end)

	if err then
		warn("[CharacterWelding] Load failed for", player.Name, "-", err)
		return
	end

	if not loaded then return end

	for slotName, entry in pairs(loaded) do
		if Skins.Get(entry.assetKey) then
			activeSkins[userId][slotName] = {
				assetKey = entry.assetKey,
				savedC0 = entry.savedC0,
			}
		end
	end
end

local function queueSave(player)
	local userId = player.UserId
	if saveQueued[userId] then return end
	saveQueued[userId] = true
	task.delay(SAVE_DELAY, function()
		saveQueued[userId] = nil
		if activeSkins[userId] then savePlayerData(player) end
	end)
end

local function serializeHandle(handle)
	local data = {
		Size = { handle.Size.X, handle.Size.Y, handle.Size.Z },
		Color = { handle.Color.R, handle.Color.G, handle.Color.B },
		Material = handle.Material.Name,
		Transparency = handle.Transparency,
		CastShadow = handle.CastShadow,
		SpecialMesh = nil,
		Textures = {},
	}

	local mesh = handle:FindFirstChildWhichIsA("SpecialMesh")
	if mesh then
		data.SpecialMesh = {
			MeshType = mesh.MeshType.Name,
			MeshId = mesh.MeshId,
			TextureId = mesh.TextureId,
			Scale = { mesh.Scale.X,  mesh.Scale.Y,  mesh.Scale.Z  },
			Offset = { mesh.Offset.X, mesh.Offset.Y, mesh.Offset.Z },
		}
	end

	for _, child in ipairs(handle:GetChildren()) do
		if child:IsA("Texture") or child:IsA("Decal") then
			table.insert(data.Textures, {
				ClassName = child.ClassName,
				Texture = child.Texture,
				Face = child.Face.Name,
				Transparency = child.Transparency,
			})
		end
	end

	return data
end

GetHandleData.OnServerInvoke = function(player, assetKey)
	if type(assetKey) ~= "string" then return nil end
	local skinFolder = SkinAssets:FindFirstChild(assetKey)
	if not skinFolder then return nil end
	local handle = skinFolder:FindFirstChild("Handle")
	if not handle then return nil end
	return serializeHandle(handle)
end

Players.PlayerAdded:Connect(function(player)
	loadPlayerData(player)
	equipCooldowns[player.UserId] = 0

	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)

	if player.Character then
		setupCharacter(player, player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	savePlayerData(player)
	activeSkins[userId] = nil
	equipCooldowns[userId] = nil
	saveQueued[userId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerData(player)
	end
end)

ApplyItem.OnServerEvent:Connect(function(player, assetKey)
	if type(assetKey) ~= "string" then return end

	local userId = player.UserId
	local now = tick()
	if (now - (equipCooldowns[userId] or 0)) < COOLDOWN then return end
	equipCooldowns[userId] = now

	local skinData = Skins.Get(assetKey)
	if not skinData then return end

	local slotName
	for sName, sType in pairs(SLOT_TYPE) do
		if sType==  skinData.ItemType then slotName = sName break end
	end
	if not slotName then return end

	local character = player.Character
	if not character then return end

	local slot = getSlot(slotName)
	local newC0 = buildC0(
		slot and slot.offset   or Vector3.new(),
		slot and slot.rotation or Vector3.new(),
		skinData.Angles
	)

	local success = weldSkinByKey(character, slotName, assetKey, packC0(newC0))
	if not success then return end

	activeSkins[userId] = activeSkins[userId] or {}
	activeSkins[userId][slotName] = {
		assetKey = assetKey,
		savedC0 = packC0(newC0),
	}

	queueSave(player)
end)