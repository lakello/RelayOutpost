-- Wave composition and timing. WaveDirectorSystem reads these.

local WaveConfig = {
	waveCount = 3, -- regular waves; wave (waveCount+1) is the extraction wave
	spawnBatchSize = 3, -- enemies spawned per spawn tick
	spawnInterval = 2.5, -- seconds between spawn batches

	-- Enemy type mix per wave number (fractions must sum to 1.0).
	-- Wave 4 is the extraction wave.
	waveMix = {
		[1] = { Crawler = 1.0, Runner = 0.0 },
		[2] = { Crawler = 0.7, Runner = 0.3 },
		[3] = { Crawler = 0.5, Runner = 0.5 },
		[4] = { Crawler = 0.3, Runner = 0.7 },
	},

	extractionWaveBudgetMultiplier = 1.5,
}

return WaveConfig
