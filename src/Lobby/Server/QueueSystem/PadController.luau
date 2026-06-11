--!strict

local Players =  game:GetService("Players")
local ReplicatedStorage =  game:GetService("ReplicatedStorage")
local RunService =  game:GetService("RunService")
local Workspace =  game:GetService("Workspace")

local Shared =  ReplicatedStorage:WaitForChild("Shared")
local Config =  require(Shared:WaitForChild("Config"))

local LobbyModules =  ReplicatedStorage:WaitForChild("Lobby"):WaitForChild("ReplicatedModules")
local PadObject =  require(LobbyModules:WaitForChild("StateMachines"):WaitForChild("PadObject"))

local MatchTeleport =  require(script.Parent:WaitForChild("MatchTeleport"))

local DETECTION_HEIGHT =  8

local PadController =  {}
PadController.__index =  PadController

export type Options =  {
	model: Model,
	pad1Part: BasePart,
	pad2Part: BasePart,
	holder: Instance?,
	perSide: number,
	mode: string,
}

type Fields =  {
	_model: Model,
	_pad1Part: BasePart,
	_pad2Part: BasePart,
	_holder: Instance?,
	_perSide: number,
	_mode: string,
	_pad: PadObject.PadObject,
	_polling: RBXScriptConnection?,
	_countdownId: number,
}

export type PadController =  typeof(setmetatable({} :: Fields, PadController))

local function thumbnailFor(player: Player): string?
	local ok, image =  pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if not ok then
		warn(`PadController: thumbnail fetch failed for {player.Name}: {image}`)
		return nil
	end
	return image
end

local function allPresent(players: { Player }, present: { [Player]: boolean }): boolean
	for _, player in players do
		if not present[player] then
			return false
		end
	end
	return true
end

function PadController.new(options: Options): PadController
	local self =  setmetatable({
		_model =  options.model,
		_pad1Part =  options.pad1Part,
		_pad2Part =  options.pad2Part,
		_holder =  options.holder,
		_perSide =  options.perSide,
		_mode =  options.mode,
		_pad =  PadObject.new(options.perSide),
		_polling =  nil :: RBXScriptConnection?,
		_countdownId =  0,
	}, PadController)

	if options.holder = = nil then
		warn(`PadController: {options.mode} pad has no display; running logic only`)
	end

	self:_showCountdown(false)
	self:_render()
	self:_startPolling()
	return self
end

function PadController._sideList(self: PadController, side: number): { Player }
	return if side = = 1 then self._pad.Side1 else self._pad.Side2
end

function PadController._playersOn(self: PadController, part: BasePart): { [Player]: boolean }
	local footprint =  math.max(part.Size.X, part.Size.Y, part.Size.Z)
	local center =  CFrame.new(part.Position + Vector3.new(0, DETECTION_HEIGHT / 2 - 1, 0))
	local volume =  Vector3.new(footprint, DETECTION_HEIGHT, footprint)

	local params =  OverlapParams.new()
	params.FilterType =  Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances =  { self._model }

	local present: { [Player]: boolean } =  {}
	for _, hit in Workspace:GetPartBoundsInBox(center, volume, params) do
		local character =  hit:FindFirstAncestorOfClass("Model")
		if character then
			local player =  Players:GetPlayerFromCharacter(character)
			if player then
				present[player] =  true
			end
		end
	end
	return present
end

function PadController._tryAdd(self: PadController, player: Player, side: number): boolean
	if MatchTeleport.isPending(player) then
		return false
	end
	for _, existing in self:_sideList(side) do
		if existing = = player then
			return false
		end
	end
	return self._pad:addPlayer(player, side)
end

function PadController._poll(self: PadController)
	if self._pad.State = = "Popped" then
		return
	end

	local on1 =  self:_playersOn(self._pad1Part)
	local on2 =  self:_playersOn(self._pad2Part)
	local changed =  false

	for _, player in table.clone(self._pad.Side1) do
		if not on1[player] and self._pad:removePlayer(player) then
			changed =  true
		end
	end
	for _, player in table.clone(self._pad.Side2) do
		if not on2[player] and self._pad:removePlayer(player) then
			changed =  true
		end
	end

	for player in on1 do
		if not on2[player] and self:_tryAdd(player, 1) then
			changed =  true
		end
	end
	for player in on2 do
		if not on1[player] and self:_tryAdd(player, 2) then
			changed =  true
		end
	end

	if changed then
		self:_onRosterChanged()
	end
