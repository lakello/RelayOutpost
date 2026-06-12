-- Centralised tracker for CollectionService-tagged game objects on the client.
-- Controllers and the debug overlay query this instead of calling GetTagged()
-- directly, so streaming events are handled in one place.
--
-- Tracked tags: RelayBeacon, Generator, EnemySpawn
-- Each tag is monitored with GetInstanceAddedSignal + GetInstanceRemovedSignal.
-- Instances that were already loaded before init() are registered immediately.
--
-- Designed to never reference distant Workspace paths — relies entirely on tags
-- and instance attributes (ObjectiveId, ZoneId, SpawnGroupId).

local CollectionService = game:GetService("CollectionService")

local StreamingAwarenessController = {}

-- ── Internal state ────────────────────────────────────────────────────────

-- tag → { [Instance]: true }
local _loaded: { [string]: { [Instance]: true } } = {}

-- Callbacks fired when a tagged instance streams in/out.
-- Each entry: { tag, fn(instance) }
type TagCallback = (instance: Instance) -> ()
local _addedCallbacks: { { tag: string, fn: TagCallback } } = {}
local _removedCallbacks: { { tag: string, fn: TagCallback } } = {}

local TRACKED_TAGS = { "RelayBeacon", "Generator", "EnemySpawn" }

-- ── Helpers ───────────────────────────────────────────────────────────────

local function fireCallbacks(list: { { tag: string, fn: TagCallback } }, tag: string, inst: Instance)
	for _, entry in ipairs(list) do
		if entry.tag == tag then
			entry.fn(inst)
		end
	end
end

local function trackTag(tag: string)
	_loaded[tag] = {}

	-- Connect signals BEFORE the initial scan to avoid missing instances that
	-- arrive between GetTagged() and signal connection.
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst: Instance)
		-- Guard against double-counting if the deferred scan also picks this up.
		if _loaded[tag][inst] then
			return
		end
		_loaded[tag][inst] = true
		print(string.format("[Streaming] IN  %-22s [%s]", inst.Name, tag))
		fireCallbacks(_addedCallbacks, tag, inst)
	end)

	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst: Instance)
		if _loaded[tag] then
			_loaded[tag][inst] = nil
		end
		print(string.format("[Streaming] OUT %-22s [%s]", inst.Name, tag))
		fireCallbacks(_removedCallbacks, tag, inst)
	end)
end

-- ── Public API ────────────────────────────────────────────────────────────

-- Number of currently loaded instances with the given tag.
function StreamingAwarenessController.getCount(tag: string): number
	local set = _loaded[tag]
	if not set then
		return 0
	end
	local n = 0
	for _ in pairs(set) do
		n += 1
	end
	return n
end

-- Returns an array snapshot of all currently loaded instances for a tag.
function StreamingAwarenessController.getAll(tag: string): { Instance }
	local set = _loaded[tag]
	if not set then
		return {}
	end
	local result: { Instance } = {}
	for inst in pairs(set) do
		table.insert(result, inst)
	end
	return result
end

-- Returns the first loaded RelayBeacon whose ObjectiveId attribute matches.
-- Returns nil if the beacon is not currently streamed in.
function StreamingAwarenessController.getBeacon(objectiveId: string): Instance?
	local set = _loaded["RelayBeacon"]
	if not set then
		return nil
	end
	for inst in pairs(set) do
		if inst:GetAttribute("ObjectiveId") == objectiveId then
			return inst
		end
	end
	return nil
end

-- Register a callback fired when an instance with `tag` streams in.
function StreamingAwarenessController.onAdded(tag: string, fn: TagCallback)
	table.insert(_addedCallbacks, { tag = tag, fn = fn })
end

-- Register a callback fired when an instance with `tag` streams out.
function StreamingAwarenessController.onRemoved(tag: string, fn: TagCallback)
	table.insert(_removedCallbacks, { tag = tag, fn = fn })
end

-- ── Init ─────────────────────────────────────────────────────────────────

function StreamingAwarenessController.init()
	for _, tag in ipairs(TRACKED_TAGS) do
		trackTag(tag)
	end
	print("[StreamingAwareness] Initialized. Tracking: " .. table.concat(TRACKED_TAGS, ", "))

	-- Deferred scan: runs after the current frame, by which point already-replicated
	-- instances are present in CollectionService (avoids timing gap on client startup).
	task.defer(function()
		for _, tag in ipairs(TRACKED_TAGS) do
			for _, inst in CollectionService:GetTagged(tag) do
				if _loaded[tag][inst] then
					continue -- already registered via AddedSignal
				end
				_loaded[tag][inst] = true
				local attrs = string.format(
					"ObjectiveId=%-10s ZoneId=%s",
					tostring(inst:GetAttribute("ObjectiveId")),
					tostring(inst:GetAttribute("ZoneId"))
				)
				print(string.format("[Streaming] Found at init: %-22s [%s] %s", inst.Name, tag, attrs))
			end
		end
	end)
end

return StreamingAwarenessController
