--!native
-- Empires Front: the ships on the map in the style of the era in play (Map/ShipData: side-view pixel art,
-- grey-scale, tinted with the owner's colour like the base game's sprites): galleys and round merchantmen
-- in antiquity (Rome, Persia), junks in Ming China, galleons, caravels and carracks in the Age of Sail.
-- EditableImages made once per style, kind and facing.
local AssetService = game:GetService("AssetService")
local RS = game:GetService("ReplicatedStorage")
local Era = require(RS:WaitForChild("Airfront"):WaitForChild("Core"):WaitForChild("Era")) :: any
local ShipData = require(script.Parent:WaitForChild("ShipData")) :: any

local ShipArt = {}

ShipArt.STYLE_OF_ERA = { rome = "ancient", persia = "ancient", china = "junk", spain = "sail" }

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local INV: { [number]: number } = {}
for i = 1, 64 do
	INV[string.byte(B64, i)] = i - 1
end
local function unb64(s: string): buffer
	local out = buffer.create(#s * 3 // 4)
	local n = 0
	for i = 1, #s, 4 do
		local a, b, c, d = string.byte(s, i, i + 3)
		local vc, vd = INV[c or 61], INV[d or 61]
		local v = (INV[a] or 0) * 262144 + (INV[b] or 0) * 4096 + (vc or 0) * 64 + (vd or 0)
		buffer.writeu8(out, n, v // 65536)
		n += 1
		if vc ~= nil then
			buffer.writeu8(out, n, (v // 256) % 256)
			n += 1
		end
		if vd ~= nil then
			buffer.writeu8(out, n, v % 256)
			n += 1
		end
	end
	return out
end

local cache: { [string]: any } = {}

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
	local src = unb64(data)
	local buf = buffer.create(n * n * 4)
	for y = 0, n - 1 do
		for x = 0, n - 1 do
			local sx = if flipped then n - 1 - x else x
			buffer.writeu32(buf, (y * n + x) * 4, buffer.readu32(src, (y * n + sx) * 4))
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
