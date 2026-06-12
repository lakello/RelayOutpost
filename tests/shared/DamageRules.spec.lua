return function()
	local DamageRules = require(game:GetService("ReplicatedStorage").Shared.Pure.DamageRules)

	describe("applyDamage", function()
		it("reduces HP by damage amount", function()
			local newHp, isDead = DamageRules.applyDamage(100, 30)
			expect(newHp).to.equal(70)
			expect(isDead).to.equal(false)
		end)

		it("clamps HP to zero, not below", function()
			local newHp, isDead = DamageRules.applyDamage(10, 50)
			expect(newHp).to.equal(0)
			expect(isDead).to.equal(true)
		end)

		it("exact lethal damage sets isDead", function()
			local newHp, isDead = DamageRules.applyDamage(30, 30)
			expect(newHp).to.equal(0)
			expect(isDead).to.equal(true)
		end)

		it("zero damage leaves HP unchanged", function()
			local newHp, isDead = DamageRules.applyDamage(80, 0)
			expect(newHp).to.equal(80)
			expect(isDead).to.equal(false)
		end)
	end)

	describe("applyHeal", function()
		it("increases HP by amount", function()
			expect(DamageRules.applyHeal(50, 100, 20)).to.equal(70)
		end)

		it("clamps to maxHp", function()
			expect(DamageRules.applyHeal(90, 100, 30)).to.equal(100)
		end)

		it("heals from zero", function()
			expect(DamageRules.applyHeal(0, 100, 40)).to.equal(40)
		end)
	end)

	describe("reviveHp", function()
		it("returns floored fraction of maxHp", function()
			expect(DamageRules.reviveHp(100, 0.3)).to.equal(30)
		end)

		it("floors fractional result", function()
			-- 70 * 0.3 = 21.0 (exact)
			expect(DamageRules.reviveHp(70, 0.3)).to.equal(21)
		end)
	end)
end
