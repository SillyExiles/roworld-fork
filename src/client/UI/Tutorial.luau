--!nonstrict
-- A new player's first match, step by step (Data/Tutorial: the steps and why; 2026-10-04: a new
-- tutorial for new players, made for phones first). One small goal at a time:
--   * a card at the top of the screen: "2 / 6", one short line, a bar for a goal with progress, and
--     Skip. Short enough to read at a glance on a phone; it never covers the map's middle or the
--     command bar;
--   * a tap mark where to tap (two rings closing on a dot, with "Tap here" under it): the map spot or
--     the control the step is about. It hides while the player is busy and comes back after
--     Data/Tutorial.NUDGE_S without an order;
--   * a finished step turns the card green for a moment, with a sound, then the next one comes.
-- The spawn step has no card (the spawn banner is up there): only the mark on a roomy spot, which
-- is taken for the player after AUTO_SPAWN_S. The City step tops the player's gold up to a City's
-- price. A step nobody finishes in STEP_MAX_S is passed over. While it runs the coach's tips are
-- off (UIRoot); they take over afterwards. While it runs the Attack bar starts at its default and
-- stops at Data.RATIO_CAP, and an order leaves Data.TROOP_FLOOR of the army's cap at home (UICtx
-- .ratio_max / .troop_floor): a new player can't empty their nation.
--
--   Tutorial.new(ctx, ui)
--   :begin()                 the tutorial match was asked for
--   :stop(how)               "done" | "skipped" | "left"
--   .active, .finished (Signal: how), .step_done (Signal: funnel step, name), .closed (Signal: the
--   last card is gone)
local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local Signal = UITheme.core("Signal")
local Defs = UICtx.core("Defs")
local Data = UICtx.data("Tutorial")

local Tutorial = W.class(W.Control)

