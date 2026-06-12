-- Victory / Defeat end screen.
-- Listens for terminal phase in MatchStateUpdate and renders a fade-in overlay.
-- No Workspace references; pure retained GUI built procedurally.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local EndScreenController = {}

local localPlayer = Players.LocalPlayer

local COLOR_VICTORY_BG = Color3.fromRGB(0, 22, 8)
local COLOR_VICTORY_TITLE = Color3.fromRGB(70, 220, 110)
local COLOR_DEFEAT_BG = Color3.fromRGB(22, 0, 0)
local COLOR_DEFEAT_TITLE = Color3.fromRGB(220, 60, 60)

local _shown = false

-- ── UI builder ────────────────────────────────────────────────────────────

local function addCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function buildEndScreen(playerGui: PlayerGui): (ScreenGui, Frame, Frame, TextLabel, TextLabel)
	local gui = Instance.new("ScreenGui")
	gui.Name = "EndScreenGui"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = playerGui

	-- Dark background overlay — starts fully transparent, tweens to semi-opaque.
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bg.BackgroundTransparency = 1
	bg.BorderSizePixel = 0
	bg.ZIndex = 30
	bg.Parent = gui

	-- Centered card
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.new(0, 500, 0, 230)
	card.Position = UDim2.new(0.5, -250, 0.5, -115)
	card.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.ZIndex = 31
	card.Parent = bg
	addCorner(card, 14)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 96)
	titleLabel.Position = UDim2.new(0, 0, 0, 24)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextSize = 68
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.TextStrokeTransparency = 0.45
	titleLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	titleLabel.ZIndex = 32
	titleLabel.Parent = card

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Size = UDim2.new(1, -48, 0, 44)
	subtitleLabel.Position = UDim2.new(0, 24, 0, 132)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.TextSize = 17
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextColor3 = Color3.fromRGB(185, 185, 185)
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Center
	subtitleLabel.TextWrapped = true
	subtitleLabel.ZIndex = 32
	subtitleLabel.Parent = card

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.Size = UDim2.new(1, -48, 0, 22)
	hintLabel.Position = UDim2.new(0, 24, 0, 196)
	hintLabel.BackgroundTransparency = 1
	hintLabel.TextSize = 12
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextColor3 = Color3.fromRGB(90, 90, 90)
	hintLabel.TextXAlignment = Enum.TextXAlignment.Center
	hintLabel.Text = "Press F9 to leave  ·  Press F5 to restart in Studio"
	hintLabel.ZIndex = 32
	hintLabel.Parent = card

	return gui, bg, card, titleLabel, subtitleLabel
end

-- ── Public ────────────────────────────────────────────────────────────────

function EndScreenController.init()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local gui, bg, card, titleLabel, subtitleLabel = buildEndScreen(playerGui)

	Remotes.MatchStateUpdate.OnClientEvent:Connect(function(state: { [string]: any })
		if _shown then
			return
		end
		local phase = state.phase :: string
		if phase ~= "Victory" and phase ~= "Defeat" then
			return
		end

		_shown = true
		local isVictory = phase == "Victory"

		titleLabel.Text = isVictory and "VICTORY" or "DEFEAT"
		titleLabel.TextColor3 = isVictory and COLOR_VICTORY_TITLE or COLOR_DEFEAT_TITLE
		card.BackgroundColor3 = isVictory and COLOR_VICTORY_BG or COLOR_DEFEAT_BG
		-- currentObjective already contains the correct end message set by WaveDirectorSystem.
		subtitleLabel.Text = tostring(state.currentObjective)

		gui.Enabled = true

		-- Fade in background overlay
		TweenService
			:Create(bg, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0.42,
			})
			:Play()
	end)

	print("[EndScreen] Initialized.")
end

return EndScreenController
