local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

-- Tracks relay activation progress.
-- contributors: { [userId: number]: boolean } — set of player UserIds currently holding E.
return Matter.component("CaptureProgress", {
	current = 0,
	required = 5,
	contributors = {},
})
