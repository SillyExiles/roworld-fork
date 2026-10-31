--!nonstrict
-- Empires Front: the Empire Shop (the top bar's banner button). Flags of empires and nations that tile over
-- your land instead of its plain colour (Data/EmpireShop, Data/EmpireFlags; worn as a territory skin).
--   Stars           most flags, bought with the Stars every match pays (server/Purchases.buy_cosmetic).
--   Robux           a few flags sold as developer products (Data/EmpireShop.ROBUX_PRODUCTS).
--   Banner          the Imperial Banner game pass: your flag also flies beside your name.
-- Owned flags are put on (or taken off) from their card.
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
local FONT_MED = Font.fromId(12187365977, Enum.FontWeight.Medium)
local GOLD = Color3.fromRGB(245, 196, 43)
local PANEL = Color3.fromRGB(18, 20, 30)
local CARD = Color3.fromRGB(30, 33, 48)
local CARD_ON = Color3.fromRGB(44, 40, 26)
local TEXT2 = Color3.fromRGB(170, 180, 205)
local GREEN = Color3.fromRGB(70, 190, 110)
local ROBUX_GREEN = Color3.fromRGB(0, 176, 111)

local main: any = nil
local gui: ScreenGui? = nil
local tab = "stars"
local grid: ScrollingFrame? = nil
local balance_label: TextLabel? = nil
local tab_buttons: { [string]: TextButton } = {}
local hooked: any = nil
local pending: { [string]: boolean } = {}

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

-- =============================================================================================
-- Actions
-- =============================================================================================

local function buy_stars(it: any)
	local s = session()
	if s == nil or pending[it.id] then
		return
	end
	local inv = inventory()
	if inv ~= nil and (inv.stars or 0) < (it.stars or 0) then
		toast(string.format("You need %s more Stars: play matches to earn them", commas((it.stars or 0) - (inv.stars or 0))))
		return
	end
	if s:buy_unlock("cosmetic:" .. it.id) then
		pending[it.id] = true
		Shop.refresh()
	else
		toast("The shop is offline right now")
	end
end

local function buy_robux(it: any)
	local id = EmpireShopData.product_of(it.id) or 0
	if id == 0 then
		toast(it.name .. " is coming soon to the Robux shop")
		return
	end
	pcall(function()
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, id)
	end)
end

local function equip(it: any, on: boolean)
	local s = session()
	if s == nil then
		return
	end
	s:equip("skin", if on then it.id else false)
end

local function buy_banner()
	local id = EmpireShopData.BANNER_GAMEPASS
	if id == 0 then
		toast("The Imperial Banner is coming soon")
		return
	end
	pcall(function()
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, id)
	end)
end

-- =============================================================================================
-- The window
-- =============================================================================================

