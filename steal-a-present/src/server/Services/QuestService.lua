--[[
	QuestService.lua
	3 daily quests per player, chosen deterministically from Catalog.Quests by (day, userId)
	so a rejoin never re-rolls them. Other services call QuestService.Progress(player, stat, amount).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Parent.Registry)
local Validate = require(script.Parent.Parent.Validate)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

local QuestService = {}
local questDefs = {}
for _, q in ipairs(Catalog.Quests) do questDefs[q.Id] = q end

local function Data() return Registry.Get("DataService") end
local function Notify() return Registry.Get("NotifyService") end

local function today()
	-- shift so the reset happens at Config.DailyQuests.ResetHourUTC
	return Util.DayStamp(os.time() - Config.DailyQuests.ResetHourUTC * 3600)
end

local function ensureDaily(player, profile)
	local day = today()
	if profile.Quests.Day == day and #profile.Quests.List > 0 then return false end
	local rng = Random.new(day * 7919 + player.UserId)
	local pool = {}
	for _, q in ipairs(Catalog.Quests) do table.insert(pool, q) end
	local list = {}
	for _ = 1, math.min(Config.DailyQuests.Count, #pool) do
		local idx = rng:NextInteger(1, #pool)
		table.insert(list, { Id = pool[idx].Id, Progress = 0, Claimed = false })
		table.remove(pool, idx)
	end
	profile.Quests.Day = day
	profile.Quests.List = list
	return true
end

local function view(profile)
	local out = {}
	for _, q in ipairs(profile.Quests.List) do
		local def = questDefs[q.Id]
		if def then
			table.insert(out, { Id = q.Id, Text = def.Text, Goal = def.Goal, Progress = math.min(q.Progress, def.Goal),
				Claimed = q.Claimed, Reward = def.Reward, Done = q.Progress >= def.Goal })
		end
	end
	return out
end

function QuestService.Send(player)
	local profile = Data().GetProfile(player)
	if not profile then return end
	ensureDaily(player, profile)
	Remotes.Get("QuestsChanged"):FireClient(player, view(profile))
end

function QuestService.Progress(player, stat, amount)
	local profile = Data().GetProfile(player)
	if not profile or not amount or amount <= 0 then return end
	ensureDaily(player, profile)
	local changed = false
	for _, q in ipairs(profile.Quests.List) do
		local def = questDefs[q.Id]
		if def and def.Stat == stat and not q.Claimed and q.Progress < def.Goal then
			q.Progress = q.Progress + amount
			changed = true
			if q.Progress >= def.Goal then
				Notify().Notify(player, "✅ Quest complete: " .. def.Text .. "! Claim it in Quests.", "success")
			end
		end
	end
	if changed then QuestService.Send(player) end
end

local function onClaim(player, questId)
	if not RateLimiter.Check(player, "Claim") then return end
	if not Validate.IsString(questId, 32) then return end
	local profile = Data().GetProfile(player)
	if not profile then return end
	ensureDaily(player, profile)
	for _, q in ipairs(profile.Quests.List) do
		local def = questDefs[q.Id]
		if q.Id == questId and def and not q.Claimed and q.Progress >= def.Goal then
			q.Claimed = true
			if def.Reward.Cash then Data().AddCash(player, def.Reward.Cash) end
			if def.Reward.Snowflakes then Data().AddSnowflakes(player, def.Reward.Snowflakes) end
			Notify().Notify(player, "Quest reward: $" .. Util.FormatNumber(def.Reward.Cash or 0) .. " + " .. (def.Reward.Snowflakes or 0) .. " Snowflakes", "success")
			Notify().Effect("Reward", nil, nil)
			QuestService.Send(player)
			return
		end
	end
end

function QuestService.Init()
	Remotes.Get("ClaimQuest").OnServerEvent:Connect(onClaim)
	Data().OnLoaded(function(player, profile)
		ensureDaily(player, profile)
		QuestService.Send(player)
	end)
end

function QuestService.Start()
	-- roll over quests at the daily reset while players are online
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				local profile = Data().GetProfile(player)
				if profile and ensureDaily(player, profile) then
					QuestService.Send(player)
					Notify().Notify(player, "New daily quests are here!", "info")
				end
			end
		end
	end)
end

return QuestService
