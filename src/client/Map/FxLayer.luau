--!native
-- Effects on the 2D map: a nuke's shockwave ring grows to 1.5 x its
-- blast radius over 1.5 s behind a white flash, a destroyed ship / shot-down nuke pops a small
-- ring (0.8 s), and the camera shakes a little for nukes near the view. Pooled GUI circles.
-- Conquests by the local player (a flag and a gold popup): a victory
-- flag planted at the conquered name's location, its banner the conqueror's colour (Assets/MapFx:
-- 10 frames of 24 x 24 at 90 ms, drawn 22 full-size tiles wide, 2.5 s, fade in over the first 10 % and
-- out after 60 %; 2026-10-25: it replaced a sword clash for the elimination), and a
-- white "+ 12.3K" gold line below it (font 6 tiles, fading
-- linearly).
-- Both keep a minimum on-screen size, so a zoomed-out map still shows them.
-- Income (2026-10-07:
-- trains show the little money-increase popup as they pass through cities too): gold the local
-- player earned at a tile, a train's stop at a station, is a white "+ 25.0K" that starts 3 full-size tiles
-- above the tile, rises 3 tiles a second and fades out over 1.5 s (font 6 tiles). It keeps a minimum
-- size on screen and is not drawn on a map zoomed far out (and is never bigger than
-- 40 px).
-- Explosions (Assets/MapFx; added 2026-10-04 for a destroyed defense post and for a
-- nuke shot down by a SAM): a
-- destroyed defense post or Arsenal structure plays `building` over a small ring, a nuke shot
-- down plays `sam` where it was. They are seen, not heard (shots and hits were made silent
-- on 2026-09-27: together they were a constant racket).
-- Nukes (since
-- 2026-10-12; the trailer's hydrogen bombs fell flat when a ring and a green stain were all
-- a nuke left): a nuke that lands plays the explosion (Assets/MapFx: 12 frames of
-- 60 x 60 at 70 ms, drawn 60 full-size tiles wide) and leaves debris burning: mini fires, smoke, big
-- smoke and smoke with fire (DEBRIS_PLAN, looping) scattered within half its radius, 6 s, fading in
-- over the first 10 % and out after 80 %; its ring grows to 1.5 x that radius. The radius is the
-- look's (NUKE_FX_RADIUS), not the blast's.
-- Every pooled object remembers what it was last given and is written only what changed (2026-10-26,
-- phones' slow frames: a nuke's 240 debris sprites were written six properties each a frame, with the
-- view still and between their frames), and spent effects leave their lists in one pass, in order.
-- Signals (Empires Front, 2026-10-31): a teammate's or ally's marker (GameState.pinged: "attack here"
-- in red, "help here" in amber) is its pixel glyph with the sender's name under it and a ring pulsing
-- around it, a fixed size on screen, for PING_S seconds (fading over the last PING_FADE_S).
local ContentProvider = game:GetService("ContentProvider")
local RS = game:GetService("ReplicatedStorage")
local Airfront = RS:WaitForChild("Airfront")
local Defs = require(Airfront:WaitForChild("Core"):WaitForChild("Defs")) :: any
local Rules = require(Airfront:WaitForChild("Core"):WaitForChild("Rules")) :: any
-- Every sprite here is drawn for Rofront, rows of one atlas (tools/assets/make_map_fx.py; 2026-10-25:
-- all new art): the explosions, the debris a nuke leaves and the conquest's flag.
local MapFx = require(Airfront:WaitForChild("Assets"):WaitForChild("MapFx")) :: any
local FrameClock = require(script.Parent:WaitForChild("FrameClock")) :: any
-- (Empires Front 2026-11-06: the atlas drawn by the client; the uploaded one is not this experience's)
local MapFxImage = require(script.Parent:WaitForChild("MapFxImage")) :: any
local WHITE = Color3.new(1, 1, 1)
local PixelIcons = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("PixelIcons")) :: any

local FxLayer = {}
FxLayer.__index = FxLayer

FxLayer.NUKE_SHOCK_S = 1.5
FxLayer.NUKE_SHOCK_K = 1.5
FxLayer.POP_S = 0.8
FxLayer.POP_RADIUS = 40 -- full-size tiles (the ring of a ship or nuke shot down)
FxLayer.Z = 16
FxLayer.CONQUEST_S = 2.5
FxLayer.CONQUEST_FADE_IN = 0.1
FxLayer.CONQUEST_FADE_OUT = 0.6
--- the flag's frames in Assets/MapFx (px: `flag` in its colours, `banner` the cloth under it, tinted),
--- how wide it is drawn (full-size tiles) and at least (px) (2026-10-26: 12 and 24, from 22 and 30:
--- the flag was too big)
FxLayer.FLAG = MapFx.flag
FxLayer.BANNER = MapFx.banner
FxLayer.FLAG_FRAME_S = 0.09
FxLayer.FLAG_WORLD = 12
FxLayer.FLAG_MIN_PX = 24
--- a banner colour darker than this (luminance) is lightened toward white by BANNER_LIFT, so the cloth
--- stands out from the flag's dark outline
FxLayer.BANNER_MIN_LUMA = 0.32
FxLayer.BANNER_LIFT = 0.3
FxLayer.GOLD_Y_OFFSET = 8 -- full-size tiles below the name
FxLayer.GOLD_SIZE = 6 -- full-size tiles
FxLayer.GOLD_MIN_PX = 15
FxLayer.GOLD_FONT = Font.fromId(12187365977, Enum.FontWeight.Bold)
--- Income popups: lifetime, rise (full-size tiles a second), where it starts
--- (tiles above the tile), the font (tiles; at least BONUS_MIN_PX on screen), the zoom (px per full-size
--- tile) under which none are drawn, and how many may be up at once.
FxLayer.BONUS_S = 1.5
FxLayer.BONUS_RISE = 3.0
FxLayer.BONUS_Y_OFFSET = -3.0
FxLayer.BONUS_SIZE = 6.0
FxLayer.BONUS_MIN_PX = 13
--- (on a map zoomed far in, 6 tiles of text would fill the screen)
FxLayer.BONUS_MAX_PX = 40
FxLayer.BONUS_CULL_ZOOM = 0.3
FxLayer.BONUS_MAX = 48
--- The explosion sprites, rows of Assets/MapFx: where the row starts in the atlas (x, y), a frame's
--- size, how many frames and how long each shows, how wide it is drawn (full-size tiles) and the least
--- it is drawn on screen (px). (`loop`: the debris, which cycle until their lifetime ends)
local function fx_row(name: string, frame_s: number, world: number, min_px: number, loop: boolean?)
	local r = MapFx[name]
	return {
		x = r.x,
		y = r.y,
		w = r.w,
		h = r.h,
		frames = r.frames,
		frame_s = frame_s,
		world = world,
		min_px = min_px,
		loop = loop,
	}
