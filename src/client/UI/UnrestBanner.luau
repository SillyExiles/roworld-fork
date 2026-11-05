--!nonstrict
-- (Empires Front 2026-11-01) The player's unrest on the HUD (Core/SimRevolts), under the status pill:
--   · a meter "UNREST 42%" with what drives it, once it reaches SHOW_AT;
--   · a warned province: "UNREST IN THESSALY", the seconds until it revolts, what calms it, and VIEW;
--   · rebels risen against the player: "REVOLT: THESSALY REBELS", the time left to crush them for a
--     reward... (2026-11-01: now only what the province is worth and two choices: BUY BACK at that
--     price, Rules.province_value, or RECOGNIZE it as an independent nation, an ally).
-- An alarm sounds when a warning comes up and when a province rises.
--   UnrestBanner.new(ctx) · apply_layout(y, right_x?) · refresh() (4 a second by itself)

local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local FillBar = require("./FillBar")
local UIRules = require("./UIRules")

local UnrestBanner = W.class(W.Control)

--- The meter shows from this unrest on (0..100).
UnrestBanner.SHOW_AT = 30
--- (2026-11-01) Revolts are a surprise (Core/SimRevolts.SECRET): no meter, no warning; only a
--- province that rose shows (crush / VIEW / PAY).
UnrestBanner.SHOW_UNREST = false
UnrestBanner.WIDTH = 330.0

local AMBER_TINT = UITheme.rgba(0.2, 0.12, 0.03, 0.88)
local RED_TINT = UITheme.rgba(0.26, 0.03, 0.07, 0.9)

--- What each part of the unrest means (Core/SimRevolts.PARTS order) when it counts.
UnrestBanner.CAUSES = {
	{ 10, "few troops" },
	{ 8, "a huge empire" },
	{ 1, "you lead" },
	{ 6, "far from the capital" },
	{ 8, "new conquests" },
}

function UnrestBanner.new(c: any)
	local self = setmetatable({}, UnrestBanner.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self._acc = 0.0
	self._t = 0.0
	self._mode = ""
	self._warn_key = ""
	self._rebel_key = ""
	self._focus_tile = -1
	self._rebel = 0
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)

	self.panel = GlassPanel.new(14.0, 10.0, 16, true, 24)
	self.panel:set_tint(AMBER_TINT)
	self.panel:set_border(T.c(T.ORANGE, 0.8))
	self:add_child(self.panel)
	local v = T.vbox(6)
	self.panel:add_child(v)
	local head = T.hbox(10)
	self._icon = T.icon_rect("troops", 18.0, T.ORANGE)
	self._icon.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._icon)
	self._title = T.label("UNREST", 14, 800, T.ORANGE, 2)
	self._title.size_flags_horizontal = W.EXPAND_FILL
	self._title.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._title)
	self._pct = T.label("", 14, 800, T.ORANGE)
	self._pct.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._pct)
	v:add_child(head)
	self._bar = FillBar.new(5.0, T.ORANGE)
	self._bar.fill_color_2 = T.RED
	v:add_child(self._bar)
	self._detail = T.label("", 11, 500, Color3.new(1.0, 0.9, 0.82))
	self._detail:set_autowrap(true)
	v:add_child(self._detail)
	local btns = T.hbox(8)
	self._view = T.button("VIEW", "GlassButton", "eye", 32.0)
	self._view:set_font_size(12)
	self._view:add_theme_constant_override("icon_max_width", 14)
	self._view.pressed:Connect(function()
		if self._focus_tile >= 0 then
			self.ctx:sfx("click")
			self.ctx:world_call("focus_tile", { self._focus_tile, -1.0, 0.8 })
		end
	end)
	btns:add_child(self._view)
	self._pay = T.button("PAY", "PrimaryButton", "gold", 32.0)
	self._pay:set_font_size(12)
	self._pay:add_theme_constant_override("icon_max_width", 14)
	self._pay.size_flags_horizontal = W.EXPAND_FILL
	self._pay.pressed:Connect(function()
		if self._rebel > 0 then
			self.ctx:send({ type = "pay_rebels", target = self._rebel })
			self.ctx:sfx("buy")
		end
	end)
	btns:add_child(self._pay)
	self._recog = T.button("RECOGNIZE", "GlassButton", "alliance", 32.0)
	self._recog:set_font_size(12)
	self._recog:add_theme_constant_override("icon_max_width", 14)
	self._recog.size_flags_horizontal = W.EXPAND_FILL
	self._recog.pressed:Connect(function()
		if self._rebel > 0 then
			self.ctx:send({ type = "recognize_rebels", target = self._rebel })
			self.ctx:sfx("confirm")
		end
	end)
	btns:add_child(self._recog)
	self._btns = btns
	v:add_child(btns)
	self.gui.Name = "UnrestBanner"
	self._view.gui.Name = "UnrestView"
	self._pay.gui.Name = "UnrestPay"
	self._recog.gui.Name = "UnrestRecognize"
	self:set_visible(false)
	self:set_process(true)
	return self
