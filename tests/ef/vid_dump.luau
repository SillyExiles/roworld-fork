-- Empires Front (2026-11-07): a real AI match (Rome) where one nation fires a volley of bombards, then
-- fire, then the rain of fire arrows; prints what the map and FxLayer need to draw it (a preview video).
-- usage: luau tests/ef/vid_dump.luau > out.txt
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local Ev = require("../../src/shared/Core/Ev")
local Rules = require("../../src/shared/Core/Rules")
local Era = require("../../src/shared/Core/Era")
Era.set("rome")
local sim = Sim.new(WorldMap.get("rome"), { seed = 3, difficulty = 2, tribes = 60, max_humans = 0 })
for _ = 1, 4600 do sim:step() end
local W, H, N = sim.W, sim.H, sim.N
local owner = sim.owner
-- the launcher: a big nation; its enemy neighbours
local A, best = 0, 0
for o = 1, sim.owner_total do
	if sim.o_alive[o] == 1 and sim.o_kind[o] == Defs.KIND_NATION and sim.o_tiles[o] > best then A, best = o, sim.o_tiles[o] end
end
sim.o_gold[A] += 1e9
for _, q in sim:allies_of(A) do sim:end_alliance(A, q, 0, true) end
sim.o_ai[A] = 0
-- an ally (spared by the rain): a neighbour
local function inside(o, near, depth)
	-- a tile of `o` about `depth` tiles in from the border, toward its middle
	local sx, sy, n = 0, 0, 0
	for t = 0, N - 1, 13 do if buffer.readi32(owner, t * 4) == o then sx += t % W; sy += t // W; n += 1 end end
	local cx, cy = sx / math.max(n, 1), sy / math.max(n, 1)
	local bx, by = near % W, near // W
	local best_t, bd = -1, math.huge
	for t = 0, N - 1, 3 do
		if buffer.readi32(owner, t * 4) == o then
			local x, y = t % W, t // W
			local d = math.abs(math.sqrt((x - bx) ^ 2 + (y - by) ^ 2) - depth) + 0.2 * math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
			if d < bd then bd, best_t = d, t end
		end
	end
	return best_t
end
local function border_tile(a, b)
	for t = 0, N - 1, 2 do
		if buffer.readi32(owner, t * 4) == b then
			for _, u in { t - 1, t + 1, t - W, t + W } do
				if u >= 0 and u < N and buffer.readi32(owner, u * 4) == a then return t end
			end
		end
	end
	return -1
end
local nb = sim:_neighbor_owners(A)
local ALLY, C, D = 0, 0, 0
local cand = {}
for _, o in nb do
	if sim.o_kind[o] == Defs.KIND_NATION and sim.o_alive[o] == 1 and sim.o_rookie[o] ~= 1 then table.insert(cand, o) end
end
table.sort(cand, function(a, b) return sim.o_tiles[a] > sim.o_tiles[b] end)
-- C: the biggest whose border with A is away from the map's edges (the camera frames it)
local ci = 1
for i, o in cand do
	local b = border_tile(A, o)
	if b >= 0 and b % W > 150 and b % W < W - 150 and b // W > 150 and b // W < H - 150 then ci = i break end
end
C = table.remove(cand, ci) or 0
local di = 1
for i, o in cand do
	local b = border_tile(A, o)
	if b >= 0 and b // W > 120 and b // W < H - 120 then di = i break end
end
D = table.remove(cand, di) or 0
ALLY = cand[1] or 0
sim:form_alliance(A, ALLY)
-- workshops: 4 on A's land 40-160 tiles from its border with C
local bt0 = -1
for t = 0, N - 1, 2 do
	if buffer.readi32(owner, t * 4) == C then
		for _, u in { t - 1, t + 1, t - W, t + W } do
			if u >= 0 and u < N and buffer.readi32(owner, u * 4) == A then bt0 = t break end
		end
	end
	if bt0 >= 0 then break end
