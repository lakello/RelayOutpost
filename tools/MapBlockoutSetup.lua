-- MAP BLOCKOUT SETUP
-- Run once in Roblox Studio Command Bar: View -> Command Bar -> paste -> Enter
-- Then Ctrl+S to save the place.
--
-- Layout (top-down):
--
--          [Zone B] North
--              |
--  [Zone C] - [Central] - [Zone A]
--    West         |          East
--           [Extraction]
--
-- All islands top surface at Y=2. Bridges connect at the same level.

local CS = game:GetService("CollectionService")
local ws = game.Workspace

-- Remove previous run so this script is idempotent
local prev = ws:FindFirstChild("Map")
if prev then
	prev:Destroy()
end

-- Remove default Baseplate (archipelago = floating islands)
local bp = ws:FindFirstChild("Baseplate")
if bp then
	bp:Destroy()
end

-- Helper: create an anchored Part
local function part(parent, name, sz, pos, color, mat, alpha, noCollide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = sz
	p.Position = pos
	p.Anchored = true
	p.BrickColor = BrickColor.new(color or "Medium stone grey")
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Transparency = alpha or 0
	p.CanCollide = not noCollide
	p.Parent = parent
	return p
end

-- Root
local Map = Instance.new("Folder", ws)
Map.Name = "Map"

-- =====================
-- AlwaysLoaded: central
-- =====================
local AL = Instance.new("Folder", Map)
AL.Name = "AlwaysLoaded"

-- Central island: 80x4x80, top surface at Y=2
part(AL, "CentralIsland", Vector3.new(80, 4, 80), Vector3.new(0, 0, 0))

-- Lobby spawn: sits on island surface (bottom = Y=2)
local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 2.5, 30) -- south side of central island
spawn.Anchored = true
spawn.TeamColor = BrickColor.new("White")
spawn.Neutral = true
spawn.Parent = AL

-- Generator placeholder: yellow neon box on center of island
local gen = part(
	AL,
	"GeneratorVisual",
	Vector3.new(6, 8, 6),
	Vector3.new(0, 6, 0),
	"Bright yellow",
	Enum.Material.Neon
)
gen:SetAttribute("ObjectiveId", "Generator")
CS:AddTag(gen, "Generator")

-- Extraction zone: green transparent pad, north side
local ext = part(
	AL,
	"ExtractionZone",
	Vector3.new(20, 1, 20),
	Vector3.new(0, 2.5, -30),
	"Lime green",
	Enum.Material.Neon,
	0.5,
	true
)
ext:SetAttribute("ObjectiveId", "Extraction")

-- Empty model for future props
local outpost = Instance.new("Model", AL)
outpost.Name = "CentralOutpost"

-- Bridges: Size.Y=2, Position.Y=1 => top surface at Y=2 (level with islands)
-- Central east edge: X=40,  Zone A west edge: X=225 => gap=185, center X=132.5
-- Central north edge: Z=-40, Zone B south edge: Z=-225 => gap=185, center Z=-132.5
-- Central west edge: X=-40, Zone C east edge: X=-225 => gap=185, center X=-132.5
local br = Instance.new("Folder", AL)
br.Name = "Bridges"
part(br, "Bridge_A", Vector3.new(185, 2, 10), Vector3.new(132.5, 1, 0))
part(br, "Bridge_B", Vector3.new(10, 2, 185), Vector3.new(0, 1, -132.5))
part(br, "Bridge_C", Vector3.new(185, 2, 10), Vector3.new(-132.5, 1, 0))

-- =============
-- Remote zones
-- =============
local Zones = Instance.new("Folder", Map)
Zones.Name = "Zones"

local zoneData = {
	{ id = "A", obj = "Relay_A", pos = Vector3.new(250, 0, 0), color = "Bright red" },
	{ id = "B", obj = "Relay_B", pos = Vector3.new(0, 0, -250), color = "Bright blue" },
	{ id = "C", obj = "Relay_C", pos = Vector3.new(-250, 0, 0), color = "Bright orange" },
}

for _, z in ipairs(zoneData) do
	local folder = Instance.new("Folder", Zones)
	folder.Name = "Zone_" .. z.id
	folder:SetAttribute("ZoneId", z.id)
	folder:SetAttribute("ObjectiveId", z.obj)

	-- Zone island: 50x4x50, top surface at Y=2
	part(folder, "Island", Vector3.new(50, 4, 50), z.pos)

	-- Relay beacon: colored neon pillar
	local beacon = part(
		folder,
		"RelayBeaconVisual",
		Vector3.new(4, 8, 4),
		z.pos + Vector3.new(0, 6, 0),
		z.color,
		Enum.Material.Neon
	)
	beacon:SetAttribute("ZoneId", z.id)
	beacon:SetAttribute("ObjectiveId", z.obj)
	CS:AddTag(beacon, "RelayBeacon")

	-- Enemy spawn markers: at island edges, semi-transparent, no collision
	local markerFolder = Instance.new("Folder", folder)
	markerFolder.Name = "EnemySpawnMarkers"

	local offsets = {
		Vector3.new(-22, 2.5, 0), -- west edge
		Vector3.new(22, 2.5, 0), -- east edge
		Vector3.new(0, 2.5, -22), -- north edge
	}
	for i, off in ipairs(offsets) do
		local m = part(
			markerFolder,
			"SpawnMarker_" .. i,
			Vector3.new(4, 1, 4),
			z.pos + off,
			"Bright red",
			Enum.Material.SmoothPlastic,
			0.6,
			true
		)
		m:SetAttribute("ZoneId", z.id)
		m:SetAttribute("SpawnGroupId", "Zone_" .. z.id)
		CS:AddTag(m, "EnemySpawn")
	end
end

-- Summary
print(
	string.format(
		"[MapSetup] Done. Generator: %d | RelayBeacons: %d | SpawnMarkers: %d",
		#CS:GetTagged("Generator"),
		#CS:GetTagged("RelayBeacon"),
		#CS:GetTagged("EnemySpawn")
	)
)
