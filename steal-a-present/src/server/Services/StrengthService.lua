--[[
	StrengthService.lua
	Stand at your bench and "Train" to gain Strength over time. Strength gates which
	box sizes you can carry (bigger box = better odds). You cannot move while training.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Registry = require(script.Parent.Parent.Registry)
local Validate = require(script.Parent.Parent.Validate)

local StrengthService = {}
local training = {}  -- [player] = plot

local function Data() return Registry.Get("DataService") end
local function Notify() return Registry.Get("NotifyService") end

function StrengthService.GetGainPerSecond(player)
	local profile = Data().GetProfile(player)
	if not profile then return 0 end
	local gain = Config.Strength.GainPerSecond * (1 + profile.Rebirths * Config.Strength.RebirthBonusPerLevel)
	if Data().HasGamepass(player, "Strong") then gain = gain * 2 end
	if (profile.Boosts.ProteinUntil or 0) > os.time() then gain = gain * Config.Strength.ProteinMultiplier end
	return gain
end

function StrengthService.Stop(player, silent)
	if not training[player] then return end
	training[player] = nil
	Registry.Get("CarryService").SetSpeedModifier(player, "Training", nil)
	if not silent then Notify().Notify(player, "Stopped training.", "info") end
end

function StrengthService.Toggle(player, plot)
	if training[player] then
		StrengthService.Stop(player)
		return
	end
	if Registry.Get("CarryService").IsCarrying(player) then
		Notify().Notify(player, "Drop what you're carrying first!", "error")
		return
	end
	if not Validate.Near(player, plot.Bench, 10) then return end
	training[player] = plot
	Registry.Get("TutorialService").Complete(player, "Train")
	Registry.Get("CarryService").SetSpeedModifier(player, "Training", 0)
	Notify().Notify(player, "Training! +" .. Util.FormatNumber(StrengthService.GetGainPerSecond(player)) .. " Strength/s. Press the bench again to stop.", "success")
end

function StrengthService.IsTraining(player)
	return training[player] ~= nil
end

function StrengthService.Init() end

function StrengthService.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			for player, plot in pairs(training) do
				local profile = Data().GetProfile(player)
				if not profile or not player.Parent or not Validate.Near(player, plot.Bench, 12) or Registry.Get("CarryService").IsCarrying(player) then
					StrengthService.Stop(player, true)
				else
					local gain = StrengthService.GetGainPerSecond(player)
					profile.Strength = Util.Round(profile.Strength + gain, 2)
					Registry.Get("QuestService").Progress(player, "Train", gain)
					Registry.Get("NotifyService").Effect("Train", plot.Bench.Position, { UserId = player.UserId })
					Data().Replicate(player)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player) training[player] = nil end)
end

return StrengthService
