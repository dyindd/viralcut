--[[
	LeaderstatsService.lua - the player list stats (Cash, Rebirths, Stolen).
]]

local Players = game:GetService("Players")
local Registry = require(script.Parent.Parent.Registry)

local LeaderstatsService = {}

local function Data() return Registry.Get("DataService") end

local function ensure(player)
	local ls = player:FindFirstChild("leaderstats")
	if ls then return ls end
	ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, name in ipairs({ "Cash", "Rebirths", "Stolen" }) do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = ls
	end
	ls.Parent = player
	return ls
end

function LeaderstatsService.Init()
	Data().OnLoaded(function(player) ensure(player) end)
end

function LeaderstatsService.Start()
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = Data().GetProfile(player)
				local ls = profile and player:FindFirstChild("leaderstats")
				if ls then
					ls.Cash.Value = math.floor(profile.Cash)
					ls.Rebirths.Value = profile.Rebirths
					ls.Stolen.Value = profile.Stats.Stolen or 0
				end
			end
		end
	end)
end

return LeaderstatsService
