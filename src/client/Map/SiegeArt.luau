--!native
-- Empires Front (2026-11-06): the siege weapons in flight, in the arms of the era in play (Map/SiegeData:
-- 16 x 16 pixel art in colour, rows of palette letters, tools/make_siege_art.py): stones from onagers
-- and slings, cannonballs, fire rockets, Great War shells; fire pots, fire arrows and incendiary
-- shells; plague bundles.
-- Drawn untinted (Map/UnitLayer): the trail behind them carries the owner's colour. EditableImages made
-- once per sprite.
local AssetService = game:GetService("AssetService")
local RS = game:GetService("ReplicatedStorage")
local Era = require(RS:WaitForChild("Airfront"):WaitForChild("Core"):WaitForChild("Era")) :: any
local Defs = require(RS:WaitForChild("Airfront"):WaitForChild("Core"):WaitForChild("Defs")) :: any
local SiegeData = require(script.Parent:WaitForChild("SiegeData")) :: any

local SiegeArt = {}

--- RGBA bytes of sprite `rows` (palette letters, "." clear).
function SiegeArt.pixels(rows: { string }, n: number, palette: { [string]: { number } }): buffer
	local buf = buffer.create(n * n * 4)
	for y = 0, n - 1 do
		local row = rows[y + 1] or ""
		for x = 0, n - 1 do
			local c = palette[string.sub(row, x + 1, x + 1)]
			if c ~= nil then
				local o = (y * n + x) * 4
				buffer.writeu8(buf, o, c[1])
				buffer.writeu8(buf, o + 1, c[2])
				buffer.writeu8(buf, o + 2, c[3])
				buffer.writeu8(buf, o + 3, 255)
			end
		end
	end
	return buf
end

--- The sprite names munition `kind` (Defs.N_*) wears in the era in play (nil: not a siege weapon).
function SiegeArt.sprite_of(kind: number): string?
	local set = SiegeData.by_era[Era.id() or ""] or SiegeData.by_era.rome
	if kind == Defs.N_ATOM then
		return set.atom
	elseif kind == Defs.N_HYDROGEN then
		return set.hydrogen
	elseif kind == Defs.N_PLAGUE then
		return set.plague
	elseif kind == Defs.N_FIRERAIN then
		return set.firerain or set.hydrogen
	end
	return nil
end

local cache: { [string]: any } = {}

--- Content of sprite `name` (SiegeData.sprites); nil if it can't be made.
function SiegeArt.content_named(name: string): any
	local c = cache[name]
	if c ~= nil then
		return if c == false then nil else c
	end
	local data = SiegeData.sprites[name]
	if data == nil then
		cache[name] = false
		return nil
	end
	local n = SiegeData.size
	local src = SiegeArt.pixels(data, n, SiegeData.palette)
	local ok, img = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(n, n) })
	end)
	if not ok or img == nil then
		cache[name] = false
		return nil
	end
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(n, n), src)
	c = Content.fromObject(img)
	cache[name] = c
	return c
end

--- Content of munition `kind` in flight in the era in play (nil: not a siege weapon, or no image).
function SiegeArt.content(kind: number): any
	local name = SiegeArt.sprite_of(kind)
	return if name ~= nil then SiegeArt.content_named(name) else nil
end

return SiegeArt
