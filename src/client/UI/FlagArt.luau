--!nonstrict
-- Empires Front: the Empire Shop's pixel flags (Data/EmpireFlags) drawn at runtime (EditableImage, one
-- pixel per flag pixel, shown Pixelated), for the shop's cards, the name tags and the leaderboard.
--   FlagArt.content(item) -> Content?      (cached per item)
--   FlagArt.apply(label, item) -> boolean  an Empire Shop flag on an ImageLabel (false: not one)
local AssetService = game:GetService("AssetService")

local FlagArt = {}

local cache: { [string]: any } = {}

local function mask_key(ch: string): number
	local b = string.byte(ch)
	if b >= 49 and b <= 57 then
		return b - 48
	elseif b >= 97 and b <= 122 then
		return b - 87
	end
	return 0
end

function FlagArt.content(item: any): any
	if type(item) ~= "table" or not item.empire or type(item.mask) ~= "table" then
		return nil
	end
	local got = cache[item.id]
	if got ~= nil then
		return if got == false then nil else got
	end
	-- (the mask's last column and row are the gutter of the owner's own colour: not part of the flag)
	local rows = item.mask
	local h = #rows - 1
	local w = #rows[1] - 1
	local ok, img = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
	end)
	if not ok or img == nil then
		cache[item.id] = false
		return nil
	end
	local buf = buffer.create(w * h * 4)
	for y = 1, h do
		local row = rows[y]
		for x = 1, w do
			local k = mask_key(string.sub(row, x, x))
			local c = item.colors[k] or 0x808080
			local o = ((y - 1) * w + (x - 1)) * 4
			buffer.writeu8(buf, o, (c // 65536) % 256)
			buffer.writeu8(buf, o + 1, (c // 256) % 256)
			buffer.writeu8(buf, o + 2, c % 256)
			buffer.writeu8(buf, o + 3, 255)
		end
	end
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), buf)
	local content = Content.fromObject(img)
	cache[item.id] = content
	return content
end

function FlagArt.apply(label: any, item: any): boolean
	local c = FlagArt.content(item)
	if c == nil then
		return false
	end
	label.Image = ""
	label.ImageRectOffset = Vector2.zero
	label.ImageRectSize = Vector2.zero
	label.ImageContent = c
	pcall(function()
		label.ResampleMode = Enum.ResamplerMode.Pixelated
	end)
	return true
end

return FlagArt
