local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

-- Tracks player downed / revive state.
-- isDowned:  player is incapacitated and waiting for revive.
-- downedAt:  os.clock() when they went down (used for timeout tracking).
return Matter.component("DownedState", {
	isDowned = false,
	downedAt = 0,
})
