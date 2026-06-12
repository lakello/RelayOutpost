local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

-- Per-entity melee attack timing, consistent with WeaponState pattern.
-- lastAttackTime: os.clock() when the last attack landed.
-- cooldown:       seconds required between attacks (loaded from EnemyConfig).
return Matter.component("AttackCooldown", {
	lastAttackTime = 0,
	cooldown = 1.0,
})
