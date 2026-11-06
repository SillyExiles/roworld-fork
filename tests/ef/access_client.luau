-- Empires Front (2026-11-06): Military Access in a free-for-all, as the player's client sees it. The Sim
-- lets an ally's troops march through (tests/ef/access.luau); the client must offer the order too
-- (BorderTracker.mate_touches / can_reach_by_sea, outside team games). usage: luau tests/ef/access_client.luau
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local GameState = require("../../src/shared/Core/GameState")
local Protocol = require("../../src/shared/Net/Protocol")
local BorderTracker = require("../../src/client/UI/BorderTracker")
local fails = 0
local function expect(c, w)
	print((if c then "  ok   " else "FAIL ") .. w)
	if not c then fails += 1 end
end
local sim = Sim.new(WorldMap.get("rome"), { seed = 4, difficulty = 1, tribes = 40, max_humans = 0 })
for _ = 1, 1500 do sim:step() end
local nations = {}
for id = 1, sim.owner_total do
	if sim.o_alive[id] == 1 and sim.o_kind[id] == Defs.KIND_NATION then table.insert(nations, id) end
end
local A, B, C
for _, a in nations do
	for _, b in nations do
		if b ~= a and sim:borders(a, b) then
			for _, c in nations do
				if c ~= a and c ~= b and sim:borders(b, c) and not sim:borders(a, c) then A, B, C = a, b, c break end
			end
		end
		if A then break end
	end
	if A then break end
end
expect(A ~= nil, "A, its neighbour B and B's neighbour C (not A's)")
local gs = GameState.new()
gs:load_snapshot(Protocol.decode_snapshot(Protocol.encode_snapshot(sim:snapshot())))
local function step()
	local d = sim:step()
	gs:apply_delta(Protocol.decode_delta(Protocol.encode_delta(d, d.ev, sim.W)))
end
step()
expect(not gs:is_team_game(), "a free-for-all")
local bt = BorderTracker.new()
bt:bind(gs, A)
-- a tile of C next to B's land (the way in)
local W = sim.W
local tile = -1
for t = 0, sim.N - 1 do
	if buffer.readi32(sim.owner, t * 4) == C then
		for _, n in { t - 1, t + 1, t - W, t + W } do
			if n >= 0 and n < sim.N and buffer.readi32(sim.owner, n * 4) == B then tile = t break end
		end
	end
	if tile >= 0 then break end
end
expect(tile >= 0, "a tile of C on B's border")
expect(bt:mate_touches(tile) == 0, "no alliance: no way through B")
sim:form_alliance(A, B)
step()
expect(gs:has_alliance(A, B), "the mirror has the alliance")
expect(bt:mate_touches(tile) == 0, "allied without Military Access: still no way through")
sim:_sign_pact(A, B, 3)
step()
expect(gs:has_pact(A, B, 3), "the mirror has the Military Access pact")
expect(bt:passage_ok(B), "B lets A pass")
expect(bt:mate_touches(tile) ~= 0, "Military Access: the client offers the march through B")
-- a port of B on a sea A has no coast on: the client offers a boat from it
local port_body = nil
for _, st in gs.structures do
	if st.owner == B and st.kind == Defs.S_PORT then
		local body = buffer.readu16(sim.map.coast_body, st.tile * 2)
		if not bt._bodies[body] then port_body = body break end
	end
end
if port_body ~= nil then
	local coast = -1
	for t = 0, sim.N - 1 do
		if buffer.readu8(sim.map.coastal, t) == 1 and buffer.readu16(sim.map.coast_body, t * 2) == port_body then coast = t break end
	end
	expect(bt:can_reach_by_sea(coast), "a sea only B's port touches: reachable with Military Access")
else
	print("  (B has no port on a sea A lacks: boat case skipped)")
end
-- (2026-11-06) the AI side: an AI ally with Military Access marches through B against B's attacker
do
	-- C attacks B
	local btile = -1
	for t = 0, sim.N - 1 do
		if buffer.readi32(sim.owner, t * 4) == B then
			for _, n in { t - 1, t + 1, t - W, t + W } do
				if n >= 0 and n < sim.N and buffer.readi32(sim.owner, n * 4) == C then btile = t break end
			end
		end
		if btile >= 0 then break end
	end
	sim.o_troops[C] = math.max(sim.o_troops[C], 20000)
	expect(sim:intent_attack(C, btile, 0.3), "C attacks B")
	for _, a in sim.attacks do
		if not a.dead and a.attacker == A and a.target == C then a.troops = 0 a.dead = true end
	end
	sim.o_troops[A] = sim.o_cap[A] * 0.95
	local ok = sim.ai:_consider_passage_war(sim, A, 0.01, 10 ^ 9)
	local by_a = nil
	for _, a in sim.attacks do
		if not a.dead and a.attacker == A and a.target == C then by_a = a end
	end
	expect(ok and by_a ~= nil, "the AI ally A attacks C, B's attacker")
	expect(not sim:borders(A, C) and by_a ~= nil and (by_a.via or -1) >= 0, "through B's land (A doesn't border C; via a tile of B)")
	-- without the pact it doesn't
	local saved = sim.pacts[math.min(A, B) * 1024 + math.max(A, B)]
	sim.pacts[math.min(A, B) * 1024 + math.max(A, B)] = nil
	if by_a then by_a.dead = true by_a.troops = 0 end
	sim.o_troops[A] = sim.o_cap[A] * 0.95
	expect(sim.ai:_consider_passage_war(sim, A, 0.01, 10 ^ 9) == false, "no Military Access: no march through B")
	sim.pacts[math.min(A, B) * 1024 + math.max(A, B)] = saved
	for _, a in sim.attacks do
		if a.attacker == C and a.target == B then a.dead = true a.troops = 0 end
	end
end
-- the order itself, as the client sends it
sim.o_troops[A] = 50000
local c0 = sim.o_tiles[C]
sim:submit(A, { type = "attack", tile = tile, ratio = 0.5 })
for _ = 1, 200 do sim:step() end
expect(sim.o_tiles[C] < c0, string.format("the march through B takes C's land (%d -> %d)", c0, sim.o_tiles[C]))
-- the alliance ends: the way closes
sim:end_alliance(A, B, 0, true)
step()
expect(bt:mate_touches(tile) == 0, "alliance over: no way through")
print(if fails == 0 then "all ok" else fails .. " FAILED")