end
local placed = 0
for t = 0, N - 1, 37 do
	if placed >= 4 then break end
	local d2 = (t % W - bt0 % W) ^ 2 + (t // W - bt0 // W) ^ 2
	if d2 > 40 ^ 2 and d2 < 160 ^ 2 and buffer.readi32(owner, t * 4) == A and sim:valid_site(A, Defs.S_SILO, t) and sim:try_build(A, "silo", t) then placed += 1 end
end
for _ = 1, Rules.BUILD_TICKS[Defs.S_SILO] + 20 do sim:step() end
local silos = sim:structs_of(A, Defs.S_SILO)
local out = {}
local function p(...) table.insert(out, table.concat({ ... }, "\t")) end
p("HDR", W, H, A, ALLY, sim.o_name[A], sim.o_name[ALLY], sim.R.K_LIN)
local cols_sent = 0
local function cols()
	for o = cols_sent + 1, sim.owner_total do p("COL", o, sim.o_color[o], sim.o_name[o]) end
	cols_sent = sim.owner_total
end
cols()
for y = 0, H - 1 do
	local r = table.create(W)
	for x = 0, W - 1 do
		local t = y * W + x
		r[x + 1] = if sim.map:is_land(t) then buffer.readi32(owner, t * 4) else -1
	end
	table.insert(out, "ROW " .. table.concat(r, ","))
end
for _, s in silos do p("SILO", s.tile) end
p("T0", sim.tick)
local function step()
	local d = sim:step()
	cols()
	for _, v in d.tiles do p("TK", d.t, v // 1024, v % 1024) end
	for _, v in d.flags do
		if bit32.band(v % 256, Defs.F_FALLOUT) ~= 0 then p("FL", d.t, v // 256, 1) else p("FL", d.t, v // 256, 0) end
	end
	for _, e in d.ev do
		local k = e[1]
		if k == Ev.NUKE or k == Ev.BOOM or k == Ev.BLAZE or k == Ev.VOLLEY then
			local s = { "EV", d.t, k }
			for i = 2, #e do table.insert(s, tostring(e[i])) end
			table.insert(out, table.concat(s, "\t"))
		end
	end
end
local function reload() for _, w in sim:structs_of(A, Defs.S_SILO) do w.shots = {} end end
-- 1) a volley of bombards on C, at its border with A
local bt = border_tile(A, C)
-- (where C's land is solid around, within 150 tiles of that border: the bombards' target)
local function solid(o, near, reach)
	local best_t, bs = inside(o, near, 30), -1
	local bx, by = near % W, near // W
	for y = math.max(20, by - reach), math.min(H - 21, by + reach), 6 do
		for x = math.max(20, bx - reach), math.min(W - 21, bx + reach), 6 do
			local t = y * W + x
			if buffer.readi32(owner, t * 4) == o then
				local sc = 0
				for dy = -18, 18, 4 do
					for dx = -18, 18, 4 do
						if buffer.readi32(owner, ((y + dy) * W + x + dx) * 4) == o then sc += 1 end
					end
				end
				if sc > bs then bs, best_t = sc, t end
			end
		end
	end
	return best_t
end
local c1 = solid(C, bt, 150)
p("SCENE", sim.tick, "bombard", c1, sim.o_name[C])
reload()
local fired = 0
for i = 0, 3 do
	-- around c1, 18 tiles out, a quarter turn apart
	local ang = i * math.pi / 2 + 0.4
	local x, y = c1 % W + math.floor(math.cos(ang) * 18), c1 // W + math.floor(math.sin(ang) * 18)
	local t = y * W + x
	local r = 18
	local function own(u) return if u >= 0 and u < N then buffer.readi32(owner, u * 4) else -1 end
	while own(t) ~= C and r > 4 do
		r -= 2
		t = (c1 // W + math.floor(math.sin(ang) * r)) * W + c1 % W + math.floor(math.cos(ang) * r)
	end
	if own(t) ~= C then t = c1 end
	if sim:launch_nuke(A, "atom", t) then fired += 1 end
end
p("LOG", "bombards " .. fired .. "\n")
for _ = 1, 160 do step() end
-- 2) fire on D
local bt2 = border_tile(A, D)
local d1 = solid(D, bt2, 150)
p("SCENE", sim.tick, "fire", d1, sim.o_name[D])
reload()
p("LOG", "fire " .. tostring(sim:launch_nuke(A, "hydrogen", d1)) .. "\n")
for _ = 1, 150 do step() end
-- 3) the rain of fire arrows
reload()
local tgt = solid(C, bt, 200)
p("SCENE", sim.tick, "rain", tgt, sim.o_name[C])
p("LOG", "rain " .. tostring(sim:launch_nuke(A, "firerain", tgt)) .. "\n")
for _ = 1, 400 do
	step()
	if #sim.firerain == 0 and #sim.blazes == 0 then break end
end
for _ = 1, 30 do step() end
p("END", sim.tick)
print(table.concat(out, "\n"))
