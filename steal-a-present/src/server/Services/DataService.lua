--[[
	DataService.lua
	Loads / saves player profiles with SESSION LOCKING so two servers can never write the
	same player at once (the classic duplication exploit). Autosaves, saves on leave, and
	saves everyone on BindToClose. Falls back to an in-memory store in Studio when API
	access is off so you can still test.

	Public API:
	  DataService.GetProfile(player) -> table | nil
	  DataService.OnLoaded(fn(player, profile))
	  DataService.OnBeforeRelease(fn(player, profile))   -- runs before the leave-save
	  DataService.AddCash(player, amount)  / SpendCash(player, amount) -> bool
	  DataService.AddSnowflakes(player, n) / SpendSnowflakes(player, n) -> bool
	  DataService.HasGamepass(player, key) -> bool
	  DataService.Replicate(player)          -- queue a DataChanged push to the client
	  DataService.Save(player)               -- manual save (rarely needed)
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Parent.Registry)

local DataService = {}

local profiles = {}        -- [userId] = profile
local loadedCallbacks = {}
local beforeReleaseCallbacks = {}
local dirty = {}           -- [player] = true  (needs replication)
local sessionId = HttpService:GenerateGUID(false) .. "|" .. (game.JobId ~= "" and game.JobId or "studio")

---------------------------------------------------------------------------
-- Template + migrations
---------------------------------------------------------------------------
local function template()
	return {
		SchemaVersion = Config.SchemaVersion,
		Cash = Config.StartingCash,
		Snowflakes = Config.StartingSnowflakes,
		Rebirths = 0,
		Strength = 0,
		BonusSlots = 0,
		Presents = {},        -- list of { Id, Key, Rarity, Mutation, Traits = {}, Slot = n, UnwrappedAt }
		Index = {},           -- [presentKey] = true
		IndexSetsClaimed = {},-- [rarity] = true
		Streak = { Count = 0, LastClaimDay = 0 },
		Quests = { Day = 0, List = {} },
		Stats = { Bought = 0, Unwrapped = 0, Stolen = 0, Hits = 0, GrinchWins = 0, GrinchTags = 0,
		          Playtime = 0, CashCollected = 0, Gifts = 0, Locks = 0, BestRarity = 0 },
		Boosts = { LuckUntil = 0, ProteinUntil = 0, LockExtendSeconds = 0 },
		Gamepasses = {},      -- [passKey] = true
		Receipts = {},        -- list of recent receipt ids (dedupe)
		Gifts = { Day = 0, Count = 0, LastGift = 0 },
		PlaytimeGift = { Progress = 0 },
		Pile = 0,             -- uncollected cash sitting at the base
		Traps = {},           -- ["1"] = "IcePatch"
		LastOnline = 0,
		FirstJoin = os.time(),
		Joins = 0,
		Settings = { Music = true, SFX = true },
	}
end

-- Add a function per version bump: migrations[2] upgrades a v1 profile to v2, etc.
local migrations = {
	-- [2] = function(profile) profile.NewField = 0 end,
}

local function migrate(profile)
	local v = profile.SchemaVersion or 1
	while v < Config.SchemaVersion do
		v = v + 1
		local fn = migrations[v]
		if fn then fn(profile) end
		profile.SchemaVersion = v
	end
	Util.Reconcile(profile, template())
	return profile
end

---------------------------------------------------------------------------
-- Store (real DataStore or Studio mock)
---------------------------------------------------------------------------
local store
local useMock = false
local mockData = {}

local function getStore()
	if store then return store end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] GetDataStore failed, using in-memory mock: " .. tostring(result))
		useMock = true
	end
	return store
end

