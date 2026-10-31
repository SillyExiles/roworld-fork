task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
local Sim = require("../../src/shared/Core/Sim")
local map = WorldMap.get("rome")
local sim = Sim.new(map, { seed = 3, difficulty = 1, tribes = 60, max_humans = 0 })
for _ = 1, 400 do
	sim:step()
end
for id = 1, 8 do
	if sim.o_alive[id] == 1 then
		local p, u = sim:resource_rates(id)
		print(id, sim.o_name[id], sim.o_kind[id], "troops", math.floor(sim.o_troops[id]), "cap", math.floor(sim.o_cap[id]), "prod", p, "use", u, "rate", sim.o_food_rate[id], "food", sim.o_food[id])
	end
end
