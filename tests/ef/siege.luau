-- Empires Front (2026-11-06): the siege weapons. The Siege Workshop (up to five a player, each weapon reloading on its own,
-- none before the war is SIEGE_UNLOCK_TICKS old), the bombard (scorched land that clears), fire that
-- spreads, the plague (it spreads; Temples ease it), the Watchtower, and betraying an ally.
-- usage: luau tests/ef/siege.luau (from tests/ef)
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local Rules = require("../../src/shared/Core/Rules")
local fails = 0
local function expect(c, w)
	print((if c then "  ok   " else "FAIL ") .. w)
	if not c then fails += 1 end
end
local sim = Sim.new(WorldMap.get("rome"), { seed = 21, difficulty = 1, tribes = 60, max_humans = 0 })
for _ = 1, 2000 do sim:step() end
local R = sim.R
local A, best = 0, 0
for o = 1, sim.owner_total do
	if sim.o_alive[o] == 1 and sim.o_kind[o] == Defs.KIND_NATION and sim.o_tiles[o] > best then A, best = o, sim.o_tiles[o] end
end
sim.o_ai[A] = 0
sim.o_gold[A] += 1e9
-- (the AI is stopped from here on: the test checks the weapons, not the wars around them)
for o = 1, sim.owner_total do
	sim.o_ai[o] = 0
end
-- (A keeps a full army through the test, so its workshop stands)
local base_step = sim.step
sim.step = function(self: any, ...)
	self.o_troops[A] = math.max(self.o_troops[A], self.o_cap[A] * 0.9)
	return base_step(self, ...)
end
expect(Defs.NUKE_NAMES[Defs.N_PLAGUE] == "plague" and Defs.NUKE_KIND_COUNT == 10, "the plague is a munition")
expect(Rules.STRUCT_LIMITS[Defs.S_SILO] == 5 and Rules.UPGRADABLE[Defs.S_SILO] == 0, "Siege Workshops: five at most, no levels")
expect(R.launch_range(Defs.N_ATOM) > 0, "the bombard has a reach (" .. math.floor(R.launch_range(Defs.N_ATOM)) .. " tiles)")

-- the workshop: a site in A's land with an enemy within reach
local reach = R.launch_range(Defs.N_ATOM)
local site, target, B = -1, -1, 0
for t = 0, sim.N - 1, 7 do
	if buffer.readi32(sim.owner, t * 4) == A and sim:valid_site(A, Defs.S_SILO, t) then
		-- an enemy nation's tile 40..reach-10 tiles away
		for u = 0, sim.N - 1, 13 do
			local o = buffer.readi32(sim.owner, u * 4)
			if o > 0 and o ~= A and sim.o_kind[o] == Defs.KIND_NATION and not sim:allied(A, o) then
				local d = math.sqrt(sim.range_d2(t, u))
				if d > 25 and d < reach - 10 then
					site, target, B = t, u, o
					break
				end
			end
		end
	end
	if site >= 0 then break end
end
expect(site >= 0 and B > 0, "a workshop site with an enemy in reach")
expect(sim:try_build(A, "silo", site), "the Siege Workshop goes up")
for _ = 1, 110 do sim:step() end
local other = -1
for t = 0, sim.N - 1, 5 do
	if buffer.readi32(sim.owner, t * 4) == A and t ~= site and sim:valid_site(A, Defs.S_SILO, t) and sim.range_d2(t, site) > 400 then other = t break end
end
expect(other >= 0 and sim:try_build(A, "silo", other), "a second one goes up (up to Rules.STRUCT_LIMITS)")
expect(Rules.STRUCT_LIMITS[Defs.S_SILO] == 5, "five a player at most")
local silo = sim:structs_of(A, Defs.S_SILO)[1]
expect(silo ~= nil and silo.active, "the workshop is finished")

