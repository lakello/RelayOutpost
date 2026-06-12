-- Assigns a Target component to each enemy every tick (runs at 4–5 Hz).
-- Priority: nearest alive non-downed player → generator (fallback).
-- Never targets downed players as primary.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage.Shared.Components)

local TargetAcquisitionSystem = {}

-- ── Internal helpers ──────────────────────────────────────────────────────

type TargetInfo = {
	entityId: number,
	position: Vector3,
	targetType: string,
}

-- Collect all valid player targets: alive, not downed, character loaded.
local function collectPlayerTargets(world: any): { TargetInfo }
	local targets = {}
	for entityId, charRef, health, downedState in
		world:query(C.CharacterRef, C.Health, C.DownedState)
	do
		if health.current <= 0 then
			continue
		end
		if downedState.isDowned then
			continue
		end
		if not charRef.character then
			continue
		end
		local hrp = charRef.character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			continue
		end
		table.insert(targets, {
			entityId = entityId,
			position = hrp.Position,
			targetType = "Player",
		})
	end
	return targets
end

-- Find the generator entity (must have Generator + Transform + Health > 0).
local function findGeneratorTarget(world: any): TargetInfo?
	for entityId, _gen, transform, health in world:query(C.Generator, C.Transform, C.Health) do
		if health.current > 0 then
			return {
				entityId = entityId,
				position = transform.cframe.Position,
				targetType = "Generator",
			}
		end
	end
	return nil
end

-- ── Ticking step ──────────────────────────────────────────────────────────

function TargetAcquisitionSystem.step(world: any, _dt: number)
	local playerTargets = collectPlayerTargets(world)
	local generatorTarget = findGeneratorTarget(world)

	for entityId, _enemy, modelRef in world:query(C.Enemy, C.ModelRef) do
		if not modelRef.model or not modelRef.model.Parent then
			continue
		end

		local hrp = modelRef.model.PrimaryPart
		if not hrp then
			continue
		end

		local enemyPos = hrp.Position
		local bestTarget: TargetInfo? = nil
		local bestDistSq = math.huge

		-- Find nearest alive player
		for _, t in ipairs(playerTargets) do
			local dSq = (t.position - enemyPos).Magnitude
			dSq = dSq * dSq
			if dSq < bestDistSq then
				bestDistSq = dSq
				bestTarget = t
			end
		end

		-- Generator competes as an equal-priority target — nearest wins.
		-- Enemies will attack it if it's closer than any living player.
		if generatorTarget then
			local dSq = (generatorTarget.position - enemyPos).Magnitude
			dSq = dSq * dSq
			if dSq < bestDistSq then
				bestDistSq = dSq
				bestTarget = generatorTarget
			end
		end

		if bestTarget then
			world:insert(
				entityId,
				C.Target({ entityId = bestTarget.entityId, targetType = bestTarget.targetType })
			)
		else
			world:insert(entityId, C.Target({ entityId = nil, targetType = nil }))
		end
	end
end

return TargetAcquisitionSystem
