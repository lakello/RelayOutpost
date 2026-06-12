-- Server-authoritative relay interaction.
-- Validates StartInteract/StopInteract remotes, tracks contributors per relay,
-- and advances capture progress. Completing a relay writes to MatchStateService,
-- which WaveDirectorSystem polls to trigger the next wave.
--
-- State split:
--   MatchStateService.relays[id]  → authoritative Locked/Active/Completed
--   ECS CaptureProgress           → contributors set + progress counter

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local C = require(ReplicatedStorage.Shared.Components)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ObjectiveRules = require(ReplicatedStorage.Shared.Pure.ObjectiveRules)
local InteractionValidation = require(ReplicatedStorage.Shared.Pure.InteractionValidation)
local MatchStateService = require(script.Parent.Parent.Services.MatchStateService)
local PlayerLifecycleSystem = require(script.Parent.PlayerLifecycleSystem)

local InteractionSystem = {}

local _world: any = nil

-- Simple rate limiter: one bucket per player, minimum gap between requests.
local RATE_LIMIT_INTERVAL = 0.25 -- seconds
local _lastRequestTime: { [Player]: number } = {}

local function isRateLimited(player: Player): boolean
	local now = os.clock()
	local last = _lastRequestTime[player] or 0
	if now - last < RATE_LIMIT_INTERVAL then
		return true
	end
	_lastRequestTime[player] = now
	return false
end

-- Linear scan over relay entities — only 3 entities exist, so this is trivially fast.
local function findRelayEntity(objectiveId: string): (number?, any, any, any)
	for entityId, obj, cap, transform in _world:query(C.Objective, C.CaptureProgress, C.Transform) do
		if obj.id == objectiveId then
			return entityId, obj, cap, transform
		end
	end
	return nil, nil, nil, nil
end

-- ── Remote handlers ───────────────────────────────────────────────────────

local function onStartInteract(player: Player, data: any)
	if type(data) ~= "table" or type(data.objectiveId) ~= "string" then
		return
	end
	if isRateLimited(player) then
		return
	end

	local objectiveId = data.objectiveId

	-- Relay must be Active in MatchStateService (authoritative state).
	local relayStates = MatchStateService.getRelayStates()
	if relayStates[objectiveId] ~= "Active" then
		return
	end

	-- Find ECS entity (for position and CaptureProgress).
	local entityId, _, cap, transform = findRelayEntity(objectiveId)
	if not entityId then
		return
	end

	-- Player entity must exist (character loaded).
	local playerEntityId = PlayerLifecycleSystem.getEntityId(player)
	if not playerEntityId or not _world:contains(playerEntityId) then
		return
	end

	-- Downed players cannot interact.
	local downedState = _world:get(playerEntityId, C.DownedState)
	local isDowned = downedState ~= nil and downedState.isDowned

	-- Need character position for distance check.
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	local distance = ((hrp :: BasePart).Position - transform.cframe.Position).Magnitude

	local isValid, _ = InteractionValidation.canInteract(
		"Active", -- we already confirmed this above
		true, -- has character = alive
		isDowned,
		distance,
		MatchConfig.interactMaxDistance
	)
	if not isValid then
		return
	end

	-- Already contributing — no-op (prevents duplicate entries).
	if cap.contributors[player.UserId] then
		return
	end

	local newContributors = table.clone(cap.contributors)
	newContributors[player.UserId] = true
	_world:insert(entityId, cap:patch({ contributors = newContributors }))

	print(
		string.format(
			"[InteractionSystem] %s → StartInteract %s (dist=%.1f)",
			player.Name,
			objectiveId,
			distance
		)
	)
end

local function onStopInteract(player: Player, data: any)
	if type(data) ~= "table" or type(data.objectiveId) ~= "string" then
		return
	end

	local objectiveId = data.objectiveId
	local entityId, _, cap = findRelayEntity(objectiveId)
	if not entityId then
		return
	end

	if not cap.contributors[player.UserId] then
		return
	end

	local newContributors = table.clone(cap.contributors)
	newContributors[player.UserId] = nil
	_world:insert(entityId, cap:patch({ contributors = newContributors }))
end

-- Remove a player from all relay contributor sets (death / disconnect).
local function cleanupContributions(player: Player)
	if not _world then
		return
	end
	for entityId, _, cap in _world:query(C.Objective, C.CaptureProgress) do
		if cap.contributors[player.UserId] then
			local newContributors = table.clone(cap.contributors)
			newContributors[player.UserId] = nil
			_world:insert(entityId, cap:patch({ contributors = newContributors }))
		end
	end
end

-- ── Ticking step (10 Hz) ──────────────────────────────────────────────────

function InteractionSystem.step(world: any, dt: number)
	local relayStates = MatchStateService.getRelayStates()

	for entityId, obj, cap, _, transform in
		world:query(C.Objective, C.CaptureProgress, C.RelayBeacon, C.Transform)
	do
		-- Only process relays that are currently Active.
		if relayStates[obj.id] ~= "Active" then
			continue
		end

		if next(cap.contributors) == nil then
			continue
		end

		-- Re-validate each contributor: must be alive, not downed, and within range.
		-- 1.5× grace distance prevents jitter at the boundary from dropping contributors.
		local relayPos = transform.cframe.Position
		local validContributors: { [number]: boolean } = {}

		for userId in pairs(cap.contributors) do
			local player = Players:GetPlayerByUserId(userId)
			if not player then
				continue
			end

			-- Downed check via ECS entity
			local pEntityId = PlayerLifecycleSystem.getEntityId(player)
			if pEntityId and world:contains(pEntityId) then
				local downedState = world:get(pEntityId, C.DownedState)
				if downedState and downedState.isDowned then
					continue
				end
			end

			local char = player.Character
			if not char then
				continue
			end
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp then
				continue
			end
			local dist = ((hrp :: BasePart).Position - relayPos).Magnitude
			if dist <= MatchConfig.interactMaxDistance * 1.5 then
				validContributors[userId] = true
			end
		end

		local contributorCount = 0
		for _ in pairs(validContributors) do
			contributorCount += 1
		end

		-- No valid contributors — clear stale entries and skip progress.
		if contributorCount == 0 then
			if next(cap.contributors) ~= nil then
				world:insert(entityId, cap:patch({ contributors = {} }))
			end
			continue
		end

		local newProgress, completed = ObjectiveRules.advanceProgress(
			cap.current,
			cap.required,
			contributorCount,
			dt
		)

		if completed then
			world:insert(entityId, cap:patch({ current = cap.required, contributors = {} }))
			MatchStateService.setRelayState(obj.id, "Completed")
			-- ObjectiveEvent lets clients know to stop showing the progress bar.
			Remotes.ObjectiveEvent:FireAllClients({
				type = "RelayCompleted",
				objectiveId = obj.id,
			})
			print(
				string.format(
					"[InteractionSystem] Relay %s COMPLETED! contributors=%d",
					obj.id,
					contributorCount
				)
			)
		else
			-- Keep contributors in sync with the validated set.
			world:insert(entityId, cap:patch({ current = newProgress, contributors = validContributors }))
		end
	end
end

-- ── Init ──────────────────────────────────────────────────────────────────

function InteractionSystem.init(world: any)
	_world = world

	Remotes.StartInteractRequest.OnServerEvent:Connect(onStartInteract)
	Remotes.StopInteractRequest.OnServerEvent:Connect(onStopInteract)

	-- Clean up contributions when a player disconnects.
	Players.PlayerRemoving:Connect(cleanupContributions)

	print("[InteractionSystem] Initialized.")
end

return InteractionSystem