end

--- Under the status pill (desktop: centred; phones: right-aligned at `right_x`).
function UnrestBanner.apply_layout(self, y: number, right_x: number?)
	local ctx = self.ctx
	local T = UITheme
	local p = self.panel
	p:set_mouse_filter(W.MOUSE_STOP)
	local w = if ctx.compact then 280.0 else UnrestBanner.WIDTH
	self._detail:set_min_size(Vector2.new(w, 0))
	T.fix_width(self._title, w - 70, W.ALIGN_LEFT, false)
	self._bar:set_min_size(Vector2.new(w, 5))
	p.anchor_top, p.anchor_bottom = 0.0, 0.0
	p.grow_vertical = W.GROW_END
	local rx = right_x or -1.0
	if rx >= 0 then
		p.anchor_left, p.anchor_right = 1.0, 1.0
		p.grow_horizontal = W.GROW_BEGIN
		p.offset_left, p.offset_right = -rx, -rx
	else
		p.anchor_left, p.anchor_right = 0.5, 0.5
		p.grow_horizontal = W.GROW_BOTH
		p.offset_left, p.offset_right = 0, 0
	end
	p.offset_top, p.offset_bottom = y, y
	p:reset_size()
end

function UnrestBanner.bottom_edge(self): number
	if not self.visible then
		return 0.0
	end
	local r = self.panel:get_global_rect()
	return r.Max.Y
end

--- The player's rising rebels (the newest band), or nil.
local function my_rebels(s: any, me: number): any
	local best = nil
	for _, o in s.owners do
		if o.alive and o.rebel_of == me and o.rebel_state == 0 and (best == nil or o.rebel_born > best.rebel_born) then
			best = o
		end
	end
	return best
end

local function causes(parts: { number }?): string
	if parts == nil then
		return ""
	end
	local out = {}
	for i, c in UnrestBanner.CAUSES do
		if (parts[i] or 0) >= c[1] then
			table.insert(out, c[2])
		end
	end
	local calm = parts[6] or 0
	local line = if #out > 0 then "From " .. table.concat(out, ", ") .. "." else ""
	if calm > 0 then
		line ..= string.format(" Buildings calm it by %d.", calm)
	end
	return line
end

--- (2026-11-05) Why a province rose (the unrest parts at the rising, SimRevolts.PARTS), and what
--- keeps the next one down: "Why: far from the capital, few troops. Calm: Temples, a Palace ... ".
UnrestBanner.WHY = {
	{ 10, "few troops at home" },
	{ 8, "a huge empire" },
	{ 1, "you lead the world" },
	{ 6, "far from your capital" },
	{ 8, "new conquests" },
}
function UnrestBanner.why_line(parts: { number }?): string
	if type(parts) ~= "table" then
		return ""
	end
	local out = {}
	for i, c in UnrestBanner.WHY do
		if (parts[i] or 0) >= c[1] then
			table.insert(out, c[2])
		end
	end
	if (parts[6] or 0) < 10 then
		table.insert(out, "no Temple or Palace near")
	end
	if #out == 0 then
		return ""
	end
	return "Why it rose: " .. table.concat(out, ", ") .. ". Temples, a Palace and Fortresses keep provinces calm.\n"
end

function UnrestBanner._style(self, mode: string)
	if self._mode == mode then
		return
	end
	self._mode = mode
	local T = UITheme
	local red = mode ~= "meter"
	local col = if red then Color3.new(1.0, 0.55, 0.5) else T.ORANGE
	self.panel:set_tint(if red then RED_TINT else AMBER_TINT)
	self.panel:set_border(T.c(if red then T.RED else T.ORANGE, 0.85))
	self._title:set_color(col)
	self._pct:set_color(col)
	self._icon:set_color(col)
	self._icon:set_icon(if mode == "revolt" then "attack" else "troops")
	self._bar:set_visible(mode ~= "revolt")
	self._pay:set_visible(mode == "revolt")
	self._recog:set_visible(mode == "revolt")
	self._view:set_visible(mode == "warn")
	self._btns:set_visible(mode ~= "meter")
end

