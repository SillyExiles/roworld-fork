-- Empires Front (2026-11-01, balance): per-player building caps, the economy buildings' rising
-- costs, city troops past 15 levels, warships afloat.
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local Rules = require("../../src/shared/Core/Rules")
local fails = 0
local function expect(c, w)
	print((if c then "  ok   " else "FAIL ") .. w)
	if not c then fails += 1 end
end

-- pure rules
expect(Rules.build_cost("city", 3) == 1000000, "4th city 1M")
expect(Rules.build_cost("city", 4) == 1250000 and Rules.build_cost("port", 7) == 2000000, "past the 4th: +250k each")
expect(Rules.build_cost("factory", 40) == 4000000, "capped at 4M")
expect(Rules.city_troops(15) == 15 * Rules.CITY_TROOPS, "15 city levels at full")
expect(Rules.city_troops(25) == 20 * Rules.CITY_TROOPS, "10 more at half")
expect(not Rules.under_limit(Defs.S_MARKET, 3, 3, false) and Rules.under_limit(Defs.S_MARKET, 3, 3, true), "4th market no, upgrade yes")
expect(not Rules.under_limit(Defs.S_MARKET, 3, 6, true), "7th market level no")
expect(Rules.under_limit(Defs.S_CITY, 99, 99, false), "cities unlimited")
expect(string.find(Rules.limit_text("market"), "3", 1, true) ~= nil, Rules.limit_text("market"))

-- in a match
local sim = Sim.new(WorldMap.get("rome"), { seed = 21, difficulty = 1, tribes = 60, max_humans = 0 })
for _ = 1, 2000 do sim:step() end
local id, bt = 0, 0
for o = 1, sim.owner_total do
	if sim.o_alive[o] == 1 and sim.o_kind[o] == Defs.KIND_NATION and sim.o_tiles[o] > bt then id, bt = o, sim.o_tiles[o] end
end
sim.o_ai[id] = 0
local own = {}
for t = 0, sim.N - 1 do
	if buffer.readi32(sim.owner, t * 4) == id then table.insert(own, t) end
end
local function build_all(kind, max)
	sim.o_gold[id] += 1e9
	local n = 0
	for i = 1, #own, math.max(1, #own // 600) do
		local t = own[i]
		if sim:valid_site(id, kind, t) then
			local before = sim:struct_count(id, kind)
			sim:try_build(id, Defs.STRUCT_NAMES[kind], t)
			if sim:struct_count(id, kind) > before then
				n += 1
				if n >= max then break end
			end
		end
	end
	return n
end
build_all(Defs.S_MINE, 20)
expect(sim:struct_count(id, Defs.S_MINE) <= 8 and sim:struct_count(id, Defs.S_MINE) >= 1, "mines at most 8: " .. sim:struct_count(id, Defs.S_MINE))
for _ = 1, 300 do sim:step() end
local mine = nil
for _, s in sim:structs_of(id, Defs.S_MINE) do mine = s end
local m0 = sim.msg
local said = ""
sim.msg = function(self, o, k, text) if o == id then said = text end return m0(self, o, k, text) end
for _ = 1, 14 do sim.o_gold[id] += 1e8; sim:try_build(id, "mine", mine.tile) end
sim.msg = m0
print("    last message:", said)
expect(sim:struct_levels(id, Defs.S_MINE) == 16, "mine levels stop at 16: " .. sim:struct_levels(id, Defs.S_MINE))
build_all(Defs.S_MARKET, 10)
expect(sim:struct_count(id, Defs.S_MARKET) == 3, "markets stop at 3: " .. sim:struct_count(id, Defs.S_MARKET))
build_all(Defs.S_FARM, 10)
expect(sim:struct_count(id, Defs.S_FARM) == 6, "farms stop at 6: " .. sim:struct_count(id, Defs.S_FARM))
local cities = build_all(Defs.S_CITY, 12)
expect(cities >= 8, "cities still build freely: " .. cities)
-- Temple, Palace, Fortress, University: no upgrades, so the caps hold
for _, k in { Defs.S_TEMPLE, Defs.S_PALACE, Defs.S_FORTRESS, Defs.S_UNIVERSITY } do
	expect(not Rules.is_upgradable(k), Defs.STRUCT_NAMES[k] .. " is not upgradable")
	build_all(k, 10)
	local n, lv = sim:struct_count(id, k), sim:struct_levels(id, k)
	for _, st in sim:structs_of(id, k) do
		sim.o_gold[id] += 1e8
		sim:try_build(id, Defs.STRUCT_NAMES[k], st.tile)
	end
	expect(n <= Rules.struct_limit(k) and sim:struct_levels(id, k) == lv and lv == n,
		string.format("%s: %d built, %d levels after trying to upgrade", Defs.STRUCT_NAMES[k], n, sim:struct_levels(id, k)))
end
-- Ports and Factories price by their own count (no longer a shared one)
expect(sim:cost_count(id, Defs.S_FACTORY) == sim:struct_levels(id, Defs.S_FACTORY), "a factory's price ignores ports")
-- a long AI run keeps to the caps
for _ = 1, 6000 do sim:step() end
local worst = {}
for o = 1, sim.owner_total do
	if sim.o_alive[o] == 1 then
		for k, lim in Rules.STRUCT_LIMITS do
			if sim:struct_count(o, k) > lim then worst[Defs.STRUCT_NAMES[k]] = sim:struct_count(o, k) end
		end
		for k, lim in Rules.LEVEL_LIMITS do
			if sim:struct_levels(o, k) > lim then worst[Defs.STRUCT_NAMES[k] .. " levels"] = sim:struct_levels(o, k) end
		end
	end
end
local w = {}
for k, v in worst do table.insert(w, k .. "=" .. v) end
expect(#w == 0, "no player over a cap after 10 min of AI play " .. table.concat(w, " "))
print(if fails == 0 then "all ok" else fails .. " FAILED")
