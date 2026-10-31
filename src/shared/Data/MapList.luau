-- Registry of the playable maps, in play order. Empires Front (2026-10-31):
--   * the empires: one empire per map, each played in its own era (Data/Eras), free for all or in teams;
--   * the free-for-all maps (`ffa_only`): World and the continents, never played in teams.
-- Terrain lives in ServerScriptService.AirfrontServer.MapData.<module> (server only; clients fetch it
-- through MapFetch) except the default map's (Rome), replicated in ReplicatedStorage.Airfront.Data.Maps
-- so the title screen and solo games start at once.
local MapList = {}

MapList.DEFAULT = "rome"
MapList.LICENSE = "Public domain"
MapList.ATTRIBUTION = "Natural Earth, NOAA"
MapList.CREDITS = "Maps made with Natural Earth and NOAA ETOPO1 data (public domain)."

--- {id, name, module, era, year, width, height, k_lin, categories, multiplayer_frequency,
--- land_tiles, nations (count), replicated, ffa_only} in play order.
MapList.maps = {
	{ id = "rome", name = "Roman Empire", module = "Rome", era = "rome", year = "117 AD", width = 1241, height = 972, k_lin = 1.0, categories = { "featured", "empire", "antiquity" }, multiplayer_frequency = 10, land_tiles = 881342, nations = 63, replicated = true },
	{ id = "persia", name = "Persian Empire", module = "Persia", era = "persia", year = "500 BC", width = 1247, height = 912, k_lin = 1.0, categories = { "featured", "empire", "antiquity" }, multiplayer_frequency = 10, land_tiles = 854416, nations = 56 },
	{ id = "china", name = "Ming China", module = "China", era = "china", year = "1450", width = 1216, height = 972, k_lin = 1.0, categories = { "featured", "empire", "gunpowder" }, multiplayer_frequency = 10, land_tiles = 678331, nations = 72 },
	{ id = "mongol", name = "Mongol Empire", module = "Mongol", era = "mongol", year = "1279", width = 1159, height = 572, k_lin = 1.0, categories = { "featured", "empire", "medieval" }, multiplayer_frequency = 10, land_tiles = 546014, nations = 53 },
	{ id = "ottoman", name = "Ottoman Empire", module = "Ottoman", era = "ottoman", year = "1566", width = 1119, height = 836, k_lin = 1.0, categories = { "featured", "empire", "gunpowder" }, multiplayer_frequency = 10, land_tiles = 743925, nations = 52 },
	{ id = "russia", name = "Russian Empire", module = "Russia", era = "russia", year = "1914", width = 1394, height = 630, k_lin = 1.0, categories = { "featured", "empire", "industrial" }, multiplayer_frequency = 10, land_tiles = 610970, nations = 63 },
	{ id = "inca", name = "Inca Empire", module = "Inca", era = "inca", year = "1500", width = 1165, height = 1420, k_lin = 1.0, categories = { "featured", "empire", "americas" }, multiplayer_frequency = 10, land_tiles = 587124, nations = 54 },
	{ id = "aztec", name = "Aztec Empire", module = "Aztec", era = "aztec", year = "1500", width = 1435, height = 856, k_lin = 1.0, categories = { "featured", "empire", "americas" }, multiplayer_frequency = 10, land_tiles = 349134, nations = 55 },
	{ id = "mali", name = "African Empires", module = "Mali", era = "mali", year = "1400", width = 1489, height = 1332, k_lin = 1.0, categories = { "featured", "empire", "africa" }, multiplayer_frequency = 10, land_tiles = 963230, nations = 65 },
	{ id = "world", name = "World", module = "World", era = "britain", year = "1897", width = 2000, height = 1000, k_lin = 1.0, categories = { "featured", "empire", "industrial", "world" }, multiplayer_frequency = 10, land_tiles = 689018, nations = 89, ffa_only = true },
	{ id = "europe", name = "Europe", module = "Europe", era = "nations", year = "1914", width = 1422, height = 1254, k_lin = 1.0, categories = { "featured", "continental", "europe" }, multiplayer_frequency = 10, land_tiles = 831821, nations = 48, ffa_only = true },
	{ id = "africa", name = "Africa", module = "Africa", era = "nations", year = "1914", width = 1489, height = 1332, k_lin = 1.0, categories = { "featured", "continental", "africa" }, multiplayer_frequency = 10, land_tiles = 963230, nations = 45, ffa_only = true },
	{ id = "northamerica", name = "North America", module = "NorthAmerica", era = "nations", year = "1914", width = 1655, height = 1224, k_lin = 1.0, categories = { "featured", "continental", "north_america" }, multiplayer_frequency = 10, land_tiles = 738172, nations = 50, ffa_only = true },
	{ id = "southamerica", name = "South America", module = "SouthAmerica", era = "nations", year = "1914", width = 1165, height = 1420, k_lin = 1.0, categories = { "featured", "continental", "south_america" }, multiplayer_frequency = 10, land_tiles = 587124, nations = 36, ffa_only = true },
}

local by_id: { [string]: any } = {}
for _, m in MapList.maps do
	by_id[m.id] = m
end

--- Registry row of map `id` (nil if unknown).
--- (a size suffix — "world@80", see WorldMap.split_id — is ignored)
function MapList.get(id: string): any
	return by_id[string.match(id, "^(.-)@%d+$") or id]
end

--- True when map `id` is played free for all only (never in a team game).
function MapList.ffa_only(id: string): boolean
	local m = MapList.get(id)
	return m ~= nil and m.ffa_only == true
end

return MapList
