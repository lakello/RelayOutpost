local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

-- Holds a reference to the player's current Character model.
-- Re-inserted on each respawn so server systems always read fresh character state.
return Matter.component("CharacterRef", {
	character = nil :: Model?,
})
