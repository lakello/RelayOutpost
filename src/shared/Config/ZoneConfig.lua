-- Zone metadata and unlock order.
-- WaveDirectorSystem unlocks zones sequentially after each wave is cleared.

local ZoneConfig = {
	zones = {
		{ zoneId = "A", objectiveId = "Relay_A", spawnGroupId = "Zone_A", unlockAfterWave = 1 },
		{ zoneId = "B", objectiveId = "Relay_B", spawnGroupId = "Zone_B", unlockAfterWave = 2 },
		{ zoneId = "C", objectiveId = "Relay_C", spawnGroupId = "Zone_C", unlockAfterWave = 3 },
	},
}

return ZoneConfig
