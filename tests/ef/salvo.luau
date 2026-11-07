--!nocheck
-- A salvo of bombards (2026-11-07): each bomb on its own spot of the target's land.
-- Run: .bin/lune run tests/ef/salvo.luau
local SimNukes = require("../../src/shared/Core/SimNukes")
local Defs = require("../../src/shared/Core/Defs")

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

local W, H = 200, 120
local N = W * H
local function make(owner_of)
	local owner = buffer.create(N * 4)
	local land = buffer.create(N)
	for t = 0, N - 1 do
		local o = owner_of(t % W, t // W)
		if o ~= nil then
			buffer.writeu8(land, t, 1)
			buffer.writei32(owner, t * 4, o)
		end
	end
	local C = {
		W = W,
		H = H,
		N = N,
		owner = owner,
		land = land,
		team_mode = false,
		R = { nuke_radii = function(_k)
			return 4, 10
		end },
		range_d2 = function(a, b)
			local dx, dy = a % W - b % W, a // W - b // W
			return dx * dx + dy * dy
		end,
	}
	SimNukes.install(C)
	return C
end

-- a big enemy (2) on the right half, us (1) on the left
local big = make(function(x, _y)
	return if x < 60 then 1 else 2
end)
local aim = 60 * W + 130
for _, n in { 2, 3, 5, 12 } do
	local ts = big:salvo_targets("atom", aim, n, 1)
	local distinct, inside, apart = true, true, true
	local seen = {}
	for i, t in ts do
		if seen[t] then
			distinct = false
		end
		seen[t] = true
		inside = inside and buffer.readi32(big.owner, t * 4) == 2
		for j = 1, i - 1 do
			if big.range_d2(t, ts[j]) < (12 * 0.8) ^ 2 - 0.01 then
				apart = false
			end
		end
	end
	expect(#ts == n and ts[1] == aim, n .. " bombs, the first at the aim")
	expect(distinct and inside and apart, n .. " bombs: distinct spots of the enemy's land, apart")
end

-- a small enemy island (radius 8): what doesn't fit goes to the aim
local small = make(function(x, y)
	local dx, dy = x - 100, y - 60
	if dx * dx + dy * dy <= 64 then
		return 3
	end
	return if x < 40 then 1 else nil
end)
local ts = small:salvo_targets("atom", 60 * W + 100, 5, 1)
local on = true
for _, t in ts do
	on = on and buffer.readi32(small.owner, t * 4) == 3
end
expect(#ts == 5 and on, "a small territory: all five still on it")

-- deterministic
local a = big:salvo_targets("hydrogen", aim, 4, 1)
local b = big:salvo_targets("hydrogen", aim, 4, 1)
expect(table.concat(a, ",") == table.concat(b, ","), "the same spots every time")

print(string.format("salvo: %d/%d", total - fails, total))
if fails > 0 then
	error(fails .. " FAILED")
end
