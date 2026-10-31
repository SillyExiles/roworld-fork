--!nonstrict
-- Empires Front: achievements on the client. Watches the match in play (Session.state, a GameState) once a
-- second and on its events, tells the server what was earned (server/Achievements saves it and awards the
-- Roblox badge), toasts it, and shows the medal window (the top bar's medal button, after Settings).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Airfront = RS:WaitForChild("Airfront")
local Data = require(Airfront:WaitForChild("Data"):WaitForChild("Achievements")) :: any
local Defs = require(Airfront:WaitForChild("Core"):WaitForChild("Defs")) :: any
local PixelIcons = require(script.Parent:WaitForChild("UI"):WaitForChild("PixelIcons")) :: any

local Ach = {}

local owned: { [string]: boolean } = {}
local net: any = nil
local main: any = nil
local bound_state: any = nil
local conns: { RBXScriptConnection } = {}
local gui: ScreenGui? = nil
local grid: Frame? = nil
local count_label: TextLabel? = nil

local FONT = Font.fromId(12187365977, Enum.FontWeight.Bold)
local FONT_MED = Font.fromId(12187365977, Enum.FontWeight.Medium)

local function toast(text: string)
	local ui = main and main.ui
	if ui ~= nil and type(ui._on_notice) == "function" then
		pcall(ui._on_notice, ui, text, 0)
	end
end

--- Earned now: saved through the server (which answers when stored), shown at once.
function Ach.unlock(id: string)
	if owned[id] or Data.get(id) == nil then
		return
	end
	owned[id] = true
	local a = Data.get(id)
	toast("Achievement unlocked: " .. a.title .. "!")
	if net ~= nil then
		local ev = net:FindFirstChild("AchievementUnlocked")
		if ev then
			ev:FireServer(id)
		end
	end
	Ach.refresh()
	-- every map won: the crown of crowns
	if not owned.all_empires then
		local all = true
		for _, w in Data.MAP_WINS do
			if not owned[w] then
				all = false
				break
			end
		end
		if all then
			Ach.unlock("all_empires")
		end
	end
end

-- =============================================================================================
-- Watching the match
-- =============================================================================================

local function me_of(st: any): number
	return tonumber(st.local_owner) or 0
end

local function check(st: any)
	local me = me_of(st)
	if me <= 0 then
		return
	end
	local o = st.owners[me]
	if o == nil then
		return
	end
	if o.spawned or (tonumber(o.tiles) or 0) > 0 then
		Ach.unlock("first_capital")
	end
	-- structures (finished: active_tick reached)
	local levels: { [number]: number } = {}
	for _, s in st.structures or {} do
		if s.owner == me and (s.active_tick or 0) <= st.tick then
			levels[s.kind] = (levels[s.kind] or 0) + (s.level or 1)
		end
	end
	if (levels[Defs.S_CITY] or 0) > 0 then
		Ach.unlock("first_city")
	end
	if (levels[Defs.S_MINE] or 0) > 0 then
		Ach.unlock("first_mine")
	end
	if (levels[Defs.S_MARKET] or 0) > 0 then
		Ach.unlock("first_market")
	end
	if (levels[Defs.S_FORGE] or 0) >= 4 then
		Ach.unlock("forge_max")
	end
	local ships = 0
	for _, u in st.units or {} do
		if u.owner == me and u.kind == Defs.U_WARSHIP then
			ships += 1
		end
	end
	if ships >= 5 then
		Ach.unlock("admiral")
	end
	if (tonumber(o.gold) or 0) >= 1000000 then
		Ach.unlock("tycoon")
	end
	if (tonumber(o.ore) or 0) >= 1000 then
		Ach.unlock("ore_baron")
	end
	local share = if type(st.land_share) == "function" then st:land_share(me) else 0
	if share >= 0.10 then
		Ach.unlock("land_10")
	end
	if share >= 0.25 then
		Ach.unlock("land_25")
	end
	if type(st.has_pact) == "function" then
		for id in st.owners do
			if id ~= me then
				if st:has_pact(me, id, 1) then
					Ach.unlock("trade_pact")
				end
				if st:has_pact(me, id, 2) then
					Ach.unlock("defense_pact")
				end
			end
		end
	end
end

local function on_game_over(st: any, winner: number, reason: number)
	local me = me_of(st)
	if me <= 0 or winner == nil then
		return
	end
	local won = winner == me
	if not won and (tonumber(st.winner_team) or 0) ~= 0 then
		local o = st.owners[me]
		won = o ~= nil and o.team == st.winner_team
	end
	if not won then
		return
	end
	if reason == Defs.OVER_OBJECTIVE then
		Ach.unlock("glory")
	elseif reason == Defs.OVER_DOMINATION then
		Ach.unlock("domination")
	end
	local map = string.match(tostring(st.map_id or ""), "^([%a_]+)") or ""
	if Data.get("win_" .. map) ~= nil then
		Ach.unlock("win_" .. map)
	end
end

local function bind(st: any)
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	bound_state = st
	if st == nil then
		return
	end
	if st.owner_eliminated ~= nil then
		table.insert(conns, st.owner_eliminated:Connect(function(_id: number, killer: number)
			if killer ~= nil and killer == me_of(st) then
				Ach.unlock("conqueror")
			end
		end))
	end
	if st.game_over ~= nil then
		table.insert(conns, st.game_over:Connect(function(winner: number, reason: number)
			on_game_over(st, winner, reason)
		end))
	end
end

-- =============================================================================================
-- The medal window
-- =============================================================================================

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

local function build_window()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local g = make("ScreenGui", {
		Name = "EmpiresFrontAchievements",
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
		Ach.close()
	end)
	local panel = make("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.82, 0),
		BackgroundColor3 = Color3.fromRGB(18, 20, 30),
		BackgroundTransparency = 0.05,
	}, g)
	make("UISizeConstraint", { MaxSize = Vector2.new(820, 600) }, panel)
	make("UICorner", { CornerRadius = UDim.new(0, 16) }, panel)
	make("UIStroke", { Color = Color3.fromRGB(245, 196, 43), Transparency = 0.6, Thickness = 1.5 }, panel)
	local title = make("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = "ACHIEVEMENTS",
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(24, 16),
		Size = UDim2.new(1, -120, 0, 30),
	}, panel)
	local _ = title
	count_label = make("TextLabel", {
		Name = "Count",
		BackgroundTransparency = 1,
		FontFace = FONT_MED,
		Text = "",
		TextSize = 14,
		TextColor3 = Color3.fromRGB(245, 196, 43),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(24, 46),
		Size = UDim2.new(1, -120, 0, 18),
	}, panel)
	local close = make("TextButton", {
		Name = "Close",
		Text = "✕",
		FontFace = FONT,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(200, 205, 225),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 12),
		Size = UDim2.fromOffset(36, 36),
	}, panel)
	close.Activated:Connect(function()
		Ach.close()
	end)
	local scroll = make("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 76),
		Size = UDim2.new(1, -32, 1, -92),
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, panel)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(250, 84),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, scroll)
	grid = scroll
	for _, a in Data.list do
		local card = make("Frame", {
			Name = a.id,
			LayoutOrder = a.order,
			BackgroundColor3 = Color3.fromRGB(30, 33, 48),
		}, scroll)
		make("UICorner", { CornerRadius = UDim.new(0, 10) }, card)
		local disc = make("Frame", {
			Name = "Medal",
			Position = UDim2.fromOffset(10, 12),
			Size = UDim2.fromOffset(60, 60),
			BackgroundColor3 = Data.TIER_COLORS[a.tier] or Color3.new(1, 1, 1),
		}, card)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
		make("UIStroke", { Name = "Rim", Color = Color3.fromRGB(70, 46, 12), Thickness = 2 }, disc)
		local icon = make("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(36, 36),
			ImageColor3 = Color3.fromRGB(60, 38, 8),
		}, disc)
		PixelIcons.apply(icon, a.icon)
		make("TextLabel", {
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = FONT,
			Text = a.title,
			TextSize = 15,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(80, 12),
			Size = UDim2.new(1, -88, 0, 20),
		}, card)
		make("TextLabel", {
			Name = "Text",
			BackgroundTransparency = 1,
			FontFace = FONT_MED,
			Text = a.text,
			TextSize = 12,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(170, 180, 205),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(80, 34),
			Size = UDim2.new(1, -88, 0, 42),
		}, card)
	end
	g.Parent = pg
	gui = g
