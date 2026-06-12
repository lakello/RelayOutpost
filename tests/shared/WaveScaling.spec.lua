return function()
	local WaveScaling = require(game:GetService("ReplicatedStorage").Shared.Pure.WaveScaling)

	describe("getEnemyBudget", function()
		it("wave 1 solo baseline is 15", function()
			-- 10 + 1*5 + 0*2 = 15
			expect(WaveScaling.getEnemyBudget(1, 1)).to.equal(15)
		end)

		it("grows with wave number", function()
			expect(WaveScaling.getEnemyBudget(2, 1) > WaveScaling.getEnemyBudget(1, 1)).to.equal(
				true
			)
		end)

		it("grows with player count", function()
			expect(WaveScaling.getEnemyBudget(1, 2) > WaveScaling.getEnemyBudget(1, 1)).to.equal(
				true
			)
		end)

		it("each extra player adds 2 enemies", function()
			-- wave 2 solo=20, wave 2 trio=24, diff=4 (2 extra players × 2)
			local solo = WaveScaling.getEnemyBudget(2, 1)
			local trio = WaveScaling.getEnemyBudget(2, 3)
			expect(trio - solo).to.equal(4)
		end)

		it("single player does not subtract enemies", function()
			-- playerCount=1 -> math.max(0,0)*2 = 0 bonus, budget is still positive
			expect(WaveScaling.getEnemyBudget(1, 1) > 0).to.equal(true)
		end)
	end)

	describe("getStatMultiplier", function()
		it("wave 1 multiplier is exactly 1.0", function()
			expect(WaveScaling.getStatMultiplier(1)).to.equal(1.0)
		end)

		it("wave 2 multiplier is 1.15", function()
			local m = WaveScaling.getStatMultiplier(2)
			expect(math.abs(m - 1.15) < 0.0001).to.equal(true)
		end)

		it("multiplier grows with each wave", function()
			expect(WaveScaling.getStatMultiplier(3) > WaveScaling.getStatMultiplier(2)).to.equal(
				true
			)
		end)
	end)

	describe("isFinalWave", function()
		it("wave 4 is final when totalWaves=3", function()
			expect(WaveScaling.isFinalWave(4, 3)).to.equal(true)
		end)

		it("wave 3 is not final when totalWaves=3", function()
			expect(WaveScaling.isFinalWave(3, 3)).to.equal(false)
		end)

		it("wave 1 is not final for any standard config", function()
			expect(WaveScaling.isFinalWave(1, 3)).to.equal(false)
		end)
	end)
end
