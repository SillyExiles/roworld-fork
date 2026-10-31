--!strict
-- A new player's first match (2026-10-04: an updated tutorial for new players, designed for phones
-- first, since 90% of the players are on a phone, with its steps drawn from the analytics funnels).
-- The onboarding funnel of the 28 days before it (202,158 new players):
--
--   Joined 100% -> Title 99% -> Match Started 85% -> Spawned 81% -> First Attack 66%
--   -> Survived 3 Min 32% -> Survived 10 Min 24% -> Second Match 21%
--
--   * 14% never start a match: the first match starts by itself, on this device, at once;
--   * 5% never pick a start: a spot is pointed out, and taken for them after AUTO_SPAWN_S;
--   * 19% spawn and never attack: the first step is the first tap, with the place to tap marked;
--   * half of those who attack are gone within 3 minutes, while the AI may not even attack them
--     yet (Rules.HUMAN_GRACE_TICKS): they leave with nothing to do. So the first minutes are a list
--     of small goals with a reward at the end, on a match with fewer tribes in the way (TRIBES)
--     and the gentlest AI (DIFFICULTY).
--
-- The match is an ordinary solo match otherwise: it goes on after the last step. client/UI/Tutorial
-- runs the steps; server/Analytics logs them as the "Tutorial" funnel (FUNNEL).
--
-- Empires Front (2026-10-31): the tutorial was reworked for the empires. It teaches founding the
-- empire, claiming land, letting the army refill, the first war, the Attack bar, the land itself (hills
-- and mountains are natural walls: an `info` step, read and dismissed) and the first City. It pays no
-- Stars any more: the reward is the empire, and the last card says what to do next.
local Tutorial = {}

--- Stars for finishing it: none (2026-10-31). Kept at 0 for old callers.
Tutorial.STARS = 0
--- The last card (two short lines).
Tutorial.DONE_TEXT = "Your empire is ready!\nGrow, ally and conquer to win"
--- Tribes on the tutorial's map (a normal match has Rules.DEFAULT_TRIBES, 400): room to grow fast.
Tutorial.TRIBES = 60
Tutorial.DIFFICULTY = 0
--- Ticks (10 a second) from placing the capital to the match starting. A solo match waits 50, but
--- (2026-10-04) a 5 s wait after placing the capital confused new players, so the tutorial's round
--- starts much sooner.
Tutorial.COUNTDOWN_TICKS = 10
--- The Attack bar while the tutorial runs: it starts at the default and stops at RATIO_CAP (the
--- player's saved setting could leave it at about 85%, which is too much; 2026-10-04).
--- Empires Front (2026-10-31): no cap (1.0) and no floor (0): in Studio and for every new player the tutorial
--- held the Attack bar at 50% and kept a quarter of the army's CAP at home, so a big army could send nothing.
Tutorial.RATIO_CAP = 1.0
--- Keeps players from going too low in troop count (2026-10-04): while the tutorial
--- runs an order leaves at least TROOP_FLOOR of the army's cap at home (it is trimmed to what may go,
--- and refused when nothing may). The floor holds from the first time the army reaches FLOOR_ARM of
--- its cap (a new nation starts below it), or from FLOOR_ARM_S seconds into play, whichever comes
--- first (floor_armed).
---   * The seconds since 2026-10-27: a new nation starts at about a fifth of its cap, so a player who
---     sent every troop as it came never reached FLOOR_ARM, and the floor never held for the very
---     players it is for.
---   * Not before the FLOOR_FROM step (2026-10-27): on "grow" it refused taps the card asked for
---     ("Troops low. Let them grow back" under the card's "Keep tapping empty land to grow"), since
---     the cap climbs with every tile taken. Grow lost 11.6% of the players who reached it, the most
---     of any step, and 110,302 of its 175,898 left with Skip (the week to 2026-10-26). Before the
---     first neighbour there is nobody to fear, and the Attack bar's cap (RATIO_CAP) still holds.
Tutorial.TROOP_FLOOR = 0.0
Tutorial.FLOOR_ARM = 0.35
Tutorial.FLOOR_ARM_S = 10
Tutorial.FLOOR_FROM = "attack"
Tutorial.FLOOR_REASON = "Troops low. Let them grow back"
--- A new player's first ROOKIE_MATCHES matches (the tutorial's among them) keep a floor under the
--- army after the tutorial too (2026-10-27): an order leaves ROOKIE_FLOOR of the army's cap at home,
--- from the time it arms (floor_armed; client/UI/UIAdvisor.check_floor). An army
--- spent below a fifth of its cap all but loses the match, and 23% of matches ended within their
--- first 3 minutes (Match funnel, the week to 2026-10-26). The first order held back in a match
--- says why (Coach "floor").
--- Empires Front (2026-10-31): off. The floor is a share of the army's CAP, so once the land grew a
--- nation with 16k troops at home and many more at war could send nothing at all ("Troops low" /
--- "No troops available" on every Attack-bar stop). Only the tutorial keeps its floor while it runs.
Tutorial.ROOKIE_MATCHES = 0
Tutorial.ROOKIE_FLOOR = 0.2

