-- Empires Front (2026-11-05): alliances are worth it (Rules.ALLY_INCOME, ALLIED_VICTORY).
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local Rules = require("../../src/shared/Core/Rules")
local Stars = require("../../src/shared/Data/Stars")
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
local ais = {}
for id = 1, sim.owner_total do
	if sim.o_alive[id] == 1 and sim.o_kind[id] == Defs.KIND_NATION and sim.o_ai[id] == 1 and #ais < 6 then
		table.insert(ais, id)
	end
end
local inc0 = sim:_income_of(h)
sim:form_alliance(ais[1], h)
local inc1 = sim:_income_of(h)
expect(math.abs(inc1 / inc0 - (1 + Rules.ALLY_INCOME)) < 1e-6, string.format("an ally: +%d%% income (%.0f -> %.0f)", Rules.ALLY_INCOME * 100, inc0, inc1))
-- allied victory: the group's land together
local need = sim.win_share * (sim.map.contestable_count - sim.fallout_count)
local w0 = sim:_allied_victory(need)
expect(w0 == 0, "not yet: the group is small")
sim.o_tiles[h] = math.floor(need * 0.5)
sim.o_tiles[ais[1]] = math.floor(need * 0.55)
local w, group = sim:_allied_victory(need)
expect(w == ais[1] and group ~= nil and #group == 2, "the player and an ally with the win share together win")
-- two AI nations alone don't
sim:end_alliance(ais[1], h, 0, true)
sim:form_alliance(ais[1], ais[2])
sim.o_tiles[ais[2]] = math.floor(need * 0.5)
expect(sim:_allied_victory(need) == 0, "AI nations alone don't win together")
-- an ally's ally is not your ally: H-A1, A1-A2, but not H-A2 (2026-11-05 fix)
sim:form_alliance(ais[1], h)
expect(sim:allied(h, ais[1]) and sim:allied(ais[1], ais[2]) and not sim:allied(h, ais[2]), "the chain H-A1-A2")
sim.o_tiles[h] = math.floor(need * 0.3)
sim.o_tiles[ais[1]] = math.floor(need * 0.3)
sim.o_tiles[ais[2]] = math.floor(need * 0.5)
expect(sim:_allied_victory(need) == 0, "the chain's land together (1.1x) doesn't win: H and A2 aren't allies")
sim.o_tiles[h] = math.floor(need * 0.75)
local w2, g2 = sim:_allied_victory(need)
expect(w2 == h and g2 ~= nil and #g2 == 2 and table.find(g2, ais[2]) == nil, "H and A1 win; A1's other ally A2 doesn't")
sim:form_alliance(h, ais[2])
local _, g3 = sim:_allied_victory(need)
expect(g3 ~= nil and #g3 == 3, "all three allied with each other win together")
-- (2026-11-05) at most Rules.ALLY_MAX = 3 alliances each, players and bots
expect(#ais >= 6, "six AI nations to test with")
expect(Rules.ALLY_MAX == 3, "3 alliances at most")
expect(sim:form_alliance(h, ais[3]) == true and sim.o_ally_count[h] == 3, "the player's 3rd alliance forms")
expect(sim:ally_request(h, ais[4]) == false and not sim:has_request(h, ais[4]), "a 4th request is refused")
expect(sim:ally_request(ais[4], h) == false and not sim:has_request(ais[4], h), "a bot can't ask a full player")
expect(sim:form_alliance(h, ais[4]) == false and not sim:allied(h, ais[4]), "a 4th alliance never forms")
sim:form_alliance(ais[4], ais[5])
sim:form_alliance(ais[4], ais[6])
sim:form_alliance(ais[4], ais[2])
expect(sim.o_ally_count[ais[4]] == 3 and sim.o_ally_count[ais[2]] == 3, "bots fill up to 3 too")
expect(sim:form_alliance(ais[4], ais[3]) == false, "a bot's 4th alliance never forms")
sim:end_alliance(h, ais[3], 0, true)
expect(sim.o_ally_count[h] == 2, "an alliance ends: room again")
expect(sim:ally_request(h, ais[4]) == false, "no request to a full bot")
expect(sim:ally_request(h, ais[5]) == true and sim:has_request(h, ais[5]), "a request to a bot with room")
sim:form_alliance(h, ais[6])
expect(sim.o_ally_count[h] == 3, "the player fills up meanwhile")
sim:ally_reply(ais[5], h, true)
expect(not sim:allied(h, ais[5]) and not sim:has_request(h, ais[5]), "accepting past the cap is refused and the request closes")
for id = 1, sim.owner_total do
	if (sim.o_ally_count[id] or 0) > Rules.ALLY_MAX then
		expect(false, "nobody past the cap: " .. id)
	end
end
-- the AI plays on: no one ever goes past the cap
for _ = 1, 3000 do sim:step() end
local worst = 0
for id = 1, sim.owner_total do worst = math.max(worst, sim.o_ally_count[id] or 0) end
expect(worst <= Rules.ALLY_MAX, "after 3000 ticks of diplomacy the most alliances anyone holds is " .. worst)
-- Stars' first match bonus is a Common flag's price
local Flags = require("../../src/shared/Data/EmpireFlags")
local cheapest = math.huge
for _, f in Flags do if (f.stars or 0) > 0 then cheapest = math.min(cheapest, f.stars) end end
expect(Stars.FIRST_BONUS >= cheapest, string.format("first match bonus %d buys the cheapest flag (%d)", Stars.FIRST_BONUS, cheapest))
print(if fails == 0 then "all ok" else fails .. " FAILED")
