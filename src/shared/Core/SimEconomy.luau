--!native
-- Empires Front: the era economy and its trade (a mixin of the flattened Sim class, after SimArsenal).
--
--   Ore      Mines dig it (on hills and mountains only; more in the mountains). The Forge's tiers need it.
--   Market   sells the ore above what the next Forge level needs, at the match's ore price; each trade
--            pact the seller holds adds PACT_PRICE_BONUS to what it gets.
--   Price    one ore price for the whole match: it falls while much ore is sold (a glut) and recovers
--            when sales stop, and swings with a slow demand cycle. Selling early or holding pays.
--   Shipping a trade ship that reaches a port also carries ore: the sender sells some at a premium and
--            the port's owner gets that ore (an import). Between trade-pact partners ships pay more
--            (SimNaval._trade_arrive).
--   Deals    trade-pact partners buy and sell ore directly, at the match's price (trade_ore).
--
-- (2026-10-31: the food and farms of the first version are gone; o_food stays 0 and o_fed 1.)
-- Every number is per second, settled once a second (_resource_tick).
local Defs = require("./Defs")
local SimState = require("./SimState")

local readu8 = buffer.readu8
local filled = SimState.filled
local MAXO = Defs.MAX_OWNERS

local S_MINE = Defs.S_MINE
local S_MARKET = Defs.S_MARKET

local SimEconomy = {}

