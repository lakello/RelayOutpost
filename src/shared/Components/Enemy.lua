local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

-- Marks an entity as an enemy. kind determines stats via EnemyConfig.
return Matter.component("Enemy", {
	kind = "Crawler", -- EnemyKind: "Crawler" | "Runner"
})
