-- Empires Front headless smoke test (plain `luau` CLI): an AI-only match on the Roman map.
-- usage: luau tests/ef/smoke.luau  (tests/ef/rome_raw.luau: the map with raw terrain, made by hand)
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local Eras = require("../../src/shared/Data/Eras")
local Rules = require("../../src/shared/Core/Rules")
local map = WorldMap.get("rome")
print("map", map.W, map.H, "sites", #map.sites, "era", map.era)
local sim = Sim.new(map, { seed = 3, difficulty = 2, tribes = 60, max_humans = 0 })
print("era active", Eras.active, "atom outer", Rules.NUKE_OUTER_FULL[Defs.N_ATOM], "warship hp", Rules.warship_max_hp(0))
local ticks = 4000
local t0 = os.clock()
for i = 1, ticks do
	sim:step()
	if i % 1000 == 0 then
		local counts = {}
		for _, s in sim.struct_list do
			if not s.dead then
				counts[s.kind] = (counts[s.kind] or 0) + s.level
			end
		end
		local food, ore, starving, pacts = 0, 0, 0, 0
		for id = 1, sim.owner_total do
			if sim.o_alive[id] == 1 and sim.o_kind[id] == Defs.KIND_NATION then
				food += sim.o_food[id]
				ore += sim.o_ore[id]
				if sim.o_fed[id] < 1 then
					starving += 1
				end
			end
		end
		for _ in sim.pacts do
			pacts += 1
		end
		local parts = {}
		for k = 0, Defs.STRUCT_KIND_COUNT - 1 do
			if counts[k] then
				table.insert(parts, Defs.STRUCT_NAMES[k] .. "=" .. counts[k])
			end
		end
		print(("tick %d phase %d  %s  ore %d price %d pacts %d  (%.1f ms/tick)"):format(
			sim.tick, sim.phase, table.concat(parts, " "), ore, sim.ore_price, pacts, (os.clock() - t0) * 1000 / i))
		local h, tm = sim:objective_holder()
		if h ~= 0 then
			print("objective holder", sim.o_name[h])
		end
	end
end
print("winner", sim.winner, sim.over_reason)
