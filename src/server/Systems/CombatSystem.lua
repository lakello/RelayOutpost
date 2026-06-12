-- Server-authoritative hitscan combat.
-- Receives fire intents from clients; validates, raycasts, applies damage.
-- Clients never send a damage value — they send only origin + direction.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage.Shared.Components)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local DamageRules = require(ReplicatedStorage.Shared.Pure.DamageRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerLifecycleSystem = require(script.Parent.PlayerLifecycleSystem)

local CombatSystem = {}

local WEAPON = WeaponConfig.HitscanBlaster
local FIRE_COOLDOWN = 1 / WEAPON.fireRate

-- Simple per-player request counter for rate limiting (max 2× fireRate per second).
local MAX_REQUESTS_PER_SEC = WEAPON.fireRate * 2
local _requestLog: { [Player]: { number } } = {}

local _world: any = nil -- set by init()

-- ── Helpers ───────────────────────────────────────────────────────────────

-- Returns true if the player hasn't exceeded the remote rate limit.
local function isWithinRateLimit(player: Player): boolean
	local now = os.clock()
	local log = _requestLog[player] or {}

	-- Prune entries older than 1 second
	local fresh = {}
	for _, t in ipairs(log) do
		if now - t < 1 then
			table.insert(fresh, t)
		end
	end

	if #fresh >= MAX_REQUESTS_PER_SEC then
		_requestLog[player] = fresh
		return false
	end

	table.insert(fresh, now)
	_requestLog[player] = fresh
	return true
end

-- Walks up the instance tree looking for a Model with an "EntityId" attribute.
-- EnemySpawnSystem (Stage 8) sets this attribute when it creates enemy models.
-- Returns (entityId, Health component) or (nil, nil).
local function findEnemyEntity(hitPart: BasePart): (number?, any)
	local model = hitPart:FindFirstAncestorOfClass("Model")
	if not model then
		return nil, nil
	end

	local entityId = model:GetAttribute("EntityId")
	if typeof(entityId) ~= "number" then
		return nil, nil
	end
	if not _world:contains(entityId) then
		return nil, nil
	end

	-- Confirm it has both Enemy and Health components
	if not _world:get(entityId, C.Enemy) then
		return nil, nil
	end
	local health = _world:get(entityId, C.Health)
	if not health then
		return nil, nil
	end

	return entityId, health
end

-- ── Core fire handler ─────────────────────────────────────────────────────

local function handleFireRequest(player: Player, origin: any, direction: any, clientTime: any)
	-- ── Type validation ────────────────────────────────────────────────────
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if type(clientTime) ~= "number" then
		return
	end

	-- ── Rate limit ─────────────────────────────────────────────────────────
	if not isWithinRateLimit(player) then
		return
	end

	-- ── Character / alive check ────────────────────────────────────────────
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- ── ECS cooldown validation ────────────────────────────────────────────
	local playerEntityId = PlayerLifecycleSystem.getEntityId(player)
	if not playerEntityId then
		return
	end

	-- Downed players cannot fire
	local downedState = _world:get(playerEntityId, C.DownedState)
	if downedState and downedState.isDowned then
		return
	end

	local weaponState = _world:get(playerEntityId, C.WeaponState)
	if not weaponState then
		return
	end

	local now = os.clock()
	if now - weaponState.lastFireTime < FIRE_COOLDOWN then
		return -- server-side cooldown not yet expired
	end

	-- ── Origin proximity check ─────────────────────────────────────────────
	-- If client-claimed origin is too far from actual HRP, use server position.
	-- This closes the gap for lag without trusting arbitrary origins.
	local serverOrigin = hrp.Position
	if (origin - serverOrigin).Magnitude > WEAPON.originTolerance then
		origin = serverOrigin
	end

	-- ── Direction normalisation ────────────────────────────────────────────
	local dirMag = direction.Magnitude
	if dirMag < 0.001 then
		return
	end
	direction = direction / dirMag

	-- ── Record fire time on ECS entity ────────────────────────────────────
	_world:insert(playerEntityId, C.WeaponState({ lastFireTime = now }))

	-- ── Server raycast ─────────────────────────────────────────────────────
	-- Exclude ALL player characters so shots pass through teammates.
	local filterInstances = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(filterInstances, p.Character)
		end
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = filterInstances

	local result = workspace:Raycast(origin, direction * WEAPON.maxRange, rayParams)

	-- ── Miss ───────────────────────────────────────────────────────────────
	if not result then
		Remotes.CombatEvent:FireAllClients({
			shooterUserId = player.UserId,
			hit = false,
			origin = origin,
			direction = direction,
		})
		return
	end

	local hitPart = result.Instance :: BasePart
	local hitPosition = result.Position

	-- ── Enemy hit ─────────────────────────────────────────────────────────
	local enemyEntityId, currentHealth = findEnemyEntity(hitPart)

	if enemyEntityId and currentHealth then
		local newHp, isDead = DamageRules.applyDamage(currentHealth.current, WEAPON.damage)
		_world:insert(enemyEntityId, C.Health({ current = newHp, max = currentHealth.max }))

		print(
			string.format(
				"[Combat] %s -> entity=%d | dmg=%d | HP %d → %d%s",
				player.Name,
				enemyEntityId,
				WEAPON.damage,
				currentHealth.current,
				newHp,
				isDead and " [DEAD]" or ""
			)
		)

		-- TODO Stage 8: if isDead, trigger CleanupSystem / death event

		Remotes.CombatEvent:FireAllClients({
			shooterUserId = player.UserId,
			hit = true,
			hitEnemy = true,
			hitEntityId = enemyEntityId,
			hitPosition = hitPosition,
			isDead = isDead,
			origin = origin,
			direction = direction,
		})
	else
		-- ── Environment hit ────────────────────────────────────────────────
		Remotes.CombatEvent:FireAllClients({
			shooterUserId = player.UserId,
			hit = true,
			hitEnemy = false,
			hitPosition = hitPosition,
			origin = origin,
			direction = direction,
		})
	end
end

-- ── Public ────────────────────────────────────────────────────────────────

-- Call once from Bootstrap.
function CombatSystem.init(world: any)
	_world = world

	Remotes.FireWeaponRequest.OnServerEvent:Connect(
		function(player: Player, origin: any, direction: any, clientTime: any)
			handleFireRequest(player, origin, direction, clientTime)
		end
	)

	-- Clean up rate-limit log when player leaves
	Players.PlayerRemoving:Connect(function(player: Player)
		_requestLog[player] = nil
	end)

	print("[CombatSystem] Initialized.")
end

return CombatSystem
