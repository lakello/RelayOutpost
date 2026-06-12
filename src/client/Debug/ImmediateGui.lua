-- Immediate-mode debug panel backed by a pre-allocated TextLabel pool.
-- Calling render(lines) updates existing labels in-place — no new Instances per call.
-- The pool is fixed at POOL_SIZE; lines beyond that are silently truncated.
-- UIListLayout skips hidden labels so the panel collapses to fit actual content.

local ImmediateGui = {}
ImmediateGui.__index = ImmediateGui

local POOL_SIZE = 45
local LINE_HEIGHT = 15
local PANEL_W = 285

-- Section-header lines start with this prefix and get a distinct colour.
local HEADER_PREFIX = "["

local COLOR_HEADER = Color3.fromRGB(255, 200, 55)
local COLOR_NORMAL = Color3.fromRGB(205, 205, 205)

-- ── Helpers ───────────────────────────────────────────────────────────────

local function makeLabel(parent: Instance, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = "L" .. order
	l.LayoutOrder = order
	l.Size = UDim2.new(1, 0, 0, LINE_HEIGHT)
	l.BackgroundTransparency = 1
	l.TextColor3 = COLOR_NORMAL
	l.TextSize = 13
	l.Font = Enum.Font.Code -- monospace for column alignment
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextStrokeTransparency = 0.55
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.Text = ""
	l.Visible = false
	l.Parent = parent
	return l
end

-- ── Constructor ───────────────────────────────────────────────────────────

function ImmediateGui.new(playerGui: PlayerGui)
	local self = setmetatable({}, ImmediateGui)

	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugOverlay"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 100 -- on top of game UI
	gui.Enabled = false -- hidden until toggled by developer
	gui.Parent = playerGui

	local panel = Instance.new("ScrollingFrame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, PANEL_W, 0.55, 0)
	panel.Position = UDim2.new(0, 5, 0, 5)
	panel.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
	panel.BackgroundTransparency = 0.22
	panel.BorderSizePixel = 0
	panel.ScrollBarThickness = 3
	panel.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 120)
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.CanvasSize = UDim2.new(0, 0, 0, 0)
	panel.Parent = gui

	-- Round corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = panel

	-- Inner padding
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 5)
	pad.PaddingRight = UDim.new(0, 5)
	pad.Parent = panel

	-- Vertical stacker — skips Visible=false children automatically
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 0)
	layout.Parent = panel

	-- Pre-allocate label pool
	local pool: { TextLabel } = {}
	for i = 1, POOL_SIZE do
		pool[i] = makeLabel(panel, i)
	end

	self._gui = gui
	self._pool = pool
	return self
end

-- ── Public API ────────────────────────────────────────────────────────────

-- Replace displayed content with `lines`. O(POOL_SIZE), never allocates.
function ImmediateGui:render(lines: { string })
	local pool = self._pool
	local count = math.min(#lines, #pool)

	for i = 1, count do
		local label = pool[i]
		local text = lines[i]
		label.Text = text
		label.Visible = true
		label.TextColor3 = (text:sub(1, 1) == HEADER_PREFIX) and COLOR_HEADER or COLOR_NORMAL
	end

	for i = count + 1, #pool do
		pool[i].Visible = false
	end
end

function ImmediateGui:setVisible(visible: boolean)
	self._gui.Enabled = visible
end

function ImmediateGui:isVisible(): boolean
	return self._gui.Enabled
end

return ImmediateGui
