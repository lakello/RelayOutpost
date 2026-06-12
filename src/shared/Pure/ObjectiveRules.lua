-- Pure relay objective logic. No Roblox services.

local ObjectiveRules = {}

-- Can a relay with this state be activated by a player interaction?
function ObjectiveRules.canActivate(objectiveState: string): boolean
	return objectiveState == "Active"
end

-- Advance relay capture progress over a time step.
-- contributorCount: players currently holding the interact button.
-- Returns (newProgress, isCompleted).
-- Progress rate: 1.0/s base, +0.5/s per additional contributor.
function ObjectiveRules.advanceProgress(
	current: number,
	required: number,
	contributorCount: number,
	dt: number
): (number, boolean)
	if contributorCount < 1 then
		return current, false
	end
	local rate = 1 + (contributorCount - 1) * 0.5
	local newProgress = math.min(required, current + rate * dt)
	return newProgress, newProgress >= required
end

-- Have all relays reached the Completed state?
-- Returns false for an empty table (no relays registered yet).
function ObjectiveRules.allRelaysCompleted(relayStates: { [string]: string }): boolean
	if next(relayStates) == nil then
		return false
	end
	for _, state in pairs(relayStates) do
		if state ~= "Completed" then
			return false
		end
	end
	return true
end

return ObjectiveRules
