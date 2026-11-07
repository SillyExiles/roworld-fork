-- Empires Front (2026-11-07): an AI match stepped with each step guarded, the way MatchServer does,
-- and the network encoder run on every delta: prints the first errors (a step error three times in a
-- row ends a live match: "The match ran into a problem").
-- usage: luau tests/ef/stress.luau -a [map] [minutes] [seed] [difficulty]
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
WorldMap.put_data("greece", require("./greece_raw"))
WorldMap.put_data("japan", require("./japan_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Era = require("../../src/shared/Core/Era")
local Protocol = require("../../src/shared/Net/Protocol")
local GameState = require("../../src/shared/Core/GameState")
local args = { ... }
local mapid = args[1] or "rome"
local minutes = tonumber(args[2]) or 20
local seed = tonumber(args[3]) or 3
local diff = tonumber(args[4]) or 2
Era.set(mapid)
local sim = Sim.new(WorldMap.get(mapid), { seed = seed, difficulty = diff, tribes = 60, max_humans = 0 })
local gs = GameState.new()
gs:load_snapshot(Protocol.decode_snapshot(Protocol.encode_snapshot(sim:snapshot())))
local Defs = require("../../src/shared/Core/Defs")
local errs, seen = 0, {}
ghosts, ghost_seen = 0, {}
-- (a player's part: every 90 s the biggest nation fires each siege weapon at a random enemy, with the
-- gold and the workshops it needs)
local function player_fire()
	local A, best = 0, 0
	for o = 1, sim.owner_total do
		if sim.o_alive[o] == 1 and sim.o_kind[o] == Defs.KIND_NATION and sim.o_tiles[o] > best then A, best = o, sim.o_tiles[o] end
	end
	if A == 0 then return end
	sim.o_gold[A] += 200000000
	if #sim:structs_of(A, Defs.S_SILO) == 0 then
		for t = 0, sim.N - 1, 7 do
			if buffer.readi32(sim.owner, t * 4) == A and sim:valid_site(A, Defs.S_SILO, t) and sim:try_build(A, "silo", t) then break end
		end
	end
	for _, w in sim:structs_of(A, Defs.S_SILO) do w.shots = {} end
	for _, kname in { "atom", "hydrogen", "plague", "firerain" } do
		for _ = 1, 40 do
			local t = sim.rng:randi() % sim.N
			local o = buffer.readi32(sim.owner, t * 4)
			if o > 0 and o ~= A and not sim:allied(A, o) then
				if sim:launch_nuke(A, kname, t) then fired[kname] = (fired[kname] or 0) + 1 break end
			end
		end
	end
end
fired = {}
local ticks = minutes * 600
local c0 = os.clock()
for i = 1, ticks do
	local ok, err = xpcall(function()
		if sim.tick % 900 == 0 and sim.phase == 1 then player_fire() end
		local d = sim:step()
		gs:apply_delta(Protocol.decode_delta(Protocol.encode_delta(d, d.ev, sim.W)))
	end, debug.traceback)
	if not ok then
		errs += 1
		local key = string.match(tostring(err), "^[^\n]*") or "?"
		if not seen[key] then
			seen[key] = true
			print(string.format("ERROR at tick %d: %s", sim.tick, tostring(err)))
		end
		-- (resync the mirror, as the server does)
		gs = GameState.new()
		gs:load_snapshot(Protocol.decode_snapshot(Protocol.encode_snapshot(sim:snapshot())))
	end
	-- (2026-11-07) every munition the mirror still draws must still fly in the Sim
	if ok and i % 10 == 0 then
		local alive = {}
		for _, n in sim.nukes do if not n.dead then alive[n.uid] = n end end
		for uid, m in gs.nukes do
			if alive[uid] == nil and not ghost_seen[uid] then
				ghost_seen[uid] = true
				ghosts += 1
				if ghosts <= 5 then print(string.format("GHOST nuke %d kind %d at tick %d (launched %d, flight %d)", uid, m.kind or -1, sim.tick, m.launch_tick or -1, m.flight_ticks or -1)) end
			end
		end
	end
	if i % 3000 == 0 then
		local alive = 0
		for o = 1, sim.owner_total do if sim.o_alive[o] == 1 then alive += 1 end end
		print(string.format("  %d min: %d owners (%d alive), %d errors, %.0f s", i // 600, sim.owner_total, alive, errs, os.clock() - c0))
	end
	if sim.phase == 2 then print("  over at tick", sim.tick) break end
end
for k, v in fired do print("  fired", k, v) end
print("ghost munitions:", ghosts)
print(errs == 0 and "no errors" or (errs .. " errors"))
