--!native
-- Empires Front: the era economy (a mixin of the flattened Sim class, after SimArsenal).
--
--   Food   every troop eats (FOOD_PER_TROOP a second). The land feeds most of a full army
--          (BASE_FOOD_SHARE of the troop cap); Farms feed the rest, more on plains than on hills, less
--          on arid land. With the granaries empty the army stops growing in proportion to the
--          shortfall, and a deep famine makes troops desert.
--   Ore    Mines (on hills and mountains, more in the mountains) dig it. Markets sell it for gold, and
--          the surplus food above a reserve; the Forge's tiers need it; allies can be sent it.
--   Trade  each trade pact (Sim.pact_*: Core/SimDiplomacy) raises what a Market gets for its goods.
--
-- Tribes (bots of the land grab) neither eat nor dig. Every number is per second, settled once a second
-- (_resource_tick) from the finished structures.
local Defs = require("./Defs")
local SimState = require("./SimState")

local readu8 = buffer.readu8
local filled = SimState.filled
local MAXO = Defs.MAX_OWNERS

local S_FARM = Defs.S_FARM
local S_MINE = Defs.S_MINE
local S_MARKET = Defs.S_MARKET

local SimEconomy = {}

SimEconomy.FOOD_PER_TROOP = 0.0005
SimEconomy.BASE_FOOD_SHARE = 0.8
SimEconomy.FARM_FOOD = 45.0
SimEconomy.MINE_ORE = 3.0
SimEconomy.MARKET_ORE = 8.0
SimEconomy.MARKET_FOOD = 30.0
SimEconomy.ORE_PRICE = 220.0
SimEconomy.FOOD_PRICE = 18.0
--- Food kept back from the Market: this many seconds of the army's needs.
SimEconomy.FOOD_RESERVE_S = 90.0
SimEconomy.START_FOOD = 3000.0
SimEconomy.START_ORE = 0.0
--- Share of the troops that desert a second in a deep famine (empty granaries, fed below DESERT_BELOW).
SimEconomy.DESERT_RATE = 0.004
SimEconomy.DESERT_BELOW = 0.6
--- A Market's price bonus per trade pact (at most MAX_PACT_BONUS).
SimEconomy.PACT_PRICE_BONUS = 0.25
SimEconomy.MAX_PACT_BONUS = 1.0
--- Ore a Forge level needs (the next level: FORGE_ORE x level).
SimEconomy.FORGE_ORE = 60

local E = SimEconomy

--- Ore needed for the next level of a `kind` structure when `levels` levels are already owned.
function SimEconomy.ore_cost(kind: number, levels: number): number
	if kind == Defs.S_FORGE then
		return E.FORGE_ORE * (math.max(levels, 0) + 1)
	end
	return 0
end

