-- Pure validation for player interaction and revive requests.
-- Returns (isValid, reason). reason is nil when valid.
-- Server passes plain distance (studs); no Roblox Vector3 here.

local InteractionValidation = {}

-- Validate a relay/objective interaction request.
function InteractionValidation.canInteract(
	objectiveState: string,
	isPlayerAlive: boolean,
	isPlayerDowned: boolean,
	distance: number, -- studs, computed server-side
	maxDistance: number
): (boolean, string?)
	if not isPlayerAlive then
		return false, "player_dead"
	end
	if isPlayerDowned then
		return false, "player_downed"
	end
	if objectiveState == "Locked" then
		return false, "objective_locked"
	end
	if objectiveState == "Completed" then
		return false, "objective_completed"
	end
	if objectiveState ~= "Active" then
		return false, "objective_not_active"
	end
	if distance > maxDistance then
		return false, "too_far"
	end
	return true, nil
end

-- Validate a revive request.
-- Target: the downed player. Reviver: the player initiating the revive.
function InteractionValidation.canRevive(
	targetIsAlive: boolean,
	targetIsDowned: boolean,
	reviverIsAlive: boolean,
	reviverIsDowned: boolean,
	distance: number,
	maxDistance: number
): (boolean, string?)
	if not reviverIsAlive or reviverIsDowned then
		return false, "reviver_cannot_act"
	end
	if not targetIsAlive then
		return false, "target_dead"
	end
	if not targetIsDowned then
		return false, "target_not_downed"
	end
	if distance > maxDistance then
		return false, "too_far"
	end
	return true, nil
end

return InteractionValidation
