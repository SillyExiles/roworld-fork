--!nonstrict
-- Empires Front: the Empire Shop (the top bar's banner button) and the inventory (the chest button). Flags of
-- empires and nations that tile over your land instead of its plain colour (Data/EmpireShop,
-- Data/EmpireFlags; worn as a territory skin).
--   Stars       most flags, bought with the Stars every match pays (server/Purchases.buy_cosmetic).
--   Robux       a few flags sold as developer products (Data/EmpireShop.ROBUX_PRODUCTS).
--   Inventory   the flags owned: put one on, or go back to your own colour.
-- One of each flag: an owned one can't be bought again.
--
-- Animated: the window pops in and out, the tabs' marker slides, the cards rise in one after another and
-- grow under the pointer, legendary cards shimmer, buttons bounce, the Stars count up, a purchase bursts.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Airfront = RS:WaitForChild("Airfront")
local Data = Airfront:WaitForChild("Data")
local EmpireShopData = require(Data:WaitForChild("EmpireShop")) :: any
local Cosmetics = require(Data:WaitForChild("Cosmetics")) :: any
local UI = script.Parent:WaitForChild("UI")
local FlagArt = require(UI:WaitForChild("FlagArt")) :: any
local PixelIcons = require(UI:WaitForChild("PixelIcons")) :: any

local Shop = {}

local FONT = Font.fromId(12187365977, Enum.FontWeight.Bold)
local FONT_HEAVY = Font.fromId(12187365977, Enum.FontWeight.Heavy)
local FONT_MED = Font.fromId(12187365977, Enum.FontWeight.Medium)
local GOLD = Color3.fromRGB(245, 196, 43)
local GOLD_DARK = Color3.fromRGB(196, 140, 20)
local PANEL = Color3.fromRGB(16, 18, 28)
local CARD = Color3.fromRGB(30, 33, 48)
local CARD_HOVER = Color3.fromRGB(38, 42, 62)
local CARD_ON = Color3.fromRGB(46, 42, 24)
local TEXT2 = Color3.fromRGB(170, 180, 205)
local GREEN = Color3.fromRGB(64, 186, 104)
local BLUE = Color3.fromRGB(70, 110, 200)
local ROBUX_GREEN = Color3.fromRGB(0, 176, 111)
local GREY = Color3.fromRGB(70, 74, 92)
local RED = Color3.fromRGB(220, 70, 70)

local TABS = { { "stars", "STARS", "star" }, { "robux", "ROBUX", nil }, { "inventory", "INVENTORY", "chest" } }

local main: any = nil
local gui: ScreenGui? = nil
local dim: TextButton? = nil
local panel: Frame? = nil
local panel_scale: UIScale? = nil
local tab = "stars"
local grid: ScrollingFrame? = nil
local balance_label: TextLabel? = nil
local balance_pill: Frame? = nil
local tab_buttons: { [string]: TextButton } = {}
local tab_marker: Frame? = nil
local title_grad: UIGradient? = nil
local header_icon: ImageLabel? = nil
local shimmers: { UIGradient } = {}
local hooked: any = nil
local pending: { [string]: boolean } = {}
local shown_stars = 0
local stars_tween: any = nil
local anim_conn: RBXScriptConnection? = nil
local closing = false
local celebrate_id: string? = nil

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in props do
		(i :: any)[k] = v
	end
	if parent then
		i.Parent = parent
	end
	return i
end

local function tween(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function session(): any
	return main and main.session
end

local function inventory(): any
	local s = session()
	return if s ~= nil then s.inventory else nil
end

local function toast(text: string)
	local ui = main and main.ui
	if ui ~= nil and type(ui._on_notice) == "function" then
		pcall(ui._on_notice, ui, text, 0)
	end
end

local function tier_color(tier: string): Color3
	local t = EmpireShopData.TIERS[tier]
	local c = if t ~= nil then t.color else 0x9AA6B2
	return Color3.fromRGB((c // 65536) % 256, (c // 256) % 256, c % 256)
end

--- An icon glyph (UI/PixelIcons) as an ImageLabel.
local function glyph(name: string, size: number, color: Color3, parent: Instance, props: { [string]: any }?): ImageLabel
	local img = make("ImageLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		ImageColor3 = color,
	}, parent)
	for k, v in props or {} do
		(img :: any)[k] = v
	end
	PixelIcons.apply(img, name)
	return img
end

--- A button that bounces when pressed and brightens under the pointer.
local function bouncy(b: GuiButton, base: Color3)
	local sc = make("UIScale", { Scale = 1 }, b)
	b.MouseEnter:Connect(function()
		tween(sc, 0.12, { Scale = 1.05 }, Enum.EasingStyle.Back)
		tween(b, 0.12, { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.15) })
	end)
	b.MouseLeave:Connect(function()
		tween(sc, 0.12, { Scale = 1 })
		tween(b, 0.12, { BackgroundColor3 = base })
	end)
	b.MouseButton1Down:Connect(function()
		tween(sc, 0.06, { Scale = 0.92 })
	end)
	b.MouseButton1Up:Connect(function()
		tween(sc, 0.25, { Scale = 1.05 }, Enum.EasingStyle.Back)
	end)
end

--- Little gold squares flying out of `frame`'s centre: a purchase.
local function burst(frame: GuiObject, color: Color3)
	if gui == nil then
		return
	end
	local p = frame.AbsolutePosition + frame.AbsoluteSize / 2
	for i = 1, 18 do
		local a = (i / 18) * math.pi * 2 + math.random() * 0.4
		local d = 60 + math.random() * 70
		local sz = math.random(5, 9)
		local bit = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(p.X, p.Y),
			Size = UDim2.fromOffset(sz, sz),
			BackgroundColor3 = if i % 3 == 0 then Color3.new(1, 1, 1) else color,
			BorderSizePixel = 0,
			Rotation = math.random(0, 90),
			ZIndex = 50,
		}, gui)
		tween(bit, 0.7, {
			Position = UDim2.fromOffset(p.X + math.cos(a) * d, p.Y + math.sin(a) * d),
			Rotation = bit.Rotation + 180,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(2, 2),
		}, Enum.EasingStyle.Quart)
		task.delay(0.75, function()
			bit:Destroy()
		end)
	end
