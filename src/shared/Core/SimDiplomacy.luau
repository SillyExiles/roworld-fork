--!native
-- Empires Front: pacts between allies (a mixin of the flattened Sim class, after SimEconomy). An alliance
-- stops two nations fighting; on top of it two allies may sign
--
--   a trade pact    each partner's passive income + TRADE_INCOME_BONUS, and its Markets sell dearer
--                   (SimEconomy.PACT_PRICE_BONUS a pact);
--   a defence pact  whoever attacks one partner earns the other's grudge (an AI partner goes to war),
--                   and the partner hears of it at once.
--
-- One side proposes (pact_request), the other accepts (pact_reply; an AI ally answers by itself). A pact
-- ends with the alliance (SimState.end_alliance: betrayal, expiry). Events: Ev.PACT a, b, kind, state
-- (0 proposed by a to b, 1 signed, 2 ended, 3 proposal withdrawn / declined).
local Defs = require("./Defs")
local Ev = require("./Ev")
local Rules = require("./Rules")

local SimDiplomacy = {}

--- (2026-11-01) Military Access ("access"): asked for and granted between allies; the asker's troops may
--- march through the granter's land to attack (SimAttacks.passage_tile) and its transports may sail from
--- the granter's ports (SimNaval._partner_port). A pact holds both ways once signed.
SimDiplomacy.KINDS = { trade = 1, defense = 2, access = 3 }
SimDiplomacy.NAMES = { [1] = "trade pact", [2] = "defence pact", [3] = "Military Access pact" }
SimDiplomacy.TRADE_INCOME_BONUS = 0.06
--- Proposals lapse after this many ticks.
SimDiplomacy.REQUEST_TICKS = 300

local function key(a: number, b: number): number
	return math.min(a, b) * 1024 + math.max(a, b)
end