--- True while a player with `matches_before` matches before this one is still a new player.
function Tutorial.rookie(matches_before: number): boolean
	return matches_before < Tutorial.ROOKIE_MATCHES
end

--- True once the floor under a new player's army holds: the army has `troops` of its `cap`, at
--- FLOOR_ARM of it or more, or the match has been played `played_s` seconds, FLOOR_ARM_S or more.
function Tutorial.floor_armed(troops: number, cap: number, played_s: number): boolean
	return played_s >= Tutorial.FLOOR_ARM_S or (cap > 0 and troops >= Tutorial.FLOOR_ARM * cap)
end
--- Seconds on the spawn step before a start is picked for the player.
Tutorial.AUTO_SPAWN_S = 12
--- "grow": one expansion, and the card teaches the rhythm: let the troops refill, then expand. Never
--- "keep tapping" (2026-10-27: the card said "Keep tapping empty land to grow", which is bad advice:
--- an order sent on an emptied army leaves the nation open, and a small army regrows slowly). While
--- the army is under GROW_READY of its cap the card says to let the troops refill, its bar fills
--- towards ready (Tutorial.refill: about 7 s after the "expand" step's order on open land) and the
--- mark is on the troop count; once ready it asks for the expansion. One sent before the bar is full
--- counts too, and its green card says `early` (let the bar fill next time) for EARLY_S.
---   * v111 (2026-10-27) asked for GROW_TAPS = 2 expansions sent ready, and 3x the land, with no bar
---     while the troops refilled: Skip on this step went up by about 60% a match (06:00-16:00 UTC
---     against the day before).
---   * v112 (2026-10-27) asked for one, sent with the bar full; one sent before spent the refill and
---     did not count. Of the players who made the first tap, 79% finished the step (88% before
---     v111) and 58% finished the tutorial (63%) (Tutorial funnel, Oct 28-29 against Oct 24-26):
---     a wait the player can't get past loses them. So since 2026-10-30 the wait is advice.
Tutorial.GROW_TAPS = 1
Tutorial.GROW_READY = 0.3
Tutorial.EARLY_S = 2.0
--- "attack": passed over when nobody borders the player this long after the step began.
Tutorial.CONTACT_WAIT_S = 25
--- The Attack bar's step asks for one stop of it, RATIO_GOAL (the next one up from where the bar
--- starts), left there for RATIO_HOLD_S: one tap on the stop the mark points at. Never more: since
--- 2026-10-04 the tutorial never encourages a 100% attack (an attack with everything leaves the
--- nation empty). Above RATIO_HIGH the card says to go back.
---   * Until 2026-10-08 it asked for 27% to 45% of a slider that ran from 1% to 100%, held for half
---     a second: on a phone that was 17 px of a 96 px track. 19.4% of the players who reached the
---     step left on it, the most of any step (Tutorial funnel, 2026-10-07), so the
---     step was made easier.
---   * Nobody waits on it past RATIO_MAX_S (the other steps: STEP_MAX_S).
--- (Empires Front v9: the 35% stop became 100%, so the goal is the 50% stop)
Tutorial.RATIO_GOAL = 0.5
Tutorial.RATIO_LOW = 0.45
Tutorial.RATIO_HIGH = 0.55
Tutorial.RATIO_HOLD_S = 0.2
Tutorial.RATIO_MAX_S = 30
Tutorial.RATIO_TOO_MUCH = "Too many! Tap 50%"
--- A step nobody finishes in this long is passed over (the player is never stuck on one).
Tutorial.STEP_MAX_S = 75
--- With no order for this long the pointer shows where to tap again.
Tutorial.NUDGE_S = 5

