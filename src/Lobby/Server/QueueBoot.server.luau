local ServerScriptService =  game:GetService("ServerScriptService")

local QueueService =  require(ServerScriptService:WaitForChild("QueueSystem"):WaitForChild("QueueService"))

QueueService.Init()
