-- Empires Front (2026-11-07): the interface's translations (client/Lang): exact entries, upper-cased
-- headers, templates with values (in order and by {n}), texts cut at their separators, and every
-- dictionary entry's own key translating to its value. usage: luau tests/ef/lang.luau
local country = "BR"
local Lang = require("../../src/client/Lang")
local DATA = {
	Pt = require("../../src/client/Lang/Pt"),
	Es = require("../../src/client/Lang/Es"),
	Ru = require("../../src/client/Lang/Ru"),
	Keys = require("../../src/client/Lang/Keys"),
}
Lang.services = function()
	return { LocalPlayer = { LocaleId = "en-us" } }, { GetCountryRegionForPlayerAsync = function() return country end }
end
Lang.find = function(name) return DATA[name] end
local fails = 0
local function expect(got, want, what)
	local ok = got == want
	print((if ok then "  ok   " else "FAIL ") .. what .. (if ok then "" else ("\n       got  " .. tostring(got) .. "\n       want " .. tostring(want))))
	if not ok then fails += 1 end
end
expect(Lang.choose("auto"), "pt", "an English account playing from Brazil gets Portuguese")
country = "US"
expect(Lang.choose("auto"), "en", "from the US: English")
expect(Lang.choose("ru"), "ru", "the setting wins")
Lang.set("pt")
expect(Lang.code(), "pt", "Portuguese loaded")
expect(Lang.tr("Leaderboard"), "Ranking", "exact entry")
expect(Lang.tr("SETTINGS"), "CONFIGURAÇÕES", "upper-case header")
expect(Lang.tr("Language"), "Idioma", "Language")
expect(Lang.tr("Language: Auto · Português"), "Idioma: Automático · Português", "the settings button, cut at its separators")
expect(Lang.tr("Rome is attacking you!"), "Rome está atacando você!", "a template keeps the nation's name")
expect(Lang.tr("You paid the Thessaly Rebels 12K gold: Thessaly returns to your empire with 3K troops"),
	"Você pagou 12K de ouro a Thessaly Rebels: Thessaly volta ao seu império com 3K tropas", "{n} and the values left, in order")
expect(Lang.tr("Gold:"), "Ouro:", "trailing punctuation")
expect(Lang.tr("Unlock Mega Nuke in the Arsenal"), "Desbloqueie Mega Bombarda no Arsenal", "a %s value is translated too")
expect(Lang.tr("Warships"), "Navios de Guerra", "plural name")
expect(Lang.tr("Goal 80%"), "Meta 80%", "a percent sign")
expect(Lang.tr("Some text nobody wrote"), "Some text nobody wrote", "unknown text stays")
Lang.set("ru")
expect(Lang.tr("PLAY SOLO"), "ИГРАТЬ ОДНОМУ", "Russian")
expect(Lang.upper("Привет, мир"), "ПРИВЕТ, МИР", "Cyrillic upper case")
-- every exact entry of every dictionary translates to itself
for _, c in { "pt", "es", "ru" } do
	Lang.set(c)
	local data = DATA[string.upper(string.sub(c, 1, 1)) .. string.sub(c, 2)]
	local bad = 0
	for i, k in DATA.Keys do
		local v = data.values[i]
		if v == "" then continue end
		if not string.find(k, "%%[%-%d%.]*[sdfi]") and not string.find(k, "{[%w_]+}") then
			if Lang.tr(k) ~= v then
				bad += 1
				if bad <= 5 then print("       " .. c .. ": " .. k .. " -> " .. Lang.tr(k)) end
			end
		end
	end
	expect(bad, 0, c .. ": every exact entry")
end
Lang.set("en")
expect(Lang.tr("Leaderboard"), "Leaderboard", "English is left alone")
print(if fails == 0 then "ALL OK" else (fails .. " FAILED"))
