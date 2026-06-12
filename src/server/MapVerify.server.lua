-- Dev tool: verify map CollectionService tags and attributes on server start.
-- Safe to leave in during development; remove before public release.

local CollectionService = game:GetService("CollectionService")

local EXPECTED = {
	Generator = 1,
	RelayBeacon = 3,
	EnemySpawn = 9,
}

local function verify()
	print("[MapVerify] Checking map tags...")
	local allOk = true

	for tag, expected in pairs(EXPECTED) do
		local tagged = CollectionService:GetTagged(tag)
		local count = #tagged
		local pass = count == expected

		if not pass then
			allOk = false
		end

		print(
			string.format(
				"  [%s] %-12s %d/%d found",
				pass and "OK  " or "FAIL",
				tag,
				count,
				expected
			)
		)

		for _, obj in ipairs(tagged) do
			print(
				string.format(
					"       %s | ObjectiveId=%-12s ZoneId=%s SpawnGroupId=%s",
					obj.Name,
					tostring(obj:GetAttribute("ObjectiveId")),
					tostring(obj:GetAttribute("ZoneId")),
					tostring(obj:GetAttribute("SpawnGroupId"))
				)
			)
		end
	end

	if allOk then
		print("[MapVerify] All tags OK.")
	else
		warn("[MapVerify] Some tags are missing. Run MapBlockoutSetup.lua in Command Bar first.")
	end
end

task.delay(1, verify)
