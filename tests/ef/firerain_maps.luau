-- Empires Front (2026-11-08): every fire of a rain of fire arrows falls inside the map, on land, on the
-- nation it was aimed at (a map's edge, the sea and another's land are never hit); on any map.
-- Run: .bin/lune run tests/ef/firerain_maps.luau  (Rome; Studio runs every map the same way)
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local Era = require("../../src/shared/Core/Era")

local fails = 0
local function expect(c, w)
	print((if c then "  ok   " else "FAIL ") .. w)
	if not c then fails += 1 end
end

local function check(mapid: string, seed: number)
	Era.set(mapid)
	local sim = Sim.new(WorldMap.get(mapid), { seed = seed, difficulty = 2, tribes = 40, max_humans = 0 })
	for _ = 1, 1500 do sim:step() end
	local A, best = 0, 0
	for o = 1, sim.owner_total do
		if sim.o_alive[o] == 1 and sim.o_kind[o] == Defs.KIND_NATION and sim.o_tiles[o] > best then A, best = o, sim.o_tiles[o] end
	end
	local from = sim.o_spawn_tile[A]
	sim.firerain = {}
	sim:_firerain_land({ owner = A, from_tile = from, uid = 1 } :: any)
	local n, bad_edge, bad_sea, bad_owner = #sim.firerain, 0, 0, 0
	local victims = {}
	for _, f in sim.firerain do
		victims[f.victim] = true
		if f.tile < 0 or f.tile >= sim.N then
			bad_edge += 1
		elseif buffer.readu8(sim.land, f.tile) ~= 1 then
			bad_sea += 1
		elseif buffer.readi32(sim.owner, f.tile * 4) ~= f.victim then
			bad_owner += 1
		end
	end
	local nv = 0
	for _ in victims do nv += 1 end
	expect(n > 0, string.format("%s: %d fires on %d nations", mapid, n, nv))
	expect(bad_edge == 0 and bad_sea == 0 and bad_owner == 0,
		string.format("%s: all inside the map (%d out), on land (%d at sea), on the target (%d elsewhere)", mapid, bad_edge, bad_sea, bad_owner))
end

for _, seed in { 3, 7, 11 } do
	check("rome", seed)
end
print(if fails == 0 then "all ok" else fails .. " FAILED")
