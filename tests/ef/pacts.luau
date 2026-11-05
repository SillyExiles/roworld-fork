-- Empires Front (2026-11-05): an AI ally proposes pacts to a player (Core/SimDiplomacy._ai_propose_pacts).
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local Ev = require("../../src/shared/Core/Ev")
local fails = 0
local function expect(c, w)
	print((if c then "  ok   " else "FAIL ") .. w)
	if not c then fails += 1 end
end
local sim = Sim.new(WorldMap.get("rome"), { seed = 7, difficulty = 1, tribes = 40, max_humans = 1 })
local h = sim:add_human("p", "Player")
for _ = 1, 300 do sim:step() end
for t = sim.N // 2, sim.N - 1, 97 do
	if buffer.readi32(sim.owner, t * 4) == 0 and buffer.readu8(sim.map.terrain, t) >= Defs.T_PLAINS then
		sim:submit(h, { type = "spawn", tile = t })
		break
	end
end
for _ = 1, 400 do sim:step() end
local ai = 0
for id = 1, sim.owner_total do
	if sim.o_alive[id] == 1 and sim.o_kind[id] == Defs.KIND_NATION and sim.o_ai[id] == 1 then ai = id break end
end
sim:form_alliance(ai, h)
expect(sim:allied(ai, h), "allied")
local asked = {}
local ev0 = sim.ev
sim.ev = function(self, e)
	if e[1] == Ev.PACT and e[5] == 0 and e[2] == ai and e[3] == h then asked[e[4]] = true end
	return ev0(self, e)
end
for _ = 1, 6000 do
	sim:step()
	if asked[1] then break end
end
expect(asked[1] == true, "the AI ally proposed a trade pact")
-- the player accepts: signed
sim:pact_reply(h, ai, "trade", true)
expect(sim:has_pact(ai, h, 1), "accepted: the trade pact is signed")
for _ = 1, 9000 do sim:step() end
expect(asked[2] == true or asked[3] == true, "then another pact")
print(if fails == 0 then "all ok" else fails .. " FAILED")
