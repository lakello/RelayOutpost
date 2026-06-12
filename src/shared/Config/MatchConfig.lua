-- Global match parameters. No magic numbers in systems — read from here.

local MatchConfig = {
	-- Health
	generatorMaxHealth = 100,
	playerMaxHealth = 100,

	-- Downed / revive
	downedDuration = 30, -- seconds a downed player has before dying
	reviveDuration = 5, -- seconds to complete a revive
	reviveHpFraction = 0.3, -- revived player receives this fraction of max HP

	-- Server-side interaction distance validation
	interactMaxDistance = 10, -- studs
	reviveMaxDistance = 8, -- studs

	-- Wave timing
	interWaveDelay = 15, -- seconds between wave-cleared and next wave start

	-- Objectives
	relayCount = 3,
	relayActivationTime = 5, -- seconds for one player to fully capture a relay

	-- Extraction
	extractionCountdown = 60, -- seconds to survive the extraction wave
}

return MatchConfig
