-- Port of scripts/ui/ui_rules.gd
-- Client-side game knowledge for the interface: build/nuke catalogue, costs (via Rules), what a
-- click on a tile would do, radial-menu contents and placement checks. These are hints only; the
-- Sim validates every intent for real.
-- (The GDScript's unused private helpers _site_ok / _nearest_own / _neighbours4 are left out.)

local UICtx = require("./UICtx") :: any
local Defs = UICtx.core("Defs")

local _Rules: any = nil
local function Rules(): any
	if _Rules == nil then
		_Rules = UICtx.core("Rules")
	end
	return _Rules
end
local _Theme: any = nil
local function T(): any
	if _Theme == nil then
		_Theme = UICtx.mod("UITheme")
	end
	return _Theme
end

local _Arsenal: any = nil
local function Arsenal(): any
	if _Arsenal == nil then
		_Arsenal = UICtx.data("Arsenal")
	end
	return _Arsenal
end

local UIRules = {}
UIRules.__index = UIRules

-- (Empires Front: no SAMs, silos, bombs or Arsenal; no farms: 2026-10-31)
-- (Empires Front 2026-10-31: the Border Wall and the Barracks)
-- (2026-11-01: the empire's ecosystem: Farm, Temple, Palace, Fortress, University)
-- (2026-11-06: the siege weapons: the Watchtower and the Siege Workshop, which fires the era's
-- bombard, fire and the plague; the weapons' slots show once the player has a workshop: CommandBar)
UIRules.BUILD_KINDS = { "city", "mine", "market", "port", "factory", "defense", "forge", "warship", "wall", "barracks", "farm", "temple", "palace", "university", "sam", "silo" }
UIRules.NUKE_KINDS = { "atom", "hydrogen", "plague" }
--- Hotkeys 1..9, 0 in this order.
UIRules.ACTIONS = { "city", "mine", "market", "port", "factory", "defense", "forge", "warship", "wall", "barracks", "farm", "temple", "palace", "university", "sam", "silo", "atom", "hydrogen", "plague" }
UIRules.HOTKEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "[", "]", "\\", ";", "'", ",", "." }
--- The Arsenal's kinds (Data/Arsenal: unlocked with Stars or Robux), in the order of its tray:
--- structures, munitions launched like a nuke (the last two from their own structure: strikes), and
--- the Reinforcements call. A locked one is offered in the Arsenal instead of doing anything.
UIRules.ARSENAL_BUILD = {}
UIRules.ARSENAL_NUKES = {}
UIRules.ARSENAL = {}

UIRules.TITLES = {
	city = "City",
	port = "Port",
	factory = "Factory",
	defense = "Defense Post",
	forge = "Forge",
	farm = "Farm",
	mine = "Mine",
	market = "Market",
	wall = "Border Wall",
	barracks = "Barracks",
	temple = "Temple",
	palace = "Palace",
	fortress = "Fortress",
	university = "University",
	sam = "SAM Launcher",
	silo = "Missile Silo",
	warship = "Warship",
	atom = "Atom Bomb",
	hydrogen = "Hydrogen Bomb",
	plague = "Plague",
	mirv = "MIRV",
	artillery = "Artillery",
	airfield = "Airfield",
	railgun = "Railgun",
	mega = "Mega Nuke",
	scatter = "Scattershot",
	airstrike = "Air Strike",
	slug = "Railgun Shot",
	reinforce = "Reinforcements",
}
UIRules.SHORT = {
	city = "City",
	port = "Port",
	factory = "Factory",
	defense = "Defense",
	forge = "Forge",
	farm = "Farm",
	mine = "Mine",
	market = "Market",
	wall = "Wall",
	barracks = "Barracks",
	temple = "Temple",
	palace = "Palace",
	fortress = "Fortress",
	university = "University",
	sam = "SAM",
	silo = "Silo",
	warship = "Warship",
	-- (2026-11-06: the siege weapons' short names: the era's words translate the long ones)
	atom = "Bombard",
	hydrogen = "Fire",
	plague = "Plague",
	mirv = "MIRV",
	artillery = "Artillery",
	airfield = "Airfield",
	railgun = "Railgun",
	mega = "Mega",
	scatter = "Scatter",
	airstrike = "Strike",
	slug = "Slug",
	reinforce = "Troops",
}
UIRules.BLURBS = {
	city = "Raises your troop cap by {city}. Joins the road network.",
	port = "Coastal. Sends trade ships for gold and builds warships.",
	factory = "Road hub: every building within its reach joins the roads. Carts pay gold at every city, port, mine and market they pass.",
	defense = "Land within {def_r} tiles costs attackers {def_mag}x the troops and {def_cost}x the time. On hills or mountains, build on your own post again to raise it into a Fortress: {fort_mag}x the troops and {fort_cost}x the time within {fort_r} tiles, and it calms the province (at most {fort_lim}).",
	forge = "Arms your troops (each level also needs Ore). Tiers: {forge_next}. At most 2 Forges per player: build near one to upgrade it.",
	farm = "Feeds a bigger army: your troop cap +{farm_pct}% a level ({farm_plain}% on plains, less on hills or cold land). Near a Temple: x{farm_bless} (a blessed harvest).",
	temple = "Calms the provinces within {temple_r} tiles and blesses the Farms there (x{farm_bless}). Each Temple also calms your whole empire a little. Universities near one study x{uni_temple}. At most {temple_lim}, no upgrades.",
	palace = "Your seat of power: land taxes +{pal_tax}%, and no province within {pal_r} tiles ever revolts. Universities near it study x{uni_palace}. Only one. If it is taken, the enemy loots {pal_loot}% of your gold and your provinces stir.",
	fortress = "A great Defense Post on hills or mountains: land within {fort_r} tiles costs attackers {fort_mag}x the troops and {fort_cost}x the time. Its garrison keeps the province calm. At most {fort_lim}, no upgrades; razed if taken.",
	university = "Scholars: +{uni_pct}% gold income each (taxes and Market sales), x{uni_temple} near a Temple, x{uni_palace} near the Palace (up to +{uni_max}%). At most {uni_lim}, no upgrades.",
	mine = "Digs {mine_ore} Ore a second for each level. Only on hills or mountains (more in mountains). On the roads (a Factory in reach): +50% Ore.",
	market = "Sells up to {mkt_ore} spare Ore a second for each level at the match's Ore price (it keeps what your next Forge level needs). Each trade pact raises what it gets by 20%. On the roads: sells 50% more.",
	wall = "Raises stone walls along your frontier within {wall_r} tiles: taking a walled tile costs {wall_mag}x the troops and {wall_cost}x the time. The stones follow the frontier and fall with the tile.",
	barracks = "Trains troops: each level makes your army grow {bar_pct}% faster (up to {bar_max} levels). Your troop cap stays the same. At most 4 Barracks per player: build near one to upgrade it.",
	sam = "Shoots down siege shots that pass within {sam_r} tiles. At most 4, no upgrades.",
	silo = "Fires your siege weapons at land within {silo_r} tiles: one shot a minute each, from {siege_at} of war on. At most 5 per player.",
	warship = "Patrols where you send it: sinks transports, then warships, and captures trade ships. Heals at your ports.",
	atom = "Razes a {atom_r}-tile circle: troops, land and buildings. The land stays scorched for {scorch_s} s. Walls and Fortresses halve the damage.",
	hydrogen = "Fire that spreads over {fire_r} tiles in {fire_s} s, burning land and buildings as it goes. Walls and Fortresses halve the damage.",
	plague = "Sickens the nation it lands on: it loses {plague_pct}% of its troops a second for {plague_s} s and passes it to its neighbours (yours too, if you border them). Each Temple eases it.",
	mirv = "Splits into up to {mirv_n} warheads that rain over one nation.",
	artillery = "Shells every enemy within {art_r} tiles on its own: their troops, and the structures it reaches.",
	airfield = "Flies Air Strikes on any spot within {air_r} tiles. Rearms in {air_s} s.",
	railgun = "Fires at any spot on the map. Reloads in {rail_s} s.",
	mega = "Twice an Atom Bomb's radius: four times the ground, gone.",
	scatter = "An Atom Bomb with {scat_lo} to {scat_hi} warheads that come down around it.",
	airstrike = "Bombs a {air_blast}-tile circle: kills troops and wrecks structures. No SAM can stop it.",
	slug = "A slug that takes a level off every structure it hits. Nothing intercepts it.",
	reinforce = "Brings a fifth of your troop cap at once. Ready again every {rein_s} s.",
}

--- Godot String.format({key: value}): replaces {key} placeholders.
function UIRules.format(text: string, values: { [string]: string }): string
	return (
		string.gsub(text, "{([%w_]+)}", function(k: string)
			local v = values[k]
			return if v ~= nil then v else "{" .. k .. "}"
		end)
	)
end

--- The per-player cap on `kind` in words ("" if none or the blurb says it already).
function UIRules.limit_note(kind: string, text: string): string
	local R = Rules()
	if string.find(text, "At most", 1, true) or string.find(text, "Only one", 1, true) then
		return ""
	end
	local sk = Defs.struct_kind_from_name(kind)
	if sk < 0 then
		return ""
	end
	local lim, lv = R.struct_limit(sk), R.level_limit(sk)
	if lim ~= nil and lv ~= nil then
		return string.format(" At most %d per player, %d levels in all.", lim, lv)
	elseif lim ~= nil then
		return string.format(" At most %d per player.", lim)
	elseif kind == "city" or kind == "port" or kind == "factory" then
		return " Each one past the 4th costs more."
	end
	return ""
end

--- Blurb with its numbers filled in from Rules.
function UIRules.blurb(kind: string): string
	local text = UIRules._blurb(kind)
	return text .. UIRules.limit_note(kind, text)
end

function UIRules._blurb(kind: string): string
	local R = Rules()
	return UIRules.format(UIRules.BLURBS[kind] or "", {
		city = T().fmt_troops(R.CITY_TROOPS),
		def_r = tostring(Defs.round(R.defense_range())),
		def_mag = tostring(Defs.round(R.DEFENSE_POST_MAG)),
		def_cost = tostring(Defs.round(R.DEFENSE_POST_COST)),
		sam_r = tostring(Defs.round(R.sam_range(1))),
		mirv_n = tostring(R.MIRV_WARHEADS),
		art_r = tostring(Defs.round(R.artillery_range())),
		air_r = tostring(Defs.round(R.launch_range(Defs.N_AIRSTRIKE))),
		air_s = tostring(R.RELOAD_TICKS[Defs.S_AIRFIELD] // Defs.TICK_RATE),
		rail_s = tostring(R.RELOAD_TICKS[Defs.S_RAILGUN] // Defs.TICK_RATE),
		air_blast = tostring(Defs.round(R.NUKE_RADIUS[Defs.N_AIRSTRIKE])),
		scat_lo = tostring(R.SCATTER_MIN),
		scat_hi = tostring(R.SCATTER_MAX),
		rein_s = tostring(R.REINFORCE_COOLDOWN_TICKS // Defs.TICK_RATE),
		forge_next = UIRules.forge_tiers(),
		farm_food = "45",
		mine_ore = "3",
		mkt_ore = "8",
		wall_r = tostring(Defs.round(R.wall_radius())),
		wall_mag = tostring(Defs.round(R.WALL_MAG)),
		wall_cost = tostring(Defs.round(R.WALL_COST)),
		bar_pct = tostring(math.floor(R.BARRACKS_GROWTH * 100 + 0.5)),
		bar_max = tostring(R.BARRACKS_MAX_LEVELS),
		-- (2026-11-01) the ecosystem
		farm_pct = tostring(math.floor(R.FARM_CAP * 100 + 0.5)),
		farm_plain = string.format("%.1f", R.FARM_CAP * 100 * (R.FARM_TERRAIN[Defs.T_PLAINS] or 1)),
		farm_bless = tostring(R.FARM_BLESSED),
		temple_r = tostring(Defs.round(R.temple_range(1))),
		temple_lim = tostring(R.TEMPLE_LIMIT),
		pal_tax = tostring(math.floor(R.PALACE_TAX * 100 + 0.5)),
		pal_r = tostring(Defs.round(R.palace_range())),
		pal_loot = tostring(math.floor(R.PALACE_LOOT * 100 + 0.5)),
		fort_r = tostring(Defs.round(R.fortress_range())),
		fort_mag = tostring(R.FORTRESS_MAG),
		fort_cost = tostring(R.FORTRESS_COST),
		fort_lim = tostring(R.FORTRESS_LIMIT),
		uni_pct = tostring(math.floor(R.UNI_INCOME * 100 + 0.5)),
		uni_temple = tostring(R.UNI_NEAR_TEMPLE),
		uni_palace = tostring(R.UNI_NEAR_PALACE),
		uni_max = tostring(math.floor(R.UNI_MAX * 100 + 0.5)),
		uni_lim = tostring(R.UNIVERSITY_LIMIT),
		-- (2026-11-06) the siege weapons
		silo_r = tostring(Defs.round(R.launch_range(Defs.N_ATOM))),
		siege_at = T().fmt_time((R.SIEGE_UNLOCK_TICKS or 0) // Defs.TICK_RATE),
		atom_r = tostring(Defs.round(R.NUKE_RADIUS[Defs.N_ATOM])),
		fire_r = tostring(Defs.round(R.NUKE_RADIUS[Defs.N_HYDROGEN])),
		fire_s = tostring((R.FIRE_SPREAD_TICKS or 60) // Defs.TICK_RATE),
		scorch_s = tostring((R.SCORCH_TICKS or 1200) // Defs.TICK_RATE),
		plague_pct = string.format("%.1f", (R.PLAGUE_LOSS_PER_S or 0) * 100),
		plague_s = tostring((R.PLAGUE_TICKS or 900) // Defs.TICK_RATE),
	})
end

--- The era's Forge tiers in order (Data/Eras forge), e.g. "Gladius (+15% attack) > Scutum (+15% defence)".
function UIRules.forge_tiers(): string
	local Eras = UICtx.data("Eras")
	local e = Eras.current() or Eras.list[1]
	local parts = {}
	for _, t in e.forge do
		local what = if t.atk > 0 then string.format("+%d%% attack", math.floor(t.atk * 100 + 0.5))
			else string.format("+%d%% defence", math.floor(t.def * 100 + 0.5))
		table.insert(parts, t.name .. " (" .. what .. ")")
	end
	return table.concat(parts, " > ")
end

function UIRules.new(c: any)
	local self = setmetatable({}, UIRules)
	self.ctx = c
	-- One-entry cache for primary(): hover card and the following click ask about the same tile.
	self._pc_tile = -1
	self._pc_msec = 0
	self._pc_tick = -1
	self._pc_ratio = -1.0
	self._pc = {} :: { [string]: any }
	-- Local owner's structure counts by kind (index = Defs.S_*) plus warships and transports, kept
	-- current from GameState signals so availability checks are O(1).
	self._scount = table.create(Defs.STRUCT_KIND_COUNT, 0)
	self._scount[0] = 0
	self._warships = 0
	self._transports = 0
	self._counted_owner = -1
	return self
end

--- The Arsenal item (Data/Arsenal) a build / launch kind belongs to; nil for the kinds everyone has.
function UIRules.arsenal_item(kind: string): any
	return Arsenal().item_for(kind)
end

--- True when `kind` is an Arsenal kind the player hasn't unlocked.
function UIRules.arsenal_locked(self: any, kind: string): boolean
	local it = Arsenal().item_for(kind)
	if it == nil then
		return false
	end
	local s = self.ctx.session
	return not (s ~= nil and type(s.has_unlock) == "function" and s:has_unlock(it.key))
end

--- A strike: a munition its own structure fires (an Air Strike, a Railgun shot), not a silo.
function UIRules.is_strike(kind: string): boolean
	return kind == "airstrike" or kind == "slug"
end

--- The structure kind (Defs.S_*) a nuke / strike kind leaves from.
function UIRules.launcher(kind: string): number
	local nk = Defs.nuke_kind_from_name(kind)
	local l = if nk >= 0 then Rules().NUKE_LAUNCHER[nk] else nil
	return if type(l) == "number" and l >= 0 then l else Defs.S_SILO
end

--- The troops/s label is green while the regrowth rate
--- (Rules.troop_growth) is >= its previous sample and orange once it drops — past the troop
--- count that regrows fastest (the (1 - troops / max) fall-off overtakes the troops^0.73 term), or
--- when losing land lowers the cap. `last` = nil (no previous sample) keeps it green.
function UIRules.troop_rate_rising(rate: number, last: number?): boolean
	return last == nil or rate >= last
end

--- The label text: "+" .. render_troops(rate per second) .. "/s"; render_number clamps at 0,
--- so a nation above its cap after losing land reads "+0/s".
function UIRules.troop_rate_text(per_second: number): string
	return "+" .. T().fmt_troops(math.max(per_second, 0.0)) .. "/s"
end

--- Aimed at a target tile and launched (the bombs, and the Arsenal's munitions).
function UIRules.is_nuke(kind: string): boolean
	return kind == "atom"
		or kind == "hydrogen"
		or kind == "plague"
		or kind == "mirv"
		or kind == "mega"
		or kind == "scatter"
		or kind == "airstrike"
		or kind == "slug"
end

-- ---------------------------------------------------------------------------------------------
-- Costs (single adapter over Core/Rules)
-- ---------------------------------------------------------------------------------------------

--- `owned`: structures of the kinds that share the cost count, warships for "warship", MIRVs
--- launched this match for "mirv".
function UIRules.rules_cost(kind: string, owned: number): number
	if UIRules.is_nuke(kind) then
		return Rules().nuke_cost(kind, owned)
	end
	return Rules().build_cost(kind, owned)
end

--- (inner, outer) blast radii in tiles (MIRV: 0, spread) — Rules.nuke_radii. Two numbers.
function UIRules.nuke_radii(kind: string): (number, number)
	local k = Defs.nuke_kind_from_name(kind)
	if k < 0 then
		return 0, 0
	end
	local a, b = Rules().nuke_radii(k)
	if typeof(a) == "Vector2" then
		return a.X, a.Y
	end
	return a or 0, b or 0
end

function UIRules.nuke_radius(kind: string): number
	local _, outer = UIRules.nuke_radii(kind)
	return Defs.round(outer)
end

--- "Blast radius" text for tooltips: "15 tiles (6 wiped out)" / MIRV spread.
function UIRules.blast_text(kind: string): string
	local inner, outer = UIRules.nuke_radii(kind)
	if kind == "mirv" then
		-- MIRV_WARHEADS is the cap: the real count follows the target's land (55-tile spacing)
		return string.format("Up to %d warheads across the target nation", Rules().MIRV_WARHEADS)
	end
	if inner > 0.0 then
		return string.format("%d tiles (%d wiped out)", Defs.round(outer), Defs.round(inner))
	end
	return string.format("%d tiles", Defs.round(outer))
end

--- The victory metric as result-screen copy (review R2-4): `win` = share of the land outside
--- fallout (what Sim._check_victory compares with Rules.WIN_SHARE), `land` = share of all land.
--- "80.1%" + `all_land` when nothing is irradiated (or it makes no visible difference), else
--- "80.1% of the land outside fallout" -- never a number that reads as short of the 80% goal.
function UIRules.win_phrase(win: number, land: number, fallout: number, all_land: string): string
	local pct = T().fmt_pct(win)
	if fallout > 0 and T().fmt_pct(land) ~= pct then
		return pct .. " of the land outside fallout"
	end
	return pct .. all_land
end

--- What the result screen's offers say for a payout and an inventory (UI/GameOver; tests/offers.luau):
--- the next unlock with the Stars towards it, and 2x Stars with what this match would have paid.
--- `stars`: the balance to count with (the payout's own, or the inventory's once it changed since).
--- Returns { goal = { key, text, ready }?, x2 = { text }? }.
function UIRules.result_offers(award: any, inv: any, catalog: any, stars: number?): { [string]: any }
	local out: { [string]: any } = {}
	if award == nil or (tonumber(award.total) or 0) <= 0 or type(inv) ~= "table" or inv.loaded == false then
		return out
	end
	local unlocks = if type(inv.unlocks) == "table" then inv.unlocks else {}
	local balance = math.max(0, math.floor(stars or tonumber(award.balance) or tonumber(inv.stars) or 0))
	local goal = catalog.next_goal(unlocks)
	if goal ~= nil then
		local ready = balance >= goal.stars
		out.goal = {
			key = goal.key,
			ready = ready,
			text = if ready
				then "UNLOCK " .. string.upper(goal.title)
				else string.format("%s  %s / %s", string.upper(goal.title), UICtx.commas(balance), UICtx.commas(goal.stars)),
		}
	end
	if not unlocks.stars2x and catalog.item("stars2x") ~= nil then
		-- (a payout already doubled never gets here: its owner has the booster)
		out.x2 = { text = string.format("WITH 2X STARS: +%s", UICtx.commas(math.floor(award.total) * 2)) }
	end
	return out
end

--- Seconds for the result screen's "Match duration" card: the whole match (stats.match_s, set at
--- game over) on a result, the moment the player fell (duration_s) on ELIMINATED (review R2-6).
function UIRules.result_seconds(kind: string, stats: { [string]: any }): number
	local secs = tonumber(stats.duration_s) or 0.0
	local m = tonumber(stats.match_s)
	if kind ~= "eliminated" and m ~= nil then
		secs = m
	end
	return secs
end

--- Full recount (on bind / when the local owner changes). Everything else is incremental.
function UIRules.recount(self: any)
	if self._m ~= nil then
		self._m.state = nil
	end
	self._scount = table.create(Defs.STRUCT_KIND_COUNT, 0)
	self._scount[0] = 0
	self._warships = 0
	self._transports = 0
	local s = self.ctx.state
	local me = self.ctx:me()
	self._counted_owner = me
	if s == nil or me == 0 then
		return
	end
	for _, st in s.structures do
		if st.owner == me and st.kind >= 0 and st.kind < Defs.STRUCT_KIND_COUNT then
			self._scount[st.kind] += 1
		end
	end
	for _, u in s.units do
		if u.owner == me then
			if u.kind == Defs.U_WARSHIP then
				self._warships += 1
			elseif u.kind == Defs.U_TRANSPORT then
				self._transports += 1
			end
		end
	end
end

--- Structure moved between owners (old -> new); returns true when the local owner is involved.
function UIRules.on_structure(self: any, kind: number, old_owner: number, new_owner: number): boolean
	local me = self.ctx:me()
	if me == 0 or kind < 0 or kind >= Defs.STRUCT_KIND_COUNT then
		return false
	end
	if self._m ~= nil then
		self._m.state = nil
	end
	if self._counted_owner ~= me then
		self:recount()
		return true
	end
	local hit = false
	if old_owner == me then
		self._scount[kind] = math.max(0, self._scount[kind] - 1)
		hit = true
	end
	if new_owner == me then
		self._scount[kind] += 1
		hit = true
	end
	return hit
end

--- Unit added (+1) or removed (-1); returns true when it is ours.
function UIRules.on_unit(self: any, kind: number, owner_id: number, delta: number): boolean
	local me = self.ctx:me()
	if me == 0 or owner_id ~= me then
		return false
	end
	if self._counted_owner ~= me then
		self:recount()
		return true
	end
	if kind == Defs.U_WARSHIP then
		self._warships = math.max(0, self._warships + delta)
	elseif kind == Defs.U_TRANSPORT then
		self._transports = math.max(0, self._transports + delta)
	end
	return true
end

function UIRules.struct_count(self: any, kind: number): number
	if self._counted_owner ~= self.ctx:me() then
		self:recount()
	end
	return if kind >= 0 and kind < Defs.STRUCT_KIND_COUNT then self._scount[kind] else 0
end

function UIRules.transports(self: any): number
	if self._counted_owner ~= self.ctx:me() then
		self:recount()
	end
	return self._transports
end

function UIRules.owned(self: any, kind: string): number
	local ctx = self.ctx
	if ctx.state == nil or ctx:me() == 0 then
		return 0
	end
	if self._counted_owner ~= ctx:me() then
		self:recount()
	end
	if kind == "warship" then
		return self._warships
	end
	if kind == "mirv" then
		return ctx.state.mirvs_launched or 0
	end
	if UIRules.is_nuke(kind) or kind == "reinforce" then
		return 0
	end
	local n = 0
	for _, sk in Rules().cost_count_kinds(kind) do
		n += self:struct_count(sk)
	end
	return n
end

--- The local player's structures by kind, from one pass over the match's, kept while the frame is
--- the same (state, tick, render tick and owner): per kind (index kind + 1) the level sum, the
--- finished and building counts, the seconds until the first one building finishes, and the
--- structures themselves. (2026-10-27: the build slots refresh 2-4 times a second and each slot made
--- its own passes, ~17 over every structure in the match per refresh: costs, silos, launchers. The
--- answers are the same.)
function UIRules._mine(self: any, s: any): any
	local me = self.ctx:me()
	local m = self._m
	if m == nil then
		local n = Defs.STRUCT_KIND_COUNT
		m = { level = table.create(n, 0), act = table.create(n, 0), building = table.create(n, 0) }
		m.soonest = table.create(n, math.huge)
		m.list = {}
		for k = 1, n do
			m.list[k] = {}
		end
		self._m = m
	elseif m.state == s and m.tick == s.tick and m.rt == s.render_tick and m.me == me then
		return m
	end
	m.state, m.tick, m.rt, m.me = s, s.tick, s.render_tick, me
	local level, act, building, soonest, list = m.level, m.act, m.building, m.soonest, m.list
	for k = 1, Defs.STRUCT_KIND_COUNT do
		level[k], act[k], building[k], soonest[k] = 0, 0, 0, math.huge
		table.clear(list[k])
	end
	local tick = s.tick
	for _, st in s.structures do
		local k = st.kind
		if st.owner ~= me or k < 0 or k >= Defs.STRUCT_KIND_COUNT then
			continue
		end
		k += 1
		level[k] += st.level
		if st.active_tick > tick then
			building[k] += 1
			soonest[k] = math.min(soonest[k], (st.active_tick - tick) / Defs.TICK_RATE)
		else
			act[k] += 1
		end
		table.insert(list[k], st)
	end
	return m
end

--- What Rules.cost_of reads the state through: the local player's level sums from _mine, the rest
--- from the state itself.
function UIRules._cost_view(self: any, s: any): any
	local view = self._view
	if view == nil then
		local mt = { __index = s }
		view = setmetatable({
			struct_level_sum = function(_, id: number, kind: number): number
				local st = mt.__index
				if id == self.ctx:me() and kind >= 0 and kind < Defs.STRUCT_KIND_COUNT then
					return self:_mine(st).level[kind + 1]
				end
				return st:struct_level_sum(id, kind)
			end,
		}, mt)
		self._view, self._view_mt = view, mt
	end
	self._view_mt.__index = s
	return view
end

--- Gold for the next `kind` (structures, upgrades, warships, nukes) — Rules.cost_of, the Sim's
--- own pricing (shared port/factory count, levels, worldwide MIRV launches).
function UIRules.cost(self: any, kind: string): number
	local ctx = self.ctx
	if kind == "reinforce" then
		return Rules().REINFORCE_COST
	end
	if ctx.state == nil then
		return UIRules.rules_cost(kind, 0)
	end
	return Rules().cost_of(self:_cost_view(ctx.state), ctx:me(), kind)
end

--- The local player's finished structures of `kind` that can fire now (a silo's loaded missiles, an
--- airfield / railgun that isn't reloading), and the seconds until the next one can when none does.
function UIRules.ready_launchers(self: any, kind: number): (number, number)
	local s = self.ctx.state
	if s == nil then
		return 0, 0.0
	end
	local cd = Rules().RELOAD_TICKS[kind] or 0
	local n = 0
	local soonest = math.huge
	local mine = if kind >= 0 and kind < Defs.STRUCT_KIND_COUNT then self:_mine(s).list[kind + 1] else {}
	for _, st in mine do
		if st.active_tick <= s.tick then
			local busy = 0
			local first = math.huge
			for _, t in st.shots or {} do
				if t + cd > s.tick then
					busy += 1
					first = math.min(first, t + cd - s.tick)
				end
			end
			local free = math.max(0, (st.level or 1) - busy)
			n += free
			if free == 0 then
				soonest = math.min(soonest, first)
			end
		end
	end
	return n, if n == 0 and soonest < math.huge then soonest / Defs.TICK_RATE else 0.0
end

--- Finished (active) structures of `kind` the local player owns — silos must be built before a
--- nuke can fly. Returns active, under_construction, seconds until the first one finishes.
function UIRules.active_structs(self: any, kind: number): (number, number, number)
	local s = self.ctx.state
	if s == nil or kind < 0 or kind >= Defs.STRUCT_KIND_COUNT then
		return 0, 0, 0.0
	end
	local m = self:_mine(s)
	local k = kind + 1
	local building = m.building[k]
	return m.act[k], building, if building > 0 then m.soonest[k] else 0.0
end

--- {ok, locked, reason, cost} — whether the action can be used right now (ignores the target).
function UIRules.availability(self: any, kind: string): { [string]: any }
	local ctx = self.ctx
	local c = self:cost(kind)
	local out = { ok = false, locked = false, reason = "", cost = c } :: { [string]: any }
	local s = ctx.state
	local o = ctx:my()
	-- an Arsenal kind the player hasn't unlocked: `arsenal` names the item to offer
	if self:arsenal_locked(kind) then
		local it = UIRules.arsenal_item(kind)
		out.reason = "Unlock " .. it.title .. " in the Arsenal"
		out.locked = true
		out.arsenal = it.key
		return out
	end
	if s == nil or o == nil or not ctx:in_match() then
		out.reason = "Join a match first"
		out.locked = true
		return out
	end
	if not o.spawned then
		out.reason = "Place your capital first"
		out.locked = true
		return out
	end
	if not o.alive then
		out.reason = "You have been eliminated"
		out.locked = true
		return out
	end
	if s.phase ~= Defs.PHASE_PLAYING then
		out.reason = "Available once the match begins"
		out.locked = true
		return out
	end
	if UIRules.is_nuke(kind) then
		-- the structure it leaves from: a silo, or (strikes) an airfield / a railgun
		local lk = UIRules.launcher(kind)
		local title = Defs.STRUCT_TITLES[lk]
		if self:struct_count(lk) == 0 then
			out.reason = "Requires " .. (if lk == Defs.S_AIRFIELD then "an " else "a ") .. title
			out.locked = true
			return out
		end
		local act, _, soon = self:active_structs(lk)
		if act == 0 then
			local what = if lk == Defs.S_SILO then "Silo" else title
			out.reason = what .. " under construction · ready in " .. T().fmt_time(math.ceil(soon))
			out.locked = true
			return out
		end
		-- (Empires Front 2026-11-06) the siege weapons: none before SIEGE_UNLOCK_TICKS of war, then a
		-- shot a minute
		if lk == Defs.S_SILO then
			local left = Rules().siege_unlock_left(s.playing_since, s.tick)
			if left > 0 then
				out.reason = "Siege weapons in " .. T().fmt_time(math.ceil(left / Defs.TICK_RATE))
				out.locked = true
				return out
			end
			local ready, wait = self:ready_launchers(lk)
			if ready == 0 then
				out.reason = "Silo reloading · ready in " .. T().fmt_time(math.ceil(wait))
				return out
			end
		end
		if UIRules.is_strike(kind) then
			local ready, wait = self:ready_launchers(lk)
			if ready == 0 then
				out.reason = string.format(
					"%s · ready in %s",
					if lk == Defs.S_AIRFIELD then "Airfield rearming" else "Railgun reloading",
					T().fmt_time(math.ceil(wait))
				)
				return out
			end
		end
	end
	if kind == "reinforce" then
		local wait = ((s.reinforce_ready and s.reinforce_ready[o.id]) or 0) - s.tick
		if wait > 0 then
			out.reason = "Ready in " .. T().fmt_time(math.ceil(wait / Defs.TICK_RATE))
			return out
		end
		if Rules().reinforce_troops(o.troops or 0, o.max_troops or 0) <= 0 then
			out.reason = "Your army is at its cap"
			return out
		end
	end
	if kind == "port" and not ctx.borders:has_coast() then
		out.reason = "Requires a coastline"
		out.locked = true
		return out
	end
	if kind == "warship" and self:struct_count(Defs.S_PORT) == 0 then
		out.reason = "Requires a Port"
		out.locked = true
		return out
	end
	if kind == "warship" then
		local act, _, soon = self:active_structs(Defs.S_PORT)
		if act == 0 then
			out.reason = "Port under construction · ready in " .. T().fmt_time(math.ceil(soon))
			out.locked = true
			return out
		end
	end
	if c < 0 then
		out.reason = "Unavailable"
		out.locked = true
		return out
	end
	-- Empires Front: the per-player caps (Rules.STRUCT_LIMITS / LEVEL_LIMITS)
	local sk = Defs.struct_kind_from_name(kind)
	if sk >= 0 then
		local R = Rules()
		local up = R.is_upgradable(sk) and self:struct_count(sk) > 0
		if not R.under_limit(sk, self:struct_count(sk), s:struct_level_sum(ctx:me(), sk), up) then
			out.reason = R.limit_text(kind)
			out.locked = true
			return out
		end
	end
	if (o.gold or 0) < c then
		out.reason = "Need " .. T().fmt_num(c - o.gold) .. " more gold"
		return out
	end
	out.ok = true
	return out
end

--- Structure kinds an own structure of the same kind upgrades instead of a new build (defense posts
--- are not upgradable).
-- (2026-11-06: the Watchtower and the Siege Workshop have no levels)
UIRules.UPGRADABLE = { "city", "port", "factory" }

--- (Empires Front 2026-11-06) A new player's build bar grows with the match: in their first matches
--- after the tutorial (Telemetry.matches_before: ROOKIE_PACE) only the first stage's buildings show,
--- the next ones join `at` seconds into their nation's life (x the pace), the bar telling them
--- (CommandBar.rookie_unlocked). The radial menu and the hotkeys follow. The tutorial's match (the
--- first) shows them all: the tutorial teaches them one by one.
UIRules.ROOKIE_STAGES = {
	{ at = 0, kinds = { "city", "farm", "mine", "defense", "port" } },
	{ at = 90, kinds = { "market", "factory", "temple", "wall" } },
	{ at = 180, kinds = { "barracks", "forge", "warship", "palace", "university", "sam", "silo" } },
}
--- matches before this one -> the share of the stages' waits it keeps (none listed: the whole bar)
UIRules.ROOKIE_PACE = { [1] = 1.0, [2] = 0.5 }

local rookie_stage: { [string]: number } = {}
for i, st in UIRules.ROOKIE_STAGES do
	for _, k in st.kinds do
		rookie_stage[k] = i
	end
end

--- Whether build kind `kind` waits yet in a new player's bar (see ROOKIE_STAGES).
function UIRules.rookie_hidden(self: any, kind: string): boolean
	local i = rookie_stage[kind]
	local tel = self.ctx.telemetry
	if i == nil or tel == nil then
		return false
	end
	local pace = UIRules.ROOKIE_PACE[tel:matches_before()]
	if pace == nil then
		return false
	end
	local at = UIRules.ROOKIE_STAGES[i].at * pace
	return at > 0 and self.ctx:alive_seconds() < at
end

--- Bulk menus (four fixed slots: x1, two steps, then the most the
--- player can do right now): structure upgrades x1 / x5 / x10 / xMax, atom bombs x1 / x2 / x5 / xMax
--- (xMax capped by gold, and for bombs by loaded silo missiles; Protocol.MAX_INTENT_AMOUNT 50). User
--- 2026-09-29: the build menu should offer to build several cities, factories or SAMs at once, stacked
--- on top of each other, when the player can afford them.
UIRules.STRUCTURE_BULK_STEPS = { 5, 10 }
UIRules.NUKE_BULK_STEPS = { 2, 5 }
UIRules.MAX_BULK = 50

--- Missiles loaded right now in the local player's finished silos (a silo holds one per level;
--- each launch reloads for SILO_COOLDOWN_TICKS).
function UIRules.ready_missiles(self: any): number
	local s = self.ctx.state
	if s == nil then
		return 0
	end
	local me = self.ctx:me()
	local cd = Rules().SILO_COOLDOWN_TICKS
	local n = 0
	for _, st in s.structures do
		if st.owner == me and st.kind == Defs.S_SILO and st.active_tick <= s.tick then
			local busy = 0
			for _, t in st.shots or {} do
				if t + cd > s.tick then
					busy += 1
				end
			end
			n += math.max(0, (st.level or 1) - busy)
		end
	end
	return n
end

--- Total gold for `amount` more of `kind` in a row (upgrades: each level at the next price).
function UIRules.bulk_cost(self: any, kind: string, amount: number): number
	local R = Rules()
	if UIRules.is_nuke(kind) then
		return R.nuke_cost(kind, if self.ctx.state then self.ctx.state.mirvs_launched else 0) * amount
	end
	local count = if self.ctx.state then R.cost_count_of(self.ctx.state, self.ctx:me(), kind) else 0
	local total = 0
	for i = 0, amount - 1 do
		total += R.build_cost(kind, count + i)
	end
	return total
end

--- The most of `kind` the local player can buy in a row now (gold; bombs: loaded missiles too).
function UIRules.bulk_max(self: any, kind: string): number
	local o = self.ctx:my()
	local gold = if o ~= nil then (tonumber(o.gold) or 0) else 0
	local cap = UIRules.MAX_BULK
	if UIRules.is_nuke(kind) then
		cap = math.min(cap, self:ready_missiles())
	end
	-- (the per-player level caps: Rules.LEVEL_LIMITS)
	local sk = Defs.struct_kind_from_name(kind)
	local lv = if sk >= 0 then Rules().level_limit(sk) else nil
	local st = self.ctx.state
	if lv ~= nil and st ~= nil then
		cap = math.min(cap, math.max(0, lv - st:struct_level_sum(self.ctx:me(), sk)))
	end
	local max = 0
	for n = 1, cap do
		if self:bulk_cost(kind, n) > gold then
			break
		end
		max = n
	end
	return max
end

--- The amount ring for `kind` (id prefix "build" / "nuke") when more than one is possible, else nil.
function UIRules.bulk_ring(self: any, prefix: string, kind: string): { any }?
	local max = self:bulk_max(kind)
	if max <= 1 then
		return nil
	end
	local steps = if UIRules.is_nuke(kind) then UIRules.NUKE_BULK_STEPS else UIRules.STRUCTURE_BULK_STEPS
	local slots = { 1, steps[1], steps[2], max }
	local ring = {}
	local nuke = UIRules.is_nuke(kind)
	local loaded = if nuke then self:ready_missiles() else math.huge
	for i, n in slots do
		local cost = self:bulk_cost(kind, n)
		local ok = n <= max
		local reason = ""
		if not ok then
			reason = if nuke and n > loaded
				then string.format("Only %d missile%s loaded", loaded, if loaded == 1 then "" else "s")
				else "Not enough gold"
		end
		table.insert(ring, {
			id = string.format("%s:%s:%d", prefix, kind, n),
			-- (the fourth slot is the most affordable: its amount says how many)
			label = string.format("×%d · %s", n, T().fmt_cost(cost)),
			icon = kind,
			ok = ok,
			reason = reason,
			danger = nuke,
			cost = cost,
		})
	end
	return ring
end

--- A Rules constant by name (so the UI works before and after the Sim exposes it).
function UIRules.rules_const(cname: string, fallback: any): any
	local v = Rules()[cname]
	if v == nil then
		return fallback
	end
	return v
end

--- Radius (our tiles) a build tap searches the player's own land for a valid site
--- (15 full-size tiles).
function UIRules.snap_radius(): number
	return tonumber(UIRules.rules_const("BUILD_SNAP_RADIUS", 15.0 / Rules().K_LIN)) :: number
end

--- (Empires Front 2026-11-05) What a `kind` built at `tile` gets there, before it is built: the land
--- under a Farm or a Mine, a Temple or the Palace in reach, the roads (a Factory in reach), what a
--- Temple or the Palace would reach. Returns rows { label, value, color } for the build card and a
--- short line for the phones' caption ("" when there is nothing to say).
UIRules.TERRAIN_WORD = { [2] = "plains", [3] = "hills", [4] = "mountains", [5] = "tundra", [6] = "ice" }
function UIRules.site_bonus(self: any, kind: string, tile: number): ({ { any } }, string)
	local ctx = self.ctx
	local s = ctx.state
	local me = ctx:me()
	if s == nil or s.map == nil or tile == nil or tile < 0 or me == 0 then
		return {}, ""
	end
	local R = Rules()
	local Th = T()
	local d2 = s.map.range_d2
	local terr = if s.map.terrain ~= nil then buffer.readu8(s.map.terrain, tile) else 2
	local function own_near(k: number, reach: (any) -> number): { any }
		local out = {}
		for _, st in s.structures do
			if st.owner == me and st.kind == k then
				local r = reach(st)
				if d2(st.tile, tile) <= r * r then
					table.insert(out, st)
				end
			end
		end
		return out
	end
	local function temple_r(st: any): number
		return R.temple_range(st.level or 1)
	end
	local function palace_r(_st: any): number
		return R.palace_range()
	end
	local function factory_near(): boolean
		local rmax = R.ROAD_MAX_TILES
		for _, st in s.structures do
			if st.kind == Defs.S_FACTORY and d2(st.tile, tile) <= rmax * rmax then
				return true
			end
		end
		return false
	end
	local function pct(x: number): string
		return string.format("+%s%%", if x >= 10 then tostring(math.floor(x + 0.5)) else string.format("%.1f", x))
	end
	local rows, short = {}, ""
	if kind == "farm" then
		local tm = R.FARM_TERRAIN[terr] or 1.0
		local blessed = #own_near(Defs.S_TEMPLE, temple_r) > 0
		local m = tm * (if blessed then R.FARM_BLESSED else 1.0)
		local v = R.FARM_CAP * m * 100
		table.insert(rows, { "Land", string.format("%s x%s", UIRules.TERRAIN_WORD[terr] or "land", tostring(tm)), if tm >= 1.2 then Th.GREEN else Th.TEXT })
		if blessed then
			table.insert(rows, { "Temple near", string.format("blessed x%s", tostring(R.FARM_BLESSED)), Th.GREEN })
		end
		table.insert(rows, { "Troop cap", pct(v), Th.GREEN })
		short = "Troop cap " .. pct(v) .. (if blessed then " (blessed)" else "")
	elseif kind == "university" then
		local m, why = 1.0, ""
		if #own_near(Defs.S_PALACE, palace_r) > 0 then
			m, why = R.UNI_NEAR_PALACE, "Palace near"
		elseif #own_near(Defs.S_TEMPLE, temple_r) > 0 then
			m, why = R.UNI_NEAR_TEMPLE, "Temple near"
		end
		if why ~= "" then
			table.insert(rows, { why, string.format("x%s", tostring(m)), Th.GREEN })
		end
		local v = R.UNI_INCOME * m * 100
		table.insert(rows, { "Gold income", pct(v), Th.GREEN })
		short = "Gold " .. pct(v) .. (if why ~= "" then " (" .. string.lower(why) .. ")" else "")
	elseif kind == "mine" then
		local m = if terr == Defs.T_MOUNTAIN then 1.5 else 1.0
		local road = factory_near()
		if terr == Defs.T_MOUNTAIN then
			table.insert(rows, { "Mountains", "x1.5 Ore", Th.GREEN })
		end
		if road then
			m *= 1.5
			table.insert(rows, { "On the roads", "x1.5 Ore", Th.GREEN })
		end
		local ore = 3.0 * m
		table.insert(rows, { "Ore", string.format("%s a second", if ore % 1 == 0 then tostring(ore) else string.format("%.1f", ore)), Th.GOLD })
		short = string.format("%s Ore/s", if ore % 1 == 0 then tostring(ore) else string.format("%.1f", ore))
	elseif kind == "market" then
		if factory_near() then
			table.insert(rows, { "On the roads", "sells +50%", Th.GREEN })
			short = "On the roads: sells +50%"
		else
			table.insert(rows, { "No Factory in reach", "build one for +50%", Th.TEXT_3 })
		end
	elseif kind == "temple" then
		local r = R.temple_range(1)
		local farms, unis = 0, 0
		for _, st in s.structures do
			if st.owner == me and d2(st.tile, tile) <= r * r then
				if st.kind == Defs.S_FARM then
					farms += 1
				elseif st.kind == Defs.S_UNIVERSITY then
					unis += 1
				end
			end
		end
		table.insert(rows, { "Farms blessed", tostring(farms), if farms > 0 then Th.GREEN else Th.TEXT_3 })
		if unis > 0 then
			table.insert(rows, { "Universities", string.format("%d study x%s", unis, tostring(R.UNI_NEAR_TEMPLE)), Th.GREEN })
		end
		short = string.format("Blesses %d Farm%s", farms, if farms == 1 then "" else "s")
	elseif kind == "palace" then
		local r = R.palace_range()
		local unis = 0
		for _, st in s.structures do
			if st.owner == me and st.kind == Defs.S_UNIVERSITY and d2(st.tile, tile) <= r * r then
				unis += 1
			end
		end
		table.insert(rows, { "No revolts within", string.format("%d tiles", math.floor(R.PALACE_RANGE_FULL)), Th.GREEN })
		if unis > 0 then
			table.insert(rows, { "Universities", string.format("%d study x%s", unis, tostring(R.UNI_NEAR_PALACE)), Th.GREEN })
		end
		short = "No revolts around it" .. (if unis > 0 then string.format(" · %d Universities x%s", unis, tostring(R.UNI_NEAR_PALACE)) else "")
	end
	return rows, short
end

--- (Empires Front 2026-11-05) Why `me` can't ally with `own` now (a team game: none; a free-for-all:
--- Rules.ALLY_MAX alliances each), or "".
function UIRules.ally_full_reason(s: any, me: number, own: number): string
	local R = Rules()
	if s:is_team_game() then
		return "Team game"
	end
	if R.ally_full(s:alliance_count(me)) then
		return string.format("You have %d allies (max)", R.ALLY_MAX)
	end
	if R.ally_full(s:alliance_count(own)) then
		return string.format("They have %d allies (max)", R.ALLY_MAX)
	end
	return ""
end

--- Friendly copy for Rules.placement reasons.
UIRules.PLACE_REASONS = {
	not_own = "Build on your own land",
	no_room = "No room here: structures need space",
	no_hills = "Mines must be dug in hills or mountains",
	no_heights = "A Fortress must stand on hills or mountains",
	no_coast = "Ports must be on your coast",
	no_port = "Warships need a finished port on this water",
	gold = "Not enough gold",
	limit = "Limit reached for this building",
	invalid = "Can't build here",
}

--- Where a build tap at `tile` really lands:
---   * near an own structure of the same upgradable kind -> upgrade it (tile = that structure);
---   * else the nearest valid site on the player's own land connected to the tap, within
---     snap_radius(), at least STRUCT_MIN_DIST from every structure of any owner (ports: coast).
--- Nukes and warships aim exactly. Returns {ok, tile, reason, warn, upgrade, sid, level}.
function UIRules.resolve_placement(self: any, kind: string, tile: number): { [string]: any }
	local ctx = self.ctx
	local out =
		{ ok = false, tile = tile, reason = "", warn = "", upgrade = false, sid = 0, level = 1 } :: { [string]: any }
	local s = ctx.state
	if s == nil or tile < 0 then
		out.reason = "Point at the globe"
		return out
	end
	if UIRules.is_nuke(kind) then
		local pl = self:_placement_exact(kind, tile)
		out.ok = pl.ok
		out.reason = pl.reason
		out.warn = pl.warn
		return out
	end
	-- The Sim's own algorithm (Rules.place_site via Rules.placement): snapped site or upgrade.
	local r = Rules().placement(s, ctx:me(), kind, tile)
	local code = tostring(r.reason or "")
	local rtile = tonumber(r.tile) or -1
	if kind == "warship" then
		-- the tap picks the patrol target on the sea; Rules returns the launching port.
		out.port = rtile
		out.ok = code == "" and s.map:is_water(tile)
		out.tile = tile
		out.code = code
		if code == "" and not s.map:is_water(tile) then
			out.reason = "Tap the sea where the warship should patrol"
		elseif code ~= "" then
			out.reason = if code == "limit"
				then Rules().limit_text(kind)
				else (UIRules.PLACE_REASONS[code] or "Can't build here")
		end
		return out
	end
	-- Gold is shown on the slot itself; the preview still shows where it would go.
	out.ok = code == "" or code == "gold"
	out.tile = if rtile >= 0 then rtile else tile
	out.reason = if code == "limit"
		then Rules().limit_text(r.limit_kind or kind)
		elseif code ~= "" then (UIRules.PLACE_REASONS[code] or "Can't build here")
		else ""
	out.code = code
	local sid = tonumber(r.upgrade_sid) or 0
	if sid > 0 and s.structures[sid] ~= nil then
		out.upgrade = true
		out.sid = sid
		out.level = s.structures[sid].level + 1
		-- (2026-11-05) a Defense Post on the hills rises into a Fortress (Rules.raise_post)
		out.into = r.into
		out.cost = tonumber(r.cost)
	end
	if code == "gold" then
		out.ok = false
	end
	return out
end

--- {ok, reason, warn, tile, upgrade, level} for placing `kind` at `tile` (availability is checked
--- separately). Structures snap / upgrade like the Sim (resolve_placement).
function UIRules.placement(self: any, kind: string, tile: number): { [string]: any }
	if UIRules.is_nuke(kind) then
		return self:_placement_exact(kind, tile)
	end
	return self:resolve_placement(kind, tile)
end

--- True when a finished structure of `skind` of the local player's that can fire now is within the
--- reach of munition `nkind` from `tile` (no reach limit: any such structure).
function UIRules.in_reach(self: any, skind: number, nkind: number, tile: number): boolean
	local s = self.ctx.state
	if s == nil then
		return false
	end
	local R = s.rules or Rules()
	local me = self.ctx:me()
	local reach = R.launch_range(nkind)
	local cd = R.RELOAD_TICKS[skind] or 0
	local range_d2 = s.map.range_d2
	for _, st in s.structures do
		if st.owner == me and st.kind == skind and st.active_tick <= s.tick then
			local busy = 0
			for _, t in st.shots or {} do
				if t + cd > s.tick then
					busy += 1
				end
			end
			if busy < (st.level or 1) and (reach <= 0 or range_d2(st.tile, tile) <= reach * reach) then
				return true
			end
		end
	end
	return false
end

function UIRules._placement_exact(self: any, kind: string, tile: number): { [string]: any }
	local ctx = self.ctx
	local out = { ok = false, reason = "", warn = "" } :: { [string]: any }
	local s = ctx.state
	if s == nil or tile < 0 then
		out.reason = "Point at the globe"
		return out
	end
	local map = s.map
	local own = s:tile_owner(tile)
	local me = ctx:me()
	if UIRules.is_nuke(kind) then
		if own == me and own ~= 0 then
			out.reason = "That is your own land"
			return out
		end
		if not map:is_land(tile) and kind ~= "mirv" then
			out.warn = "Open water: little to hit"
		end
		if own ~= 0 and s:are_allies(me, own) then
			out.warn = "Breaks your alliance with " .. s:owner_name(own)
		end
		if kind == "mirv" and own == 0 then
			out.reason = "Target a nation"
			return out
		end
		-- (Empires Front 2026-11-06) the siege weapons: within the workshop's reach; the plague on a
		-- nation; never a teammate
		if UIRules.launcher(kind) == Defs.S_SILO and not UIRules.is_strike(kind) then
			if kind == "plague" and own == 0 then
				out.reason = "Aim the plague at a nation"
				return out
			end
			if own ~= 0 and s:same_team(me, own) and s:is_team_game() then
				out.reason = "That is your teammate's land"
				return out
			end
			-- (2026-11-06) a new player is safe from them (Core/SimNukes)
			if own ~= 0 and s.is_rookie ~= nil and s:is_rookie(own) then
				out.reason = s:owner_name(own) .. " is new: safe from siege weapons"
				return out
			end
			if not self:in_reach(Defs.S_SILO, Defs.nuke_kind_from_name(kind), tile) then
				out.reason = "Out of your Siege Workshop's reach"
				return out
			end
		end
		if UIRules.is_strike(kind) then
			-- a strike never hits an ally, and an air strike needs a ready airfield within reach
			out.warn = ""
			if own ~= 0 and s:are_allies(me, own) then
				out.reason = "That is your ally's land"
				return out
			end
			if kind == "airstrike" and not self:in_reach(Defs.S_AIRFIELD, Defs.N_AIRSTRIKE, tile) then
				out.reason = "Out of your Airfields' reach"
				return out
			end
			if own == 0 then
				out.warn = "Nobody's land: nothing to hit"
			end
		end
		out.ok = true
		return out
	end
	if kind == "warship" then
		if map:is_water(tile) or own == me then
			out.ok = true
		else
			out.reason = "Target water near your ports"
		end
		return out
	end
	if own ~= me then
		out.reason = "Build on your own land"
		return out
	end
	if kind == "port" and not map:is_coastal(tile) then
		out.reason = "Ports must be on the coast"
		return out
	end
	-- Same test as the Sim: no structure closer than STRUCT_MIN_DIST (latitude-corrected circle).
	local md = Rules().STRUCT_MIN_DIST
	local min_d2 = md * md
	local range_d2 = Defs.range_d2
	for _, st in s.structures do
		if range_d2(tile, st.tile) < min_d2 then
			out.reason = "Too close to another structure"
			return out
		end
	end
	out.ok = true
	return out
end

-- ---------------------------------------------------------------------------------------------
-- Primary click
-- ---------------------------------------------------------------------------------------------

--- What a primary click on `tile` does:
--- Where a boat aimed at `tile` lands — the
--- nearest coastal tile of the same owner (unclaimed land for owner 0) that one of our coasts
--- reaches by sea, so clicking anywhere on a territory across the water works, not only its shore
--- pixel. Searches rings out to BOAT_SNAP_FULL full-size tiles; -1 when none.
UIRules.BOAT_SNAP_FULL = 120.0
function UIRules.boat_landing(self: any, tile: number): number
	local ctx = self.ctx
	local s = ctx.state
	if s == nil or tile < 0 then
		return -1
	end
	local map = s.map
	local borders = ctx.borders
	if map:is_coastal(tile) and borders:can_reach_by_sea(tile) then
		return tile
	end
	local own = s:tile_owner(tile)
	local W, H = map.W, map.H
	local k = tonumber(map.k_lin) or 1.0
	local rmax = math.ceil(UIRules.BOAT_SNAP_FULL / k)
	local cx, cy = tile % W, tile // W
	local best, best_d = -1, math.huge
	for r = 1, rmax do
		-- the ring at Chebyshev distance r
		for dy = -r, r do
			local y = cy + dy
			if y < 0 or y >= H then
				continue
			end
			local edge = dy == -r or dy == r
			local dx = -r
			while dx <= r do
				local x = cx + dx
				if x >= 0 and x < W then
					local t = y * W + x
					if map:is_coastal(t) and s:tile_owner(t) == own and borders:can_reach_by_sea(t) then
						local d = dx * dx + dy * dy
						if d < best_d then
							best, best_d = t, d
						end
					end
				end
				dx += if edge then 1 else 2 * r
			end
		end
		-- a hit on ring r: nothing farther than r * sqrt(2) can be closer
		if best >= 0 and r * r >= best_d / 2 then
			break
		end
	end
	return best
end

--- {type: spawn|expand|attack|boat|inspect|none, ok, reason, target, troops, verb, icon}
function UIRules.primary(self: any, tile: number): { [string]: any }
	local ctx = self.ctx
	local now = UICtx.msec()
	local t = if ctx.state ~= nil then ctx.state.tick else -1
	if
		tile == self._pc_tile
		and now - self._pc_msec < 400
		and t == self._pc_tick
		and math.abs(ctx.ratio - self._pc_ratio) < 1e-6
	then
		return table.clone(self._pc)
	end
	local res = self:_primary(tile)
	self._pc_tile = tile
	self._pc_msec = now
	self._pc_tick = t
	self._pc_ratio = ctx.ratio
	self._pc = res
	return table.clone(res)
end

--- Drops the primary() cache (tests / after the world changed under the same tick).
function UIRules.invalidate(self: any)
	self._pc_tile = -1
end

function UIRules._primary(self: any, tile: number): { [string]: any }
	local ctx = self.ctx
	local out =
		{ type = "none", ok = false, reason = "", target = 0, troops = 0.0, verb = "", icon = "info" } :: { [string]: any }
	local s = ctx.state
	if s == nil or tile < 0 or tile >= Defs.TILE_COUNT then
		return out
	end
	local map = s.map
	local me = ctx:me()
	local own = s:tile_owner(tile)
	out.target = own
	if me == 0 or not ctx:in_match() then
		out.type = "inspect"
		out.ok = own ~= 0
		return out
	end
	local o = ctx:my()
	if s.phase == Defs.PHASE_SPAWN or ctx:needs_spawn() then
		if o ~= nil and o.spawned and own == me then
			out.type = "inspect"
			out.ok = true
			return out
		end
		if map:is_contestable(tile) and own == 0 and not s:has_fallout(tile) then
			out.type = "spawn"
			out.ok = true
			out.verb = "Start here"
			out.icon = "target"
		else
			out.reason = if map:is_land(tile) then "Pick unclaimed land" else "Pick land, not water"
		end
		return out
	end
	if s.phase ~= Defs.PHASE_PLAYING or o == nil or not o.alive then
		out.type = "inspect"
		out.ok = own ~= 0
		return out
	end
	if own == me or (own ~= 0 and s:are_allies(me, own)) then
		out.type = "inspect"
		out.ok = true
		return out
	end
	if not map:is_contestable(tile) then
		out.reason = if ctx:terrain_at(tile) == Defs.T_ICECAP then "Antarctica cannot be claimed" else ""
		return out
	end
	-- Fallout stays until the land is conquered again; taking it is slow and costly.
	local fallout = own == 0 and s:has_fallout(tile)
	local share = ctx:order_ratio()
	local troops = (o.troops or 0) * share
	out.troops = troops
	if troops < 1.0 then
		-- (the floor under a new player's army: UICtx.troop_floor)
		out.floor = share < ctx.ratio
		out.reason = if out.floor then UICtx.data("Tutorial").FLOOR_REASON else "No troops available"
		return out
	end
	local land = false
	if s:borders_tile(me, tile) then
		land = true
	elseif own == 0 then
		local touch = ctx.borders:region_touches_me(tile)
		land = touch == 1 or (touch == -1 and ctx.borders:borders_owner(0))
	else
		land = ctx.borders:borders_owner(own)
	end
	if land then
		out.type = if own == 0 then "expand" else "attack"
		out.ok = true
		out.verb = if own == 0 then (if fallout then "Expand into fallout" else "Expand") else "Attack"
		out.icon = "attack"
		return out
	end
	-- Empires Front (2026-10-31): team games: march through a teammate's land (the Sim finds the way:
	-- SimAttacks passage_tile). Before a boat: a land route through friends is the natural one.
	-- (2026-11-06: also through an ally that signed Military Access, in any game)
	local via_mate = ctx.borders:mate_touches(tile)
	if via_mate == 1 then
		out.type = if own == 0 then "expand" else "attack"
		out.ok = true
		out.via_ally = true
		out.verb = if own == 0 then "Expand through ally" else "Attack through ally"
		out.icon = "attack"
		return out
	end
	local landing = self:boat_landing(tile)
	if landing >= 0 then
		out.boat_tile = landing
		local max_boats = Rules().MAX_BOATS_PLAYER
		if self:transports() >= max_boats then
			out.type = "boat"
			out.reason = string.format("All %d transports at sea", max_boats)
			out.icon = "boat"
			return out
		end
		out.type = "boat"
		out.ok = true
		out.verb = "Boat invasion"
		out.icon = "boat"
		return out
	end
	if via_mate == -1 then
		-- (a region too large to explore here: let the Sim look for a way through a teammate)
		out.type = if own == 0 then "expand" else "attack"
		out.ok = true
		out.via_ally = true
		out.verb = if own == 0 then "Expand through ally" else "Attack through ally"
		out.icon = "attack"
		return out
	end
	out.reason = if own == 0 then "Out of reach: expand toward it" else "No border or sea route"
	return out
end

function UIRules.primary_intent(self: any, tile: number, action: { [string]: any }): { [string]: any }
	local ty = tostring(action.type or "")
	if ty == "spawn" then
		return { type = "spawn", tile = tile }
	elseif ty == "expand" or ty == "attack" then
		return { type = "attack", tile = tile, ratio = self.ctx:order_ratio() }
	elseif ty == "boat" then
		return { type = "boat", tile = tonumber(action.boat_tile) or tile, ratio = self.ctx:order_ratio() }
	end
	return {}
end

--- Short sentence for the floating confirmation ("Attacking Brazil with 24.5K").
function UIRules.confirm_text(self: any, action: { [string]: any }): string
	local s = self.ctx.state
	local troops = T().fmt_troops(tonumber(action.troops) or 0.0)
	local target = tonumber(action.target) or 0
	local ty = tostring(action.type or "")
	if ty == "spawn" then
		return "Starting position set"
	elseif ty == "expand" then
		if action.via_ally then
			return "Marching through allied land with " .. troops
		end
		return "Expanding with " .. troops
	elseif ty == "attack" then
		if action.via_ally then
			return string.format("Marching through allied land to attack %s with %s", s:owner_name(target), troops)
		end
		return string.format("Attacking %s with %s", s:owner_name(target), troops)
	elseif ty == "boat" then
		if target == 0 then
			return "Boat launched with " .. troops
		end
		return string.format("Invading %s by sea with %s", s:owner_name(target), troops)
	end
	return ""
end

-- ---------------------------------------------------------------------------------------------
-- Radial menu
-- ---------------------------------------------------------------------------------------------

--- Items: {id, label, icon, ok, reason, danger, sub: {items}}
--- A donation to ally `own` at the current attack ratio, limited to the ally's troop headroom.
--- The Sim accepts any amount (rule unchanged), but troops above the cap evaporate on the next tick
--- (Rules.troop_growth snaps to the cap), so the UI never sends more than fits (review P1-5).
--- Returns { amount, want, room, cap, capped (amount < want), full (no useful room: < 1 % of cap) }.
function UIRules.donate_plan(self: any, own: number): { [string]: any }
	local ctx = self.ctx
	local want = Defs.trunc(ctx:troops_for_ratio())
	local s = ctx.state
	local o = if s ~= nil and own ~= 0 then s:get_owner(own) else nil
	local cap = if o ~= nil then (tonumber(o.max_troops) or 0) else 0
	local room = want
	if cap > 0 then
		room = math.max(0, math.floor(cap - (tonumber(o.troops) or 0)))
	end
	local amount = math.max(0, math.min(want, room))
	return {
		amount = amount,
		want = want,
		room = room,
		cap = cap,
		capped = amount < want,
		full = cap > 0 and room < math.max(1.0, cap * 0.01),
	}
end

--- True when the local player has a living human teammate or ally (who would see a Signal).
function UIRules.has_mates(self: any): boolean
	local ctx = self.ctx
	local s = ctx.state
	local me = ctx:me()
	if s == nil or me == 0 then
		return false
	end
	for id, o in s.owners do
		-- (Empires Front 2026-11-01: AI allies too: they answer a Signal, Sim.ping)
		if id ~= me and o.alive and o.kind ~= Defs.KIND_TRIBE and s:are_allies(me, id) then
			return true
		end
	end
	return false
end

function UIRules.radial_items(self: any, tile: number): { { [string]: any } }
	local ctx = self.ctx
	local items = {}
	local s = ctx.state
	if s == nil or tile < 0 then
		return items
	end
	local me = ctx:me()
	local own = s:tile_owner(tile)
	local playing = s.phase == Defs.PHASE_PLAYING and ctx:alive_player() and not ctx:needs_spawn()
	local land = s.map:is_contestable(tile)

	if playing and land and own ~= me and not s:are_allies(me, own) then
		local p = self:primary(tile)
		local is_boat = tostring(p.type) == "boat"
		local verb = if own == 0 then "Expand" else "Attack"
		local atk =
			{ id = "attack", label = verb, icon = "attack", ok = p.ok and not is_boat, reason = "", danger = false }
		if is_boat then
			atk.reason = "No land border: send a boat"
		elseif not p.ok then
			atk.reason = tostring(p.reason)
		end
		table.insert(items, atk)
		local boat = { id = "boat", label = "Boat", icon = "boat", ok = false, reason = "", danger = false }
		if self:boat_landing(tile) < 0 then
			boat.reason = if s.map:is_coastal(tile)
				then "None of your coasts reach it"
				else "No coast of theirs within reach"
		elseif self:transports() >= Rules().MAX_BOATS_PLAYER then
			boat.reason = "All transports are at sea"
		elseif ctx:troops_for_ratio() < 1.0 then
			boat.reason = "No troops available"
		else
			boat.ok = true
		end
		table.insert(items, boat)
	end

	if playing and own ~= me and me ~= 0 then
		for _, a in s.attacks do
			if a.attacker == me and a.target == own then
				table.insert(
					items,
					{ id = "retreat", label = "Retreat", icon = "retreat", ok = true, reason = "", danger = false }
				)
				break
			end
		end
	end

	if playing and own == me then
		local sub = {}
		-- (the Arsenal's structures the player has unlocked come after the others)
		local build_kinds = table.clone(UIRules.BUILD_KINDS)
		for _, k in UIRules.ARSENAL_BUILD do
			if not self:arsenal_locked(k) then
				table.insert(build_kinds, k)
			end
		end
		for _, k in build_kinds do
			-- (a new player's bar shows its buildings a few at a time: ROOKIE_STAGES)
			if self:rookie_hidden(k) then
				continue
			end
			local av = self:availability(k)
			local pl = self:placement(k, tile)
			local ok = av.ok and pl.ok
			local reason = if not av.ok then tostring(av.reason) else tostring(pl.reason)
			table.insert(sub, {
				id = "build:" .. k,
				label = UIRules.SHORT[k],
				icon = k,
				ok = ok,
				reason = reason,
				danger = false,
				cost = av.cost,
				-- an existing structure here: level it up several times at once (bulk upgrade)
				sub = if ok and pl.upgrade then self:bulk_ring("build", k) else nil,
			})
		end
		table.insert(
			items,
			{ id = "build", label = "Build", icon = "city", ok = true, reason = "", danger = false, sub = sub }
		)
	end

	-- what can be launched at the tile: the bombs with a silo, and the Arsenal's munitions the player
	-- has unlocked (a strike with its own structure)
	local launch_kinds = {}
	if playing and own ~= me and me ~= 0 then
		local kinds = table.clone(UIRules.NUKE_KINDS)
		for _, k in UIRules.ARSENAL_NUKES do
			if not self:arsenal_locked(k) then
				table.insert(kinds, k)
			end
		end
		for _, k in kinds do
			if self:struct_count(UIRules.launcher(k)) > 0 then
				table.insert(launch_kinds, k)
			end
		end
	end
	if #launch_kinds > 0 then
		local nsub = {}
		for _, k2 in launch_kinds do
			local av2 = self:availability(k2)
			local pl2 = self:placement(k2, tile)
			local ok2 = av2.ok and pl2.ok
			table.insert(nsub, {
				id = "nuke:" .. k2,
				label = UIRules.SHORT[k2],
				icon = k2,
				ok = ok2,
				reason = if not av2.ok then tostring(av2.reason) else tostring(pl2.reason),
				danger = true,
				cost = av2.cost,
				-- (Empires Front: one workshop, a shot a minute: no bulk launch)
				sub = nil,
			})
		end
		local only_strikes = self:struct_count(Defs.S_SILO) == 0
		table.insert(items, {
			id = "nuke",
			label = if only_strikes then "Strike" else "Nuke",
			icon = if only_strikes then launch_kinds[1] else "atom",
			ok = true,
			reason = "",
			danger = true,
			sub = nsub,
		})
	end

	if playing and own ~= 0 and own ~= me then
		local target_info = s:get_owner(own)
		-- Empires Front: our own rebels can be bought back (Core/SimRevolts.pay_rebels)
		local price = UIRules.rebel_price(s, me, own)
		if price >= 0 then
			local mo = s:get_owner(me)
			local gold = if mo ~= nil then tonumber(mo.gold) or 0 else 0
			table.insert(items, {
				id = "pay_rebels",
				label = "Buy Back",
				icon = "gold",
				ok = gold >= price,
				reason = if gold >= price then "" else "Need " .. T().fmt_cost(price) .. " gold",
				danger = false,
				cost = price,
			})
			table.insert(items, {
				id = "recognize_rebels",
				label = "Recognize",
				icon = "alliance",
				ok = true,
				reason = "",
				danger = false,
			})
		end
		if s:are_allies(me, own) then
			local plan = self:donate_plan(own)
			table.insert(items, {
				id = "donate",
				label = "Donate",
				icon = "donate",
				ok = plan.want >= 1 and not plan.full,
				reason = if plan.want < 1 then "No troops to spare" elseif plan.full then "At their troop cap" else "",
				danger = false,
				troops = plan.amount,
				capped = plan.capped,
			})
			-- Empires Front: pacts and resources between allies (SimDiplomacy, SimEconomy)
			if type(s.has_pact) == "function" then
				-- (2026-11-01: Military Access: march through their land and sail from their ports)
				for _, pk in { { 1, "trade", "Trade Pact" }, { 2, "defense", "Defence Pact" }, { 3, "access", "Military Access" } } do
					local kid, kname, label = pk[1], pk[2], pk[3]
					local picon = if kname == "access" then "alliance" else "pact_" .. kname
					if s:has_pact(me, own, kid) then
						table.insert(items, { id = "pact:" .. kname, label = label, icon = picon, ok = false, reason = "Signed", danger = false })
					elseif s:pact_requested(own, me, kid) then
						table.insert(items, { id = "pact_accept:" .. kname, label = "Accept " .. label, icon = picon, ok = true, reason = "", danger = false })
					elseif s:pact_requested(me, own, kid) then
						table.insert(items, { id = "pact:" .. kname, label = label, icon = picon, ok = false, reason = "Proposed", danger = false })
					else
						table.insert(items, { id = "pact:" .. kname, label = label, icon = picon, ok = true, reason = "", danger = false })
					end
				end
				local mo = s:get_owner(me)
				local ore = if mo ~= nil then tonumber(mo.ore) or 0 else 0
				if s:has_pact(me, own, 1) then
					table.insert(items, { id = "trade:sell", label = "Sell Ore", icon = "ore_sell", ok = ore >= 4, reason = if ore >= 4 then "" else "No Ore to sell", danger = false })
					table.insert(items, { id = "trade:buy", label = "Buy Ore", icon = "ore_buy", ok = true, reason = "", danger = false })
				else
					table.insert(items, { id = "send:ore", label = "Send Ore", icon = "ore", ok = ore >= 4, reason = if ore >= 4 then "" else "No Ore to spare", danger = false })
				end
			end
			-- the last ALLIANCE_EXTEND_WINDOW_TICKS: ask to renew (renewed once both asked)
			local ai = s:alliance_info(me, own)
			if ai ~= nil and ai.in_window then
				table.insert(items, {
					id = "ally_extend",
					label = "Renew",
					icon = "renew",
					ok = ai.can_extend,
					reason = if ai.me_asked then "Renewal asked" else "",
					danger = false,
				})
			end
			-- (a teammate is no alliance: nothing to betray)
			if s:has_alliance(me, own) then
				table.insert(
					items,
					{ id = "ally_break", label = "Betray", icon = "betray", ok = true, reason = "", danger = true }
				)
			end
		elseif s:has_request(own, me) then
			local full = UIRules.ally_full_reason(s, me, own)
			table.insert(
				items,
				{ id = "ally_accept", label = "Accept", icon = "alliance", ok = full == "", reason = full, danger = false }
			)
		elseif s:has_request(me, own) then
			table.insert(items, {
				id = "ally_request",
				label = "Ally",
				icon = "alliance",
				ok = false,
				reason = "Request pending",
				danger = false,
			})
		elseif target_info ~= nil and target_info.alive and not s:is_team_game() then
			-- (a team game has no alliances with other teams: no Ally button)
			-- a new request waits 30 s after the previous one (Rules.ALLY_REQUEST_COOLDOWN_TICKS)
			local wait = s:request_cooldown_left(me, own)
			local full = UIRules.ally_full_reason(s, me, own)
			table.insert(items, {
				id = "ally_request",
				label = "Ally",
				icon = "alliance",
				ok = wait <= 0 and full == "",
				reason = if full ~= "" then full elseif wait > 0 then string.format("Wait %ds", math.ceil(wait / Defs.TICK_RATE)) else "",
				danger = false,
			})
		end
	end

	-- Empires Front: markers for the team and allies (Sim.ping): what to hit, where help is needed
	if playing and me ~= 0 and self:has_mates() then
		table.insert(items, {
			id = "ping",
			label = "Signal",
			icon = "ping",
			ok = true,
			reason = "",
			danger = false,
			sub = {
				{ id = "ping:target", label = "Attack here", icon = "ping_target", ok = true, reason = "", danger = false },
				{ id = "ping:help", label = "Help here", icon = "ping_help", ok = true, reason = "", danger = false },
			},
		})
	end

	table.insert(items, { id = "focus", label = "Focus", icon = "eye", ok = true, reason = "", danger = false })
	if own ~= 0 then
		table.insert(items, { id = "info", label = "Info", icon = "info", ok = true, reason = "", danger = false })
	end
	return items
end

--- Empires Front: what buying rebels `rid` back costs `me` (the province's worth, Rules.province_value,
--- as the Sim last sent it: Ev.REBEL); -1 when `rid` are not `me`'s rising rebels.
function UIRules.rebel_price(s: any, me: number, rid: number): number
	local r = if s ~= nil then s:get_owner(rid) else nil
	if r == nil or me == 0 or r.rebel_of ~= me or r.rebel_state ~= 0 or not r.alive then
		return -1
	end
	return tonumber(r.rebel_price) or 0
end

return UIRules
