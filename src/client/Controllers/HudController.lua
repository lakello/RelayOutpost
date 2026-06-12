-- Retained HUD controller.
-- Reads ONLY from: MatchStateUpdate (server) and local Humanoid (player HP).
-- Never reads Workspace relay/generator instances directly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HudBuilder = require(script.Parent.Parent.UI.HudBuilder)
local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local WaveConfig = require(ReplicatedStorage.Shared.Config.WaveConfig)

local HudController = {}

-- Ordered relay IDs must match HudBuilder relayIcons[1..3]
local RELAY_IDS = { "Relay_A", "Relay_B", "Relay_C" }

local COLOR_HP_GOOD = Color3.fromRGB(80, 200, 80)
local COLOR_HP_WARN = Color3.fromRGB(220, 178, 30)
local COLOR_HP_DANGER = Color3.fromRGB(200, 60, 60)
local COLOR_RELAY_LOCKED = Color3.fromRGB(55, 55, 55)
local COLOR_RELAY_ACTIVE = Color3.fromRGB(255, 195, 40)
local COLOR_RELAY_DONE = Color3.fromRGB(40, 195, 100)

local _elements: HudBuilder.HudElements? = nil
local _isLocalDowned = false

-- ── Internal helpers ──────────────────────────────────────────────────────

local function hpColor(fraction: number): Color3
	if fraction > 0.6 then
		return COLOR_HP_GOOD
	elseif fraction > 0.3 then
		return COLOR_HP_WARN
	else
		return COLOR_HP_DANGER
	end
end

local function setBarFill(fill: Frame, fraction: number)
	fill.Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0)
end

-- ── Server state handler ──────────────────────────────────────────────────

local function onMatchStateUpdate(state: { [string]: any })
	local e = _elements
	if e == nil then
		return
	end

	-- Phase-aware wave label: avoid "Wave 0" in Lobby and "Wave 4" in Extraction.
	local phase: string = state.phase
	if phase == "Lobby" then
		e.waveLabel.Text = "Lobby"
		e.waveLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	elseif phase == "Extraction" then
		e.waveLabel.Text = "Extraction"
		e.waveLabel.TextColor3 = Color3.fromRGB(255, 120, 40)
	elseif phase == "Victory" then
		e.waveLabel.Text = "Victory!"
		e.waveLabel.TextColor3 = Color3.fromRGB(80, 220, 120)
	elseif phase == "Defeat" then
		e.waveLabel.Text = "Defeat"
		e.waveLabel.TextColor3 = Color3.fromRGB(220, 60, 60)
	elseif state.wave > 0 then
		e.waveLabel.Text = "Wave " .. tostring(state.wave) .. " / " .. tostring(WaveConfig.waveCount)
		e.waveLabel.TextColor3 = Color3.fromRGB(255, 210, 80)
	else
		e.waveLabel.Text = "Lobby"
		e.waveLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	end

	-- Objective
	e.objectiveLabel.Text = tostring(state.currentObjective)

	-- Generator HP
	local genCur: number = state.generator.current
	local genMax: number = state.generator.max
	local genFrac = genMax > 0 and (genCur / genMax) or 0
	e.genHpLabel.Text = tostring(genCur) .. " / " .. tostring(genMax)
	setBarFill(e.genHpFill, genFrac)
	-- Generator bar keeps its blue colour; darken fill on low HP for urgency
	if genFrac <= 0.3 then
		e.genHpFill.BackgroundColor3 = COLOR_HP_DANGER
	elseif genFrac <= 0.6 then
		e.genHpFill.BackgroundColor3 = COLOR_HP_WARN
	else
		e.genHpFill.BackgroundColor3 = Color3.fromRGB(55, 140, 220)
	end

	-- Relay icons
	local relays: { [string]: string } = state.relays
	for i, relayId in ipairs(RELAY_IDS) do
		local relayState = relays[relayId] or "Locked"
		if relayState == "Completed" then
			e.relayIcons[i].BackgroundColor3 = COLOR_RELAY_DONE
		elseif relayState == "Active" then
			e.relayIcons[i].BackgroundColor3 = COLOR_RELAY_ACTIVE
		else
			e.relayIcons[i].BackgroundColor3 = COLOR_RELAY_LOCKED
		end
	end
end

-- ── Player HP (local Humanoid) ────────────────────────────────────────────

local function applyPlayerHp(hp: number, maxHp: number)
	local e = _elements
	if e == nil then
		return
	end
	-- While downed the Humanoid is kept at 1 HP to block respawn; suppress those
	-- updates so the bar shows 0 rather than a misleading "1 / 100".
	if _isLocalDowned then
		return
	end
	local frac = maxHp > 0 and (hp / maxHp) or 0
	e.playerHpLabel.Text = tostring(math.ceil(hp)) .. " / " .. tostring(math.ceil(maxHp))
	setBarFill(e.playerHpFill, frac)
	e.playerHpFill.BackgroundColor3 = hpColor(frac)
end

-- Bind to a character's Humanoid; re-called on each respawn.
local function bindCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if humanoid == nil then
		return
	end

	applyPlayerHp(humanoid.Health, humanoid.MaxHealth)

	humanoid.HealthChanged:Connect(function(hp: number)
		applyPlayerHp(hp, humanoid.MaxHealth)
	end)
end

-- ── Public ────────────────────────────────────────────────────────────────

function HudController.init()
	local localPlayer = Players.LocalPlayer

	_elements = HudBuilder.build(localPlayer.PlayerGui)

	-- Server → client match state
	Remotes.MatchStateUpdate.OnClientEvent:Connect(onMatchStateUpdate)

	-- Downed / revived state for the local player
	Remotes.PlayerStateEvent.OnClientEvent:Connect(function(data: { [string]: any })
		local e = _elements
		if not e then
			return
		end
		if data.userId ~= localPlayer.UserId then
			return
		end

		if data.type == "Downed" then
			_isLocalDowned = true
			e.downedOverlay.Visible = true
			-- Show 0 HP while downed (Humanoid is actually at 1 to block respawn)
			setBarFill(e.playerHpFill, 0)
			e.playerHpLabel.Text = "0 / " .. tostring(MatchConfig.playerMaxHealth)
			e.playerHpFill.BackgroundColor3 = COLOR_HP_DANGER
		elseif data.type == "Revived" then
			_isLocalDowned = false
			e.downedOverlay.Visible = false
			-- HP display will update automatically via Humanoid.HealthChanged
		end
	end)

	-- Local player HP (from Roblox-native Humanoid replication, not Workspace lookup)
	if localPlayer.Character then
		task.spawn(bindCharacter, localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(function(char)
		-- Reset downed state display on respawn (fresh character = not downed)
		_isLocalDowned = false
		if _elements then
			_elements.downedOverlay.Visible = false
		end
		bindCharacter(char)
	end)
end

return HudController
