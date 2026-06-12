local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

-- Marker component: distinguishes relay beacon entities from other Objective entities
-- (e.g. Generator also has Objective; this tag makes queries unambiguous).
return Matter.component("RelayBeacon", {})
