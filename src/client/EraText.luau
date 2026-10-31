--!native
-- Empires Front: every text the player reads, in the words of the era in play (Data/Eras words). The base
-- game names a Warship, an Atom Bomb, a Missile Silo; on the Roman map they are a Quinquereme, an Onager
-- Volley, a Siege Workshop. Rather than touching every label, this watches the PlayerGui's text objects
-- and rewrites their Text when it changes:
--   * one pass per text, longest terms first, matches only on word boundaries (%f), every case of a term
--     (Warship / warship / WARSHIP, and the plural); a replaced word is never matched again;
--   * "a"/"an" before a replaced term follows the new word ("an Atom Bomb" -> "a Fire Rocket");
--   * results are memoised (texts repeat: counters, tooltips), and a text already in the era's words
--     maps to itself, so rewriting Text never loops.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Airfront = RS:WaitForChild("Airfront")
local Eras = require(Airfront:WaitForChild("Data"):WaitForChild("Eras")) :: any
local Era = require(Airfront:WaitForChild("Core"):WaitForChild("Era")) :: any

local EraText = {}

type Rule = { find: string, art: string, pat: string, repl: string, art_new: string }

local rules: { Rule } = {}
local memo: { [string]: string } = {}
local memo_n = 0
local MEMO_MAX = 6000

local function esc(s: string): string
	return (string.gsub(s, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

local function plural(s: string): string
	local last = string.sub(s, -1)
	local last2 = string.sub(s, -2)
	if last == "y" and not string.find("aeiou", string.sub(s, -2, -2), 1, true) then
		return string.sub(s, 1, -2) .. "ies"
	elseif last == "s" or last == "x" or last2 == "sh" or last2 == "ch" then
		return s .. "es"
	end
	return s .. "s"
end

local function article_for(word: string): string
	local c = string.lower(string.sub(word, 1, 1))
	return if c == "a" or c == "e" or c == "i" or c == "o" or c == "u" then "an" else "a"
end

local function add(list: { { string } }, a: string, b: string)
	table.insert(list, { a, b })
end

local function build(id: string?)
	table.clear(rules)
	table.clear(memo)
	memo_n = 0
	local era = Eras.get(id)
	local pairs_: { { string } } = {}
	local src: { { any } } = table.clone(Eras.COMMON_WORDS)
	if era ~= nil then
		for _, w in era.words do
			table.insert(src, w)
		end
	end
	local seen: { [string]: boolean } = {}
	for _, w in src do
		local a, b, bp = w[1], w[2], w[3]
		local forms = { { a, b }, { plural(a), bp or plural(b) } }
		for _, f in forms do
			local x, y = f[1], f[2]
			local variants = { { x, y } }
			-- lower case (not for acronyms like SAM / MIRV)
			if string.lower(x) ~= x and string.upper(x) ~= x then
				table.insert(variants, { string.lower(x), string.lower(y) })
			end
			table.insert(variants, { string.upper(x), string.upper(y) })
			for _, v in variants do
				if not seen[v[1]] then
					seen[v[1]] = true
					add(pairs_, v[1], v[2])
				end
			end
		end
	end
	table.sort(pairs_, function(p, q)
		return #p[1] > #q[1]
	end)
	for _, p in pairs_ do
		local e = esc(p[1])
		table.insert(rules, {
			find = p[1],
			art = "%f[%a]([Aa]n?) " .. e .. "%f[%W]",
			pat = "%f[%w]" .. e .. "%f[%W]",
			repl = p[2],
			art_new = article_for(p[2]),
		})
	end
end

--- `s` in the active era's words.
function EraText.tr(s: string): string
	local m = memo[s]
	if m ~= nil then
		return m
	end
	local out = s
	if #rules > 0 and string.find(s, "%a%a") then
		local tokens: { string } = {}
		for _, r in rules do
			if string.find(out, r.find, 1, true) then
				local repl = r.repl
				local art_new = r.art_new
				out = string.gsub(out, r.art, function(art: string)
					table.insert(tokens, repl)
					local a = if string.sub(art, 1, 1) == "A" then (string.upper(string.sub(art_new, 1, 1)) .. string.sub(art_new, 2)) else art_new
					return a .. " \1" .. #tokens .. "\2"
				end)
				out = string.gsub(out, r.pat, function()
					table.insert(tokens, repl)
					return "\1" .. #tokens .. "\2"
				end)
			end
		end
		if #tokens > 0 then
			out = string.gsub(out, "\1(%d+)\2", function(n: string)
				return tokens[tonumber(n) :: number]
			end)
		end
	end
	if memo_n > MEMO_MAX then
		table.clear(memo)
		memo_n = 0
	end
	memo[s] = out
	memo[out] = out
	memo_n += 2
	return out
end

local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
--- the text the game last set on an object (before our rewrite), and the text we wrote
local orig: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any
local wrote: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any

local function fix(obj: any)
	local t = obj.Text
	if type(t) ~= "string" or t == "" or t == wrote[obj] then
		return
	end
	orig[obj] = t
	local n = EraText.tr(t)
	if n ~= t then
		wrote[obj] = n
		obj.Text = n
	end
end

local function watch(obj: Instance)
	if watched[obj] then
		return
	end
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		watched[obj] = true
		fix(obj)
		obj:GetPropertyChangedSignal("Text"):Connect(function()
			fix(obj)
		end)
	end
end

function EraText.start()
	build(Era.id())
	Era.on_change(function(id: string?)
		build(id)
		-- the texts on screen: rewritten from what the game set, in the new era's words
		for obj, t in orig do
			if (obj :: any).Parent ~= nil then
				local n = EraText.tr(t)
				wrote[obj] = n
				;(obj :: any).Text = n
			end
		end
	end)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, d in pg:GetDescendants() do
		watch(d)
	end
	pg.DescendantAdded:Connect(watch)
end

return EraText
