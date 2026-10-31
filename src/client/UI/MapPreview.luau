--!native
-- Empires Front: the map picker's previews (Assets/MapPreviews, made by tools/maps/make_previews.py: the
-- map in the game's pixel-art colours with its objective's gold stars), shown through EditableImages.
local AssetService = game:GetService("AssetService")
local RS = game:GetService("ReplicatedStorage")
local Airfront = RS:WaitForChild("Airfront")
local MapCodec = require(Airfront:WaitForChild("Core"):WaitForChild("MapCodec")) :: any

local MapPreview = {}

local _data: any = nil
local cache: { [string]: any } = {}

local function data(): any
	if _data == nil then
		local ok, m = pcall(function()
			return require(Airfront:WaitForChild("Assets"):WaitForChild("MapPreviews"))
		end)
		_data = if ok and type(m) == "table" then m else {}
	end
	return _data
end

--- The preview of map `id` as Content (nil when there is none or it can't be made).
function MapPreview.content(id: string?): any
	if id == nil then
		return nil
	end
	local base = string.match(id, "^(.-)@%d+$") or id
	local c = cache[base]
	if c ~= nil then
		return if c == false then nil else c
	end
	local e = data()[base]
	if e == nil then
		cache[base] = false
		return nil
	end
	local ok, content = pcall(function()
		local rgb = MapCodec.zstd_decompress(MapCodec.b64decode(e.data))
		local w, h = e.w, e.h
		local rgba = buffer.create(w * h * 4)
		for i = 0, w * h - 1 do
			buffer.writeu8(rgba, i * 4, buffer.readu8(rgb, i * 3))
			buffer.writeu8(rgba, i * 4 + 1, buffer.readu8(rgb, i * 3 + 1))
			buffer.writeu8(rgba, i * 4 + 2, buffer.readu8(rgb, i * 3 + 2))
			buffer.writeu8(rgba, i * 4 + 3, 255)
		end
		local img = AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), rgba)
		return Content.fromObject(img)
	end)
	cache[base] = if ok and content ~= nil then content else false
	return if ok then content else nil
end

--- Shows map `id`'s preview on ImageLabel `label`. True if shown.
function MapPreview.apply(label: any, id: string?): boolean
	local c = MapPreview.content(id)
	if c == nil then
		return false
	end
	label.ImageContent = c
	return true
end

return MapPreview
