--!native
-- Empires Front: the ships on the map in the style of the era in play (Map/ShipData: side-view pixel art,
-- 32 x 32, grey-scale, tinted with the owner's colour like the base game's sprites): triremes and corbitas
-- for Rome, triremes rowed into battle and holkades for Greece, dhows for Persia, war dhows and pinasses on
-- the Niger for Mali, lateen galleys for the Ottomans, junks for China, Yuan junks for the Mongols,
-- atakebune and bezaisen for Japan, war canoes and acalli for the Aztecs, balsa rafts and totora boats for
-- the Inca, dreadnoughts and steamers for Russia 1914, ironclads and liners for Britain 1897, and ships of
-- the line, fluyts and brigs on the maps of nations. EditableImages made once per style, kind and facing.
local AssetService = game:GetService("AssetService")
local RS = game:GetService("ReplicatedStorage")
local Era = require(RS:WaitForChild("Airfront"):WaitForChild("Core"):WaitForChild("Era")) :: any
local ShipData = require(script.Parent:WaitForChild("ShipData")) :: any

local ShipArt = {}

-- (2026-11-06: every era its own; the maps of nations keep the Age of Sail)
ShipArt.STYLE_OF_ERA = {
	rome = "ancient",
	greece = "greek",
	persia = "dhow",
	mali = "niger",
	ottoman = "galley",
	china = "junk",
	mongol = "yuan",
	japan = "japan",
	inca = "raft",
	aztec = "canoe",
	russia = "steam",
	britain = "victorian",
	nations = "sail",
}

local cache: { [string]: any } = {}

--- A sprite row of ShipData unpacked ("12.3A" = 12 clear, then 3 A).
local function unrle(row: string): string
	return (string.gsub(row, "(%d+)(%D)", function(n: string, c: string): string
		return string.rep(c, tonumber(n) or 1)
	end))
end

--- The ship style of the era in play.
function ShipArt.style(): string
	return ShipArt.STYLE_OF_ERA[Era.id() or ""] or "ancient"
end

--- Content of ship `kind` ("warship" | "trade" | "transport") in the current style, mirrored when
--- `flipped` (facing left). nil if it can't be made.
function ShipArt.content(kind: string, flipped: boolean): any
	local style = ShipArt.style()
	local key = style .. kind .. (if flipped then "<" else ">")
	local c = cache[key]
	if c ~= nil then
		return if c == false then nil else c
	end
	local set = ShipData[style]
	local data = set and set[kind]
	if data == nil then
		cache[key] = false
		return nil
	end
	local n = ShipData.size
	local pal = ShipData.palette
	local buf = buffer.create(n * n * 4)
	for y = 0, n - 1 do
		local row = unrle(data[y + 1] or "")
		for x = 0, n - 1 do
			local sx = if flipped then n - 1 - x else x
			local v = pal[string.sub(row, sx + 1, sx + 1)]
			if v ~= nil then
				local o = (y * n + x) * 4
				buffer.writeu8(buf, o, v)
				buffer.writeu8(buf, o + 1, v)
				buffer.writeu8(buf, o + 2, v)
				buffer.writeu8(buf, o + 3, 255)
			end
		end
	end
	local ok, img = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(n, n) })
	end)
	if not ok or img == nil then
		cache[key] = false
		return nil
	end
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(n, n), buf)
	c = Content.fromObject(img)
	cache[key] = c
	return c
end

return ShipArt