end

function PadController._startPolling(self: PadController)
	local accumulator =  0
	self._polling =  RunService.Heartbeat:Connect(function(delta)
		accumulator += delta
		if accumulator >= Config.OccupancyPollInterval then
			accumulator =  0
			self:_poll()
		end
	end)
end

function PadController._onRosterChanged(self: PadController)
	self:_render()
	if self._pad.State = = "Ready" then
		self:_startCountdown()
	else
		self:_cancelCountdown()
	end
end

function PadController._startCountdown(self: PadController)
	self._countdownId += 1
	local id =  self._countdownId
	self:_showCountdown(true)
	task.spawn(function()
		local remaining =  Config.CountdownSeconds
		while remaining > 0 and self._countdownId = = id do
			self:_setCountdownText(remaining)
			task.wait(1)
			remaining -= 1
		end
		if self._countdownId = = id then
			self:_pop()
		end
	end)
end

function PadController._cancelCountdown(self: PadController)
	self._countdownId += 1
	self:_showCountdown(false)
end

function PadController._pop(self: PadController)
	local on1 =  self:_playersOn(self._pad1Part)
	local on2 =  self:_playersOn(self._pad2Part)
	if not (allPresent(self._pad.Side1, on1) and allPresent(self._pad.Side2, on2)) then
		warn(`PadController: {self._mode} roster left the pad before pop, reopening`)
		for _, player in table.clone(self._pad.Side1) do
			if not on1[player] then
				self._pad:removePlayer(player)
			end
		end
		for _, player in table.clone(self._pad.Side2) do
			if not on2[player] then
				self._pad:removePlayer(player)
			end
		end
		self:_cancelCountdown()
		self:_render()
		return
	end

	local snapshot =  self._pad:Pop()
	self:_showCountdown(false)

	if snapshot = = nil then
		warn(`PadController: {self._mode} pop was not ready`)
		self:_reset()
		return
	end

	if MatchTeleport.teleportMatch(snapshot, self._mode, self._perSide) then
		task.delay(Config.TeleportCooldown, function()
			self:_reset()
		end)
	else
		warn(`PadController: teleport failed for {self._mode}, reopening pad`)
		self:_reset()
	end
end

function PadController._reset(self: PadController)
	self._pad =  PadObject.new(self._perSide)
	self:_render()
end

function PadController._render(self: PadController)
	local holder =  self._holder
	if holder then
		self:_renderSide(holder, 1, self._pad.Side1)
		self:_renderSide(holder, 2, self._pad.Side2)
	end
end

function PadController._renderSide(self: PadController, holder: Instance, side: number, players: { Player })
	for index =  1, self._perSide do
		local slot =  holder:FindFirstChild(`Team{side}P{index}`)
		if slot and slot:IsA("ImageLabel") then
			slot.Image =  ""
			local player =  players[index]
			if player then
				self:_loadSlotImage(side, index, player)
			end
		end
	end
end

function PadController._loadSlotImage(self: PadController, side: number, index: number, player: Player)
	task.spawn(function()
		local image =  thumbnailFor(player)
		local holder =  self._holder
		if image and holder and self:_sideList(side)[index] = = player then
			local slot =  holder:FindFirstChild(`Team{side}P{index}`)
			if slot and slot:IsA("ImageLabel") then
				slot.Image =  image
			end
		end
	end)
end

function PadController._showCountdown(self: PadController, visible: boolean)
	local holder =  self._holder
	if holder then
		local frame =  holder:FindFirstChild("CountdownFrame")
		if frame and frame:IsA("GuiObject") then
			frame.Visible =  visible
		end
	end
end

function PadController._setCountdownText(self: PadController, value: number)
	local holder =  self._holder
	if holder then
		local frame =  holder:FindFirstChild("CountdownFrame")
		local label =  if frame then frame:FindFirstChild("1") else nil
		if label and label:IsA("TextLabel") then
			label.Text =  tostring(value)
		end
	end
end

function PadController.removePlayer(self: PadController, player: Player)
	if self._pad:removePlayer(player) then
		self:_onRosterChanged()
	end
end

function PadController.destroy(self: PadController)
	if self._polling then
		self._polling:Disconnect()
		self._polling =  nil
	end
	self._countdownId += 1
end

return PadController