function SimDiplomacy.install(C)
	function C:_init_diplomacy()
		--- key(a, b) -> { [kind] = true }
		self.pacts = {} :: { [number]: { [number]: boolean } }
		--- (from * 1024 + to) * 4 + kind -> tick proposed
		self.pact_req = {} :: { [number]: number }
	end

	function C:has_pact(a: number, b: number, kind: number): boolean
		local p = self.pacts[key(a, b)]
		return p ~= nil and p[kind] == true
	end

	--- Trade pacts `id` holds.
	function C:trade_pacts(id: number): number
		local n = 0
		for k, p in self.pacts do
			if p[1] and (k // 1024 == id or k % 1024 == id) then
				n += 1
			end
		end
		return n
	end

	--- Partners of `id` in a pact of `kind`.
	function C:pact_partners(id: number, kind: number): { number }
		local out = {}
		for k, p in self.pacts do
			if p[kind] then
				local a, b = k // 1024, k % 1024
				if a == id then
					table.insert(out, b)
				elseif b == id then
					table.insert(out, a)
				end
			end
		end
		return out
	end

	function C:_sign_pact(a: number, b: number, kind: number)
		local k = key(a, b)
		local p = self.pacts[k] or {}
		p[kind] = true
		self.pacts[k] = p
		self.pact_req[(a * 1024 + b) * 4 + kind] = nil
		self.pact_req[(b * 1024 + a) * 4 + kind] = nil
		self:ev({ Ev.PACT, a, b, kind, 1 })
		local what = SimDiplomacy.NAMES[kind]
		self:msg(a, Defs.MSG_GOOD, string.format("You signed a %s with %s", what, self.o_name[b]))
		self:msg(b, Defs.MSG_GOOD, string.format("You signed a %s with %s", what, self.o_name[a]))
	end

	--- `id` proposes a pact of `kind_name` ("trade" | "defense") to its ally `target`.
	function C:pact_request(id: number, target: number, kind_name: string): boolean
		local kind = SimDiplomacy.KINDS[kind_name]
		if kind == nil or target <= 0 or target > self.owner_total or target == id then
			return false
		end
		if not self:allied(id, target) or self.o_alive[target] == 0 then
			self:msg(id, Defs.MSG_INFO, "Pacts are signed between allies: ally first")
			return false
		end
		if self:has_pact(id, target, kind) then
			return false
		end
		-- they proposed the same: signed
		if self.pact_req[(target * 1024 + id) * 4 + kind] ~= nil then
			self:_sign_pact(target, id, kind)
			return true
		end
		if self.o_ai[target] == 1 then
			-- an AI ally signs a trade pact, and a defence pact unless it is far stronger than the asker
			-- (Military Access: unless the asker's army is over twice its own, a march through is a risk)
			local ok = kind == 1
				or (kind == 2 and self.o_troops[target] < self.o_troops[id] * 3.0)
				or (kind == 3 and self.o_troops[id] < self.o_troops[target] * 2.0)
			if ok then
				self:_sign_pact(id, target, kind)
			else
				self:msg(id, Defs.MSG_INFO, self.o_name[target] .. " declined your " .. SimDiplomacy.NAMES[kind])
			end
			return ok
		end
		self.pact_req[(id * 1024 + target) * 4 + kind] = self.tick
		self:ev({ Ev.PACT, id, target, kind, 0 })
		self:msg(
			target,
			Defs.MSG_ALLIANCE,
			string.format("%s proposes a %s: open their menu to accept", self.o_name[id], SimDiplomacy.NAMES[kind])
		)
		return true
	end

	--- `id` answers `target`'s proposal of `kind_name`.
	function C:pact_reply(id: number, target: number, kind_name: string, accept: boolean): boolean
		local kind = SimDiplomacy.KINDS[kind_name]
		if kind == nil or target <= 0 or target > self.owner_total then
			return false
		end
		local rk = (target * 1024 + id) * 4 + kind
		if self.pact_req[rk] == nil then
			return false
		end
		if accept and self:allied(id, target) then
			self:_sign_pact(target, id, kind)
		else
			self.pact_req[rk] = nil
			self:ev({ Ev.PACT, target, id, kind, 3 })
			self:msg(target, Defs.MSG_INFO, self.o_name[id] .. " declined your " .. SimDiplomacy.NAMES[kind])
		end
		return true
	end

	--- Every pact between `a` and `b` ends (their alliance ended).
	function C:_end_pacts(a: number, b: number)
		local k = key(a, b)
		local p = self.pacts[k]
		if p ~= nil then
			self.pacts[k] = nil
			for kind in p do
				self:ev({ Ev.PACT, a, b, kind, 2 })
			end
		end
	end

	--- Lapsed proposals (once a second).
	function C:_pacts_tick()
		local now = self.tick
		local stale = nil
		for rk, t in self.pact_req do
			if now - t >= SimDiplomacy.REQUEST_TICKS then
				stale = stale or {}
				table.insert(stale, rk)
			end
		end
		if stale ~= nil then
			for _, rk in stale do
				self.pact_req[rk] = nil
				local kind = rk % 4
				local pair = rk // 4
				self:ev({ Ev.PACT, pair // 1024, pair % 1024, kind, 3 })
			end
		end
	end

	-- two AI nations that ally also trade (a human proposes pacts from the ally's menu)
	local form_alliance = C.form_alliance
	function C.form_alliance(self: any, a: number, b: number)
		form_alliance(self, a, b)
		if self.o_ai[a] == 1 and self.o_ai[b] == 1 and self:allied(a, b) and not self:has_pact(a, b, 1) then
			local k = key(a, b)
			local p = self.pacts[k] or {}
			p[1] = true
			self.pacts[k] = p
			self:ev({ Ev.PACT, a, b, 1, 1 })
		end
	end

	-- a pact ends with its alliance
	local end_alliance = C.end_alliance
	function C.end_alliance(self: any, a: number, b: number, traitor: number, expired: boolean?)
		local had = self.alliances[math.min(a, b) * 1024 + math.max(a, b)] ~= nil
		end_alliance(self, a, b, traitor, expired)
		if had then
			self:_end_pacts(a, b)
		end
	end

	-- a defence pact: the attacked partner's allies take it personally
	local on_started = C._on_attack_started
	function C._on_attack_started(self: any, at: any)
		on_started(self, at)
		local tg = at.target
		local by = at.attacker
		if tg == nil or tg <= 0 or by == nil or by <= 0 then
			return
		end
		for _, p in self:pact_partners(tg, 2) do
			if p ~= by and self.o_alive[p] == 1 and not self:allied(p, by) then
				self:add_grudge(p, by, Rules.HOSTILE_TICKS * 2)
				if self.o_kind[p] == Defs.KIND_HUMAN then
					self:msg(
						p,
						Defs.MSG_ALERT,
						string.format("%s attacks your pact partner %s!", self.o_name[by], self.o_name[tg])
					)
				end
			end
		end
	end
end

return SimDiplomacy
