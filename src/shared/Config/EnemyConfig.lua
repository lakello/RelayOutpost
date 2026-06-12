-- Base stats for each enemy type (wave 1, before WaveScaling multipliers).

export type EnemyKind = "Crawler" | "Runner"

local EnemyConfig: { [string]: { [string]: number } } = {
	Crawler = {
		maxHealth = 80,
		moveSpeed = 8,
		meleeRange = 5,
		meleeDamage = 15,
		attackCooldown = 1.0,
	},
	Runner = {
		maxHealth = 50,
		moveSpeed = 18,
		meleeRange = 4,
		meleeDamage = 10,
		attackCooldown = 0.85,
	},
}

return EnemyConfig
