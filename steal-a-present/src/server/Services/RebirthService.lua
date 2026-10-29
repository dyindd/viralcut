--[[
	RebirthService.lua
	Reset cash + presents for a permanent income multiplier and an extra base slot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Parent.Registry)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

local RebirthService = {}

local function Data() return Registry.Get("DataService") end
local function Notify() return Registry.Get("NotifyService") end

function RebirthService.GetCost(rebirths)
	return math.floor(Config.Rebirth.BaseCost * (Config.Rebirth.CostMultiplier ^ rebirths))
end

local function onRebirth(player)
	if not RateLimiter.Check(player, "Rebirth") then return end
	local profile = Data().GetProfile(player)
	local plot = Registry.Get("PlotService").GetPlot(player)
	if not profile or not plot then return end
	local cost = RebirthService.GetCost(profile.Rebirths)
	if profile.Cash < cost then
		Notify().Notify(player, "You need $" .. Util.FormatNumber(cost) .. " to rebirth!", "error")
		return
	end
	if Registry.Get("CarryService").IsCarrying(player) then
		Notify().Notify(player, "Drop what you're carrying first!", "error")
		return
	end
	profile.Cash = Config.StartingCash
	profile.Pile = 0
	profile.Presents = {}
	profile.Rebirths = profile.Rebirths + 1
	if not Config.Rebirth.KeepStrength then profile.Strength = 0 end
	Data().AddSnowflakes(player, Config.Rebirth.SnowflakesReward)
	Registry.Get("PresentService").RebuildBase(player)
	Registry.Get("PlotService").RefreshSlots(plot)
	Registry.Get("PlotService").SendBaseState(player)
	Data().Replicate(player)
	Notify().Effect("Rebirth", plot.Deposit.Position, nil)
	Notify().Announce(string.format("%s rebirthed! Now x%.1f income (Rebirth %d)", player.DisplayName, 1 + profile.Rebirths * Config.Rebirth.IncomeBonusPerRebirth, profile.Rebirths), Color3.fromRGB(255, 120, 255), "rebirth")
end

function RebirthService.Init()
	Remotes.Get("Rebirth").OnServerEvent:Connect(onRebirth)
end

function RebirthService.Start() end

return RebirthService
