local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

return Matter.component("Health", {
	current = 100,
	max = 100,
})
