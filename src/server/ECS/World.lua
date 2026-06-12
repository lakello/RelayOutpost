-- Matter ECS World singleton.
-- Required once from Bootstrap; module caching ensures only one World exists.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

return Matter.World.new()
