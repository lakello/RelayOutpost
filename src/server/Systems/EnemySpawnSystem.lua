-- Maintains a spawn queue and releases enemies in batches at spawnInterval rate.
-- Call queueWave() to enqueue; step() drains over time.
-- hasActiveSpawn() lets WaveDirectorSystem know spawning is still in progress.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyFactory = require(script.Parent.Parent.Services.EnemyFactory)
local WaveConfig = require(ReplicatedStorage.Shared.Config.WaveConfig)
local WaveScaling = require(ReplicatedStorage.Shared.Pure.WaveScaling)

local EnemySpawnSystem = {}

type QueueEntry = { kind: string, cframe: CFrame, statMult: number }

local _queue: { QueueEntry } = {}
local _spawnTimer = 0

-- ── Public ────────────────────────────────────────────────────────────────

-- True while there are enemies still queued for spawning.
-- WaveDirectorSystem uses this to distinguish "wave starting" from "wave cleared".
function EnemySpawnSystem.hasActiveSpawn(): boolean
	return #_queue > 0
end

-- Enqueue a full wave of enemies for gradual release.
function EnemySpawnSystem.queueWave(waveNumber: number, playerCount: number)
	local markers = CollectionService:GetTagged("EnemySpawn")
	if #markers == 0 then
		warn("[EnemySpawn] No EnemySpawn markers. Run MapBlockoutSetup Command Bar script first.")
		return
	end

	local budget = WaveScaling.getEnemyBudget(waveNumber, playerCount)

	-- Extraction wave gets an extra budget multiplier
	if WaveScaling.isFinalWave(waveNumber, WaveConfig.waveCount) then
		budget = math.floor(budget * WaveConfig.extractionWaveBudgetMultiplier)
	end

	local statMult = WaveScaling.getStatMultiplier(waveNumber)
	local waveIndex = math.min(waveNumber, 4)
	local mix = WaveConfig.waveMix[waveIndex] or WaveConfig.waveMix[1]
	local runnerChance = mix.Runner or 0

	for i = 1, budget do
		local marker = markers[((i - 1) % #markers) + 1]
		local kind = (math.random() < runnerChance) and "Runner" or "Crawler"
		table.insert(_queue, { kind = kind, cframe = marker.CFrame, statMult = statMult })
	end

	print(
		string.format(
			"[EnemySpawn] Wave %d queued: %d enemies | statMult=%.2f | Runner=%.0f%%",
			waveNumber,
			budget,
			statMult,
			runnerChance * 100
		)
	)
end

-- Ticking step (2 Hz): releases WaveConfig.spawnBatchSize enemies per interval.
function EnemySpawnSystem.step(world: any, dt: number)
	if #_queue == 0 then
		return
	end

	_spawnTimer -= dt
	if _spawnTimer > 0 then
		return
	end
	_spawnTimer = WaveConfig.spawnInterval

	local batchSize = math.min(WaveConfig.spawnBatchSize, #_queue)
	for _ = 1, batchSize do
		local entry = table.remove(_queue, 1)
		if entry then
			EnemyFactory.createEnemy(world, entry.kind, entry.cframe, entry.statMult)
		end
	end
end

return EnemySpawnSystem
