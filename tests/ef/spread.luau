local LobbyRules = require("../../src/server/Lobbies/LobbyRules")
local now = 1000000
local function L(id, players, max, starts_in)
	return { id = id, map = "rome", map_name = "Rome", max = max, starts = now + starts_in, created = now - 10, players = players, status = "open" }
end
local list = { L("A", 46, 50, 20), L("B", 12, 50, 60), L("C", 0, 50, 85) }
local first = { A = 0, B = 0, C = 0 }
for u = 1, 1000 do
	local o = LobbyRules.spread(list, tostring(1000000 + u * 7919), now)
	first[o[1].id] += 1
end
print("1000 players see first: A (46/50, soon)", first.A, " B (12/50)", first.B, " C (0/50)", first.C)
-- simulate joins: each player joins their first lobby with room, lobbies fill in turn
local joined = { A = 0, B = 0, C = 0 }
for u = 1, 120 do
	local o = LobbyRules.spread(list, tostring(5000000 + u * 104729), now)
	for _, l in o do
		if l.players < l.max then
			l.players += 1
			joined[l.id] += 1
			break
		end
	end
end
print("after 120 joins:", list[1].players, list[2].players, list[3].players)
