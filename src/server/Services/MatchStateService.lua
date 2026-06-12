-- Authoritative match state.
-- Systems call setters here; ReplicationBridgeSystem reads getSnapshot() and fires to clients.
-- This module does NOT reference Remotes -- sending is the bridge's responsibility.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

-- Private state table (never returned directly -- always via getSnapshot)
local _state = {
	phase = "Lobby",
	wave = 0,
	enemiesAlive = 0,
	generator = {
		current = MatchConfig.generatorMaxHealth,
		max = MatchConfig.generatorMaxHealth,
	},
	relays = {},
	currentObjective = "Defend the generator",
	extractionCountdown = nil :: number?,
}

-- Initialise relay states from ZoneConfig (all Locked at start)
for _, zone in ipairs(ZoneConfig.zones) do
	_state.relays[zone.objectiveId] = "Locked"
end

-- Starts dirty so new players receive state on the first bridge tick
local _dirty = true

local MatchStateService = {}

-- Returns a shallow copy safe to send over RemoteEvent.
function MatchStateService.getSnapshot()
	return {
		phase = _state.phase,
		wave = _state.wave,
		enemiesAlive = _state.enemiesAlive,
		generator = { current = _state.generator.current, max = _state.generator.max },
		relays = table.clone(_state.relays),
		currentObjective = _state.currentObjective,
		extractionCountdown = _state.extractionCountdown,
	}
end

function MatchStateService.isDirty(): boolean
	return _dirty
end

function MatchStateService.clearDirty()
	_dirty = false
end

function MatchStateService.markDirty()
	_dirty = true
end

-- ── Setters ────────────────────────────────────────────────────────────────

function MatchStateService.setGeneratorHp(current: number)
	_state.generator.current = math.clamp(current, 0, _state.generator.max)
	_dirty = true
end

function MatchStateService.setPhase(phase: string)
	_state.phase = phase
	_dirty = true
end

function MatchStateService.setWave(wave: number)
	_state.wave = wave
	_dirty = true
end

function MatchStateService.setEnemiesAlive(count: number)
	_state.enemiesAlive = count
	_dirty = true
end

function MatchStateService.setRelayState(objectiveId: string, state: string)
	_state.relays[objectiveId] = state
	_dirty = true
end

function MatchStateService.setObjective(text: string)
	_state.currentObjective = text
	_dirty = true
end

function MatchStateService.setExtractionCountdown(seconds: number?)
	_state.extractionCountdown = seconds
	_dirty = true
end

-- ── Getters ────────────────────────────────────────────────────────────────

function MatchStateService.getGeneratorHp(): (number, number)
	return _state.generator.current, _state.generator.max
end

function MatchStateService.getPhase(): string
	return _state.phase
end

function MatchStateService.getRelayStates(): { [string]: string }
	return table.clone(_state.relays)
end

function MatchStateService.getWave(): number
	return _state.wave
end

function MatchStateService.getEnemiesAlive(): number
	return _state.enemiesAlive
end

return MatchStateService