end

-- =============================================================================================
-- Actions
-- =============================================================================================

local function buy_stars(it: any)
	local s = session()
	if s == nil or pending[it.id] then
		return
	end
	local inv = inventory()
	if inv ~= nil and inv.owned ~= nil and inv.owned[it.id] then
		return
	end
	if inv ~= nil and (inv.stars or 0) < (it.stars or 0) then
		toast(string.format("You need %s more Stars: play matches to earn them", commas((it.stars or 0) - (inv.stars or 0))))
		if balance_pill ~= nil then
			-- the balance shakes: not enough
			local x = balance_pill.Position
			for k, dx in { -6, 6, -4, 4, 0 } do
				task.delay(k * 0.05, function()
					tween(balance_pill :: Frame, 0.05, { Position = x + UDim2.fromOffset(dx, 0) })
				end)
			end
		end
		return
	end
	if s:buy_unlock("cosmetic:" .. it.id) then
		pending[it.id] = true
		Shop.refresh(true)
	else
		toast("The shop is offline right now")
	end
end

local function buy_robux(it: any)
	local inv = inventory()
	if inv ~= nil and inv.owned ~= nil and inv.owned[it.id] then
		toast("You already own " .. it.name)
		return
	end
	local id = EmpireShopData.product_of(it.id) or 0
	if id == 0 then
		toast(it.name .. " is coming soon to the Robux shop")
		return
	end
	pcall(function()
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, id)
	end)
end

local function equip(id: string | false)
	local s = session()
	if s == nil then
		return
	end
	celebrate_id = if id == false then "none" else id
	s:equip("skin", id)
end

-- =============================================================================================
-- Cards
-- =============================================================================================