function SimEconomy.install(C)
	function C:_init_economy()
		self.o_food = filled(MAXO, E.START_FOOD)
		self.o_ore = filled(MAXO, E.START_ORE)
		--- net food a second (production - use), ore dug a second, gold the Markets made last second
		self.o_food_rate = filled(MAXO, 0)
		self.o_ore_rate = filled(MAXO, 0)
		--- the share of the troop growth the food allows (1 = all)
		self.o_fed = filled(MAXO, 1.0)
		self._famine_warned = {} :: { [number]: number }
	end

	--- Food per second the land and the farms of `id` give, its army eats, and its ore per second.
	function C:resource_rates(id: number): (number, number, number)
		local prod, ore = 0.0, 0.0
		local cap = self.o_cap[id] or 0
		prod = cap * E.FOOD_PER_TROOP * E.BASE_FOOD_SHARE
		local f = self._farm_food and self._farm_food[id] or 0
		local m = self._mine_ore and self._mine_ore[id] or 0
		return prod + f, math.max(self.o_troops[id], 0) * E.FOOD_PER_TROOP, ore + m
	end

	--- Yield of a farm / mine on tile `t` (terrain and the arid bit of the tile byte).
	function C:_yield(kind: number, t: number): number
		local terr = readu8(self.terr, t)
		local b = readu8(self.map.tile_bytes, t)
		local arid = b >= 128 and bit32.band(b, 0x20) ~= 0
		if kind == S_FARM then
			local y = if terr == Defs.T_PLAINS then 1.0 elseif terr == Defs.T_HIGHLAND then 0.6 else 0.3
			return if arid then y * 0.5 else y
		elseif kind == S_MINE then
			return if terr == Defs.T_MOUNTAIN then 1.5 else 1.0
		end
		return 1.0
	end

	--- Once a second: production, consumption, the Markets' sales and famine.
	function C:_resource_tick()
		local farm = {} :: { [number]: number }
		local mine = {} :: { [number]: number }
		local market = {} :: { [number]: number }
		for _, s in self.struct_list do
			if s.dead or not s.active then
				continue
			end
			local k = s.kind
			if k == S_FARM then
				local y = s.yield
				if y == nil then
					y = self:_yield(k, s.tile)
					s.yield = y
				end
				farm[s.owner] = (farm[s.owner] or 0) + s.level * E.FARM_FOOD * y
			elseif k == S_MINE then
				local y = s.yield
				if y == nil then
					y = self:_yield(k, s.tile)
					s.yield = y
				end
				mine[s.owner] = (mine[s.owner] or 0) + s.level * E.MINE_ORE * y
			elseif k == S_MARKET then
				market[s.owner] = (market[s.owner] or 0) + s.level
			end
		end
		self._farm_food = farm
		self._mine_ore = mine
		local o_alive, o_spawned, o_kind = self.o_alive, self.o_spawned, self.o_kind
		local o_food, o_ore, o_troops = self.o_food, self.o_ore, self.o_troops
		for id = 1, self.owner_total do
			if o_alive[id] == 0 or o_spawned[id] == 0 then
				continue
			end
			if o_kind[id] == Defs.KIND_TRIBE then
				self.o_fed[id] = 1.0
				continue
			end
			local prod, use, ore = self:resource_rates(id)
			local food = o_food[id] + prod - use
			local ore_now = o_ore[id] + ore
			-- the Markets sell ore, and the food above the reserve
			local mk = market[id] or 0
			local sold_gold = 0.0
			if mk > 0 then
				local bonus = math.min(E.MAX_PACT_BONUS, E.PACT_PRICE_BONUS * self:trade_pacts(id))
				local sell_ore = math.min(ore_now, mk * E.MARKET_ORE)
				ore_now -= sell_ore
				local reserve = use * E.FOOD_RESERVE_S
				local sell_food = math.clamp(food - reserve, 0, mk * E.MARKET_FOOD)
				food -= sell_food
				sold_gold = (sell_ore * E.ORE_PRICE + sell_food * E.FOOD_PRICE) * (1.0 + bonus)
				if sold_gold > 0 then
					self.o_gold[id] += sold_gold
					self.o_bonus_acc[id] += sold_gold
				end
			end
			local store = math.max(5000.0, prod * 300.0)
			local fed = 1.0
			if food <= 0 then
				food = 0
				fed = if use > 0 then math.clamp(prod / use, 0, 1) else 1.0
			end
			food = math.min(food, store)
			self.o_food_rate[id] = food - o_food[id]
			self.o_ore_rate[id] = ore
			o_food[id] = food
			o_ore[id] = ore_now
			self.o_fed[id] = fed
			if fed < E.DESERT_BELOW then
				o_troops[id] -= o_troops[id] * E.DESERT_RATE * (1.0 - fed / E.DESERT_BELOW)
			end
			if fed < 1.0 and o_kind[id] == Defs.KIND_HUMAN then
				local last = self._famine_warned[id] or -100000
				if self.tick - last >= 600 then
					self._famine_warned[id] = self.tick
					self:msg(
						id,
						Defs.MSG_BAD,
						"Your granaries are empty: your army stops growing and deserts. Build Farms!"
					)
				end
			end
		end
	end

	--- Number of trade pacts `id` holds (Core/SimDiplomacy; 0 before it is installed).
	if C.trade_pacts == nil then
		function C:trade_pacts(_id: number): number
			return 0
		end
	end

	--- `id` sends `amount` of `what` ("food" | "ore" | "gold") to its ally `target`.
	function C:send_resource(id: number, target: number, what: string, amount: number): boolean
		if target <= 0 or target > self.owner_total or not self:allied(id, target) or self.o_alive[target] == 0 then
			return false
		end
		local pool = if what == "food" then self.o_food elseif what == "ore" then self.o_ore elseif what == "gold" then self.o_gold else nil
		if pool == nil then
			return false
		end
		local a = math.floor(math.clamp(amount, 0, math.max(pool[id], 0)))
		if a < 1 then
			return false
		end
		pool[id] -= a
		pool[target] += a
		local word = if what == "food" then "Food" elseif what == "ore" then "Ore" else "gold"
		self:msg(target, Defs.MSG_GOOD, string.format("%s sent you %d %s", self.o_name[id], a, word))
		return true
	end
end

return SimEconomy
