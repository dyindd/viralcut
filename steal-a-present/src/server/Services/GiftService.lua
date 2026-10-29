--[[
	GiftService.lua
	Give one of your presents to another player in the server. Both earn Snowflakes, the
	present gains the "Wrapped with Love" trait (+10%), and +10% more if you're Roblox friends.
	This is the co-play hook: Roblox's recommendation algorithm rewards friends playing together.
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

local GiftService = {}

local function Data() return Registry.Get("DataService") end
local function Plots() return Registry.Get("PlotService") end
local function Notify() return Registry.Get("NotifyService") end
local function Presents() return Registry.Get("PresentService") end

local function onGift(player, presentId, targetUserId)
	if not Config.Gift.Enabled then return end
	if not RateLimiter.Check(player, "Gift") then return end
	if not Validate.IsString(presentId, 64) or not Validate.IsNumber(targetUserId, 1) then return end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then return end
	local profile = Data().GetProfile(player)
	local targetProfile = Data().GetProfile(target)
	local plot = Plots().GetPlot(player)
	local targetPlot = Plots().GetPlot(target)
	if not profile or not targetProfile or not plot or not targetPlot then return end

	-- limits
	local day = Util.DayStamp()
	if profile.Gifts.Day ~= day then
		profile.Gifts.Day = day
		profile.Gifts.Count = 0
	end
	if profile.Gifts.Count >= Config.Gift.MaxPerDay then
		Notify().Notify(player, "You've hit today's gift limit (" .. Config.Gift.MaxPerDay .. ").", "error")
		return
	end
	if os.time() - (profile.Gifts.LastGift or 0) < Config.Gift.Cooldown then
		Notify().Notify(player, "Gift cooldown: " .. Util.FormatTime(Config.Gift.Cooldown - (os.time() - profile.Gifts.LastGift)), "error")
		return
	end
	local record, index = Presents().FindRecord(profile, presentId)
	if not record then return end
	local slot = Plots().GetFreeSlot(target)
	if not slot then
		Notify().Notify(player, target.DisplayName .. "'s base is full!", "error")
		return
	end

	-- move it
	table.remove(profile.Presents, index)
	Presents().RemoveModel(plot, presentId)
	Presents().RecalcIncome(plot)
	record.Slot = slot
	record.Traits = record.Traits or {}
	record.Traits.Gifted = true
	local friends = false
	pcall(function() friends = player:IsFriendsWith(target.UserId) end)
	if friends then record.Traits.Friends = true end
	table.insert(targetProfile.Presents, record)
	Presents().PlaceModel(targetPlot, target, record)
	Presents().RecalcIncome(targetPlot)
	Registry.Get("IndexService").Unlock(target, record.Key)

	profile.Gifts.Count = profile.Gifts.Count + 1
	profile.Gifts.LastGift = os.time()
	profile.Stats.Gifts = (profile.Stats.Gifts or 0) + 1
	Data().AddSnowflakes(player, Config.Gift.SnowflakesForBoth)
	Data().AddSnowflakes(target, Config.Gift.SnowflakesForBoth)
	Registry.Get("QuestService").Progress(player, "Gift", 1)

	local info = Catalog.PresentByKey[record.Key] or { Name = record.Key }
	local rarity = Catalog.Rarities[record.Rarity] or Catalog.Rarities.Common
	Notify().Notify(player, "You gifted " .. info.Name .. " to " .. target.DisplayName .. "! +" .. Config.Gift.SnowflakesForBoth .. " Snowflakes", "success")
	Notify().Notify(target, "💝 " .. player.DisplayName .. " gifted you a " .. rarity.Name .. " " .. info.Name .. "!" .. (friends and " (Best Friends bonus!)" or ""), "success")
	Notify().Effect("Gift", targetPlot.Deposit.Position, { Rarity = record.Rarity })
	if rarity.Tier >= 6 then
		Notify().Announce(player.DisplayName .. " gifted a " .. rarity.Name .. " " .. info.Name .. " to " .. target.DisplayName .. "!", rarity.Color, "rare")
	end
	Data().Replicate(player)
	Data().Replicate(target)
end

function GiftService.Init()
	Remotes.Get("GiftPresent").OnServerEvent:Connect(onGift)
end

function GiftService.Start() end

return GiftService
