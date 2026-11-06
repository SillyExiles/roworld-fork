-- Empires Front: what the siege weapons do in an AI match (a probe, not a test).
-- usage: luau tests/ef/siege_probe.luau -a [map] [minutes] [seed] [difficulty]
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
WorldMap.put_data("greece", require("./greece_raw"))
WorldMap.put_data("japan", require("./japan_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local Rules = require("../../src/shared/Core/Rules")
local Era = require("../../src/shared/Core/Era")
local args = { ... }
local mapid = args[1] or "rome"
local minutes = tonumber(args[2]) or 20
local seed = tonumber(args[3]) or 3
local diff = tonumber(args[4]) or 2
Era.set(mapid)
local sim = Sim.new(WorldMap.get(mapid), { seed = seed, difficulty = diff, tribes = 60, max_humans = 0 })

local K = { [Defs.N_ATOM] = "bombard", [Defs.N_HYDROGEN] = "fire", [Defs.N_PLAGUE] = "plague" }
local st = {}
for k, n in K do st[k] = { n = 0, gold = 0, down = 0, tiles = 0, troops = 0, structs = 0, sick = 0 } end
local fails = 0
local ln = sim.launch_nuke
sim.launch_nuke = function(self, id, kname, t)
	local g = self.o_gold[id]
	local ok = ln(self, id, kname, t)
	local k = Defs.nuke_kind_from_name(kname)
	if ok and st[k] then st[k].n += 1; st[k].gold += g - self.o_gold[id] elseif not ok then fails += 1 end
	return ok
end
local si = sim._sam_intercept
sim._sam_intercept = function(self, n)
	local ok = si(self, n)
	if ok and st[n.kind] then st[n.kind].down += 1 end
	return ok
end
-- land and troops each kind takes (troops lost in _nuke_troops; plague: dbg_flow while sick)
local cur = nil
local nt = sim._nuke_troops
sim._nuke_troops = function(self, o, kind, n_lost, before)
	local t0 = self.o_troops[o]
	nt(self, o, kind, n_lost, before)
	if st[kind] then st[kind].tiles += n_lost; st[kind].troops += t0 - self.o_troops[o] end
end
local ds = sim.destroy_struct
sim.destroy_struct = function(self, s, ...)
	if cur ~= nil and st[cur] then st[cur].structs += 1 end
	return ds(self, s, ...)
end
local det = sim._detonate
sim._detonate = function(self, n) cur = n.kind; det(self, n); cur = nil end
local bt = sim._blazes_tick
sim._blazes_tick = function(self) cur = Defs.N_HYDROGEN; bt(self); cur = nil end
local inf = sim._infect
sim._infect = function(self, o, src, ticks)
	local ok = inf(self, o, src, ticks)
	if ok then st[Defs.N_PLAGUE].sick += 1 end
	return ok
end
local pt = sim._plague_tick
sim._plague_tick = function(self)
	local before = 0
	for _, o in self.plague_list do before += self.o_troops[o] end
	local ids = table.clone(self.plague_list)
	pt(self)
	local after = 0
	for _, o in ids do after += self.o_troops[o] end
	st[Defs.N_PLAGUE].troops += math.max(0, before - after)
end

local function fmt(v) return if v >= 1e6 then string.format("%.1fM", v / 1e6) else string.format("%.0fk", v / 1e3) end
print(string.format("%s seed %d diff %d: %d nations", mapid, seed, diff, sim.nation_count))
for m = 1, minutes do
	for _ = 1, 600 do sim:step() end
	if m % 2 == 0 or m == minutes then
		local golds, incs, silos = {}, {}, 0
		for id = 1, sim.owner_total do
			if sim.o_alive[id] == 1 and sim.o_kind[id] == Defs.KIND_NATION then
				table.insert(golds, sim.o_gold[id])
				table.insert(incs, sim.o_income[id] * 10)
				silos += sim:struct_count(id, Defs.S_SILO)
			end
		end
		table.sort(golds); table.sort(incs)
		local med = golds[#golds // 2 + 1] or 0
		local parts = {}
		for k, n in K do local s = st[k]; table.insert(parts, string.format("%s %d(-%d)", n, s.n, s.down)) end
		print(string.format("%2d | %2d alive | gold med %s top %s | passive/s med %s top %s | workshops %d | %s", m, #golds, fmt(med), fmt(golds[#golds] or 0), fmt(incs[#incs // 2 + 1] or 0), fmt(incs[#incs] or 0), silos, table.concat(parts, " ")))
	end
end
print("kind | shots | gold | shot down | tiles razed/shot | troops/shot | buildings | sick")
for k, n in K do
	local s = st[k]
	local hit = math.max(1, s.n - s.down)
	print(string.format("%s | %d | %s | %d | %.0f | %s | %d | %d", n, s.n, fmt(s.gold), s.down, s.tiles / hit, fmt(s.troops / hit), s.structs, s.sick))
end
print("failed launches", fails)
