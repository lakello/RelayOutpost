-- Client entry point. Initializes controllers and HUD.
print("[RelayOutpost] Client bootstrap starting...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.LocalPlayer

-- ── Controllers ───────────────────────────────────────────────────────────
local HudController = require(script.Parent.Controllers.HudController)
local CrosshairController = require(script.Parent.Controllers.CrosshairController)
local InputController = require(script.Parent.Controllers.InputController)
local StreamingAwarenessController = require(script.Parent.Controllers.StreamingAwarenessController)
local ReviveController = require(script.Parent.Controllers.ReviveController)
local InteractionController = require(script.Parent.Controllers.InteractionController)
local VfxController = require(script.Parent.Controllers.VfxController)
local EndScreenController = require(script.Parent.Controllers.EndScreenController)
local DebugOverlayController = require(script.Parent.Debug.DebugOverlayController)

HudController.init()
CrosshairController.init()
InputController.init()
-- StreamingAwareness must be first: other controllers and debug overlay query it.
StreamingAwarenessController.init()
ReviveController.init() -- must init before InteractionController (hasTarget dependency)
InteractionController.init()
VfxController.init()
EndScreenController.init()
DebugOverlayController.init()

-- ── CombatEvent feedback (dev log) ────────────────────────────────────────
local Remotes = require(ReplicatedStorage.Shared.Remotes)

Remotes.CombatEvent.OnClientEvent:Connect(function(data: { [string]: any })
	if data.hit and data.hitEnemy then
		print(
			string.format(
				"[CombatEvent] Hit entity=%s dead=%s pos=%s",
				tostring(data.hitEntityId),
				tostring(data.isDead),
				tostring(data.hitPosition)
			)
		)
	end
end)

-- Streaming event logging is now handled by StreamingAwarenessController.

print(string.format("[RelayOutpost] Client bootstrap complete. Player: %s", localPlayer.Name))
