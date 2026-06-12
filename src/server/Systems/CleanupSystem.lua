-- Destroys enemies whose Health has reached zero, updates enemiesAlive in MatchStateService.
-- Runs at 5 Hz. Collects dead entity IDs first, then despawns to avoid mid-query mutation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyFactory = require(script.Parent.Parent.Services.EnemyFactory)
local MatchStateService = require(script.Parent.Parent.Services.MatchStateService)
local C = require(ReplicatedStorage.Shared.Components)

local CleanupSystem = {}

function CleanupSystem.step(world: any, _dt: number)
	-- Collect IDs of dead enemies without mutating during iteration.
	-- An enemy is dead if:
	--   (a) ECS health reached 0 (shot by player / Humanoid.Died synced it), OR
	--   (b) the Roblox model was destroyed (fell off the map past FallenPartsDestroyHeight).
	local dead: { number } = {}
	for entityId, _enemy, health, modelRef in world:query(C.Enemy, C.Health, C.ModelRef) do
		local modelGone = modelRef.model == nil or modelRef.model.Parent == nil
		-- Safety net: if HumanoidRootPart was destroyed (fell off the map via
		-- FallenPartsDestroyHeight) the Model container survives but the root is gone.
		-- The ChildRemoved handler in EnemyFactory should set health to 0 first, but
		-- this catches any edge case where that event fired after a despawn race.
		local rootGone = not modelGone and modelRef.model:FindFirstChild("HumanoidRootPart") == nil
		if health.current <= 0 or modelGone or rootGone then
			table.insert(dead, entityId)
		end
	end

	for _, entityId in ipairs(dead) do
		EnemyFactory.destroyEnemy(world, entityId)
	end

	-- Update replicated enemy count whenever any cleanup happened
	if #dead > 0 then
		local alive = 0
		for _ in world:query(C.Enemy) do
			alive += 1
		end
		MatchStateService.setEnemiesAlive(alive)
		print(string.format("[Cleanup] Removed %d dead enemies | alive=%d", #dead, alive))
	end
end

return CleanupSystem
