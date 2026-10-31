--!nonstrict
-- Empires Front: achievements on the server. Clients notice what they earned (client/Achievements watches
-- their match) and tell the server, which saves it for good (DataStore "EF_Achievements_v1", key = user
-- id) and awards the achievement's Roblox badge when it has one (Data/Achievements `badge`). On join a
-- player gets the list of what they own, and any badge added since they earned its achievement.
--
-- Remotes (ReplicatedStorage.EmpiresFrontNet): GetAchievements (RemoteFunction: -> { id }) and
-- AchievementUnlocked (RemoteEvent: client -> server (id); server -> client (id) once saved).
local BadgeService = game:GetService("BadgeService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Achievements = require(RS:WaitForChild("Airfront"):WaitForChild("Data"):WaitForChild("Achievements")) :: any

local Server = {}

Server.STORE = "EF_Achievements_v1"
--- unlock requests a player may send a minute
Server.MAX_PER_MINUTE = 30

local store: any = nil
local owned: { [Player]: { [string]: boolean } } = {}
local budget: { [Player]: { n: number, t: number } } = {}

local function key(p: Player): string
	return "u" .. tostring(p.UserId)
end

local function load(p: Player): { [string]: boolean }
	local out = {}
	if store ~= nil then
		local ok, data = pcall(function()
			return store:GetAsync(key(p))
		end)
		if ok and type(data) == "table" then
			for _, id in data do
				if type(id) == "string" and Achievements.get(id) ~= nil then
					out[id] = true
				end
			end
		end
	end
	return out
end

local function save(p: Player)
	if store == nil then
		return
	end
	local list = {}
	for id in owned[p] or {} do
		table.insert(list, id)
	end
	task.spawn(function()
		pcall(function()
			store:UpdateAsync(key(p), function(old)
				local merged = {}
				local seen = {}
				for _, id in (if type(old) == "table" then old else {}) do
					if type(id) == "string" and not seen[id] then
						seen[id] = true
						table.insert(merged, id)
					end
				end
				for _, id in list do
					if not seen[id] then
						seen[id] = true
						table.insert(merged, id)
					end
				end
				return merged
			end)
		end)
	end)
end

local function award_badge(p: Player, a: any)
	local badge = tonumber(a.badge) or 0
	if badge <= 0 or p.Parent ~= Players then
		return
	end
	task.spawn(function()
		local ok, has = pcall(function()
			return BadgeService:UserHasBadgeAsync(p.UserId, badge)
		end)
		if ok and not has then
			pcall(function()
				BadgeService:AwardBadge(p.UserId, badge)
			end)
		end
	end)
end

function Server.start()
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(Server.STORE)
	end)
	store = if ok then s else nil
	local folder = RS:FindFirstChild("EmpiresFrontNet") or Instance.new("Folder")
	folder.Name = "EmpiresFrontNet"
	folder.Parent = RS
	local get = Instance.new("RemoteFunction")
	get.Name = "GetAchievements"
	get.Parent = folder
	local unlocked = Instance.new("RemoteEvent")
	unlocked.Name = "AchievementUnlocked"
	unlocked.Parent = folder

	local function joined(p: Player)
		if owned[p] ~= nil then
			return
		end
		owned[p] = load(p)
		-- badges created after the achievement was earned
		for id in owned[p] do
			award_badge(p, Achievements.get(id))
		end
	end
	Players.PlayerAdded:Connect(function(p)
		task.spawn(joined, p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(joined, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		owned[p] = nil
		budget[p] = nil
	end)

	get.OnServerInvoke = function(p: Player)
		local t0 = os.clock()
		while owned[p] == nil and os.clock() - t0 < 10 do
			task.wait(0.1)
		end
		local list = {}
		for id in owned[p] or {} do
			table.insert(list, id)
		end
		return list
	end

	unlocked.OnServerEvent:Connect(function(p: Player, id: any)
		if type(id) ~= "string" then
			return
		end
		local a = Achievements.get(id)
		local mine = owned[p]
		if a == nil or mine == nil or mine[id] then
			return
		end
		local now = os.clock()
		local b = budget[p]
		if b == nil or now - b.t > 60 then
			b = { n = 0, t = now }
			budget[p] = b
		end
		b.n += 1
		if b.n > Server.MAX_PER_MINUTE then
			return
		end
		mine[id] = true
		save(p)
		award_badge(p, a)
		unlocked:FireClient(p, id)
	end)
end

return Server
