-- Empires Front (2026-11-05): the session bonus (Data/Stars.session_*, server/Rewards).
local Stars = require("../../src/shared/Data/Stars")
local Rewards = require("../../src/server/Rewards")
local fails = 0
local function expect(c, w)
	print((if c then "  ok   " else "FAIL ") .. w)
	if not c then fails += 1 end
end
expect(Stars.session_next(0, nil) == 1, "first match of a run")
expect(Stars.session_next(1, 600) == 2, "10 min after the last: the next of the run")
expect(Stars.session_next(2, 60) == 2, "a minute after: the same match (a second life)")
expect(Stars.session_next(3, 46 * 60) == 1, "46 min after: a new run")
expect(Stars.session_bonus(1) == 0 and Stars.session_bonus(2) == 0.25 and Stars.session_bonus(3) == 0.5 and Stars.session_bonus(9) == 0.5, "0 / 25% / 50% / 50%")
expect(Stars.session_stars(1000, 0.5) == 500 and Stars.session_stars(0, 0.5) == 0 and Stars.session_stars(12, 0.25) == 5, "rounded to 5")

-- Rewards with a fake store: the run moves on, the line and payload say so
local clock = 0
local chain_n, chain_at = 0, nil
local sent = nil
Rewards.reset()
Rewards.configure({
	add_stars = function() error("the session path should be used") end,
	add_match_stars = function(_p, base)
		local n = Stars.session_next(chain_n, if chain_at then clock - chain_at else nil)
		local bonus = Stars.session_stars(base, Stars.session_bonus(n))
		chain_n, chain_at = n, clock
		return true, 0, bonus, n
	end,
	send = function(_p, payload) sent = payload end,
	now = function() return clock end,
})
local P = { UserId = 1 }
local r = { spawned = true, left = false, won = false, minutes = 10, shares = 1, kills = 1, place = 2, field = 10 }
local t1 = Rewards.pay(P, r, "public")
expect(sent.session.n == 1 and sent.session.next_pct == 0.25, "1st match: no bonus, next +25%")
clock += 12 * 60
local t2 = Rewards.pay(P, r, "public")
local has = false
for _, l in sent.lines do if l[1] == "session" then has = true end end
expect(sent.session.n == 2 and has and t2 > t1, string.format("2nd match: +25%% line (%d vs %d)", t2, t1))
clock += 12 * 60
local t3 = Rewards.pay(P, r, "public")
expect(sent.session.n == 3 and math.abs(t3 - t1 * 1.5) <= 5, string.format("3rd: +50%% (%d)", t3))
print(if fails == 0 then "all ok" else fails .. " FAILED")
