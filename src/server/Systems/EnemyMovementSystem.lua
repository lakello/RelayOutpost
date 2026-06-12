-- Moves enemies toward their assigned Target (runs at 10–20 Hz).
-- Uses PathfindingSystem waypoints when available; falls back to direct MoveTo.
-- Updates the Transform component from the model's actual position each tick.
-- MoveTo is only re-issued when the target shifts by more than RESEND_THRESHOLD
-- to avoid the animation-restart jitter that comes from calling it every frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage.Shared.Components)
local PathfindingSystem = require(script.Parent.PathfindingSystem)

local EnemyMovementSystem = {}

-- Only re-call MoveTo when the waypoint moves more than this many studs.
-- Waypoints are 4 studs apart, so any waypoint advance triggers a new call.
local RESEND_THRESHOLD = 1.5

-- Last MoveTo destination per entity — keyed by Matter entity ID.
local _lastMoveTargets: { [number]: Vector3 } = {}

-- Resolve the world-space position of a target entity.
local function getTargetPosition(world: any, targetEntityId: number, targetType: string): Vector3?
	if targetType == "Player" then
		local charRef = world:get(targetEntityId, C.CharacterRef)
		if not charRef or not charRef.character then
			return nil
		end
		local hrp = charRef.character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return hrp and hrp.Position or nil
	elseif targetType == "Generator" then
		local transform = world:get(targetEntityId, C.Transform)
		return transform and transform.cframe.Position or nil
	end
	return nil
end

function EnemyMovementSystem.step(world: any, _dt: number)
	-- Drop stale entries for despawned enemies so the table doesn't grow forever.
	for entityId in pairs(_lastMoveTargets) do
		if not world:contains(entityId) then
			_lastMoveTargets[entityId] = nil
		end
	end

	for entityId, _enemy, modelRef, target in world:query(C.Enemy, C.ModelRef, C.Target) do
		if not modelRef.model or not modelRef.model.Parent then
			continue
		end

		local model = modelRef.model
		local hrp = model.PrimaryPart
		if not hrp then
			continue
		end

		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid?
		if not humanoid or humanoid.Health <= 0 then
			continue
		end

		-- Keep ECS Transform in sync with actual physics position
		world:insert(entityId, C.Transform({ cframe = hrp.CFrame }))

		-- If no target, stand still
		if not target.entityId or not target.targetType then
			continue
		end

		if not world:contains(target.entityId) then
			continue
		end

		local targetPos = getTargetPosition(world, target.entityId, target.targetType)
		if not targetPos then
			continue
		end

		-- Advance waypoint index first so getNextWaypoint returns the freshest target.
		PathfindingSystem.tryAdvanceWaypoint(entityId, hrp.Position)

		-- Use PathfindingSystem waypoints when available; falls back to targetPos directly.
		local moveTarget = PathfindingSystem.getNextWaypoint(entityId, targetPos)

		-- Only re-issue MoveTo when the destination has shifted enough to matter.
		-- Calling MoveTo every frame at 20 Hz resets the Humanoid's walk animation
		-- each tick, which causes visible stuttering.
		local prev = _lastMoveTargets[entityId]
		if not prev or (moveTarget - prev).Magnitude > RESEND_THRESHOLD then
			humanoid:MoveTo(moveTarget)
			_lastMoveTargets[entityId] = moveTarget
		end
	end
end

return EnemyMovementSystem
