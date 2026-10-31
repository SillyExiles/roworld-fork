--!native
-- Empires Front: pixel-art glyphs drawn at runtime (EditableImage, 16 x 16, white on clear: tint them
-- like the other masks) for what has no uploaded art: the Forge, Farm, Mine and Market, Food, Ore and
-- the trade pact, the Border Wall, the Barracks and the Signals. PixelIcons.apply(label, name) shows one on an ImageLabel (crisp: Pixelated).
local AssetService = game:GetService("AssetService")

local PixelIcons = {}

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_INV: { [number]: number } = {}
for i = 1, 64 do
	B64_INV[string.byte(B64, i)] = i - 1
end
local function base64_decode(s: string): string
	local out = table.create(#s * 3 // 4)
	local n = 0
	for i = 1, #s, 4 do
		local a, b, c, d = string.byte(s, i, i + 3)
		local va, vb = B64_INV[a] or 0, B64_INV[b] or 0
		local vc, vd = B64_INV[c or 61], B64_INV[d or 61]
		local v = va * 262144 + vb * 4096 + (vc or 0) * 64 + (vd or 0)
		n += 1
		out[n] = string.char(v // 65536)
		if vc ~= nil then
			n += 1
			out[n] = string.char((v // 256) % 256)
		end
		if vd ~= nil then
			n += 1
			out[n] = string.char(v % 256)
		end
	end
	return table.concat(out)
end

PixelIcons.GLYPHS = {
	farm = {
		"................",
		"......W..W......",
		".....WW..WW.....",
		"..W..W.WW.W..W..",
		".WW..WW..WW..WW.",
		".W.W..W..W..W.W.",
		"..WW..WWWW..WW..",
		"...WW..WW..WW...",
		"....WWWWWWWW....",
		"......WWWW......",
		".......WW.......",
		".......WW.......",
		".......WW.......",
		"..WWWWWWWWWWWW..",
		".WWWWWWWWWWWWWW.",
		"................",
	},
	mine = {
		"................",
		"...WWWWWW.......",
		"..WWWWWWWWW.....",
		".WW......WWW....",
		".W.........WW...",
		"..........WWW...",
		".........WWW....",
		"........WWW.....",
		".......WWW......",
		"......WWW.......",
		".....WWW........",
		"....WWW.........",
		"...WWW..........",
		"..WWW...........",
		".WWW............",
		"................",
	},
	market = {
		"................",
		".......WW.......",
		".......WW.......",
		".WWWWWWWWWWWWWW.",
		".W.....WW.....W.",
		".W.....WW.....W.",
		"WWW....WW....WWW",
		"W.W....WW....W.W",
		"WWW....WW....WWW",
		".......WW.......",
		".......WW.......",
		".......WW.......",
		".....WWWWWW.....",
		"....WWWWWWWW....",
		"................",
		"................",
	},
	forge = {
		"................",
		"................",
		".WWWWWWWWWWWW...",
		"WWWWWWWWWWWWWWW.",
		".WWWWWWWWWWWWWWW",
		"...WWWWWWWWWW...",
		".....WWWWWW.....",
		".....WWWWWW.....",
		"....WWWWWWWW....",
		"...WWWWWWWWWW...",
		"..WWWWWWWWWWWW..",
		"..WWWWWWWWWWWW..",
		"................",
		"................",
		"................",
		"................",
	},
	food = {
		"................",
		"................",
		"......WWWW......",
		"....WWWWWWWW....",
		"...WW.WWWW.WW...",
		"..WWWWWWWWWWWW..",
		"..W.WWWWWWWW.W..",
		"..WWWWWWWWWWWW..",
		"...WWWWWWWWWW...",
		"....WWWWWWWW....",
		"................",
		"..WWWWWWWWWWWW..",
		"...WWWWWWWWWW...",
		"................",
		"................",
		"................",
	},
	ore = {
		"................",
		"................",
		"......WWW.......",
		".....WWWWW......",
		"....WWW.WWW.....",
		"...WWWWW.WWW....",
		"..WWWWWWW.WWW...",
		"..WWWWWWWWWWWW..",
		"..WWWWWWWWWWWW..",
		"...WWWWWWWWWW...",
		"....WWWWWWWW....",
		"................",
		"................",
		"................",
		"................",
		"................",
	},
	pact = {
		"................",
		"................",
		"..WW........WW..",
		".WWWW......WWWW.",
		"WWWWWW....WWWWWW",
		"WW..WWW..WWW..WW",
		"....WWWWWWWW....",
		".....WWWWWW.....",
		"....WWW..WWW....",
		"...WWW....WWW...",
		"..WWW......WWW..",
		"................",
		"................",
		"................",
		"................",
		"................",
	},
	-- (2026-10-31) the Border Wall, the Barracks, and the team's Signals (a flag, a target, help)
	wall = {
		"................",
		".WW..WW..WW..WW.",
		".WW..WW..WW..WW.",
		".WWWWWWWWWWWWWW.",
		".WWWWWWWWWWWWWW.",
		"................",
		".WWWWW.WWWWWWWW.",
		".WWWWW.WWWWWWWW.",
		"................",
		".WWW.WWWWWW.WWW.",
		".WWW.WWWWWW.WWW.",
		"................",
		".WWWWW.WWWWWWWW.",
		".WWWWW.WWWWWWWW.",
		"................",
		"................",
	},
	barracks = {
		"........WWW.....",
		"........WWWW....",
		"........WWW.....",
		"........W.......",
		"........W.......",
		".......WWW......",
		".....WWWWWWW....",
		"...WWWWWWWWWWW..",
		"..WWWWWWWWWWWWW.",
		"...W.........W..",
		"...W.WW...WW.W..",
		"...W.WW...WW.W..",
		"...W...WWW...W..",
		"...W...WWW...W..",
		"..WWWWWWWWWWWWW.",
		"................",
	},
	ping = {
		"................",
		"...WWWWWWWW.....",
		"...WWWWWWWWWW...",
		"...WWWWWWWWWWW..",
		"...WWWWWWWWWW...",
		"...WWWWWWWW.....",
		"...W............",
		"...W............",
		"...W............",
		"...W............",
		"...W............",
		"...W............",
		"...W............",
		"...W............",
		"..WWW...........",
		"................",
	},
	ping_target = {
		"................",
		".......WW.......",
		".....WWWWWW.....",
		"....W..WW..W....",
		"...W...WW...W...",
		"..W....WW....W..",
		"..W..........W..",
		".WWWWW....WWWWW.",
		".WWWWW....WWWWW.",
		"..W..........W..",
		"..W....WW....W..",
		"...W...WW...W...",
		"....W..WW..W....",
		".....WWWWWW.....",
		".......WW.......",
		"................",
	},
	ping_help = {
		"................",
		".......WW.......",
		"......WWWW......",
		"......W..W......",
		".....WW..WW.....",
		".....W.WW.W.....",
		"....WW.WW.WW....",
		"....W..WW..W....",
		"...WW..WW..WW...",
		"...W...WW...W...",
		"..WW........WW..",
		"..W....WW....W..",
		".WW....WW....WW.",
		".W............W.",
		".WWWWWWWWWWWWWW.",
		"................",
	},
}

local cache: { [string]: any } = {}

--- Antialiased 48 x 48 masks (UI/IconData, tools/make_icons.py) and the icon names they stand for.
local IconData = require("./IconData") :: any
PixelIcons.ALIASES = {
	city = "city_era",
	factory = "road_era",
	warship = "ship_era",
	forge = "forge",
	mine = "mine",
	market = "market",
	ore = "ore",
	pact = "pact",
	-- the ally's menu (2026-10-31)
	alliance = "alliance",
	betray = "betray",
	donate = "donate",
	renew = "renew",
	pact_trade = "pact_trade",
	pact_defense = "pact_defense",
	ore_sell = "ore_sell",
	ore_buy = "ore_buy",
	-- achievements
	medal = "medal",
	crown = "crown",
	laurel = "laurel",
	sword = "sword",
	-- the Empire Shop (v10)
	flagshop = "flagshop",
	chest = "chest",
}

function PixelIcons.has(name: string?): boolean
	return name ~= nil and (PixelIcons.ALIASES[name] ~= nil or PixelIcons.GLYPHS[name] ~= nil)
end

local function make(size: number, fill: (buffer) -> ()): any
	local ok, img = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
	end)
	if not ok or img == nil then
		return nil
	end
	local buf = buffer.create(size * size * 4)
	fill(buf)
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), buf)
	return Content.fromObject(img)
end

--- The glyph's Content (nil if it can't be made: EditableImage memory budget).
function PixelIcons.content(name: string): any
	local c = cache[name]
	if c ~= nil then
		return if c == false then nil else c
	end
	local alias = PixelIcons.ALIASES[name]
	local data = if alias ~= nil then IconData[alias] else nil
	if data ~= nil then
		local n = IconData.size
		local alpha = buffer.fromstring(base64_decode(data))
		c = make(n, function(buf)
			for i = 0, n * n - 1 do
				local a = buffer.readu8(alpha, i)
				-- white, alpha from the mask (RGBA bytes: little-endian u32 = A B G R)
				buffer.writeu32(buf, i * 4, 0x00FFFFFF + a * 16777216)
			end
		end)
	else
		local rows = PixelIcons.GLYPHS[name]
		if rows == nil then
			return nil
		end
		c = make(16, function(buf)
			for y = 0, 15 do
				local row = rows[y + 1]
				for x = 0, 15 do
					if string.sub(row, x + 1, x + 1) == "W" then
						buffer.writeu32(buf, (y * 16 + x) * 4, 0xFFFFFFFF)
					end
				end
			end
		end)
	end
	cache[name] = c or false
	return c
end

--- Shows glyph `name` on ImageLabel / ImageButton `label` (the whole image: no atlas rect). True if shown.
function PixelIcons.apply(label: any, name: string): boolean
	local c = PixelIcons.content(name)
	if c == nil then
		return false
	end
	label.ImageRectOffset = Vector2.zero
	label.ImageRectSize = Vector2.zero
	label.ImageContent = c
	pcall(function()
		label.ResampleMode = if PixelIcons.ALIASES[name] ~= nil then Enum.ResamplerMode.Default else Enum.ResamplerMode.Pixelated
	end)
	return true
end

return PixelIcons
