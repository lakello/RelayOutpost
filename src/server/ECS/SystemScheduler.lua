-- Throttled ECS system scheduler with per-system timing registry.
-- Systems are called at most `hz` times per second; hz=0 means every frame.

local SystemScheduler = {}
SystemScheduler.__index = SystemScheduler

local LOG_INTERVAL = 10 -- seconds between periodic debug log lines

type SystemEntry = {
	name: string,
	fn: (world: any, dt: number) -> (),
	interval: number,
	lastRun: number,
	lastDurationMs: number,
	totalTicks: number,
}

function SystemScheduler.new(world: any)
	return setmetatable({
		_world = world,
		_systems = {} :: { SystemEntry },
		_tickCount = 0,
		_lastLogAt = 0,
	}, SystemScheduler)
end

-- Register a system function.
-- name:  display name used in logs and debug overlay.
-- fn:    function(world, dt) called each tick.
-- hz:    target ticks per second; 0 = every frame.
function SystemScheduler:register(name: string, fn: (any, number) -> (), hz: number)
	local interval = (hz > 0) and (1 / hz) or 0
	table.insert(self._systems, {
		name = name,
		fn = fn,
		interval = interval,
		lastRun = 0,
		lastDurationMs = 0,
		totalTicks = 0,
	})
end

-- Call once per Heartbeat from Bootstrap.
function SystemScheduler:step(dt: number)
	local now = os.clock()
	self._tickCount += 1

	for _, entry in ipairs(self._systems) do
		if now - entry.lastRun >= entry.interval then
			local t0 = os.clock()
			-- Throttled systems receive actual elapsed time since last tick, not the raw
			-- Heartbeat frame time (~0.016 s). Without this, a 10 Hz system gets dt≈0.016
			-- instead of ≈0.1 — stretching a 5-second relay capture to ~31 seconds.
			-- Every-frame systems (interval==0) keep the Heartbeat dt unchanged.
			-- Clamped to 2× interval to guard against a huge value on the very first tick
			-- (when lastRun==0 and now-lastRun equals the server uptime in seconds).
			local tickDt: number
			if entry.interval > 0 then
				tickDt = math.min(now - entry.lastRun, entry.interval * 2)
			else
				tickDt = dt
			end
			entry.fn(self._world, tickDt)
			entry.lastDurationMs = (os.clock() - t0) * 1000
			entry.lastRun = now
			entry.totalTicks += 1
		end
	end

	-- Periodic log: entity count + per-system timing
	if now - self._lastLogAt >= LOG_INTERVAL then
		self._lastLogAt = now
		local systemCount = #self._systems
		print(
			string.format(
				"[Scheduler] heartbeat=%d | entities=%d | systems=%d",
				self._tickCount,
				self._world:size(),
				systemCount
			)
		)
		for _, entry in ipairs(self._systems) do
			print(
				string.format(
					"  %s: %.3f ms last | %d ticks total",
					entry.name,
					entry.lastDurationMs,
					entry.totalTicks
				)
			)
		end
	end
end

-- Returns a snapshot of system timings for the debug overlay.
-- Returns: { [systemName]: lastDurationMs }
function SystemScheduler:getTimings(): { [string]: number }
	local snapshot = {}
	for _, entry in ipairs(self._systems) do
		snapshot[entry.name] = entry.lastDurationMs
	end
	return snapshot
end

-- Returns total entities in the world.
function SystemScheduler:entityCount(): number
	return self._world:size()
end

return SystemScheduler
