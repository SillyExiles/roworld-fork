--!nonstrict
-- (Empires Front 2026-11-01) The title's "support the game" card, under the party: favorite the game
-- (and leave a like) for SupportCard.STARS Stars, once per account. FAVORITE opens Roblox's own
-- favorite prompt; when it says yes the server pays (OP.FAVORITED → server/Purchases.favorite_bonus)
-- and the card goes for good (INVENTORY.fav_paid). A like can't be seen by a game, so it is only asked.
--   SupportCard.new(ctx) · apply_layout(party) · refresh(on_title)
-- Phones: one gold button under the PARTY button.

local AvatarEditorService = game:GetService("AvatarEditorService")
local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")

local SupportCard = W.class(W.Control)

SupportCard.WIDTH = 250.0
--- (shown; server/Purchases.FAVORITE_STARS pays it)
SupportCard.STARS = 1000
--- The gap under the party panel.
SupportCard.GAP = 10.0

function SupportCard.new(c: any)
	local self = setmetatable({}, SupportCard.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self._asking = false
	self._sent = false
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)

	local p = GlassPanel.new(14.0, 12.0, 14, true, 24)
	self._panel = p
	self:add_child(p)
	local v = T.vbox(8)
	p:add_child(v)
	local head = T.hbox(8)
	local ic = T.icon_rect("star", 18.0, T.AMBER)
	ic.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(ic)
	local title = T.label("SUPPORT THE GAME", 14, 800, T.TEXT, 2)
	title.size_flags_horizontal = W.EXPAND_FILL
	title.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(title)
	v:add_child(head)
	local text = T.label("Favorite Empires Front and leave a Like to help it grow!", 11, 500, T.TEXT_2)
	text:set_autowrap(true)
	text:set_min_size(Vector2.new(SupportCard.WIDTH - 28, 0))
	v:add_child(text)
	local reward = T.hbox(6)
	local rl = T.label("Favorite reward:", 12, 600, T.TEXT_2)
	rl.size_flags_vertical = W.SHRINK_CENTER
	reward:add_child(rl)
	local rs = T.icon_rect("star", 14.0, T.AMBER)
	rs.size_flags_vertical = W.SHRINK_CENTER
	reward:add_child(rs)
	local rn = T.label(self:_amount(), 13, 800, T.AMBER)
	rn.size_flags_vertical = W.SHRINK_CENTER
	reward:add_child(rn)
	v:add_child(reward)
	self._btn = T.button("FAVORITE", "PrimaryButton", "star", 36.0)
	self._btn:set_font_size(12)
	self._btn:add_theme_constant_override("icon_max_width", 14)
	self._btn.pressed:Connect(function()
		self:_favorite()
	end)
	v:add_child(self._btn)

	-- phones: one button
	self._pill = T.button("+" .. self:_amount(), "PrimaryButton", "star", 40.0)
	self._pill:set_font_size(12)
	self._pill:add_theme_constant_override("icon_max_width", 16)
	self._pill.pressed:Connect(function()
		self:_favorite()
	end)
	self:add_child(self._pill)

	self._conn = AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result: any)
		if not self._asking then
			return
		end
		self._asking = false
		self:_set_busy(false)
		if result == Enum.AvatarPromptResult.Success and not self._sent then
			self._sent = true
			self.ctx:session_call("claim_favorite")
		end
	end)
	self:set_visible(false)
	return self
end

function SupportCard._amount(_self): string
	return UICtx.commas(SupportCard.STARS)
end

function SupportCard._set_busy(self, on: boolean)
	self._btn:set_disabled(on)
	self._pill:set_disabled(on)
end

--- Roblox's favorite prompt for this game (places are assets).
function SupportCard._favorite(self)
	if self._asking or self._sent then
		return
	end
	self.ctx:sfx("click")
	self._asking = true
	self:_set_busy(true)
	local ok = pcall(function()
		AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end)
	if not ok then
		self._asking = false
		self:_set_busy(false)
	end
end

--- Shown on the title until the Stars are paid (the inventory has come and has no `fav_paid`).
function SupportCard.refresh(self, on_title: boolean)
	local s = self.ctx.session
	local inv = if s ~= nil then s.inventory else nil
	local on = on_title and type(inv) == "table" and inv.loaded == true and inv.fav_paid ~= true
	if self.visible ~= on then
		self:set_visible(on)
	end
	if on then
		-- (the party panel grows and shrinks with its members and invites: follow its bottom)
		local party = self._party_ref
		local key = if party ~= nil and party.state ~= nil and party.visible
			then string.format("%d:%s", party._panel:get_combined_minimum_size().Y, tostring(party._open))
			else "-"
		if key ~= self._layout_key then
			self:apply_layout(party)
		end
	end
end

--- Under the party panel (left, halfway down on desktop); halfway down by itself when there is no party.
function SupportCard.apply_layout(self, party: any?)
	local ctx = self.ctx
	self._party_ref = party
	if ctx.vp == nil then
		return
	end
	local compact = ctx.compact
	local p, pill = self._panel, self._pill
	local x = 12.0 + ctx.insets.x
	local party_on = party ~= nil and party.state ~= nil and party.visible
	self._layout_key = if party_on
		then string.format("%d:%s", party._panel:get_combined_minimum_size().Y, tostring(party._open))
		else "-"
	p:set_visible(not compact)
	pill:set_visible(compact)
	if compact then
		-- phones: under the PARTY button (or where it would be), hidden while the party panel is open
		local y = math.max(ctx.reserved_top_left.Max.Y, 44.0) + 6.0 + ctx.insets.y
		if party_on then
			y += 46.0
			pill:set_visible(not party._open)
		end
		pill:set_anchors(0, 0, 0, 0)
		pill:set_offsets(x, y, x + 120, y + 40)
		return
	end
	p:set_min_size(Vector2.new(SupportCard.WIDTH, 0))
	p.anchor_left, p.anchor_right, p.anchor_top, p.anchor_bottom = 0, 0, 0.5, 0.5
	p.grow_horizontal = W.GROW_END
	p.offset_left, p.offset_right = x + 4.0, x + 4.0
	if party_on then
		-- the party panel grows both ways from the middle: start under its bottom
		local ph = party._panel:get_combined_minimum_size().Y
		local top = ph * 0.5 + SupportCard.GAP
		p.grow_vertical = W.GROW_END
		p.offset_top, p.offset_bottom = top, top
	else
		p.grow_vertical = W.GROW_BOTH
		p.offset_top, p.offset_bottom = 0, 0
	end
	p:reset_size()
end

return SupportCard
