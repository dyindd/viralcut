--[[
	PresentService.lua
	The heart of the game: UNWRAPPING (all rarity/mutation rolls happen HERE on the server),
	placing presents at bases, income ticks, the cash pile, collecting, selling, offline earnings.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local PresentModels = require(ReplicatedStorage.Shared.PresentModels)
local Registry = require(script.Parent.Parent.Registry)
local Validate = require(script.Parent.Parent.Validate)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

local PresentService = {}
local rng = Random.new()
local offlinePaid = {}   -- [player] = true  (per session, never saved)

local rarityTier = {}
for key, info in pairs(Catalog.Rarities) do rarityTier[key] = info.Tier end

local function Data() return Registry.Get("DataService") end
local function Plots() return Registry.Get("PlotService") end
local function Notify() return Registry.Get("NotifyService") end
local function Quests() return Registry.Get("QuestService") end
local function Events() return Registry.Get("EventService") end

---------------------------------------------------------------------------
-- Value math
---------------------------------------------------------------------------
function PresentService.GetMultipliers(player, profile)
	profile = profile or Data().GetProfile(player)
	local mult = 1
	if profile then
		mult = mult * (1 + (profile.Rebirths or 0) * Config.Rebirth.IncomeBonusPerRebirth)
	end
	if Data().HasGamepass(player, "VIP") then
		mult = mult * Config.Monetization.VIPCashMultiplier
	end
	mult = mult * Events().GetIncomeMultiplier()
	return mult
end

-- cash/sec for one present record (before player multipliers)
function PresentService.GetBaseValue(record)
	local info = Catalog.PresentByKey[record.Key]
	if not info then return 0 end
	local value = info.Income
	local mutation = record.Mutation and Catalog.Mutations[record.Mutation]
	if mutation then value = value * mutation.Multiplier end
	local traitBonus = 0
	for traitKey in pairs(record.Traits or {}) do
		local trait = Catalog.Traits[traitKey]
		if trait then traitBonus = traitBonus + trait.Bonus end
	end
	return value * (1 + traitBonus)
end

function PresentService.GetValue(player, record, profile)
	return PresentService.GetBaseValue(record) * PresentService.GetMultipliers(player, profile)
end

function PresentService.GetLuck(player, profile)
	profile = profile or Data().GetProfile(player)
	local luck = 1
	if profile and (profile.Boosts.LuckUntil or 0) > os.time() then
		luck = luck * Config.Luck.PotionMultiplier
	end
	if Data().HasGamepass(player, "VIP") then
		luck = luck * Config.Luck.VIPMultiplier
	end
	luck = luck * Events().GetLuckMultiplier()
	return luck
end

---------------------------------------------------------------------------
-- Rolls (server only!)
---------------------------------------------------------------------------
function PresentService.RollRarity(tier, luck)
	local odds = Util.ApplyLuck(tier.Odds, luck, rarityTier)
	return Util.WeightedPickDict(odds, rng) or "Common"
end

function PresentService.RollPresent(rarity)
	local pool = Seasons.GetDroppablePresents(rarity)
	return pool[rng:NextInteger(1, #pool)]
end

function PresentService.RollMutation()
	local dict = {}
	local total = 0
	for _, key in ipairs(Catalog.MutationOrder) do
		local m = Catalog.Mutations[key]
		local chance = m.Chance * Events().GetMutationChanceMultiplier()
		if m.EventBoost and Events().IsActive(m.EventBoost) then
			chance = chance * Config.Events.MutationBoost
		end
		if key == "Cursed" and Events().IsActive("KrampusNight") then
			chance = Config.Events.KrampusNight.CursedChance
		end
		if chance > 0 then
			dict[key] = chance
			total = total + chance
		end
	end
	dict.None = math.max(0, 100 - total)
	local pick = Util.WeightedPickDict(dict, rng)
	if pick == "None" then return nil end
	return pick
end

---------------------------------------------------------------------------
-- Models at the base
---------------------------------------------------------------------------
local function makeBillboard(model, player, record)
	local info = Catalog.PresentByKey[record.Key]
	local rarity = Catalog.Rarities[record.Rarity]
	local bb = Instance.new("BillboardGui")
	bb.Name = "Info"
	bb.Size = UDim2.new(0, 180, 0, 70)
	bb.StudsOffset = Vector3.new(0, 3.2 + (model.PrimaryPart and model.PrimaryPart.Size.Y / 2 or 1), 0)
	bb.MaxDistance = 90
	bb.Parent = model.PrimaryPart
	local function line(name, y, h, text, color, size)
		local tl = Instance.new("TextLabel")
		tl.Name = name
		tl.BackgroundTransparency = 1
		tl.Position = UDim2.new(0, 0, 0, y)
		tl.Size = UDim2.new(1, 0, 0, h)
		tl.Font = Enum.Font.FredokaOne
		tl.TextScaled = true
		tl.Text = text
		tl.TextColor3 = color
		tl.TextStrokeTransparency = 0
		tl.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
		tl.Parent = bb
		return tl
	end
	local mutationText = record.Mutation and (Catalog.Mutations[record.Mutation].Name .. " ") or ""
	line("Name", 0, 26, mutationText .. (info and info.Name or record.Key), rarity.Color, 20)
	line("Rarity", 26, 20, rarity.Name, rarity.Color2, 16)
	line("Value", 46, 22, "$" .. Util.FormatNumber(PresentService.GetValue(player, record)) .. "/s", Color3.fromRGB(140, 255, 160), 18)
end

function PresentService.PlaceModel(plot, player, record)
	local ped = plot.Slots[record.Slot]
	if not ped then return nil end
	local model = PresentModels.MakeUnwrapped(record)
	local body = model.PrimaryPart
	model:PivotTo(ped.CFrame * CFrame.new(0, 0.8 + body.Size.Y / 2, 0))
	model:SetAttribute("PresentId", record.Id)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("BaseCFrame", model:GetPivot()) -- clients bob/spin the model around this
	makeBillboard(model, player, record)
	-- rarity flair: a neon ring for Rare+, a light pillar + sparkles for Legendary+
	local rarity = Catalog.Rarities[record.Rarity]
	if rarity and rarity.Tier >= 4 then
		local ring = Instance.new("Part")
		ring.Name = "Ring"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.2, 5.2, 5.2)
		ring.CFrame = ped.CFrame * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
		ring.Color = rarity.Color
		ring.Material = Enum.Material.Neon
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.Transparency = 0.25
		ring.Parent = model
		if rarity.Tier >= 6 then
			local pillar = Instance.new("Part")
			pillar.Name = "Pillar"
			pillar.Shape = Enum.PartType.Cylinder
			pillar.Size = Vector3.new(14, 2.6, 2.6)
			pillar.CFrame = ped.CFrame * CFrame.new(0, 7.5, 0) * CFrame.Angles(0, 0, math.rad(90))
			pillar.Color = rarity.Color
			pillar.Material = Enum.Material.Neon
			pillar.Anchored = true
			pillar.CanCollide = false
			pillar.CanQuery = false
			pillar.Transparency = 0.8
			pillar.Parent = model
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = rarity.Color
			sparkles.Parent = body
		end
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal!"
	prompt.ObjectText = (Catalog.PresentByKey[record.Key] or {}).Name or record.Key
	prompt.HoldDuration = Config.Steal.PromptHoldSeconds
	prompt.MaxActivationDistance = Config.Steal.InteractDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(thief)
		Registry.Get("StealService").TrySteal(thief, plot, record.Id)
	end)
	model.Parent = plot.PresentsFolder
	plot.PresentModels[record.Id] = model
	return model
end

function PresentService.RemoveModel(plot, presentId)
	local model = plot.PresentModels[presentId]
	if model then
		model:Destroy()
		plot.PresentModels[presentId] = nil
	end
end

function PresentService.RecalcIncome(plot)
	local owner = plot.Owner
	local profile = owner and Data().GetProfile(owner)
	if not profile then
		plot.IncomePerSec = 0
		return
	end
	local total = 0
	for _, record in ipairs(profile.Presents) do
		total = total + PresentService.GetValue(owner, record, profile)
	end
	plot.IncomePerSec = total
	Plots().UpdateSign(plot)
	Plots().SendBaseState(owner)
end

-- Recompute every base's income (events start/end, global multipliers)
function PresentService.RecalcAll()
	for _, plot in ipairs(Plots().AllPlots()) do
		if plot.Owner then PresentService.RecalcIncome(plot) end
	end
end

function PresentService.FindRecord(profile, presentId)
	for i, record in ipairs(profile.Presents) do
		if record.Id == presentId then
			return record, i
		end
	end
	return nil
end

function PresentService.ClearBase(plot)
	for id in pairs(plot.PresentModels) do
		PresentService.RemoveModel(plot, id)
	end
	plot.IncomePerSec = 0
end

-- Rebuild all models from the profile (join, rebirth, gift). Also pays offline earnings on first build.
function PresentService.RebuildBase(player)
	local plot = Plots().GetPlot(player)
	local profile = Data().GetProfile(player)
	if not plot or not profile then return end
	PresentService.ClearBase(plot)
	-- repair slots (bad data, fewer slots after a schema change...)
	local maxSlots = Plots().GetSlotCount(player)
	local used = {}
	for _, record in ipairs(profile.Presents) do
		if type(record.Slot) ~= "number" or record.Slot < 1 or record.Slot > Config.Plots.MaxSlots or used[record.Slot] then
			record.Slot = nil
		else
			used[record.Slot] = true
		end
	end
	local kept = {}
	local paidOut = 0
	for _, record in ipairs(profile.Presents) do
		if not record.Slot then
			for i = 1, Config.Plots.MaxSlots do
				if not used[i] then
					record.Slot = i
					used[i] = true
					break
				end
			end
		end
		record.Traits = record.Traits or {}
		if record.Slot then
			table.insert(kept, record)
			PresentService.PlaceModel(plot, player, record)
		else
			-- more presents than slots can ever hold (bad data): pay the sell value instead of losing it
			paidOut = paidOut + math.floor(PresentService.GetValue(player, record, profile) * Config.SellSeconds)
		end
	end
	profile.Presents = kept
	if paidOut > 0 then
		Data().AddCash(player, paidOut)
		Notify().Notify(player, "Some presents had no slot and were sold for $" .. Util.FormatNumber(paidOut) .. ".", "info")
	end
	PresentService.RecalcIncome(plot)

	-- offline earnings (once per session)
	if not offlinePaid[player] then
		offlinePaid[player] = true
		if Config.OfflineEarnings.Enabled and (profile.LastOnline or 0) > 0 then
			local elapsed = Util.Clamp(os.time() - profile.LastOnline, 0, Config.OfflineEarnings.MaxSeconds)
			local earned = math.floor(elapsed * plot.IncomePerSec * Config.OfflineEarnings.Rate)
			if earned >= 1 then
				profile.Pile = profile.Pile + earned
				task.delay(3, function()
					Notify().Notify(player, "Welcome back! Your presents made $" .. Util.FormatNumber(earned) .. " while you were away. Collect it at your base!", "success")
				end)
			end
		end
	end
	Plots().SendBaseState(player)
end

---------------------------------------------------------------------------
-- Deposit: box -> unwrap, present -> place
---------------------------------------------------------------------------
local function coalPrank(player)
	local root = Validate.GetRoot(player)
	if root then
		local dir = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		Registry.Get("CombatService").Impulse(root, Vector3.new(dir.X * 35, 55, dir.Z * 35), 0.15)
	end
end

local function announceUnwrap(player, record, plot)
	local info = Catalog.PresentByKey[record.Key] or { Name = record.Key }
	local rarity = Catalog.Rarities[record.Rarity]
	local mutationText = record.Mutation and (Catalog.Mutations[record.Mutation].Name .. " ") or ""
	local pos = plot.Deposit.Position
	Notify().Effect("Unwrap", pos, { Rarity = record.Rarity, Mutation = record.Mutation })
	if rarity.Announce == "server" then
		Notify().Announce(string.format("%s unwrapped a %s%s %s!", player.DisplayName, mutationText, rarity.Name, info.Name), rarity.Color, "rare")
	elseif record.Mutation and Catalog.Mutations[record.Mutation].Multiplier >= 6 then
		Notify().Announce(string.format("%s found a %s%s!", player.DisplayName, mutationText, info.Name), Catalog.Mutations[record.Mutation].Color, "rare")
	end
end

local function unwrapBox(player, plot, profile, carry)
	local tier = PresentModels.GetTier(carry.Tier)
	local luck = PresentService.GetLuck(player, profile)
	local rarityKey = PresentService.RollRarity(tier, luck)
	local info = PresentService.RollPresent(rarityKey)
	local slot = nil
	if rarityKey ~= "Coal" then
		slot = Plots().GetFreeSlot(player)
		if not slot then
			Notify().Notify(player, "Your base is FULL! Sell a present, rebirth, or buy more slots.", "error")
			return
		end
	end
	Registry.Get("CarryService").Take(player)
	local record = {
		Id = Util.NewId("p"),
		Key = info.Key,
		Rarity = rarityKey,
		Mutation = PresentService.RollMutation(),
		Traits = {},
		Slot = slot,
		UnwrappedAt = os.time(),
		Tier = tier.Key,
	}
	profile.Stats.Unwrapped = (profile.Stats.Unwrapped or 0) + 1
	local tierNum = rarityTier[rarityKey]
	if tierNum > (profile.Stats.BestRarity or 0) then profile.Stats.BestRarity = tierNum end
	Quests().Progress(player, "Unwrap", 1)
	Registry.Get("TutorialService").Complete(player, "Unwrap")
	if tierNum >= 4 then Quests().Progress(player, "UnwrapRare", 1) end
	if tierNum >= 5 then Quests().Progress(player, "UnwrapEpic", 1) end
	Registry.Get("IndexService").Unlock(player, info.Key)

	if rarityKey == "Coal" then
		coalPrank(player)
		Notify().Effect("Coal", plot.Deposit.Position, nil)
		Remotes.Get("UnwrapResult"):FireClient(player, record, 0, tier.Key)
		Data().Replicate(player)
		return
	end
	table.insert(profile.Presents, record)
	PresentService.PlaceModel(plot, player, record)
	PresentService.RecalcIncome(plot)
	Remotes.Get("UnwrapResult"):FireClient(player, record, PresentService.GetValue(player, record, profile), tier.Key)
	announceUnwrap(player, record, plot)
	Data().Replicate(player)
end

local function placeStolen(player, plot, profile, carry)
	local slot = Plots().GetFreeSlot(player)
	if not slot then
		Notify().Notify(player, "Your base is FULL! You can't keep this present.", "error")
		return
	end
	Registry.Get("CarryService").Take(player)
	local record = carry.Record
	record.Slot = slot
	record.Traits = record.Traits or {}
	if carry.Stolen then
		record.Traits.Stolen = true
		if carry.GrinchLoot then record.Traits.Grinch = true end
		profile.Stats.Stolen = (profile.Stats.Stolen or 0) + 1
		Quests().Progress(player, "Steal", 1)
		Registry.Get("TutorialService").Complete(player, "Steal")
	end
	Registry.Get("StealService").OnDeposited(player, carry)
	table.insert(profile.Presents, record)
	PresentService.PlaceModel(plot, player, record)
	PresentService.RecalcIncome(plot)
	Registry.Get("IndexService").Unlock(player, record.Key)
	local info = Catalog.PresentByKey[record.Key] or { Name = record.Key }
	local rarity = Catalog.Rarities[record.Rarity] or Catalog.Rarities.Common
	Notify().Effect("Steal", plot.Deposit.Position, { Rarity = record.Rarity })
	if carry.Stolen and rarity.Tier >= 6 then
		local victim = carry.FromUserId and Players:GetPlayerByUserId(carry.FromUserId)
		Notify().Announce(string.format("%s STOLE a %s %s from %s!", player.DisplayName, rarity.Name, info.Name, victim and victim.DisplayName or "someone"), rarity.Color, "steal")
	else
		Notify().Notify(player, "Secured: " .. info.Name .. "!", "success")
	end
	Data().Replicate(player)
end

-- A deposit that implies travelling faster than Config.AntiCheat.MaxTravelSpeed is a teleport exploit.
local function tooFast(player, plot, carry)
	if not Config.AntiCheat.Enabled or not carry.StartPos or not carry.StartedAt then return false end
	local distance = (plot.Deposit.Position - carry.StartPos).Magnitude
	local elapsed = os.clock() - carry.StartedAt
	return elapsed < distance / Config.AntiCheat.MaxTravelSpeed
end

function PresentService.TryDeposit(player, plot)
	local profile = Data().GetProfile(player)
	local carry = Registry.Get("CarryService").Get(player)
	if not profile or not carry or plot.Owner ~= player then return end
	if tooFast(player, plot, carry) then
		profile.Stats.Flags = (profile.Stats.Flags or 0) + 1
		warn(string.format("[AntiCheat] %s deposited too fast (flag #%d)", player.Name, profile.Stats.Flags))
		Notify().Notify(player, "Whoa, too fast! Walk your present to the pad.", "error")
		Registry.Get("CarryService").Drop(player, "anticheat")
		return
	end
	if carry.Kind == "Box" then
		unwrapBox(player, plot, profile, carry)
	else
		placeStolen(player, plot, profile, carry)
	end
end

---------------------------------------------------------------------------
-- Collect / sell
---------------------------------------------------------------------------
function PresentService.Collect(player, plot)
	local profile = Data().GetProfile(player)
	if not profile or plot.Owner ~= player then return end
	local pile = math.floor(profile.Pile)
	if pile < 1 then return end
	profile.Pile = 0
	Data().AddCash(player, pile)
	profile.Stats.CashCollected = (profile.Stats.CashCollected or 0) + pile
	Quests().Progress(player, "Collect", pile)
	Registry.Get("TutorialService").Complete(player, "Collect")
	Notify().Effect("Cash", plot.Collect.Position, { Amount = pile })
	Plots().SendBaseState(player)
end

function PresentService.Sell(player, presentId)
	if not RateLimiter.Check(player, "Default") then return end
	if not Validate.IsString(presentId, 64) then return end
	local profile = Data().GetProfile(player)
	local plot = Plots().GetPlot(player)
	if not profile or not plot then return end
	local record, index = PresentService.FindRecord(profile, presentId)
	if not record then return end
	local value = math.floor(PresentService.GetValue(player, record, profile) * Config.SellSeconds)
	value = math.max(value, 10)
	table.remove(profile.Presents, index)
	PresentService.RemoveModel(plot, presentId)
	PresentService.RecalcIncome(plot)
	Data().AddCash(player, value)
	Notify().Notify(player, "Sold for $" .. Util.FormatNumber(value), "success")
end

---------------------------------------------------------------------------
-- Income tick
---------------------------------------------------------------------------
local function incomeLoop()
	while true do
		task.wait(Config.IncomeTickSeconds)
		for _, plot in ipairs(Plots().AllPlots()) do
			local owner = plot.Owner
			local profile = owner and Data().GetProfile(owner)
			if profile and plot.IncomePerSec > 0 then
				local earned = plot.IncomePerSec * Config.IncomeTickSeconds
				if Data().HasGamepass(owner, "AutoCollect") then
					-- accumulate fractions in the pile, bank only whole cash (AddCash floors)
					profile.Pile = profile.Pile + earned
					local whole = math.floor(profile.Pile)
					if whole >= 1 then
						profile.Pile = profile.Pile - whole
						Data().AddCash(owner, whole)
						profile.Stats.CashCollected = (profile.Stats.CashCollected or 0) + whole
					end
				else
					profile.Pile = profile.Pile + earned
					Plots().SendBaseState(owner)
				end
			end
		end
	end
end

function PresentService.Init()
	Remotes.Get("SellPresent").OnServerEvent:Connect(PresentService.Sell)
end

function PresentService.Start()
	task.spawn(incomeLoop)
	Players.PlayerRemoving:Connect(function(player) offlinePaid[player] = nil end)
end

return PresentService
