-- Empires Front v10: AI matches on the new maps (Ancient Greece, Sengoku Japan). usage: luau tests/ef/newmaps.luau
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("greece", require("./greece_raw"))
WorldMap.put_data("japan", require("./japan_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Eras = require("../../src/shared/Data/Eras")
local Defs = require("../../src/shared/Core/Defs")
for _, id in { "greece", "japan" } do
	local map = WorldMap.get(id)
	local sim = Sim.new(map, { seed = 5, difficulty = 2, tribes = 40, max_humans = 0 })
	local t0 = os.clock()
	for i = 1, 6000 do
		sim:step()
		if sim.winner ~= 0 then
			break
		end
	end
	local alive = 0
	for o = 1, sim.owner_total do
		if sim.o_alive[o] == 1 and sim.o_kind[o] == Defs.KIND_NATION then
			alive += 1
		end
	end
	print(id, map.W, map.H, "era", Eras.active, "tick", sim.tick, "nations alive", alive, "winner", sim.winner,
		string.format("%.1f ms/tick", (os.clock() - t0) * 1000 / sim.tick))
end
