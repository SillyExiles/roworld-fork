-- Empires Front (2026-11-06): each era map has its own building glyphs (UI/EraBuildings) and ships
-- (Map/ShipData): every kind present, 16 x 16 white-on-clear rows, ship rows of palette letters.
-- usage: luau tests/ef/era_art.luau (from tests/ef)
local E = require("../../src/client/UI/EraBuildings")
local S = require("../../src/client/Map/ShipData")
local fails = 0
local function unrle(row: string): string
	return (string.gsub(row, "(%d+)(%D)", function(n, c) return string.rep(c, tonumber(n)) end))
end
local eras = {}
for m, e in E.by_map do eras[e] = true end
for e in eras do
  for k in E.kinds do
    local g = E.glyphs[k .. "_" .. e]
    if g == nil or #g ~= 16 then print("missing/short", k, e) fails += 1
    else for _, r in g do if #r ~= 16 or r:find("[^W%.]") then print("bad row", k, e, r) fails += 1 end end end
  end
end
local styles = { "ancient","greek","dhow","niger","galley","junk","yuan","japan","canoe","raft","steam","victorian","sail" }
for _, st in styles do
  for _, kind in { "warship", "trade", "transport" } do
    local d = S[st] and S[st][kind]
    if d == nil or #d ~= S.size then print("ship missing", st, kind) fails += 1
    else for _, r0 in d do
      local r = unrle(r0)
      if #r ~= S.size then fails += 1 print("ship row", st, kind) end
      for i = 1, #r do local c = r:sub(i, i) if c ~= "." and S.palette[c] == nil then fails += 1 print("bad letter", c) break end end
    end end
  end
end
print(if fails == 0 then "all ok" else fails .. " FAILED")
