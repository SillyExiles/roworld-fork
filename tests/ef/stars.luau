local Stars = require("../../src/shared/Data/Stars")
local function r(t) return Stars.payout(t, t.mode).total end
print("lost early, poor", r({ spawned = true, left = false, won = false, minutes = 4, shares = 0.3, kills = 0, place = 40, field = 60 }))
print("lost, mid", r({ spawned = true, left = false, won = false, minutes = 12, shares = 1.5, kills = 1, place = 10, field = 60 }))
print("lost, great", r({ spawned = true, left = false, won = false, minutes = 20, shares = 4, kills = 5, place = 2, field = 60 }))
print("won, carried", r({ spawned = true, left = false, won = true, minutes = 15, shares = 0.5, kills = 0, place = 8, field = 60 }))
print("won, mvp", r({ spawned = true, left = false, won = true, minutes = 18, shares = 6, kills = 6, place = 1, field = 60 }))
print("solo easy won", r({ spawned = true, left = false, won = true, minutes = 18, shares = 6, kills = 6, place = 1, field = 60, mode = "solo0" }))
print("left", r({ spawned = true, left = true, won = false, minutes = 8, shares = 1, kills = 0, place = 30, field = 60 }))
