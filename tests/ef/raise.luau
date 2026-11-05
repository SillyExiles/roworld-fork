-- Empires Front (2026-11-05): a Defense Post on the hills rises into a Fortress.
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local fails = 0
local function expect(c, w)
	print((if c then "  ok   " else "FAIL ") .. w)
	if not c then fails += 1 end
end
local sim = Sim.new(WorldMap.get("rome"), { seed = 21, difficulty = 1, tribes = 60, max_humans = 0 })
for _ = 1, 2000 do sim:step() end
local id, bt = 0, 0
for o = 1, sim.owner_total do
	if sim.o_alive[o] == 1 and sim.o_kind[o] == Defs.KIND_NATION and sim.o_tiles[o] > bt then id, bt = o, sim.o_tiles[o] end
end
sim.o_ai[id] = 0
local hill = -1
for t = 0, sim.N - 1 do
	if buffer.readi32(sim.owner, t * 4) == id and buffer.readu8(sim.terr, t) >= Defs.T_HIGHLAND and sim:valid_site(id, Defs.S_DEFENSE, t) then
		hill = t
		break
	end
end
expect(hill >= 0, "a hill site")
sim.o_gold[id] += 1e8
local f0 = sim:struct_count(id, Defs.S_FORTRESS)
expect(sim:try_build(id, "defense", hill), "a post on the hill")
for _ = 1, 120 do sim:step() end
local posts = sim:struct_count(id, Defs.S_DEFENSE)
local ok, up = sim:try_build(id, "defense", hill)
expect(ok and up, "built on again: raised")
expect(sim:struct_count(id, Defs.S_FORTRESS) == f0 + 1 and sim:struct_count(id, Defs.S_DEFENSE) == posts - 1, "the post became a Fortress")
print(if fails == 0 then "all ok" else fails .. " FAILED")