-- not before the war is old enough
local ps = sim.playing_since
sim.playing_since = sim.tick
expect(not sim:launch_nuke(A, "atom", target), "no siege weapon before SIEGE_UNLOCK_TICKS")
-- (the match is younger than SIEGE_UNLOCK_TICKS here: unlock it by the rule's own number)
Rules.SIEGE_UNLOCK_TICKS = 100
sim.playing_since = sim.tick - 101
expect(not sim:launch_nuke(A, "mirv", target), "no MIRV from a workshop")
expect(not sim:launch_nuke(A, "plague", site), "the plague can't be aimed at your own land")

-- the bombard: a small disc razed and scorched; the scorch clears after SCORCH_TICKS
local fo0 = sim.fallout_count
local btiles0 = sim.o_tiles[B]
local gold0 = sim.o_gold[A]
local price = Rules.siege_cost("atom", sim:land_share(A))
expect(sim:launch_nuke(A, "atom", target), "a bombard flies")
expect(gold0 - sim.o_gold[A] == price and price > Rules.nuke_cost("atom"), string.format("a big empire pays more for it (%d, base %d)", price, Rules.nuke_cost("atom")))
expect(Rules.siege_cost("atom", 0) == Rules.nuke_cost("atom") and Rules.siege_cost("atom", 0.3) == math.floor(Rules.nuke_cost("atom") * 1.75 / 1000 + 0.5) * 1000, "x1 at no land, x1.75 at 30%")
expect(not sim:launch_nuke(A, "atom", target), "the workshop reloads its bombard")
expect(sim:siege_ready(silo, Defs.N_HYDROGEN) and sim:siege_ready(silo, Defs.N_PLAGUE), "but its fire and its plague stay loaded")
local busy, wait = Rules.shots_busy(silo.shots, Defs.S_SILO, sim.tick, Defs.N_ATOM)
expect(busy == 1 and wait == Rules.siege_reload(Defs.N_ATOM) and Rules.shots_busy(silo.shots, Defs.S_SILO, sim.tick, Defs.N_PLAGUE) == 0, "the client reads the same reloads from the shots")
for _ = 1, 200 do sim:step() end
local scorched = sim.fallout_count - fo0
expect(scorched > 0 and scorched < 1200, "it scorched a small disc (" .. scorched .. " tiles)")
expect(sim.o_tiles[B] < btiles0 + 50, "the target lost land")
for _ = 1, Rules.SCORCH_TICKS + 10 do sim:step() end
expect(sim.fallout_count <= fo0 + 5, "the scorched land cleared (" .. sim.fallout_count - fo0 .. " left)")

for _ = 1, Rules.siege_reload(Defs.N_ATOM) do sim:step() end
expect(sim:siege_ready(silo, Defs.N_ATOM) and #silo.shots == 0, "the bombard is loaded again after its own reload")
-- two workshops: a volley of two bombards, then none
local second = sim:structs_of(A, Defs.S_SILO)[2]
expect(second ~= nil and second.active, "the second workshop is finished")
local volley = 0
for _ = 1, 3 do if sim:launch_nuke(A, "atom", target) then volley += 1 end end
expect(volley == 2, "two workshops fire two bombards in a row (" .. volley .. ")")
second.shots = {}

-- fire: it spreads over FIRE_SPREAD_TICKS
silo.shots = {}
local tg2 = -1
for u = 0, sim.N - 1, 11 do
	local o = buffer.readi32(sim.owner, u * 4)
	if o > 0 and o ~= A and not sim:allied(A, o) and sim.range_d2(site, u) < (reach - 10) ^ 2 and sim.range_d2(site, u) > 900 then tg2 = u break end
end
expect(tg2 >= 0, "a target for the fire")
local fo1 = sim.fallout_count
expect(sim:launch_nuke(A, "hydrogen", tg2), "fire flies")
local landed = false
local early, late = 0, 0
for _ = 1, 400 do
	sim:step()
	if not landed and #sim.blazes > 0 then
		landed = true
		local start = sim.blazes[1].start
		while sim.tick < start + 6 do sim:step() end
		early = sim.fallout_count - fo1
		for _ = 1, Rules.FIRE_SPREAD_TICKS do sim:step() end
		late = sim.fallout_count - fo1
		break
	end
end
expect(landed, "the fire caught")
expect(late > early and early >= 0, string.format("it spread (%d tiles after 0.6 s, %d at the end)", early, late))
expect(#sim.blazes == 0, "and burnt out")

-- the plague: the target sickens and loses troops; it spreads; it ends and leaves immunity
silo.shots = {}
local P = buffer.readi32(sim.owner, target * 4)
if P <= 0 or P == A then
	P = B
	for u = 0, sim.N - 1, 7 do
		if buffer.readi32(sim.owner, u * 4) == B and sim.range_d2(site, u) < (reach - 5) ^ 2 then target = u break end
	end
end
P = buffer.readi32(sim.owner, target * 4)
expect(P > 0 and P ~= A, "a nation to strike with the plague")
sim.o_troops[P] = math.max(sim.o_troops[P], 50000)
expect(sim:launch_nuke(A, "plague", target), "the plague flies")
local sick_at = -1
for _ = 1, 300 do
	sim:step()
	if sim.o_plague_until[P] > sim.tick then sick_at = sim.tick break end
end
expect(sick_at > 0, "it took hold")
local tr0 = sim.o_troops[P]
local dead0 = sim.dbg_flow[P * 5 + 3]
local before_spread = #sim.plague_list
local spread = false
-- (spreading is a chance a neighbour's Temples cut: made sure here)
local p_spread = Rules.PLAGUE_SPREAD_P
Rules.PLAGUE_SPREAD_P = 10
for _ = 1, 700 do
	sim:step()
	if #sim.plague_list > before_spread then spread = true end
end
Rules.PLAGUE_SPREAD_P = p_spread
local died = sim.dbg_flow[P * 5 + 3] - dead0
expect(died > tr0 * 0.15, string.format("the sick lose troops (%d of %d died in 70 s)", died, tr0))
expect(spread, "it spread to a neighbour")
for _ = 1, Rules.PLAGUE_TICKS do sim:step() end
expect(sim.o_plague_until[P] == 0, "the plague ends")
expect(not sim:_infect(P, A, 100), "and leaves the nation immune for a while")
expect(Rules.plague_severity(0) == 1 and Rules.plague_severity(2) == 0.5 and Rules.plague_severity(9) == Rules.PLAGUE_MIN_SEVERITY, "Temples ease it")

-- (A's workshop may have fallen to a neighbour meanwhile: a new one)
local function ensure_silo()
	if silo ~= nil and not silo.dead and silo.owner == A then
		silo.shots = {}
		return
	end
	for t = 0, sim.N - 1, 3 do
		if buffer.readi32(sim.owner, t * 4) == A and sim:valid_site(A, Defs.S_SILO, t) and sim:try_build(A, "silo", t) then
			site = t
			break
		end
	end
	for _ = 1, 110 do sim:step() end
	silo = sim:structs_of(A, Defs.S_SILO)[1]
	silo.shots = {}
end
-- an ally hit: the alliance breaks and the launcher is a traitor
ensure_silo()
local C = 0
for u = 0, sim.N - 1, 9 do
	local o = buffer.readi32(sim.owner, u * 4)
	if o > 0 and o ~= A and sim.o_kind[o] == Defs.KIND_NATION and sim.range_d2(site, u) < (reach - 10) ^ 2 and sim.o_plague_until[o] == 0 then
		C, target = o, u
		break
	end
end
for _, q in sim:allies_of(A) do sim:end_alliance(A, q, 0, true) end
sim:form_alliance(A, C)
expect(C > 0 and sim:has_alliance(A, C), "A allied with C")
expect(sim:launch_nuke(A, "atom", target), "A fires on its ally")
expect(not sim:has_alliance(A, C) and sim.o_traitor_until[A] > sim.tick, "the alliance broke; A is a traitor")

-- the Watchtower shoots the shot down
for _ = 1, 300 do sim:step() end
ensure_silo()
local D, tower = 0, -1
for u = 0, sim.N - 1, 17 do
	local o = buffer.readi32(sim.owner, u * 4)
	local d2 = sim.range_d2(site, u)
	if o > 0 and o ~= A and sim.o_kind[o] == Defs.KIND_NATION and d2 > 900 and d2 < (reach - 15) ^ 2 and sim:valid_site(o, Defs.S_SAM, u) then
		D, tower = o, u
		break
	end
end
sim.o_gold[D] += 1e8
if tower >= 0 and sim:try_build(D, "sam", tower) then
	for _ = 1, Rules.BUILD_TICKS[Defs.S_SAM] + 10 do sim:step() end
	local target_tile = target
	for u = 0, sim.N - 1 do
		if buffer.readi32(sim.owner, u * 4) == D and sim.range_d2(u, tower) < 64 then target_tile = u break end
	end
	local downed = {}
	local real = sim._sam_intercept
	sim._sam_intercept = function(self2, n)
		local ok = real(self2, n)
		if ok then downed[n.kind] = (downed[n.kind] or 0) + 1 end
		return ok
	end
	ensure_silo()
	expect(sim:launch_nuke(A, "hydrogen", target_tile), "fire at the tower's land")
	for _ = 1, 200 do sim:step() end
	expect((downed[Defs.N_HYDROGEN] or 0) == 1, "the Watchtower shot the fire down")
	ensure_silo()
	local fo2 = sim.fallout_count
	expect(sim:launch_nuke(A, "atom", target_tile), "a bombard at the tower's land")
	for _ = 1, 200 do sim:step() end
	expect(downed[Defs.N_ATOM] == nil and sim.fallout_count > fo2, "the bombard can't be stopped: it scorched the land")
	expect(Rules.NUKE_INTERCEPT_P[Defs.N_PLAGUE] == 0 and Rules.NUKE_INTERCEPT_P[Defs.N_HYDROGEN] > 0, "nor can the plague; only the fire can")
	sim._sam_intercept = real
else
	print("  (no Watchtower site: skipped)")
end

-- walls and Fortresses shield
local wall_t = -1
for t = 0, sim.N - 1 do
	if bit32.band(buffer.readu8(sim.flags, t), Defs.F_WALL) ~= 0 then wall_t = t break end
end
if wall_t >= 0 then
	expect(sim:_shielded(wall_t, buffer.readi32(sim.owner, wall_t * 4)), "a walled tile is shielded")
end
-- (2026-11-06) a new player is safe: no siege weapon may be aimed at them, a blast spares their land,
-- the plague never takes them, and the AI picks no target of theirs
ensure_silo()
local Rk, rk_tile = 0, -1
for u = 0, sim.N - 1, 7 do
	local o = buffer.readi32(sim.owner, u * 4)
	if o > 0 and o ~= A and sim.o_kind[o] == Defs.KIND_NATION and not sim:has_alliance(A, o) and sim.range_d2(site, u) < (reach - 10) ^ 2 and sim.range_d2(site, u) > 400 then
		Rk, rk_tile = o, u
		break
	end
end
expect(Rk > 0, "a nation to make a new player")
sim:set_rookie(Rk, true)
expect(not sim:launch_nuke(A, "atom", rk_tile), "a bombard can't be aimed at a new player")
expect(not sim:launch_nuke(A, "plague", rk_tile), "nor the plague")
expect(not sim:_infect(Rk, A, 100), "the plague never takes a new player")
local SimAI = require("../../src/shared/Core/SimAI")
expect(SimAI._nuke_target(sim.ai, sim, A, Rk, Defs.N_ATOM) == -1, "the AI picks no target of theirs")
-- a bombard and a fire landing on their land (as if a shot aimed next door went wide) spare it
local rk_tiles0 = sim.o_tiles[Rk]
local rk_structs0 = 0
for k = 0, Defs.STRUCT_KIND_COUNT - 1 do rk_structs0 += #sim:structs_of(Rk, k) end
sim:_detonate({ uid = 990001, kind = Defs.N_ATOM, owner = A, to_tile = rk_tile, target_owner = Rk })
sim:_ignite({ uid = 990002, kind = Defs.N_HYDROGEN, owner = A, to_tile = rk_tile, target_owner = Rk })
for _ = 1, Rules.FIRE_SPREAD_TICKS + 5 do sim:step() end
local rk_structs1 = 0
for k = 0, Defs.STRUCT_KIND_COUNT - 1 do rk_structs1 += #sim:structs_of(Rk, k) end
expect(sim.o_tiles[Rk] >= rk_tiles0 - 5, string.format("a blast on their land spared it (%d -> %d tiles)", rk_tiles0, sim.o_tiles[Rk]))
expect(rk_structs1 >= rk_structs0, "and their buildings")
expect(#sim:rookie_rows() >= 1, "the snapshot lists the new player")
local _ = ps
print(if fails == 0 then "all ok" else fails .. " FAILED")
