--[[
	LeaderboardService.lua - global top-10 boards (OrderedDataStore) shown on the hub boards.
	Uploads each online player's score every WriteInterval, refreshes the boards every ReadInterval.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Registry = require(script.Parent.Parent.Registry)

local LeaderboardService = {}
local stores = {}
local nameCache = {}
local boards = {}

local function Data() return Registry.Get("DataService") end

local function getStore(def)
	if stores[def.Key] then return stores[def.Key] end
	local ok, store = pcall(function() return DataStoreService:GetOrderedDataStore(def.Store) end)
	if ok then stores[def.Key] = store end
	return stores[def.Key]
end

local function nameFor(userId)
	if nameCache[userId] then return nameCache[userId] end
	local player = Players:GetPlayerByUserId(userId)
	local name = player and player.DisplayName
	if not name then
		local ok, result = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
		name = ok and result or ("User" .. userId)
	end
	nameCache[userId] = name
	return name
end

local function scoreFor(profile, def)
	if def.Stat == "Rebirths" then return profile.Rebirths or 0 end
	return math.floor(profile.Stats[def.Stat] or 0)
end

function LeaderboardService.WriteAll()
	for _, def in ipairs(Config.Leaderboard.Boards) do
		local store = getStore(def)
		if store then
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = Data().GetProfile(player)
				if profile then
					local score = scoreFor(profile, def)
					if score > 0 then
						pcall(function() store:SetAsync(tostring(player.UserId), score) end)
					end
				end
			end
		end
	end
end

function LeaderboardService.Refresh()
	for _, def in ipairs(Config.Leaderboard.Boards) do
		local store = getStore(def)
		local gui = boards[def.Key]
		if store and gui then
			local ok, pages = pcall(function() return store:GetSortedAsync(false, Config.Leaderboard.Top) end)
			if ok and pages then
				local page = pages:GetCurrentPage()
				for row = 1, Config.Leaderboard.Top do
					local label = gui:FindFirstChild("Row" .. row)
					local entry = page[row]
					if label then
						if entry then
							local userId = tonumber(entry.key)
							label.Text = string.format("%d.  %s  -  %s", row, userId and nameFor(userId) or "?", Util.FormatNumber(entry.value))
						else
							label.Text = row .. ".  ---"
						end
					end
				end
			end
		end
	end
end

function LeaderboardService.Init()
	local hub = Workspace:WaitForChild("World"):WaitForChild("Hub")
	local model = hub:FindFirstChild("Leaderboards")
	if model then
		for _, def in ipairs(Config.Leaderboard.Boards) do
			local board = model:FindFirstChild(def.Key .. "Board")
			boards[def.Key] = board and board:FindFirstChild("BoardGui")
		end
	end
end

function LeaderboardService.Start()
	if not Config.Leaderboard.Enabled then return end
	task.spawn(function()
		task.wait(5)
		LeaderboardService.Refresh()
		while true do
			task.wait(Config.Leaderboard.WriteInterval)
			LeaderboardService.WriteAll()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Leaderboard.ReadInterval)
			LeaderboardService.Refresh()
		end
	end)
end

return LeaderboardService
