--[[
	BaseLifeService.lua - little bits of life at owned bases: an elf worker that wanders between
	your pedestals carrying a gift. Pure decoration, server-driven at 10 updates/sec.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Registry = require(script.Parent.Parent.Registry)
local Decor = require(script.Parent.Parent.Decor)

local BaseLifeService = {}
local elves = {}   -- [plotIndex] = { Model, Plot, Feet, Target, WaitUntil, Scale }
local rng = Random.new()

local function Data() return Registry.Get("DataService") end
local function Plots() return Registry.Get("PlotService") end

local function floorTop(plot)
	return plot.Floor.Position.Y + plot.Floor.Size.Y / 2
end

local function pickTarget(plot, elf)
	local count = plot.Owner and Plots().GetSlotCount(plot.Owner) or 0
	local options = { plot.Deposit.Position, plot.Collect.Position, plot.Delivery.Position }
	for i = 1, count do
		local ped = plot.Slots[i]
		if ped then table.insert(options, ped.Position) end
	end
	local pick = options[rng:NextInteger(1, #options)]
	-- stand a little to the side so it doesn't clip the present
	return Vector3.new(pick.X + rng:NextNumber(-3, 3), floorTop(plot), pick.Z + rng:NextNumber(-3, 3))
end

function BaseLifeService.Spawn(plot)
	if not Config.BaseLife.ElfEnabled or elves[plot.Index] then return end
	local scale = 0.8
	local feet = Vector3.new(plot.Delivery.Position.X, floorTop(plot), plot.Delivery.Position.Z)
	local model = Decor.Elf(plot.Model, CFrame.new(feet), scale)
	model.Name = "ElfWorker"
	elves[plot.Index] = { Model = model, Plot = plot, Feet = feet, Target = nil, WaitUntil = 0, Scale = scale }
end

function BaseLifeService.Despawn(plot)
	local elf = elves[plot.Index]
	if elf then
		elf.Model:Destroy()
		elves[plot.Index] = nil
	end
end

local function step(dt)
	local now = os.clock()
	for _, elf in pairs(elves) do
		if now >= elf.WaitUntil then
			if not elf.Target then
				elf.Target = pickTarget(elf.Plot, elf)
			end
			local toTarget = elf.Target - elf.Feet
			toTarget = Vector3.new(toTarget.X, 0, toTarget.Z)
			local dist = toTarget.Magnitude
			if dist < 0.5 then
				elf.Target = nil
				elf.WaitUntil = now + rng:NextNumber(1, 2.5)
			else
				local stepLen = math.min(dist, Config.BaseLife.ElfSpeed * dt)
				elf.Feet = elf.Feet + toTarget.Unit * stepLen
				local bob = math.abs(math.sin(now * 10)) * 0.25
				local torso = elf.Feet + Vector3.new(0, 2.5 * elf.Scale + bob, 0)
				local look = Vector3.new(elf.Target.X, torso.Y, elf.Target.Z)
				elf.Model:PivotTo(CFrame.lookAt(torso, look))
			end
		end
	end
end

function BaseLifeService.Init()
	Data().OnLoaded(function(player)
		local plot = Plots().GetPlot(player)
		if plot then BaseLifeService.Spawn(plot) end
	end)
	Data().OnBeforeRelease(function(player)
		local plot = Plots().GetPlot(player)
		if plot then BaseLifeService.Despawn(plot) end
	end)
end

function BaseLifeService.Start()
	task.spawn(function()
		while true do
			local dt = task.wait(0.1)
			local ok, err = pcall(step, dt)
			if not ok then warn("[BaseLife] " .. tostring(err)) end
		end
	end)
end

return BaseLifeService
