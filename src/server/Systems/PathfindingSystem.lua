-- Async enemy pathfinding via PathfindingService.
-- Runs at 2 Hz. Each enemy has an AgentState in the module-local _agents table
-- (not an ECS component) so path state is never written from async callbacks.
--
-- ComputeAsync is called inside task.spawn to avoid blocking the Heartbeat loop.
-- The callback writes only to _agents (a plain Lua table) — never to the ECS world.
-- EnemyMovementSystem calls getNextWaypoint() and tryAdvanceWaypoint() each tick.
--
-- Graceful fallback: if no path has been computed yet, getNextWaypoint() returns
-- the raw target position so the enemy moves directly (existing behavior).

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage.Shared.Components)

local PathfindingSystem = {}

-- ── Config ────────────────────────────────────────────────────────────────

local RECOMPUTE_TARGET_DIST = 8 -- studs: recompute when target moves this far
local STALE_AGE = 5 -- seconds: force recompute even if target hasn't moved
local MAX_NEW_PER_STEP = 16 -- cap on new ComputeAsync calls launched per tick
local WAYPOINT_REACH = 3 -- studs: advance waypoint index when this close

local AGENT_PARAMS = {
	AgentRadius = 2.5,
	AgentHeight = 5,
	AgentCanJump = false,
	AgentCanClimb = false,
	WaypointSpacing = 4, -- denser path = smoother movement around corners
}

-- ── Internal state ────────────────────────────────────────────────────────

type AgentState = {
	waypoints: { Vector3 },
	index: number,
	computedAt: number,
	targetPos: Vector3,
	computing: boolean,
}

-- Keyed by Matter entityId. Written only from the main thread (step) or from
-- task.spawn callbacks (which run between frames, never mid-iteration).
local _agents: { [number]: AgentState } = {}

-- ── Helpers ───────────────────────────────────────────────────────────────

local function needsRecompute(agent: AgentState, targetPos: Vector3): boolean
	if agent.computing then
		return false
	end
	-- No usable waypoints remaining
	if #agent.waypoints == 0 or agent.index > #agent.waypoints then
		return true
	end
	-- Path is stale
	if os.clock() - agent.computedAt > STALE_AGE then
		return true
	end
	-- Target has moved significantly
	if (agent.targetPos - targetPos).Magnitude > RECOMPUTE_TARGET_DIST then
		return true
	end
	return false
end

local function startCompute(entityId: number, startPos: Vector3, targetPos: Vector3)
	local agent = _agents[entityId]
	if not agent then
		_agents[entityId] = {
			waypoints = {},
			index = 1,
			computedAt = 0,
			targetPos = targetPos,
			computing = true,
		}
		agent = _agents[entityId]
	else
		agent.computing = true
	end

	task.spawn(function()
		local path = PathfindingService:CreatePath(AGENT_PARAMS)
		local ok = pcall(path.ComputeAsync, path, startPos, targetPos)

		-- Entity may have been despawned while we were computing.
		local a = _agents[entityId]
		if not a then
			return
		end
		a.computing = false

		if not ok or path.Status ~= Enum.PathStatus.Success then
			-- Keep existing path (if any); step() will retry on the next needsRecompute.
			return
		end

		local positions: { Vector3 } = {}
		for i, wp in ipairs(path:GetWaypoints()) do
			if i > 1 then -- skip waypoint[1] which is the enemy's current position
				table.insert(positions, wp.Position)
			end
		end

		if #positions > 0 then
			a.waypoints = positions
			a.index = 1
			a.computedAt = os.clock()
			a.targetPos = targetPos
		end
	end)
end

-- ── Public API ────────────────────────────────────────────────────────────

-- Returns the next waypoint the enemy should walk toward.
-- Falls back to fallbackPos (raw target) when no path is available yet.
function PathfindingSystem.getNextWaypoint(entityId: number, fallbackPos: Vector3): Vector3
	local agent = _agents[entityId]
	if not agent or #agent.waypoints == 0 or agent.index > #agent.waypoints then
		return fallbackPos
	end
	return agent.waypoints[agent.index]
end

-- Advances the waypoint index when the enemy is close enough to the current one.
-- Call this every EnemyMovement tick after MoveTo.
function PathfindingSystem.tryAdvanceWaypoint(entityId: number, currentPos: Vector3)
	local agent = _agents[entityId]
	if not agent or agent.index > #agent.waypoints then
		return
	end
	if (currentPos - agent.waypoints[agent.index]).Magnitude < WAYPOINT_REACH then
		agent.index += 1
	end
end

-- ── Ticking step (2 Hz) ───────────────────────────────────────────────────

function PathfindingSystem.step(world: any, _dt: number)
	-- Remove agents whose entities have been despawned (CleanupSystem may have removed them).
	for entityId in pairs(_agents) do
		if not world:contains(entityId) then
			_agents[entityId] = nil
		end
	end

	-- Launch new path computes for enemies that need updated paths.
	local launched = 0
	for entityId, _enemy, modelRef, target in world:query(C.Enemy, C.ModelRef, C.Target) do
		if launched >= MAX_NEW_PER_STEP then
			break
		end
		if not target.entityId then
			continue
		end

		local hrp = modelRef.model and modelRef.model.PrimaryPart
		if not hrp then
			continue
		end

		-- Resolve the target's world position the same way EnemyMovementSystem does.
		local targetPos: Vector3? = nil
		if target.targetType == "Player" then
			local charRef = world:get(target.entityId, C.CharacterRef)
			if charRef and charRef.character then
				local tHrp = charRef.character:FindFirstChild("HumanoidRootPart") :: BasePart?
				targetPos = tHrp and tHrp.Position
			end
		elseif target.targetType == "Generator" then
			local transform = world:get(target.entityId, C.Transform)
			targetPos = transform and transform.cframe.Position
		end

		if not targetPos then
			continue
		end

		local agent = _agents[entityId]
		if agent == nil or needsRecompute(agent, targetPos) then
			startCompute(entityId, hrp.Position, targetPos)
			launched += 1
		end
	end
end

return PathfindingSystem
