--[[
	StealService.lua
	Stealing presents from other bases. A stolen present is "in transit" (owned by nobody)
	until the thief deposits it at their base. If the thief is hit, dies, or leaves, it
	returns to the owner's base. If the OWNER leaves while it's in transit, it vanishes
	from the thief and goes back into the owner's saved data (no dupes, no losses).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Util = require(ReplicatedStorage.Shared.Util)
local Registry = require(script.Parent.Parent.Registry)
local Validate = require(script.Parent.Parent.Validate)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

local StealService = {}

local transit = {}   -- [presentId] = { Record, FromUserId, Thief }

local function Data() return Registry.Get("DataService") end
local function Plots() return Registry.Get("PlotService") end
local function Notify() return Registry.Get("NotifyService") end
local function Presents() return Registry.Get("PresentService") end

local function returnToOwner(entry, reason)
	local owner = Players:GetPlayerByUserId(entry.FromUserId)
	local profile = owner and Data().GetProfile(owner)
	local plot = owner and Plots().GetPlot(owner)
	transit[entry.Record.Id] = nil
	if not profile then
		-- owner is gone; nothing to return to (their leave handler already reclaimed it)
		return
	end
	-- put it back in a free slot (its old one if possible)
	local used = {}
	for _, r in ipairs(profile.Presents) do used[r.Slot] = true end
	local slot = (not used[entry.Record.Slot]) and entry.Record.Slot or Plots().GetFreeSlot(owner)
	if not slot then
		-- base somehow full: pay them out instead
		local value = math.floor(Presents().GetValue(owner, entry.Record, profile) * Config.SellSeconds)
		Data().AddCash(owner, value)
		return
	end
	entry.Record.Slot = slot
	table.insert(profile.Presents, entry.Record)
	if plot then
		Presents().PlaceModel(plot, owner, entry.Record)
		Presents().RecalcIncome(plot)
	end
	Data().Replicate(owner)
	local info = Catalog.PresentByKey[entry.Record.Key]
	if reason == "hit" then
		Notify().Notify(owner, "Your " .. (info and info.Name or "present") .. " was saved and returned!", "success")
	else
		Notify().Notify(owner, "Your " .. (info and info.Name or "present") .. " returned to your base.", "info")
	end
end

---------------------------------------------------------------------------
-- Steal attempt (from the ProximityPrompt on a placed present)
---------------------------------------------------------------------------
function StealService.TrySteal(thief, plot, presentId)
	if not RateLimiter.Check(thief, "Default") then return end
	local owner = plot.Owner
	if not owner or owner == thief then return end
	local thiefProfile = Data().GetProfile(thief)
	local ownerProfile = Data().GetProfile(owner)
	if not thiefProfile or not ownerProfile then return end
	local Carry = Registry.Get("CarryService")
	if Carry.IsCarrying(thief) then
		Notify().Notify(thief, "You're already carrying something!", "error")
		return
	end
	local Grinch = Registry.Get("GrinchService")
	local isGrinch = Grinch.IsGrinch(thief)
	if Plots().IsLocked(plot) and not (isGrinch and Config.Grinch.CanStealLocked) then
		Notify().Notify(thief, "This base is LOCKED!", "error")
		return
	end
	local model = plot.PresentModels[presentId]
	if not model or not Validate.Near(thief, model, Config.Steal.InteractDistance + 4) then return end
	local record, index = Presents().FindRecord(ownerProfile, presentId)
	if not record then return end
	-- strength gate: heavy presents need strength just like boxes
	local rarity = Catalog.Rarities[record.Rarity]
	local strength = thiefProfile.Strength
	if Data().HasGamepass(thief, "Strong") then strength = strength * 2 end
	local needed = rarity and (rarity.Weight * 2) or 0
	if strength < needed and not isGrinch then
		Notify().Notify(thief, string.format("Too heavy to steal! You need %s Strength.", Util.FormatNumber(needed)), "error")
		return
	end

	table.remove(ownerProfile.Presents, index)
	Presents().RemoveModel(plot, presentId)
	Presents().RecalcIncome(plot)
	Data().Replicate(owner)
	local entry = { Record = record, FromUserId = owner.UserId, Thief = thief }
	transit[presentId] = entry
	local ok = Carry.Give(thief, { Kind = "Present", Record = record, FromUserId = owner.UserId, Stolen = true, GrinchLoot = isGrinch })
	if not ok then
		returnToOwner(entry, "failed")
		return
	end
	local info = Catalog.PresentByKey[record.Key]
	Notify().Notify(thief, "You grabbed " .. owner.DisplayName .. "'s " .. (info and info.Name or "present") .. "! RUN!", "success")
	Notify().Notify(owner, "⚠️ " .. thief.DisplayName .. " is stealing your " .. (info and info.Name or "present") .. "!", "error")
	Notify().Effect("StealStart", model and model.PrimaryPart and model.PrimaryPart.Position or plot.Deposit.Position, { Rarity = record.Rarity })
end

-- Called by CarryService.Drop for Present carries
function StealService.OnDropped(thief, carry, reason)
	local entry = transit[carry.Record.Id]
	if entry then
		returnToOwner(entry, reason)
	else
		-- a gifted/owned present with no transit entry: give it back to the carrier's own base
		local profile = Data().GetProfile(thief)
		local plot = Plots().GetPlot(thief)
		if profile and plot and reason ~= "left" then
			local slot = Plots().GetFreeSlot(thief)
			if slot then
				carry.Record.Slot = slot
				table.insert(profile.Presents, carry.Record)
				Presents().PlaceModel(plot, thief, carry.Record)
				Presents().RecalcIncome(plot)
				Data().Replicate(thief)
			end
		end
	end
end

-- Called by PresentService when the thief deposits successfully
function StealService.OnDeposited(thief, carry)
	transit[carry.Record.Id] = nil
end

-- Owner leaving: reclaim everything of theirs that is in transit BEFORE their data saves
function StealService.ReclaimAllFrom(owner, profile)
	local Carry = Registry.Get("CarryService")
	for id, entry in pairs(transit) do
		if entry.FromUserId == owner.UserId then
			transit[id] = nil
			local thief = entry.Thief
			if thief and Carry.Get(thief) and Carry.Get(thief).Record == entry.Record then
				Carry.Take(thief)
				Notify().Notify(thief, "The owner left - the present vanished!", "info")
			end
			local used = {}
			for _, r in ipairs(profile.Presents) do used[r.Slot] = true end
			if used[entry.Record.Slot] then
				entry.Record.Slot = nil
				for i = 1, Config.Plots.MaxSlots do
					if not used[i] then entry.Record.Slot = i break end
				end
			end
			if entry.Record.Slot then
				table.insert(profile.Presents, entry.Record)
			end
		end
	end
end

function StealService.IsInTransit(presentId)
	return transit[presentId] ~= nil
end

function StealService.Init()
	Data().OnBeforeRelease(StealService.ReclaimAllFrom)
end

function StealService.Start() end

return StealService