--- A card's shell: the grid cell, and the body inside it that animates (rises in, grows when hovered).
local function card_shell(name: string, order: number, worn: boolean, stroke: Color3, legendary: boolean): (Frame, Frame)
	local cell = make("Frame", { Name = name, LayoutOrder = order, BackgroundTransparency = 1 }, grid)
	local body = make("Frame", {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 30),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = if worn then CARD_ON else CARD,
		BackgroundTransparency = 1,
	}, cell)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, body)
	local sc = make("UIScale", { Scale = 0.85 }, body)
	local st = make("UIStroke", {
		Color = if legendary then Color3.new(1, 1, 1) else stroke,
		Transparency = 1,
		Thickness = if worn then 2.5 else 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, body)
	if legendary then
		local g = make("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, stroke),
				ColorSequenceKeypoint.new(0.45, stroke),
				ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 0.85)),
				ColorSequenceKeypoint.new(0.55, stroke),
				ColorSequenceKeypoint.new(1, stroke),
			}),
		}, st)
		table.insert(shimmers, g)
	end
	-- rise in, one after another
	local delay = math.min(order, 24) * 0.025
	task.delay(delay, function()
		if body.Parent == nil then
			return
		end
		tween(body, 0.35, { Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 0 }, Enum.EasingStyle.Back)
		tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(st, 0.35, { Transparency = if worn then 0 else 0.45 })
	end)
	-- grow under the pointer
	body.MouseEnter:Connect(function()
		tween(sc, 0.15, { Scale = 1.06 }, Enum.EasingStyle.Back)
		tween(st, 0.15, { Transparency = 0 })
		if not worn then
			tween(body, 0.15, { BackgroundColor3 = CARD_HOVER })
		end
	end)
	body.MouseLeave:Connect(function()
		tween(sc, 0.15, { Scale = 1 })
		tween(st, 0.15, { Transparency = if worn then 0 else 0.45 })
		tween(body, 0.15, { BackgroundColor3 = if worn then CARD_ON else CARD })
	end)
	return cell, body
end

local function card_button(body: Frame, text: string, color: Color3, icon: string?, fn: () -> ())
	local b = make("TextButton", {
		Name = "Buy",
		AutoButtonColor = false,
		BackgroundColor3 = color,
		FontFace = FONT,
		Text = text,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(0, 8, 1, -36),
		Size = UDim2.new(1, -16, 0, 28),
		ZIndex = 3,
	}, body)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
		Rotation = 90,
	}, b)
	if icon ~= nil then
		make("UIPadding", { PaddingLeft = UDim.new(0, 16) }, b)
		glyph(icon, 14, Color3.new(1, 1, 1), b, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -6, 0.5, 0),
			ZIndex = 4,
		})
	end
	bouncy(b, color)
	b.Activated:Connect(fn)
	return b
end

