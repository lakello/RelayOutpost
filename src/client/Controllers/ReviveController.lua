-- Client-side revive controller.
-- Tracks downed allies via PlayerStateEvent, shows a proximity prompt, and
-- fires ReviveRequest while the player holds [E] near a downed teammate.
-- Revive takes priority over relay interaction — InteractionController
-- calls ReviveController.hasTarget() before acting on the E key.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)

local ReviveController = {}

local localPlayer = Players.LocalPlayer

-- Prompt appears slightly beyond server reviveMaxDistance so it shows before the
-- server would reject the request.
local PROMPT_DISTANCE = MatchConfig.reviveMaxDistance + 4

-- ── State ─────────────────────────────────────────────────────────────────

local _downedPlayers: { [number]: true } = {} -- userId → true
local _isLocalDowned = false
local _reviveTarget: Player? = nil -- nearest downed ally within PROMPT_DISTANCE
local _isReviving = false
local _reviveStartTime = 0

local _proximityTimer = 0
local PROXIMITY_HZ = 10

-- ── UI ────────────────────────────────────────────────────────────────────

local _panel: Frame? = nil
local _label: TextLabel? = nil
local _fill: Frame? = nil

local function addCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function buildUI(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "RevivePromptGui"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "RevivePanel"
	panel.Size = UDim2.new(0, 240, 0, 58)
	panel.Position = UDim2.new(0.5, -120, 0.82, 0)
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
	keyHint.Text = "[E] Revive Ally"
	keyHint.TextColor3 = Color3.fromRGB(100, 220, 255)
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
	fill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	addCorner(fill, 4)

	return panel, keyHint, fill
end

-- ── Prompt helpers ────────────────────────────────────────────────────────

local function showPrompt(target: Player)
	if not _panel or not _label then
		return
	end
	_label.Text = "[E] Revive " .. target.DisplayName
	_panel.Visible = true
end

local function hidePrompt()
	if _panel then
		_panel.Visible = false
	end
	if _fill then
		_fill.Size = UDim2.new(0, 0, 1, 0)
	end
end

-- ── Revive control ────────────────────────────────────────────────────────

local function stopRevive()
	if not _isReviving then
		return
	end
	_isReviving = false
	if _reviveTarget then
		Remotes.ReviveRequest:FireServer({ state = "Stop", targetUserId = _reviveTarget.UserId })
	end
	if _fill then
		_fill.Size = UDim2.new(0, 0, 1, 0)
	end
end

local function startRevive()
	if not _reviveTarget or _isReviving then
		return
	end
	_isReviving = true
	_reviveStartTime = os.clock()
	Remotes.ReviveRequest:FireServer({ state = "Start", targetUserId = _reviveTarget.UserId })
end

-- ── Proximity scan ────────────────────────────────────────────────────────

local function getLocalPos(): Vector3?
	local char = localPlayer.Character
	if not char then
		return nil
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp and hrp.Position or nil
end

local function findNearestDownedAlly(): Player?
	local myPos = getLocalPos()
	if not myPos then
		return nil
	end

	local best: Player? = nil
	local bestDist = PROMPT_DISTANCE

	for _, player in Players:GetPlayers() do
		if player == localPlayer then
			continue
		end
		if not _downedPlayers[player.UserId] then
			continue
		end
		local char = player.Character
		if not char then
			continue
		end
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			continue
		end
		local dist = (myPos - hrp.Position).Magnitude
		if dist < bestDist then
			bestDist = dist
			best = player
		end
	end

	return best
end

local function updateProximity()
	if _isLocalDowned then
		if _reviveTarget then
			stopRevive()
			hidePrompt()
			_reviveTarget = nil
		end
		return
	end

	local newTarget = findNearestDownedAlly()

	if newTarget ~= _reviveTarget then
		if _isReviving then
			stopRevive()
		end
		_reviveTarget = newTarget
	end

	if _reviveTarget then
		showPrompt(_reviveTarget)
	else
		hidePrompt()
	end
end

-- ── Public ────────────────────────────────────────────────────────────────

-- InteractionController checks this before acting on E to let revive take priority.
function ReviveController.hasTarget(): boolean
	return _reviveTarget ~= nil and not _isLocalDowned
end

function ReviveController.init()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	_panel, _label, _fill = buildUI(playerGui)

	-- Track downed/revived state for all players
	Remotes.PlayerStateEvent.OnClientEvent:Connect(function(data: { [string]: any })
		if data.type == "Downed" then
			_downedPlayers[data.userId] = true
			if data.userId == localPlayer.UserId then
				_isLocalDowned = true
				stopRevive()
				hidePrompt()
				_reviveTarget = nil
			end
		elseif data.type == "Revived" then
			_downedPlayers[data.userId] = nil
			if data.userId == localPlayer.UserId then
				_isLocalDowned = false
			end
			-- If we were reviving this player, clean up
			if _reviveTarget and _reviveTarget.UserId == data.userId then
				stopRevive()
				hidePrompt()
				_reviveTarget = nil
			end
		end
	end)

	-- E key: start / stop revive
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E and _reviveTarget then
			startRevive()
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.E then
			stopRevive()
		end
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		-- Proximity scan (throttled)
		_proximityTimer -= dt
		if _proximityTimer <= 0 then
			_proximityTimer = 1 / PROXIMITY_HZ
			updateProximity()
		end

		-- Update local progress bar every frame
		if _isReviving and _panel and _panel.Visible and _fill then
			local elapsed = os.clock() - _reviveStartTime
			_fill.Size = UDim2.new(math.min(elapsed / MatchConfig.reviveDuration, 1), 0, 1, 0)
		end
	end)

	print("[ReviveController] Initialized.")
end

return ReviveController
