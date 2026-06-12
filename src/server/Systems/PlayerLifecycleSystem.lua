-- Creates and destroys player ECS entities in response to Roblox lifecycle events.
-- Called from Bootstrap; not a ticking system.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage.Shared.Components)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)

local PlayerLifecycleSystem = {}

-- Map from Player -> entityId for cleanup.
local playerEntities: { [Player]: number } = {}

-- Spawns a fresh player entity once HumanoidRootPart is available.
local function spawnPlayerEntity(world: any, player: Player, character: Model)
	task.spawn(function()
		local hrp = character:WaitForChild("HumanoidRootPart", 5)
		if not hrp then
			warn(string.format("[PlayerLifecycle] HumanoidRootPart timeout for %s", player.Name))
			return
		end

		-- Guard: player may have left or respawned while we waited
		if player.Parent == nil or player.Character ~= character then
			return
		end

		-- Despawn stale entity from a previous character (e.g. after respawn)
		local existing = playerEntities[player]
		if existing and world:contains(existing) then
			world:despawn(existing)
		end

		local entityId = world:spawn(
			C.Health({ current = MatchConfig.playerMaxHealth, max = MatchConfig.playerMaxHealth }),
			C.Transform({ cframe = hrp.CFrame }),
			C.PlayerRef({ player = player }),
			C.CharacterRef({ character = character }),
			C.WeaponState({ lastFireTime = 0 }),
			C.DownedState({ isDowned = false, downedAt = 0 })
		)

		playerEntities[player] = entityId

		print(
			string.format(
				"[PlayerLifecycle] Spawned entity=%d for %s | world:size()=%d",
				entityId,
				player.Name,
				world:size()
			)
		)
	end)
end

local function onCharacterAdded(world: any, player: Player, character: Model)
	spawnPlayerEntity(world, player, character)
end

local function onPlayerAdded(world: any, player: Player)
	-- Connect to future respawns
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(world, player, character)
	end)

	-- Handle character that loaded before this connection was set up
	if player.Character then
		onCharacterAdded(world, player, player.Character)
	end
end

local function onPlayerRemoving(world: any, player: Player)
	local entityId = playerEntities[player]
	if entityId and world:contains(entityId) then
		world:despawn(entityId)
		print(
			string.format(
				"[PlayerLifecycle] Despawned entity=%d for %s | world:size()=%d",
				entityId,
				player.Name,
				world:size()
			)
		)
	end
	playerEntities[player] = nil
end

-- Call once from Bootstrap to wire up all player lifecycle events.
function PlayerLifecycleSystem.init(world: any)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(world, player)
	end

	Players.PlayerAdded:Connect(function(player)
		onPlayerAdded(world, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		onPlayerRemoving(world, player)
	end)

	print("[PlayerLifecycle] Initialized.")
end

-- Returns the entity ID for a player, or nil if none.
function PlayerLifecycleSystem.getEntityId(player: Player): number?
	return playerEntities[player]
end

return PlayerLifecycleSystem
