-- Applies server-authoritative melee damage when an enemy is within attack range.
-- Runs at ~10 Hz. Damages players via ECS Health + Humanoid.Health (auto-replicated).
-- Damages generator via ECS Health + MatchStateService (for HUD replication).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage.Shared.Components)
local DamageRules = require(ReplicatedStorage.Shared.Pure.DamageRules)
local MatchStateService = require(script.Parent.Parent.Services.MatchStateService)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local EnemyMeleeSystem = {}

-- ── Internal helpers ──────────────────────────────────────────────────────

-- Returns the world-space position of the target, or nil.
local function getTargetPosition(world: any, entityId: number, targetType: string): Vector3?
	if targetType == "Player" then
		local charRef = world:get(entityId, C.CharacterRef)
		if not charRef or not charRef.character then
			return nil
		end
		local hrp = charRef.character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return hrp and hrp.Position or nil
	elseif targetType == "Generator" then
		local transform = world:get(entityId, C.Transform)
		return transform and transform.cframe.Position or nil
	end
	return nil
end

local function damagePlayer(world: any, playerEntityId: number, damage: number)
	local health = world:get(playerEntityId, C.Health)
	local charRef = world:get(playerEntityId, C.CharacterRef)
	local downedState = world:get(playerEntityId, C.DownedState)
	if not health or not charRef or not charRef.character then
		return
	end

	-- Already downed: don't stack damage.
	if downedState and downedState.isDowned then
		return
	end

	local newHp, _ = DamageRules.applyDamage(health.current, damage)

	if newHp <= 0 then
		-- Transition to downed state: keep Humanoid alive (Health=1) to prevent Roblox
		-- from automatically respawning the character, then immobilise.
		world:insert(playerEntityId, C.Health({ current = 0, max = health.max }))
		world:insert(playerEntityId, C.DownedState({ isDowned = true, downedAt = os.clock() }))

		local humanoid = charRef.character:FindFirstChildOfClass("Humanoid") :: Humanoid?
		if humanoid then
			humanoid.Health = 1 -- > 0 so Roblox does not trigger respawn
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
		end

		local playerRef = world:get(playerEntityId, C.PlayerRef)
		if playerRef then
			Remotes.PlayerStateEvent:FireAllClients({
				type = "Downed",
				userId = playerRef.player.UserId,
			})
		end

		print(string.format("[EnemyMelee] Player entity=%d DOWNED", playerEntityId))
	else
		world:insert(playerEntityId, C.Health({ current = newHp, max = health.max }))

		-- Sync to Humanoid so the client sees HP change via HealthChanged
		local humanoid = charRef.character:FindFirstChildOfClass("Humanoid") :: Humanoid?
		if humanoid then
			humanoid.Health = newHp
		end
	end
end

local function damageGenerator(world: any, genEntityId: number, damage: number)
	local health = world:get(genEntityId, C.Health)
	if not health then
		return
	end

	local newHp, _ = DamageRules.applyDamage(health.current, damage)
	world:insert(genEntityId, C.Health({ current = newHp, max = health.max }))

	-- Propagate to MatchStateService so HUD reflects change via ReplicationBridgeSystem
	MatchStateService.setGeneratorHp(newHp)

	if newHp <= 0 then
		print("[EnemyMelee] Generator destroyed! HP=0")
		MatchStateService.setPhase("Defeat")
		MatchStateService.setObjective("Generator destroyed")
	end
end

-- ── Ticking step ──────────────────────────────────────────────────────────

function EnemyMeleeSystem.step(world: any, _dt: number)
	local now = os.clock()

	for entityId, _enemy, modelRef, target, meleeAttack, attackCooldown in
		world:query(C.Enemy, C.ModelRef, C.Target, C.MeleeAttack, C.AttackCooldown)
	do
		-- Skip enemies with no target
		if not target.entityId or not target.targetType then
			continue
		end
		if not world:contains(target.entityId) then
			continue
		end

		-- Skip if on cooldown
		if now - attackCooldown.lastAttackTime < attackCooldown.cooldown then
			continue
		end

		-- Skip if model is gone
		if not modelRef.model or not modelRef.model.Parent then
			continue
		end
		local hrp = modelRef.model.PrimaryPart
		if not hrp then
			continue
		end

		-- Skip if target is out of melee range
		local targetPos = getTargetPosition(world, target.entityId, target.targetType)
		if not targetPos then
			continue
		end

		local dist = (hrp.Position - targetPos).Magnitude
		if dist > meleeAttack.range then
			continue
		end

		-- Register the attack
		world:insert(
			entityId,
			C.AttackCooldown({
				lastAttackTime = now,
				cooldown = attackCooldown.cooldown,
			})
		)

		if target.targetType == "Player" then
			damagePlayer(world, target.entityId, meleeAttack.damage)
		elseif target.targetType == "Generator" then
			damageGenerator(world, target.entityId, meleeAttack.damage)
		end
	end
end

return EnemyMeleeSystem
