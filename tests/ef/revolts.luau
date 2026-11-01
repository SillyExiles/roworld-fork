-- Empires Front (2026-11-01): unrest, warnings, revolts and rebels (Core/SimRevolts).
-- usage: luau tests/ef/revolts.luau [ticks]
task = { spawn = function(f, ...) f(...) end, wait = function() end }
local WorldMap = require("../../src/shared/Core/WorldMap")
WorldMap.put_data("rome", require("./rome_raw"))
local Sim = require("../../src/shared/Core/Sim")
local Defs = require("../../src/shared/Core/Defs")
local Rules = require("../../src/shared/Core/Rules")
local Ev = require("../../src/shared/Core/Ev")
local SimRevolts = require("../../src/shared/Core/SimRevolts")
local GameState = require("../../src/shared/Core/GameState")
local Protocol = require("../../src/shared/Net/Protocol")

local fails = 0
local function expect(c, w)
	print((if c then "  ok   " else "FAIL ") .. w)
	if not c then
		fails += 1
	end
end
local map = WorldMap.get("rome")

-- 1) a whole AI match: warnings come before every revolt; some calm down
local sim = Sim.new(map, { seed = 11, difficulty = 2, tribes = 60, max_humans = 0 })
local warned, calmed, rose, free = 0, 0, 0, 0
local warned_ids = {}
local orig_msg = sim.msg
sim.msg = function(self, to, cat, text)
	if string.find(text, "^Unrest in") or string.find(text, "calmed down") then
		calmed += 1 -- (secret: none of these may be sent)
	end
	orig_msg(self, to, cat, text)
end
local orig_rev = sim._revolt
local unwarned = 0
sim._revolt = function(self, id, t, prov)
	if (warned_ids[id] or 0) == 0 then
		unwarned += 1
	end
	local ok = orig_rev(self, id, t, prov)
	if ok then
		rose += 1
	end
	return ok
end
local ticks = tonumber((...)) or 9000
local evs = {}
local seen_warn = {}
local unrest_events = 0
for _ = 1, ticks do
	local d = sim:step()
	-- (the warnings are secret now: SimRevolts.SECRET; read them from the state)
	local rv = sim._rv
	if rv ~= nil then
		for wid, w in rv.warn do
			local key = wid .. ":" .. w.at
			if not seen_warn[key] then
				seen_warn[key] = true
				warned += 1
				warned_ids[wid] = (warned_ids[wid] or 0) + 1
			end
		end
	end
	for _, e in d.ev or {} do
		if e[1] == Ev.UNREST then
			unrest_events += 1
		end
		if e[1] == Ev.REBEL then
			table.insert(evs, e)
			if e[5] == SimRevolts.FREE then
				free += 1
			end
		end
	end
end
print(string.format("AI match %d ticks: %d hidden warnings, %d revolts, %d free nations", ticks, warned, rose, free))
expect(calmed == 0, "secret: no warning or calm-down messages")
expect(unwarned == 0, "no revolt without a (hidden) warning first")
expect(unrest_events == 0, "secret: no unrest is sent to players")
local secret_msgs = 0
expect(rose <= warned, "revolts never outnumber warnings")
local s = sim._rv
expect(s ~= nil and next(s.unrest) ~= nil, "unrest is computed")
local maxu = 0
for _, u in s.unrest do
	maxu = math.max(maxu, u)
end
print("highest unrest at the end", maxu)

-- 2) the first match: no revolts at all
local calm = Sim.new(map, { seed = 11, difficulty = 2, tribes = 60, max_humans = 0, revolts = false })
for _ = 1, 4000 do
	calm:step()
end
expect(calm._rv == nil, "revolts = false: no unrest, no revolts")

-- 3) a revolt by hand on a big empire, then the three ways out
local function biggest(sm)
	local best, bt = 0, 0
	for id = 1, sm.owner_total do
		if sm.o_alive[id] == 1 and sm.o_kind[id] ~= Defs.KIND_TRIBE and sm.o_tiles[id] > bt then
			best, bt = id, sm.o_tiles[id]
		end
	end
	return best
end
local function fresh_revolt(seed)
	local sm = Sim.new(map, { seed = seed, difficulty = 2, tribes = 60, max_humans = 0 })
	for _ = 1, 2500 do
		sm:step()
	end
	local id = biggest(sm)
	local epi = sm:_far_province(id)
	local before = sm.owner_total
	local ok = sm:_revolt(id, epi, "Testland")
	return sm, id, if ok then sm.owner_total else 0, before
end

local sm, id, rid = fresh_revolt(5)
do
	local nm = sm:_province_name(id, sm:_far_province(id))
	print("  province name:", nm, "(empire " .. sm.o_name[id] .. ")")
	expect(nm ~= sm.o_name[id], "a province is not named like its empire")
	local alive_named = false
	for o = 1, sm.owner_total do
		if sm.o_alive[o] == 1 and sm.o_name[o] == nm then
			alive_named = true
		end
	end
	expect(not alive_named, "nor like any living owner")
end
expect(rid > 0, "a revolt makes a rebel band")
expect(sm.o_name[rid] == "Testland Rebels", "named after the province: " .. tostring(sm.o_name[rid]))
expect(sm.o_color[rid] == SimRevolts.rebel_color(sm.o_color[id]), "a darker shade of the empire's colour")
expect(sm.o_color[rid] ~= Defs.html_rgba("#8a5a44"), "not the old brown")
local r = sm._rv.rebels[rid]
expect(r ~= nil and r.parent == id and r.state == SimRevolts.RISING, "the band is recorded as rising")

