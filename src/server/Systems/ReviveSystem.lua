-- Server-authoritative revive system.
-- Handles ReviveRequest intents, validates state and proximity each tick,
-- completes after MatchConfig.reviveDuration seconds of continuous uninterrupted holding.
-- Runs at 10 Hz.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage.Shared.Components)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerLifecycleSystem = require(script.Parent.PlayerLifecycleSystem)

local ReviveSystem = {}

local _world: any = nil

type ReviveEntry = { targetUserId: number, startTime: number }
-- Active revive attempts: reviver UserId → entry
local _active: { [number]: ReviveEntry } = {}

-- ── Helpers ───────────────────────────────────────────────────────────────

local function isAliveAndStanding(entityId: number): boolean
	local health = _world:get(entityId, C.Health)
	local downed = _world:get(entityId, C.DownedState)
	return health ~= nil
		and health.current > 0
		and (downed == nil or not downed.isDowned)
end

local function hrpOf(player: Player): BasePart?
	local char = player.Character
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- ── Remote handler ────────────────────────────────────────────────────────

local function onReviveRequest(reviver: Player, data: any)
	if type(data) ~= "table" then
		return
	end

	if data.state == "Stop" then
		_active[reviver.UserId] = nil
		return
	end

	if data.state ~= "Start" then
		return
	end

	local targetUserId = data.targetUserId
	if type(targetUserId) ~= "number" then
		return
	end

	-- Reviver must be alive and not downed
	local reviverEntityId = PlayerLifecycleSystem.getEntityId(reviver)
	if not reviverEntityId or not _world:contains(reviverEntityId) then
		return
	end
	if not isAliveAndStanding(reviverEntityId) then
		return
	end

	-- Target must exist and be downed
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or not target.Character then
		return
	end
	local targetEntityId = PlayerLifecycleSystem.getEntityId(target)
	if not targetEntityId or not _world:contains(targetEntityId) then
		return
	end
	local targetDowned = _world:get(targetEntityId, C.DownedState)
	if not targetDowned or not targetDowned.isDowned then
		return
	end

	-- Distance check
	local rHrp = hrpOf(reviver)
	local tHrp = hrpOf(target)
	if not rHrp or not tHrp then
		return
	end
	if (rHrp.Position - tHrp.Position).Magnitude > MatchConfig.reviveMaxDistance then
		return
	end

	-- Begin (idempotent — repeated Start while already active is ignored so the
	-- timer does not reset if the client re-sends on each heartbeat tick).
	if not _active[reviver.UserId] then
		_active[reviver.UserId] = { targetUserId = targetUserId, startTime = os.clock() }
		print(string.format("[ReviveSystem] %s → reviving userId=%d", reviver.Name, targetUserId))
	end
end

-- ── Ticking step (10 Hz) ──────────────────────────────────────────────────

function ReviveSystem.step(_w: any, _dt: number)
	if next(_active) == nil then
		return
	end

	local toRemove: { number } = {}

	for reviverUserId, entry in pairs(_active) do
		local reviver = Players:GetPlayerByUserId(reviverUserId)
		if not reviver then
			table.insert(toRemove, reviverUserId)
			continue
		end

		-- Reviver still alive and standing?
		local reviverEntityId = PlayerLifecycleSystem.getEntityId(reviver)
		if
			not reviverEntityId
			or not _world:contains(reviverEntityId)
			or not isAliveAndStanding(reviverEntityId)
		then
			table.insert(toRemove, reviverUserId)
			continue
		end

		-- Target still downed?
		local target = Players:GetPlayerByUserId(entry.targetUserId)
		if not target or not target.Character then
			table.insert(toRemove, reviverUserId)
			continue
		end
		local targetEntityId = PlayerLifecycleSystem.getEntityId(target)
		if not targetEntityId or not _world:contains(targetEntityId) then
			table.insert(toRemove, reviverUserId)
			continue
		end
		local targetDowned = _world:get(targetEntityId, C.DownedState)
		if not targetDowned or not targetDowned.isDowned then
			table.insert(toRemove, reviverUserId)
			continue
		end

		-- Distance re-validation (1.5× grace to tolerate minor movement jitter)
		local rHrp = hrpOf(reviver)
		local tHrp = hrpOf(target)
		if not rHrp or not tHrp then
			table.insert(toRemove, reviverUserId)
			continue
		end
		if (rHrp.Position - tHrp.Position).Magnitude > MatchConfig.reviveMaxDistance * 1.5 then
			table.insert(toRemove, reviverUserId)
			continue
		end

		-- Timer not yet expired — keep waiting
		if os.clock() - entry.startTime < MatchConfig.reviveDuration then
			continue
		end

		-- ── Revive complete ──────────────────────────────────────────────
		table.insert(toRemove, reviverUserId)

		local health = _world:get(targetEntityId, C.Health)
		local charRef = _world:get(targetEntityId, C.CharacterRef)
		if not health or not charRef or not charRef.character then
			continue
		end

		local revivedHp = math.max(1, math.floor(health.max * MatchConfig.reviveHpFraction))
		_world:insert(targetEntityId, C.Health({ current = revivedHp, max = health.max }))
		_world:insert(targetEntityId, C.DownedState({ isDowned = false, downedAt = 0 }))

		local humanoid = charRef.character:FindFirstChildOfClass("Humanoid") :: Humanoid?
		if humanoid then
			humanoid.Health = revivedHp
			humanoid.WalkSpeed = 16
			humanoid.JumpPower = 50
		end

		Remotes.PlayerStateEvent:FireAllClients({
			type = "Revived",
			userId = entry.targetUserId,
			revivedHp = revivedHp,
		})

		print(
			string.format(
				"[ReviveSystem] %s revived userId=%d | HP=%d",
				reviver.Name,
				entry.targetUserId,
				revivedHp
			)
		)
	end

	for _, id in ipairs(toRemove) do
		_active[id] = nil
	end
end

-- ── Init ─────────────────────────────────────────────────────────────────

function ReviveSystem.init(world: any)
	_world = world

	Remotes.ReviveRequest.OnServerEvent:Connect(function(player: Player, data: any)
		onReviveRequest(player, data)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		_active[player.UserId] = nil
	end)

	print("[ReviveSystem] Initialized.")
end

return ReviveSystem
