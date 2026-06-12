-- Client VFX controller.
-- Handles: bullet tracer, hit spark, damage screen vignette.
-- All effects are pure Part/GUI — no asset IDs required.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)

local VfxController = {}

local localPlayer = Players.LocalPlayer
local _vignette: Frame? = nil

local TRACER_COLOR = Color3.fromRGB(255, 230, 120) -- warm yellow tracer
local SPARK_COLOR  = Color3.fromRGB(255, 200, 60)  -- orange hit spark
local TRACER_LIFE  = 0.08 -- seconds until tracer fades
local SPARK_LIFE   = 0.12

-- ── World-space effects ───────────────────────────────────────────────────

-- Thin glowing Part from origin to endpoint that fades out immediately.
local function spawnTracer(origin: Vector3, endpoint: Vector3)
	local length = (endpoint - origin).Magnitude
	if length < 0.1 then
		return
	end
	local midPoint = origin:Lerp(endpoint, 0.5)

	local part = Instance.new("Part")
	part.Name = "BulletTracer"
	-- CFrame.new(pos, lookAt) orients the Part so its -Z axis (LookVector) faces endpoint.
	-- With Size.Z = length the part spans exactly from origin to endpoint.
	part.CFrame = CFrame.new(midPoint, endpoint)
	part.Size = Vector3.new(0.06, 0.06, length)
	part.Material = Enum.Material.Neon
	part.Color = TRACER_COLOR
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Parent = workspace

	TweenService
		:Create(part, TweenInfo.new(TRACER_LIFE, Enum.EasingStyle.Linear), {
			Transparency = 1,
		})
		:Play()
	task.delay(TRACER_LIFE + 0.02, function()
		part:Destroy()
	end)
end

-- Small glowing ball that pops at the hit position and shrinks away.
local function spawnHitSpark(pos: Vector3)
	local part = Instance.new("Part")
	part.Name = "HitSpark"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(0.45, 0.45, 0.45)
	part.CFrame = CFrame.new(pos)
	part.Material = Enum.Material.Neon
	part.Color = SPARK_COLOR
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Parent = workspace

	TweenService
		:Create(part, TweenInfo.new(SPARK_LIFE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.05, 0.05, 0.05),
			Transparency = 1,
		})
		:Play()
	task.delay(SPARK_LIFE + 0.02, function()
		part:Destroy()
	end)
end

-- ── UI ────────────────────────────────────────────────────────────────────

local function buildVignetteGui(playerGui: PlayerGui): Frame
	local gui = Instance.new("ScreenGui")
	gui.Name = "VfxGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local v = Instance.new("Frame")
	v.Name = "DamageVignette"
	v.Size = UDim2.new(1, 0, 1, 0)
	v.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
	v.BackgroundTransparency = 1
	v.BorderSizePixel = 0
	v.ZIndex = 25
	v.Parent = gui
	return v
end

-- ── Flash ─────────────────────────────────────────────────────────────────

local function flashDamage()
	local v = _vignette
	if not v then
		return
	end
	-- Snap visible, then fade out — any previous tween is overridden by the snap.
	v.BackgroundTransparency = 0.35
	TweenService
		:Create(v, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		})
		:Play()
end

-- ── Character binding ─────────────────────────────────────────────────────

local function bindCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		return
	end
	local prevHp = humanoid.Health
	humanoid.HealthChanged:Connect(function(hp: number)
		-- Flash on damage, but not when transitioning to the downed sentinel (hp == 1).
		-- The Downed PlayerStateEvent below handles that case separately.
		if hp < prevHp and hp > 1 then
			flashDamage()
		end
		prevHp = hp
	end)
end

-- ── Public ────────────────────────────────────────────────────────────────

function VfxController.init()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	_vignette = buildVignetteGui(playerGui)

	-- ── Bullet tracer + hit spark ─────────────────────────────────────────
	-- CombatEvent fires on all clients for every shot (hit or miss).
	Remotes.CombatEvent.OnClientEvent:Connect(function(data: { [string]: any })
		local origin = data.origin :: Vector3?
		local direction = data.direction :: Vector3?
		if not origin or not direction then
			return
		end

		local endpoint: Vector3
		if data.hit and data.hitPosition then
			endpoint = data.hitPosition :: Vector3
		else
			-- Miss: draw tracer to max weapon range
			endpoint = origin + direction * WeaponConfig.HitscanBlaster.maxRange
		end

		spawnTracer(origin, endpoint)

		if data.hit then
			spawnHitSpark(endpoint)
		end
	end)

	-- ── Damage vignette ───────────────────────────────────────────────────
	Remotes.PlayerStateEvent.OnClientEvent:Connect(function(data: { [string]: any })
		if data.userId == localPlayer.UserId and data.type == "Downed" then
			flashDamage()
		end
	end)

	if localPlayer.Character then
		task.spawn(bindCharacter, localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(function(char)
		bindCharacter(char)
	end)

	print("[VfxController] Initialized.")
end

return VfxController
