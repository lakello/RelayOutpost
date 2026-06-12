-- Creates and destroys enemy ECS entities + their Roblox models.
-- Models are built programmatically (no ServerStorage templates needed for the vertical slice).
-- Each model gets an "EntityId" attribute so CombatSystem can find the ECS entity on raycast hit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage.Shared.Components)
local EnemyConfig = require(ReplicatedStorage.Shared.Config.EnemyConfig)

local EnemyFactory = {}

local ENEMY_FOLDER_NAME = "Enemies"

-- Friendly colors for each enemy type (placeholder visuals)
local ENEMY_COLOR: { [string]: BrickColor } = {
	Crawler = BrickColor.new("Bright red"),
	Runner = BrickColor.new("Bright orange"),
}

-- ── Internal helpers ──────────────────────────────────────────────────────

local function getEnemiesFolder(): Folder
	local folder = workspace:FindFirstChild(ENEMY_FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = ENEMY_FOLDER_NAME
		folder.Parent = workspace
	end
	return folder :: Folder
end

-- Builds a minimal enemy Model: one Part (HumanoidRootPart) + Humanoid.
-- The Humanoid enables Roblox's built-in movement when we call :MoveTo().
-- MaxHealth is set high so Roblox fall-damage never kills it independently
-- of the ECS Health component; death is always driven through ECS.
local function buildModel(kind: string, walkSpeed: number, maxHealth: number): Model
	local model = Instance.new("Model")
	model.Name = "Enemy_" .. kind

	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = walkSpeed
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 3, 1)
	root.BrickColor = ENEMY_COLOR[kind] or BrickColor.new("Medium stone grey")
	root.Material = Enum.Material.SmoothPlastic
	root.CanCollide = true
	root.Parent = model

	model.PrimaryPart = root
	return model
end

-- ── Public ────────────────────────────────────────────────────────────────

-- Spawn one enemy of `kind` at `spawnCFrame`.
-- statMultiplier: scales health and damage (from WaveScaling.getStatMultiplier).
-- Returns the ECS entity ID, or nil on failure.
function EnemyFactory.createEnemy(
	world: any,
	kind: string,
	spawnCFrame: CFrame,
	statMultiplier: number?
): number?
	local stats = EnemyConfig[kind]
	if not stats then
		warn("[EnemyFactory] Unknown enemy kind: " .. tostring(kind))
		return nil
	end

	local mult = statMultiplier or 1
	local scaledHp = math.floor(stats.maxHealth * mult)
	local scaledDmg = math.floor(stats.meleeDamage * mult)

	local model = buildModel(kind, stats.moveSpeed, scaledHp)
	model.Parent = getEnemiesFolder()

	-- Spawn 3 studs above the marker so physics lands the enemy on the surface
	local spawnPos = spawnCFrame.Position + Vector3.new(0, 3, 0)
	model:PivotTo(CFrame.new(spawnPos))

	local entityId = world:spawn(
		C.Enemy({ kind = kind }),
		C.Health({ current = scaledHp, max = scaledHp }),
		C.Transform({ cframe = CFrame.new(spawnPos) }),
		C.ModelRef({ model = model }),
		C.Target({ entityId = nil, targetType = nil }),
		C.AttackCooldown({ lastAttackTime = 0, cooldown = stats.attackCooldown }),
		C.MeleeAttack({ range = stats.meleeRange, damage = scaledDmg })
	)

	-- Link model → entity so CombatSystem can resolve a raycast hit back to ECS
	model:SetAttribute("EntityId", entityId)

	-- Sync Humanoid death back to ECS so CleanupSystem always sees health = 0.
	-- This covers fall damage, void kills, or any non-combat death source.
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local conn: RBXScriptConnection
	conn = humanoid.Died:Connect(function()
		conn:Disconnect()
		if world:contains(entityId) then
			local health = world:get(entityId, C.Health)
			if health and health.current > 0 then
				world:insert(entityId, C.Health({ current = 0, max = health.max }))
			end
		end
	end)

	-- FallenPartsDestroyHeight destroys HumanoidRootPart but leaves the Model container
	-- alive in workspace, so Humanoid.Died never fires for enemies that fall off the map.
	-- Catch that case by listening for ChildRemoved on the model itself.
	local rootConn: RBXScriptConnection
	rootConn = model.ChildRemoved:Connect(function(child: Instance)
		if child.Name ~= "HumanoidRootPart" then
			return
		end
		rootConn:Disconnect()
		if world:contains(entityId) then
			local h = world:get(entityId, C.Health)
			if h and h.current > 0 then
				world:insert(entityId, C.Health({ current = 0, max = h.max }))
			end
		end
	end)

	return entityId
end

-- Remove an enemy entity and its Roblox model.
function EnemyFactory.destroyEnemy(world: any, entityId: number)
	if not world:contains(entityId) then
		return
	end

	local modelRef = world:get(entityId, C.ModelRef)
	if modelRef and modelRef.model and modelRef.model.Parent then
		modelRef.model:Destroy()
	end

	world:despawn(entityId)
end

return EnemyFactory
