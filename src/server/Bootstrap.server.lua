-- Server entry point. Initializes ECS world, services, systems, and the heartbeat loop.
print("[RelayOutpost] Server bootstrap starting...")

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── ECS core ──────────────────────────────────────────────────────────────
local world = require(script.Parent.ECS.World)
local SystemScheduler = require(script.Parent.ECS.SystemScheduler)
local scheduler = SystemScheduler.new(world)

-- ── Shared modules ────────────────────────────────────────────────────────
local C = require(ReplicatedStorage.Shared.Components)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local ZoneConfig = require(ReplicatedStorage.Shared.Config.ZoneConfig)

-- Create RemoteEvents before any system tries to fire them.
require(ReplicatedStorage.Shared.Remotes)

-- ── Systems ───────────────────────────────────────────────────────────────
local PlayerLifecycleSystem = require(script.Parent.Systems.PlayerLifecycleSystem)
local ReplicationBridgeSystem = require(script.Parent.Systems.ReplicationBridgeSystem)
local CombatSystem = require(script.Parent.Systems.CombatSystem)
local InteractionSystem = require(script.Parent.Systems.InteractionSystem)
local WaveDirectorSystem = require(script.Parent.Systems.WaveDirectorSystem)
local EnemySpawnSystem = require(script.Parent.Systems.EnemySpawnSystem)
local TargetAcquisitionSystem = require(script.Parent.Systems.TargetAcquisitionSystem)
local EnemyMovementSystem = require(script.Parent.Systems.EnemyMovementSystem)
local EnemyMeleeSystem = require(script.Parent.Systems.EnemyMeleeSystem)
local CleanupSystem = require(script.Parent.Systems.CleanupSystem)
local PathfindingSystem = require(script.Parent.Systems.PathfindingSystem)
local ReviveSystem = require(script.Parent.Systems.ReviveSystem)
local DebugSnapshotSystem = require(script.Parent.Systems.DebugSnapshotSystem)

-- ── Generator entity ──────────────────────────────────────────────────────
local function findGeneratorModel(): BasePart?
	local map = workspace:FindFirstChild("Map")
	local al = map and map:FindFirstChild("AlwaysLoaded")
	return al and al:FindFirstChild("GeneratorVisual") :: BasePart?
end

local generatorModel = findGeneratorModel()
local genCFrame = generatorModel and generatorModel.CFrame or CFrame.new(0, 6, 0)

local genEntityId = world:spawn(
	C.Health({ current = MatchConfig.generatorMaxHealth, max = MatchConfig.generatorMaxHealth }),
	C.Generator({ generatorModel = generatorModel }),
	C.Objective({ id = "Generator", state = "Active" }),
	C.Transform({ cframe = genCFrame })
)
print(
	string.format(
		"[Bootstrap] Generator entity=%d | HP=%d/%d",
		genEntityId,
		MatchConfig.generatorMaxHealth,
		MatchConfig.generatorMaxHealth
	)
)

-- ── Relay beacon entities ─────────────────────────────────────────────────
-- Server has full workspace access (not subject to StreamingEnabled).
-- Reads beacon world position from CollectionService-tagged models.
-- Falls back to placeholder positions when the map blockout isn't set up yet.
local RELAY_FALLBACK_POSITIONS = {
	Relay_A = CFrame.new(60, 6, 0),
	Relay_B = CFrame.new(-60, 6, 0),
	Relay_C = CFrame.new(0, 6, 60),
}

local function findBeaconCFrame(objectiveId: string): CFrame
	for _, beacon in CollectionService:GetTagged("RelayBeacon") do
		local attr = beacon:GetAttribute("ObjectiveId") :: string?
		if attr ~= objectiveId then
			continue
		end
		if beacon:IsA("BasePart") then
			return (beacon :: BasePart).CFrame
		elseif beacon:IsA("Model") then
			local model = beacon :: Model
			if model.PrimaryPart then
				return model.PrimaryPart.CFrame
			end
			local cf, _ = model:GetBoundingBox()
			return cf
		end
	end
	-- Beacon not tagged/placed yet — use placeholder.
	warn(
		string.format(
			"[Bootstrap] No RelayBeacon tagged with ObjectiveId=%s in workspace. "
				.. "Add CollectionService tag 'RelayBeacon' and Attribute ObjectiveId='%s' in Studio.",
			objectiveId,
			objectiveId
		)
	)
	return RELAY_FALLBACK_POSITIONS[objectiveId] or CFrame.new(0, 6, 0)
end

for _, zone in ipairs(ZoneConfig.zones) do
	local beaconCFrame = findBeaconCFrame(zone.objectiveId)
	local relayEntityId = world:spawn(
		C.Objective({ id = zone.objectiveId, state = "Locked" }),
		C.CaptureProgress({
			current = 0,
			required = MatchConfig.relayActivationTime,
			contributors = {},
		}),
		C.RelayBeacon({}),
		C.Transform({ cframe = beaconCFrame })
	)
	print(
		string.format(
			"[Bootstrap] Relay entity=%d | id=%s | pos=%s",
			relayEntityId,
			zone.objectiveId,
			tostring(beaconCFrame.Position)
		)
	)
end

-- ── Wire event-driven systems ─────────────────────────────────────────────
PlayerLifecycleSystem.init(world)
ReplicationBridgeSystem.init()
CombatSystem.init(world)
InteractionSystem.init(world) -- connects StartInteract/StopInteract remotes
WaveDirectorSystem.init() -- sets Lobby phase and starts countdown timer
ReviveSystem.init(world) -- connects ReviveRequest remote
DebugSnapshotSystem.init(scheduler) -- needs scheduler for timings + entity count

-- ── Register ticking systems (ordered by priority) ───────────────────────
-- Hz values match ТЗ performance budget.
scheduler:register("WaveDirector", WaveDirectorSystem.step, 2) -- 2 Hz state machine
scheduler:register("EnemySpawn", EnemySpawnSystem.step, 2) -- 2 Hz queue drain
scheduler:register("TargetAcquisition", TargetAcquisitionSystem.step, 5) -- 4–5 Hz
scheduler:register("Pathfinding", PathfindingSystem.step, 2)       -- 2 Hz path recompute
scheduler:register("EnemyMovement", EnemyMovementSystem.step, 20) -- 10–20 Hz
scheduler:register("EnemyMelee", EnemyMeleeSystem.step, 10) -- ~10 Hz
scheduler:register("Interaction", InteractionSystem.step, 10) -- 10 Hz capture progress
scheduler:register("Revive", ReviveSystem.step, 10) -- 10 Hz revive progress
scheduler:register("Cleanup", CleanupSystem.step, 5) -- 5 Hz
scheduler:register("ReplicationBridge", ReplicationBridgeSystem.step, 5) -- 5 Hz
scheduler:register("DebugSnapshot", DebugSnapshotSystem.step, 4) -- 4 Hz dev overlay

-- ── Heartbeat loop ────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt)
	scheduler:step(dt)
end)

print("[RelayOutpost] Server bootstrap complete. ECS world active.")
