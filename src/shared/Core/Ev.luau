--!strict
-- Port of scripts/core/ev.gd: event type ids carried in the "ev" array of a Sim delta. Each event
-- is a 1-based Luau array whose first element is one of these ids, followed by the arguments in
-- GDScript order (DESIGN.md §4): { Ev.OWNER_ADD, id, name, color, kind, flags }. Values are part
-- of the network protocol, so never renumber them.
local Ev = {}

Ev.OWNER_ADD = 0 -- id, name, color, kind, flags
Ev.OWNER_OUT = 1 -- id, killer_id
Ev.PHASE = 2 -- phase, ticks_left
Ev.SPAWNED = 3 -- id, tile
Ev.STRUCT_ADD = 4 -- sid, kind, owner, tile
Ev.STRUCT_OWNER = 5 -- sid, new_owner
Ev.STRUCT_DEL = 6 -- sid
Ev.ROAD_ADD = 7 -- rid, sid_a, sid_b, tiles  (a railroad: its tile path from a's end to b's end)
Ev.ROAD_DEL = 8 -- rid (, sid_a, sid_b)
Ev.UNIT_ADD = 9 -- uid, kind, owner, path, start_tick, ticks_per_tile_x100, troops
Ev.UNIT_MOVE = 10 -- uid, tile
Ev.UNIT_DEL = 11 -- uid, reason
Ev.NUKE = 12 -- uid, kind, owner, from_tile, to_tile, launch_tick, flight_ticks
Ev.BOOM = 13 -- uid, kind, tile, radius_tiles, owner
Ev.ATTACK = 14 -- aid, attacker, target, troops, anchor_tile, retreating  (re-sent to update)
Ev.ATTACK_END = 15 -- aid
Ev.ALLY_REQ = 16 -- from, to, created_tick
Ev.ALLY = 17 -- a, b, expires_at
Ev.ALLY_END = 18 -- a, b, traitor_id, expired
Ev.MSG = 19 -- to_owner (-1 all), category, text
Ev.GAME_OVER = 20 -- winner_id, reason
Ev.ALLY_REQ_END = 21 -- from, to   (request answered or expired)
Ev.TRAITOR = 22 -- id, until_tick
Ev.STRUCT_LEVEL = 23 -- sid, level, active_tick  (upgrade, or construction start: active from active_tick)
Ev.SHELL = 24 -- shell_id, shooter_kind (0 warship, 1 defense post), shooter_id (uid / sid), from_tile, target_uid, fire_tick, impact_tick, damage
Ev.UNIT_HP = 25 -- uid, hp, max_hp  (at most once per unit per tick)
Ev.UNIT_VET = 26 -- uid, veterancy_level
Ev.UNIT_STATE = 27 -- uid, state (0 patrolling, 1 retreating, 2 docked / repairing), patrol_tile
Ev.UNIT_PATH = 28 -- uid, path, start_tick, ticks_per_tile_x100  (a warship changed course)
Ev.SAM_LAUNCH = 29 -- sam_sid, nuke_uid, fire_tick, intercept_tick, will_hit  (BOOM radius 0 follows at intercept_tick)
Ev.ALLY_EXT = 30 -- a, b, expires_at, asked  (renewal asked: bit 1 by min(a, b), bit 2 by max(a, b); a renewal resets it to 0)
Ev.CONQUEST = 31 -- conqueror, conquered, gold  (the gold `conqueror` took)
Ev.STRUCT_SHOTS = 32 -- sid, ticks  (SAM / silo: launch or upgrade ticks of its missiles still reloading
--   — each reloads for Rules.SAM / SILO_COOLDOWN_TICKS)

Ev.REINFORCE = 33 -- id, troops, ready_tick  (Reinforcements arrived; the next call is ready at ready_tick)

Ev.BONUS = 34 -- owner, tile, gold  (gold `owner` earned at `tile`, a train's
--   stop at a station. Only for a person, and sent to that person alone)

-- Empires Front
Ev.PACT = 35 -- a, b, kind (1 trade, 2 defence), state (0 proposed by a to b, 1 signed, 2 ended, 3 withdrawn)
Ev.PING = 36 -- to, from, tile, kind (1 attack here, 2 help here)  (a Signal: sent to `to` alone, one
--   event per teammate or ally of `from` and one for `from` itself: Sim.ping)

Ev.UNREST = 37 -- id, unrest 0..100, province tile (-1), warned until tick (0: no warning), province name,
--   then the parts troops, size, lead, far, fresh, calm (Core/SimRevolts; players' own empires only)
Ev.REBEL = 38 -- rid, parent, born_tick, state (0 rising, 1 crushed, 2 bought back, 3 free nation, 4 gone),
--   then while rising what the province is worth (its price): total, land, troops, buildings

Ev.PLAGUE = 39 -- id, until_tick (0: over), source_id, severity x100 (Core/SimNukes: the plague on a nation)
Ev.BLAZE = 40 -- uid, owner, tile, radius_tiles, start_tick, spread_ticks  (fire spreading from `tile`)

--- Number of event ids (ids are 0..COUNT-1).
--- (Empires Front 2026-11-06) a new player (Rules.ROOKIE_MATCHES): safe from the siege weapons, the AI
--- gentler with them (Sim.set_rookie).
Ev.ROOKIE = 41 -- id, on (1 / 0)
--- (Empires Front 2026-11-06) how many times a player sent the plague (its price doubles each time,
--- Rules.PLAGUE_MAX_USES a match).
Ev.PLAGUE_USES = 42 -- id, uses, kind (Defs.N_PLAGUE, or N_FIRERAIN: 2026-11-07)
--- (Empires Front 2026-11-07) the plague's land breaking away: its victim, the free nation (0 before its
--- first tile), where it landed, done (1 / 0), then a few of the tiles it just took (Map/FxLayer.blight).
Ev.BLIGHT = 43 -- victim, rid, origin, done, tiles...
--- (2026-11-07) the rain of fire arrows shot: owner, kind, start_tick, then (from_tile, to_tile, at_tick)
--- for each sheaf of arrows (Core/SimNukes._firerain_land; Map/FxLayer.volley draws them flying)
Ev.VOLLEY = 44
Ev.COUNT = 45

return Ev
