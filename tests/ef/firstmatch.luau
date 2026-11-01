-- Empires Front: how long the first match (tutorial) takes on Ancient Greece with few nations.
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("greece", require("./greece_raw"))
WorldMap.put_data("japan", require("./japan_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local args = { ... }
local mapid = args[1] or "greece"
local nations = tonumber(args[2]) or 8
local tribes = tonumber(args[3]) or 25
for seed = 1, 3 do
	local sim = Sim.new(WorldMap.get(mapid), { seed = seed, difficulty = 0, tribes = tribes, max_humans = 0, nation_limit = nations, win_share = tonumber(args[4]) })
	local marks = {}
	for i = 1, 12000 do
		sim:step()
		if i % 600 == 0 then
			local best = 0
			for id = 1, sim.owner_total do
				if sim.o_alive[id] == 1 then best = math.max(best, sim.o_tiles[id]) end
			end
			table.insert(marks, string.format("%d%%", math.floor(100 * best / sim.map.contestable_count)))
		end
		if sim.winner ~= 0 then break end
	end
	print(mapid, "seed", seed, "minutes", string.format("%.1f", sim.tick / 600), "winner", sim.winner, table.concat(marks, " "))
end
