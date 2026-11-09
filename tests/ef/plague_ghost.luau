-- Empires Front (2026-11-09): the plague's free nation, conquered while the plague still tears land
-- away, must not become a ghost (out of the match yet holding land: no one could attack it and it
-- raised no troops). The plague stops for it, and any such ghost comes back as an AI nation.
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
local function ghosts(sim)
	local n = 0
	for id = 1, sim.owner_total do
		if sim.o_alive[id] == 0 and sim.o_tiles[id] > 0 then n += 1 end
	end
	return n
end
Era.set("rome")
local sim = Sim.new(WorldMap.get("rome"), { seed = 9, difficulty = 2, tribes = 40, max_humans = 0 })
for _ = 1, 1200 do sim:step() end
-- the two biggest nations: the victim and its conqueror
local order = {}
for o = 1, sim.owner_total do
	if sim.o_alive[o] == 1 and sim.o_kind[o] == Defs.KIND_NATION then table.insert(order, o) end
end
table.sort(order, function(a, b) return sim.o_tiles[a] > sim.o_tiles[b] end)
local victim, other = order[1], order[2]
local t0 = sim.o_spawn_tile[victim]
-- the plague's land breaking away (_plague_land's blight)
local before = #sim.blights
sim:_blight_start(victim, t0, other)
expect(#sim.blights == before + 1, "the plague starts tearing " .. sim.o_name[victim] .. "'s land away")
-- a few steps: the free nation rises
local rid = 0
for _ = 1, 40 do
	sim:step()
	local b = sim.blights[#sim.blights]
	if b ~= nil and b.rid > 0 then rid = b.rid break end
end
expect(rid > 0, "a free nation rose: " .. (sim.o_name[rid] or "?"))
-- it is conquered whole while the plague goes on
for t = 0, sim.N - 1 do
	if buffer.readi32(sim.owner, t * 4) == rid then sim:conquer(t, other, nil) end
end
for _ = 1, 10 do sim:step() end
expect(sim.o_alive[rid] == 0, "conquered: out of the match")
-- the plague goes on for a while: it must not hand it land again
for _ = 1, 600 do sim:step() end
expect(sim.o_tiles[rid] == 0, "the fallen free nation gets no more land (" .. sim.o_tiles[rid] .. " tiles)")
expect(ghosts(sim) == 0, "no ghosts")
-- the safety net: a ghost made by hand comes back as an AI nation within a second
local g = rid
for t = 0, sim.N - 1, 997 do
	if buffer.readi32(sim.owner, t * 4) == other then sim:set_owner(t, g) end
end
expect(sim.o_alive[g] == 0 and sim.o_tiles[g] > 0, "a ghost made by hand")
for _ = 1, 12 do sim:step() end
expect(sim.o_alive[g] == 1 and sim.o_troops[g] > 0, "it came back: alive, with an army")
local ok = sim:intent_attack_troops(other, (function()
	for t = 0, sim.N - 1 do
		if buffer.readi32(sim.owner, t * 4) == g then return t end
	end
	return -1
end)(), 1000)
expect(ghosts(sim) == 0, "no ghosts left")
print(if fails == 0 then "all ok" else fails .. " FAILED")