local function flag_card(it: any, order: number, parent: Instance)
	local inv = inventory() or {}
	local owned = inv.owned ~= nil and inv.owned[it.id] == true
	local worn = inv.equipped ~= nil and inv.equipped.skin == it.id
	local card = make("Frame", {
		Name = it.id,
		LayoutOrder = order,
		BackgroundColor3 = if worn then CARD_ON else CARD,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, card)
	make("UIStroke", {
		Color = tier_color(it.rarity),
		Transparency = if worn then 0 else 0.55,
		Thickness = if worn then 2 else 1,
	}, card)
	local img = make("ImageLabel", {
		Name = "Flag",
		BackgroundColor3 = Color3.new(0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(108, 72),
		ScaleType = Enum.ScaleType.Stretch,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 4) }, img)
	FlagArt.apply(img, it)
	make("TextLabel", {
		Name = "FlagName",
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = it.name,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(8, 86),
		Size = UDim2.new(1, -16, 0, 16),
	}, card)
	local tier = EmpireShopData.TIERS[it.rarity]
	make("TextLabel", {
		Name = "Tier",
		BackgroundTransparency = 1,
		FontFace = FONT_MED,
		Text = string.upper(if tier then tier.name else it.rarity),
		TextSize = 10,
		TextColor3 = tier_color(it.rarity),
		Position = UDim2.fromOffset(8, 102),
		Size = UDim2.new(1, -16, 0, 12),
	}, card)
	local text, color, fn
	if worn then
		text, color, fn = "EQUIPPED  ✓", GREEN, function()
			equip(it, false)
		end
	elseif owned then
		text, color, fn = "EQUIP", Color3.fromRGB(70, 110, 200), function()
			equip(it, true)
		end
	elseif (it.robux or 0) > 0 then
		local pid = EmpireShopData.product_of(it.id) or 0
		text = if pid == 0 then "SOON  ·  R$ " .. it.robux else "R$ " .. it.robux
		color, fn = ROBUX_GREEN, function()
			buy_robux(it)
		end
	elseif pending[it.id] then
		text, color, fn = "...", Color3.fromRGB(90, 90, 100), function() end
	else
		local enough = (inv.stars or 0) >= (it.stars or 0)
		text = "★ " .. commas(it.stars or 0)
		color = if enough then Color3.fromRGB(196, 140, 20) else Color3.fromRGB(80, 74, 60)
		fn = function()
			buy_stars(it)
		end
	end
	local b = make("TextButton", {
		Name = "Buy",
		AutoButtonColor = true,
		BackgroundColor3 = color,
		FontFace = FONT,
		Text = text,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(0, 8, 1, -34),
		Size = UDim2.new(1, -16, 0, 26),
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
	b.Activated:Connect(fn)
end

local function perk_card(title: string, price: string, lines: { string }, active: boolean, button: string, fn: () -> (), order: number, parent: Instance)
	local card = make("Frame", {
		Name = title,
		LayoutOrder = order,
		BackgroundColor3 = if active then CARD_ON else CARD,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, card)
	make("UIStroke", { Color = GOLD, Transparency = if active then 0 else 0.5, Thickness = 1.5 }, card)
	make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = title,
		TextSize = 18,
		TextColor3 = GOLD,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 0, 22),
	}, card)
	make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT_MED,
		Text = price,
		TextSize = 13,
		TextColor3 = TEXT2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(16, 34),
		Size = UDim2.new(1, -32, 0, 16),
	}, card)
	make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT_MED,
		Text = "• " .. table.concat(lines, "\n• "),
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(16, 58),
		Size = UDim2.new(1, -32, 1, -108),
	}, card)
	local b = make("TextButton", {
		AutoButtonColor = true,
		BackgroundColor3 = if active then GREEN else ROBUX_GREEN,
		FontFace = FONT,
		Text = if active then "ACTIVE  ✓" else button,
		TextSize = 15,
		TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(0, 16, 1, -46),
		Size = UDim2.new(1, -32, 0, 34),
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
	if not active then
		b.Activated:Connect(fn)
	end
end

local function fill()
	if grid == nil then
		return
	end
	for _, c in grid:GetChildren() do
		if not c:IsA("UIGridLayout") then
			c:Destroy()
		end
	end
	local layout = grid:FindFirstChildOfClass("UIGridLayout")
	if tab == "crown" then
		layout.CellSize = UDim2.fromOffset(330, 250)
		local inv = inventory() or {}
		perk_card("Imperial Banner", string.format("Game pass  ·  R$ %d once", EmpireShopData.BANNER_ROBUX), {
			"The Empire Shop flag you wear flies beside your name on the map",
			"...and beside your name on the leaderboard",
			"Yours for good",
		}, inv.banner == true, if EmpireShopData.BANNER_GAMEPASS == 0 then "COMING SOON" else "BUY", buy_banner, 2, grid)
		return
	end
	layout.CellSize = UDim2.fromOffset(150, 160)
	local list = {}
	for _, it in Cosmetics.empire_items() do
		if it.general then
			continue -- (the subscription's flag: shown only to whoever has it, under Stars)
		end
		local robux = (it.robux or 0) > 0
		if (tab == "robux") == robux then
			table.insert(list, it)
		end
	end
	-- the subscription's flag, owned: wearable from the Stars tab
	local inv = inventory() or {}
	if tab == "stars" then
		for _, it in Cosmetics.empire_items() do
			if it.general and inv.owned ~= nil and inv.owned[it.id] then
				table.insert(list, 1, it)
			end
		end
	end
	table.sort(list, function(a, b)
		local ta = (EmpireShopData.TIERS[a.rarity] or { order = 0 }).order
		local tb = (EmpireShopData.TIERS[b.rarity] or { order = 0 }).order
		if a.general ~= b.general then
			return a.general == true
		end
		if ta ~= tb then
			return ta < tb
		end
		return a.name < b.name
	end)
	for i, it in list do
		flag_card(it, i, grid)
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
	local dim = make("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(3, 4, 12),
		BackgroundTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
	}, g)
	dim.Activated:Connect(function()
		Shop.close()
	end)
	local panel = make("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0.86, 0),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.03,
	}, g)
	make("UISizeConstraint", { MaxSize = Vector2.new(860, 640) }, panel)
	make("UICorner", { CornerRadius = UDim.new(0, 16) }, panel)
	make("UIStroke", { Color = GOLD, Transparency = 0.6, Thickness = 1.5 }, panel)
	local icon = make("ImageLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 16),
		Size = UDim2.fromOffset(30, 30),
		ImageColor3 = GOLD,
	}, panel)
	PixelIcons.apply(icon, "flagshop")
	make("TextLabel", {
		Name = "Heading",
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = "EMPIRE SHOP",
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(58, 14),
		Size = UDim2.new(0, 220, 0, 22),
	}, panel)
	make("TextLabel", {
		Name = "Sub",
		BackgroundTransparency = 1,
		FontFace = FONT_MED,
		Text = "Flags that fly over your land. Every match pays Stars.",
		TextSize = 12,
		TextColor3 = TEXT2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(58, 36),
		Size = UDim2.new(0, 360, 0, 14),
	}, panel)
	balance_label = make("TextLabel", {
		Name = "Balance",
		BackgroundColor3 = Color3.fromRGB(40, 34, 14),
		FontFace = FONT,
		Text = "★ 0",
		TextSize = 16,
		TextColor3 = GOLD,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -60, 0, 16),
		Size = UDim2.fromOffset(150, 30),
	}, panel)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, balance_label)
	local close = make("TextButton", {
		Name = "Close",
		Text = "✕",
		FontFace = FONT,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(200, 205, 225),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(36, 36),
	}, panel)
	close.Activated:Connect(function()
		Shop.close()
	end)
	local tabs = make("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 0, 32),
	}, panel)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabs)
	for i, t in { { "stars", "★ STARS" }, { "robux", "ROBUX" }, { "crown", "BANNER" } } do
		local b = make("TextButton", {
			Name = t[1],
			LayoutOrder = i,
			AutoButtonColor = true,
			BackgroundColor3 = CARD,
			FontFace = FONT,
			Text = t[2],
			TextSize = 13,
			TextColor3 = Color3.new(1, 1, 1),
			Size = UDim2.fromOffset(110, 32),
		}, tabs)
		make("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
		b.Activated:Connect(function()
			tab = t[1]
			Shop.refresh()
		end)
		tab_buttons[t[1]] = b
	end
	local scroll = make("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 102),
		Size = UDim2.new(1, -32, 1, -118),
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, panel)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 160),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, scroll)
	make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, scroll)
	grid = scroll
	g.Parent = pg
	gui = g
