-- Pure UI constructor. Builds the ScreenGui hierarchy and returns element references.
-- No game state reads, no event subscriptions — that is HudController's job.

local HudBuilder = {}

local RELAY_LETTERS = { "A", "B", "C" }
local COLOR_RELAY_LOCKED = Color3.fromRGB(55, 55, 55)
local COLOR_RELAY_ACTIVE = Color3.fromRGB(255, 195, 40)
local COLOR_RELAY_DONE = Color3.fromRGB(40, 195, 100)

-- ── Private helpers ──────────────────────────────────────────────────────

local function addCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function addPadding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	local u = UDim.new(0, px)
	p.PaddingTop = u
	p.PaddingBottom = u
	p.PaddingLeft = u
	p.PaddingRight = u
	p.Parent = parent
end

local function makePanel(parent: Instance, name: string, pos: UDim2, size: UDim2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	f.BackgroundTransparency = 0.32
	f.BorderSizePixel = 0
	f.Position = pos
	f.Size = size
	f.Parent = parent
	addCorner(f, 8)
	return f
end

-- Returns the fill Frame (width driven by HudController).
local function makeBar(
	parent: Instance,
	name: string,
	pos: UDim2,
	size: UDim2,
	fillColor: Color3
): Frame
	local bg = Instance.new("Frame")
	bg.Name = name .. "Bg"
	bg.BackgroundColor3 = Color3.fromRGB(38, 38, 38)
	bg.BackgroundTransparency = 0.2
	bg.BorderSizePixel = 0
	bg.ClipsDescendants = true
	bg.Position = pos
	bg.Size = size
	bg.Parent = parent
	addCorner(bg, 4)

	local fill = Instance.new("Frame")
	fill.Name = name .. "Fill"
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.Parent = bg
	addCorner(fill, 4)

	return fill
end

local function makeLabel(
	parent: Instance,
	name: string,
	text: string,
	pos: UDim2,
	size: UDim2,
	fontSize: number,
	xAlign: Enum.TextXAlignment?,
	bold: boolean?
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.fromRGB(235, 235, 235)
	l.TextSize = fontSize
	l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
	l.TextStrokeTransparency = 0.6
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.Parent = parent
	return l
end

local function makeCaption(parent: Instance, name: string, text: string, posY: number): TextLabel
	local l = makeLabel(
		parent,
		name,
		text,
		UDim2.new(0, 0, 0, posY),
		UDim2.new(1, 0, 0, 14),
		10,
		Enum.TextXAlignment.Left
	)
	l.TextColor3 = Color3.fromRGB(150, 150, 150)
	return l
end

-- ── Public ───────────────────────────────────────────────────────────────

export type HudElements = {
	waveLabel: TextLabel,
	objectiveLabel: TextLabel,
	playerHpLabel: TextLabel,
	playerHpFill: Frame,
	genHpLabel: TextLabel,
	genHpFill: Frame,
	relayIcons: { Frame },
	downedOverlay: Frame,
}

-- Builds the full HUD inside playerGui. Call once; returns updatable element refs.
function HudBuilder.build(playerGui: PlayerGui): HudElements
	local gui = Instance.new("ScreenGui")
	gui.Name = "RelayOutpostHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- ── Top center: Wave + Objective ──────────────────────────────────────
	local topPanel =
		makePanel(gui, "TopPanel", UDim2.new(0.5, -155, 0, 8), UDim2.new(0, 310, 0, 52))
	addPadding(topPanel, 8)

	local waveLabel = makeLabel(
		topPanel,
		"WaveLabel",
		"Wave 1",
		UDim2.new(0, 0, 0, 0),
		UDim2.new(1, 0, 0, 20),
		13,
		Enum.TextXAlignment.Center,
		true
	)
	waveLabel.TextColor3 = Color3.fromRGB(255, 210, 80)

	local objectiveLabel = makeLabel(
		topPanel,
		"ObjectiveLabel",
		"Defend the generator",
		UDim2.new(0, 0, 0, 22),
		UDim2.new(1, 0, 0, 18),
		13,
		Enum.TextXAlignment.Center
	)
	objectiveLabel.TextTruncate = Enum.TextTruncate.AtEnd

	-- ── Bottom left: Player HP ─────────────────────────────────────────────
	local playerPanel =
		makePanel(gui, "PlayerPanel", UDim2.new(0, 10, 1, -80), UDim2.new(0, 175, 0, 66))
	addPadding(playerPanel, 8)

	makeCaption(playerPanel, "PlayerCaption", "PLAYER HP", 0)

	local playerHpLabel = makeLabel(
		playerPanel,
		"PlayerHpValue",
		"100 / 100",
		UDim2.new(0, 0, 0, 16),
		UDim2.new(1, 0, 0, 16),
		13,
		Enum.TextXAlignment.Left
	)

	local playerHpFill = makeBar(
		playerPanel,
		"PlayerHP",
		UDim2.new(0, 0, 0, 36),
		UDim2.new(1, 0, 0, 14),
		Color3.fromRGB(80, 200, 80)
	)

	-- ── Bottom right: Generator HP + Relay beacons ────────────────────────
	local rightPanel =
		makePanel(gui, "RightPanel", UDim2.new(1, -188, 1, -128), UDim2.new(0, 178, 0, 116))
	addPadding(rightPanel, 8)

	makeCaption(rightPanel, "GenCaption", "GENERATOR", 0)

	local genHpLabel = makeLabel(
		rightPanel,
		"GenHpValue",
		"100 / 100",
		UDim2.new(0, 0, 0, 16),
		UDim2.new(1, 0, 0, 16),
		13,
		Enum.TextXAlignment.Left
	)

	local genHpFill = makeBar(
		rightPanel,
		"GenHP",
		UDim2.new(0, 0, 0, 36),
		UDim2.new(1, 0, 0, 14),
		Color3.fromRGB(55, 140, 220)
	)

	makeCaption(rightPanel, "RelayCaption", "RELAY BEACONS", 58)

	-- Three relay icons (A / B / C)
	local relayIcons: { Frame } = {}
	for i, letter in ipairs(RELAY_LETTERS) do
		local icon = Instance.new("Frame")
		icon.Name = "RelayIcon_" .. letter
		icon.Size = UDim2.new(0, 42, 0, 26)
		icon.Position = UDim2.new(0, (i - 1) * 50, 0, 74)
		icon.BackgroundColor3 = COLOR_RELAY_LOCKED
		icon.BackgroundTransparency = 0.15
		icon.BorderSizePixel = 0
		icon.Parent = rightPanel
		addCorner(icon, 5)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text = letter
		lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
		lbl.TextSize = 13
		lbl.Font = Enum.Font.GothamBold
		lbl.Parent = icon

		relayIcons[i] = icon
	end

	-- Attach color constants as attributes so HudController can read them
	-- without duplicating the definitions.
	gui:SetAttribute("ColorRelayLocked", COLOR_RELAY_LOCKED)
	gui:SetAttribute("ColorRelayActive", COLOR_RELAY_ACTIVE)
	gui:SetAttribute("ColorRelayDone", COLOR_RELAY_DONE)

	-- ── Downed overlay ────────────────────────────────────────────────────
	-- Full-screen tinted panel shown when the local player is incapacitated.
	local downedOverlay = Instance.new("Frame")
	downedOverlay.Name = "DownedOverlay"
	downedOverlay.Size = UDim2.new(1, 0, 1, 0)
	downedOverlay.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
	downedOverlay.BackgroundTransparency = 0.55
	downedOverlay.BorderSizePixel = 0
	downedOverlay.ZIndex = 20
	downedOverlay.Visible = false
	downedOverlay.Parent = gui

	local downedTitle = makeLabel(
		downedOverlay,
		"DownedTitle",
		"DOWNED",
		UDim2.new(0, 0, 0.38, 0),
		UDim2.new(1, 0, 0, 64),
		52,
		Enum.TextXAlignment.Center,
		true
	)
	downedTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
	downedTitle.ZIndex = 21

	local downedSub = makeLabel(
		downedOverlay,
		"DownedSubtitle",
		"An ally can revive you with [E]",
		UDim2.new(0, 0, 0.38, 72),
		UDim2.new(1, 0, 0, 28),
		18,
		Enum.TextXAlignment.Center,
		false
	)
	downedSub.TextColor3 = Color3.fromRGB(220, 180, 180)
	downedSub.ZIndex = 21

	return {
		waveLabel = waveLabel,
		objectiveLabel = objectiveLabel,
		playerHpLabel = playerHpLabel,
		playerHpFill = playerHpFill,
		genHpLabel = genHpLabel,
		genHpFill = genHpFill,
		relayIcons = relayIcons,
		downedOverlay = downedOverlay,
	}
end

return HudBuilder