local function flag_card(it: any, order: number)
	local inv = inventory() or {}
	local owned = inv.owned ~= nil and inv.owned[it.id] == true
	local worn = inv.equipped ~= nil and inv.equipped.skin == it.id
	local legendary = it.rarity == "legendary"
	local _, body = card_shell(it.id, order, worn, tier_color(it.rarity), legendary)
	local img = make("ImageLabel", {
		Name = "Flag",
		BackgroundColor3 = Color3.new(0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(112, 75),
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 2,
	}, body)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, img)
	FlagArt.apply(img, it)
	if worn then
		make("UIStroke", { Color = GREEN, Thickness = 2 }, img)
	end
	make("TextLabel", {
		Name = "FlagName",
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = it.name,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(8, 90),
		Size = UDim2.new(1, -16, 0, 16),
		ZIndex = 2,
	}, body)
	local tier = EmpireShopData.TIERS[it.rarity]
	make("TextLabel", {
		Name = "Tier",
		BackgroundTransparency = 1,
		FontFace = FONT_HEAVY,
		Text = string.upper(if tier then tier.name else it.rarity),
		TextSize = 10,
		TextColor3 = tier_color(it.rarity),
		Position = UDim2.fromOffset(8, 106),
		Size = UDim2.new(1, -16, 0, 12),
		ZIndex = 2,
	}, body)
	if tab == "inventory" then
		if worn then
			card_button(body, "EQUIPPED", GREEN, "tick", function()
				equip(false)
			end)
		else
			card_button(body, "EQUIP", BLUE, nil, function()
				equip(it.id)
			end)
		end
	elseif worn then
		card_button(body, "EQUIPPED", GREEN, "tick", function()
			Shop.open("inventory")
		end)
	elseif owned then
		card_button(body, "OWNED", GREY, "tick", function()
			Shop.open("inventory")
		end)
	elseif (it.robux or 0) > 0 then
		local pid = EmpireShopData.product_of(it.id) or 0
		card_button(body, (if pid == 0 then "SOON  " else "") .. "R$ " .. it.robux, ROBUX_GREEN, nil, function()
			buy_robux(it)
		end)
	elseif pending[it.id] then
		card_button(body, "BUYING...", GREY, nil, function() end)
	else
		local enough = (inv.stars or 0) >= (it.stars or 0)
		card_button(body, commas(it.stars or 0), if enough then GOLD_DARK else Color3.fromRGB(84, 76, 56), "star", function()
			buy_stars(it)
		end)
	end
	-- just bought or put on: a burst over the card
	if celebrate_id == it.id and (worn or owned) then
		celebrate_id = nil
		task.delay(0.35, function()
			if body.Parent ~= nil then
				burst(body, GOLD)
				local flash = make("Frame", {
					BackgroundColor3 = GOLD,
					BackgroundTransparency = 0.2,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 10,
				}, body)
				make("UICorner", { CornerRadius = UDim.new(0, 12) }, flash)
				tween(flash, 0.6, { BackgroundTransparency = 1 })
				task.delay(0.65, function()
					flash:Destroy()
				end)
			end
		end)
	end
end

local function own_colour_card()
	local inv = inventory() or {}
	local worn_none = inv.equipped == nil or EmpireShopData.flag_of(inv.equipped.skin) == nil
	local _, body = card_shell("None", 0, worn_none, Color3.fromRGB(120, 130, 160), false)
	local sw = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(112, 75),
		BackgroundColor3 = Color3.fromRGB(90, 120, 200),
		ZIndex = 2,
	}, body)
	make("UICorner", { CornerRadius = UDim.new(0, 5) }, sw)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(110, 150, 230), Color3.fromRGB(60, 90, 170)),
		Rotation = 45,
	}, sw)
	make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = "Your colour",
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(8, 90),
		Size = UDim2.new(1, -16, 0, 16),
		ZIndex = 2,
	}, body)
	make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT_HEAVY,
		Text = "NO FLAG",
		TextSize = 10,
		TextColor3 = TEXT2,
		Position = UDim2.fromOffset(8, 106),
		Size = UDim2.new(1, -16, 0, 12),
		ZIndex = 2,
	}, body)
	card_button(body, if worn_none then "EQUIPPED" else "EQUIP", if worn_none then GREEN else BLUE, if worn_none then "tick" else nil, function()
		if not worn_none then
			equip(false)
		end
	end)
end

local function fill()
	if grid == nil then
		return
	end
	table.clear(shimmers)
	for _, c in grid:GetChildren() do
		if not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
	local list = {}
	local inv = inventory() or {}
	local owned = inv.owned or {}
	for _, it in Cosmetics.empire_items() do
		if tab == "inventory" then
			if owned[it.id] then
				table.insert(list, it)
			end
			continue
		end
		if it.general then
			continue -- (never sold)
		end
		local robux = (it.robux or 0) > 0
		if (tab == "robux") == robux then
			table.insert(list, it)
		end
	end
	table.sort(list, function(a, b)
		local ta = (EmpireShopData.TIERS[a.rarity] or { order = 0 }).order
		local tb = (EmpireShopData.TIERS[b.rarity] or { order = 0 }).order
		if ta ~= tb then
			return ta < tb
		end
		return a.name < b.name
	end)
	if tab == "inventory" then
		own_colour_card()
		if #list == 0 then
			make("TextLabel", {
				Name = "Empty",
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				FontFace = FONT_MED,
				Text = "No flags yet: buy them with Stars or Robux in the other tabs.",
				TextSize = 13,
				TextWrapped = true,
				TextColor3 = TEXT2,
			}, grid)
		end
	end
	for i, it in list do
		flag_card(it, i)
	end
	grid.CanvasPosition = Vector2.zero
