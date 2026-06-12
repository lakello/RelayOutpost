-- Collects server-side runtime data and broadcasts it to all connected clients.
-- Runs at 4 Hz. Only fires when at least one player is connected.
-- Payload carries everything the debug overlay needs: ECS entity count,
-- system timings from SystemScheduler, and current MatchStateService snapshot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MatchStateService = require(script.Parent.Parent.Services.MatchStateService)

local DebugSnapshotSystem = {}

local _scheduler: any = nil -- set in init()

-- ── Ticking step (4 Hz) ───────────────────────────────────────────────────

function DebugSnapshotSystem.step(_world: any, _dt: number)
	if #Players:GetPlayers() == 0 then
		return
	end

	local state = MatchStateService.getSnapshot()

	Remotes.DebugSnapshot:FireAllClients({
		entityCount = _scheduler:entityCount(),
		enemiesAlive = state.enemiesAlive,
		wave = state.wave,
		phase = state.phase,
		generatorHp = state.generator,
		relays = state.relays,
		systems = _scheduler:getTimings(),
		serverTime = os.clock(),
	})
end

-- ── Init ─────────────────────────────────────────────────────────────────

-- Pass the SystemScheduler instance so this system can read timings + entity count.
function DebugSnapshotSystem.init(scheduler: any)
	_scheduler = scheduler
	print("[DebugSnapshot] Initialized.")
end

return DebugSnapshotSystem