local function updateAsync(key, transform)
	if useMock then
		local new = transform(mockData[key] and Util.DeepCopy(mockData[key]) or nil)
		if new ~= nil then
			mockData[key] = new
		end
		return true, mockData[key]
	end
	local ds = getStore()
	if not ds then
		return false, "no store"
	end
	local ok, result = pcall(function()
		return ds:UpdateAsync(key, transform)
	end)
	if not ok and RunService:IsStudio() then
		warn("[DataService] DataStore error in Studio, switching to in-memory mock. Enable 'Studio Access to API Services' in Game Settings > Security to test real saving. (" .. tostring(result) .. ")")
		useMock = true
		return updateAsync(key, transform)
	end
	return ok, result
end

local function keyFor(userId)
	return "Player_" .. tostring(userId)
end

local function lockIsForeign(data)
	if not data or not data.Lock then return false end
	if data.Lock.Session == sessionId then return false end
	return (os.time() - (data.Lock.Time or 0)) < Config.SessionLockTimeout
end

---------------------------------------------------------------------------
-- Load
---------------------------------------------------------------------------
local function loadProfile(player)
	local key = keyFor(player.UserId)
	local profile
	for attempt = 1, 6 do
		local foreign = false
		local ok, result = updateAsync(key, function(old)
			if lockIsForeign(old) then
				foreign = true
				return nil -- cancel: another live server owns this profile
			end
			local data = old or template()
			data.Lock = { Session = sessionId, Time = os.time() }
			return data
		end)
		if ok and not foreign and type(result) == "table" then
			profile = result
			break
		end
		if foreign then
			-- The previous server is probably still saving the leave; wait a bit and retry.
			task.wait(2 + attempt)
		else
			warn(string.format("[DataService] load attempt %d failed for %s: %s", attempt, player.Name, tostring(result)))
			task.wait(1 + attempt)
		end
		if not player.Parent then return nil end
	end
	if not profile then
		return nil
	end
	migrate(profile)
	profile.Joins = (profile.Joins or 0) + 1
	return profile
end

---------------------------------------------------------------------------
-- Save
---------------------------------------------------------------------------
local function saveProfile(userId, profile, release)
	local key = keyFor(userId)
	local snapshot = Util.DeepCopy(profile)
	if release then
		snapshot.Lock = nil
		snapshot.LastOnline = os.time()
	else
		snapshot.Lock = { Session = sessionId, Time = os.time() }
	end
	snapshot.LastSave = os.time()
	local ok, err = updateAsync(key, function(old)
		if lockIsForeign(old) then
			return nil -- we no longer own it; don't clobber
		end
		return snapshot
	end)
	if not ok then
		warn("[DataService] save failed for " .. tostring(userId) .. ": " .. tostring(err))
	end
	return ok
end

function DataService.Save(player)
	local profile = profiles[player.UserId]
	if profile then
		return saveProfile(player.UserId, profile, false)
	end
	return false
end

---------------------------------------------------------------------------
-- Public helpers
---------------------------------------------------------------------------
function DataService.GetProfile(player)
	return player and profiles[player.UserId] or nil
end

function DataService.GetProfileByUserId(userId)
	return profiles[userId]
end

function DataService.OnLoaded(fn)
	table.insert(loadedCallbacks, fn)
	-- also fire for anyone already loaded (services that init late)
	for userId, profile in pairs(profiles) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			task.spawn(fn, player, profile)
		end
	end
end

function DataService.OnBeforeRelease(fn)
	table.insert(beforeReleaseCallbacks, fn)
end

function DataService.Replicate(player)
	if player and profiles[player.UserId] then
		dirty[player] = true
	end
end

local function sanitized(profile)
	local copy = Util.DeepCopy(profile)
	copy.Receipts = nil
	copy.Lock = nil
	return copy
end

function DataService.Snapshot(player)
	local profile = profiles[player.UserId]
	return profile and sanitized(profile) or nil
end

function DataService.AddCash(player, amount)
	local profile = profiles[player.UserId]
	if not profile or type(amount) ~= "number" or amount ~= amount then return end
	profile.Cash = math.max(0, math.floor(profile.Cash + amount))
	DataService.Replicate(player)
end

