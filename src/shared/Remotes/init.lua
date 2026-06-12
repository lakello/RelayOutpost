-- Remote event registry.
-- Server requires this first (creates instances). Client waits for them.
-- Runtime instances live at: ReplicatedStorage.Remotes  (root level, not inside Shared)
-- Module itself lives at:    ReplicatedStorage.Shared.Remotes

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

if IS_SERVER then
	-- Create folder structure and all RemoteEvents
	local root = Instance.new("Folder")
	root.Name = "Remotes"
	root.Parent = ReplicatedStorage

	local c2s = Instance.new("Folder")
	c2s.Name = "ClientToServer"
	c2s.Parent = root

	local s2c = Instance.new("Folder")
	s2c.Name = "ServerToClient"
	s2c.Parent = root

	local function makeRemote(parent: Folder, name: string): RemoteEvent
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = parent
		return r
	end

	return {
		-- Client → Server
		FireWeaponRequest = makeRemote(c2s, "FireWeaponRequest"),
		StartInteractRequest = makeRemote(c2s, "StartInteractRequest"),
		StopInteractRequest = makeRemote(c2s, "StopInteractRequest"),
		ReviveRequest = makeRemote(c2s, "ReviveRequest"),

		-- Server → Client
		MatchStateUpdate = makeRemote(s2c, "MatchStateUpdate"),
		CombatEvent = makeRemote(s2c, "CombatEvent"),
		ObjectiveEvent = makeRemote(s2c, "ObjectiveEvent"),
		PlayerStateEvent = makeRemote(s2c, "PlayerStateEvent"),
		DebugSnapshot = makeRemote(s2c, "DebugSnapshot"),
	}
else
	-- Client waits for the server to create the folder and events
	local root = ReplicatedStorage:WaitForChild("Remotes")
	local c2s = root:WaitForChild("ClientToServer")
	local s2c = root:WaitForChild("ServerToClient")

	return {
		-- Client → Server
		FireWeaponRequest = c2s:WaitForChild("FireWeaponRequest") :: RemoteEvent,
		StartInteractRequest = c2s:WaitForChild("StartInteractRequest") :: RemoteEvent,
		StopInteractRequest = c2s:WaitForChild("StopInteractRequest") :: RemoteEvent,
		ReviveRequest = c2s:WaitForChild("ReviveRequest") :: RemoteEvent,

		-- Server → Client
		MatchStateUpdate = s2c:WaitForChild("MatchStateUpdate") :: RemoteEvent,
		CombatEvent = s2c:WaitForChild("CombatEvent") :: RemoteEvent,
		ObjectiveEvent = s2c:WaitForChild("ObjectiveEvent") :: RemoteEvent,
		PlayerStateEvent = s2c:WaitForChild("PlayerStateEvent") :: RemoteEvent,
		DebugSnapshot = s2c:WaitForChild("DebugSnapshot") :: RemoteEvent,
	}
end
