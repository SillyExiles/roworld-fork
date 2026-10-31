-- Empires Front balance probe (plain `luau` CLI): an AI match, every minute the leaders' land, army,
-- gold income and trade, plus how the match ends. usage: luau tests/ef/balance.luau -a [ticks] [seed]
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local args = { ... }
local ticks = tonumber(args[1]) or 9000
local seed = tonumber(args[2]) or 3
local map = WorldMap.get("rome")
local sim = Sim.new(map, { seed = seed, difficulty = 2, tribes = 60, max_humans = 0 })

local last_gold = {}
local last_tiles = {}
local function land_of(id)
	return sim.o_tiles and sim.o_tiles[id] or 0
end
local t0 = os.clock()
for i = 1, ticks do
	sim:step()
	if i % 600 == 0 then
		local rows = {}
		local alive = 0
		for id = 1, sim.owner_total do
			if sim.o_alive[id] == 1 and sim.o_kind[id] == Defs.KIND_NATION then
				alive += 1
				table.insert(rows, id)
			end
		end
		table.sort(rows, function(a, b)
			return land_of(a) > land_of(b)
		end)
		local parts = {}
		for j = 1, math.min(3, #rows) do
			local id = rows[j]
			local g = sim.o_gold[id]
			local inc = (g - (last_gold[id] or g)) / 60
			table.insert(
				parts,
				string.format(
					"%s land %d troops %dk/%dk gold %dk (+%dk/s) trade %d/s ore %d",
					string.sub(sim.o_name[id], 1, 10),
					land_of(id),
					sim.o_troops[id] // 1000,
					sim.o_cap[id] // 1000,
					g // 1000,
					inc // 1000,
					sim.o_trade_gold[id] or 0,
					sim.o_ore[id] or 0
				)
			)
		end
		local flips = 0
		for id = 1, sim.owner_total do
			last_gold[id] = sim.o_gold[id]
			flips += math.abs(land_of(id) - (last_tiles[id] or 0))
			last_tiles[id] = land_of(id)
		end
		print(string.format("min %2d  nations %d  land moved/min %d", i // 600, alive, flips // 2))
		for _, p in parts do
			print("   " .. p)
		end
		if sim.winner ~= 0 then
			print("WINNER", sim.o_name[sim.winner], sim.over_reason)
			break
		end
	end
end
print(string.format("%.1f ms/tick", (os.clock() - t0) * 1000 / sim.tick))
