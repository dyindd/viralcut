--[[
	RetentionService.lua
	The "come back tomorrow" systems:
	  - 25-day streak calendar (Advent calendar in December). Miss a day = back to day 1.
	  - Playtime gift: every 30 minutes of play, a free Rare+ box at your base.
	  - Snowflake shop (event currency sink).
	  - Settings remote.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Parent.Registry)
local Validate = require(script.Parent.Parent.Validate)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

local RetentionService = {}

local function Data() return Registry.Get("DataService") end
local function Notify() return Registry.Get("NotifyService") end

---------------------------------------------------------------------------
-- Streak calendar
---------------------------------------------------------------------------
function RetentionService.GetStreakInfo(profile)
	local today = Util.DayStamp()
	local streak = profile.Streak
	local count = streak.Count
	if Config.Streak.ResetIfMissed and streak.LastClaimDay > 0 and streak.LastClaimDay < today - 1 then
		count = 0 -- missed a day: will restart at day 1 on next claim
	end
	local canClaim = streak.LastClaimDay ~= today
	local nextDay = (count % Config.Streak.Days) + 1
	return { Count = count, NextDay = nextDay, CanClaim = canClaim, LastClaimDay = streak.LastClaimDay, Today = today, Days = Config.Streak.Days }
end

local function sendStreak(player, profile)
	Remotes.Get("StreakChanged"):FireClient(player, RetentionService.GetStreakInfo(profile))
end

function RetentionService.SendStreak(player)
	local profile = Data().GetProfile(player)
	if profile then sendStreak(player, profile) end
end

local function grantReward(player, profile, reward)
	if reward.Type == "Cash" then
		Data().AddCash(player, reward.Amount)
		return "$" .. Util.FormatNumber(reward.Amount)
	elseif reward.Type == "Snowflakes" then
		Data().AddSnowflakes(player, reward.Amount)
		return reward.Amount .. " Snowflakes"
	elseif reward.Type == "Box" then
		Registry.Get("ConveyorService").GiveBoxAtBase(player, reward.Tier)
		return "a free " .. reward.Tier .. " Box"
	elseif reward.Type == "Luck" then
		local base = math.max(os.time(), profile.Boosts.LuckUntil or 0)
		profile.Boosts.LuckUntil = base + reward.Minutes * 60
		return reward.Minutes .. " minutes of 2x Luck"
	elseif reward.Type == "Slot" then
		profile.BonusSlots = (profile.BonusSlots or 0) + (reward.Amount or 1)
		local plot = Registry.Get("PlotService").GetPlot(player)
		if plot then Registry.Get("PlotService").RefreshSlots(plot) end
		return "+" .. (reward.Amount or 1) .. " base slot"
	end
	return "a reward"
end

local function onClaimStreak(player)
	if not RateLimiter.Check(player, "Claim") then return end
	local profile = Data().GetProfile(player)
	if not profile then return end
	local info = RetentionService.GetStreakInfo(profile)
	if not info.CanClaim then
		Notify().Notify(player, "Already claimed today! Come back tomorrow.", "info")
		return
	end
	local day = info.NextDay
	profile.Streak.Count = info.Count + 1
	profile.Streak.LastClaimDay = info.Today
	local reward = Config.Streak.Rewards[day] or Config.Streak.Rewards[#Config.Streak.Rewards]
	local text = grantReward(player, profile, reward)
	Notify().Notify(player, "Day " .. day .. " reward: " .. text .. "!", "success")
	Notify().Effect("Reward", nil, nil)
	sendStreak(player, profile)
	Data().Replicate(player)
end

---------------------------------------------------------------------------
-- Playtime gift
---------------------------------------------------------------------------
local function onClaimPlaytimeGift(player)
	if not RateLimiter.Check(player, "Claim") then return end
	local profile = Data().GetProfile(player)
	if not profile then return end
	if profile.PlaytimeGift.Progress < Config.PlaytimeGift.IntervalSeconds then
		Notify().Notify(player, "Not ready yet! " .. Util.FormatTime(Config.PlaytimeGift.IntervalSeconds - profile.PlaytimeGift.Progress) .. " to go.", "info")
		return
	end
	profile.PlaytimeGift.Progress = profile.PlaytimeGift.Progress - Config.PlaytimeGift.IntervalSeconds
	Registry.Get("ConveyorService").GiveBoxAtBase(player, Config.PlaytimeGift.Tier)
	Data().Replicate(player)
end

---------------------------------------------------------------------------
-- Snowflake shop
---------------------------------------------------------------------------
local function onBuySnowflakeItem(player, shopKey)
	if not RateLimiter.Check(player, "Claim") then return end
	if not Validate.IsString(shopKey, 32) then return end
	local profile = Data().GetProfile(player)
	if not profile then return end
	local item
	for _, it in ipairs(Catalog.SnowflakeShop) do
		if it.Key == shopKey then item = it end
	end
	if not item then return end
	if not Data().SpendSnowflakes(player, item.Cost) then
		Notify().Notify(player, "Not enough Snowflakes! Do quests and hit the Grinch to earn them.", "error")
		return
	end
	local give = item.Give
	if give.Box then
		Registry.Get("ConveyorService").GiveBoxAtBase(player, give.Box)
	elseif give.Luck then
		grantReward(player, profile, { Type = "Luck", Minutes = give.Luck })
	elseif give.Slot then
		grantReward(player, profile, { Type = "Slot", Amount = give.Slot })
	end
	Notify().Notify(player, "Bought " .. item.Name .. "!", "success")
	Data().Replicate(player)
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local allowedSettings = { Music = "boolean", SFX = "boolean" }
local function onSetSetting(player, key, value)
	if not RateLimiter.Check(player, "Default") then return end
	local profile = Data().GetProfile(player)
	if not profile or not Validate.IsString(key, 16) then return end
	if allowedSettings[key] ~= type(value) then return end
	profile.Settings[key] = value
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function RetentionService.Init()
	Remotes.Get("ClaimStreak").OnServerEvent:Connect(onClaimStreak)
	Remotes.Get("ClaimPlaytimeGift").OnServerEvent:Connect(onClaimPlaytimeGift)
	Remotes.Get("BuySnowflakeItem").OnServerEvent:Connect(onBuySnowflakeItem)
	Remotes.Get("SetSetting").OnServerEvent:Connect(onSetSetting)
	Data().OnLoaded(function(player, profile)
		sendStreak(player, profile)
		local info = RetentionService.GetStreakInfo(profile)
		if info.CanClaim then
			task.delay(4, function()
				if player.Parent then Notify().Notify(player, "🎁 Your daily calendar reward is ready!", "success") end
			end)
		end
	end)
end

function RetentionService.Start()
	-- playtime loop (10s ticks)
	task.spawn(function()
		local notified = {}
		while true do
			task.wait(10)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = Data().GetProfile(player)
				if profile then
					profile.Stats.Playtime = (profile.Stats.Playtime or 0) + 10
					profile.PlaytimeGift.Progress = profile.PlaytimeGift.Progress + 10
					if profile.PlaytimeGift.Progress >= Config.PlaytimeGift.IntervalSeconds and not notified[player] then
						notified[player] = true
						Notify().Notify(player, "🎁 Your free playtime gift is ready! Claim it from the Rewards button.", "success")
					elseif profile.PlaytimeGift.Progress < Config.PlaytimeGift.IntervalSeconds then
						notified[player] = nil
					end
					Data().Replicate(player)
				end
			end
		end
	end)
end

return RetentionService
