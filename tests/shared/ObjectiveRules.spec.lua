return function()
	local ObjectiveRules = require(game:GetService("ReplicatedStorage").Shared.Pure.ObjectiveRules)

	describe("canActivate", function()
		it("allows activation when Active", function()
			expect(ObjectiveRules.canActivate("Active")).to.equal(true)
		end)

		it("blocks activation when Locked", function()
			expect(ObjectiveRules.canActivate("Locked")).to.equal(false)
		end)

		it("blocks re-activation when Completed", function()
			expect(ObjectiveRules.canActivate("Completed")).to.equal(false)
		end)
	end)

	describe("advanceProgress", function()
		it("advances by 1.0/s with one contributor", function()
			local newProgress, done = ObjectiveRules.advanceProgress(0, 5, 1, 1)
			expect(newProgress).to.equal(1)
			expect(done).to.equal(false)
		end)

		it("two contributors are faster than one", function()
			local solo, _ = ObjectiveRules.advanceProgress(0, 10, 1, 1)
			local duo, _ = ObjectiveRules.advanceProgress(0, 10, 2, 1)
			expect(duo > solo).to.equal(true)
		end)

		it("does not overshoot required amount", function()
			local newProgress, done = ObjectiveRules.advanceProgress(4.9, 5, 1, 10)
			expect(newProgress).to.equal(5)
			expect(done).to.equal(true)
		end)

		it("returns completed=true exactly at required", function()
			local done = ObjectiveRules.advanceProgress(0, 1, 1, 1)
			expect(done).to.equal(true)
		end)

		it("no progress with zero contributors", function()
			local newProgress, done = ObjectiveRules.advanceProgress(2, 5, 0, 1)
			expect(newProgress).to.equal(2)
			expect(done).to.equal(false)
		end)
	end)

	describe("allRelaysCompleted", function()
		it("returns true when all relays are Completed", function()
			local states = { Relay_A = "Completed", Relay_B = "Completed", Relay_C = "Completed" }
			expect(ObjectiveRules.allRelaysCompleted(states)).to.equal(true)
		end)

		it("returns false when any relay is Active", function()
			local states = { Relay_A = "Completed", Relay_B = "Active", Relay_C = "Locked" }
			expect(ObjectiveRules.allRelaysCompleted(states)).to.equal(false)
		end)

		it("returns false when any relay is Locked", function()
			local states = { Relay_A = "Completed", Relay_B = "Completed", Relay_C = "Locked" }
			expect(ObjectiveRules.allRelaysCompleted(states)).to.equal(false)
		end)

		it("returns false for empty table (no relays registered)", function()
			expect(ObjectiveRules.allRelaysCompleted({})).to.equal(false)
		end)
	end)
end
