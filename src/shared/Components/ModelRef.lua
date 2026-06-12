local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

-- Links an ECS entity to its Roblox Model in workspace.
-- CleanupSystem and movement systems read this to manipulate the model.
return Matter.component("ModelRef", {
	model = nil :: Model?,
})
