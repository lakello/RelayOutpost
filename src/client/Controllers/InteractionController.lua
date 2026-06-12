-- Client-side relay interaction.
-- Uses CollectionService to discover nearby RelayBeacon instances (streaming-safe).
-- When the local player holds E near an Active beacon, fires StartInteractRequest.
-- Shows a screen-space prompt and an approximate local progress bar.
-- The server is authoritative; this is presentation only.

local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local ReviveController = require(script.Parent.ReviveController)

local InteractionController = {}

local localPlayer = Players.LocalPlayer

-- Prompt appears when player is within this distance (studs).
-- Slightly larger than server's interactMaxDistance so the prompt appears before
-- the server rejects the request.
local PROMPT_DISTANCE = MatchConfig.interactMaxDistance + 4

-- ── State ─────────────────────────────────────────────────────────────────

local _currentObjectiveId: string? = nil -- id of the beacon the prompt is showing
local _isInteracting = false
local _eHeld = false -- true while E is physically held down
local _interactStartTime = 0
local _relayStates: { [string]: string } = {} -- updated from MatchStateUpdate
-- Guard: don't show any prompt until we've received at least one authoritative
-- relay state from the server. Prevents showing prompts for Locked relays during
-- the brief window before the first MatchStateUpdate arrives.
local _hasReceivedState = false

-- Proximity check throttle (~10 Hz is plenty; no need to run every frame).
local _proximityTimer = 0
local PROXIMITY_HZ = 10

-- ── UI ────────────────────────────────────────────────────────────────────

local _promptPanel: Frame? = nil
local _promptLabel: TextLabel? = nil
local _progressFill: Frame? = nil

