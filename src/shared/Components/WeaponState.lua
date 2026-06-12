local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

-- Tracks server-side weapon cooldown state.
-- lastFireTime: os.clock() timestamp of the last validated shot (0 = never fired).
return Matter.component("WeaponState", {
	lastFireTime = 0,
})