end

--- Unlocked medals in their metal, locked ones grey.
function Ach.refresh()
	if grid == nil then
		return
	end
	local n, total = 0, #Data.list
	for _, a in Data.list do
		local card = grid:FindFirstChild(a.id)
		if card then
			local on = owned[a.id] == true
			if on then
				n += 1
			end
			local disc = card:FindFirstChild("Medal")
			disc.BackgroundColor3 = if on then (Data.TIER_COLORS[a.tier] or Color3.new(1, 1, 1)) else Color3.fromRGB(62, 66, 82)
			disc.Icon.ImageColor3 = if on then Color3.fromRGB(60, 38, 8) else Color3.fromRGB(110, 116, 136)
			card.BackgroundColor3 = if on then Color3.fromRGB(40, 38, 30) else Color3.fromRGB(26, 28, 40)
			card.Title.TextColor3 = if on then Color3.fromRGB(255, 236, 170) else Color3.fromRGB(150, 156, 176)
		end
	end
	if count_label then
		count_label.Text = string.format("%d of %d earned  ·  Roblox badges are awarded with them", n, total)
	end
end

function Ach.is_open(): boolean
	return gui ~= nil and gui.Enabled
end

function Ach.open()
	if gui == nil then
		build_window()
	end
	Ach.refresh()
	gui.Enabled = true
	local panel = gui:FindFirstChild("Panel")
	if panel then
		panel.Position = UDim2.fromScale(0.5, 0.53)
		TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	end
end

function Ach.close()
	if gui ~= nil then
		gui.Enabled = false
	end
end

function Ach.toggle()
	if Ach.is_open() then
		Ach.close()
	else
		Ach.open()
	end
end

--- Starts watching (Main: the client entry).
function Ach.start(m: any)
	main = m
	task.spawn(function()
		net = RS:WaitForChild("EmpiresFrontNet", 30)
		if net == nil then
			return
		end
		local get = net:WaitForChild("GetAchievements", 10)
		if get then
			local ok, list = pcall(function()
				return get:InvokeServer()
			end)
			if ok and type(list) == "table" then
				for _, id in list do
					owned[id] = true
				end
				Ach.refresh()
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local st = main and main.session and main.session.state
			if st ~= bound_state then
				bind(st)
			end
			if st ~= nil then
				pcall(check, st)
			end
		end
	end)
end

return Ach
