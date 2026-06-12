return function()
	local IV = require(game:GetService("ReplicatedStorage").Shared.Pure.InteractionValidation)

	local MAX = 10 -- max interact distance used in all tests

	describe("canInteract", function()
		it("allows a valid interaction", function()
			local ok, reason = IV.canInteract("Active", true, false, 5, MAX)
			expect(ok).to.equal(true)
			expect(reason).to.equal(nil)
		end)

		it("rejects dead player", function()
			local ok, reason = IV.canInteract("Active", false, false, 5, MAX)
			expect(ok).to.equal(false)
			expect(reason).to.equal("player_dead")
		end)

		it("rejects downed player", function()
			local ok, reason = IV.canInteract("Active", true, true, 5, MAX)
			expect(ok).to.equal(false)
			expect(reason).to.equal("player_downed")
		end)

		it("rejects Locked objective", function()
			local ok, reason = IV.canInteract("Locked", true, false, 5, MAX)
			expect(ok).to.equal(false)
			expect(reason).to.equal("objective_locked")
		end)

		it("rejects Completed objective", function()
			local ok, reason = IV.canInteract("Completed", true, false, 5, MAX)
			expect(ok).to.equal(false)
			expect(reason).to.equal("objective_completed")
		end)

		it("rejects player too far away", function()
			local ok, reason = IV.canInteract("Active", true, false, 15, MAX)
			expect(ok).to.equal(false)
			expect(reason).to.equal("too_far")
		end)

		it("allows interaction exactly at max distance", function()
			local ok, _ = IV.canInteract("Active", true, false, MAX, MAX)
			expect(ok).to.equal(true)
		end)
	end)

	describe("canRevive", function()
		it("allows a valid revive", function()
			-- target: alive+downed. reviver: alive+not downed. distance: within range.
			local ok, reason = IV.canRevive(true, true, true, false, 5, MAX)
			expect(ok).to.equal(true)
			expect(reason).to.equal(nil)
		end)

		it("rejects downed reviver", function()
			local ok, reason = IV.canRevive(true, true, true, true, 5, MAX)
			expect(ok).to.equal(false)
			expect(reason).to.equal("reviver_cannot_act")
		end)

		it("rejects dead reviver", function()
			local ok, reason = IV.canRevive(true, true, false, false, 5, MAX)
			expect(ok).to.equal(false)
			expect(reason).to.equal("reviver_cannot_act")
		end)

		it("rejects target that is not downed (already standing)", function()
			local ok, reason = IV.canRevive(true, false, true, false, 5, MAX)
			expect(ok).to.equal(false)
			expect(reason).to.equal("target_not_downed")
		end)

		it("rejects target that is fully dead", function()
			local ok, reason = IV.canRevive(false, true, true, false, 5, MAX)
			expect(ok).to.equal(false)
			expect(reason).to.equal("target_dead")
		end)

		it("rejects reviver too far from target", function()
			local ok, reason = IV.canRevive(true, true, true, false, 15, MAX)
			expect(ok).to.equal(false)
			expect(reason).to.equal("too_far")
		end)
	end)
end