end
FxLayer.BURSTS = {
	building = fx_row("building", 0.07, 18, 32),
	sam = fx_row("sam", 0.08, 40, 60),
	nuke = fx_row("nuke", 0.07, 60, 36),
	fire = fx_row("fire", 0.1, 7, 4, true),
	smoke = fx_row("smoke", 0.12, 11, 6, true),
	big_smoke = fx_row("big_smoke", 0.12, 24, 12, true),
	smoke_fire = fx_row("smoke_fire", 0.12, 24, 12, true),
}
--- A nuke's look by Defs.N_* (full-size tiles): 70 for an atom bomb, 160 for a hydrogen bomb, 70 a
--- MIRV warhead; the Arsenal's Mega Nuke (a blast between the two) 120, a Scatter
--- bomb an atom's.
FxLayer.NUKE_FX_RADIUS = { [0] = 70, [1] = 160, [3] = 70, [4] = 120, [5] = 70 }
--- (Empires Front 2026-11-06) The siege weapons: a bombard's look is SIEGE_LOOK x its outer radius; fire
--- burns out over FIRE_S once its front passed (FIRE_DENSITY flames a tile of radius, FIRE_SMOKE of
--- them smoky); the plague's cloud is PLAGUE_GREEN, PLAGUE_PUFFS puffs, and a sick nation's capital
--- smokes green every PLAGUE_EVERY_S.
FxLayer.SIEGE_LOOK = 2.4
FxLayer.FIRE_S = 5.0
FxLayer.FIRE_DENSITY = 2.2
FxLayer.FIRE_SMOKE = 0.3
FxLayer.PLAGUE_GREEN = Color3.fromRGB(150, 235, 100)
FxLayer.PLAGUE_PUFFS = 10
FxLayer.PLAGUE_EVERY_S = 1.4
--- The debris a nuke leaves: the sprite, how far out (of the radius) and how many (radius x density)
FxLayer.DEBRIS_PLAN = {
	{ kind = "fire", factor = 1.0, density = 1 / 25 },
	{ kind = "smoke", factor = 1.0, density = 1 / 28 },
	{ kind = "big_smoke", factor = 0.9, density = 1 / 70 },
	{ kind = "smoke_fire", factor = 0.9, density = 1 / 70 },
}
FxLayer.DEBRIS_S = 6.0 -- s each debris sprite lasts
FxLayer.DEBRIS_FADE_IN = 0.1
FxLayer.DEBRIS_FADE_OUT = 0.8
--- Every sprite is a GUI object, and a MIRV's 350 warheads would be some 2,500
--- GUI objects. So at most BURST_MAX explosions and DEBRIS_MAX debris are up at once (the newest
--- wait their turn: none is drawn), and of a strike's warheads about WARHEAD_DEBRIS leave debris,
--- picked at random over all of them (so it is spread over the whole strike).
FxLayer.BURST_MAX = 96
FxLayer.DEBRIS_MAX = 240
FxLayer.WARHEAD_DEBRIS = 28
--- how long a strike's warheads are counted together (s)
FxLayer.WARHEAD_WINDOW_S = 10.0
--- Signals: lifetime, fade-out, the glyph's size and the ring's widest (px), one pulse a PING_PULSE_S,
--- at most PING_MAX up at once, and the colours of "attack here" (1) and "help here" (2).
FxLayer.PING_S = 7.0
FxLayer.PING_FADE_S = 1.5
FxLayer.PING_PX = 26
FxLayer.PING_RING_PX = 54
FxLayer.PING_PULSE_S = 1.0
FxLayer.PING_MAX = 12
FxLayer.PING_COLORS = { Color3.fromRGB(255, 84, 72), Color3.fromRGB(255, 198, 64), Color3.fromRGB(255, 120, 40) }
--- (Empires Front 2026-11-01) A warned province (Core/SimRevolts): kind 3, the unrest colour, up until
--- the revolt is due (FxLayer.unrest); its marker's sender id.
FxLayer.UNREST_FROM = -100

