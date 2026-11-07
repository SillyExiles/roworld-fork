--!native
-- Port of scripts/core/sim_nukes.gd (SimNukes, mixin of the flattened Sim class).
-- Atom bombs, hydrogen bombs and MIRVs: silo launch, SAM interception, blasts and fallout.
--
-- Empires Front (2026-11-06): the siege weapons. The silo is the Siege Workshop (up to
-- Rules.STRUCT_LIMITS a player, each weapon reloading on its own, none before Rules.SIEGE_UNLOCK_TICKS of war) and
-- the SAM the Watchtower; they fire
--   * the bombard (the atom bomb, in each era's arms: Onager, Catapult, Orban's Bombard, Fire Rocket,
--     Big Bertha...): it razes a small disc at once, kills troops and destroys the buildings there;
--   * fire (the hydrogen bomb: Greek fire, fire arrows, naphtha...): it spreads from where it lands
--     to its radius over Rules.FIRE_SPREAD_TICKS, burning land and buildings as it goes (_blazes_tick);
--   * the plague (Defs.N_PLAGUE): the nation it lands on sickens and loses troops while it lasts, and
--     passes it to its neighbours, the launcher too if it borders them; Temples ease it (_plague_tick).
-- The land a bombard or a fire takes is scorched only for Rules.SCORCH_TICKS (then free land again),
-- and a tile behind a Border Wall or within its owner's Fortress's reach suffers less (_shielded).
-- Every launch is told to every player; aiming at an ally breaks the alliance, as a traitor.
--
-- Event conventions (see DESIGN.md §4): a NUKE event announces every missile (MIRV warheads
-- included). BOOM with radius > 0 is a detonation; radius 0 means the missile was shot down
-- mid-air at that tile; radius -1 means a MIRV bus split into warheads at that tile. SAM_LAUNCH
-- announces a SAM firing at a bomb / warhead (it hits at intercept_tick).
--
-- Nukes fly an arc (Rules.nuke_arc: a Bezier bowed toward the top of the map, constant speed
-- along it), the same curve the renderer draws; the flight time is its length over the nuke's speed.
--
-- Luau notes: `traj` is a 1-based array; trajectory indices (`k`, `sam_k`, `plan_k`) keep the
-- GDScript 0-based meaning (ticks since launch), so traj[k + 1] is the tile at tick k.

local Defs = require("./Defs")
local Coop = require("../Net/Coop")
local Ev = require("./Ev")
local Rules = require("./Rules")
local SimState = require("./SimState")
local SimRevolts = require("./SimRevolts")
local NumberFormat = require("./NumberFormat")

local readu8 = buffer.readu8
local writeu8 = buffer.writeu8
local readi32 = buffer.readi32

local a_an = SimState.a_an
local cap_first = SimState.cap_first
local filled = SimState.filled
local MAXO = Defs.MAX_OWNERS

local S_SAM = Defs.S_SAM
local S_SILO = Defs.S_SILO
local U_TRANSPORT = Defs.U_TRANSPORT
local N_ATOM = Defs.N_ATOM
local N_HYDROGEN = Defs.N_HYDROGEN
local N_MIRV = Defs.N_MIRV
local N_WARHEAD = Defs.N_WARHEAD
local N_SCATTER = Defs.N_SCATTER
local N_SHELL = Defs.N_SHELL
local N_PLAGUE = Defs.N_PLAGUE
local N_FIRERAIN = Defs.N_FIRERAIN
local F_FALLOUT = Defs.F_FALLOUT
local F_WALL = Defs.F_WALL
local S_TEMPLE = Defs.S_TEMPLE

local SimNukes = {}

local function nuke_title(kind: number): string
	return Defs.NUKE_TITLES[kind]
end

export type Nuke = {
	uid: number,
	kind: number,
	owner: number,
	from_tile: number,
	to_tile: number,
	launch_tick: number,
	flight: number,
	--- Rules.nuke_arc: its flight path (the arc the renderer draws; traj samples it)
	arc: any,
	target_owner: number,
	dead: boolean,
	traj: { number },
	cands: { number },
	cand_tick: number,
	plan_fire: { [number]: number },
	plan_k: { [number]: number },
	sam_sid: number,
	sam_fire_tick: number,
	sam_hit_tick: number,
	sam_k: number,
}

local Nuke = {}
SimNukes.Nuke = Nuke

function Nuke.new(): Nuke
	return {
		uid = 0,
		kind = 0,
		owner = 0,
		from_tile = 0,
		to_tile = 0,
		launch_tick = 0,
		flight = 1,
		arc = nil,
		target_owner = 0,
		dead = false,
		-- Ground tile under the missile at each tick of its flight (traj[k + 1] = tick k since
		-- launch), computed when a SAM might reach it.
		traj = {},
		-- SAM interception planning: candidate SAM sids, refreshed every 30
		-- ticks, and per SAM the planned fire tick (-1 unreachable) and trajectory index of the
		-- intercept.
		cands = {},
		cand_tick = -100000,
		plan_fire = {},
		plan_k = {},
		-- Set once a SAM missile is on its way.
		sam_sid = 0,
		sam_fire_tick = 0,
		sam_hit_tick = 0,
		sam_k = 0,
	}
end

-- Ground tile under a missile flying from tile a to tile b (straight ground track on the flat map)
-- at fraction w of its flight, on a grid `W` tiles wide.