end

-- =============================================================================================
-- The window
-- =============================================================================================

local function move_marker(instant: boolean?)
	local b = tab_buttons[tab]
	if tab_marker == nil or b == nil then
		return
	end
	local goal = { Position = UDim2.fromOffset(b.Position.X.Offset, 34), Size = UDim2.fromOffset(b.Size.X.Offset, 3) }
	if instant then
		tab_marker.Position = goal.Position
		tab_marker.Size = goal.Size
	else
		tween(tab_marker, 0.25, goal, Enum.EasingStyle.Back)
	end
	for k, tb in tab_buttons do
		tween(tb, 0.2, { TextColor3 = if k == tab then GOLD else TEXT2 })
		local ic = tb:FindFirstChild("Icon")
		if ic then
			tween(ic, 0.2, { ImageColor3 = if k == tab then GOLD else TEXT2 })
		end
	end
end

local function build()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = make("ScreenGui", {
		Name = "EmpiresFrontShop",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 60,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	dim = make("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(3, 4, 12),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, g)
	;(dim :: TextButton).Activated:Connect(function()
		Shop.close()
	end)
	local p = make("CanvasGroup", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0.86, 0),
		BackgroundColor3 = PANEL,
		GroupTransparency = 1,
	}, g)
	panel = p
	panel_scale = make("UIScale", { Scale = 0.85 }, p)
	make("UISizeConstraint", { MaxSize = Vector2.new(880, 650) }, p)
	make("UICorner", { CornerRadius = UDim.new(0, 18) }, p)
	make("UIStroke", { Color = GOLD, Transparency = 0.5, Thickness = 2 }, p)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 196, 220)),
		Rotation = 90,
	}, p)
	-- header band
	local head = make("Frame", {
		Name = "Head",
		BackgroundColor3 = Color3.fromRGB(28, 24, 14),
		Size = UDim2.new(1, 0, 0, 62),
	}, p)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(70, 52, 14), Color3.fromRGB(20, 22, 32)),
		Rotation = 0,
	}, head)
	header_icon = glyph("flagshop", 34, GOLD, head, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(38, 31),
	})
	local title = make("TextLabel", {
		Name = "Heading",
		BackgroundTransparency = 1,
		FontFace = FONT_HEAVY,
		Text = "EMPIRE SHOP",
		TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(64, 10),
		Size = UDim2.new(0, 260, 0, 26),
	}, head)
	title_grad = make("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, GOLD),
			ColorSequenceKeypoint.new(0.42, GOLD),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 250, 220)),
			ColorSequenceKeypoint.new(0.58, GOLD),
			ColorSequenceKeypoint.new(1, GOLD),
		}),
	}, title)
	make("TextLabel", {
		Name = "Sub",
		BackgroundTransparency = 1,
		FontFace = FONT_MED,
		Text = "Flags that fly over your land. Every match pays Stars.",
		TextSize = 12,
		TextColor3 = TEXT2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(64, 36),
		Size = UDim2.new(0, 380, 0, 14),
	}, head)
	-- the balance
	local pill = make("Frame", {
		Name = "Balance",
		BackgroundColor3 = Color3.fromRGB(46, 36, 10),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -66, 0, 31),
		Size = UDim2.fromOffset(150, 34),
	}, head)
	balance_pill = pill
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)
	make("UIStroke", { Color = GOLD, Transparency = 0.4, Thickness = 1.5 }, pill)
	glyph("star", 18, GOLD, pill, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0) })
	balance_label = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT_HEAVY,
		Text = "0",
		TextSize = 17,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -48, 1, 0),
	}, pill)
	-- close: a plain X that turns red and spins under the pointer
	local close = make("TextButton", {
		Name = "Close",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(44, 46, 62),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0, 31),
		Size = UDim2.fromOffset(38, 38),
	}, head)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, close)
	local x = glyph("cross", 18, Color3.new(1, 1, 1), close, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	local xs = make("UIScale", { Scale = 1 }, close)
	close.MouseEnter:Connect(function()
		tween(close, 0.15, { BackgroundColor3 = RED })
		tween(x, 0.25, { Rotation = 90 }, Enum.EasingStyle.Back)
		tween(xs, 0.15, { Scale = 1.08 }, Enum.EasingStyle.Back)
	end)
	close.MouseLeave:Connect(function()
		tween(close, 0.15, { BackgroundColor3 = Color3.fromRGB(44, 46, 62) })
		tween(x, 0.25, { Rotation = 0 }, Enum.EasingStyle.Back)
		tween(xs, 0.15, { Scale = 1 })
	end)
	close.MouseButton1Down:Connect(function()
		tween(xs, 0.06, { Scale = 0.9 })
	end)
	close.Activated:Connect(function()
		Shop.close()
	end)
	-- tabs, with a sliding marker under the chosen one
	local tabs = make("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 70),
		Size = UDim2.new(1, -40, 0, 38),
	}, p)
	local tx = 0
	for _, t in TABS do
		local w = if t[1] == "inventory" then 130 else 104
		local b = make("TextButton", {
			Name = t[1],
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			FontFace = FONT_HEAVY,
			Text = t[2],
			TextSize = 14,
			TextColor3 = TEXT2,
			Position = UDim2.fromOffset(tx, 0),
			Size = UDim2.fromOffset(w, 32),
		}, tabs)
		if t[3] ~= nil then
			make("UIPadding", { PaddingLeft = UDim.new(0, 20) }, b)
			glyph(t[3], 14, TEXT2, b, {
				Name = "Icon",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, -2, 0.5, 0),
			})
		end
		local sc = make("UIScale", { Scale = 1 }, b)
		b.MouseEnter:Connect(function()
			tween(sc, 0.12, { Scale = 1.08 }, Enum.EasingStyle.Back)
		end)
		b.MouseLeave:Connect(function()
			tween(sc, 0.12, { Scale = 1 })
		end)
		b.Activated:Connect(function()
			if tab ~= t[1] then
				tab = t[1]
				move_marker()
				fill()
			end
		end)
		tab_buttons[t[1]] = b
		tx += w + 10
	end
	tab_marker = make("Frame", {
		Name = "Marker",
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(100, 3),
		Position = UDim2.fromOffset(0, 34),
	}, tabs)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, tab_marker)
	make("Frame", {
		BackgroundColor3 = Color3.fromRGB(50, 54, 72),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 37),
		Size = UDim2.new(1, 0, 0, 1),
	}, tabs)
	local scroll = make("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 116),
		Size = UDim2.new(1, -32, 1, -128),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = GOLD,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, p)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(152, 170),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, scroll)
	make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12) }, scroll)
	grid = scroll
	g.Parent = pg
	gui = g
