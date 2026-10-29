--[[
	StrengthService.lua
	Stand at your bench and press Train. Strength is only gained when you LIFT (click, tap the
	LIFT button or press F), so it can't be AFK-farmed. Every lift pumps the barbell.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Parent.Registry)
local Validate = require(script.Parent.Parent.Validate)
local RateLimiter = require(script.Parent.Parent.RateLimiter)
local Decor = require(script.Parent.Parent.Decor)

local StrengthService = {}
local training = {}  -- [player] = plot
local tools = {}     -- [player] = barbell Tool
local lastLift = {}  -- [player] = os.clock()

local function Data() return Registry.Get("DataService") end
local function Notify() return Registry.Get("NotifyService") end

local function startPose(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not char or not hum or not backpack then return end
	local tool = Decor.Barbell()
	tool.Parent = backpack
	hum:EquipTool(tool)
	tools[player] = tool
	char:SetAttribute("Training", true)
end

local function stopPose(player)
	local tool = tools[player]
	tools[player] = nil
	if tool then tool:Destroy() end
	local char = player.Character
	if char then char:SetAttribute("Training", false) end
end

local function pump(player)
	local tool = tools[player]
	if not tool or not tool.Parent then return end
	TweenService:Create(tool, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Grip = Decor.GripUp }):Play()
	task.delay(0.22, function()
		if tool.Parent then
			TweenService:Create(tool, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Grip = Decor.GripDown }):Play()
		end
	end)
end

function StrengthService.GetGainPerLift(player)
	local profile = Data().GetProfile(player)
	if not profile then return 0 end
	local gain = (Config.Strength.GainPerLift or 1) * (1 + profile.Rebirths * Config.Strength.RebirthBonusPerLevel)
	if Data().HasGamepass(player, "Strong") then gain = gain * 2 end
	if (profile.Boosts.ProteinUntil or 0) > os.time() then gain = gain * Config.Strength.ProteinMultiplier end
	return gain
end
StrengthService.GetGainPerSecond = StrengthService.GetGainPerLift

function StrengthService.Stop(player, silent)
	if not training[player] then return end
	training[player] = nil
	stopPose(player)
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
	startPose(player)
	Notify().Notify(player, "Click, tap LIFT or press F to lift! +" .. Util.FormatNumber(StrengthService.GetGainPerLift(player)) .. " Strength per rep.", "success")
end

function StrengthService.Lift(player)
	if not RateLimiter.Check(player, "Lift") then return false end
	local plot = training[player]
	if not plot then return false end
	local t = os.clock()
	if lastLift[player] and t - lastLift[player] < (Config.Strength.LiftCooldown or 0.45) then return false end
	local profile = Data().GetProfile(player)
	if not profile or not Validate.Near(player, plot.Bench, 12) then return false end
	lastLift[player] = t
	pump(player)
	local gain = StrengthService.GetGainPerLift(player)
	profile.Strength = Util.Round(profile.Strength + gain, 2)
	Registry.Get("QuestService").Progress(player, "Train", gain)
	Notify().Effect("Train", plot.Bench.Position, { UserId = player.UserId })
	Data().Replicate(player)
	return true
end

function StrengthService.IsTraining(player)
	return training[player] ~= nil
end

function StrengthService.Init()
	Remotes.Get("Lift").OnServerEvent:Connect(function(player) StrengthService.Lift(player) end)
end

function StrengthService.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			for player, plot in pairs(training) do
				local profile = Data().GetProfile(player)
				local tool = tools[player]
				local holding = tool ~= nil and tool.Parent == player.Character
				if not profile or not player.Parent or not Validate.Near(player, plot.Bench, 12) or Registry.Get("CarryService").IsCarrying(player) or not holding then
					StrengthService.Stop(player, true)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player) training[player] = nil tools[player] = nil lastLift[player] = nil end)
end

return StrengthService
