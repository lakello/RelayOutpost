-- Convenience re-export of all component definitions.
-- Usage: local C = require(ReplicatedStorage.Shared.Components)
-- Then: C.Health, C.Transform, C.PlayerRef, ...

return {
	Health = require(script.Health),
	Transform = require(script.Transform),
	PlayerRef = require(script.PlayerRef),
	CharacterRef = require(script.CharacterRef),
	WeaponState = require(script.WeaponState),
	DownedState = require(script.DownedState),
	Generator = require(script.Generator),
	Objective = require(script.Objective),
	Enemy = require(script.Enemy),
	Target = require(script.Target),
	AttackCooldown = require(script.AttackCooldown),
	MeleeAttack = require(script.MeleeAttack),
	ModelRef = require(script.ModelRef),
	CaptureProgress = require(script.CaptureProgress),
	RelayBeacon = require(script.RelayBeacon),
}