end

--- The Stars count up (or down) to the balance; the pill pops when it grows.
local function show_balance(stars: number, instant: boolean?)
	if balance_label == nil then
		return
	end
	if instant or stars == shown_stars then
		shown_stars = stars
		balance_label.Text = commas(stars)
		return
	end
	local from = shown_stars
	shown_stars = stars
	local v = Instance.new("NumberValue")
	v.Value = from
	v.Changed:Connect(function(n)
		if balance_label ~= nil then
			balance_label.Text = commas(n)
		end
	end)
	if stars_tween ~= nil then
		stars_tween:Cancel()
	end
	stars_tween = tween(v, 0.8, { Value = stars }, Enum.EasingStyle.Quart)
	if balance_pill ~= nil and stars > from then
		local sc = balance_pill:FindFirstChildOfClass("UIScale") or make("UIScale", { Scale = 1 }, balance_pill)
		sc.Scale = 1.18
		tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

function Shop.refresh(keep_cards: boolean?)
	if gui == nil or not gui.Enabled or closing then
		return
	end
	local inv = inventory() or {}
	show_balance(inv.stars or 0)
	local _ = keep_cards
	fill()
end

local function hook()
	local s = session()
	if s == nil or hooked == s then
		return
	end
	hooked = s
	s.inventory_changed:Connect(function()
		table.clear(pending)
		Shop.refresh()
	end)
	s.unlock_result:Connect(function(key: string, ok: boolean, reason: string?)
		local id = string.match(tostring(key), "^cosmetic:(.+)$")
		if id == nil then
			return
		end
		pending[id] = nil
		local it = Cosmetics.item(id)
		if ok then
			celebrate_id = id
			toast((if it then it.name else "Flag") .. " is yours: it now flies over your land!")
		elseif reason == "not enough" then
			toast("Not enough Stars yet: play matches to earn more")
		elseif reason ~= "owned" then
			toast("Couldn't buy that flag right now (" .. tostring(reason) .. ")")
		end
		Shop.refresh()
	end)
