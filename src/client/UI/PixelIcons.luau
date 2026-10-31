--!native
-- Empires Front: pixel-art glyphs drawn at runtime (EditableImage, 16 x 16, white on clear: tint them
-- like the other masks) for what has no uploaded art: the Forge, Farm, Mine and Market, Food, Ore and
-- the trade pact. PixelIcons.apply(label, name) shows one on an ImageLabel (crisp: Pixelated).
local AssetService = game:GetService("AssetService")

local PixelIcons = {}

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
}

local cache: { [string]: any } = {}

function PixelIcons.has(name: string?): boolean
	return name ~= nil and PixelIcons.GLYPHS[name] ~= nil
end

--- The glyph's Content (nil if it can't be made: EditableImage memory budget).
function PixelIcons.content(name: string): any
	local c = cache[name]
	if c ~= nil then
		return if c == false then nil else c
	end
	local rows = PixelIcons.GLYPHS[name]
	if rows == nil then
		return nil
	end
	local ok, img = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(16, 16) })
	end)
	if not ok or img == nil then
		cache[name] = false
		return nil
	end
	local buf = buffer.create(16 * 16 * 4)
	for y = 0, 15 do
		local row = rows[y + 1]
		for x = 0, 15 do
			if string.sub(row, x + 1, x + 1) == "W" then
				buffer.writeu32(buf, (y * 16 + x) * 4, 0xFFFFFFFF)
			end
		end
	end
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(16, 16), buf)
	local content = Content.fromObject(img)
	cache[name] = content
	return content
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
		label.ResampleMode = Enum.ResamplerMode.Pixelated
	end)
	return true
end

return PixelIcons
