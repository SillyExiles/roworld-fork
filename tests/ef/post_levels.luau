-- Empires Front (2026-11-07): a Defense Post levels up to 5, each level guarding a little more land.
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
local R = sim.R
expect(R.defense_range(1) < R.defense_range(2) and R.defense_range(5) == R.defense_range(9), "wider a level, up to level 5")
-- a site on the plains (an upgrade there, not a Fortress)
local flat = -1
for t = 0, sim.N - 1 do
	if buffer.readi32(sim.owner, t * 4) == id and buffer.readu8(sim.terr, t) < Defs.T_HIGHLAND and sim:valid_site(id, Defs.S_DEFENSE, t)
		and sim:_post_to_raise(id, t) == nil then
		flat = t
		break
	end
end
expect(flat >= 0, "a plains site")
sim.o_gold[id] += 1e9
expect(sim:try_build(id, "defense", flat), "a post")
for _ = 1, 120 do sim:step() end
local post
for _, s in sim:structs_of(id, Defs.S_DEFENSE) do
	if s.tile == flat then post = s end
end
expect(post ~= nil and post.active and post.level == 1, "built, level 1")
local function covered(r)
	local n = 0
	for t = 0, sim.N - 1 do
		local d = sim.range_d2(post.tile, t)
		if d <= r * r and buffer.readu8(sim.def_cover, t) > 0 then n += 1 end
	end
	return n
end
-- a tile just outside level 1's reach, inside level 2's
local edge = -1
local r1, r2 = R.defense_range(1), R.defense_range(2)
for t = 0, sim.N - 1 do
	local d = sim.range_d2(post.tile, t)
	if d > r1 * r1 and d <= r2 * r2 and buffer.readi32(sim.owner, t * 4) == id and not sim:_defense_post_covers(t, id) then
		edge = t
		break
	end
end
expect(edge >= 0, "a tile between the two reaches, not guarded yet")
local ok, up = sim:try_build(id, "defense", flat)
expect(ok and up and post.level == 2, "built on again: level 2")
expect(sim:_defense_post_covers(edge, id), "level 2 guards it")
expect(buffer.readu8(sim.def_cover, edge) > 0, "the coverage map too")
for l = 3, 5 do
	sim:try_build(id, "defense", flat)
end
expect(post.level == 5, "level 5")
local ok6 = sim:try_build(id, "defense", flat)
expect(not ok6 and post.level == 5, "no level 6")
-- razed: its whole (level 5) coverage goes
local before = buffer.readu8(sim.def_cover, edge)
sim:destroy_struct(post)
expect(buffer.readu8(sim.def_cover, edge) == before - 1, "razed: its coverage goes with it")
print(if fails == 0 then "all ok" else fails .. " FAILED")
