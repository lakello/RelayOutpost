local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

-- Holds a reference to the Roblox Player object.
-- Created once per player; replaced on respawn (via CharacterRef update).
return Matter.component("PlayerRef", {
	player = nil :: Player?,
})