function DataService.SpendCash(player, amount)
	local profile = profiles[player.UserId]
	if not profile or type(amount) ~= "number" or amount < 0 then return false end
	if profile.Cash < amount then return false end
	profile.Cash = math.floor(profile.Cash - amount)
	DataService.Replicate(player)
	return true
end

function DataService.AddSnowflakes(player, amount)
	local profile = profiles[player.UserId]
	if not profile or type(amount) ~= "number" then return end
	profile.Snowflakes = math.max(0, math.floor(profile.Snowflakes + amount))
	DataService.Replicate(player)
end

function DataService.SpendSnowflakes(player, amount)
	local profile = profiles[player.UserId]
	if not profile or type(amount) ~= "number" or amount < 0 then return false end
	if profile.Snowflakes < amount then return false end
	profile.Snowflakes = math.floor(profile.Snowflakes - amount)
	DataService.Replicate(player)
	return true
end

function DataService.HasGamepass(player, key)
	local profile = profiles[player.UserId]
	return profile ~= nil and profile.Gamepasses[key] == true
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local function onPlayerAdded(player)
	local profile = loadProfile(player)
	if not player.Parent then
		if profile then saveProfile(player.UserId, profile, true) end
		return
	end
	if not profile then
		if Config.KickOnDataFail then
			player:Kick("Your data could not be loaded. Please rejoin in a moment.")
		end
		return
	end
	profiles[player.UserId] = profile
	-- Callbacks run IN REGISTRATION ORDER (PlotService assigns a base before anything else needs it)
	for _, fn in ipairs(loadedCallbacks) do
		local ok, err = pcall(fn, player, profile)
		if not ok then warn("[DataService] OnLoaded callback error: " .. tostring(err)) end
	end
	DataService.Replicate(player)
end

local function onPlayerRemoving(player)
	local profile = profiles[player.UserId]
	if not profile then return end
	for _, fn in ipairs(beforeReleaseCallbacks) do
		local ok, err = pcall(fn, player, profile)
		if not ok then warn("[DataService] OnBeforeRelease callback error: " .. tostring(err)) end
	end
	profiles[player.UserId] = nil
	dirty[player] = nil
	saveProfile(player.UserId, profile, true)
end

function DataService.Init()
	getStore()
	Remotes.Get("GetProfile").OnServerInvoke = function(player)
		-- wait briefly for the profile if the client asks before load finishes
		local t = 0
		while not profiles[player.UserId] and t < 15 do
			task.wait(0.25)
			t = t + 0.25
		end
		-- the client may have missed the first pushes; re-send everything it shows
		task.defer(function()
			pcall(function()
				Registry.Get("QuestService").Send(player)
				Registry.Get("PlotService").SendBaseState(player)
				Registry.Get("RetentionService").SendStreak(player)
				Registry.Get("GrinchService").SendTo(player)
				Registry.Get("EventService").SendTo(player)
			end)
		end)
		return DataService.Snapshot(player)
	end
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- replication flush (max 4 pushes/sec per player)
	task.spawn(function()
		local remote = Remotes.Get("DataChanged")
		while true do
			task.wait(0.25)
			for player in pairs(dirty) do
				dirty[player] = nil
				if player.Parent and profiles[player.UserId] then
					remote:FireClient(player, sanitized(profiles[player.UserId]))
				end
			end
		end
	end)

	-- autosave
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for userId, profile in pairs(profiles) do
				saveProfile(userId, profile, false)
				task.wait(0.5) -- stagger to respect DataStore budgets
			end
		end
	end)

	game:BindToClose(function()
		if useMock then return end
		local remaining = 0
		for userId, profile in pairs(profiles) do
			remaining = remaining + 1
			task.spawn(function()
				local player = Players:GetPlayerByUserId(userId)
				if player then
					for _, fn in ipairs(beforeReleaseCallbacks) do pcall(fn, player, profile) end
				end
				saveProfile(userId, profile, true)
				remaining = remaining - 1
			end)
		end
		local waited = 0
		while remaining > 0 and waited < 25 do
			task.wait(0.5)
			waited = waited + 0.5
		end
	end)
end

return DataService
