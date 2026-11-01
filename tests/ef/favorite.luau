--!nocheck
-- Empires Front: the title's support card pays Purchases.FAVORITE_STARS once per account.
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local Purchases = require("../../src/server/Purchases")
local fails = 0
local function expect(c, w)
	print((if c then "  ok   " else "FAIL ") .. w)
	if not c then fails += 1 end
end
local rows = {}
local store = {}
function store:UpdateAsync(k, fn)
	local new = fn(rows[k])
	if new ~= nil then rows[k] = new end
	return new
end
function store:GetAsync(k) return rows[k] end
local P = { UserId = 7, Name = "Fan" }
Purchases.configure({
	datastore = store,
	players = { GetPlayerByUserId = function(_, id) return if id == 7 then P else nil end },
	notify = function() end,
	bought = function() end,
})
Purchases.load(P)
expect(Purchases.inventory(P).fav_paid == false, "not paid yet")
local before = Purchases.stars(P)
expect(Purchases.favorite_bonus(P) == true, "first favorite pays")
expect(Purchases.stars(P) == before + Purchases.FAVORITE_STARS, "+1000 Stars")
expect(Purchases.inventory(P).fav_paid == true, "inventory says paid")
expect(Purchases.favorite_bonus(P) == false, "second claim pays nothing")
expect(Purchases.stars(P) == before + Purchases.FAVORITE_STARS, "still +1000 only")
Purchases.release(P)
Purchases.load(P)
expect(Purchases.inventory(P).fav_paid == true, "kept in the store")
print(if fails == 0 then "all ok" else (fails .. " failed"))
