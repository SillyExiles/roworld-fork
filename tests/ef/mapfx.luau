-- Empires Front (2026-11-06): the map effects atlas drawn by the client (Map/MapFxImage from
-- Assets/MapFxPixels) is the atlas pixel for pixel. usage: luau tests/ef/mapfx.luau (from tests/ef)
local MapFxImage = require("../../src/client/Map/MapFxImage")
local data = require("../../src/shared/Assets/MapFxPixels")
local MapFx = require("../../src/shared/Assets/MapFx")
local px = MapFxImage.pixels(data)
local fails = 0
local function expect(c, w)
	print((if c then "  ok   " else "FAIL ") .. w)
	if not c then fails += 1 end
end
expect(buffer.len(px) == data.w * data.h * 4, "w * h RGBA bytes")
-- every row of Assets/MapFx fits in the atlas and has something drawn (in any of its frames)
for name, r in MapFx do
	if type(r) == "table" then
		local any = false
		for y = r.y, r.y + r.h - 1 do
			for x = r.x, r.x + r.w * r.frames - 1 do
				if buffer.readu8(px, (y * data.w + x) * 4 + 3) > 0 then any = true end
			end
		end
		expect(r.x + r.w * r.frames <= data.w and r.y + r.h <= data.h and any, name .. ": in the atlas, drawn")
	end
end
-- the PNG's bytes: sum of RGBA (transparent as 0,0,0,0) mod 1000003, from tools/assets/make_map_fx_pixels.py's source
local sum = 0
for i = 0, buffer.len(px) - 1 do sum = (sum + buffer.readu8(px, i)) % 1000003 end
expect(sum == 530278, "the same pixels as assets/map_fx/map_fx.png (" .. sum .. ")")
print(if fails == 0 then "all ok" else fails .. " FAILED")
