local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

-- Which entity an enemy is currently targeting.
-- entityId:   ECS entity ID of the target (player entity or generator entity).
-- targetType: "Player" | "Generator" | nil when no valid target.
return Matter.component("Target", {
	entityId = nil :: number?,
	targetType = nil :: string?,
})