function UnrestBanner.refresh(self)
	local ctx = self.ctx
	local s = ctx.state
	local me = ctx:me()
	local o = if s ~= nil and me ~= 0 then s:get_owner(me) else nil
	local playing = s ~= nil and s.phase == 1 and o ~= nil and o.alive
	if not playing then
		if self.visible then
			self:set_visible(false)
		end
		return
	end
	local T = UITheme
	local tick = ctx:render_tick()
	local rate = 10
	local was = self.visible
	local reb = my_rebels(s, me)
	local warn_left = if (o.unrest_at or 0) > 0 then (o.unrest_at - tick) / rate else -1
	if reb ~= nil then
		self:_style("revolt")
		self._rebel = reb.id
		self._focus_tile = tonumber(reb.label_tile) or -1
		if self._focus_tile < 0 then
			self._focus_tile = s:label_tile(reb.id)
		end
		self._title:set_text("REVOLT: " .. string.upper(tostring(reb.name)))
		self._pct:set_text("")
		-- what the province is worth (the Sim's valuation, Ev.REBEL): its price to buy it back
		local price = UIRules.rebel_price(s, me, reb.id)
		self._detail:set_text(string.format(
			"%sProvince worth %s: land %s · troops %s · buildings %s. Buy it back, or recognize it as an independent nation (your ally).",
			UnrestBanner.why_line(reb.rebel_why),
			T.fmt_cost(math.max(price, 0)),
			T.fmt_cost(tonumber(reb.rebel_land) or 0),
			T.fmt_cost(tonumber(reb.rebel_troops_value) or 0),
			T.fmt_cost(tonumber(reb.rebel_buildings) or 0)
		))
		local gold = tonumber(o.gold) or 0
		self._pay:set_text(if price > 0 then "BUY BACK " .. T.fmt_cost(price) else "BUY BACK")
		self._pay:set_disabled(price <= 0 or gold < price)
		local key = tostring(reb.id)
		if key ~= self._rebel_key then
			self._rebel_key = key
			ctx:sfx("betrayal")
			W.pop_in(self.panel, 0.0, 1.12, 0.35)
		end
	elseif UnrestBanner.SHOW_UNREST and warn_left > 0 then
		self:_style("warn")
		self._rebel = 0
		self._focus_tile = tonumber(o.unrest_tile) or -1
		self._title:set_text("UNREST IN " .. string.upper(tostring(o.unrest_prov)))
		self._pct:set_text(string.format("%d%%", math.floor(o.unrest or 0)))
		self._bar:set_target(math.clamp((o.unrest or 0) / 100, 0, 1))
		self._detail:set_text(string.format(
			"Revolts in %s! Raise your troops, or build a City, Market, Defense Post or a road there. %s",
			T.fmt_time(math.ceil(warn_left)),
			causes(o.unrest_parts)
		))
		local key = string.format("%d", o.unrest_at)
		if key ~= self._warn_key then
			self._warn_key = key
			ctx:sfx("alarm")
			W.pop_in(self.panel, 0.0, 1.12, 0.35)
		end
	elseif UnrestBanner.SHOW_UNREST and (o.unrest or 0) >= UnrestBanner.SHOW_AT then
		self:_style("meter")
		self._rebel = 0
		self._focus_tile = tonumber(o.unrest_tile) or -1
		self._title:set_text("UNREST")
		self._pct:set_text(string.format("%d%%", math.floor(o.unrest or 0)))
		self._bar:set_target(math.clamp((o.unrest or 0) / 100, 0, 1))
		self._detail:set_text(causes(o.unrest_parts) .. " At 55% a far province may revolt.")
	else
		if was then
			self:set_visible(false)
		end
		return
	end
	if not was then
		self:set_visible(true)
	end
	self.panel:reset_size()
	-- (its height changes with the mode and the text: UIRoot places it again)
	local h = math.floor(self.panel:get_combined_minimum_size().Y)
	if (not was or h ~= self._h) and self.on_layout ~= nil then
		self._h = h
		self.on_layout()
	end
end

function UnrestBanner._process(self, delta: number)
	self._acc += delta
	self._t += delta
	if self._acc >= 0.25 then
		self._acc = 0.0
		self:refresh()
	end
	-- a warning or a revolt pulses
	if self.visible and self._mode ~= "meter" then
		local a = 0.75 + 0.25 * (0.5 + 0.5 * math.sin(self._t * 6.0))
		self.panel:set_modulate_a(a)
	elseif self.visible then
		self.panel:set_modulate_a(1.0)
	end
end

return UnrestBanner
