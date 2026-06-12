-- Pure wave budget and enemy scaling calculations. No Roblox services.

local WaveScaling = {}

-- Total enemy count to spawn for a given wave and player count.
-- Formula: 10 base + 5 per wave + 2 per extra player.
function WaveScaling.getEnemyBudget(waveNumber: number, playerCount: number): number
	return 10 + waveNumber * 5 + math.max(playerCount - 1, 0) * 2
end

-- Damage/health multiplier applied on top of base enemy stats.
-- Wave 1 = 1.0x, each subsequent wave adds 15%.
function WaveScaling.getStatMultiplier(waveNumber: number): number
	return 1 + (waveNumber - 1) * 0.15
end

-- Is this the final (extraction) wave?
-- Extraction wave is waveCount+1.
function WaveScaling.isFinalWave(waveNumber: number, totalWaves: number): boolean
	return waveNumber > totalWaves
end

return WaveScaling
