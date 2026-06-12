-- Authoritative match state machine.
-- Runs at 2 Hz. Uses os.clock() for phase timers — NOT dt — because dt is the
-- Heartbeat frame time (~0.016 s) which is unrelated to the system's tick interval.
--
-- Phase flow:
--   Lobby → Wave 1 → Relay (A active) → Wave 2 → Relay (B active) → Wave 3
--        → Relay (C active) → Extraction (wave 4) → Victory
--   Any phase → Defeat   (generator HP ≤ 0)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemySpawnSystem = require(script.Parent.EnemySpawnSystem)
local MatchStateService = require(script.Parent.Parent.Services.MatchStateService)
local C = require(ReplicatedStorage.Shared.Components)
local WaveConfig = require(ReplicatedStorage.Shared.Config.WaveConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)
local WaveScaling = require(ReplicatedStorage.Shared.Pure.WaveScaling)

local WaveDirectorSystem = {}

-- ── Config constants ──────────────────────────────────────────────────────

local LOBBY_COUNTDOWN = 10 -- seconds before wave 1 starts

-- ── Internal state ────────────────────────────────────────────────────────

local _phaseStartTime = 0 -- os.clock() when the current phase began

local function phaseElapsed(): number
	return os.clock() - _phaseStartTime
end

local function resetPhaseTimer()
	_phaseStartTime = os.clock()
end

-- ── Helpers ───────────────────────────────────────────────────────────────

-- Returns the relay objective ID unlocked after a given regular wave number.
-- Wave 1 → Relay_A, Wave 2 → Relay_B, Wave 3 → Relay_C.
local function relayForWave(wave: number): string?
	local zone = ZoneConfig.zones[wave]
	return zone and zone.objectiveId or nil
end

local function startWave(wave: number, phaseOverride: string?)
	local playerCount = math.max(1, #Players:GetPlayers())
	local isFinal = WaveScaling.isFinalWave(wave, WaveConfig.waveCount)

	MatchStateService.setPhase(phaseOverride or "Wave")
	MatchStateService.setWave(wave)
	MatchStateService.setObjective(
		isFinal and "Survive the extraction wave!" or "Defend the generator"
	)

	EnemySpawnSystem.queueWave(wave, playerCount)
	resetPhaseTimer()

	print(
		string.format(
			"[WaveDirector] %s %d | players=%d | final=%s",
			phaseOverride or "Wave",
			wave,
			playerCount,
			tostring(isFinal)
		)
	)
end

local function enterRelayPhase(clearedWave: number)
	local relayId = relayForWave(clearedWave)
	if not relayId then
		return
	end
	MatchStateService.setRelayState(relayId, "Active")
	MatchStateService.setPhase("Relay")
	MatchStateService.setObjective(
		string.format("Activate Relay %s — hold [E] near the beacon", relayId:sub(-1))
	)
	resetPhaseTimer()
	print(string.format("[WaveDirector] Wave %d cleared → %s Active", clearedWave, relayId))
end

local function triggerVictory()
	MatchStateService.setPhase("Victory")
	MatchStateService.setObjective("Extraction successful! Mission complete!")
	resetPhaseTimer()
	print("[WaveDirector] VICTORY!")
end

local function triggerDefeat(reason: string)
	MatchStateService.setPhase("Defeat")
	MatchStateService.setObjective(reason)
	resetPhaseTimer()
	print("[WaveDirector] DEFEAT. " .. reason)
end

-- ── Ticking step (2 Hz) ───────────────────────────────────────────────────

function WaveDirectorSystem.step(world: any, _dt: number)
	local phase = MatchStateService.getPhase()

	-- Defeat checks (run before all phase logic every tick)
	if phase ~= "Victory" and phase ~= "Defeat" then
		-- Generator destroyed
		local genHp = MatchStateService.getGeneratorHp()
		if genHp <= 0 then
			triggerDefeat("Generator destroyed. Mission failed.")
			return
		end

		-- All players downed
		local hasPlayer = false
		local anyStanding = false
		for _, _, downedState in world:query(C.PlayerRef, C.DownedState) do
			hasPlayer = true
			if not downedState.isDowned then
				anyStanding = true
				break
			end
		end
		if hasPlayer and not anyStanding then
			triggerDefeat("All operatives down. Mission failed.")
			return
		end
	end

	-- ── Lobby ──────────────────────────────────────────────────────────────
	if phase == "Lobby" then
		local remaining = math.max(0, math.ceil(LOBBY_COUNTDOWN - phaseElapsed()))
		MatchStateService.setObjective(string.format("Match starts in %ds...", remaining))
		if phaseElapsed() >= LOBBY_COUNTDOWN then
			startWave(1)
		end

	-- ── Wave / Extraction ──────────────────────────────────────────────────
	elseif phase == "Wave" or phase == "Extraction" then
		-- Wave is done only when: no enemies alive AND spawn queue is empty
		local alive = MatchStateService.getEnemiesAlive()
		if alive > 0 or EnemySpawnSystem.hasActiveSpawn() then
			return
		end

		local wave = MatchStateService.getWave()

		if phase == "Extraction" or WaveScaling.isFinalWave(wave, WaveConfig.waveCount) then
			triggerVictory()
		else
			enterRelayPhase(wave)
		end

	-- ── Relay ──────────────────────────────────────────────────────────────
	elseif phase == "Relay" then
		local wave = MatchStateService.getWave()
		local relayId = relayForWave(wave)
		if not relayId then
			return
		end

		local relays = MatchStateService.getRelayStates()
		local completed = relays[relayId] == "Completed"

		-- InteractionSystem sets the relay to Completed when players capture it.
		-- WaveDirector polls here and advances the phase once that happens.
		if completed then
			local nextWave = wave + 1
			if nextWave > WaveConfig.waveCount then
				-- All 3 relays done → start extraction (wave 4)
				startWave(nextWave, "Extraction")
			else
				startWave(nextWave)
			end
		end

		-- Victory / Defeat: terminal states, no transitions needed
	end
end

-- Call once from Bootstrap before the Heartbeat loop begins.
function WaveDirectorSystem.init()
	MatchStateService.setPhase("Lobby")
	MatchStateService.setWave(0)
	MatchStateService.setObjective(string.format("Match starts in %ds...", LOBBY_COUNTDOWN))
	resetPhaseTimer()
	print(string.format("[WaveDirector] Initialized. Lobby countdown: %ds", LOBBY_COUNTDOWN))
end

return WaveDirectorSystem
