-- Empires Front (2026-11-07) economy balance: trade pays big traders less, the small catch up, upkeep.
local Rules = require("../../src/shared/Core/Rules")
local Defs = require("../../src/shared/Core/Defs")
local fails = 0
local function expect(c, w)
	print((if c then "  ok   " else "FAIL ") .. w)
	if not c then fails += 1 end
end
local N, T = Defs.KIND_NATION, Defs.KIND_TRIBE
expect(Rules.trade_mult(0) == 1 and Rules.trade_mult(8) == 1, "a small trader: full pay")
expect(Rules.trade_mult(20) < Rules.trade_mult(10) and Rules.trade_mult(10) < 1, "less a level past the free ones")
local grows = true
for n = 1, 200 do
	grows = grows and n * Rules.trade_mult(n) > (n - 1) * Rules.trade_mult(n - 1)
end
expect(grows, "more ports and roads always earn more in all")
expect(Rules.catchup_income(N, 0.01, 0.05) == 0, "no catch-up while the leader is small")
expect(Rules.catchup_income(N, 0.01, 0.40) > 1000, "far behind a big leader: extra gold")
expect(Rules.catchup_income(N, 0.12, 0.40) == 0, "a close rival: none")
expect(Rules.catchup_income(T, 0.01, 0.40) == 0, "tribes: none")
expect(Rules.upkeep(N, 40) == 0 and Rules.upkeep(N, 50) == 300, "upkeep past 40 levels")
expect(Rules.upkeep(T, 200) == 0, "tribes pay none")
print(if fails == 0 then "all ok" else fails .. " FAILED")