function SimNukes.install(C)
	function C:_init_nukes()
		self.nukes = {} :: { Nuke }
		self.nukes_launched = 0
		-- MIRVs launched this match (each one raises the next MIRV's price by Rules.MIRV_COST_STEP).
		self.mirvs_launched = 0
		-- (Empires Front 2026-11-06) fires spreading; scorched land in the order it clears (tiles and
		-- when) and each tile's latest clearing tick; the plague on each owner (until when, since when,
		-- who sent it, its severity), when each may catch it again, and the sick in a list
		self.blazes = {} :: { any }
		self.scorch_t = {} :: { number }
		self.scorch_e = {} :: { number }
		self.scorch_head = 1
		self.scorch_until = {} :: { [number]: number }
		self.o_plague_until = filled(MAXO, 0)
		self.o_plague_from = filled(MAXO, 0)
		self.o_plague_src = filled(MAXO, 0)
		self.o_plague_sev = filled(MAXO, 0.0)
		self.o_plague_imm = filled(MAXO, 0)
		self.plague_list = {} :: { number }
		-- (2026-11-06) until when the sick raise no new troops (Rules.PLAGUE_HALT_TICKS; Sim's growth)
		self.o_plague_halt = filled(MAXO, 0)
		-- (2026-11-06) how many times each player sent the plague (Rules.PLAGUE_MAX_USES), and the land
		-- breaking away where it struck (_blights_tick)
		self.o_plague_used = filled(MAXO, 0)
		self.blights = {} :: { any }
		-- (2026-11-07) the rain of fire arrows: how many times each player sent it, and its fires still
		-- to fall (_firerain_tick)
		self.o_firerain_used = filled(MAXO, 0)
		self.firerain = {} :: { any }
	end

	--- (2026-11-07) How many times `id` fired `kind` this match, for the weapons Rules.LIMITED_USES counts.
	function C:siege_uses(id: number, kind: number): number
		if kind == N_FIRERAIN then
			return self.o_firerain_used[id] or 0
		elseif kind == N_PLAGUE then
			return self.o_plague_used[id] or 0
		end
		return 0
	end

	--- (2026-11-06) How many times `id` sent the plague this match (its price doubles each time).
	function C:plague_uses(id: number): number
		return self.o_plague_used[id] or 0
	end

	--- Snapshot rows: { owner, plague uses, rain of fire arrows uses } of those who sent either.
	function C:plague_use_rows(): { { number } }
		local out = {}
		for id = 1, self.owner_total do
			local n = self.o_plague_used[id]
			local f = self.o_firerain_used[id]
			if n > 0 or f > 0 then
				table.insert(out, { id, n, f })
			end
		end
		return out
	end

	-- =========================================================================================
	-- Launch
	-- =========================================================================================

	-- Nuke intent. Returns true when a missile left a silo.
	function C:launch_nuke(id: number, kind_name: string, t: number): boolean
		local kind = Defs.nuke_kind_from_name(kind_name)
		if kind < 0 or kind == N_WARHEAD or kind == N_SHELL or t < 0 or t >= self.N then
			return false
		end
		-- the Arsenal's munitions need their unlock (SimArsenal)
		if not self:has_unlock(id, Defs.NUKE_UNLOCK[kind] or 0) then
			self:msg(id, Defs.MSG_INFO, string.format("Unlock the %s in the Arsenal first", nuke_title(kind)))
			return false
		end
		-- a strike (air strike, slug) leaves its own structure, takes no land and costs nothing
		local strike = Rules.NUKE_FLAT[kind] == true
		-- (Empires Front 2026-11-06) the Siege Workshop fires the bombard, fire and the plague only, and
		-- none of them before Rules.SIEGE_UNLOCK_TICKS of war
		local siege = Rules.NUKE_LAUNCHER[kind] == S_SILO
		if siege and not Defs.SIEGE_KINDS[kind] then
			return false
		end
		if siege then
			local left = Rules.siege_unlock_left(self.playing_since, self.tick)
			if left > 0 then
				local secs = math.ceil(left / Rules.TICK_RATE)
				self:msg(
					id,
					Defs.MSG_INFO,
					string.format("Siege weapons can be used in %d:%02d", secs // 60, secs % 60)
				)
				return false
			end
		end
		local tg = readi32(self.owner, t * 4)
		if tg == id then
			self:msg(
				id,
				Defs.MSG_INFO,
				if strike then "You can't strike your own land" else "You can't nuke your own land"
			)
			return false
		end
		if kind == N_PLAGUE and tg <= 0 then
			self:msg(id, Defs.MSG_INFO, "Aim the plague at a nation's land")
			return false
		end
		-- (2026-11-07) the rain of fire arrows: aimed at an enemy's land (it spares the launcher's friends)
		if kind == N_FIRERAIN and (tg <= 0 or self:allied(id, tg)) then
			self:msg(id, Defs.MSG_INFO, "Aim the rain of fire arrows at an enemy's land")
			return false
		end
		-- (2026-11-06) the plague, (2026-11-07) the rain of fire arrows: Rules.LIMITED_USES a player a match
		local max_uses = Rules.LIMITED_USES[kind]
		if max_uses ~= nil and self:siege_uses(id, kind) >= max_uses then
			self:msg(id, Defs.MSG_INFO, string.format("You have sent %s %d times: no more this match", nuke_title(kind), max_uses))
			return false
		end
		-- (2026-11-06) a new player (their first Rules.ROOKIE_MATCHES matches) is safe from them
		if siege and tg > 0 and self.o_rookie[tg] == 1 then
			self:msg(id, Defs.MSG_INFO, string.format("%s is new to war: siege weapons can't hit them yet", self:name_of(tg)))
			return false
		end
		-- (a siege weapon aimed at an ally breaks the alliance, as a traitor: below. A teammate, never.)
		if tg ~= 0 and self:allied(id, tg) and not (siege and not self:same_team(id, tg)) then
			self:msg(
				id,
				Defs.MSG_INFO,
				if self:same_team(id, tg)
					then (if strike then "You can't strike a teammate" else "You can't nuke a teammate")
					else (if strike then "You can't strike an ally" else "You can't nuke an ally")
			)
			return false
		end
		-- Team games: no atom or hydrogen bomb with a teammate's
		-- structure inside its outer radius
		if self.team_mode and (kind == N_ATOM or kind == N_HYDROGEN) then
			local _, outer = self.R.nuke_radii(kind)
			local r = math.ceil(outer)
			local o2 = outer * outer
			for _, s in self:structs_in_box(t, r, r) do
				if s.owner ~= id and self:same_team(id, s.owner) and self.range_d2(t, s.tile) <= o2 then
					self:msg(id, Defs.MSG_INFO, "A teammate's building is too close")
					return false
				end
			end
		end
		-- (Empires Front 2026-11-06: a siege weapon costs a big empire more, Rules.siege_cost)
		local cost = if siege
			then Rules.siege_cost(kind_name, self:land_share(id), self:siege_uses(id, kind))
			else Rules.nuke_cost(kind_name, self.mirvs_launched)
		if self.o_gold[id] < cost then
			self:msg(id, Defs.MSG_INFO, string.format("Not enough gold for %s", a_an(nuke_title(kind))))
			return false
		end
		-- Launch site: the nearest (manhattan) finished silo with a loaded missile. (A strike: the
		-- nearest loaded airfield within its reach, or railgun.)
		local geo_manhattan = self.geo_manhattan
		local launcher = Rules.NUKE_LAUNCHER[kind]
		local reload = Rules.RELOAD_TICKS[launcher]
		local reach = self.R.launch_range(kind)
		local reach2 = reach * reach
		local range_d2 = self.range_d2
		local silo = nil
		local bd = 0.0
		local out_of_reach = false
		for _, s in self:structs_of(id, launcher) do
			-- (Empires Front 2026-11-06: a Siege Workshop reloads each weapon on its own)
			if not s.active or (if siege then not self:siege_ready(s, kind) else self:ready_missiles(s, reload) <= 0) then
				continue
			end
			if reach > 0 and range_d2(s.tile, t) > reach2 then
				out_of_reach = true
				continue
			end
			local d = geo_manhattan(s.tile, t)
			if silo == nil or d < bd then
				bd = d
				silo = s
			end
		end
		if silo == nil then
			local what = string.lower(Defs.STRUCT_TITLES[launcher])
			self:msg(
				id,
				Defs.MSG_INFO,
				if out_of_reach
					then string.format("That is out of your %s's reach", what)
					elseif siege then string.format("No %s has %s loaded", what, a_an(nuke_title(kind)))
					else string.format("No %s is ready", what)
			)
			return false
		end
		local tick = self.tick
		self.o_gold[id] -= cost
		if kind == N_PLAGUE then
			self.o_plague_used[id] += 1
			self:ev({ Ev.PLAGUE_USES, id, self.o_plague_used[id], N_PLAGUE })
		elseif kind == N_FIRERAIN then
			self.o_firerain_used[id] += 1
			self:ev({ Ev.PLAGUE_USES, id, self.o_firerain_used[id], N_FIRERAIN })
		end
		table.insert(silo.shots, self:shot_stamp(silo, if siege then kind else nil))
		self:ev({ Ev.STRUCT_SHOTS, silo.sid, table.clone(silo.shots) })
		local arc = self.R.munition_arc(self.W, self.H, silo.tile, t, kind)
		local n = self:_spawn_nuke(kind, id, silo.tile, t, self.R.nuke_arc_ticks(arc, kind), arc)
		n.target_owner = tg
		if strike then
			self:msg(id, Defs.MSG_INFO, string.format("%s on its way to %s", nuke_title(kind), self:name_of(tg)))
			return true
		end
		self.nukes_launched += 1
		if kind == N_MIRV then
			self.mirvs_launched += 1
		elseif kind == N_SCATTER then
			self:_scatter_warheads(id, silo.tile, t, n.flight)
		end
		local o_name = self.o_name
		-- (2026-11-06) aimed at an ally: the alliance is over, and the launcher a traitor
		if tg > 0 and siege and self:has_alliance(id, tg) then
			self:end_alliance(id, tg, id)
		end
		if tg ~= 0 then
			self:add_grudge(tg, id, Rules.NUKE_GRUDGE_TICKS)
			self.o_attacked_tick[tg] = tick
			self:msg(tg, Defs.MSG_ALERT, string.format("%s attacks you with %s!", o_name[id], a_an(nuke_title(kind))))
		end
		self:msg(id, Defs.MSG_INFO, string.format("%s launched at %s", nuke_title(kind), self:name_of(tg)))
		-- (Empires Front 2026-11-06: every launch is told to every player, the bombard's too)
		if kind ~= N_ATOM or siege then
			for _, h in self.humans do
				if h ~= tg and h ~= id then
					self:msg(
						h,
						Defs.MSG_ALERT,
						string.format("%s attacks %s with %s", o_name[id], self:name_of(tg), a_an(nuke_title(kind)))
					)
				end
			end
		end
		if kind ~= N_MIRV and kind ~= N_PLAGUE and kind ~= N_FIRERAIN then
			self:_break_nuked_alliances(id, t, kind)
		end
		self:_on_nuke_launched(id, tg, kind)
		return true
	end

	-- Alliance breaking: allies with at least nukeAllianceBreakThreshold weighted
	-- full-size tiles (inner radius 1, outer ring 0.5) inside the blast lose their alliance with the
	-- launcher.
	function C:_break_nuked_alliances(id: number, t: number, kind: number)
		if self.o_ally_count[id] <= 0 then
			return
		end
		local range_d2 = self.range_d2
		local inner, outer = self.R.nuke_radii(kind)
		local weight = {}
		local order = {}
		local inner2 = inner * inner
		local owner = self.owner
		for _, c in self:disk_tiles(t, outer, true) do
			local o = readi32(owner, c * 4)
			if o <= 0 or o == id or not self:has_alliance(id, o) then
				continue
			end
			local w = weight[o]
			if w == nil then
				w = 0.0
				table.insert(order, o)
			end
			weight[o] = w + (if range_d2(t, c) <= inner2 then 1.0 else 0.5)
		end
		for _, o in order do
			if weight[o] * self.R.K_AREA >= Rules.NUKE_ALLIANCE_BREAK_FULL then
				self:end_alliance(id, o, id)
			end
		end
	end

	-- Hook for the AI.
	function C:_on_nuke_launched(_id: number, _tg: number, _kind: number) end

	function C:_spawn_nuke(kind: number, id: number, from_tile: number, to_tile: number, flight: number, arc: any?): Nuke
		local tick = self.tick
		local n = Nuke.new()
		n.uid = self.next_uid
		self.next_uid += 1
		n.kind = kind
		n.owner = id
		n.from_tile = from_tile
		n.to_tile = to_tile
		n.launch_tick = tick
		n.flight = math.max(flight, 1)
		n.arc = arc or self.R.munition_arc(self.W, self.H, from_tile, to_tile, kind)
		n.target_owner = readi32(self.owner, to_tile * 4)
		table.insert(self.nukes, n)
		self:ev({ Ev.NUKE, n.uid, kind, id, from_tile, to_tile, tick, n.flight })
		return n
	end

	-- =========================================================================================
	-- Flight, interception, detonation
	-- =========================================================================================

	function C:nukes_tick()
		self:_sam_tick()
		local list = self.nukes
		local count = #list
		local tick = self.tick
		for i = 1, count do
			local n = list[i]
			if n.dead then
				continue
			end
			if n.sam_sid ~= 0 and tick >= n.sam_hit_tick and self:_sam_intercept(n) then
				continue
			end
			if tick >= n.launch_tick + n.flight then
				n.dead = true
				if n.kind == N_MIRV then
					self:_split_mirv(n)
				elseif Rules.NUKE_FLAT[n.kind] then
					self:_strike(n) -- (a shell, an air strike, a slug: SimArsenal)
				elseif n.kind == N_PLAGUE then
					self:_plague_land(n)
				elseif n.kind == N_FIRERAIN then
					self:_firerain_land(n)
				elseif n.kind == N_HYDROGEN then
					self:_ignite(n)
				else
					self:_detonate(n)
				end
				Coop.check() -- (a local match's step is spread over frames: Session._local_process)
			end
		end
		local w = 0
		local m = #list
		for i = 1, m do
			local n2 = list[i]
			if not n2.dead then
				w += 1
				list[w] = n2
			end
		end
		for i = m, w + 1, -1 do
			list[i] = nil
		end
		-- (Empires Front 2026-11-06) fire spreading, scorched land clearing, the plague
		if #self.blazes > 0 then
			self:_blazes_tick()
		end
		if self.scorch_head <= #self.scorch_t then
			self:_scorch_tick()
		end
		if #self.plague_list > 0 then
			self:_plague_tick()
		end
		-- (2026-11-07: the plague's land breaking away goes on whether or not its victim is still sick)
		if #self.blights > 0 then
			self:_blights_tick()
		end
		-- (2026-11-07) the rain of fire arrows still falling
		if #self.firerain > 0 then
			self:_firerain_tick()
		end
	end

	-- SAM targeting: every non-friendly finished SAM plans, for each
	-- bomb or warhead it could reach, the latest tick to fire so its missile (12 full-size tiles per
	-- tick) meets the missile at the first trajectory tile that is inside the SAM's range and
	-- targetable (within 150 full-size tiles of the target or launch point); it fires on that tick if a
	-- missile is loaded (hydrogen bombs first, then targets nearest the SAM, then the most
	-- urgent). Always a hit.
	function C:_sam_tick()
		local list = self.nukes
		if #list == 0 then
			return
		end
		local tick = self.tick
		local structs = self.structs
		local geo_manhattan = self.geo_manhattan
		local K_LIN = self.R.K_LIN
		local sams = nil
		local fires = {}
		for _, n in list do
			if n.dead or n.sam_sid ~= 0 or Rules.NUKE_INTERCEPT_P[n.kind] <= 0 then
				continue
			end
			if tick >= n.cand_tick then
				if sams == nil then
					sams = {}
					for _, st in self.struct_list do
						if not st.dead and st.kind == S_SAM and st.active then
							table.insert(sams, st)
						end
					end
				end
				self:_sam_candidates(n, sams)
			end
			if #n.cands == 0 then
				continue
			end
			for _, sid in n.cands do
				local s = structs[sid]
				if s == nil or s.dead or not s.active or s.owner == n.owner or self:allied(s.owner, n.owner) then
					continue
				end
				local plan = n.plan_fire[sid]
				if plan == nil then
					plan = -3
				end
				if plan == -3 or (plan >= 0 and plan < tick) then
					self:_sam_plan(n, s)
					plan = n.plan_fire[sid]
				end
				if plan >= 0 and plan <= tick + 1 then
					local score = (if n.kind == N_HYDROGEN then 70001 else 0)
						+ math.max(0, 200000 - Defs.trunc(geo_manhattan(s.tile, n.to_tile) * K_LIN) * 1000)
						+ math.max(0, 10000 - (n.launch_tick + n.flight - tick) * 100)
					table.insert(fires, { score, n, s })
				end
			end
		end
		if #fires == 0 then
			return
		end
		-- Godot's sort_custom (unstable): equal scores end up in the Godot version's order.
		Defs.godot_sort(fires, function(a, b)
			return a[1] > b[1]
		end)
		for _, f in fires do
			local n2: Nuke = f[2]
			local s2 = f[3]
			if n2.sam_sid ~= 0 or self:ready_missiles(s2, Rules.SAM_COOLDOWN_TICKS) <= 0 then
				continue
			end
			table.insert(s2.shots, tick)
			self:ev({ Ev.STRUCT_SHOTS, s2.sid, table.clone(s2.shots) })
			local k = n2.plan_k[s2.sid]
			local t = n2.traj[k + 1]
			n2.sam_sid = s2.sid
			n2.sam_k = k
			n2.sam_fire_tick = tick
			n2.sam_hit_tick = tick + self:_sam_ticks_to(s2.tile, t)
			self:ev({ Ev.SAM_LAUNCH, s2.sid, n2.uid, tick, n2.sam_hit_tick, true })
		end
	end

	-- SAMs that might reach `n`: within max SAM range + the targetable zone of its target or
	-- launch.
	function C:_sam_candidates(n: Nuke, sams)
		n.cand_tick = self.tick + 30
		table.clear(n.plan_fire)
		table.clear(n.plan_k)
		local cands = {}
		n.cands = cands
		local range_d2 = self.range_d2
		local K_LIN = self.R.K_LIN
		local reach = Rules.SAM_MAX_RANGE_FULL / K_LIN + Rules.NUKE_TARGETABLE_FULL / K_LIN
		local r2 = reach * reach
		for _, s in sams do
			if s.owner == n.owner then
				continue
			end
			if range_d2(s.tile, n.to_tile) <= r2 or range_d2(s.tile, n.from_tile) <= r2 then
				table.insert(cands, s.sid)
			end
		end
		if #cands > 0 and #n.traj == 0 then
			-- the tile under the nuke on each tick of its flight, along its arc (Rules.nuke_arc: the
			-- curve the renderer draws)
			local W, H = self.W, self.H
			local R = self.R
			local arc = n.arc or R.munition_arc(W, H, n.from_tile, n.to_tile, n.kind)
			n.arc = arc
			local flight = n.flight
			local traj = table.create(flight + 1)
			for k = 0, flight do
				local x, y = R.nuke_arc_at(arc, k / flight)
				traj[k + 1] = math.clamp(math.floor(y), 0, H - 1) * W + math.clamp(math.floor(x), 0, W - 1)
			end
			n.traj = traj
		end
	end

	-- Ticks a SAM missile needs from `from` to `to` (manhattan full-size tiles / 12, rounded up).
	function C:_sam_ticks_to(from: number, to: number): number
		return math.ceil(self.geo_manhattan(from, to) * self.R.K_LIN / Rules.SAM_MISSILE_SPEED_FULL)
	end

	-- Interception tile: the first future trajectory tile in range and targetable that the
	-- SAM's missile can reach in time (or the tile before detonation when the target is in range).
	function C:_sam_plan(n: Nuke, s)
		local tick = self.tick
		local traj = n.traj
		local sid = s.sid
		local cur = tick - n.launch_tick
		local last = n.flight
		local R = self.R
		local range_d2 = self.range_d2
		local zone = Rules.NUKE_TARGETABLE_FULL / R.K_LIN
		local z2 = zone * zone
		local rmax = Rules.SAM_MAX_RANGE_FULL / R.K_LIN
		local rmax2 = rmax * rmax
		local inc = 0
		local lastd = -1.0
		for k = math.max(cur, 0), last - 1 do
			local t = traj[k + 1]
			local d = range_d2(s.tile, t)
			inc = if lastd >= 0.0 and d > lastd then inc + 1 else 0
			lastd = d
			local nt = k - cur
			local rr = R.sam_range_at(s.level, tick + nt - s.up_tick)
			if d <= rr * rr and (range_d2(n.to_tile, t) < z2 or range_d2(n.from_tile, t) < z2) then
				local st = self:_sam_ticks_to(s.tile, t)
				if nt >= st then
					n.plan_fire[sid] = tick + nt - st
					n.plan_k[sid] = k
					return
				end
			end
			if inc > 3 and d > rmax2 then
				break
			end
		end
		local kf = last - 1
		if kf >= cur then
			local rf = R.sam_range_at(s.level, tick + (last - cur) - s.up_tick)
			if range_d2(s.tile, n.to_tile) <= rf * rf then
				local st2 = self:_sam_ticks_to(s.tile, traj[kf + 1])
				if kf - cur >= st2 then
					n.plan_fire[sid] = tick + kf - cur - st2
					n.plan_k[sid] = kf
					return
				end
			end
		end
		n.plan_fire[sid] = -1
	end

	-- A SAM missile arriving: the bomb / warhead is destroyed (BOOM radius 0 at the ground
	-- tile under the intercept point) unless the SAM was lost meanwhile (then the target is free
	-- again).
	function C:_sam_intercept(n: Nuke): boolean
		local s = self.structs[n.sam_sid]
		if s == nil or s.dead or s.owner == n.owner then
			n.sam_sid = 0
			n.cand_tick = self.tick
			return false
		end
		n.dead = true
		self:ev({ Ev.BOOM, n.uid, n.kind, n.traj[n.sam_k + 1], 0, n.owner })
		if n.kind ~= N_WARHEAD then
			self:msg(
				s.owner,
				Defs.MSG_GOOD,
				string.format("Your SAM shot down %s from %s", a_an(nuke_title(n.kind)), self.o_name[n.owner])
			)
			self:msg(
				n.owner,
				Defs.MSG_BAD,
				string.format("Your %s was intercepted by %s", nuke_title(n.kind), self.o_name[s.owner])
			)
		end
		return true
	end

	-- Snapshot rows of SAM missiles in flight: [sam_sid, nuke_uid, fire_tick, intercept_tick, true].
	function C:sam_rows(): { { any } }
		local out = {}
		for _, n in self.nukes do
			if not n.dead and n.sam_sid ~= 0 then
				table.insert(out, { n.sam_sid, n.uid, n.sam_fire_tick, n.sam_hit_tick, true })
			end
		end
		return out
	end

	-- Missiles a SAM or silo can fire now: `level` minus those still reloading (each launch or
	-- upgrade reloads for `cooldown` ticks — a queue of missile timers).
	function C:ready_missiles(s, cooldown: number): number
		local shots = s.shots
		local n = #shots
		local tick = self.tick
		local k = 0
		while k < n and shots[k + 1] + cooldown <= tick do
			k += 1
		end
		if k > 0 then
			s.shots = table.move(shots, k + 1, n, 1, {})
		end
		return s.level - #s.shots
	end

	-- (Empires Front 2026-11-06) Whether Siege Workshop `s` has weapon `kind` loaded: one of each per
	-- level, each reloading for Rules.siege_reload(kind). Drops the shots whose reload is over.
	function C:siege_ready(s, kind: number): boolean
		local shots = s.shots
		local tick = self.tick
		local keep = nil
		local busy = 0
		for i, v in shots do
			if Rules.shot_tick(v) + Rules.shot_reload(S_SILO, v) <= tick then
				if keep == nil then
					keep = table.move(shots, 1, i - 1, 1, {})
				end
			else
				if keep ~= nil then
					table.insert(keep, v)
				end
				if Rules.shot_kind(v) == kind then
					busy += 1
				end
			end
		end
		if keep ~= nil then
			s.shots = keep
		end
		return busy < s.level
	end

	--- Whether any of `id`'s finished Siege Workshops has `kind` loaded (within `t`'s reach, given a tile).
	function C:siege_loaded(id: number, kind: number, t: number?): boolean
		local reach = self.R.launch_range(kind)
		for _, s in self:structs_of(id, S_SILO) do
			if s.active and not s.dead and self:siege_ready(s, kind) then
				if t == nil or reach <= 0 or self.range_d2(s.tile, t) <= reach * reach then
					return true
				end
			end
		end
		return false
	end

	-- MIRV split: up to MIRV_WARHEADS warheads, aimed at the target's land within MIRV_SPREAD
	-- of the aim point and at least 55 full-size tiles (manhattan) apart, leave the bus when it arrives.
	function C:_split_mirv(n: Nuke)
		self:ev({ Ev.BOOM, n.uid, n.kind, n.to_tile, -1, n.owner })
		local tg = n.target_owner
		if tg > 0 and self:allied(n.owner, tg) then
			self:end_alliance(n.owner, tg, n.owner)
		end
		local R = self.R
		local W = self.W
		local range_d2 = self.range_d2
		local geo_manhattan = self.geo_manhattan
		local spread2 = R.MIRV_SPREAD * R.MIRV_SPREAD
		local gap = math.ceil(55.0 / R.K_LIN)
		local grid = {}
		local targets = { n.to_tile }
		SimNukes._mirv_mark(grid, W, n.to_tile, gap)
		local map = self.map
		local land_list = map.land_list
		local nlt = map.land_count
		local owner = self.owner
		local rng = self.rng
		local max_w = Rules.MIRV_WARHEADS
		for _ = 1, 8000 do
			if #targets >= max_w then
				break
			end
			local c = readi32(land_list, (rng:randi() % nlt) * 4)
			if readi32(owner, c * 4) ~= tg or tg == 0 or range_d2(n.to_tile, c) > spread2 then
				continue
			end
			if SimNukes._mirv_overlaps(grid, W, c, gap, geo_manhattan) then
				continue
			end
			table.insert(targets, c)
			SimNukes._mirv_mark(grid, W, c, gap)
		end
		for _, t in targets do
			local arc = R.nuke_arc(self.W, self.H, n.to_tile, t)
			local flight = R.nuke_arc_ticks(arc, N_WARHEAD) + rng:randi_range(0, 15)
			self:_spawn_nuke(N_WARHEAD, n.owner, n.to_tile, t, flight, arc).target_owner = tg
		end
	end

	-- Detonation: every tile of the inner radius and half of the outer ring (at
	-- random) is relinquished and left as fallout; each hit owner loses troops per full-size tile by
	-- nukeDeathFactor (its attacks and transports too), and every unit and structure inside the
	-- outer radius is destroyed.
	function C:_detonate(n: Nuke)
		local range_d2 = self.range_d2
		local inner, radius = self.R.nuke_radii(n.kind)
		local inner2 = inner * inner
		local to = n.to_tile
		local tiles = self:disk_tiles(to, radius, true)
		local lost = {}
		local before = {}
		local order = {}
		local owner = self.owner
		local o_tiles = self.o_tiles
		local rng = self.rng
		for _, t in tiles do
			if range_d2(to, t) > inner2 and rng:randi() % 2 == 0 then
				continue
			end
			local o = readi32(owner, t * 4)
			-- (Empires Front: a new player's land is never razed; behind a wall or within a Fortress's
			-- reach, half as likely)
			if o > 0 and self.o_rookie[o] == 1 then
				continue
			end
			if o > 0 and self:_shielded(t, o) and rng:randf() >= Rules.PROTECT_MULT then
				continue
			end
			if o ~= 0 then
				if before[o] == nil then
					before[o] = o_tiles[o]
					lost[o] = 0
					table.insert(order, o)
				end
				lost[o] += 1
				self:set_owner(t, 0)
			end
			-- (Empires Front: scorched for Rules.SCORCH_TICKS only)
			self:_scorch(t)
		end
		local o_killer = self.o_killer
		for _, o in order do
			self:_nuke_troops(o, n.kind, lost[o], before[o])
			if o_tiles[o] <= 0 then
				o_killer[o] = n.owner
			end
			if o ~= n.owner then
				self:add_grudge(o, n.owner, Rules.NUKE_GRUDGE_TICKS)
			end
		end
		-- Structures and units inside the outer radius are destroyed.
		local r = math.ceil(radius)
		local r2 = radius * radius
		local o_name = self.o_name
		for _, s in self:structs_in_box(to, self.geo_span(to, radius), r) do
			if not s.dead and range_d2(to, s.tile) <= r2 then
				local so = s.owner
				-- (Empires Front: a new player's buildings stand; one behind a wall or within a
				-- Fortress's reach may)
				if so > 0 and self.o_rookie[so] == 1 then
					continue
				end
				if self:_shielded(s.tile, so) and rng:randf() < Rules.PROTECT_SAVE then
					continue
				end
				self:destroy_struct(s)
				if so ~= n.owner then
					self:msg(
						so,
						Defs.MSG_BAD,
						string.format("%s destroyed your %s", o_name[n.owner], Defs.STRUCT_TITLES[s.kind])
					)
				end
			end
		end
		for _, u in self.unit_list do
			if u.dead then
				continue
			end
			local ut = self:unit_tile(u)
			if ut >= 0 and range_d2(to, ut) <= r2 then
				self:remove_unit(u, Defs.DEL_DESTROYED)
			end
		end
		self:ev({ Ev.BOOM, n.uid, n.kind, to, r, n.owner })
		local victim = n.target_owner
		if victim > 0 and n.kind ~= N_WARHEAD then
			self:msg(
				victim,
				Defs.MSG_BAD,
				string.format("%s from %s hit your land", cap_first(a_an(nuke_title(n.kind))), o_name[n.owner])
			)
		end
		if n.kind == N_HYDROGEN then
			self:msg_others(
				victim,
				Defs.MSG_INFO,
				string.format("Hydrogen bomb detonated over %s", self:name_of(victim))
			)
		end
	end

	-- nukeDeathFactor applied once per full-size tile lost: bombs remove 5 x troops / tiles left each
	-- time (so troops shrink by ((T - n) / T)^5), warheads 500 x (1 - e^(-2 excess / max)).
	function C:_nuke_troops(o: number, kind: number, n_lost: number, tiles_before: number)
		local cap = math.max(self.o_cap[o], 1.0)
		local o_troops = self.o_troops
		local dbg_flow = self.dbg_flow
		if kind ~= N_WARHEAD then
			local f = (math.max(0.0, tiles_before - n_lost) / math.max(tiles_before, 1)) ^ 5.0
			dbg_flow[o * 5 + 3] += o_troops[o] * (1.0 - f)
			o_troops[o] *= f
			for _, a in self.attacks do
				if not a.dead and a.attacker == o then
					a.troops *= f
				end
			end
			for _, u in self.unit_list do
				if not u.dead and u.owner == o and u.kind == U_TRANSPORT then
					u.troops *= f
				end
			end
			return
		end
		local k = self.R.K_AREA
		local warhead_death = Rules.warhead_death
		for _ = 1, n_lost do
			local d = math.min(k * warhead_death(o_troops[o], cap), math.max(0.0, o_troops[o] - 0.03 * cap))
			dbg_flow[o * 5 + 3] += d
			o_troops[o] -= d
		end
		for _, a in self.attacks do
			if not a.dead and a.attacker == o then
				for _ = 1, n_lost do
					a.troops -= math.min(k * warhead_death(a.troops, cap), math.max(0.0, a.troops - 0.03 * cap))
				end
			end
		end
		for _, u in self.unit_list do
			if not u.dead and u.owner == o and u.kind == U_TRANSPORT then
				for _ = 1, n_lost do
					u.troops -= math.min(k * warhead_death(u.troops, cap), math.max(0.0, u.troops - 0.03 * cap))
				end
			end
		end
	end

	-- =========================================================================================
	-- Empires Front (2026-11-06): scorched land, walls and Fortresses, fire, the plague
	-- =========================================================================================

	--- Whether `owner`'s tile `t` is behind a Border Wall's stones or within its Fortress's reach.
	function C:_shielded(t: number, o: number): boolean
		if o <= 0 then
			return false
		end
		if bit32.band(readu8(self.flags, t), F_WALL) ~= 0 then
			return true
		end
		return readu8(self.def_cover, t) > 0 and self:_cover_strength(t, o) == 2
	end

	--- Scorches tile `t` (Defs.F_FALLOUT) until Rules.SCORCH_TICKS from now (a later scorch extends it).
	function C:_scorch(t: number)
		local flags = self.flags
		local f = readu8(flags, t)
		if bit32.band(f, F_FALLOUT) == 0 then
			f = bit32.bor(f, F_FALLOUT)
			writeu8(flags, t, f)
			table.insert(self.d_flags, t * 256 + f)
			self.fallout_count += 1
		end
		local e = self.tick + Rules.SCORCH_TICKS
		self.scorch_until[t] = e
		local q = self.scorch_t
		q[#q + 1] = t
		self.scorch_e[#q] = e
	end

	--- Scorched land whose time is up is plain free land again (taken meanwhile, it already is).
	function C:_scorch_tick()
		local q, qe = self.scorch_t, self.scorch_e
		local h = self.scorch_head
		local n = #q
		local tick = self.tick
		local until_ = self.scorch_until
		local flags = self.flags
		local owner = self.owner
		while h <= n and qe[h] <= tick do
			local t = q[h]
			if until_[t] == qe[h] then
				until_[t] = nil
				local f = readu8(flags, t)
				if bit32.band(f, F_FALLOUT) ~= 0 and readi32(owner, t * 4) == 0 then
					f = bit32.band(f, bit32.bnot(F_FALLOUT))
					writeu8(flags, t, f)
					table.insert(self.d_flags, t * 256 + f)
					self.fallout_count -= 1
				end
			end
			h += 1
		end
		if h > n then
			table.clear(q)
			table.clear(qe)
			h = 1
		elseif h > 4096 then
			self.scorch_t = table.move(q, h, n, 1, {})
			self.scorch_e = table.move(qe, h, n, 1, {})
			h = 1
		end
		self.scorch_head = h
	end

	--- Fire landing: it spreads from its tile over Rules.FIRE_SPREAD_TICKS (_blazes_tick).
	--- (2026-11-07: `foes_of` an owner: the fire spares that owner and its friends, Rules allied; `quiet`:
	--- no Ev.BOOM nor messages, for the rain of fire arrows' many small fires.)
	function C:_ignite(n: Nuke, foes_of: number?, quiet: boolean?)
		local inner, outer = self.R.nuke_radii(n.kind)
		local to = n.to_tile
		local range_d2 = self.range_d2
		local tiles = self:disk_tiles(to, outer, true)
		local d2s = {}
		for _, t in tiles do
			d2s[t] = range_d2(to, t)
		end
		table.sort(tiles, function(a, b)
			local da, db = d2s[a], d2s[b]
			if da ~= db then
				return da < db
			end
			return a < b
		end)
		local r2 = outer * outer
		local ss = {}
		for _, s in self:structs_in_box(to, self.geo_span(to, outer), math.ceil(outer)) do
			if not s.dead then
				local d = range_d2(to, s.tile)
				if d <= r2 then
					table.insert(ss, { s = s, d = d })
				end
			end
		end
		table.sort(ss, function(a, b)
			if a.d ~= b.d then
				return a.d < b.d
			end
			return a.s.sid < b.s.sid
		end)
		local dur = Rules.FIRE_SPREAD_TICKS
		table.insert(self.blazes, {
			uid = n.uid,
			kind = n.kind,
			owner = n.owner,
			to = to,
			inner2 = inner * inner,
			outer = outer,
			tiles = tiles,
			d2s = d2s,
			i = 1,
			structs = ss,
			si = 1,
			start = self.tick,
			dur = dur,
			foes_of = foes_of or 0,
		})
		self:ev({ Ev.BLAZE, n.uid, n.owner, to, math.ceil(outer), self.tick, dur })
		if quiet then
			return
		end
		self:ev({ Ev.BOOM, n.uid, n.kind, to, math.ceil(outer), n.owner })
		local victim = n.target_owner
		local o_name = self.o_name
		if victim > 0 then
			self:msg(
				victim,
				Defs.MSG_BAD,
				string.format("%s from %s set your land on fire", cap_first(a_an(nuke_title(n.kind))), o_name[n.owner])
			)
		end
		self:msg_others(victim, Defs.MSG_INFO, string.format("Fire spreads over %s", self:name_of(victim)))
	end

	--- Each fire's front moves out: the land it reaches burns (Rules.FIRE_BURN_*: free and scorched),
	--- the buildings it reaches are destroyed, and their armies lose troops as their land does.
	function C:_blazes_tick()
		local list = self.blazes
		local tick = self.tick
		local owner = self.owner
		local o_tiles = self.o_tiles
		local rng = self.rng
		local w = 0
		for i = 1, #list do
			local b = list[i]
			local frac = math.min(1.0, (tick - b.start + 1) / b.dur)
			local r = b.outer * frac
			local r2 = r * r
			local lost, before, order = {}, {}, {}
			local tiles, d2s = b.tiles, b.d2s
			while b.i <= #tiles do
				local t = tiles[b.i]
				local d = d2s[t]
				if d > r2 then
					break
				end
				b.i += 1
				local p = if d <= b.inner2 then Rules.FIRE_BURN_INNER else Rules.FIRE_BURN_OUTER
				local o = readi32(owner, t * 4)
				if o > 0 and self.o_rookie[o] == 1 then
					continue -- (a new player's land does not burn)
				end
				-- (2026-11-07) the rain of fire arrows spares the launcher and its friends
				if b.foes_of > 0 and (o == b.foes_of or self:allied(b.foes_of, o)) then
					continue
				end
				if o > 0 and self:_shielded(t, o) then
					p *= Rules.PROTECT_MULT
				end
				if rng:randf() >= p then
					continue
				end
				if o ~= 0 then
					if before[o] == nil then
						before[o] = o_tiles[o]
						lost[o] = 0
						table.insert(order, o)
					end
					lost[o] += 1
					self:set_owner(t, 0)
				end
				self:_scorch(t)
			end
			local ss = b.structs
			while b.si <= #ss and ss[b.si].d <= r2 do
				local s = ss[b.si].s
				b.si += 1
				if s.dead then
					continue
				end
				local so = s.owner
				if so > 0 and self.o_rookie[so] == 1 then
					continue
				end
				if b.foes_of > 0 and (so == b.foes_of or self:allied(b.foes_of, so)) then
					continue
				end
				if self:_shielded(s.tile, so) and rng:randf() < Rules.PROTECT_SAVE then
					continue
				end
				self:destroy_struct(s)
				if so ~= b.owner then
					self:msg(so, Defs.MSG_BAD, string.format("Fire destroyed your %s", Defs.STRUCT_TITLES[s.kind]))
				end
			end
			for _, o in order do
				self:_nuke_troops(o, b.kind, lost[o], before[o])
				if o_tiles[o] <= 0 then
					self.o_killer[o] = b.owner
				end
				if o ~= b.owner then
					self:add_grudge(o, b.owner, Rules.NUKE_GRUDGE_TICKS)
				end
			end
			if frac < 1.0 or b.i <= #tiles then
				w += 1
				list[w] = b
			end
		end
		for i = #list, w + 1, -1 do
			list[i] = nil
		end
	end

	--- (2026-11-07) The rain of fire arrows came down: every nation that isn't the launcher, its ally or
	--- teammate, nor a new player, takes Rules.FIRERAIN_STRIKES_MIN..MAX fires (one more a
	--- FIRERAIN_TILES_PER of its land; FIRERAIN_STRIKES_ALL in all), half on its buildings, half on
	--- its land at random, falling over FIRERAIN_TICKS (_firerain_tick).
	function C:_firerain_land(n: Nuke)
		local id = n.owner
		local rng = self.rng
		local o_name = self.o_name
		local targets = {}
		local want = {}
		for o = 1, self.owner_total do
			if
				o ~= id
				and self.o_alive[o] == 1
				and self.o_kind[o] == Defs.KIND_NATION
				and self.o_tiles[o] > 0
				and self.o_rookie[o] ~= 1
				and not self:allied(id, o)
			then
				table.insert(targets, o)
				want[o] = math.clamp(
					Rules.FIRERAIN_STRIKES_MIN + self.o_tiles[o] // Rules.FIRERAIN_TILES_PER,
					Rules.FIRERAIN_STRIKES_MIN,
					Rules.FIRERAIN_STRIKES_MAX
				)
			end
		end
		self:ev({ Ev.BOOM, n.uid, n.kind, n.to_tile, 8, id })
		if #targets == 0 then
			self:msg(id, Defs.MSG_INFO, "The rain of fire arrows found no enemy to fall on")
			return
		end
		-- (too many for FIRERAIN_STRIKES_ALL: each nation's share cut alike, one at least)
		local total = 0
		for _, o in targets do
			total += want[o]
		end
		if total > Rules.FIRERAIN_STRIKES_ALL then
			local f = Rules.FIRERAIN_STRIKES_ALL / total
			for _, o in targets do
				want[o] = math.max(1, math.floor(want[o] * f))
			end
		end
		-- each target's land: a sample by reservoir (one pass over the map), as many as it needs
		local sample = {}
		local seen = {}
		local is_t = {}
		for _, o in targets do
			sample[o] = {}
			seen[o] = 0
			is_t[o] = true
		end
		local owner = self.owner
		for t = 0, self.N - 1 do
			local o = readi32(owner, t * 4)
			if o > 0 and is_t[o] then
				local c = seen[o] + 1
				seen[o] = c
				local k = want[o]
				local sm = sample[o]
				if #sm < k then
					table.insert(sm, t)
				else
					local j = rng:randi() % c + 1
					if j <= k then
						sm[j] = t
					end
				end
			end
		end
		local q = self.firerain
		local tick = self.tick
		for _, o in targets do
			local tiles = {}
			-- half on its buildings
			local structs = {}
			for k = 0, Defs.STRUCT_KIND_COUNT - 1 do
				for _, s in self:structs_of(o, k) do
					if not s.dead then
						table.insert(structs, s.tile)
					end
				end
			end
			local on_b = math.min(#structs, want[o] // 2)
			for _ = 1, on_b do
				local j = rng:randi() % #structs + 1
				table.insert(tiles, structs[j])
				structs[j] = structs[#structs]
				structs[#structs] = nil
			end
			for _, t in sample[o] do
				if #tiles >= want[o] then
					break
				end
				table.insert(tiles, t)
			end
			for _, t in tiles do
				table.insert(q, { at = tick + 1 + rng:randi() % math.max(1, Rules.FIRERAIN_TICKS), tile = t, victim = o, owner = id })
			end
			self:add_grudge(o, id, Rules.NUKE_GRUDGE_TICKS)
			self:msg(o, Defs.MSG_ALERT, string.format("%s rains fire arrows on your land!", o_name[id]))
		end
		table.sort(q, function(a, b)
			if a.at ~= b.at then
				return a.at < b.at
			end
			return a.tile < b.tile
		end)
		self:msg(id, Defs.MSG_INFO, string.format("Your rain of fire arrows falls on %d nations", #targets))
		for _, h in self.humans do
			if h ~= id and not table.find(targets, h) then
				self:msg(h, Defs.MSG_INFO, string.format("%s rains fire arrows on all its enemies", o_name[id]))
			end
		end
	end

	--- The rain of fire arrows' fires that are due: each a small Fire (N_FIRERAIN's radii) that spares
	--- the launcher's friends (_ignite foes_of), quietly.
	function C:_firerain_tick()
		local q = self.firerain
		local tick = self.tick
		local n = 0
		while n < #q and q[n + 1].at <= tick do
			n += 1
			local f = q[n]
			local fake = {
				uid = self.next_uid,
				kind = N_FIRERAIN,
				owner = f.owner,
				to_tile = f.tile,
				target_owner = readi32(self.owner, f.tile * 4),
			}
			self.next_uid += 1
			self:_ignite(fake :: any, f.owner, true)
		end
		if n > 0 then
			local m = #q
			table.move(q, n + 1, m, 1)
			for i = m - n + 1, m do
				q[i] = nil
			end
		end
	end

	--- How many finished Temples `o` holds (they ease the plague).
	function C:_temples_of(o: number): number
		local n = 0
		for _, s in self:structs_of(o, S_TEMPLE) do
			if s.active and not s.dead then
				n += 1
			end
		end
		return n
	end

	--- The plague landing: the nation whose land it hit sickens (unless it is sick or immune already).
	function C:_plague_land(n: Nuke)
		local to = n.to_tile
		local victim = readi32(self.owner, to * 4)
		self:ev({ Ev.BOOM, n.uid, n.kind, to, 2, n.owner })
		local o_name = self.o_name
		if victim <= 0 or victim == n.owner then
			self:msg(n.owner, Defs.MSG_INFO, "The plague found no one to strike")
			return
		end
		-- (2026-11-06: a direct hit always takes, sick or immune; the land it spreads over breaks away)
		if self:_infect(victim, n.owner, Rules.PLAGUE_TICKS, 1.0, true) then
			self:_blight_start(victim, to, n.owner)
			-- (2026-11-07) the treasury lost in the chaos (Rules.PLAGUE_GOLD_LOSS)
			local lost = math.floor(self.o_gold[victim] * Rules.PLAGUE_GOLD_LOSS)
			if lost > 0 then
				self.o_gold[victim] -= lost
				self:msg(victim, Defs.MSG_BAD, string.format("The plague empties your treasury: %s gold lost", NumberFormat.render_number(lost)))
			end
			self:msg(victim, Defs.MSG_ALERT, string.format("%s struck your land with the plague! It is spreading: the land it reaches breaks away", o_name[n.owner]))
			self:msg(n.owner, Defs.MSG_INFO, string.format("The plague took hold in %s", o_name[victim]))
			for _, h in self.humans do
				if h ~= victim and h ~= n.owner then
					self:msg(h, Defs.MSG_INFO, string.format("The plague breaks out in %s", o_name[victim]))
				end
			end
		else
			self:msg(n.owner, Defs.MSG_INFO, string.format("%s resists the plague for now", o_name[victim]))
		end
	end

	--- Makes `o` sick with the plague for `ticks` (sent by `src`). False if it is sick or immune already
	--- (unless `force`: a direct hit). (2026-11-06: nothing eases it; `sev` 1 for a hit, the contagion's
	--- Rules.PLAGUE_SPREAD_SEV.)
	function C:_infect(o: number, src: number, ticks: number, sev0: number?, force: boolean?): boolean
		if o <= 0 or self.o_alive[o] ~= 1 or self.o_tiles[o] <= 0 then
			return false
		end
		-- (a new player never catches it)
		if self.o_rookie[o] == 1 then
			return false
		end
		local tick = self.tick
		local sick = self.o_plague_until[o] > tick
		if not force and (sick or self.o_plague_imm[o] > tick) then
			return false
		end
		local sev = math.max(sev0 or Rules.PLAGUE_SPREAD_SEV, if sick then self.o_plague_sev[o] else 0)
		local u = math.max(tick + ticks, self.o_plague_until[o])
		self.o_plague_until[o] = u
		self.o_plague_from[o] = tick
		self.o_plague_src[o] = src
		self.o_plague_sev[o] = sev
		self.o_plague_imm[o] = u + Rules.PLAGUE_IMMUNE_TICKS
		-- (2026-11-06) and its army stops growing for a while
		local halt = math.floor(Rules.PLAGUE_HALT_TICKS * sev + 0.5)
		self.o_plague_halt[o] = tick + halt
		if halt > 0 then
			self:msg(o, Defs.MSG_BAD, string.format("The plague stops your army from growing for %d s", math.ceil(halt / Rules.TICK_RATE)))
		end
		if not sick then
			table.insert(self.plague_list, o)
		end
		self:ev({ Ev.PLAGUE, o, u, src, math.floor(sev * 100 + 0.5) })
		return true
	end

	--- (2026-11-06) The plague spreading over `victim`'s land from tile `t` (sent by `src`): over
	--- Rules.PLAGUE_TICKS the land it reaches (its connected land, up to PLAGUE_LAND_SHARE of it) breaks
	--- away as an independent nation (_blights_tick). (2026-11-07: it grows as a ragged blot, not a
	--- diamond: the next tile is the one nearest the origin after a warp by angle (a few random lobes,
	--- reaching out like tendrils) and a little noise per tile, Rules.PLAGUE_LOBES / PLAGUE_JITTER.)
	function C:_blight_start(victim: number, t: number, src: number)
		if readi32(self.owner, t * 4) ~= victim then
			return
		end
		local budget = math.max(Rules.PLAGUE_LAND_MIN, math.floor(self.o_tiles[victim] * Rules.PLAGUE_LAND_SHARE))
		local steps = math.max(1, Rules.PLAGUE_LAND_TICKS // 5)
		local rng = self.rng
		local lobes = {}
		for _, l in Rules.PLAGUE_LOBES do
			table.insert(lobes, { k = l[1], a = l[2] * (0.6 + 0.8 * rng:randf()), ph = rng:randf() * math.pi * 2 })
		end
		local b = {
			victim = victim,
			src = src,
			at = t,
			x0 = t % self.W,
			y0 = t // self.W,
			lobes = lobes,
			seed = rng:randi() % 1000003,
			rid = 0,
			keys = {} :: { number },
			tiles = {} :: { number },
			seen = { [t] = true },
			budget = budget,
			per_step = math.max(1, math.ceil(budget / steps)),
			taken = 0,
			until_tick = self.tick + Rules.PLAGUE_LAND_TICKS,
		}
		self:_blight_push(b, t)
		table.insert(self.blights, b)
		self:ev({ Ev.BLIGHT, victim, 0, t, 0 })
	end

	--- A hash of grid point (x, y) for plague `seed`, in [0, 1).
	local function hash01(x: number, y: number, seed: number): number
		local h = (x * 374761393 + y * 668265263 + seed * 2246822519) % 4294967296
		h = ((h // 8192) * 1274126177 + h % 8192 * 3266489917) % 4294967296
		return (h % 100003) / 100003
	end

	--- Smooth noise in [0, 1) at (x, y), on a grid of `cell` tiles (value noise, smoothstepped).
	local function vnoise(x: number, y: number, cell: number, seed: number): number
		local gx, gy = x / cell, y / cell
		local ix, iy = math.floor(gx), math.floor(gy)
		local fx, fy = gx - ix, gy - iy
		fx = fx * fx * (3 - 2 * fx)
		fy = fy * fy * (3 - 2 * fy)
		local a = hash01(ix, iy, seed)
		local b = hash01(ix + 1, iy, seed)
		local c = hash01(ix, iy + 1, seed)
		local d = hash01(ix + 1, iy + 1, seed)
		return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy
	end

	--- How far the plague's front is from tile `t` (smaller is sooner): the distance from where it
	--- landed, shrunk along its lobes, plus noise at a few scales (Rules.PLAGUE_NOISE: { cell, tiles,
	--- tiles per tile of distance }) so its edge comes out ragged, with bays and spurs, and a little
	--- per tile (PLAGUE_JITTER).
	function C:_blight_key(b: any, t: number): number
		local x, y = t % self.W, t // self.W
		local dx, dy = x - b.x0, y - b.y0
		local d = math.sqrt(dx * dx + dy * dy)
		local ang = math.atan2(dy, dx)
		local lobe = 0
		for _, l in b.lobes do
			lobe += l.a * math.sin(l.k * ang + l.ph)
		end
		local warp = math.max(0.35, 1 + lobe)
		local k = d / warp
		for i, nz in Rules.PLAGUE_NOISE do
			k += (vnoise(x, y, nz[1], b.seed + i * 7919) - 0.5) * 2 * (nz[2] + nz[3] * d)
		end
		return k + hash01(x, y, b.seed) * Rules.PLAGUE_JITTER
	end

	--- A binary min-heap of (key, tile) in b.keys / b.tiles.
	function C:_blight_push(b: any, t: number)
		local keys, tiles = b.keys, b.tiles
		local k = self:_blight_key(b, t)
		local i = #keys + 1
		keys[i], tiles[i] = k, t
		while i > 1 do
			local p = i // 2
			if keys[p] <= k then
				break
			end
			keys[i], tiles[i] = keys[p], tiles[p]
			keys[p], tiles[p] = k, t
			i = p
		end
	end

	function C:_blight_pop(b: any): number
		local keys, tiles = b.keys, b.tiles
		local n = #keys
		local top = tiles[1]
		local lk, lt = keys[n], tiles[n]
		keys[n], tiles[n] = nil, nil
		n -= 1
		if n > 0 then
			local i = 1
			while true do
				local c = i * 2
				if c > n then
					break
				end
				if c < n and keys[c + 1] < keys[c] then
					c += 1
				end
				if keys[c] >= lk then
					break
				end
				keys[i], tiles[i] = keys[c], tiles[c]
				i = c
			end
			keys[i], tiles[i] = lk, lt
		end
		return top
	end

	--- The independent nation the plague's land becomes: "Free <province>", in a sickly shade of the
	--- old empire's colour (Rules.PLAGUE_TINT of the plague's green), an AI nation (SimRevolts.FREE_SKILL).
	function C:_blight_nation(b: any): number
		local victim = b.victim
		local pname = self:_province_name(victim, b.at)
		local base = "Free " .. pname
		local name = base
		local n = 1
		local function worn(nm: string): boolean
			for o = 1, self.owner_total do
				if self.o_alive[o] == 1 and self.o_name[o] == nm then
					return true
				end
			end
			return false
		end
		while worn(name) do
			n += 1
			name = string.format("%s %d", base, n)
		end
		local col = SimRevolts.rebel_color(self.o_color[victim])
		do
			local f = Rules.PLAGUE_TINT
			local function mix(c: number, g: number): number
				return math.clamp(math.floor(c * (1 - f) + g * f + 0.5), 0, 255)
			end
			local r, g, bl, a = (col // 0x1000000) % 256, (col // 0x10000) % 256, (col // 0x100) % 256, col % 256
			col = ((mix(r, 120) * 256 + mix(g, 190)) * 256 + mix(bl, 70)) * 256 + a
		end
		local rid = self:add_owner(name, col, Defs.KIND_NATION)
		if rid <= 0 then
			return 0
		end
		self.o_ai[rid] = 1
		self.o_skill[rid] = SimRevolts.FREE_SKILL
		self.o_spawned[rid] = 1
		self.o_spawn_tile[rid] = b.at
		-- (it rose out of the plague: it won't catch it again for a while)
		self.o_plague_imm[rid] = self.tick + Rules.PLAGUE_IMMUNE_TICKS
		self:ev({ Ev.SPAWNED, rid, b.at })
		self:msg(victim, Defs.MSG_BAD, string.format("The plague-struck %s breaks away: %s is independent", pname, name))
		self:msg_others(victim, Defs.MSG_INFO, string.format("The plague tears %s from %s", name, self.o_name[victim]))
		return rid
	end

	--- Each 5 ticks, the plague takes the next tiles of its struck land (nearest its warped front first,
	--- through the victim's land only) for the free nation; done when its time is up, its share is
	--- taken or the land around it is gone. Ev.BLIGHT tells the clients where its front went (a few of
	--- the tiles it took: Map/FxLayer.blight).
	function C:_blights_tick()
		local list = self.blights
		if #list == 0 or self.tick % 5 ~= 0 then
			return
		end
		local owner = self.owner
		local W = self.W
		local NW = self.N - W
		local tick = self.tick
		local i = 1
		while i <= #list do
			local b = list[i]
			local victim = b.victim
			local took = {}
			while #took < b.per_step and b.taken < b.budget and #b.keys > 0 and self.o_alive[victim] == 1 do
				local t = self:_blight_pop(b)
				if readi32(owner, t * 4) ~= victim then
					continue
				end
				if b.rid == 0 then
					b.rid = self:_blight_nation(b)
					if b.rid == 0 then
						b.keys, b.tiles = {}, {}
						break
					end
				end
				self:set_owner(t, b.rid)
				table.insert(took, t)
				b.taken += 1
				local x = t % W
				local function push(u: number)
					if not b.seen[u] and readi32(owner, u * 4) == victim then
						b.seen[u] = true
						self:_blight_push(b, u)
					end
				end
				if x > 0 then push(t - 1) end
				if x < W - 1 then push(t + 1) end
				if t >= W then push(t - W) end
				if t < NW then push(t + W) end
			end
			local rid = b.rid
			-- (2026-11-07) the garrison of the land that broke away goes with it: the victim's troops in
			-- the share of its land just taken
			if rid > 0 and #took > 0 and self.o_alive[rid] == 1 then
				local before = self.o_tiles[victim] + #took
				local moved = self.o_troops[victim] * #took / math.max(1, before)
				self.o_troops[victim] -= moved
				self.o_troops[rid] += moved
			end
			if rid > 0 and self.o_alive[rid] == 1 then
				-- a free nation's army: at least half a nation's cap for the land it holds
				local levy = 0.5 * self.R.max_troops(Defs.KIND_NATION, self.o_tiles[rid], 0, SimRevolts.FREE_SKILL)
				self.o_troops[rid] = math.max(self.o_troops[rid], levy)
			end
			local done = tick >= b.until_tick or b.taken >= b.budget or #b.keys == 0 or self.o_alive[victim] ~= 1
			-- (where the front went: up to PLAGUE_FX_TILES of the tiles taken, spread over them)
			if #took > 0 or done then
				local e = { Ev.BLIGHT, victim, rid, b.at, if done then 1 else 0 }
				local m = math.min(#took, Rules.PLAGUE_FX_TILES)
				for j = 1, m do
					table.insert(e, took[math.max(1, math.floor(j * #took / m))])
				end
				self:ev(e)
			end
			if done then
				list[i] = list[#list]
				list[#list] = nil
				if rid > 0 and b.taken > 0 then
					self:msg(victim, Defs.MSG_BAD, string.format("The plague took %d tiles of your land", b.taken))
				end
				continue
			end
			i += 1
		end
	end

	--- The owners whose land touches `o`'s (walks its border list).
	function C:_neighbor_owners(o: number): { number }
		local out, seen = {}, {}
		local owner = self.owner
		local bnext = self.bnext
		local W = self.W
		local NW = self.N - W
		local t = self.bhead[o]
		local function see(q: number)
			if q > 0 and q ~= o and not seen[q] then
				seen[q] = true
				table.insert(out, q)
			end
		end
		while t ~= -1 do
			local x = t % W
			if x > 0 then
				see(readi32(owner, (t - 1) * 4))
			end
			if x < W - 1 then
				see(readi32(owner, (t + 1) * 4))
			end
			if t >= W then
				see(readi32(owner, (t - W) * 4))
			end
			if t < NW then
				see(readi32(owner, (t + W) * 4))
			end
			t = readi32(bnext, t * 4)
		end
		table.sort(out)
		return out
	end

	--- The sick lose troops; the plague passes to their neighbours; it ends when its time is up.
	function C:_plague_tick()
		local list = self.plague_list
		local tick = self.tick
		local o_troops = self.o_troops
		local o_name = self.o_name
		local i = 1
		while i <= #list do
			local o = list[i]
			if tick >= self.o_plague_until[o] or self.o_alive[o] ~= 1 then
				self.o_plague_until[o] = 0
				list[i] = list[#list]
				list[#list] = nil
				self:ev({ Ev.PLAGUE, o, 0, 0, 0 })
				if self.o_alive[o] == 1 then
					self:msg(o, Defs.MSG_GOOD, "The plague has left your land")
				end
				continue
			end
			local loss = o_troops[o] * Rules.PLAGUE_LOSS_PER_S * self.o_plague_sev[o] / Rules.TICK_RATE
			self.dbg_flow[o * 5 + 3] += loss
			o_troops[o] -= loss
			i += 1
		end
		if tick % Rules.PLAGUE_SPREAD_GAP ~= 0 then
			return
		end
		local rng = self.rng
		for _, o in table.clone(list) do
			if tick - self.o_plague_from[o] < Rules.PLAGUE_SPREAD_AFTER then
				continue
			end
			for _, q in self:_neighbor_owners(o) do
				if self.o_plague_until[q] > tick or self.o_plague_imm[q] > tick then
					continue
				end
				-- (2026-11-06: nothing eases it: the contagion's own severity, Rules.PLAGUE_SPREAD_SEV)
				local p = Rules.PLAGUE_SPREAD_P
				if rng:randf() < p and self:_infect(q, self.o_plague_src[o], Rules.PLAGUE_SPREAD_TICKS, Rules.PLAGUE_SPREAD_SEV) then
					self:msg(q, Defs.MSG_ALERT, string.format("The plague spread to your land from %s", o_name[o]))
				end
			end
		end
	end

	--- Snapshot rows of the sick: { owner, until_tick, source, severity x100 }.
	function C:plague_rows(): { { number } }
		local out = {}
		for _, o in self.plague_list do
			table.insert(out, { o, self.o_plague_until[o], self.o_plague_src[o], math.floor(self.o_plague_sev[o] * 100 + 0.5) })
		end
		table.sort(out, function(a, b)
			return a[1] < b[1]
		end)
		return out
	end

	function C:nuke_rows(): { { number } }
		local out = {}
		for _, n in self.nukes do
			if not n.dead then
				table.insert(out, { n.uid, n.kind, n.owner, n.from_tile, n.to_tile, n.launch_tick, n.flight })
			end
		end
		return out
	end
end

function SimNukes._mirv_mark(grid: { [number]: { number } }, W: number, t: number, gap: number)
	local k = ((t // W) // gap) * 65536 + ((t % W) // gap)
	local cell = grid[k]
	if cell == nil then
		cell = {}
		grid[k] = cell
	end
	table.insert(cell, t)
end

function SimNukes._mirv_overlaps(
	grid: { [number]: { number } },
	W: number,
	t: number,
	gap: number,
	geo_manhattan: (number, number) -> number
): boolean
	local gx = (t % W) // gap
	local gy = (t // W) // gap
	for dy = -1, 1 do
		for dx = -1, 1 do
			if gx + dx < 0 or gy + dy < 0 then
				continue
			end
			local cell = grid[(gy + dy) * 65536 + (gx + dx)]
			if cell == nil then
				continue
			end
			for _, o in cell do
				if geo_manhattan(o, t) < gap then
					return true
				end
			end
		end
	end
	return false
end

return SimNukes
