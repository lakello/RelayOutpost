-- Reads player fire input and sends FireWeaponRequest to server.
-- Does NOT compute damage, hit detection, or game outcomes.
-- Client-side cooldown is cosmetic only; server validates authoritatively.
-- Direction is computed from the cursor screen position via ViewportPointToRay,
-- so shots go where the cursor is pointing, not where the camera faces.

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)

local InputController = {}

local localPlayer = Players.LocalPlayer
local FIRE_COOLDOWN = 1 / WeaponConfig.HitscanBlaster.fireRate

local _lastFireTime = 0
local _mouseHeld = false

local function tryFire()
	local now = os.clock()
	if now - _lastFireTime < FIRE_COOLDOWN then
		return
	end

	local character = localPlayer.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	_lastFireTime = now

	-- Step 1: cast a ray from the camera through the cursor to find the world aim point.
	-- Exclude all player characters so the cursor aims through teammates.
	local mousePos = UserInputService:GetMouseLocation()
	local cameraRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local aimParams = RaycastParams.new()
	aimParams.FilterType = Enum.RaycastFilterType.Exclude
	local charList = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(charList, p.Character)
		end
	end
	aimParams.FilterDescendantsInstances = charList

	local AIM_DIST = WeaponConfig.HitscanBlaster.maxRange + 50
	local aimResult = workspace:Raycast(cameraRay.Origin, cameraRay.Direction * AIM_DIST, aimParams)
	local aimPoint = aimResult and aimResult.Position or (cameraRay.Origin + cameraRay.Direction * AIM_DIST)

	-- Step 2: direction is from HRP toward the aim point, not from the camera.
	-- This removes the parallax offset between camera and character position.
	local origin = hrp.Position
	local direction = (aimPoint - origin).Unit

	Remotes.FireWeaponRequest:FireServer(origin, direction, now)
end

function InputController.init()
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			_mouseHeld = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			_mouseHeld = false
		end
	end)

	-- Poll on Heartbeat so fire rate is gated by FIRE_COOLDOWN, not click count.
	RunService.Heartbeat:Connect(function()
		if _mouseHeld then
			tryFire()
		end
	end)
end

return InputController
