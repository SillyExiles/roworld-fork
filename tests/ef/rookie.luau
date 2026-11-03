-- Empires Front (2026-11-03): a new player's protection (Rules.ROOKIE_*): the AI waits longer for them.
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
-- the first tick an AI may attack the human, with and without the rookie flag
local function first_attack(rookie)
	local sim = Sim.new(WorldMap.get("rome"), { seed = 5, difficulty = 1, tribes = 40, max_humans = 1 })
	local h = sim:add_human("p", "Player")
	if rookie then sim:set_rookie(h, true) end
	local ai = sim.ai
	local min_age = math.huge
	for _ = 1, 400 do sim:step() end
	-- spawn the human on a free tile near the middle
	for t = sim.N // 2, sim.N - 1, 97 do
		if buffer.readi32(sim.owner, t * 4) == 0 and buffer.readu8(sim.map.terrain, t) >= Defs.T_PLAINS then
			sim:submit(h, { type = "spawn", tile = t })
			break
		end
	end
	local may = 0
	for i = 1, 4500 do
		sim:step()
		if i % 100 == 0 and sim.phase == Defs.PHASE_PLAYING then
			for id = 1, sim.owner_total do
				if sim.o_alive[id] == 1 and sim.o_kind[id] == Defs.KIND_NATION and ai._may_attack_human ~= nil then
					if ai:_may_attack_human(sim, id, h, sim.tick - sim.playing_since) then
						may += 1
					end
				end
			end
		end
	end
	return may
end
local plain, rk = first_attack(false), first_attack(true)
expect(Rules.ROOKIE_GRACE_MULT > 1 and Rules.ROOKIE_MAX_WARS >= 1, "rookie rules set")
expect(rk < plain, string.format("the AI may attack a rookie less often in the first 7.5 min (%d vs %d checks)", rk, plain))
print(if fails == 0 then "all ok" else fails .. " FAILED")
