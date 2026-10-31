--!strict
-- Empires Front: the Empire Shop (client/EmpireShop). Flags of empires and nations that tile over your
-- land instead of its plain colour (territory skins: Data/EmpireFlags, made by tools/make_empire_flags.py).
--
--   Stars   every match pays Stars (Data/Stars, server/Rewards); most flags sell for Stars, by tier.
--   Robux   a few flags (Rome, the Mongols, the Ottomans) also sell for Robux (developer products: set
--           their ids below); they can be bought with Stars too, at a higher price.
--   Banner  a gamepass: your flag also flies beside your name on the map and the leaderboard.
--
-- TO SELL FOR ROBUX: in the Creator Dashboard (the game > Monetization) create
--   * one Developer Product per Robux flag (Roman, Mongol, Ottoman Empire: 149 Robux each) and paste its id
--     in ROBUX_PRODUCTS;
--   * one Game Pass "Imperial Banner" (149 Robux) and paste its id in BANNER_GAMEPASS.
-- With an id of 0 the button says "Coming soon" (in Studio the prompt still opens as a test purchase).
local IS_ROBLOX = typeof(game) == "Instance"
local Flags: any = if IS_ROBLOX
	then require((script :: any).Parent.EmpireFlags)
	else (require :: any)("./EmpireFlags")

local EmpireShop = {}

--- Developer product ids of the Robux flags (key -> id); 0 = not created yet.
EmpireShop.ROBUX_PRODUCTS = {
	mongol = 0,
	ottoman = 0,
	rome = 0,
}

--- The "Imperial Banner" game pass (your flag beside your name); 0 = not created yet.
EmpireShop.BANNER_GAMEPASS = 0
EmpireShop.BANNER_ROBUX = 149

--- Tiers: their colour in the shop and their order.
EmpireShop.TIERS = {
	common = { name = "Common", color = 0x9AA6B2, order = 1 },
	rare = { name = "Rare", color = 0x3D8BFF, order = 2 },
	epic = { name = "Epic", color = 0xA35BFF, order = 3 },
	legendary = { name = "Legendary", color = 0xFFB22E, order = 4 },
}

EmpireShop.PREFIX = "ef_"

--- A flag's cosmetic item id.
function EmpireShop.item_id(key: string): string
	return EmpireShop.PREFIX .. key
end

--- The flag of item id `id` (nil: not an Empire Shop flag).
local by_key: { [string]: any } = {}
for i, f in Flags do
	f.order = i
	by_key[f.key] = f
end
function EmpireShop.flag_of(id: any): any
	if type(id) ~= "string" or string.sub(id, 1, #EmpireShop.PREFIX) ~= EmpireShop.PREFIX then
		return nil
	end
	return by_key[string.sub(id, #EmpireShop.PREFIX + 1)]
end

function EmpireShop.flags(): { any }
	return Flags
end

--- Stars price of item `id` (nil: not sold for Stars).
function EmpireShop.stars_price(id: any): number?
	local f = EmpireShop.flag_of(id)
	if f == nil or (f.stars or 0) <= 0 then
		return nil
	end
	return f.stars
end

--- The developer product id of a Robux flag (0: not created yet; nil: not a Robux flag).
function EmpireShop.product_of(id: any): number?
	local f = EmpireShop.flag_of(id)
	if f == nil or (f.robux or 0) <= 0 then
		return nil
	end
	return EmpireShop.ROBUX_PRODUCTS[f.key] or 0
end

return EmpireShop
