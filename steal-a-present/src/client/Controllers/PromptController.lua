--[[
	PromptController.lua - hides prompts that don't apply to you (no "Steal!" on your own
	presents, no "Lock"/"Train"/"Place Trap" on other people's bases). Server validates anyway.
]]

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local PromptController = {}

local OWNER_ONLY = { LockPrompt = true, TrainPrompt = true, TrapPrompt = true }

local function plotOf(instance)
	local node = instance
	while node and node ~= workspace do
		if node:IsA("Model") and node.Name:match("^Plot%d+$") then return node end
		node = node.Parent
	end
	return nil
end

local function refresh(prompt)
	if not prompt:IsA("ProximityPrompt") then return end
	local plot = plotOf(prompt)
	if not plot then return end
	local owner = plot:GetAttribute("Owner") or 0
	local mine = owner == player.UserId
	if prompt.Name == "StealPrompt" then
		prompt.Enabled = not mine
	elseif OWNER_ONLY[prompt.Name] then
		prompt.Enabled = mine
	end
end

function PromptController.Start()
	local world = workspace:WaitForChild("World")
	local plots = world:WaitForChild("Plots")
	for _, d in ipairs(plots:GetDescendants()) do refresh(d) end
	plots.DescendantAdded:Connect(function(d) task.defer(refresh, d) end)
	-- when ownership changes, re-evaluate that plot's prompts
	for _, plot in ipairs(plots:GetChildren()) do
		plot:GetAttributeChangedSignal("Owner"):Connect(function()
			for _, d in ipairs(plot:GetDescendants()) do refresh(d) end
		end)
	end
end

return PromptController
