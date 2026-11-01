-- Empires Front: Military Access (pact "access") lets an ally's troops march through and sail from its ports;
-- and a solo team game draws teams. usage: luau tests/ef/access.luau
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local map = WorldMap.get("rome")
local sim = Sim.new(map, { seed = 4, difficulty = 1, tribes = 40, max_humans = 0 })
for _ = 1, 1500 do sim:step() end
-- find a nation A, an ally candidate B bordering A, and a target C bordering B but not A
local function borders(a, b)
	local W = sim.W
	for t = 0, sim.N - 1 do
		if buffer.readi32(sim.owner, t * 4) == a then
			for _, n in { t - 1, t + 1, t - W, t + W } do
				if n >= 0 and n < sim.N and buffer.readi32(sim.owner, n * 4) == b then
					return true
				end
			end
		end
	end
	return false
end
local nations = {}
for id = 1, sim.owner_total do
	if sim.o_alive[id] == 1 and sim.o_kind[id] == Defs.KIND_NATION then table.insert(nations, id) end
end
local A, B, C
for _, a in nations do
	for _, b in nations do
		if b ~= a and borders(a, b) then
			for _, c in nations do
				if c ~= a and c ~= b and borders(b, c) and not borders(a, c) then A, B, C = a, b, c break end
			end
		end
		if A then break end
	end
	if A then break end
end
print("A B C", A, B, C)
sim:form_alliance(A, B)
local tile = -1
for t = 0, sim.N - 1 do if buffer.readi32(sim.owner, t * 4) == C then tile = t break end end
sim.o_troops[A] = 50000
print("attack C without access:", sim:intent_attack(A, tile, 0.5))
print("passage ok before:", sim:_passage_ok(A, B))
sim:_sign_pact(A, B, 3)
print("passage ok after:", sim:_passage_ok(A, B))
print("attack C with access:", sim:intent_attack(A, tile, 0.5))
-- solo team game
local sim2 = Sim.new(map, { seed = 9, difficulty = 1, tribes = 20, max_humans = 1, teams = 2 })
local h = sim2:add_human("local", "Tester")
sim2:assign_teams()
local count = {}
for id = 1, sim2.owner_total do
	local t = sim2.o_team[id]
	if t ~= 0 then count[t] = (count[t] or 0) + 1 end
end
print("teams", table.concat(sim2.team_names, ","), "sizes", count[1], count[2], "human on", sim2.o_team[h])
