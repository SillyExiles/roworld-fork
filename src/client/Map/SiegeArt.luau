--!native
-- Empires Front (2026-11-06): the siege weapons in flight, in the arms of the era in play (Map/SiegeData:
-- 16 x 16 pixel art in colour, tools/make_siege_art.py): stones from onagers and slings, cannonballs,
-- fire rockets, Great War shells; fire pots, fire arrows and incendiary shells; plague bundles.
-- Drawn untinted (Map/UnitLayer): the trail behind them carries the owner's colour. EditableImages made
-- once per sprite.
local AssetService = game:GetService("AssetService")
local RS = game:GetService("ReplicatedStorage")
local Era = require(RS:WaitForChild("Airfront"):WaitForChild("Core"):WaitForChild("Era")) :: any
local Defs = require(RS:WaitForChild("Airfront"):WaitForChild("Core"):WaitForChild("Defs")) :: any
local SiegeData = require(script.Parent:WaitForChild("SiegeData")) :: any

local SiegeArt = {}

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
		if n < buffer.len(out) then
			buffer.writeu8(out, n, v // 65536)
		end
		n += 1
		if vc ~= nil and n < buffer.len(out) then
			buffer.writeu8(out, n, (v // 256) % 256)
			n += 1
		end
		if vd ~= nil and n < buffer.len(out) then
			buffer.writeu8(out, n, v % 256)
			n += 1
		end
	end
	return out
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
	local src = unb64(data)
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