end

function Shop.refresh()
	if gui == nil or not gui.Enabled then
		return
	end
	local inv = inventory() or {}
	if balance_label ~= nil then
		balance_label.Text = "★ " .. commas(inv.stars or 0)
	end
	for k, b in tab_buttons do
		b.BackgroundColor3 = if k == tab then Color3.fromRGB(196, 140, 20) else CARD
	end
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
			toast((if it then it.name else "Flag") .. " is yours: it now flies over your land!")
		elseif reason == "not enough" then
			toast("Not enough Stars yet: play matches to earn more")
		elseif reason ~= "owned" then
			toast("Couldn't buy that flag right now (" .. tostring(reason) .. ")")
		end
		Shop.refresh()
	end)
	if s.general_changed ~= nil then
		s.general_changed:Connect(function()
			Shop.refresh()
		end)
	end
end

function Shop.is_open(): boolean
	return gui ~= nil and gui.Enabled
end

function Shop.open(which: string?)
	if gui == nil then
		build()
	end
	hook()
	if which ~= nil then
		tab = which
	end
	gui.Enabled = true
	Shop.refresh()
	local panel = gui:FindFirstChild("Panel")
	if panel then
		panel.Position = UDim2.fromScale(0.5, 0.53)
		TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	end
end

function Shop.close()
	if gui ~= nil then
		gui.Enabled = false
	end
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
	local _ = RunService
end

return Shop
