local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

-- Melee attack parameters. Values loaded from EnemyConfig at spawn time.
return Matter.component("MeleeAttack", {
	range = 5, -- studs
	damage = 10,
})
