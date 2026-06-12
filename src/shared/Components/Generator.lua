local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Matter = require(ReplicatedStorage.Packages.Matter)

-- Marks an entity as the generator objective.
-- generatorModel: reference to the GeneratorVisual Part in Workspace (may be nil if not yet placed).
return Matter.component("Generator", {
	generatorModel = nil :: BasePart?,
})
