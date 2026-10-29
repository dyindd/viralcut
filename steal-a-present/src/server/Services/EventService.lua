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

local Decor = require(script.Parent.Parent.Decor)

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

function EventService.GetIncomeMultiplier()
	if EventService.IsActive("DoubleCash") then
		return Config.Events.DoubleCash.Multiplier
	end
	return 1
end

function EventService.GetMutationChanceMultiplier()
	if EventService.IsActive("MutationMadness") then
		return Config.Events.MutationMadness.Multiplier
	end
	return 1
end

function EventService.GetLockMultiplier()
	if EventService.IsActive("KrampusNight") then
		return Config.Events.KrampusNight.LockMultiplier
	end
	return 1
end

-- Santa flies a sleigh + reindeer team across the hub and drops 1-7 sacks along the way
local function buildFlyingSleigh(parent)
	local group = Instance.new("Model")
	group.Name = "SantaSleigh"
	group.Parent = parent
	local origin = CFrame.new()
	local sleigh = Decor.Sleigh(group, origin, 1.2)
	Decor.Santa(group, origin * CFrame.new(0, 3.8, 1.6), 0.9)
	for i = 1, 4 do
		Decor.Reindeer(group, origin * CFrame.new((i % 2 == 0) and 1.6 or -1.6, -1, -9 - math.ceil(i / 2) * 5.5), 0.9)
	end
	group.PrimaryPart = sleigh.PrimaryPart
	local trail = Instance.new("ParticleEmitter")
	trail.Rate = 40
	trail.Lifetime = NumberRange.new(1, 1.6)
	trail.Speed = NumberRange.new(1, 2)
	trail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120))
	trail.LightEmission = 1
	trail.Parent = sleigh.PrimaryPart
	return group
end

local function sleighDrop()
	local cfg = Config.Events.SleighDrop
	local Conveyor = Registry.Get("ConveyorService")
	local hub = Workspace:FindFirstChild("World") and Workspace.World:FindFirstChild("Hub")
	local count = rng:NextInteger(cfg.MinSacks or 1, cfg.MaxSacks or 7)
	local a = rng:NextNumber(0, math.pi * 2)
	local startPos = Vector3.new(math.cos(a) * 170, cfg.Height, math.sin(a) * 170)
	local endPos = Vector3.new(-startPos.X, cfg.Height, -startPos.Z)
	local dir = (endPos - startPos).Unit
	local group = hub and buildFlyingSleigh(hub)
	local drops = {}
	for i = 1, count do drops[i] = 0.25 + 0.5 * (i - 0.5) / count end
	task.spawn(function()
		local t0 = os.clock()
		local nextDrop = 1
		while true do
			local a01 = math.min(1, (os.clock() - t0) / cfg.FlightSeconds)
			local pos = startPos:Lerp(endPos, a01) + Vector3.new(0, math.sin(a01 * math.pi * 3) * 3, 0)
			if group and group.Parent then group:PivotTo(CFrame.lookAt(pos, pos + dir)) end
			while nextDrop <= count and a01 >= drops[nextDrop] do
				local ground = Vector3.new(pos.X + rng:NextNumber(-8, 8), 0, pos.Z + rng:NextNumber(-8, 8))
				Conveyor.SpawnFloorBox("Sack", ground, 150, cfg.Height - 2)
				Notify().Effect("SleighDrop", ground, nil)
				nextDrop = nextDrop + 1
			end
			if a01 >= 1 then break end
			task.wait(0.05)
		end
		if group then group:Destroy() end
	end)
end

function EventService.StartEvent(def)
	active = { Key = def.Key, Name = def.Name, EndsAt = now() + def.Duration, Color = def.Color, Description = def.Description }
	Notify().Announce("🌟 " .. def.Name .. " - " .. def.Description, def.Color, "event")
	broadcast()
	if def.Key == "SleighDrop" then
		sleighDrop()
	end
	Registry.Get("PresentService").RecalcAll()
	local endsAt = active.EndsAt
	task.delay(def.Duration, function()
		if active and active.EndsAt == endsAt then
			active = nil
			nextAt = now() + rng:NextInteger(Config.Events.MinInterval, Config.Events.MaxInterval)
			broadcast()
			Registry.Get("PresentService").RecalcAll()
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
