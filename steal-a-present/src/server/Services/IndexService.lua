--[[
	IndexService.lua
	The collection book. Unlock an entry the first time you unwrap (or receive) a present type.
	Complete every present of a rarity for a big cash reward.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Util = require(ReplicatedStorage.Shared.Util)
local Registry = require(script.Parent.Parent.Registry)

local IndexService = {}

local function Data() return Registry.Get("DataService") end
local function Notify() return Registry.Get("NotifyService") end

local function checkSet(player, profile, rarity)
	if profile.IndexSetsClaimed[rarity] then return end
	for _, present in ipairs(Catalog.PresentsByRarity[rarity] or {}) do
		if not profile.Index[present.Key] then return end
	end
	local reward = Config.Index.SetRewards[rarity]
	if not reward then return end
	profile.IndexSetsClaimed[rarity] = true
	Data().AddCash(player, reward)
	Notify().Notify(player, "📖 " .. rarity .. " set COMPLETE! +$" .. Util.FormatNumber(reward), "success")
	if (Catalog.Rarities[rarity].Tier or 0) >= 6 then
		Notify().Announce(player.DisplayName .. " completed the " .. rarity .. " index!", Catalog.Rarities[rarity].Color, "rare")
	end
end

function IndexService.Unlock(player, presentKey)
	local profile = Data().GetProfile(player)
	local info = Catalog.PresentByKey[presentKey]
	if not profile or not info then return false end
	if profile.Index[presentKey] then return false end
	profile.Index[presentKey] = true
	Data().AddSnowflakes(player, Config.Index.SnowflakesPerNewEntry)
	Notify().Notify(player, "📖 New index entry: " .. info.Name .. " (+" .. Config.Index.SnowflakesPerNewEntry .. " Snowflakes)", "info")
	checkSet(player, profile, info.Rarity)
	Data().Replicate(player)
	return true
end

function IndexService.Init() end
function IndexService.Start() end

return IndexService
