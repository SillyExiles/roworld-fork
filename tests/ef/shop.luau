-- Empires Front v10: the Empire Shop on the server (Purchases.buy_cosmetic, Robux grants, the banner).
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local Purchases = require("../../src/server/Purchases")
local Cosmetics = require("../../src/shared/Data/Cosmetics")
local EmpireShop = require("../../src/shared/Data/EmpireShop")
local Products = require("../../src/shared/Data/Products")
local store = {}
local ds = {
	GetAsync = function(_, k)
		return store[k]
	end,
	UpdateAsync = function(_, k, fn)
		local v = fn(store[k])
		if v ~= nil then
			store[k] = v
		end
	end,
}
local sent = {}
Purchases.configure({ datastore = ds, inventory = function(_p, inv)
	table.insert(sent, inv)
end, log = function() end })
local player = { UserId = 42, Name = "tester" }
Purchases.load(player)
print("flags", #Cosmetics.empire_items(), "robux products",
	(function()
		local n = 0
		for _, p in Products do
			if p.empire_flag then
				n += 1
			end
		end
		return n
	end)())
Purchases.add_stars(player, 5000)
print("buy italy", Purchases.buy_cosmetic(player, "ef_italy"))
print("buy italy again", Purchases.buy_cosmetic(player, "ef_italy"))
print("buy hre (6000)", Purchases.buy_cosmetic(player, "ef_hre"))
print("buy mongol w/ stars", Purchases.buy_cosmetic(player, "ef_mongol"))
print("via buy_unlock", Purchases.buy_unlock(player, "cosmetic:ef_france"))
local inv = Purchases.inventory(player)
print("stars", inv.stars, "equipped", inv.equipped.skin, "owned", table.concat(inv.owned, ","))
print("grant mongol", Purchases.grant(42, "cosmetic:ef_mongol", "r1", 1, 149))
inv = Purchases.inventory(player)
print("equipped after robux", inv.equipped.skin)
print("equipped (no banner)", Purchases.equipped(player).flag)
Purchases.set_banner(player, true)
print("equipped (banner)", Purchases.equipped(player).flag, Purchases.inventory(player).banner)
print("equip italy", Purchases.equip(player, "skin", "ef_italy"))
print("now", Purchases.inventory(player).equipped.skin)