end

local function animate(on: boolean)
	if on then
		if anim_conn ~= nil then
			return
		end
		local t0 = os.clock()
		anim_conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			-- the title's shine sweeps across every 2.5 s; legendary borders turn
			if title_grad ~= nil then
				title_grad.Offset = Vector2.new(((t % 2.5) / 2.5) * 2.4 - 1.2, 0)
			end
			for _, g in shimmers do
				g.Rotation = (t * 90) % 360
			end
			-- the banner in the header sways
			if header_icon ~= nil then
				header_icon.Rotation = math.sin(t * 2.2) * 7
			end
		end)
	elseif anim_conn ~= nil then
		anim_conn:Disconnect()
		anim_conn = nil
	end
end

function Shop.is_open(): boolean
	return gui ~= nil and gui.Enabled and not closing
end

function Shop.open(which: string?)
	if gui == nil then
		build()
	end
	hook()
	local was_open = gui.Enabled and not closing
	closing = false
	if which ~= nil then
		tab = which
	end
	gui.Enabled = true
	move_marker(not was_open)
	local inv = inventory() or {}
	if not was_open then
		show_balance(inv.stars or 0, true)
		;(panel_scale :: UIScale).Scale = 0.85
		;(panel :: any).GroupTransparency = 1
		;(dim :: TextButton).BackgroundTransparency = 1
		tween(panel_scale :: UIScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(panel :: any, 0.25, { GroupTransparency = 0 })
		tween(dim :: TextButton, 0.25, { BackgroundTransparency = 0.35 })
		animate(true)
	end
	fill()
end

function Shop.close()
	if gui == nil or not gui.Enabled or closing then
		return
	end
	closing = true
	tween(panel_scale :: UIScale, 0.2, { Scale = 0.88 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(panel :: any, 0.2, { GroupTransparency = 1 })
	tween(dim :: TextButton, 0.2, { BackgroundTransparency = 1 })
	task.delay(0.21, function()
		if closing and gui ~= nil then
			gui.Enabled = false
			closing = false
			animate(false)
		end
	end)
end

function Shop.toggle()
	if Shop.is_open() then
		Shop.close()
	else
		Shop.open()
	end
end

--- Main (the client entry) hands over itself: its session and UI.
function Shop.start(m: any)
	main = m
	-- (a Robux flag bought: the server's receipt brings the inventory, and with it the refresh)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(_uid, _pid, bought: boolean)
		if bought then
			toast("Thank you! Your flag arrives in a moment")
		end
	end)
end

return Shop
