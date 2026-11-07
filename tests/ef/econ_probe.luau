-- Empires Front: where the gold comes from and where it goes in an AI match (a probe, not a test).
-- usage: luau tests/ef/econ_probe.luau [map] [minutes] [seed]
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
WorldMap.put_data("greece", require("./greece_raw"))
WorldMap.put_data("japan", require("./japan_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local args = { ... }
local mapid = args[1] or "rome"
local minutes = tonumber(args[2]) or 15
local sim = Sim.new(WorldMap.get(mapid), { seed = tonumber(args[3]) or 3, difficulty = 1, tribes = 60, max_humans = 0 })

local acc = { passive = 0, trade = 0, bonus = 0, conquest = 0, spent = 0, builds = {} }
local per = {} -- trade + bonus gold by owner this minute
local function add_per(id, g) per[id] = (per[id] or 0) + g end
local function nation(id)
	return sim.o_kind[id] ~= Defs.KIND_TRIBE
end
local tg = sim._trade_gold
sim._trade_gold = function(self, id, g)
	if nation(id) and g > 0 then acc.trade += g; add_per(id, g) end
	return tg(self, id, g)
end
local ab = sim.add_bonus_gold
sim.add_bonus_gold = function(self, id, amount, tile)
	-- (what really reached the treasury: big traders are paid less since 2026-11-07, Rules.trade_mult)
	local before = self.o_gold[id]
	local r = ab(self, id, amount, tile)
	local got = self.o_gold[id] - before
	if nation(id) and got > 0 then acc.bonus += got; add_per(id, got) end
	return r
end
local cg = sim._conquest_gold
sim._conquest_gold = function(self, victim, by)
	local before = self.o_gold[by]
	cg(self, victim, by)
	if nation(by) then acc.conquest += self.o_gold[by] - before end
end
local tb = sim.try_build
sim.try_build = function(self, id, kname, tile)
	local before = self.o_gold[id]
	local ok, up = tb(self, id, kname, tile)
	if ok and nation(id) then
		local spent = before - self.o_gold[id]
		acc.spent += spent
		local key = tostring(kname) .. (if up then "+" else "")
		acc.builds[key] = (acc.builds[key] or 0) + 1
	end
	return ok, up
end
local function fmt(v) return string.format("%.1fM", v / 1e6) end
print(string.format("%s: %d nations", mapid, sim.nation_count))
print("min | earned: passive trade(ore) bonus(ships/trains) conquest | spent | nations: avg gold held, max gold, avg ore | ore price | top trader's share")
for m = 1, minutes do
	for _ = 1, 600 do
		sim:step()
		for id = 1, sim.owner_total do
			if sim.o_alive[id] == 1 and sim.o_spawned[id] == 1 and nation(id) and sim.phase == Defs.PHASE_PLAYING then
				acc.passive += sim.o_income[id] / 10
			end
		end
	end
	local n, gold, maxg, ore = 0, 0, 0, 0
	for id = 1, sim.owner_total do
		if sim.o_alive[id] == 1 and nation(id) then
			n += 1
			gold += sim.o_gold[id]
			maxg = math.max(maxg, sim.o_gold[id])
			ore += sim.o_ore[id]
		end
	end
	local tot, top = 0, 0
	for _, g in per do tot += g; top = math.max(top, g) end
	per = {}
	print(string.format("%2d | %s %s %s %s | %s | %d alive: %s, %s, %.0f | %.0f | %.0f%%", m, fmt(acc.passive), fmt(acc.trade), fmt(acc.bonus), fmt(acc.conquest), fmt(acc.spent), n, fmt(gold / math.max(n, 1)), fmt(maxg), ore / math.max(n, 1), sim.ore_price, 100 * top / math.max(tot, 1)))
	acc.passive, acc.trade, acc.bonus, acc.conquest, acc.spent = 0, 0, 0, 0, 0
	if sim.winner ~= 0 then
		print("winner", sim.o_name[sim.winner], "at minute", m)
		break
	end
end
local keys = {}
for k, v in acc.builds do table.insert(keys, k .. "=" .. v) end
table.sort(keys)
print("builds:", table.concat(keys, " "))
-- structures standing, by kind (all nations)
local st = {}
for _, s in sim.struct_list do
	if not s.dead and nation(s.owner) then
		local k = Defs.STRUCT_NAMES[s.kind]
		st[k] = (st[k] or 0) + s.level
	end
end
local ks = {}
for k, v in st do table.insert(ks, k .. "=" .. v) end
table.sort(ks)
print("levels standing:", table.concat(ks, " "))
-- the three richest survivors' holdings
local alive = {}
for id = 1, sim.owner_total do
	if sim.o_alive[id] == 1 and nation(id) then table.insert(alive, id) end
end
table.sort(alive, function(a, b) return sim.o_tiles[a] > sim.o_tiles[b] end)
for i = 1, math.min(3, #alive) do
	local id = alive[i]
	local row = {}
	for k = 0, Defs.STRUCT_KIND_COUNT - 1 do
		local lv = sim:struct_levels(id, k)
		if lv > 0 then table.insert(row, Defs.STRUCT_NAMES[k] .. "=" .. sim:struct_count(id, k) .. "/" .. lv) end
	end
	print(string.format("#%d %s gold %s ships %d: %s", i, sim.o_name[id], fmt(sim.o_gold[id]), sim.o_warships[id], table.concat(row, " ")))
end
