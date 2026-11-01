--!strict
-- Empires Front (2026-11-01): unrest and revolts (replaces SimAttacks' first revolts of 2026-10-31).
--
-- Every PERIOD ticks each empire (nations and players; never tribes) gets an unrest score 0..100:
--   + troops      W_TROOPS × how far its troops are under LOW_TROOPS of its cap (the main cause)
--   + size        W_SIZE × its land share from 3% to 25%
--   ± lead        +W_LEAD for the land leader (at 8%+); down to −W_LEAD for empires far behind it
--   + far         W_FAR × how far its far province lies from the capital (in empire radii)
--   + fresh       W_FRESH × the land taken lately (a decaying sum, against its size)
--   − calm        at the far province: CALM_TOWN per City / Market (2 at most), CALM_POST for a
--                 Defense Post, CALM_ROAD when a structure there is linked by road
-- The far province is the border tile farthest from the capital (a little noise, the same for a
-- minute). At WARN_AT or more (an empire with MIN_SHARE+ of the land, FROM_TICKS into play, COOLDOWN
-- since its last revolt) the province is warned: WARN_TICKS later, still at RISE_AT or more, it rises
-- (the province's land and TROOPS of the army break away as "<province> Rebels", a tribe in a darker
-- shade of the empire's colour); under it, the unrest calms down. Provinces are named after the
-- map's nations (the nearest within reach whose name no living owner wears), else by the side of the
-- empire they lie on ("Northern Rome").
-- Rebels: crushed by their empire within CRUSH_TICKS pays Rules.rebel_crush_gold; bought back with
-- gold (the "pay_rebels" intent, Rules.rebel_price) returns the province and half the rebels; alive
-- after FREE_TICKS they become the free nation "Free <province>" (an AI nation at FREE_SKILL) that
-- allies with the strongest empire at war with their old one.
-- Players see their own unrest (Ev.UNREST, snapshot `unrest`); everyone sees the rebels (Ev.REBEL,
-- snapshot `rebels`). A match with `revolts = false` in its config (the first match) has none.
local Defs = require("./Defs")
local Ev = require("./Ev")
local Rules = require("./Rules")
local NumberFormat = require("./NumberFormat")
local Coop = require("../Net/Coop")

local readi32 = buffer.readi32

local SimRevolts = {}

SimRevolts.PERIOD = 50
SimRevolts.FROM_TICKS = 3000
SimRevolts.MIN_SHARE = 0.05
SimRevolts.WARN_AT = 60
SimRevolts.RISE_AT = 50
SimRevolts.WARN_TICKS = 300
SimRevolts.COOLDOWN = 1800
--- After a warning that calmed down, the next one waits at least this long.
SimRevolts.CALM_COOLDOWN = 600
SimRevolts.MAX = 40
--- The rebels take about this share of the empire's tiles and of its troops.
SimRevolts.SHARE = 0.08
SimRevolts.TROOPS = 0.25
SimRevolts.CRUSH_TICKS = 1200
SimRevolts.FREE_TICKS = 1800
SimRevolts.FREE_SKILL = 2
--- Unrest weights (see the header).
SimRevolts.LOW_TROOPS = 0.5
SimRevolts.W_TROOPS = 55
SimRevolts.W_SIZE = 25
SimRevolts.W_LEAD = 15
SimRevolts.W_FAR = 15
SimRevolts.W_FRESH = 20
SimRevolts.CALM_TOWN = 8
SimRevolts.CALM_POST = 15
SimRevolts.CALM_ROAD = 10
--- Rebel states (Ev.REBEL): rising, crushed, bought back, a free nation, gone (taken by others).
SimRevolts.RISING = 0
SimRevolts.CRUSHED = 1
SimRevolts.PAID = 2
SimRevolts.FREE = 3
SimRevolts.GONE = 4

--- The unrest parts, in the order Ev.UNREST carries them.
SimRevolts.PARTS = { "troops", "size", "lead", "far", "fresh", "calm" }

local function clamp01(v: number): number
	return if v < 0 then 0 elseif v > 1 then 1 else v
end

--- A darker shade of an owner's colour (0xRRGGBBAA): the rebels'.
function SimRevolts.rebel_color(rgba: number): number
	local r = (rgba // 0x1000000) % 256
	local g = (rgba // 0x10000) % 256
	local b = (rgba // 0x100) % 256
	local a = rgba % 256
	local function dk(c: number): number
		-- darker and a little greyer, so the rebels read as the empire's own land gone wrong
		local grey = (r + g + b) / 3
		return math.clamp(math.floor((c * 0.75 + grey * 0.25) * 0.55), 0, 255)
	end
	return ((dk(r) * 256 + dk(g)) * 256 + dk(b)) * 256 + a
end

function SimRevolts.install(C: any)
	local function rv(self: any): any
		local s = self._rv
		if s == nil then
			s = {
				unrest = {} :: { [number]: number },
				parts = {} :: { [number]: { number } },
				sent = {} :: { [number]: string },
				epi = {} :: { [number]: number },
				epi_at = {} :: { [number]: number },
				fresh = {} :: { [number]: number },
				last_tiles = {} :: { [number]: number },
				warn = {} :: { [number]: any },
				last = {} :: { [number]: number },
				n = 0,
				rebels = {} :: { [number]: any },
				provs = nil :: { any }?,
			}
			self._rv = s
		end
		return s
	end
	C._revolt_state = rv

	function C.revolts_on(self: any): boolean
		return self.revolts ~= false and self.no_revolts ~= true
	end

	--- A person (not a bot player) sees their unrest.
	local function shown(self: any, id: number): boolean
		return self.o_kind[id] == Defs.KIND_HUMAN and self.o_bot[id] ~= 1
	end

	-- =========================================================================================
	-- Provinces
	-- =========================================================================================

	local function provinces(self: any, s: any): { any }
		if s.provs == nil then
			local out = {}
			local ok, list = pcall(function()
				return self.map:load_nations()
			end)
			if ok and type(list) == "table" then
				for _, nd in list do
					local t = if type(nd) == "table" then tonumber(nd.tile) or -1 else -1
					if t >= 0 and t < self.N then
						table.insert(out, { name = tostring(nd.name), tile = t })
					end
				end
			end
			s.provs = out
		end
		return s.provs
	end

	local DIRS = { "Eastern", "Southeastern", "Southern", "Southwestern", "Western", "Northwestern", "Northern", "Northeastern" }

	--- The province at tile `t` of empire `id`: the nearest map nation within the empire's reach whose
	--- name no living owner wears (a nation it swallowed, or one never in play); else the side of the
	--- empire it lies on ("Northern Rome").
	function C._province_name(self: any, id: number, t: number): string
		local s = rv(self)
		local worn = {}
		for o = 1, self.owner_total do
			if self.o_alive[o] == 1 then
				worn[self.o_name[o]] = true
			end
		end
		local range_d2 = self.range_d2
		local reach = 2.5 * math.sqrt(math.max(self.o_tiles[id], 1) / math.pi) + 20
		local best, bd = nil, reach * reach
		for _, p in provinces(self, s) do
			if worn[p.name] then
				continue
			end
			local d = range_d2(p.tile, t)
			if d < bd then
				best, bd = p.name, d
			end
		end
		if best ~= nil then
			return best
		end
		local cap = self.o_spawn_tile[id]
		if cap < 0 then
			return "Outer " .. self.o_name[id]
		end
		local W = self.W
		local dx = t % W - cap % W
		local dy = t // W - cap // W
		if math.abs(dx) > W / 2 then
			dx -= if dx > 0 then W else -W
		end
		-- (rows grow southwards: north is -y)
		local a = math.atan2(dy, dx)
		local k = math.floor((a / (2 * math.pi)) * 8 + 0.5) % 8
		return DIRS[k + 1] .. " " .. self.o_name[id]
	end

	--- The border tile of `id` farthest from its capital (the centroid without one), with a little
	--- noise that changes once a minute. -1: none.
	function C._far_province(self: any, id: number): number
		local tiles = self.o_tiles[id]
		if tiles <= 0 then
			return -1
		end
		local W = self.W
		local cap = self.o_spawn_tile[id]
		local range_d2 = self.range_d2
		local cx = self.o_cx[id] / tiles
		local cy = self.o_cy[id] / tiles
		local salt = (self.tick // 600) * 0.618 + id * 1.37
		local best, bd = -1, -1.0
		local t = self.bhead[id]
		local seen = 0
		while t ~= -1 do
			local d
			if cap >= 0 then
				d = range_d2(t, cap)
			else
				local dx, dy = t % W - cx, t // W - cy
				d = dx * dx + dy * dy
			end
			local h = math.sin(t * 12.9898 + salt) * 43758.5453
			h -= math.floor(h)
			d *= 0.75 + 0.5 * h
			if d > bd then
				best, bd = t, d
			end
			seen += 1
			if seen % 4096 == 0 then
				Coop.check()
			end
			t = readi32(self.bnext, t * 4)
		end
		return best
	end

	--- How far the rebels' province reaches around its centre (tiles), and the calm's reach.
	local function province_radius(self: any, id: number): number
		local want = math.max(12, math.floor(self.o_tiles[id] * SimRevolts.SHARE))
		return math.clamp(math.sqrt(want / math.pi) * 1.25, 3.0, 80.0)
	end

	--- The calm `id`'s structures bring to the province around `epi` (points off its unrest).
	function C._province_calm(self: any, id: number, epi: number): number
		local rc = province_radius(self, id) * 1.6 + 6.0
		local rc2 = rc * rc
		local range_d2 = self.range_d2
		local towns, post, road = 0, false, false
		local tick = self.tick
		for _, st in self:structs_in_box(epi, self.geo_span(epi, rc), math.ceil(rc)) do
			if st.owner ~= id or st.active_tick > tick or range_d2(st.tile, epi) > rc2 then
				continue
			end
			local k = st.kind
			if k == Defs.S_CITY or k == Defs.S_MARKET then
				towns += 1
			elseif k == Defs.S_DEFENSE then
				post = true
			end
			if type(st.roads) == "table" and #st.roads > 0 then
				road = true
			end
		end
		return math.min(towns, 2) * SimRevolts.CALM_TOWN
			+ (if post then SimRevolts.CALM_POST else 0)
			+ (if road then SimRevolts.CALM_ROAD else 0)
	end

	-- =========================================================================================
	-- Unrest
	-- =========================================================================================

	--- (unrest 0..100, its parts (SimRevolts.PARTS order, rounded), the far province or -1).
	--- `epi`: the province to judge (a warned one); else the empire's far province (cached a while).
	function C.unrest_of(self: any, id: number, epi: number?): (number, { number }, number)
		local s = rv(self)
		local tiles = self.o_tiles[id]
		local cap = self.o_cap[id] or 0.0
		local ratio = if cap > 0 then self.o_troops[id] / cap else 1.0
		local p_troops = clamp01((SimRevolts.LOW_TROOPS - ratio) / SimRevolts.LOW_TROOPS) * SimRevolts.W_TROOPS
		local share = self:land_share(id)
		local p_size = clamp01((share - 0.03) / 0.22) * SimRevolts.W_SIZE
		local p_lead = 0.0
		local ai = self.ai
		local lshare = if ai ~= nil then tonumber(ai.leader_share) or 0.0 else 0.0
		if ai ~= nil and ai.leader == id and share >= 0.08 then
			p_lead = SimRevolts.W_LEAD
		elseif lshare > 0 then
			p_lead = -SimRevolts.W_LEAD * clamp01(1 - share / lshare)
		end
		local p_fresh = clamp01(((s.fresh[id] or 0) / math.max(tiles, 1)) / 0.35) * SimRevolts.W_FRESH
		local base = p_troops + p_size + p_lead + p_fresh
		local t = epi or -1
		if t < 0 and base >= 20 then
			t = s.epi[id] or -1
			if t < 0 or self.tick - (s.epi_at[id] or -100000) >= 300 or readi32(self.owner, t * 4) ~= id then
				t = self:_far_province(id)
				s.epi[id] = t
				s.epi_at[id] = self.tick
			end
		end
		local p_far, calm = 0.0, 0.0
		if t >= 0 then
			local capital = self.o_spawn_tile[id]
			if capital >= 0 then
				local reff = math.max(math.sqrt(tiles / math.pi), 1.0)
				p_far = clamp01((math.sqrt(self.range_d2(t, capital)) / reff - 1.2) / 1.8) * SimRevolts.W_FAR
			end
			calm = self:_province_calm(id, t)
		end
		local total = math.clamp(base + p_far - calm, 0, 100)
		local r = math.floor
		return total,
			{ r(p_troops + 0.5), r(p_size + 0.5), r(p_lead + 0.5), r(p_far + 0.5), r(p_fresh + 0.5), r(calm + 0.5) },
			t
	end

	--- {id, unrest, province tile (-1), warned until tick (0), province name, parts...}: Ev.UNREST's body
	--- and a snapshot row.
	function C._unrest_row(self: any, id: number): { any }
		local s = rv(self)
		local w = s.warn[id]
		local p = s.parts[id] or { 0, 0, 0, 0, 0, 0 }
		return {
			id,
			math.floor((s.unrest[id] or 0) + 0.5),
			if w ~= nil then w.tile else (s.epi[id] or -1),
			if w ~= nil then w.at else 0,
			if w ~= nil then w.name else "",
			p[1],
			p[2],
			p[3],
			p[4],
			p[5],
			p[6],
		}
	end

	local function send_unrest(self: any, s: any, id: number)
		if not shown(self, id) then
			return
		end
		local row = self:_unrest_row(id)
		local key = table.concat(row, ",", 2)
		if s.sent[id] == key then
			return
		end
		s.sent[id] = key
		local e = { Ev.UNREST }
		table.move(row, 1, #row, 2, e)
		self:ev(e)
	end

	--- Every tick (SimAttacks.attacks_tick): the unrest of every empire each PERIOD ticks, its warnings
	--- and revolts, and the rebels' time.
	function C._unrest_tick(self: any)
		if self.tick % SimRevolts.PERIOD ~= 0 or not self:revolts_on() then
			return
		end
		local since = self.playing_since or -1
		if since < 0 then
			return
		end
		local s = rv(self)
		self:_rebels_tick(s)
		local can_rise = self.tick - since >= SimRevolts.FROM_TICKS and s.n < SimRevolts.MAX
		local o_alive, o_spawned, o_kind, o_tiles = self.o_alive, self.o_spawned, self.o_kind, self.o_tiles
		local owner = self.owner
		local rate = Rules.TICK_RATE
		for id = 1, self.owner_total do
			if o_alive[id] == 0 or o_spawned[id] == 0 or o_kind[id] == Defs.KIND_TRIBE or o_tiles[id] < 40 then
				if s.unrest[id] ~= nil then
					s.unrest[id] = nil
					s.parts[id] = nil
					s.warn[id] = nil
					s.epi[id] = nil
					send_unrest(self, s, id)
				end
				continue
			end
			local tiles = o_tiles[id]
			local last = s.last_tiles[id] or tiles
			s.fresh[id] = (s.fresh[id] or 0) * 0.85 + math.max(0, tiles - last)
			s.last_tiles[id] = tiles
			local w = s.warn[id]
			local fixed = nil
			if w ~= nil and readi32(owner, w.tile * 4) == id then
				fixed = w.tile
			end
			local u, parts, epi = self:unrest_of(id, fixed)
			s.unrest[id] = u
			s.parts[id] = parts
			if w ~= nil then
				if self.tick >= w.at then
					s.warn[id] = nil
					if u >= SimRevolts.RISE_AT and epi >= 0 then
						s.last[id] = self.tick
						if self:_revolt(id, epi, w.name) then
							s.n += 1
						end
					else
						s.last[id] = self.tick - SimRevolts.COOLDOWN + SimRevolts.CALM_COOLDOWN
						self:msg(id, Defs.MSG_GOOD, string.format("The unrest in %s has calmed down", w.name))
					end
				end
			elseif
				can_rise
				and u >= SimRevolts.WARN_AT
				and epi >= 0
				and self:land_share(id) >= SimRevolts.MIN_SHARE
				and self.tick - (s.last[id] or -1000000) >= SimRevolts.COOLDOWN
			then
				local name = self:_province_name(id, epi)
				s.warn[id] = { tile = epi, at = self.tick + SimRevolts.WARN_TICKS, name = name }
				self:msg(
					id,
					Defs.MSG_ALERT,
					string.format(
						"Unrest in %s! It revolts in %d s: raise your troops, or calm it with a City, Market, Defense Post or a road",
						name,
						SimRevolts.WARN_TICKS // rate
					)
				)
			end
			send_unrest(self, s, id)
			if id % 16 == 0 then
				Coop.check()
			end
		end
	end

	-- =========================================================================================
	-- Revolts
	-- =========================================================================================

	--- The province around `best` rises against `id` as "<name> Rebels". True when rebels took land.
	function C._revolt(self: any, id: number, best: number, prov: string?): boolean
		local tiles = self.o_tiles[id]
		if tiles < 40 or best < 0 then
			return false
		end
		local owner = self.owner
		local want = math.max(12, math.floor(tiles * SimRevolts.SHARE))
		local r = province_radius(self, id)
		local take: { number } = {}
		for _, c in self:disk_tiles(best, r, true) do
			if readi32(owner, c * 4) == id then
				take[#take + 1] = c
			end
		end
		if #take < 8 then
			return false
		end
		local range_d2 = self.range_d2
		table.sort(take, function(a, b)
			local da, db = range_d2(a, best), range_d2(b, best)
			if da ~= db then
				return da < db
			end
			return a < b
		end)
		local pname = prov or self:_province_name(id, best)
		local name = pname .. " Rebels"
		local n = 1
		local function worn(nm: string): boolean
			for o = 1, self.owner_total do
				if self.o_name[o] == nm and self.o_alive[o] == 1 then
					return true
				end
			end
			return false
		end
		while worn(name) do
			n += 1
			name = string.format("%s Rebels %d", pname, n)
		end
		local rid = self:add_owner(name, SimRevolts.rebel_color(self.o_color[id]), Defs.KIND_TRIBE)
		if rid <= 0 then
			return false
		end
		local taken = 0
		for i = 1, math.min(#take, want) do
			self:set_owner(take[i], rid)
			taken += 1
		end
		-- defectors from the empire's army, and a levy raised in the province
		local defect = math.floor(self.o_troops[id] * SimRevolts.TROOPS)
		self.o_troops[id] -= defect
		local levy = math.floor(0.5 * self.R.max_troops(Defs.KIND_TRIBE, taken, 0, self.difficulty))
		self.o_troops[rid] = defect + levy
		self.o_spawned[rid] = 1
		self.o_spawn_tile[rid] = best
		self:ev({ Ev.SPAWNED, rid, best })
		local s = rv(self)
		local rec = {
			parent = id,
			born = self.tick,
			prov = pname,
			price0 = Rules.rebel_price(defect + levy, self.o_cap[id] or 0.0),
			state = SimRevolts.RISING,
		}
		s.rebels[rid] = rec
		self:ev({ Ev.REBEL, rid, id, rec.born, rec.state })
		self:msg(
			id,
			Defs.MSG_BAD,
			string.format(
				"Revolt! %s rises: %d tiles and %s troops break away as the %s. Crush them within %d min for a reward, or buy them back",
				pname,
				taken,
				NumberFormat.render_troops(defect + levy),
				name,
				SimRevolts.CRUSH_TICKS // (Rules.TICK_RATE * 60)
			)
		)
		self:msg_others(id, Defs.MSG_INFO, string.format("Revolt in %s: the %s take up arms", self.o_name[id], name))
		return true
	end

	local function rebel_ev(self: any, rid: number, r: any)
		self:ev({ Ev.REBEL, rid, r.parent, r.born, r.state })
	end

	--- The strongest empire (most land) at war with `parent` right now: attacking it, not its ally,
	--- not `skip`. 0: none.
	function C._enemy_of(self: any, parent: number, skip: number): number
		local best, bt = 0, 0
		for _, a in self.attacks do
			local o = a.attacker
			if
				not a.dead
				and a.target == parent
				and o ~= skip
				and o ~= parent
				and self.o_alive[o] == 1
				and self.o_kind[o] ~= Defs.KIND_TRIBE
				and not self:allied(o, parent)
				and self.o_tiles[o] > bt
			then
				best, bt = o, self.o_tiles[o]
			end
		end
		return best
	end

	--- Rebels alive FREE_TICKS become the free nation of their province.
	function C._rebels_free(self: any, rid: number, r: any)
		local name = "Free " .. tostring(r.prov)
		local base = name
		local n = 1
		local taken = true
		while taken do
			taken = false
			for o = 1, self.owner_total do
				if o ~= rid and self.o_alive[o] == 1 and self.o_name[o] == name then
					taken = true
					n += 1
					name = string.format("%s %d", base, n)
					break
				end
			end
		end
		local old = self.o_name[rid]
		self.o_name[rid] = name
		self.o_kind[rid] = Defs.KIND_NATION
		self.o_ai[rid] = 1
		self.o_skill[rid] = SimRevolts.FREE_SKILL
		self:ev({ Ev.OWNER_ADD, rid, name, self.o_color[rid], Defs.KIND_NATION, self.o_team[rid] })
		-- a nation's army: their levy grows to half a nation's cap for their land
		local levy = 0.5 * self.R.max_troops(Defs.KIND_NATION, self.o_tiles[rid], 0, SimRevolts.FREE_SKILL)
		self.o_troops[rid] = math.max(self.o_troops[rid], levy)
		r.state = SimRevolts.FREE
		rebel_ev(self, rid, r)
		local parent = r.parent
		self:msg(
			parent,
			Defs.MSG_BAD,
			string.format("The %s held out: %s is now a free nation", old, name)
		)
		self:msg_others(parent, Defs.MSG_INFO, string.format("%s declares its independence from %s", name, self.o_name[parent]))
		-- the enemy of their old empire is their friend
		local enemy = self:_enemy_of(parent, rid)
		if enemy > 0 then
			if self.o_kind[enemy] == Defs.KIND_HUMAN and self.o_bot[enemy] ~= 1 then
				pcall(self.ally_request, self, rid, enemy)
			else
				self:form_alliance(rid, enemy)
				self:msg(parent, Defs.MSG_BAD, string.format("%s allies with %s against you", name, self.o_name[enemy]))
			end
		end
	end

	function C._rebels_tick(self: any, s: any)
		local tick = self.tick
		for rid, r in s.rebels do
			if r.state ~= SimRevolts.RISING then
				continue
			end
			if self.o_alive[rid] == 0 then
				r.state = SimRevolts.GONE
				rebel_ev(self, rid, r)
			elseif tick - r.born >= SimRevolts.FREE_TICKS then
				self:_rebels_free(rid, r)
			end
		end
	end

	--- Sim._eliminate: rebels are out. Their own empire crushing them in time is paid.
	function C._rebels_out(self: any, rid: number, killer: number)
		local s = self._rv
		local r = if s ~= nil then s.rebels[rid] else nil
		if r == nil or r.state ~= SimRevolts.RISING then
			return
		end
		if killer == r.parent and self.tick - r.born <= SimRevolts.CRUSH_TICKS then
			r.state = SimRevolts.CRUSHED
			local gold = Rules.rebel_crush_gold(r.price0)
			self.o_gold[killer] += gold
			self:msg(
				killer,
				Defs.MSG_GOOD,
				string.format("Revolt crushed! The %s are no more: +%s gold", self.o_name[rid], NumberFormat.render_number(gold))
			)
		else
			r.state = SimRevolts.GONE
		end
		rebel_ev(self, rid, r)
	end

	--- What buying rebels `rid` back costs their empire now (-1: they can't be bought).
	function C.rebel_price_of(self: any, rid: number): number
		local s = self._rv
		local r = if s ~= nil then s.rebels[rid] else nil
		if r == nil or r.state ~= SimRevolts.RISING or self.o_alive[rid] == 0 then
			return -1
		end
		return Rules.rebel_price(self.o_troops[rid], self.o_cap[r.parent] or 0.0)
	end

	--- The "pay_rebels" intent: `id` buys its rebels `rid` back (their land returns with half of them).
	function C.pay_rebels(self: any, id: number, rid: number): boolean
		local s = self._rv
		local r = if s ~= nil then s.rebels[rid] else nil
		if r == nil or r.parent ~= id then
			return false
		end
		local price = self:rebel_price_of(rid)
		if price < 0 then
			return false
		end
		if self.o_gold[id] < price then
			self:msg(
				id,
				Defs.MSG_BAD,
				string.format("The %s want %s gold to lay down their arms", self.o_name[rid], NumberFormat.render_number(price))
			)
			return false
		end
		self.o_gold[id] -= price
		r.state = SimRevolts.PAID
		local back = 0.5 * self.o_troops[rid]
		local owner = self.owner
		for t = 0, self.N - 1 do
			if readi32(owner, t * 4) == rid then
				self:set_owner(t, id)
			end
			if t % 65536 == 0 then
				Coop.check()
			end
		end
		self.o_troops[id] += back
		self.o_troops[rid] = 0.0
		-- (bought, not beaten: no "You eliminated" and no conquest gold when they go)
		self.o_killer[rid] = 0
		rebel_ev(self, rid, r)
		self:msg(
			id,
			Defs.MSG_GOOD,
			string.format(
				"You paid the %s %s gold: %s returns to your empire with %s troops",
				self.o_name[rid],
				NumberFormat.render_number(price),
				tostring(r.prov),
				NumberFormat.render_troops(back)
			)
		)
		return true
	end

	--- Snapshot rows: {rid, parent, born, state} per rebel band, and the players' unrest rows.
	function C.rebel_rows(self: any): { { number } }
		local out = {}
		local s = self._rv
		if s == nil then
			return out
		end
		for rid, r in s.rebels do
			table.insert(out, { rid, r.parent, r.born, r.state })
		end
		table.sort(out, function(a, b)
			return a[1] < b[1]
		end)
		return out
	end

	function C.unrest_rows(self: any): { { any } }
		local out = {}
		local s = self._rv
		if s == nil then
			return out
		end
		for id = 1, self.owner_total do
			if s.unrest[id] ~= nil and shown(self, id) then
				table.insert(out, self:_unrest_row(id))
			end
		end
		return out
	end
end

return SimRevolts
