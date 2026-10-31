--!strict
-- Empires Front: the Imperial Crown, a monthly Roblox subscription paid in Robux (Creator Dashboard ->
-- the game -> Monetization -> Subscriptions; Roblox renews and bills it, players cancel it in Roblox's
-- own settings). While subscribed (server/General):
--   * DAILY_STARS Stars every UTC day they play (Purchases.general_perks);
--   * +STARS_BONUS on every match's Stars (server/Rewards: the "general" line);
--   * the month's subscriber flag (SKINS: an Empire Shop flag never sold), theirs to keep;
--   * the Imperial Banner: their flag flies beside their name (as the game pass does).
--
-- (2026-10-31: not offered for now; nothing shows it while ID is "".)
-- TO SELL IT: create the subscription on the dashboard and paste its id ("EXP-...") in ID ("" = not
-- created yet: the shop says "Coming soon").
local IS_ROBLOX = typeof(game) == "Instance"
local Staging: any = if IS_ROBLOX then require((script :: any).Parent.Staging) else (require :: any)("./Staging")

local Subscription = {}

Subscription.ID = ""
Subscription.STAGING = ""
Subscription.NAME = "Imperial Crown"
--- The price set on the dashboard (Robux a month); the interface shows Roblox's own.
Subscription.ROBUX = 299
Subscription.DAILY_STARS = 1500
Subscription.STARS_BONUS = 0.5
--- The General skin of each month ("YYYY-MM", UTC, oldest first): a month without its own gives the
--- latest one before it.
Subscription.SKINS = {
	
}

--- The subscription's id in this experience ("" where there is none).
function Subscription.id(): string
	return if Staging.here() then Subscription.STAGING else Subscription.ID
end

--- The UTC day number of unix time `t`.
function Subscription.day(t: number): number
	return math.floor(t / 86400)
end

--- The General skin of the month of unix time `t`.
function Subscription.skin_for(t: number): string?
	local month = os.date("!%Y-%m", math.floor(t)) :: string
	local skin = nil
	for _, s in Subscription.SKINS do
		if s.month <= month then
			skin = s.skin
		end
	end
	return skin or (if #Subscription.SKINS > 0 then Subscription.SKINS[1].skin else nil)
end

--- What a match's Stars gain (`total` before 2x Stars) for a General: whole QUANTUMs.
function Subscription.bonus(total: number, quantum: number): number
	local q = math.max(quantum, 1)
	return math.floor(math.max(total, 0) * Subscription.STARS_BONUS / q) * q
end

return Subscription
