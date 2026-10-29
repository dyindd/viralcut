--[[
	EventService.lua
	Random server-wide events (Blizzard, Aurora, Sleigh Drop, Krampus Night, Lucky Hour).
	Other services ask: IsActive(key), GetLuckMultiplier(), GetLockMultiplier().
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Parent.Registry)

local EventService = {}

local active = nil
local nextAt = 0
local rng = Random.new()

local function now() return Workspace:GetServerTimeNow() end
local function Notify() return Registry.Get("NotifyService") end

local function broadcast(player)
	local payload = {
		Active = active and {
			Key = active.Key, Name = active.Name, EndsAt = active.EndsAt,
			Color = active.Color, Description = active.Description,
		} or nil,
		NextAt = nextAt,
		Now = now(),
	}
	if player then
		Remotes.Get("EventState"):FireClient(player, payload)
	else
		Remotes.Get("EventState"):FireAllClients(payload)
	end
end

function EventService.SendTo(player)
	broadcast(player)
end

function EventService.IsActive(key)
	return active ~= nil and active.Key == key and now() < active.EndsAt
end

function EventService.GetActive()
	if active and now() < active.EndsAt then return active end
	return nil
end

function EventService.GetLuckMultiplier()
	if EventService.IsActive("LuckyHour") then
		return Config.Events.LuckyHour.LuckMultiplier
	end
	return 1
end

function EventService.GetLockMultiplier()
	if EventService.IsActive("KrampusNight") then
		return Config.Events.KrampusNight.LockMultiplier
	end
	return 1
end

local function sleighDrop()
	local cfg = Config.Events.SleighDrop
	local Conveyor = Registry.Get("ConveyorService")
	for i = 1, cfg.SackCount do
		task.delay(i * 0.8, function()
			local angle = rng:NextNumber(0, math.pi * 2)
			local dist = rng:NextNumber(20, cfg.Radius)
			local pos = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
			Conveyor.SpawnFloorBox("Sack", pos, 150, cfg.DropHeight)
			Notify().Effect("SleighDrop", pos, nil)
		end)
	end
end

function EventService.StartEvent(def)
	active = { Key = def.Key, Name = def.Name, EndsAt = now() + def.Duration, Color = def.Color, Description = def.Description }
	Notify().Announce("🌟 " .. def.Name .. " - " .. def.Description, def.Color, "event")
	broadcast()
	if def.Key == "SleighDrop" then
		sleighDrop()
	end
	local endsAt = active.EndsAt
	task.delay(def.Duration, function()
		if active and active.EndsAt == endsAt then
			active = nil
			nextAt = now() + rng:NextInteger(Config.Events.MinInterval, Config.Events.MaxInterval)
			broadcast()
		end
	end)
end

function EventService.Init() end

function EventService.Start()
	nextAt = now() + rng:NextInteger(Config.Events.MinInterval, Config.Events.MaxInterval)
	broadcast()
	task.spawn(function()
		while true do
			task.wait(2)
			if Config.Events.Enabled and not active and now() >= nextAt and #Players:GetPlayers() > 0 then
				local def = Util.WeightedPick(Config.Events.List, "Weight", rng)
				if def then EventService.StartEvent(def) end
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.delay(2, broadcast, player)
	end)
end

return EventService
