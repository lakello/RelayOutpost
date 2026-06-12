-- Pure damage and healing calculations. No Roblox services or instances.

local DamageRules = {}

-- Apply damage. Returns (newHp, isDead).
-- HP is clamped to [0, currentHp]; cannot go negative.
function DamageRules.applyDamage(currentHp: number, damage: number): (number, boolean)
	local newHp = math.max(0, currentHp - damage)
	return newHp, newHp <= 0
end

-- Apply healing, clamped to maxHp.
function DamageRules.applyHeal(currentHp: number, maxHp: number, amount: number): number
	return math.min(maxHp, currentHp + amount)
end

-- HP a player receives on revive (fraction of max).
-- Caller passes reviveHpFraction from MatchConfig.
function DamageRules.reviveHp(maxHp: number, fraction: number): number
	return math.floor(maxHp * fraction)
end

return DamageRules
