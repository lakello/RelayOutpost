-- Weapon definitions. CombatSystem reads these; clients never send damage values.

local WeaponConfig = {
	HitscanBlaster = {
		damage = 25,
		fireRate = 2.5, -- shots per second (cooldown = 1/fireRate)
		maxRange = 200, -- studs, server raycast limit
		originTolerance = 8, -- studs: max allowed gap between client-claimed and actual origin
	},
}

return WeaponConfig
