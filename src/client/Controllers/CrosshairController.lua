-- Cursor-following crosshair.
-- Hides the default Roblox cursor icon and replaces it with a custom crosshair
-- made of plain Frames (no image assets required).
-- Updates position every RenderStepped for smooth tracking.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CrosshairController = {}

local localPlayer = Players.LocalPlayer

-- ── Layout constants ──────────────────────────────────────────────────────

local LINE_W = 2   -- line thickness (px)
local LINE_L = 8   -- line length (px)
local GAP = 5      -- gap between center and line start (px)

-- ── State ─────────────────────────────────────────────────────────────────

local _container: Frame? = nil
local _hidden = false

-- ── Builder ───────────────────────────────────────────────────────────────

-- Makes a single crosshair line with a dark outline for readability over any background.
local function makeLine(parent: Frame, name: string, w: number, h: number, ox: number, oy: number)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.new(0, w, 0, h)
	-- ox/oy are offsets from the zero-size container's anchor point (= cursor position).
	-- AnchorPoint 0.5,0.5 means Position sets the line's center.
	f.Position = UDim2.new(0, ox, 0, oy)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.BackgroundTransparency = 0
	f.BorderSizePixel = 0
	f.ZIndex = 51
	f.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = f
end

local function buildCrosshair(playerGui: PlayerGui): Frame
	local gui = Instance.new("ScreenGui")
	gui.Name = "CrosshairGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 50
	gui.Parent = playerGui

	-- Zero-size anchor frame; children offset from its AnchorPoint = cursor position.
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 0, 0, 0)
	container.BackgroundTransparency = 1
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.ZIndex = 50
	container.Parent = gui

	local half = LINE_L / 2
	local mid = GAP + half -- distance from center to line center

	makeLine(container, "Top",    LINE_W, LINE_L,  0,   -mid)
	makeLine(container, "Bottom", LINE_W, LINE_L,  0,    mid)
	makeLine(container, "Left",   LINE_L, LINE_W,  -mid, 0)
	makeLine(container, "Right",  LINE_L, LINE_W,   mid, 0)

	-- Center dot
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.Size = UDim2.new(0, 3, 0, 3)
	dot.Position = UDim2.new(0, 0, 0, 0)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.BorderSizePixel = 0
	dot.ZIndex = 51
	dot.Parent = container
	Instance.new("UICorner").Parent = dot

	return container
end

-- ── Public ────────────────────────────────────────────────────────────────

-- Hides/shows the crosshair (e.g. when downed).
function CrosshairController.setHidden(hidden: boolean)
	_hidden = hidden
	if _container then
		_container.Visible = not hidden
	end
end

function CrosshairController.init()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	-- Replace the default Roblox cursor icon with our crosshair.
	UserInputService.MouseIconEnabled = false

	_container = buildCrosshair(playerGui)

	-- Hide crosshair while downed; restore on revive.
	Remotes.PlayerStateEvent.OnClientEvent:Connect(function(data: { [string]: any })
		if data.userId ~= localPlayer.UserId then
			return
		end
		if data.type == "Downed" then
			CrosshairController.setHidden(true)
		elseif data.type == "Revived" then
			CrosshairController.setHidden(false)
		end
	end)

	-- Reset on character respawn.
	localPlayer.CharacterAdded:Connect(function()
		CrosshairController.setHidden(false)
	end)

	-- Track cursor every render frame for smooth movement.
	RunService.RenderStepped:Connect(function()
		local c = _container
		if not c or _hidden then
			return
		end
		local mousePos = UserInputService:GetMouseLocation()
		c.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
	end)

	print("[CrosshairController] Initialized.")
end

return CrosshairController