type Fx = { u: number, v: number, r0: number, r1: number, t0: number, dur: number, col: Color3, flash: boolean }
type Pop = { u: number, v: number, t0: number, text: string, col: Color3 }
--- The pools' GUI objects, each with what it was last given (Roblox's own values, kept here: an object
--- shown for another effect still shows them, so nothing needs resetting; `vis` its Visible).
type FxGui = {
	frame: Frame,
	stroke: UIStroke,
	vis: boolean,
	x: number,
	y: number,
	d: number,
	col: Color3?,
	fill_t: number,
	stroke_col: Color3?,
	width: number,
	stroke_t: number,
}
--- (`vis` for all three: they show and hide together)
type PopGui = {
	flag: ImageLabel,
	banner: ImageLabel,
	gold: TextLabel,
	stroke: UIStroke,
	vis: boolean,
	x: number,
	y: number,
	w: number,
	h: number,
	img_t: number,
	flag_ox: number,
	flag_oy: number,
	banner_ox: number,
	banner_oy: number,
	col: Color3?,
	text: string?,
	text_size: number,
	gold_x: number,
	gold_y: number,
	text_t: number,
	width: number,
	stroke_t: number,
}
--- (`life`, `fade_in`, `fade_out`: debris only; a burst ends with its last frame. `col`: a tint (the
--- plague's green); a `t0` still to come: not drawn yet)
type Burst = {
	u: number,
	v: number,
	t0: number,
	row: any,
	life: number?,
	fade_in: number?,
	fade_out: number?,
	col: Color3?,
}
type BurstGui = {
	img: ImageLabel,
	vis: boolean,
	x: number,
	y: number,
	w: number,
	h: number,
	rw: number,
	rh: number,
	ox: number,
	oy: number,
	img_t: number,
	col: Color3?,
}
type Bonus = { u: number, v: number, t0: number, text: string }
type BonusGui = {
	label: TextLabel,
	stroke: UIStroke,
	vis: boolean,
	text: string?,
	size: number,
	x: number,
	y: number,
	text_t: number,
	width: number,
	stroke_t: number,
}

function FxLayer.new(parent: Instance, view: any)
	local self = setmetatable({}, FxLayer) :: any
	local root = Instance.new("Frame")
	root.Name = "Fx"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = FxLayer.Z
	root.Parent = parent
	self.root = root
	self.view = view
	self._state = nil :: any
	self._fx = {} :: { Fx }
	self._frames = {} :: { FxGui }
	self._pops = {} :: { Pop }
	self._pop_gui = {} :: { PopGui }
	self._bursts = {} :: { Burst }
	self._burst_gui = {} :: { BurstGui }
	self._debris = {} :: { Burst }
	self._debris_gui = {} :: { BurstGui }
	--- a strike's warheads: those landed lately (times) and in flight (counted once a frame)
	self._warheads_landed = {} :: { number }
	self._warheads_flying = 0
	self._warheads_counted = -1.0
	self._bonus = {} :: { Bonus }
	self._bonus_gui = {} :: { BonusGui }
	--- Signals: { u, v, t0, kind, name, from } and their pooled GUI
	self._pings = {} :: { any }
	self._ping_gui = {} :: { any }
	-- Fetch the atlas now: a cold download outlasts the 2.5 s conquest popup.
	task.spawn(function()
		if MapFxImage.drawn() then
			return
		end
		pcall(function()
			ContentProvider:PreloadAsync({ MapFx.id })
		end)
	end)
	return self
end

function FxLayer.bind(self: any, state: any)
	self._state = state
	table.clear(self._fx)
	table.clear(self._pops)
	table.clear(self._bursts)
	table.clear(self._debris)
	table.clear(self._warheads_landed)
	table.clear(self._bonus)
	table.clear(self._pings)
end

function FxLayer.unbind(self: any)
	self._state = nil
	table.clear(self._fx)
	table.clear(self._pops)
	table.clear(self._bursts)
	table.clear(self._debris)
	table.clear(self._warheads_landed)
	table.clear(self._bonus)
	table.clear(self._pings)
	for _, g in self._ping_gui do
		g.vis = false
		g.root.Visible = false
	end
	for _, g in self._frames do
		g.vis = false
		g.frame.Visible = false
	end
	for _, g in self._bonus_gui do
		g.vis = false
		g.label.Visible = false
	end
	for _, g in self._burst_gui do
		g.vis = false
		g.img.Visible = false
	end
	for _, g in self._debris_gui do
		g.vis = false
		g.img.Visible = false
	end
	for _, g in self._pop_gui do
		g.vis = false
		g.flag.Visible = false
		g.banner.Visible = false
		g.gold.Visible = false
	end
end

function FxLayer.destroy(self: any)
	self:unbind()
	self.root:Destroy()
end

local function add(self: any, tile: number, r0: number, r1: number, dur: number, col: Color3, flash: boolean)
	local st = self._state
	if st == nil or tile < 0 then
		return
	end
	local W = st.map.W or Defs.W
	table.insert(self._fx, {
		u = tile % W + 0.5,
		v = tile // W + 0.5,
		r0 = r0,
		r1 = r1,
		t0 = FrameClock.now(),
		dur = dur,
		col = col,
		flash = flash,
	})
end

--- 32-bit multiply, low 32 bits (Math.imul, unsigned)
local function imul(a: number, b: number): number
	local ah, al = a // 65536, a % 65536
	return ((ah * b) % 65536 * 65536 + al * b) % 4294967296
end

--- mulberry32: a float in [0, 1) from an integer seed.
function FxLayer.seeded_random(seed: number): number
	local s = (seed + 0x6d2b79f5) % 4294967296
	local t = imul(bit32.bxor(s, bit32.rshift(s, 15)), bit32.bor(1, s))
	t = bit32.bxor((t + imul(bit32.bxor(t, bit32.rshift(t, 7)), bit32.bor(61, t))) % 4294967296, t)
	return bit32.bxor(t, bit32.rshift(t, 14)) / 4294967296
end

--- The debris a nuke leaves: map positions (offsets from the tile in full-size tiles, divided
--- by k) and sprites, for a nuke of look radius `radius` (full-size tiles) at `tile`.
function FxLayer.debris_plan(tile: number, radius: number, k: number): { { kind: string, du: number, dv: number } }
	local out = {}
	local idx = 0
	for _, d in FxLayer.DEBRIS_PLAN do
		local count = math.max(0, math.floor(radius * d.density))
		local r = radius * d.factor
		for _ = 1, count do
			local seed = tile * 997 + idx
			idx += 1
			local angle = FxLayer.seeded_random(seed) * math.pi * 2
			local dist = FxLayer.seeded_random(seed + 0x10000) * (r / 2)
			-- (Math.floor of the offsets in full-size tiles)
			table.insert(out, {
				kind = d.kind,
				du = math.floor(math.cos(angle) * dist) / k,
				dv = math.floor(math.sin(angle) * dist) / k,
			})
		end
	end
	return out
end

--- Whether this warhead leaves debris: about WARHEAD_DEBRIS of a strike's do, picked by its tile.
function FxLayer._warhead_debris(self: any, tile: number): boolean
	local st = self._state
	local now = FrameClock.now()
	local landed = self._warheads_landed
	while #landed > 0 and now - landed[1] > FxLayer.WARHEAD_WINDOW_S do
		table.remove(landed, 1)
	end
	table.insert(landed, now)
	if self._warheads_counted ~= now then
		self._warheads_counted = now
		local n = 0
		for _, m in st.nukes do
			if m.kind == Defs.N_WARHEAD then
				n += 1
			end
		end
		self._warheads_flying = n
	end
	local p = FxLayer.WARHEAD_DEBRIS / math.max(1, #landed + self._warheads_flying)
	return FxLayer.seeded_random(tile * 31 + 7) < p
end

--- GameState.nuke_detonated(uid, kind, tile, radius, owner).
function FxLayer.nuke(self: any, kind: number, tile: number, radius: number)
	-- a MIRV splitting into its warheads: nothing (no look radius of its own; a
	-- flash its spread wide whitened the screen)
	if kind == Defs.N_MIRV then
		return
	end
	local r = radius
	local VR = self.view.view_rules
	if VR then
		local _, outer = VR.nuke_radii(kind)
		if outer > 0 then
			r = outer
		end
	end
	-- a strike (a shell, an air strike, a slug; Data/Arsenal) is a small burst: no flash, no shake
	-- for a shell, a nudge for the others
	if Rules.NUKE_FLAT ~= nil and Rules.NUKE_FLAT[kind] then
		local col = if kind == Defs.N_SLUG then Color3.new(0.75, 0.6, 1) else Color3.new(1, 0.72, 0.35)
		add(self, tile, 0, math.max(r, 2.5) * 1.15, if kind == Defs.N_SHELL then 0.45 else 0.8, col, false)
		if kind ~= Defs.N_SHELL then
			local cam = self.view.rig
			local x, y = cam:tile_to_screen(tile)
			if cam:on_screen(x, y, 200) then
				cam:add_shake(0.25)
			end
		end
		return
	end
	local st = self._state
	local k = tonumber(st and st.map and st.map.k_lin) or Rules.K_LIN
	-- (Empires Front 2026-11-06) the plague: a green cloud; fire: a flash, its front does the rest
	-- (FxLayer.blaze); a bombard: a blast its own size
	if kind == Defs.N_PLAGUE then
		self:plague_cloud(tile, FxLayer.PLAGUE_PUFFS, 6.0)
		add(self, tile, 0, 10 / k, 0.9, FxLayer.PLAGUE_GREEN, false)
		return
	elseif kind == Defs.N_HYDROGEN then
		add(self, tile, 0, math.max(r, 4) * 0.6, 0.6, Color3.new(1, 0.6, 0.25), false)
		local W = if st ~= nil then st.map.W or Defs.W else Defs.W
		self:burst("nuke", tile % W + 0.5, tile // W + 0.5)
		return
	end
	local look = FxLayer.NUKE_FX_RADIUS[kind]
	if kind == Defs.N_ATOM then
		look = r * k * FxLayer.SIEGE_LOOK
	end
	-- (a warhead's ring without the flash: 350 flashes a look radius
	-- wide whiten the screen)
	add(
		self,
		tile,
		0,
		(if look then look / k else r) * FxLayer.NUKE_SHOCK_K,
		FxLayer.NUKE_SHOCK_S,
		Color3.new(1, 0.92, 0.75),
		kind ~= Defs.N_WARHEAD
	)
	if st ~= nil and look ~= nil and tile >= 0 then
		local W = st.map.W or Defs.W
		local u, v = tile % W + 0.5, tile // W + 0.5
		self:burst("nuke", u, v)
		if kind ~= Defs.N_WARHEAD or self:_warhead_debris(tile) then
			local now = FrameClock.now()
			for _, d in FxLayer.debris_plan(tile, look, k) do
				if #self._debris >= FxLayer.DEBRIS_MAX then
					break
				end
				table.insert(self._debris, {
					u = u + d.du,
					v = v + d.dv,
					t0 = now,
					row = FxLayer.BURSTS[d.kind],
					life = FxLayer.DEBRIS_S,
					fade_in = FxLayer.DEBRIS_FADE_IN,
					fade_out = FxLayer.DEBRIS_FADE_OUT,
				})
			end
		end
	end
	local cam = self.view.rig
	local x, y = cam:tile_to_screen(tile)
	if cam:on_screen(x, y, 200) then
		cam:add_shake(if kind == Defs.N_HYDROGEN or kind == Defs.N_MEGA then 0.9 elseif kind == Defs.N_ATOM then 0.35 else 0.5)
	end
end

--- (Empires Front 2026-11-06) Fire spreading from `tile` to `radius` tiles over `spread_s`: flames
--- light up where its front passes and burn for FIRE_S.
function FxLayer.blaze(self: any, tile: number, radius: number, spread_s: number, uid: number)
	local st = self._state
	if st == nil or tile < 0 then
		return
	end
	local W = st.map.W or Defs.W
	local u0, v0 = tile % W + 0.5, tile // W + 0.5
	local now = FrameClock.now()
	local count = math.floor(radius * FxLayer.FIRE_DENSITY) + 6
	for i = 1, count do
		if #self._debris >= FxLayer.DEBRIS_MAX then
			break
		end
		local seed = uid * 7919 + i
		local ang = FxLayer.seeded_random(seed) * math.pi * 2
		local d = math.sqrt(FxLayer.seeded_random(seed + 0x10000)) * radius
		local smoky = FxLayer.seeded_random(seed + 0x20000) < FxLayer.FIRE_SMOKE
		table.insert(self._debris, {
			u = u0 + math.cos(ang) * d,
			v = v0 + math.sin(ang) * d,
			t0 = now + spread_s * d / math.max(radius, 1),
			row = FxLayer.BURSTS[if smoky then "smoke_fire" else "fire"],
			life = FxLayer.FIRE_S,
			fade_in = 0.08,
			fade_out = 0.7,
		})
	end
end

--- (Empires Front 2026-11-06) `n` puffs of the plague's green cloud around `tile`, for `life` seconds.
function FxLayer.plague_cloud(self: any, tile: number, n: number, life: number)
	local st = self._state
	if st == nil or tile < 0 then
		return
	end
	local W = st.map.W or Defs.W
	local u0, v0 = tile % W + 0.5, tile // W + 0.5
	local now = FrameClock.now()
	self._plague_seq = (self._plague_seq or 0) + 1
	for i = 1, n do
		if #self._debris >= FxLayer.DEBRIS_MAX then
			break
		end
		local seed = self._plague_seq * 104729 + i
		local ang = FxLayer.seeded_random(seed) * math.pi * 2
		local d = FxLayer.seeded_random(seed + 0x10000) * 7
		table.insert(self._debris, {
			u = u0 + math.cos(ang) * d,
			v = v0 + math.sin(ang) * d,
			t0 = now + FxLayer.seeded_random(seed + 0x30000) * 0.8,
			row = FxLayer.BURSTS[if i % 3 == 0 then "smoke" else "big_smoke"],
			life = life,
			fade_in = 0.15,
			fade_out = 0.6,
			col = FxLayer.PLAGUE_GREEN,
		})
	end
end

--- (Empires Front 2026-11-06) The sick nations' capitals give off the plague's green, now and then.
function FxLayer._plague_tick(self: any, now: number)
	local st = self._state
	if st == nil or st.plague == nil or next(st.plague) == nil then
		return
	end
	if now - (self._plague_at or 0) < FxLayer.PLAGUE_EVERY_S then
		return
	end
	self._plague_at = now
	for id, p in st.plague do
		if p.until_tick > st.tick then
			local o = st:get_owner(id)
			local t = if o ~= nil then tonumber(o.spawn_tile) or -1 else -1
			if t >= 0 and st:tile_owner(t) == id then
				self:plague_cloud(t, 2, 3.5)
			end
		end
	end
end

--- A ship destroyed / a nuke shot down at `tile`.
function FxLayer.pop(self: any, tile: number, col: Color3?)
	local st = self._state
	local k = tonumber(st and st.map and st.map.k_lin) or Rules.K_LIN
	add(self, tile, 0, FxLayer.POP_RADIUS / k * 0.25, FxLayer.POP_S, col or Color3.new(1, 0.6, 0.25), false)
end

--- An explosion sprite (BURSTS) at map position (u, v) (tile + 0.5 is the tile's centre).
function FxLayer.burst(self: any, kind: string, u: number, v: number)
	local row = FxLayer.BURSTS[kind]
	if self._state == nil or row == nil or #self._bursts >= FxLayer.BURST_MAX then
		return
	end
	table.insert(self._bursts, { u = u, v = v, t0 = FrameClock.now(), row = row })
end

--- GameState.structure_removed (the structure is still in the state): the ones a capture destroys go
--- up in a small explosion (Sim._struct_tile_changed: a defense post, the Arsenal's structures).
function FxLayer.on_structure_removed(self: any, sid: number)
	local st = self._state
	local s = if st ~= nil then st.structures[sid] else nil
	if s == nil or not (s.kind == Defs.S_DEFENSE or s.kind >= Defs.S_ARTILLERY) then
		return
	end
	local W = st.map.W or Defs.W
	local k = tonumber(st.map.k_lin) or Rules.K_LIN
	self:burst("building", s.tile % W + 0.5, s.tile // W + 0.5)
	add(self, s.tile, 0, 14 / k, 0.5, Color3.new(1, 0.7, 0.3), false)
end

--- Gold as a popup shows it: one decimal K / M (halves round up), whole numbers
--- below 1,000.
function FxLayer.format_gold(gold: number): string
	local function fixed1(v: number): string
		return string.format("%.1f", math.floor(v * 10 + 0.5) / 10)
	end
	if gold >= 1_000_000 then
		return fixed1(gold / 1_000_000) .. "M"
	elseif gold >= 1_000 then
		return fixed1(gold / 1_000) .. "K"
	end
	return tostring(math.floor(gold))
end

--- The local player conquered someone whose name sat at map tile (u, v) and took `gold`.
--- The banner's tint for an owner's colour: the colour, lightened when it is too dark to show.
function FxLayer.banner_color(c: any): Color3
	if typeof(c) ~= "Color3" then
		return Color3.new(1, 1, 1)
	end
	local luma = c.R * 0.299 + c.G * 0.587 + c.B * 0.114
	return if luma < FxLayer.BANNER_MIN_LUMA then c:Lerp(Color3.new(1, 1, 1), FxLayer.BANNER_LIFT) else c
end

function FxLayer.conquest(self: any, u: number, v: number, gold: number)
	if self._state == nil then
		return
	end
	table.insert(self._pops, {
		u = u,
		v = v,
		t0 = FrameClock.now(),
		text = "+ " .. FxLayer.format_gold(gold),
		col = FxLayer.banner_color(self._state:owner_color(self._state.local_owner)),
	})
end

--- The local player earned `gold` at `tile` (GameState.bonus: a train of theirs stopped at a station,
--- or someone's train at a station of theirs).
function FxLayer.bonus(self: any, tile: number, gold: number)
	local st = self._state
	if st == nil or tile < 0 or gold <= 0 then
		return
	end
	local W = st.map.W or Defs.W
	local list = self._bonus
	if #list >= FxLayer.BONUS_MAX then
		table.remove(list, 1)
	end
	table.insert(list, {
		u = tile % W + 0.5,
		v = tile // W + 0.5,
		t0 = FrameClock.now(),
		text = "+ " .. FxLayer.format_gold(gold),
	})
end

--- Drop a list's entries from n + 1 on (the spent ones were left behind as the live ones moved up).
local function truncate(list: { any }, n: number)
	for i = #list, n + 1, -1 do
		list[i] = nil
	end
end

--- A Signal from owner `from` at `tile` (kind 1: attack here, 2: help here). GameState.pinged.
function FxLayer.ping(self: any, from: number, tile: number, kind: number)
	local st = self._state
	if st == nil or tile < 0 then
		return
	end
	local W = st.map.W or Defs.W
	local list = self._pings
	-- (a sender's new Signal replaces its old one)
	for i = #list, 1, -1 do
		if list[i].from == from then
			table.remove(list, i)
		end
	end
	if #list >= FxLayer.PING_MAX then
		table.remove(list, 1)
	end
	local name = if from == st.local_owner then "You" else st:owner_name(from)
	table.insert(list, {
		u = tile % W + 0.5,
		v = tile // W + 0.5,
		t0 = FrameClock.now(),
		kind = if kind == 2 then 2 else 1,
		name = tostring(name or ""),
		from = from,
	})
end

--- (Empires Front) A warned province at `tile`: a pulsing marker named `text` for `seconds` (one at a
--- time; nil `tile` or -1 takes it down).
function FxLayer.unrest(self: any, tile: number?, seconds: number?, text: string?)
	local st = self._state
	local list = self._pings
	for i = #list, 1, -1 do
		if list[i].from == FxLayer.UNREST_FROM then
			table.remove(list, i)
		end
	end
	if st == nil or tile == nil or tile < 0 or (seconds or 0) <= 0 then
		return
	end
	local W = st.map.W or Defs.W
	table.insert(list, {
		u = tile % W + 0.5,
		v = tile // W + 0.5,
		t0 = FrameClock.now(),
		kind = 3,
		name = tostring(text or "Unrest"),
		from = FxLayer.UNREST_FROM,
		dur = math.max(seconds :: number, FxLayer.PING_FADE_S),
	})
end

local function ping_gui(self: any, n: number): any
	local g = self._ping_gui[n]
	if g ~= nil then
		return g
	end
	local root = Instance.new("Frame")
	root.Name = "Signal"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Size = UDim2.fromOffset(FxLayer.PING_RING_PX, FxLayer.PING_RING_PX)
	root.ZIndex = FxLayer.Z + 3
	root.Parent = self.root
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.ZIndex = FxLayer.Z + 3
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = ring
	ring.Parent = root
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.fromOffset(FxLayer.PING_PX + 8, FxLayer.PING_PX + 8)
	plate.BackgroundColor3 = Color3.fromRGB(16, 18, 28)
	plate.BackgroundTransparency = 0.2
	plate.ZIndex = FxLayer.Z + 4
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0.5, 0)
	pc.Parent = plate
	local ps = Instance.new("UIStroke")
	ps.Thickness = 2
	ps.Parent = plate
	plate.Parent = root
	local icon = Instance.new("ImageLabel")
	icon.Name = "Glyph"
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(FxLayer.PING_PX - 6, FxLayer.PING_PX - 6)
	icon.ZIndex = FxLayer.Z + 5
	icon.Parent = plate
	local label = Instance.new("TextLabel")
	label.Name = "From"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0.5, FxLayer.PING_PX // 2 + 8)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.FontFace = FxLayer.GOLD_FONT
	label.TextSize = 13
	label.TextColor3 = Color3.new(1, 1, 1)
	label.ZIndex = FxLayer.Z + 5
	local ls = Instance.new("UIStroke")
	ls.Color = Color3.new(0, 0, 0)
	ls.Thickness = 1.5
	ls.Parent = label
	label.Parent = root
	g = {
		root = root,
		ring = ring,
		ring_stroke = stroke,
		plate = plate,
		plate_stroke = ps,
		icon = icon,
		label = label,
		label_stroke = ls,
		vis = true,
		kind = 0,
		text = nil,
	}
	self._ping_gui[n] = g
	return g
end

local function pings_step(self: any, cam: any, now: number)
	local list = self._pings
	local keep, n = 0, 0
	for i = 1, #list do
		local p = list[i]
		local el = now - p.t0
		local life = p.dur or FxLayer.PING_S
		if el >= life then
			continue
		end
		keep += 1
		list[keep] = p
		local x, y = cam:map_to_screen(p.u, p.v)
		if not cam:on_screen(x, y, FxLayer.PING_RING_PX) then
			continue
		end
		n += 1
		local g = ping_gui(self, n)
		if not g.vis then
			g.vis = true
			g.root.Visible = true
		end
		local col = FxLayer.PING_COLORS[p.kind] or FxLayer.PING_COLORS[1]
		if g.kind ~= p.kind then
			g.kind = p.kind
			pcall(PixelIcons.apply, g.icon, if p.kind == 2 then "ping_help" elseif p.kind == 3 then "ping" else "ping_target")
			g.icon.ImageColor3 = col
			g.ring_stroke.Color = col
			g.plate_stroke.Color = col
		end
		if g.text ~= p.name then
			g.text = p.name
			g.label.Text = p.name
		end
		g.root.Position = UDim2.fromOffset(x, y)
		-- fades over the last PING_FADE_S; the ring pulses out from the plate and fades as it grows
		local fade = math.clamp((life - el) / FxLayer.PING_FADE_S, 0, 1)
		local ph = (el % FxLayer.PING_PULSE_S) / FxLayer.PING_PULSE_S
		local d = FxLayer.PING_PX + (FxLayer.PING_RING_PX - FxLayer.PING_PX) * ph
		g.ring.Size = UDim2.fromOffset(d, d)
		g.ring_stroke.Transparency = 1 - (1 - ph) * fade
		local t = 1 - fade
		g.icon.ImageTransparency = t
		g.plate.BackgroundTransparency = 0.2 + 0.8 * t
		g.plate_stroke.Transparency = t
		g.label.TextTransparency = t
		g.label_stroke.Transparency = t
	end
	truncate(list, keep)
	for j = n + 1, #self._ping_gui do
		local g = self._ping_gui[j]
		if g.vis then
			g.vis = false
			g.root.Visible = false
		end
	end
end

local function bonus_step(self: any, cam: any, now: number)
	local st = self._state
	local k = tonumber(st and st.map and st.map.k_lin) or Rules.K_LIN
	local zoom = cam.scale / k -- px per full-size tile
	local n = 0
	local list = self._bonus
	local keep = 0
	for i = 1, #list do
		local b = list[i]
		local el = now - b.t0
		if el >= FxLayer.BONUS_S then
			continue
		end
		keep += 1
		list[keep] = b
		if zoom < FxLayer.BONUS_CULL_ZOOM then
			continue
		end
		local fs = math.clamp(FxLayer.BONUS_SIZE * zoom, FxLayer.BONUS_MIN_PX, FxLayer.BONUS_MAX_PX)
		-- (offset and rise are in tiles; under the minimum size they keep pace with the text)
		local unit = fs / FxLayer.BONUS_SIZE
		local x, y = cam:map_to_screen(b.u, b.v)
		y += (FxLayer.BONUS_Y_OFFSET - FxLayer.BONUS_RISE * el) * unit
		if not cam:on_screen(x, y, fs * 4) then
			continue
		end
		n += 1
		local g = self._bonus_gui[n]
		if g == nil then
			local label = Instance.new("TextLabel")
			label.Name = "Income"
			label.BackgroundTransparency = 1
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.AutomaticSize = Enum.AutomaticSize.XY
			label.Size = UDim2.fromOffset(0, 0)
			label.FontFace = FxLayer.GOLD_FONT
			label.TextColor3 = Color3.new(1, 1, 1)
			label.ZIndex = FxLayer.Z + 1
			label.Parent = self.root
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.new(0, 0, 0)
			stroke.LineJoinMode = Enum.LineJoinMode.Round
			stroke.Parent = label
			g = {
				label = label,
				stroke = stroke,
				vis = true,
				text = nil,
				size = -1,
				x = math.huge,
				y = math.huge,
				text_t = -1,
				width = -1,
				stroke_t = -1,
			}
			self._bonus_gui[n] = g
		end
		local t = el / FxLayer.BONUS_S
		local label = g.label
		if not g.vis then
			g.vis = true
			label.Visible = true
		end
		-- (the text and its size seldom change: each write of them makes Roblox measure the text again)
		if g.text ~= b.text then
			g.text = b.text
			label.Text = b.text
		end
		if g.size ~= fs then
			g.size = fs
			label.TextSize = fs
		end
		if g.x ~= x or g.y ~= y then
			g.x, g.y = x, y
			label.Position = UDim2.fromOffset(x, y)
		end
		if g.text_t ~= t then
			g.text_t = t
			label.TextTransparency = t
		end
		local width = math.max(1.5, fs * 0.12)
		if g.width ~= width then
			g.width = width
			g.stroke.Thickness = width
		end
		if g.stroke_t ~= t then
			g.stroke_t = t
			g.stroke.Transparency = t
		end
	end
	truncate(list, keep)
	for j = n + 1, #self._bonus_gui do
		local g = self._bonus_gui[j]
		if g.vis then
			g.vis = false
			g.label.Visible = false
		end
	end
end

local function pop_gui(self: any, n: number): PopGui
	local g = self._pop_gui[n]
	if g ~= nil then
		return g
	end
	-- (the cloth and the flag never share a pixel: their order doesn't matter)
	local function layer(name: string, row: any): ImageLabel
		local l = Instance.new("ImageLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		MapFxImage.apply(l)
		l.ImageRectSize = Vector2.new(row.w, row.h)
		l.ResampleMode = Enum.ResamplerMode.Pixelated
		l.ZIndex = FxLayer.Z
		l.Parent = self.root
		return l
	end
	local banner = layer("ConquestBanner", FxLayer.BANNER)
	local flag = layer("Conquest", FxLayer.FLAG)
	local gold = Instance.new("TextLabel")
	gold.Name = "ConquestGold"
	gold.BackgroundTransparency = 1
	gold.AnchorPoint = Vector2.new(0.5, 0.5)
	gold.AutomaticSize = Enum.AutomaticSize.XY
	gold.Size = UDim2.fromOffset(0, 0)
	gold.FontFace = FxLayer.GOLD_FONT
	gold.TextColor3 = Color3.new(1, 1, 1)
	gold.ZIndex = FxLayer.Z + 1
	gold.Parent = self.root
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = gold
	g = {
		flag = flag,
		banner = banner,
		gold = gold,
		stroke = stroke,
		vis = true,
		x = math.huge,
		y = math.huge,
		w = -1,
		h = -1,
		img_t = -1,
		flag_ox = -1,
		flag_oy = -1,
		banner_ox = -1,
		banner_oy = -1,
		col = nil,
		text = nil,
		text_size = -1,
		gold_x = math.huge,
		gold_y = math.huge,
		text_t = -1,
		width = -1,
		stroke_t = -1,
	}
	self._pop_gui[n] = g
	return g :: PopGui
end

local function pops_step(self: any, cam: any, now: number)
	local st = self._state
	local k = tonumber(st and st.map and st.map.k_lin) or Rules.K_LIN
	local n = 0
	local list = self._pops
	local keep = 0
	for i = 1, #list do
		local p = list[i]
		local el = now - p.t0
		if el >= FxLayer.CONQUEST_S then
			continue
		end
		keep += 1
		list[keep] = p
		local x, y = cam:map_to_screen(p.u, p.v)
		local sw = math.max(FxLayer.FLAG_MIN_PX, FxLayer.FLAG_WORLD / k * cam.scale)
		if not cam:on_screen(x, y, sw * 2) then
			continue
		end
		n += 1
		local g = pop_gui(self, n)
		local t = el / FxLayer.CONQUEST_S
		local a = 1.0
		if t < FxLayer.CONQUEST_FADE_IN then
			a = t / FxLayer.CONQUEST_FADE_IN
		elseif t > FxLayer.CONQUEST_FADE_OUT then
			a = (1 - t) / (1 - FxLayer.CONQUEST_FADE_OUT)
		end
		local F, B = FxLayer.FLAG, FxLayer.BANNER
		local frame = math.min(math.floor(el / FxLayer.FLAG_FRAME_S), F.frames - 1)
		local flag, banner = g.flag, g.banner
		-- the flag and its cloth: one place, size and fade
		if not g.vis then
			g.vis = true
			flag.Visible = true
			banner.Visible = true
			g.gold.Visible = true
		end
		if g.x ~= x or g.y ~= y then
			g.x, g.y = x, y
			local pos = UDim2.fromOffset(x, y)
			flag.Position = pos
			banner.Position = pos
		end
		local sh = sw * F.h / F.w
		if g.w ~= sw or g.h ~= sh then
			g.w, g.h = sw, sh
			local size = UDim2.fromOffset(sw, sh)
			flag.Size = size
			banner.Size = size
		end
		local img_t = 1 - a
		if g.img_t ~= img_t then
			g.img_t = img_t
			flag.ImageTransparency = img_t
			banner.ImageTransparency = img_t
		end
		local fox, foy = F.x + frame * F.w, F.y
		if g.flag_ox ~= fox or g.flag_oy ~= foy then
			g.flag_ox, g.flag_oy = fox, foy
			flag.ImageRectOffset = Vector2.new(fox, foy)
		end
		local box, boy = B.x + frame * B.w, B.y
		if g.banner_ox ~= box or g.banner_oy ~= boy then
			g.banner_ox, g.banner_oy = box, boy
			banner.ImageRectOffset = Vector2.new(box, boy)
		end
		if g.col ~= p.col then
			g.col = p.col
			banner.ImageColor3 = p.col
		end
		local fs = math.max(FxLayer.GOLD_MIN_PX, FxLayer.GOLD_SIZE / k * cam.scale)
		-- GOLD_Y_OFFSET's 8 tiles scaled with the flag; its mound ends 0.42 of the sprite below its
		-- centre, so the line never overlaps it when the minimum sizes apply
		local gy = math.max(sw * FxLayer.GOLD_Y_OFFSET / FxLayer.FLAG_WORLD, sw * 0.42 + fs * 0.5)
		local gold = g.gold
		if g.text ~= p.text then
			g.text = p.text
			gold.Text = p.text
		end
		local ts = math.min(fs, 100)
		if g.text_size ~= ts then
			g.text_size = ts
			gold.TextSize = ts
		end
		if g.gold_x ~= x or g.gold_y ~= y + gy then
			g.gold_x, g.gold_y = x, y + gy
			gold.Position = UDim2.fromOffset(x, y + gy)
		end
		if g.text_t ~= t then
			g.text_t = t
			gold.TextTransparency = t
		end
		local width = math.max(1.5, fs * 0.12)
		if g.width ~= width then
			g.width = width
			g.stroke.Thickness = width
		end
		if g.stroke_t ~= t then
			g.stroke_t = t
			g.stroke.Transparency = t
		end
	end
	truncate(list, keep)
	for j = n + 1, #self._pop_gui do
		local g = self._pop_gui[j]
		if g.vis then
			g.vis = false
			g.flag.Visible = false
			g.banner.Visible = false
			g.gold.Visible = false
		end
	end
end

--- Draw a list of bursts (or debris) with its pool; a looping one runs until its `life`, fading.
local function bursts_step(self: any, cam: any, now: number, list: { Burst }, pool: { BurstGui }, z: number)
	local st = self._state
	local k = tonumber(st and st.map and st.map.k_lin) or Rules.K_LIN
	local n = 0
	local keep = 0
	-- (MapCamera.map_to_screen and on_screen worked out here, the same sums: a nuke's debris are
	-- hundreds of sprites, each projected every frame, and a phone runs Luau without native code)
	local ax, ay = cam:anchor()
	local sc, cu, cv = cam.scale, cam.cu, cam.cv
	local vp = cam:viewport_size()
	local vw, vh = vp.X, vp.Y
	for i = 1, #list do
		local b = list[i]
		local row = b.row
		local el = now - b.t0
		if el < 0 then
			-- (Empires Front: a spreading fire's flames, not reached yet)
			keep += 1
			list[keep] = b
			continue
		end
		local frame = math.floor(el / row.frame_s)
		local a = 1.0
		if b.life ~= nil then
			if el >= b.life then
				continue
			end
			if row.loop then
				frame %= row.frames
			end
			local t = el / b.life
			if t < (b.fade_in or 0) then
				a = t / b.fade_in
			elseif t > (b.fade_out or 1) then
				a = (1 - t) / (1 - b.fade_out)
			end
		elseif frame >= row.frames then
			continue
		end
		keep += 1
		list[keep] = b
		local x, y = ax + (b.u - cu) * sc, ay + (b.v - cv) * sc
		local w = math.max(row.min_px, row.world / k * sc)
		if not (x >= -w and y >= -w and x <= vw + w and y <= vh + w) then
			continue
		end
		n += 1
		local g = pool[n]
		if g == nil then
			local img = Instance.new("ImageLabel")
			img.Name = "Explosion"
			img.BackgroundTransparency = 1
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			MapFxImage.apply(img)
			img.ResampleMode = Enum.ResamplerMode.Pixelated
			img.ZIndex = z
			img.Parent = self.root
			g = {
				img = img,
				vis = true,
				x = math.huge,
				y = math.huge,
				w = -1,
				h = -1,
				rw = -1,
				rh = -1,
				ox = -1,
				oy = -1,
				img_t = -1,
			}
			pool[n] = g
		end
		-- (debris sit still between their frames, full strength mid-life: mostly nothing to write)
		local img = g.img
		if not g.vis then
			g.vis = true
			img.Visible = true
		end
		if g.x ~= x or g.y ~= y then
			g.x, g.y = x, y
			img.Position = UDim2.fromOffset(x, y)
		end
		local h = w * row.h / row.w
		if g.w ~= w or g.h ~= h then
			g.w, g.h = w, h
			img.Size = UDim2.fromOffset(w, h)
		end
		if g.rw ~= row.w or g.rh ~= row.h then
			g.rw, g.rh = row.w, row.h
			img.ImageRectSize = Vector2.new(row.w, row.h)
		end
		local ox, oy = (row.x or 0) + frame * row.w, row.y
		if g.ox ~= ox or g.oy ~= oy then
			g.ox, g.oy = ox, oy
			img.ImageRectOffset = Vector2.new(ox, oy)
		end
		local img_t = 1 - a
		if g.img_t ~= img_t then
			g.img_t = img_t
			img.ImageTransparency = img_t
		end
		local col = b.col or WHITE
		if g.col ~= col then
			g.col = col
			img.ImageColor3 = col
		end
	end
	truncate(list, keep)
	for j = n + 1, #pool do
		local g = pool[j]
		if g.vis then
			g.vis = false
			g.img.Visible = false
		end
	end
end

function FxLayer.tick(self: any, _dt: number)
	local cam = self.view.rig
	local now = FrameClock.now()
	self:_plague_tick(now)
	local n = 0
	local list = self._fx
	local keep = 0
	for i = 1, #list do
		local fx = list[i]
		local t = (now - fx.t0) / fx.dur
		if t >= 1 then
			continue
		end
		keep += 1
		list[keep] = fx
		local x, y = cam:map_to_screen(fx.u, fx.v)
		local e = 1 - (1 - t) ^ 3
		local r = (fx.r0 + (fx.r1 - fx.r0) * e) * cam.scale
		if not cam:on_screen(x, y, r) then
			continue
		end
		n += 1
		local g = self._frames[n]
		if g == nil then
			local f = Instance.new("Frame")
			f.Name = "Fx"
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.BorderSizePixel = 0
			f.ZIndex = FxLayer.Z
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = f
			-- (kept with the frame: it was looked up among the frame's children every frame)
			local s = Instance.new("UIStroke")
			s.Parent = f
			f.Parent = self.root
			g = {
				frame = f,
				stroke = s,
				vis = true,
				x = math.huge,
				y = math.huge,
				d = -1,
				col = nil,
				fill_t = -1,
				stroke_col = nil,
				width = -1,
				stroke_t = -1,
			}
			self._frames[n] = g
		end
		local f, s = g.frame, g.stroke
		if not g.vis then
			g.vis = true
			f.Visible = true
		end
		if g.x ~= x or g.y ~= y then
			g.x, g.y = x, y
			f.Position = UDim2.fromOffset(x, y)
		end
		if g.d ~= r * 2 then
			g.d = r * 2
			f.Size = UDim2.fromOffset(r * 2, r * 2)
		end
		if g.col ~= fx.col then
			g.col = fx.col
			f.BackgroundColor3 = fx.col
		end
		-- the flash fills the disc early on; the ring stays
		local fill_t = if fx.flash then math.clamp(0.25 + t * 3, 0, 1) else 0.8 + 0.2 * t
		if g.fill_t ~= fill_t then
			g.fill_t = fill_t
			f.BackgroundTransparency = fill_t
		end
		if g.stroke_col ~= fx.col then
			g.stroke_col = fx.col
			s.Color = fx.col
		end
		local width = math.max(1.5, r * 0.04)
		if g.width ~= width then
			g.width = width
			s.Thickness = width
		end
		if g.stroke_t ~= t then
			g.stroke_t = t
			s.Transparency = t
		end
	end
	truncate(list, keep)
	for j = n + 1, #self._frames do
		local g = self._frames[j]
		if g.vis then
			g.vis = false
			g.frame.Visible = false
		end
	end
	pops_step(self, cam, now)
	bursts_step(self, cam, now, self._bursts, self._burst_gui, FxLayer.Z + 1)
	-- (the debris over the fireball, pushed after it)
	bursts_step(self, cam, now, self._debris, self._debris_gui, FxLayer.Z + 2)
	bonus_step(self, cam, now)
	if #self._pings > 0 or #self._ping_gui > 0 then
		pings_step(self, cam, now)
	end
end

return FxLayer