local function addCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function buildPromptUI(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "InteractPromptGui"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "PromptPanel"
	panel.Size = UDim2.new(0, 240, 0, 58)
	panel.Position = UDim2.new(0.5, -120, 0.76, 0)
	panel.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	panel.BackgroundTransparency = 0.3
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	addCorner(panel, 8)

	local keyHint = Instance.new("TextLabel")
	keyHint.Name = "KeyHint"
	keyHint.Size = UDim2.new(1, 0, 0, 20)
	keyHint.Position = UDim2.new(0, 0, 0, 6)
	keyHint.BackgroundTransparency = 1
	keyHint.Text = "[E] Activate Relay"
	keyHint.TextColor3 = Color3.fromRGB(255, 210, 80)
	keyHint.TextSize = 14
	keyHint.Font = Enum.Font.GothamBold
	keyHint.TextXAlignment = Enum.TextXAlignment.Center
	keyHint.Parent = panel

	local barBg = Instance.new("Frame")
	barBg.Name = "ProgressBg"
	barBg.Size = UDim2.new(1, -20, 0, 12)
	barBg.Position = UDim2.new(0, 10, 0, 34)
	barBg.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
	barBg.BackgroundTransparency = 0.15
	barBg.ClipsDescendants = true
	barBg.BorderSizePixel = 0
	barBg.Parent = panel
	addCorner(barBg, 4)

	local fill = Instance.new("Frame")
	fill.Name = "ProgressFill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	addCorner(fill, 4)

	return panel, keyHint, fill
end

-- ── Helpers ───────────────────────────────────────────────────────────────

-- Returns the world position of a beacon instance (BasePart or Model).
local function getBeaconPosition(beacon: Instance): Vector3?
	if beacon:IsA("BasePart") then
		return (beacon :: BasePart).Position
	elseif beacon:IsA("Model") then
		local model = beacon :: Model
		if model.PrimaryPart then
			return model.PrimaryPart.Position
		end
		local cf, _ = model:GetBoundingBox()
		return cf.Position
	end
	return nil
end

-- Returns the player's HumanoidRootPart position, or nil if not loaded.
local function getPlayerPosition(): Vector3?
	local char = localPlayer.Character
	if not char then
		return nil
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp and (hrp :: BasePart).Position or nil
end

-- ── Interaction control ───────────────────────────────────────────────────

local function showPrompt(objectiveId: string)
	local panel = _promptPanel
	if not panel then
		return
	end
	if _promptLabel then
		local letter = objectiveId:sub(-1)
		_promptLabel.Text = "[E] Activate Relay " .. letter
	end
	panel.Visible = true
end

local function hidePrompt()
	if _promptPanel then
		_promptPanel.Visible = false
	end
	if _progressFill then
		_progressFill.Size = UDim2.new(0, 0, 1, 0)
	end
end

local function stopInteract()
	if not _isInteracting then
		return
	end
	_isInteracting = false
	if _currentObjectiveId then
		Remotes.StopInteractRequest:FireServer({ objectiveId = _currentObjectiveId })
	end
	if _progressFill then
		_progressFill.Size = UDim2.new(0, 0, 1, 0)
	end
end

local function tryStartInteract()
	if _currentObjectiveId == nil then
		return
	end
	if _isInteracting then
		return
	end
	-- Don't try to interact with a completed relay.
	if _relayStates[_currentObjectiveId] == "Completed" then
		return
	end
	_isInteracting = true
	_interactStartTime = os.clock()
	Remotes.StartInteractRequest:FireServer({ objectiveId = _currentObjectiveId })
end

-- ── Proximity scan (throttled) ────────────────────────────────────────────

local function updateNearbyBeacon()
	-- Don't show any prompt before the first authoritative state arrives.
	if not _hasReceivedState then
		return
	end

	local playerPos = getPlayerPosition()
	if not playerPos then
		if _currentObjectiveId then
			stopInteract()
			hidePrompt()
			_currentObjectiveId = nil
		end
		return
	end

	local bestId: string? = nil
	local bestDist = PROMPT_DISTANCE

	for _, beacon in CollectionService:GetTagged("RelayBeacon") do
		local objectiveId = beacon:GetAttribute("ObjectiveId") :: string?
		if not objectiveId then
			continue
		end
		-- Only show a prompt for Active relays.  Locked (and nil, which is the
		-- state before the first MatchStateUpdate) are silently skipped.
		if _relayStates[objectiveId] ~= "Active" then
			continue
		end

		local pos = getBeaconPosition(beacon)
		if not pos then
			continue
		end

		local dist = (playerPos - pos).Magnitude
		if dist < bestDist then
			bestDist = dist
			bestId = objectiveId
		end
	end

	if bestId ~= _currentObjectiveId then
		-- Moved to a different beacon (or moved away entirely).
		if _isInteracting then
			stopInteract()
		end
		_currentObjectiveId = bestId
	end

	if bestId and not ReviveController.hasTarget() then
		showPrompt(bestId)
		-- If E is already held (e.g. after a brief beacon stream-out/stream-in or
		-- if the first StartInteractRequest was silently dropped by the server),
		-- resume interaction without requiring the player to re-press E.
		if _eHeld and not _isInteracting then
			tryStartInteract()
		end
	else
		hidePrompt()
	end
end

-- ── Input handlers ────────────────────────────────────────────────────────

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		_eHeld = true
		-- Revive takes priority; let ReviveController handle the key in that case.
		if ReviveController.hasTarget() then
			return
		end
		tryStartInteract()
	end
end

local function onInputEnded(input: InputObject)
	-- Always clean up on key-up, even if gameProcessed, to avoid stuck interact state.
	if input.KeyCode == Enum.KeyCode.E then
		_eHeld = false
		stopInteract()
	end
end

-- ── MatchState listener ───────────────────────────────────────────────────

local function onMatchStateUpdate(state: { [string]: any })
	local relays = state.relays :: { [string]: string }?
	if not relays then
		return
	end
	_relayStates = table.clone(relays)
	_hasReceivedState = true

	-- If the relay we're interacting with is no longer Active, clean up.
	if _currentObjectiveId and _relayStates[_currentObjectiveId] ~= "Active" then
		stopInteract()
		hidePrompt()
		_currentObjectiveId = nil
	end
end

-- ── Public ────────────────────────────────────────────────────────────────

function InteractionController.init()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	_promptPanel, _promptLabel, _progressFill = buildPromptUI(playerGui)

	Remotes.MatchStateUpdate.OnClientEvent:Connect(onMatchStateUpdate)

	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)

	RunService.Heartbeat:Connect(function(dt: number)
		-- Throttled proximity scan.
		_proximityTimer -= dt
		if _proximityTimer <= 0 then
			_proximityTimer = 1 / PROXIMITY_HZ
			updateNearbyBeacon()
		end

		-- Update local progress bar every frame (cheap).
		if _isInteracting and _promptPanel and _promptPanel.Visible and _progressFill then
			local elapsed = os.clock() - _interactStartTime
			local fraction = math.min(elapsed / MatchConfig.relayActivationTime, 1)
			_progressFill.Size = UDim2.new(fraction, 0, 1, 0)
		end
	end)

	-- If a beacon streams out while the player is interacting with it, cancel.
	CollectionService:GetInstanceRemovedSignal("RelayBeacon"):Connect(function(beacon: Instance)
		local objectiveId = beacon:GetAttribute("ObjectiveId") :: string?
		if objectiveId and objectiveId == _currentObjectiveId then
			stopInteract()
			hidePrompt()
			_currentObjectiveId = nil
		end
	end)

	print("[InteractionController] Initialized.")
end

return InteractionController
