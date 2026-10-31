--!nonstrict
-- Empires Front: the achievements. Each is earned once for good (saved by server/Achievements in a
-- DataStore) and, when its `badge` is set, also awards that Roblox badge.
--
-- TO ADD THE BADGES: create one badge per achievement in the Creator Dashboard (Creations > the game >
-- Engagement > Badges; images in Documents/EmpiresFront/badges, made by tools/make_badges.py), then paste
-- each badge's id into `badge` below. A player who earned an achievement before its badge existed gets the
-- badge the next time they join.
--
-- `icon`: a UI/PixelIcons glyph; `tier`: the medal's metal (bronze, silver, gold).
local Achievements = {}

export type Achievement = {
	id: string,
	title: string,
	text: string,
	icon: string,
	tier: string,
	badge: number,
}

Achievements.list = {
	{ id = "first_capital", title = "Founding Father", text = "Place your capital on any map.", icon = "city", tier = "bronze", badge = 0 },
	{ id = "first_city", title = "Urbs", text = "Build your first City.", icon = "city", tier = "bronze", badge = 0 },
	{ id = "first_mine", title = "Into the Mountains", text = "Dig your first Mine.", icon = "mine", tier = "bronze", badge = 0 },
	{ id = "first_market", title = "Merchant Prince", text = "Open your first Market.", icon = "market", tier = "bronze", badge = 0 },
	{ id = "trade_pact", title = "Silk & Silver", text = "Sign a Trade Pact with an ally.", icon = "pact_trade", tier = "bronze", badge = 0 },
	{ id = "defense_pact", title = "Brothers in Arms", text = "Sign a Defence Pact with an ally.", icon = "pact_defense", tier = "bronze", badge = 0 },
	{ id = "forge_max", title = "Master Smith", text = "Reach the fourth Forge tier in one match.", icon = "forge", tier = "silver", badge = 0 },
	{ id = "admiral", title = "Admiral of the Fleet", text = "Command 5 warships at once.", icon = "warship", tier = "silver", badge = 0 },
	{ id = "conqueror", title = "Conqueror", text = "Wipe a nation off the map.", icon = "sword", tier = "silver", badge = 0 },
	{ id = "tycoon", title = "Tycoon", text = "Hold 1M gold at once.", icon = "market", tier = "silver", badge = 0 },
	{ id = "ore_baron", title = "Ore Baron", text = "Hold 1,000 Ore at once.", icon = "ore", tier = "silver", badge = 0 },
	{ id = "land_10", title = "Warlord", text = "Hold 10% of the land.", icon = "sword", tier = "silver", badge = 0 },
	{ id = "land_25", title = "Emperor", text = "Hold 25% of the land.", icon = "crown", tier = "gold", badge = 0 },
	{ id = "glory", title = "Glory Restored", text = "Win through the empire's historic objective.", icon = "laurel", tier = "gold", badge = 0 },
	{ id = "domination", title = "Master of the World", text = "Win by holding 80% of the land.", icon = "crown", tier = "gold", badge = 0 },
	{ id = "win_rome", title = "Caesar", text = "Win a match on the Roman Empire.", icon = "laurel", tier = "gold", badge = 0 },
	{ id = "win_persia", title = "King of Kings", text = "Win a match on the Persian Empire.", icon = "laurel", tier = "gold", badge = 0 },
	{ id = "win_mongol", title = "Great Khan", text = "Win a match on the Mongol Empire.", icon = "laurel", tier = "gold", badge = 0 },
	{ id = "win_china", title = "Son of Heaven", text = "Win a match on Ming China.", icon = "laurel", tier = "gold", badge = 0 },
	{ id = "win_ottoman", title = "The Magnificent", text = "Win a match on the Ottoman Empire.", icon = "laurel", tier = "gold", badge = 0 },
	{ id = "win_spain", title = "Conquistador", text = "Win a match on the Spanish Empire.", icon = "laurel", tier = "gold", badge = 0 },
	{ id = "all_empires", title = "Empire of Empires", text = "Win on every map.", icon = "crown", tier = "gold", badge = 0 },
}

local by_id: { [string]: any } = {}
for i, a in Achievements.list do
	a.order = i
	by_id[a.id] = a
end

function Achievements.get(id: string): any
	return by_id[id]
end

--- The map wins that make up "all_empires".
Achievements.MAP_WINS = { "win_rome", "win_persia", "win_mongol", "win_china", "win_ottoman", "win_spain" }

Achievements.TIER_COLORS = {
	bronze = Color3.fromRGB(205, 127, 50),
	silver = Color3.fromRGB(196, 206, 220),
	gold = Color3.fromRGB(245, 196, 43),
}

return Achievements
