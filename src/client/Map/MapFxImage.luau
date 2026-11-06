--!native
-- Empires Front (2026-11-06): the map effects atlas drawn by the client (an EditableImage made from
-- Assets/MapFxPixels), because the uploaded atlas (Assets/MapFx.id) belongs to the original RoWorld
-- account and this experience isn't allowed to load it. Same layout: Assets/MapFx's rows still say
-- where each sprite is.
--
--   MapFxImage.apply(label)  shows the atlas on an ImageLabel (ImageRectOffset / Size still pick the
--                            frame); falls back to Assets/MapFx.id when no EditableImage can be made
local MapFxImage = {}

--- (looked up when first needed: the decoder runs in tests too)
local function assets(): any
	return game:GetService("ReplicatedStorage"):WaitForChild("Airfront"):WaitForChild("Assets")
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DEC: { [number]: number } = {}
for i = 1, #B64 do
	DEC[string.byte(B64, i)] = i - 1
end

--- Base64 to a buffer of bytes (no padding inside; "=" ends it).
function MapFxImage.decode_b64(s: string): buffer
	local n = #s
	local pad = 0
	if n > 0 and string.byte(s, n) == 61 then
		pad += 1
	end
	if n > 1 and string.byte(s, n - 1) == 61 then
		pad += 1
	end
	local out = buffer.create(n // 4 * 3 - pad)
	local o = 0
	local size = buffer.len(out)
	for i = 1, n, 4 do
		local a = DEC[string.byte(s, i)] or 0
		local b = DEC[string.byte(s, i + 1)] or 0
		local c = DEC[string.byte(s, i + 2)] or 0
		local d = DEC[string.byte(s, i + 3)] or 0
		local v = a * 262144 + b * 4096 + c * 64 + d
		if o < size then
			buffer.writeu8(out, o, v // 65536)
		end
		if o + 1 < size then
			buffer.writeu8(out, o + 1, (v // 256) % 256)
		end
		if o + 2 < size then
			buffer.writeu8(out, o + 2, v % 256)
		end
		o += 3
	end
	return out
end

--- The atlas as RGBA bytes (w * h * 4), from the palette and the runs.
function MapFxImage.pixels(data: any): buffer
	local w, h = data.w, data.h
	local pal = data.palette
	local runs = MapFxImage.decode_b64(data.runs)
	local px = buffer.create(w * h * 4)
	local total = w * h
	local p = 0
	for r = 0, buffer.len(runs) - 2, 2 do
		local k = buffer.readu8(runs, r) * 4
		local len = buffer.readu8(runs, r + 1)
		local cr, cg, cb, ca = pal[k + 1], pal[k + 2], pal[k + 3], pal[k + 4]
		for _ = 1, len do
			if p >= total then
				break
			end
			local o = p * 4
			buffer.writeu8(px, o, cr)
			buffer.writeu8(px, o + 1, cg)
			buffer.writeu8(px, o + 2, cb)
			buffer.writeu8(px, o + 3, ca)
			p += 1
		end
	end
	return px
end

local content: any = nil
local tried = false

--- The atlas's Content (nil when no EditableImage can be made: then Assets/MapFx.id is used).
function MapFxImage.content(): any
	if tried then
		return content
	end
	tried = true
	local ok = pcall(function()
		local data = require(assets():WaitForChild("MapFxPixels")) :: any
		local img = game:GetService("AssetService"):CreateEditableImage({ Size = Vector2.new(data.w, data.h) })
		if img == nil then
			return
		end
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(data.w, data.h), MapFxImage.pixels(data))
		content = Content.fromObject(img)
	end)
	if not ok then
		content = nil
	end
	return content
end

--- Shows the atlas on `label` (its ImageRectOffset / ImageRectSize pick the frame).
function MapFxImage.apply(label: any)
	local c = MapFxImage.content()
	if c ~= nil then
		label.Image = ""
		label.ImageContent = c
	else
		label.Image = (require(assets():WaitForChild("MapFx")) :: any).id
	end
end

--- True when the client draws the atlas itself (nothing to download).
function MapFxImage.drawn(): boolean
	return MapFxImage.content() ~= nil
end

return MapFxImage