--- The steps, in order. `touch` / `desktop`: what the card says; `%s` is the neighbour's name.
--- `info`: nothing to do but read it; the card's button says GOT IT and moves on (or INFO_S passes).
--- `mark`: what the tap mark says instead of "Tap here".
Tutorial.INFO_S = 9
Tutorial.STEPS = {
	{ id = "spawn", touch = "Tap the map to found your empire", desktop = "Click the map to found your empire" },
	{ id = "expand", touch = "Tap the land next to you to claim it", desktop = "Click the land next to you to claim it" },
	{
		id = "grow",
		touch = "Troops ready: tap empty land again",
		desktop = "Troops ready: click empty land again",
		wait = "Let your troops refill before you expand",
		-- (the green card of an expansion sent while they refilled)
		early = "Done! Next time, let the bar fill",
		bar = true,
	},
	-- (the neighbour before the slider: a first attack at the slider's 20% leaves an army at home; in
	-- the first order of steps a new player dragged it to 100% and sent everything)
	{
		id = "attack",
		touch = "Tap %s, then tap again to attack",
		desktop = "Click %s's land to attack them",
	},
	{
		id = "ratio",
		touch = "Tap 50% below. Keep troops home!",
		desktop = "Click 50% on the Attack bar. Keep troops home!",
		max_s = Tutorial.RATIO_MAX_S,
	},
	{
		id = "terrain",
		info = true,
		touch = "Hills and mountains are natural walls: armies cross them slowly",
		desktop = "Hills and mountains are natural walls: armies cross them slowly",
		mark = "Mountains",
		max_s = Tutorial.INFO_S,
	},
	{
		id = "city",
		touch = "Open BUILD, pick City, tap your land",
		desktop = "Pick City (1) and click your land",
		note = "Here is gold for your first City",
	},
}

--- The "Tutorial" funnel's steps (Creator Dashboard): 1 is the match starting, then one a step,
--- then finishing. A step passed over is not logged.
Tutorial.FUNNEL =
	{ "Started", "Spawned", "First Tap", "Grew", "Attacked", "Used Slider", "Saw Terrain", "Built City", "Completed" }

--- The funnel step of finishing step `id` (2..7), or nil.
function Tutorial.funnel_step(id: string): number?
	for i, s in Tutorial.STEPS do
		if s.id == id then
			return i + 1
		end
	end
	return nil
end

--- True for a player who has never played: no tutorial state, no match counted, no tip seen.
--- `ui` is the saved [ui] settings, `stats` the saved [stats] ({ matches }).
function Tutorial.is_new(ui: any, stats: any): boolean
	local u = if type(ui) == "table" then ui else {}
	local s = if type(stats) == "table" then stats else {}
	if type(u.tutorial) == "string" and u.tutorial ~= "" then
		return false
	end
	if (tonumber(s.matches) or 0) > 0 then
		return false
	end
	if type(u.tips_seen) == "table" and next(u.tips_seen) ~= nil then
		return false
	end
	return true
end

--- "grow"'s bar while the army refills: how far `troops` are towards GROW_READY of `cap` (0..1), and
--- never below `shown` (what the bar already shows): the cap climbs as the expansion's land comes in,
--- and a bar that slides back while nobody did anything reads as broken. (An order sent meanwhile
--- does empty it: the client passes no `shown` then.)
function Tutorial.refill(troops: number, cap: number, shown: number?): number
	local need = Tutorial.GROW_READY * cap
	local f = if need > 0 then math.clamp(troops / need, 0, 1) else 1
	return math.max(f, shown or 0)
end

--- Where step `id` is in STEPS, or nil.
function Tutorial.step_index(id: string): number?
	for i, s in Tutorial.STEPS do
		if s.id == id then
			return i
		end
	end
	return nil
end

return Tutorial
