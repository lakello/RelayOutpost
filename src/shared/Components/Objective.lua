local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

-- Attaches an objective identity and lifecycle state to an entity.
-- id:    stable string ID (e.g. "Generator", "Relay_A", "Extraction").
-- state: "Locked" | "Active" | "Completed"
return Matter.component("Objective", {
	id = "",
	state = "Locked",
})
