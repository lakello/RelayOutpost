-- Developer debug overlay controller.
-- Receives DebugSnapshot events from the server (4 Hz), merges with
-- client-local data (FPS, streamed zone counts), and renders via ImmediateGui.
--
-- Toggle visibility: backtick (`) or F3.
-- Default: hidden.  Works without any Workspace instance references.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ImmediateGui = require(script.Parent.ImmediateGui)
local StreamingAwarenessController = require(script.Parent.Parent.Controllers.StreamingAwarenessController)

local DebugOverlayController = {}

local localPlayer = Players.LocalPlayer

-- Tags whose client-loaded counts are shown in the Streaming section.
local STREAMING_TAGS = { "RelayBeacon", "EnemySpawn", "Generator" }

-- ── State ─────────────────────────────────────────────────────────────────

local _gui: any = nil
local _snapshot: any = nil -- last DebugSnapshot from server

-- FPS smoothing (updated every 0.5 s)
local _fpsAccum = 0
local _fpsFrames = 0
local _fpsDisplay = 0
local FPS_INTERVAL = 0.5

-- ── Line builder ──────────────────────────────────────────────────────────

local function pad(label: string, width: number): string
	local s = label
	while #s < width do
		s = s .. " "
	end
	return s
end

local function buildLines(): { string }
	local lines: { string } = {}

	local function add(s: string)
		table.insert(lines, s)
	end

	local s = _snapshot

	-- ── Header ────────────────────────────────────────────────────────────
	add("[DEBUG OVERLAY]")
	add("  Toggle: ` or F3")

	if not s then
		add("")
		add("  Waiting for server snapshot...")
		return lines
	end

	-- ── Match state ───────────────────────────────────────────────────────
	add("")
	add("[MATCH]")
	add("  " .. pad("Phase:", 10) .. tostring(s.phase))
	add("  " .. pad("Wave:", 10) .. tostring(s.wave))
	add("  " .. pad("Enemies:", 10) .. tostring(s.enemiesAlive))

	local gen = s.generatorHp
	if gen then
		add("  " .. pad("Gen HP:", 10) .. tostring(gen.current) .. " / " .. tostring(gen.max))
	end

	-- ── Relay states ──────────────────────────────────────────────────────
	add("")
	add("[RELAYS]")
	if s.relays then
		for _, id in ipairs({ "Relay_A", "Relay_B", "Relay_C" }) do
			local state = s.relays[id] or "?"
			add("  " .. pad(id .. ":", 12) .. state)
		end
	end

	-- ── ECS ───────────────────────────────────────────────────────────────
	add("")
	add("[ECS]")
	add("  " .. pad("Entities:", 10) .. tostring(s.entityCount))

	-- ── System timings ────────────────────────────────────────────────────
	add("")
	add("[SYSTEMS  ms/tick]")
	if s.systems then
		local names: { string } = {}
		for name in pairs(s.systems) do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in ipairs(names) do
			local ms: number = s.systems[name]
			add(string.format("  %-16s %6.3f", name, ms))
		end
	end

	-- ── Streaming (client-local via StreamingAwarenessController) ────────
	add("")
	add("[STREAMING  loaded]")
	for _, tag in ipairs(STREAMING_TAGS) do
		local count = StreamingAwarenessController.getCount(tag)
		add("  " .. pad(tag .. ":", 14) .. tostring(count))
	end

	-- ── Client ────────────────────────────────────────────────────────────
	add("")
	add("[CLIENT]")
	add("  " .. pad("FPS:", 10) .. tostring(math.round(_fpsDisplay)))
	add(string.format("  %-10s%.1f s", "SrvTime:", s.serverTime or 0))

	return lines
end

-- ── Public ────────────────────────────────────────────────────────────────

function DebugOverlayController.init()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	_gui = ImmediateGui.new(playerGui)

	-- Server snapshot → re-render if overlay is visible
	Remotes.DebugSnapshot.OnClientEvent:Connect(function(snapshot: any)
		_snapshot = snapshot
		if _gui:isVisible() then
			_gui:render(buildLines())
		end
	end)

	-- FPS measurement (every frame, cheap)
	RunService.Heartbeat:Connect(function(dt: number)
		_fpsAccum += dt
		_fpsFrames += 1
		if _fpsAccum >= FPS_INTERVAL then
			_fpsDisplay = _fpsFrames / _fpsAccum
			_fpsAccum = 0
			_fpsFrames = 0
		end
	end)

	-- Dev toggle: backtick (`) or F3
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Backquote or input.KeyCode == Enum.KeyCode.F3 then
			local visible = not _gui:isVisible()
			_gui:setVisible(visible)
			-- Force an immediate render so the overlay isn't blank on first open
			if visible then
				_gui:render(buildLines())
			end
		end
	end)

	print("[DebugOverlay] Initialized. Press ` (backtick) or F3 to toggle.")
end

return DebugOverlayController
