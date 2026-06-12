-- Throttled match state replication (registered at 5 Hz in SystemScheduler).
-- Reads MatchStateService dirty flag; if set, broadcasts snapshot to all players.
-- Also sends state immediately to new players on join.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MatchStateService = require(script.Parent.Parent.Services.MatchStateService)

local ReplicationBridgeSystem = {}

-- Call once from Bootstrap after Remotes are created.
function ReplicationBridgeSystem.init()
	-- New players always receive the current state immediately on join,
	-- regardless of the bridge's dirty flag or tick timing.
	Players.PlayerAdded:Connect(function(player)
		Remotes.MatchStateUpdate:FireClient(player, MatchStateService.getSnapshot())
	end)
end

-- Ticking step (called by SystemScheduler at 5 Hz).
-- Sends snapshot to all current players only when state has changed.
function ReplicationBridgeSystem.step(_world: any, _dt: number)
	if not MatchStateService.isDirty() then
		return
	end

	MatchStateService.clearDirty()
	local snapshot = MatchStateService.getSnapshot()

	for _, player in Players:GetPlayers() do
		Remotes.MatchStateUpdate:FireClient(player, snapshot)
	end
end

return ReplicationBridgeSystem
