-- Empires Front (2026-11-01): the ecosystem (Farm, Temple, Palace, Fortress, University).
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
local id, bt = 0, 0
for o = 1, sim.owner_total do
	if sim.o_alive[o] == 1 and sim.o_kind[o] == Defs.KIND_NATION and sim.o_tiles[o] > bt then id, bt = o, sim.o_tiles[o] end
end
sim.o_ai[id] = 0 -- (hold its hand: no AI builds in the way)
print("nation", sim.o_name[id], "tiles", bt)
local own = {}
for t = 0, sim.N - 1 do
	if buffer.readi32(sim.owner, t * 4) == id then table.insert(own, t) end
end
local function finish()
	for _ = 1, 210 do sim:step() end
end
local function build(kind, pick)
	sim.o_gold[id] += 1e8
	for i = 1, #own, math.max(1, #own // 400) do
		local t = own[i]
		if (pick == nil or pick(t)) and sim:valid_site(id, kind, t) then
			local before = sim:struct_count(id, kind)
			sim:try_build(id, Defs.STRUCT_NAMES[kind], t)
			if sim:struct_count(id, kind) > before then
				return t
			end
		end
	end
	return -1
end
local function high(t) return buffer.readu8(sim.terr, t) >= Defs.T_HIGHLAND end
local function low(t) return buffer.readu8(sim.terr, t) < Defs.T_HIGHLAND end

-- Farm: the troop cap
local cap0 = sim.o_cap[id]
local farm = build(Defs.S_FARM)
finish()
expect(farm >= 0 and sim.o_farm_mult[id] > 1.0, "a Farm raises the troop cap (x" .. string.format("%.3f", sim.o_farm_mult[id]) .. ")")
expect(sim.o_cap[id] > cap0, "the cap grew: " .. math.floor(cap0) .. " -> " .. math.floor(sim.o_cap[id]))
local fm1 = sim.o_farm_mult[id]
-- Temple next to it: the harvest is blessed
local temple = build(Defs.S_TEMPLE, function(t) return sim.range_d2(t, farm) < (sim.R.temple_range(1) * 0.8) ^ 2 end)
finish()
expect(temple >= 0, "a Temple near the Farm")
expect(sim.o_farm_mult[id] > fm1 + 0.001, string.format("blessed harvest: x%.3f -> x%.3f", fm1, sim.o_farm_mult[id]))
expect(sim.o_temple_levels[id] >= 1, "temple levels counted")
-- University: income, more near the Palace
local inc0 = sim:_income_of(id)
local uni = build(Defs.S_UNIVERSITY, function(t) return sim.range_d2(t, temple) > (sim.R.temple_range(1) + 5) ^ 2 end)
finish()
expect(uni >= 0 and sim.o_uni_mult[id] > 1.0, "a University raises the income (x" .. string.format("%.3f", sim.o_uni_mult[id]) .. ")")
local um1 = sim.o_uni_mult[id]
expect(sim:_income_of(id) > inc0, "income " .. math.floor(inc0) .. " -> " .. math.floor(sim:_income_of(id)))
-- Palace near the University: taxes and patronage
local tax0 = sim:_income_of(id)
local pal = build(Defs.S_PALACE, function(t) return sim.range_d2(t, uni) < (sim.R.palace_range() - 5) ^ 2 end)
finish()
expect(pal >= 0 and sim.o_palace[id] == pal, "the Palace stands")
expect(sim.o_uni_mult[id] > um1, string.format("royal patronage: University x%.3f -> x%.3f", um1, sim.o_uni_mult[id]))
expect(sim:_income_of(id) > tax0, "Palace taxes: income " .. math.floor(tax0) .. " -> " .. math.floor(sim:_income_of(id)))
expect(build(Defs.S_PALACE) < 0, "one Palace only")
-- the Palace's region never revolts; a Temple calms
expect(sim:_province_calm(id, pal) >= 100, "a province by the Palace never rises")
local far = -1
local pr = sim.R.palace_range()
for _, t in own do
	if sim.range_d2(t, pal) > (pr * 1.5) ^ 2 and sim.range_d2(t, temple) > (sim.R.temple_range(1) * 1.5) ^ 2 then far = t break end
end
if far >= 0 then
	local c0 = sim:_province_calm(id, far)
	local t2 = build(Defs.S_TEMPLE, function(t) return sim.range_d2(t, far) < (sim.R.temple_range(1) * 0.6) ^ 2 end)
	finish()
	expect(t2 >= 0 and sim:_province_calm(id, far) >= c0 + Rules.CALM_TEMPLE, "a Temple calms its province")
end
expect(sim:_empire_calm(id) >= Rules.PALACE_EMPIRE_CALM + Rules.TEMPLE_EMPIRE_CALM, "empire-wide calm: " .. sim:_empire_calm(id))
-- Fortress: high ground only, stronger than a post
expect(build(Defs.S_FORTRESS, low) < 0, "no Fortress on low ground")
local fort = build(Defs.S_FORTRESS, high)
finish()
if fort >= 0 then
	expect(sim:_cover_strength(fort, id) == 2, "a Fortress guards its land (strength 2)")
	expect(Rules.FORTRESS_MAG > Rules.DEFENSE_POST_MAG, "stronger than a defense post")
else
	print("  (no hills here for a Fortress)")
end
-- the Palace taken: razed, looted, the empire shaken
local enemy = 0
for o = 1, sim.owner_total do
	if o ~= id and sim.o_alive[o] == 1 and sim.o_kind[o] == Defs.KIND_NATION then enemy = o break end
end
sim.o_gold[id] = 1000000
local eg = sim.o_gold[enemy]
local fresh0 = sim._rv and sim._rv.fresh[id] or 0
local ep = sim:struct_count(enemy, Defs.S_PALACE)
sim:set_owner(pal, enemy)
expect(sim:struct_count(id, Defs.S_PALACE) == 0 and sim:struct_count(enemy, Defs.S_PALACE) == ep, "a taken Palace is razed")
expect(sim.o_gold[enemy] >= eg + 250000 - 1, "the conqueror loots a quarter of the gold")
expect((sim._rv.fresh[id] or 0) > fresh0, "the empire is shaken")
print(if fails == 0 then "all ok" else (fails .. " failed"))
