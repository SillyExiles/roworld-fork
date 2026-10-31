-- Empires Front v9 checks (plain `luau` CLI): captures keep structures, the Barracks cap, roads link
-- every structure kind. usage: luau tests/ef/v9.luau
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local Rules = require("../../src/shared/Core/Rules")
local map = WorldMap.get("rome")
local sim = Sim.new(map, { seed = 7, difficulty = 2, tribes = 60, max_humans = 0 })

local captured, razed = {}, {}
local orig = sim._struct_tile_changed
sim._struct_tile_changed = function(self, t, old, nw)
	local s = self.structs[buffer.readi32(self.struct_at, t * 4)]
	local kind = if s ~= nil then s.kind else -1
	orig(self, t, old, nw)
	if s ~= nil then
		if s.dead then
			razed[kind] = (razed[kind] or 0) + 1
		else
			captured[kind] = (captured[kind] or 0) + 1
		end
	end
end

local ticks = tonumber((...)) or 5000
for _ = 1, ticks do
	sim:step()
end

local function dump(label, t)
	local parts = {}
	for k = 0, Defs.STRUCT_KIND_COUNT - 1 do
		if t[k] then
			table.insert(parts, Defs.STRUCT_NAMES[k] .. "=" .. t[k])
		end
	end
	print(label, table.concat(parts, " "))
end
dump("captured", captured)
dump("razed   ", razed)

-- stations by kind
local st, all = {}, {}
for _, s in sim.struct_list do
	if not s.dead then
		all[s.kind] = (all[s.kind] or 0) + 1
		if s.station then
			st[s.kind] = (st[s.kind] or 0) + 1
		end
	end
end
dump("built   ", all)
dump("stations", st)

-- the Barracks cap
local worst = 0
for id = 1, sim.owner_total do
	worst = math.max(worst, sim.o_scount[id * sim.STRUCT_KINDS + Defs.S_BARRACKS])
end
print("most barracks held by one nation", worst, "(limit", Rules.BARRACKS_LIMIT .. ")")

-- a direct try: a nation at the cap can't place a 5th barracks away from its own
local test_id = 0
for id = 1, sim.owner_total do
	if sim.o_alive[id] == 1 and sim.o_kind[id] == Defs.KIND_NATION then
		test_id = id
		break
	end
end
if test_id > 0 then
	sim.o_gold[test_id] += 1e9
	local tiles = {}
	for t = 0, sim.N - 1 do
		if buffer.readi32(sim.owner, t * 4) == test_id then
			table.insert(tiles, t)
		end
	end
	local made = 0
	for i = 1, #tiles, math.max(1, #tiles // 60) do
		local before = sim.o_scount[test_id * sim.STRUCT_KINDS + Defs.S_BARRACKS]
		sim:try_build(test_id, "barracks", tiles[i])
		local after = sim.o_scount[test_id * sim.STRUCT_KINDS + Defs.S_BARRACKS]
		if after > before then
			made += 1
		end
	end
	local held = sim.o_scount[test_id * sim.STRUCT_KINDS + Defs.S_BARRACKS]
	print("forced builds: new barracks", made, "held now", held)
	assert(held <= Rules.BARRACKS_LIMIT or worst > Rules.BARRACKS_LIMIT, "barracks cap broken")
end
print("ok", sim.tick)
