--!strict
-- Empires Front: which era is in play. A process plays one map at a time (a server hosts one match; a
-- client shows one), so the era is process-wide: binding a map (Sim.new, GameState.new / set_map) sets
-- its era (Data/MapList / the map data's `era`), which rebuilds the rules tables in place (Core/Rules
-- rebuild_for_era) and tells listeners (client/EraText swaps the UI's words).
local Eras = require("../Data/Eras")
local MapList = require("../Data/MapList")
local Rules = require("./Rules")

local Era = {}

local listeners: { (string?) -> () } = {}

--- The active era id (nil: none yet).
function Era.id(): string?
	return Eras.active
end

--- The active era table (Data/Eras), or nil.
function Era.current(): any
	return Eras.current()
end

--- Calls `fn(era_id)` whenever the era changes.
function Era.on_change(fn: (string?) -> ())
	table.insert(listeners, fn)
end

function Era.set(id: string?)
	if id ~= nil and Eras.get(id) == nil then
		id = nil
	end
	if Eras.active == id then
		return
	end
	Eras.active = id
	Rules.rebuild_for_era()
	for _, fn in listeners do
		task.spawn(fn, id)
	end
end

--- The era of map `map` (a WorldMap, or a map id).
function Era.of_map(map: any): string?
	if type(map) == "string" then
		local row = MapList.get(map)
		return if row ~= nil then row.era else nil
	elseif type(map) == "table" then
		if type(map.era) == "string" then
			return map.era
		end
		if type(map.meta) == "table" and type(map.meta.era) == "string" then
			return map.meta.era
		end
		if type(map.id) == "string" then
			local row = MapList.get(map.id)
			return if row ~= nil then row.era else nil
		end
	end
	return nil
end

function Era.set_for_map(map: any)
	Era.set(Era.of_map(map))
end

return Era
