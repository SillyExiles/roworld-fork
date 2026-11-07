--!nocheck
-- Empires Front public lobbies in rounds (2026-11-07): the three kinds (PUBLIC MATCH, WORLD, the team
-- game) start together on multiples of LobbyRules.ROUND_S, World is always one of them (free for all
-- or teams, a round each), and every card a player sees shows the same round.
-- Run: .bin/lune run tests/ef/rounds.luau
local LobbyRules = require("../../src/server/Lobbies/LobbyRules")
local LobbyStore = require("../../src/server/Lobbies/LobbyStore")
local LobbyDirectory = require("../../src/server/Lobbies/LobbyDirectory")

local fails, total = 0, 0
local function expect(cond: any, what: string)
	total += 1
	if cond then
		print("  ok   " .. what)
	else
		fails += 1
		print("FAIL " .. what)
	end
end

local R = LobbyRules.ROUND_S
local clock = 100007 -- not on the grid
local function tnow()
	return clock
end

-- kinds: the three cards, in the title's order
do
	local m = {}
	for _, k in LobbyRules.kinds(true) do
		table.insert(m, k.mode)
	end
	expect(table.concat(m, ",") == "ffa,world,team", "kinds: " .. table.concat(m, ","))
end

-- the rotations leave World to its own card
do
	local maps = {
		{ id = "world", weight = 10 },
		{ id = "europe", weight = 5 },
	}
	for _, w in LobbyRules.public_weights(maps) do
		expect(w.id ~= "world", "free-for-all rotation: no World")
	end
	for _, w in LobbyRules.team_weights(maps) do
		expect(w.id ~= "world", "team rotation: no World")
	end
	expect(#LobbyRules.team_weights({ { id = "world", weight = 10 } }) == 1, "World alone: the team rotation still has a map")
end

-- missing_starts on the grid
do
	local s = LobbyRules.missing_starts({}, clock, "ffa", 1, nil, nil, R)
	expect(#s == 1 and s[1] % R == 0 and s[1] >= clock + LobbyRules.QUIET_LEAD_S, "a start on the grid: " .. tostring(s[1]))
	local open = { { id = "a", map = "x", max = 10, starts = s[1], created = clock, players = 0, status = "open" } }
	local t = LobbyRules.missing_starts(open, s[1] - 10, "world", 1, nil, nil, R)
	expect(#t == 1 and t[1] % R == 0, "another kind's lobby doesn't count")
	local u = LobbyRules.missing_starts(open, s[1] - 10, "ffa", 1, nil, nil, R)
	expect(#u == 1 and u[1] == s[1] + R, "the next round, one ROUND_S later")
	local hot = { rate = 5, size = 50 }
	local v = LobbyRules.missing_starts({}, clock, "ffa", 1, hot, nil, R)
	local grid = true
	for i, x in v do
		grid = grid and x % R == 0 and (i == 1 or x - v[i - 1] == R)
	end
	expect(#v >= 1 and grid, "busy: still on the grid, a round apart (" .. #v .. ")")
end

-- world_teams alternates
expect(LobbyRules.world_teams(R * 10) == false and LobbyRules.world_teams(R * 11) == true, "World: free for all, then teams")

-- the directory
local store = LobbyStore.localstore(tnow)
local reserved = 0
local function hub_new()
	return LobbyDirectory.new({
		store = store,
		teleport = {
			reserve = function()
				reserved += 1
				return "code" .. reserved, "psid" .. reserved
			end,
			send = function()
				return true
			end,
		},
		maps = function()
			return {
				{ id = "world", name = "World", weight = 30, land = 651569, k_lin = 1 },
				{ id = "europe", name = "Europe", weight = 10, land = 500000, k_lin = 1 },
				{ id = "persia", name = "Persia", weight = 10, land = 300000, k_lin = 1 },
			}
		end,
		now = tnow,
		rand = function()
			return 0.3
		end,
		new_id = (function()
			local n = 0
			return function()
				n += 1
				return "L" .. n
			end
		end)(),
		team_games = true,
	})
end
local hub = hub_new()
hub:refresh()
local by = {}
for _, l in hub:lobbies() do
	by[LobbyRules.mode_of(l)] = l
end
expect(by.ffa and by.world and by.team and #hub:lobbies() == 3, "three lobbies: " .. #hub:lobbies())
expect(by.ffa.starts == by.world.starts and by.world.starts == by.team.starts, "they start together")
expect(by.world.map == "world" and by.ffa.map ~= "world" and by.team.map ~= "world", "World on its card only")
expect(by.team.teams ~= nil, "the team game has teams")
expect((by.world.teams ~= nil) == LobbyRules.world_teams(by.world.starts), "World's teams follow its round")

-- later: the next round is made for every kind, together, and World flips
clock = by.ffa.starts - 15
hub:refresh()
local starts = {}
local worlds = {}
for _, l in hub:lobbies() do
	starts[l.starts] = (starts[l.starts] or 0) + 1
	if LobbyRules.mode_of(l) == "world" then
		worlds[l.starts] = l
	end
end
local rounds = 0
local all3 = true
for s, n in starts do
	rounds += 1
	all3 = all3 and n == 3 and s % R == 0
end
expect(rounds == 2 and all3, "two rounds of three, on the grid")
local w1, w2 = worlds[by.ffa.starts], worlds[by.ffa.starts + R]
expect(w1 and w2 and (w1.teams == nil) ~= (w2.teams == nil), "World: one round solo, the next teams")
local wraw = store.get(w2.id)
local back = LobbyRules.decode(wraw)
expect(back.mode == "world" and back.teams == w2.teams, "World's teams survive the store")
expect(LobbyRules.public_view(back, clock).teams == w2.teams, "...and reach the title")

-- every player's cards show one round
local same = 0
for i = 1, 40 do
	local v = hub:view_for("user" .. i)
	local first = {}
	for _, e in v do
		local k = e.mode or "ffa"
		if first[k] == nil and e.joinable then
			first[k] = e
		end
	end
	if first.ffa and first.world and first.team and first.ffa.starts_in == first.world.starts_in and first.world.starts_in == first.team.starts_in then
		same += 1
	end
end
expect(same == 40, "40 players: the three cards on the same round (" .. same .. ")")

-- a second hub sees the same lobbies and makes none
local hub2 = hub_new()
local before = reserved
hub2:refresh()
expect(reserved == before and #hub2:lobbies() == #hub:lobbies(), "a second hub: the same lobbies, no duplicates")

print(string.format("rounds: %d/%d", total - fails, total))
if fails > 0 then
	error(fails .. " FAILED")
end
