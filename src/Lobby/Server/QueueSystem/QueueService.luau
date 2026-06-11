--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MatchData = require(Shared:WaitForChild("MatchData"))

local PadController = require(script.Parent:WaitForChild("PadController"))

local QueueService = {}

local controllers: { PadController.PadController } = {}
local initialized = false

local function resolvePad(model: Model): PadController.Options?
	local mode, perSide = MatchData.fromPadName(model.Name)
	if mode==  nil or perSide==  nil then
		return nil
	end

	local pad1 = model:FindFirstChild("Pad1")
	local pad2 = model:FindFirstChild("Pad2")
	local pad1Part = if pad1 then pad1:FindFirstChild("Part") else nil
	local pad2Part = if pad2 then pad2:FindFirstChild("Part") else nil
	if not (pad1Part and pad1Part:IsA("BasePart")) then
		warn(`QueueService: {model.Name} missing Pad1.Part; skipping`)
		return nil
	end
	if not (pad2Part and pad2Part:IsA("BasePart")) then
		warn(`QueueService: {model.Name} missing Pad2.Part; skipping`)
		return nil
	end

	local holder: Instance? = nil
	local screen = model:FindFirstChild("Screen")
	local surfaceGui = if screen then screen:FindFirstChildWhichIsA("SurfaceGui") else nil
	if surfaceGui then
		holder = surfaceGui:FindFirstChild("Holder")
	end
	if holder==  nil then
		warn(`QueueService: {model.Name} has no Screen.SurfaceGui.Holder; display disabled`)
	end

	return {
		model = model,
		pad1Part = pad1Part,
		pad2Part = pad2Part,
		holder = holder,
		perSide = perSide,
		mode = mode,
	}
end

function QueueService.Init()
	if initialized then
		return
	end
	initialized = true

	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") then
			local options = resolvePad(child)
			if options then
				table.insert(controllers, PadController.new(options))
			end
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		for _, controller in controllers do
			controller:removePlayer(player)
		end
	end)
end

return QueueService