-- buy back
local price = sm:rebel_price_of(rid)
do
	local total, land, tg, bg = sm:rebel_value(rid)
	print(string.format("  worth %d = land %d + troops %d + buildings %d (%d tiles, %.2f%% of the map, %d troops)", total, land, tg, bg, sm.o_tiles[rid], 100 * sm.o_tiles[rid] / sm.map.contestable_count, sm.o_troops[rid]))
	expect(price == total and price >= Rules.REBEL_PRICE_MIN, "the price is the province's worth: " .. price)
	expect(land > 0 and tg > 0, "land and troops both count")
end
sm.o_gold[id] = price - 1
expect(not sm:pay_rebels(id, rid), "too little gold: no deal")
sm.o_gold[id] = price + 5
local tiles_before = sm.o_tiles[id]
local rt = sm.o_tiles[rid]
expect(sm:pay_rebels(id, rid), "bought back")
expect(sm.o_tiles[rid] == 0 and sm.o_tiles[id] == tiles_before + rt, "the province returns")
expect(sm.o_gold[id] == 5, "paid the price")
sm:step()
expect(sm.o_alive[rid] == 0 and r.state == SimRevolts.PAID, "the band is gone, marked bought back")

-- recognize: a free nation, allied with its old empire
local sr, idr, ridr = fresh_revolt(7)
expect(sr:recognize_rebels(idr, ridr), "recognized")
local rr = sr._rv.rebels[ridr]
expect(rr.state == SimRevolts.FREE and sr.o_kind[ridr] == Defs.KIND_NATION, "a free nation at once")
expect(sr:allied(ridr, idr), "allied with the empire that let it go")
expect(not sr:recognize_rebels(idr, ridr), "only once")

-- crush in time
local sc, idc, ridc = fresh_revolt(6)
local gold0 = sc.o_gold[idc]
local rc = sc._rv.rebels[ridc]
for t = 0, sc.N - 1 do
	if buffer.readi32(sc.owner, t * 4) == ridc then
		sc.o_killer[ridc] = idc
		sc:set_owner(t, idc)
	end
end
sc:step()
expect(rc.state == SimRevolts.CRUSHED, "crushed by its own empire in time")
expect(sc.o_gold[idc] >= gold0 + Rules.REBEL_CRUSH_MIN, "the crush reward is paid")

-- free nation after FREE_TICKS
local sf, idf, ridf = fresh_revolt(8)
local rf = sf._rv.rebels[ridf]
-- (as if 3 min had gone by: the next unrest tick frees them)
rf.born = sf.tick - SimRevolts.FREE_TICKS
for _ = 1, SimRevolts.PERIOD do
	sf:step()
end
expect(sf.o_alive[ridf] == 1 and rf.state == SimRevolts.FREE, "alive after 3 min: a free nation")
expect(sf.o_kind[ridf] == Defs.KIND_NATION, "now a nation")
expect(string.sub(sf.o_name[ridf], 1, 5) == "Free ", "named Free ...: " .. sf.o_name[ridf])
expect(sf.o_skill[ridf] == SimRevolts.FREE_SKILL, "plays at Hard")
for _ = 1, 600 do
	sf:step()
end
expect(sf.o_alive[ridf] == 0 or sf.o_tiles[ridf] > 0, "the free nation plays on as a nation (no error)")

-- 4) structures calm a province
local sp, idp = fresh_revolt(9)
local epi = sp:_far_province(idp)
local c0 = sp:_province_calm(idp, epi)
local st = sp:add_struct(Defs.S_DEFENSE, idp, epi)
st.active_tick = sp.tick
local c1 = sp:_province_calm(idp, epi)
expect(c1 >= c0 + SimRevolts.CALM_POST - 0.01 or c0 >= SimRevolts.CALM_POST, "a Defense Post calms the province (" .. c0 .. " -> " .. c1 .. ")")
sp.o_troops[idp] = 0
local u_low = sp:unrest_of(idp, epi)
sp.o_troops[idp] = sp.o_cap[idp]
local u_full = sp:unrest_of(idp, epi)
expect(u_low > u_full + 30, "an empty army is restless (" .. math.floor(u_low) .. " vs " .. math.floor(u_full) .. ")")

-- 5) the wire: the pay intent, and the mirror learns the rebels and a player's unrest
local b = Protocol.encode_intent({ type = "pay_rebels", target = 42 })
local back = b and Protocol.decode_intent(b)
expect(back ~= nil and back.type == "pay_rebels" and back.target == 42, "pay_rebels intent round trip")
local gs = GameState.new()
local sm2, id2, rid2 = fresh_revolt(10)
gs:load_snapshot(sm2:snapshot())
expect(gs.owners[rid2] and gs.owners[rid2].rebel_of == id2, "snapshot: the mirror knows the rebels' empire")
expect(gs.owners[rid2].rebel_price == sm2:rebel_price_of(rid2) and gs.owners[rid2].rebel_land > 0, "snapshot: the mirror knows their price")
local b2 = Protocol.encode_intent({ type = "recognize_rebels", target = 7 })
local back2 = b2 and Protocol.decode_intent(b2)
expect(back2 ~= nil and back2.type == "recognize_rebels" and back2.target == 7, "recognize_rebels intent round trip")
gs:_set_unrest({ Ev.UNREST, id2, 73, 1234, 999, "Testland", 30, 10, 5, 8, 20, 0 }, 1)
expect(gs.owners[id2].unrest == 73 and gs.owners[id2].unrest_prov == "Testland" and gs.owners[id2].unrest_at == 999, "Ev.UNREST fills the owner")

print(if fails == 0 then "all ok" else (fails .. " failed"))
