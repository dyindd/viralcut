--[[
	TutorialService.lua - first-join objectives. Other services call TutorialService.Complete(player, key)
	when the player does the thing; the HUD shows the first unfinished step. Finishing all steps pays
	Config.Tutorial.Reward. Steps can be completed in any order (no "stuck" states).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(script.Parent.Parent.Registry)

local TutorialService = {}

local function Data() return Registry.Get("DataService") end
local function Notify() return Registry.Get("NotifyService") end

function TutorialService.Complete(player, key)
	if not Config.Tutorial.Enabled then return end
	local profile = Data().GetProfile(player)
	if not profile or profile.Tutorial.Finished then return end
	local valid = false
	for _, step in ipairs(Config.Tutorial.Steps) do
		if step.Key == key then valid = true end
	end
	if not valid or profile.Tutorial.Completed[key] then return end
	profile.Tutorial.Completed[key] = true
	local allDone = true
	for _, step in ipairs(Config.Tutorial.Steps) do
		if not profile.Tutorial.Completed[step.Key] then allDone = false end
	end
	if allDone then
		profile.Tutorial.Finished = true
		local Retention = Registry.Get("RetentionService")
		local parts = {}
		local reward = Config.Tutorial.Reward
		if reward.Cash then table.insert(parts, Retention.Grant(player, profile, { Type = "Cash", Amount = reward.Cash })) end
		if reward.Snowflakes then table.insert(parts, Retention.Grant(player, profile, { Type = "Snowflakes", Amount = reward.Snowflakes })) end
		if reward.Box then table.insert(parts, Retention.Grant(player, profile, { Type = "Box", Tier = reward.Box })) end
		Notify().Notify(player, "🎓 Tutorial complete! Reward: " .. table.concat(parts, ", ") .. ". Now go steal Christmas!", "success")
		Notify().Effect("Reward", nil, nil)
	else
		Notify().Notify(player, "✅ Objective done!", "success")
	end
	Data().Replicate(player)
end

function TutorialService.Init() end
function TutorialService.Start() end

return TutorialService