SimEconomy.MINE_ORE = 3.0
SimEconomy.MARKET_ORE = 12.0
SimEconomy.ORE_PRICE = 220.0
SimEconomy.PRICE_MIN = 0.7
SimEconomy.PRICE_MAX = 1.6
--- The glut (ore sold, decayed GLUT_DECAY a second) that cuts the price to 1.4 / 2 of its base is this many
--- times the number of nations (players and AI) in the match.
SimEconomy.GLUT_REF = 1000.0
SimEconomy.GLUT_DECAY = 0.985
--- The demand cycle: +-DEMAND_SWING over DEMAND_PERIOD_S.
SimEconomy.DEMAND_SWING = 0.18
SimEconomy.DEMAND_PERIOD_S = 240.0
SimEconomy.START_ORE = 0.0
--- A Market's price bonus per trade pact (at most MAX_PACT_BONUS).
SimEconomy.PACT_PRICE_BONUS = 0.2
SimEconomy.MAX_PACT_BONUS = 0.8
--- Ore a Forge level needs (the next level: FORGE_ORE x level).
SimEconomy.FORGE_ORE = 60
--- Shipping: ore a trade ship carries at most, and the premium it sells at.
SimEconomy.SHIP_ORE = 12.0
SimEconomy.SHIP_PREMIUM = 1.25
--- Deals between partners: the share of the seller's spare ore one deal moves.
SimEconomy.DEAL_SHARE = 0.25
--- Empires Front (2026-10-31): structures on the roads (stations: a Way Station in reach). A Mine on
--- the roads digs ROAD_MINE_BONUS more ore (the carts haul it); a Market on the roads sells
--- ROAD_MARKET_BONUS more ore a second.
SimEconomy.ROAD_MINE_BONUS = 0.5
SimEconomy.ROAD_MARKET_BONUS = 0.5

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
		self.o_food = filled(MAXO, 0)
		self.o_ore = filled(MAXO, E.START_ORE)
		--- (kept for the stats rows: always 0)
		self.o_food_rate = filled(MAXO, 0)
		--- ore dug a second, and the gold its trade (Markets, ships, deals) made last second
		self.o_ore_rate = filled(MAXO, 0)
		self.o_trade_gold = filled(MAXO, 0)
		self._trade_acc = filled(MAXO, 0)
		--- the troop growth the economy allows (1: all; no food any more)
		self.o_fed = filled(MAXO, 1.0)
		--- the match's ore market
		self.ore_glut = 0.0
		self.ore_price = E.ORE_PRICE
	end

	--- Food (always 0), the army's use (0) and ore a second of `id` (kept for the AI's callers).
	function C:resource_rates(id: number): (number, number, number)
		return 0.0, 0.0, (self._mine_ore and self._mine_ore[id] or 0)
	end

	--- Yield of a mine on tile `t`.
	function C:_yield(kind: number, t: number): number
		if kind == S_MINE then
			return if readu8(self.terr, t) == Defs.T_MOUNTAIN then 1.5 else 1.0
		end
		return 1.0
	end

	--- The ore `id` keeps back from sales: what its next Forge level needs.
	function C:ore_reserve(id: number): number
		return E.ore_cost(Defs.S_FORGE, self:struct_levels(id, Defs.S_FORGE))
	end

	--- What a pact-holder gets over the price (1 + bonus).
	function C:ore_bonus(id: number): number
		return 1.0 + math.min(E.MAX_PACT_BONUS, E.PACT_PRICE_BONUS * self:trade_pacts(id))
	end

	--- Gold `id` earned by trade (stats: o_trade_gold is the last second's).
	function C:_trade_gold(id: number, g: number)
		if g > 0 then
			self.o_gold[id] += g
			self.o_bonus_acc[id] += g
			self._trade_acc[id] += g
		end
	end

	--- Once a second: mining, the Markets' sales and the ore price.
	function C:_resource_tick()
		local mine = {} :: { [number]: number }
		local market = {} :: { [number]: number }
		for _, s in self.struct_list do
			if s.dead or not s.active then
				continue
			end
			local k = s.kind
			if k == S_MINE then
				local y = s.yield
				if y == nil then
					y = self:_yield(k, s.tile)
					s.yield = y
				end
				if s.station then
					y *= 1.0 + E.ROAD_MINE_BONUS
				end
				mine[s.owner] = (mine[s.owner] or 0) + s.level * E.MINE_ORE * y
			elseif k == S_MARKET then
				market[s.owner] = (market[s.owner] or 0)
					+ s.level * (if s.station then 1.0 + E.ROAD_MARKET_BONUS else 1.0)
			end
		end
		self._mine_ore = mine
		local price = self.ore_price
		local sold = 0.0
		local o_alive, o_spawned, o_kind = self.o_alive, self.o_spawned, self.o_kind
		local o_ore = self.o_ore
		local nations = 0
		for id = 1, self.owner_total do
			if o_alive[id] == 0 or o_spawned[id] == 0 or o_kind[id] == Defs.KIND_TRIBE then
				continue
			end
			nations += 1
			local ore = mine[id] or 0
			o_ore[id] += ore
			self.o_ore_rate[id] = ore
			local mk = market[id] or 0
			if mk > 0 then
				local spare = o_ore[id] - self:ore_reserve(id)
				local sell = math.clamp(spare, 0, mk * E.MARKET_ORE)
				if sell > 0 then
					o_ore[id] -= sell
					sold += sell
					self:_trade_gold(id, sell * price * self:ore_bonus(id))
				end
			end
			self.o_trade_gold[id] = self._trade_acc[id]
			self._trade_acc[id] = 0
		end
		-- the price: a glut of sales pushes it down, a slow demand cycle swings it
		self.ore_glut = self.ore_glut * E.GLUT_DECAY + sold
		local t = self.tick / 10.0
		local cycle = 1.0 + E.DEMAND_SWING * math.sin(2.0 * math.pi * t / E.DEMAND_PERIOD_S)
		local ref = E.GLUT_REF * math.max(nations, 1)
		local k = math.clamp(1.4 / (1.0 + self.ore_glut / ref) * cycle, E.PRICE_MIN, E.PRICE_MAX)
		self.ore_price = E.ORE_PRICE * k
	end

	--- Number of trade pacts `id` holds (Core/SimDiplomacy; 0 before it is installed).
	if C.trade_pacts == nil then
		function C:trade_pacts(_id: number): number
			return 0
		end
	end

	--- A trade ship of `from` reached `to`'s port: it carried ore. Returns the gold the sale made.
	function C:ship_ore(from: number, to: number): number
		local spare = self.o_ore[from] - self:ore_reserve(from)
		local n = math.clamp(spare, 0, E.SHIP_ORE)
		if n <= 0 then
			return 0
		end
		self.o_ore[from] -= n
		if to > 0 and to ~= from and self.o_kind[to] ~= Defs.KIND_TRIBE then
			self.o_ore[to] += n
		end
		local g = n * self.ore_price * E.SHIP_PREMIUM * self:ore_bonus(from)
		self:_trade_gold(from, g)
		return g
	end

	--- A deal between trade-pact partners: `id` sells ("sell") its spare ore to `target`, or buys ("buy")
	--- the target's spare ore, a quarter of it at a time, at the match's price (the buyer pays what it can).
	function C:trade_ore(id: number, target: number, how: string): boolean
		if target <= 0 or target > self.owner_total or self.o_alive[target] == 0 then
			return false
		end
		if not (self.has_pact and self:has_pact(id, target, 1)) then
			self:msg(id, Defs.MSG_INFO, "Ore deals need a trade pact")
			return false
		end
		local seller, buyer = id, target
		if how == "buy" then
			seller, buyer = target, id
		elseif how ~= "sell" then
			return false
		end
		local spare = self.o_ore[seller] - self:ore_reserve(seller)
		local n = math.floor(math.max(spare, 0) * E.DEAL_SHARE)
		local price = self.ore_price
		n = math.min(n, math.floor(math.max(self.o_gold[buyer], 0) / price))
		if n < 1 then
			self:msg(
				id,
				Defs.MSG_INFO,
				if how == "buy" then self.o_name[target] .. " has no Ore to spare (or you lack the gold)"
					else "No spare Ore to sell (or they lack the gold)"
			)
			return false
		end
		local g = n * price
		self.o_ore[seller] -= n
		self.o_ore[buyer] += n
		self.o_gold[buyer] -= g
		self:_trade_gold(seller, g)
		local text = string.format("%s sold %d Ore to %s for %d gold", self.o_name[seller], n, self.o_name[buyer], math.floor(g))
		self:msg(seller, Defs.MSG_GOOD, text)
		self:msg(buyer, Defs.MSG_GOOD, text)
		return true
	end

	--- `id` sends `amount` of `what` ("ore" | "gold") to its ally `target`.
	function C:send_resource(id: number, target: number, what: string, amount: number): boolean
		if target <= 0 or target > self.owner_total or not self:allied(id, target) or self.o_alive[target] == 0 then
			return false
		end
		local pool = if what == "ore" then self.o_ore elseif what == "gold" then self.o_gold else nil
		if pool == nil then
			return false
		end
		local a = math.floor(math.clamp(amount, 0, math.max(pool[id], 0)))
		if a < 1 then
			return false
		end
		pool[id] -= a
		pool[target] += a
		self:msg(target, Defs.MSG_GOOD, string.format("%s sent you %d %s", self.o_name[id], a, if what == "ore" then "Ore" else "gold"))
		return true
	end
end

return SimEconomy