--- The card stays green this long after a step, and the last card this long.
Tutorial.DONE_S = 0.9
--- Skip does nothing this long after a step moves on (a GOT IT tapped late isn't a Skip).
Tutorial.GUARD_S = 1.5
Tutorial.END_S = 9.0
--- Spawn spots tried for the roomiest one.
Tutorial.SPAWN_TRIES = 240
--- Free land this far (tiles) from every nation is roomy enough.
Tutorial.SPAWN_ROOM = 35.0
--- The camera shows the suggested spot with tiles this many px across.
Tutorial.SPAWN_PX = 5.0

function Tutorial.new(c: any, ui: any)
	local self = setmetatable({}, Tutorial.__mt)
	W.Control._init(self)
	self.ctx = c
	self.ui = ui
	self.active = false
	self.finished = Signal.new()
	self.step_done = Signal.new()
	--- the last card (the reward) is gone: the screen is the coach's again
	self.closed = Signal.new()
	self._i = 0
	self._t = 0.0
	self._step_t = 0.0
	self._flash = 0.0
	self._ending = 0.0
	self._sent = 0
	self._idle = 0.0
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	-- the tap mark
	self._mark = UICtx.canvas(self.gui, "TutorialMark")
	self._mark.ZIndex = 1
	self._ring_a = UICtx.ring(self._mark, Vector2.zero, 10, 3, UITheme.AMBER, 1)
	self._ring_b = UICtx.ring(self._mark, Vector2.zero, 10, 2, UITheme.AMBER, 1)
	self._dot = UICtx.circle(self._mark, Vector2.zero, 6, UITheme.AMBER, 0)
	self._tap = UICtx.make("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(14, 20, 38),
		BackgroundTransparency = 0.15,
		Text = "Tap here",
		FontFace = Font.fromId(12187365977, Enum.FontWeight.Bold),
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		AutomaticSize = Enum.AutomaticSize.XY,
		AnchorPoint = Vector2.new(0.5, 0),
	}, self._mark)
	UICtx.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, self._tap)
	UICtx.make("UIPadding", {
		PaddingLeft = UDim.new(0, 9),
		PaddingRight = UDim.new(0, 9),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
	}, self._tap)
	self._mark.Visible = false
	-- the card
	local card = GlassPanel.new(12.0, 8.0, UITheme.R_MD, true, 18)
	card:set_accent(UITheme.AMBER)
	card:set_border(UITheme.c(UITheme.AMBER, 0.5))
	self._card = card
	local h = UITheme.hbox(10)
	card:add_child(h)
	self._count = UITheme.label("1 / 6", 12, 800, UITheme.AMBER)
	self._count.size_flags_vertical = W.SHRINK_CENTER
	h:add_child(self._count)
	local v = UITheme.vbox(5)
	v.size_flags_horizontal = W.EXPAND_FILL
	v.size_flags_vertical = W.SHRINK_CENTER
	self._text = UITheme.label("", 14, 700, UITheme.TEXT)
	self._text:set_autowrap(true)
	self._text:set_min_size(Vector2.new(220, 0))
	v:add_child(self._text)
	-- (a goal with progress: a thin bar under the line)
	local bar = UICtx.make("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 5),
	})
	UICtx.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, bar)
	self._fill = UICtx.make("Frame", {
		BackgroundColor3 = UITheme.AMBER,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, bar)
	UICtx.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, self._fill)
	self._bar = W.wrap(bar)
	self._bar:set_min_size(Vector2.new(0, 5))
	self._bar:set_mouse_filter(W.MOUSE_IGNORE)
	v:add_child(self._bar)
	h:add_child(v)
	self._skip = UITheme.button("Skip", "GhostButton", "", 36.0)
	self._skip:set_font_size(12)
	self._skip:set_min_size(Vector2.new(52, 36))
	self._skip.size_flags_vertical = W.SHRINK_CENTER
	self._skip.pressed:Connect(function()
		if self._ending > 0.0 then
			self:_close()
		elseif self.active and (self._flash > 0.0 or os.clock() < (self._guard or 0.0)) then
			-- (2026-11-01: a GOT IT tapped just as its card moved on, or on the green card, would
			-- have been the next step's Skip and ended the whole tutorial)
			return
		elseif self.active and (Data.STEPS[self._i] or {}).info then
			-- (a step to read: GOT IT moves on)
			self:_advance()
		else
			self:stop("skipped")
		end
	end)
	h:add_child(self._skip)
	self:add_child(card)
	card:set_visible(false)
	self:set_process(true)
	return self
end

--- The tutorial match was asked for: the steps begin with its spawn phase.
function Tutorial.begin(self)
	self.active = true
	self._i = 1
	self._step_t = 0.0
	self._flash = 0.0
	self._ending = 0.0
	self._idle = 0.0
	self._spot = nil
	self._spot_state = nil
	self._picked = false
	self._base = nil
	self._neighbour = nil
	self._gold_given = {}
	self._sent = #self.ctx.sent_log
	self._card:set_visible(false)
	self._started = false
	-- the Attack bar: from its default, never past the cap; the floor under the army comes from the
	-- FLOOR_FROM step, once it arms (Data.floor_armed; _process)
	local ctx = self.ctx
	ctx.ratio_max = 1.0
	ctx:set_ratio(UICtx.DEFAULT_RATIO)
	ctx:set_ratio_max(Data.RATIO_CAP)
	ctx.troop_floor = nil
end

function Tutorial.stop(self, how: string)
	if not self.active then
		return
	end
	self.active = false
	self._mark.Visible = false
	self.ctx:set_ratio_max(1.0)
	self.ctx.troop_floor = nil
	if how == "done" then
		-- the last card: what to do next (2026-10-31: no Stars reward any more)
		self._ending = Tutorial.END_S
		self._count:set_text("DONE")
		self._text:set_text(Data.DONE_TEXT or "Your empire is ready!")
		self._bar:set_visible(false)
		self._skip:set_text("OK")
		self:_tint(UITheme.GREEN)
		self._card:set_visible(true)
		self:_place()
		self.ctx:sfx("unlock", -4.0)
	else
		self._card:set_visible(false)
	end
	self.finished:Fire(how)
	if how ~= "done" then
		self.closed:Fire()
	end
end

function Tutorial._close(self)
	self._ending = 0.0
	self._card:set_visible(false)
	self.closed:Fire()
end

function Tutorial._tint(self, col: any)
	self._card:set_accent(col)
	self._card:set_border(UITheme.c(col, 0.5))
	UITheme.set_font_color(self._count, col)
end

function Tutorial.apply_layout(self)
	if self._card.visible then
		self:_place()
	end
end

--- The card: top centre, under Roblox's top bar row and the match's status pill.
function Tutorial._place(self)
	local ctx = self.ctx
	local vp, ins = ctx.vp, ctx.insets
	local c = ctx.compact
	self._text:set_font_size(if c then 13 else 15)
	-- (the reward's two lines are a little longer than a step's)
	self._text:set_min_size(Vector2.new(if self._ending > 0.0 then 256 elseif c then 200 else 260, 0))
	self._card:reset_size()
	local sz = self._card:get_combined_minimum_size()
	local x = math.clamp((vp.X - sz.X) * 0.5, ins.x + 8.0, math.max(ins.x + 8.0, vp.X - ins.z - sz.X - 8.0))
	UICtx.move_node(self._card, Vector2.new(math.floor(x), math.floor(ins.y + (if c then 62.0 else 74.0))))
end

-- ---------------------------------------------------------------------------------------------
-- What the player did
-- ---------------------------------------------------------------------------------------------

--- The orders sent since the last look: any, an attack on a neighbour, on empty land.
function Tutorial._orders(self): (boolean, boolean, boolean)
	local log = self.ctx.sent_log
	local s = self.ctx.state
	local any, on_owner, on_land = false, false, false
	-- (the log is a window of the last orders: after it wraps, count from its end)
	if self._sent > #log then
		self._sent = 0
	end
	for i = self._sent + 1, #log do
		local it = log[i].intent
		if type(it) == "table" and (it.type == "attack" or it.type == "boat") then
			any = true
			local target = tonumber(it.target)
			if target == nil and type(it.tile) == "number" and s ~= nil then
				target = s:tile_owner(it.tile)
			end
			if target ~= nil and target > 0 then
				on_owner = true
			else
				on_land = true
			end
		end
	end
	self._sent = #log
	return any, on_owner, on_land
end

--- A roomy place to start: of SPAWN_TRIES free land tiles, one far from every nation's start
--- (SPAWN_ROOM tiles is far enough) and away from the map's top and bottom edges (the first pick on
--- the world map was the middle of Antarctica: empty, and nothing to see).
function Tutorial._find_spot(self): number?
	local s = self.ctx.state
	local map = s and s.map
	if map == nil or type(map.land_tile) ~= "function" or (map.land_count or 0) <= 0 then
		return nil
	end
	local starts = {}
	for _, o in s.owners do
		if type(o.spawn_tile) == "number" and o.spawn_tile >= 0 then
			table.insert(starts, o.spawn_tile)
		end
	end
	local best, best_d = nil, -1.0
	for _ = 1, Tutorial.SPAWN_TRIES do
		local t = map:land_tile(math.random(0, map.land_count - 1))
		if map:is_contestable(t) and s:tile_owner(t) == 0 and not map:is_coastal(t) then
			local d = math.huge
			for _, o in starts do
				d = math.min(d, Defs.tile_distance(t, o))
			end
			d = math.min(d, Tutorial.SPAWN_ROOM)
			local W, H = map.W or Defs.W, map.H or Defs.H
			local off = math.abs((t // W) / H - 0.45)
			d -= math.max(0.0, off - 0.27) * 300.0
			if d > best_d then
				best, best_d = t, d
			end
		end
	end
	return best
end

function Tutorial._say(self, i: number, arg: string?)
	local step = Data.STEPS[i]
	local txt = if self.ctx.touch then step.touch else step.desktop
	if string.find(txt, "%s", 1, true) then
		txt = string.format(txt, arg or "them")
	end
	self._count:set_text(string.format("%d / %d", i, #Data.STEPS))
	self._text:set_text(txt)
	self._bar:set_visible(step.bar == true)
	self._fill.Size = UDim2.fromScale(0, 1)
	self._fill.BackgroundColor3 = UITheme.AMBER
	self._fill_f = 0.0
	self._skip:set_text(if step.info then "Got it" else "Skip")
	self:_tint(UITheme.AMBER)
	self._card:set_visible(i > 1)
	if i > 1 then
		self:_place()
		UICtx.pop_in(self._card, 0.0, 0.94, 0.3, true)
	end
end

--- Step `i` is finished (`passed`: nobody did it in time, it is passed over without a tick).
function Tutorial._advance(self, passed: boolean?)
	local step = Data.STEPS[self._i]
	if not passed then
		self.step_done:Fire(Data.funnel_step(step.id), Data.FUNNEL[Data.funnel_step(step.id)])
		self.ctx:sfx("confirm", -4.0)
		if self._card.visible then
			self:_tint(UITheme.GREEN)
			self._text:set_text("Nice!")
			self._bar:set_visible(false)
			self._flash = Tutorial.DONE_S
		end
	end
	self._i += 1
	self._step_t = 0.0
	self._idle = 0.0
	self._shown = nil
	self._guard = os.clock() + Tutorial.GUARD_S
	if self._i > #Data.STEPS then
		self.step_done:Fire(#Data.FUNNEL, Data.FUNNEL[#Data.FUNNEL])
		self:stop("done")
	end
end

-- ---------------------------------------------------------------------------------------------
-- Per frame
-- ---------------------------------------------------------------------------------------------

function Tutorial._process(self, delta: number)
	self._t += delta
	if self._ending > 0.0 then
		self._ending -= delta
		if self._ending <= 0.0 then
			self:_close()
		end
		return
	end
	if not self.active then
		return
	end
	local ctx = self.ctx
	local ui = self.ui
	local s = ctx.state
	if s == nil or ctx:mode() ~= UICtx.MODE_SOLO then
		return
	end
	if s.phase == Defs.PHASE_OVER then
		self:stop("left")
		return
	end
	-- a finished step's green card stands a moment before the next line
	if self._flash > 0.0 then
		self._flash -= delta
		self._mark.Visible = false
		if self._flash > 0.0 then
			return
		end
	end
	local i = self._i
	local step = Data.STEPS[i]
	local o = ctx:my()
	local any, on_owner, on_land = self:_orders()
	self._step_t += delta
	if
		ctx.troop_floor == nil
		and i >= (Data.step_index(Data.FLOOR_FROM) or 1)
		and o ~= nil
		and Data.floor_armed(o.troops or 0, o.max_troops or 0, ctx:alive_seconds())
	then
		ctx.troop_floor = Data.TROOP_FLOOR
	end
	if not self._started and self._step_t > 1.0 then
		-- the match is up (and reported: the server logs a step for a match it knows of)
		self._started = true
		self.step_done:Fire(1, Data.FUNNEL[1])
	end
	self._idle = if any then 0.0 else self._idle + delta
	local point = Vector2.new(-1, -1)
	--- (a control's radius, when the mark is for one: it goes around it)
	local around: number? = nil
	--- (what the mark says, when not the step's own word)
	local word: string? = nil
	local id = step.id
	if id == "spawn" then
		if o ~= nil and o.spawned then
			self:_advance()
			return
		end
		if self._spot == nil or self._spot_state ~= s then
			self._spot = self:_find_spot()
			self._spot_state = s
			self._step_t = 0.0
			if self._spot ~= nil then
				-- the camera goes there, close enough that a thumb hits the land around it
				local w = ctx.world
				local d = if w ~= nil and w.rig ~= nil and type(w.rig.scale_to_distance) == "function"
					then w.rig:scale_to_distance(Tutorial.SPAWN_PX)
					else -1.0
				ctx:world_call("focus_tile", { self._spot, d, 0.9 })
			end
		end
		if self._spot ~= nil then
			point = ctx:tile_screen_pos(self._spot)
			if self._step_t > Data.AUTO_SPAWN_S and not self._picked and s:tile_owner(self._spot) == 0 then
				-- nobody picked: this spot is theirs
				self._picked = true
				ctx:send({ type = "spawn", tile = self._spot })
			end
		end
	elseif o ~= nil and o.spawned and o.alive == false then
		self:stop("left") -- (conquered: the result screen takes over)
		return
	elseif o == nil or not ctx:alive_player() or s.phase ~= Defs.PHASE_PLAYING then
		self._mark.Visible = false
		return
	else
		if self._shown ~= i then
			-- the step's line (and what it needs) once, when it comes up
			self._shown = i
			if id == "grow" then
				self._taps = 0
				self._ready = nil
				self._refill = nil
				self._line = nil
				-- (an order sent while "expand"'s card was green was that step's second tap)
				any = false
			elseif id == "attack" then
				self._neighbour = nil
			elseif id == "ratio" then
				self._ratio_ok = 0.0
				self._ratio_high = false
			elseif id == "terrain" then
				self._relief = self:_find_relief()
				if self._relief ~= nil then
					ctx:world_call("focus_tile", { self._relief, -1.0, 0.9 })
				end
			elseif step.at ~= nil then
				-- (the boats' card: the sea nearest the player's land; the allies': a neighbour)
				if step.at == "sea" then
					self._spot_at = self:_near_tile(function(t, code)
						return code == Defs.T_OCEAN
					end)
				else
					local ns = ctx.borders:neighbour_ids()
					self._spot_at = if #ns > 0 then s:label_tile(ns[1]) else nil
				end
				if self._spot_at ~= nil and self._spot_at >= 0 then
					ctx:world_call("focus_tile", { self._spot_at, -1.0, 0.9 })
				else
					self._spot_at = nil
				end
			elseif step.build ~= nil then
				-- (2026-11-01) a building to place: where it can go, and its gold
				self._site = nil
				if step.needs == "coast" and not ctx.borders:has_coast() then
					self:_advance(true)
					return
				elseif step.needs == "hills" then
					local me = ctx:me()
					self._site = self:_near_tile(function(t, code)
						return code >= Defs.T_HIGHLAND and s:tile_owner(t) == me
					end)
					if self._site == nil then
						self:_advance(true) -- (no hills in the empire yet)
						return
					end
				end
				if not self._gold_given[id] then
					self._gold_given[id] = true
					local sim = ctx:session_call("local_sim")
					local cost = ctx.rules:cost(step.build)
					if sim ~= nil and type(sim.o_gold) == "table" and cost > 0 and (sim.o_gold[ctx:me()] or 0) < cost then
						sim.o_gold[ctx:me()] = cost
					end
				end
			end
			self:_say(i, if self._neighbour ~= nil then s:owner_name(self._neighbour) else nil)
		end
		if id == "expand" then
			if any then
				self:_advance()
				return
			end
			point = ui.advisor:frontier_point()
		elseif id == "grow" then
			-- let the troops refill (Data.GROW_READY: the bar fills towards ready), then expand. An
			-- expansion sent before counts too: its card says to let the bar fill next time
			if any then
				local early = not self._ready
				self._taps += 1
				if early then
					-- (it spent the refill: the bar drops)
					self._refill = nil
				end
				if self._taps >= Data.GROW_TAPS then
					self:_advance()
					if early and self._card.visible then
						self._text:set_text(step.early)
						self._flash = Data.EARLY_S
					end
					return
				end
			end
			local cap = o.max_troops or 0
			local f = if cap > 0 then Data.refill(o.troops, cap, self._refill) else 1.0
			self._refill = f
			-- (a full bar stays full, so ready stays ready while the cap climbs under it)
			local ready = f >= 1.0
			if ready ~= self._ready then
				if ready and self._ready == false then
					-- refilled: the card says so, so eyes on the troop count come back up
					ctx:sfx("tick", -6.0)
					UICtx.pop_in(self._card, 0.0, 0.97, 0.25, true)
				end
				self._ready = ready
				self._fill.BackgroundColor3 = if ready then UITheme.GREEN else UITheme.AMBER
			end
			local line = if ready then (if ctx.touch then step.touch else step.desktop) else step.wait
			if line ~= self._line then
				self._line = line
				self._text:set_text(line)
			end
			if math.abs(f - (self._fill_f or 0.0)) >= 0.005 or (ready and self._fill_f ~= 1.0) then
				self._fill_f = f
				self._fill.Size = UDim2.fromScale(f, 1)
			end
			if not ready then
				-- the troop count, filling
				local tc = self:_troops_control()
				if tc ~= nil then
					local r = tc:get_global_rect()
					point = UICtx.rect_center(r)
					around = math.max(r.Width, r.Height) * 0.5
					word = "Refilling"
				end
			elseif self._taps == 0 or self._idle > Data.NUDGE_S then
				point = ui.advisor:frontier_point()
			end
		elseif id == "ratio" then
			-- a moderate share, and left there: never a push to send everything
			local r = ctx.ratio
			if r >= Data.RATIO_LOW and r <= Data.RATIO_HIGH then
				self._ratio_ok = (self._ratio_ok or 0.0) + delta
				if self._ratio_ok >= Data.RATIO_HOLD_S then
					self:_advance()
					return
				end
			else
				self._ratio_ok = 0.0
			end
			local high = r > Data.RATIO_HIGH
			if high ~= self._ratio_high then
				self._ratio_high = high
				self._text:set_text(
					if high then Data.RATIO_TOO_MUCH elseif ctx.touch then step.touch else step.desktop
				)
				self:_tint(if high then UITheme.RED else UITheme.AMBER)
			end
			-- the mark goes around the stop to tap
			local sl = ui.bar._slider
			if sl ~= nil and sl:is_visible_in_tree() then
				local r = sl:stop_rect(Data.RATIO_GOAL) or sl:get_global_rect()
				point = UICtx.rect_center(r)
				around = math.min(r.Width, r.Height) * 0.5
			end
		elseif step.info then
			-- read, then GOT IT (or INFO_S passes): counts as done either way
			if self._step_t > (step.max_s or Data.INFO_S or 9) then
				self:_advance()
				return
			end
			if id == "terrain" then
				if self._relief ~= nil then
					point = ctx:tile_screen_pos(self._relief)
				end
			elseif step.button ~= nil then
				-- (the building's slot on the command bar, or the BUILD tray that holds it)
				local cb = ui.bar:button(step.button)
				local b = if cb ~= nil and cb:is_visible_in_tree() then cb else ui.bar._tray_btn
				if b ~= nil and b:is_visible_in_tree() then
					local r = b:get_global_rect()
					point = UICtx.rect_center(r)
					around = math.max(r.Width, r.Height) * 0.5
				end
			elseif self._spot_at ~= nil then
				point = ctx:tile_screen_pos(self._spot_at)
			end
			-- (nothing to tap on a card to read)
			word = step.mark or "Look here"
		elseif id == "attack" then
			if on_owner then
				self:_advance()
				return
			end
			if self._neighbour == nil or s:get_owner(self._neighbour) == nil then
				local ns = ctx.borders:neighbour_ids()
				if #ns > 0 then
					self._neighbour = ns[1]
					self:_say(i, s:owner_name(ns[1]))
				elseif self._step_t > Data.CONTACT_WAIT_S then
					self:_advance(true) -- nobody to attack yet
					return
				else
					-- no neighbour yet: keep growing towards one
					self._text:set_text(if ctx.touch then "Keep growing until you meet a neighbour" else "Keep growing until you meet a neighbour")
					if self._idle > Data.NUDGE_S then
						point = ui.advisor:frontier_point()
					end
				end
			end
			if self._neighbour ~= nil and s:get_owner(self._neighbour) ~= nil then
				point = ctx:tile_screen_pos(s:label_tile(self._neighbour))
			end
		elseif step.build ~= nil then
			local kind = Defs.struct_kind_from_name(step.build)
			for _, st in s.structures do
				if st.owner == ctx:me() and st.kind == kind then
					self:_advance()
					return
				end
			end
			local cb = ui.bar:button(step.build)
			local b = if cb ~= nil and cb:is_visible_in_tree() then cb else ui.bar._tray_btn
			local pc = ui.place_confirm
			local placing = ui.interact.aim_kind == step.build
			-- (while the City is in hand the game's own line stands where the card does: the card
			-- steps aside and only the mark leads on)
			if self._card.visible == placing then
				self._card:set_visible(not placing)
			end
			if pc ~= nil and pc.is_open and pc._ok:is_visible_in_tree() then
				-- a spot is picked: the tick builds it
				local r = pc._ok:get_global_rect()
				point = UICtx.rect_center(r)
				around = math.max(r.Width, r.Height) * 0.5
			elseif placing then
				-- the building is in hand: the mark moves to the player's land (a Mine: its hills)
				point = ctx:tile_screen_pos(self._site or s:label_tile(ctx:me()))
			elseif b ~= nil and b:is_visible_in_tree() then
				local r = b:get_global_rect()
				point = UICtx.rect_center(r)
				around = math.max(r.Width, r.Height) * 0.5
			end
		end
		if self._step_t > (step.max_s or Data.STEP_MAX_S) then
			self:_advance(true)
			return
		end
	end
	self:_draw_mark(point, word or step.mark, around)
end

--- The "terrain" step's example: the mountain (else hill) tile nearest the player's land, within
--- RELIEF_R tiles, or nil.
Tutorial.RELIEF_R = 90
function Tutorial._find_relief(self): number?
	local s = self.ctx.state
	local map = s and s.map
	local me = self.ctx:me()
	if map == nil or map.terrain == nil or me == 0 then
		return nil
	end
	local c = s:label_tile(me)
	if type(c) ~= "number" or c < 0 then
		return nil
	end
	local W, H = map.W, map.H
	local cx, cy = c % W, c // W
	local R = Tutorial.RELIEF_R
	local best_m, bd_m = nil, math.huge
	local best_h, bd_h = nil, math.huge
	for dy = -R, R, 2 do
		local y = cy + dy
		if y < 0 or y >= H then
			continue
		end
		for dx = -R, R, 2 do
			local x = cx + dx
			if x < 0 or x >= W then
				continue
			end
			local t = y * W + x
			local code = buffer.readu8(map.terrain, t)
			local d = dx * dx + dy * dy
			if code == Defs.T_MOUNTAIN and d < bd_m then
				best_m, bd_m = t, d
			elseif code == Defs.T_HIGHLAND and d < bd_h then
				best_h, bd_h = t, d
			end
		end
	end
	return best_m or best_h
end

--- The tile nearest the player's land (its label) within RELIEF_R tiles for which `pred(tile,
--- terrain code)` holds, or nil.
function Tutorial._near_tile(self, pred: (number, number) -> boolean): number?
	local s = self.ctx.state
	local map = s and s.map
	local me = self.ctx:me()
	if map == nil or map.terrain == nil or me == 0 then
		return nil
	end
	local c = s:label_tile(me)
	if type(c) ~= "number" or c < 0 then
		return nil
	end
	local W, H = map.W, map.H
	local cx, cy = c % W, c // W
	local R = Tutorial.RELIEF_R
	local best, bd = nil, math.huge
	for dy = -R, R do
		local y = cy + dy
		if y < 0 or y >= H then
			continue
		end
		for dx = -R, R do
			local x = cx + dx
			local d = dx * dx + dy * dy
			if x < 0 or x >= W or d >= bd then
				continue
			end
			local t = y * W + x
			if pred(t, buffer.readu8(map.terrain, t)) then
				best, bd = t, d
			end
		end
	end
	return best
end

--- The command bar's troop count as it shows (phones' compact bar has its own), or nil.
function Tutorial._troops_control(self): any
	local bar = self.ui.bar
	if bar == nil then
		return nil
	end
	for _, c in { bar._troops_box, bar._m_troops } do
		if c ~= nil and c:is_visible_in_tree() then
			return c
		end
	end
	return nil
end

--- The tap mark at logical point `p` ((-1, -1): none); `word`: what it says instead of "Tap here".
--- `around`: the mark is for a control of this radius, and goes around it, not on it (on the
--- confirm tick the dot and rings sat on the icon, which looked bad; 2026-10-04).
--- Without it (a spot on the map) two rings close on a dot.
function Tutorial._draw_mark(self, p: Vector2, word: string?, around: number?)
	local ctx = self.ctx
	local mark = self._mark
	if p.X < 0.0 or p.Y < 0.0 or p.X > ctx.vp.X or p.Y > ctx.vp.Y then
		mark.Visible = false
		return
	end
	ctx:fit_canvas(mark)
	mark.Visible = true
	-- two rings closing on the dot, half a beat apart: a finger coming down
	local k1 = (self._t % 1.1) / 1.1
	local k2 = ((self._t + 0.55) % 1.1) / 1.1
	-- (a control: the rings close from outside onto its edge and stop there, and there is no dot)
	local inner = if around ~= nil then around + 4.0 else 12.0
	local outer = inner + (if around ~= nil then 16.0 else 22.0)
	UICtx.set_circle(self._ring_a, p, outer - (outer - inner) * k1)
	UICtx.set_circle(self._ring_b, p, outer - (outer - inner) * k2);
	(self._ring_a:FindFirstChild("Stroke") :: UIStroke).Transparency = 1 - k1 * 0.95;
	(self._ring_b:FindFirstChild("Stroke") :: UIStroke).Transparency = 1 - k2 * 0.95
	self._dot.Visible = around == nil
	UICtx.set_circle(self._dot, p, 6.0)
	self._tap.Text = word or (if ctx.touch then "Tap here" else "Click here")
	-- (under the mark; over it when the mark is near the bottom of the screen, on the command bar)
	local gap = outer + 6.0
	local below = p.Y + gap + 26 < ctx.vp.Y - ctx.insets.w
	self._tap.AnchorPoint = Vector2.new(0.5, if below then 0 else 1)
	self._tap.Position = UDim2.fromOffset(p.X, if below then p.Y + gap else p.Y - gap)
end

return Tutorial
