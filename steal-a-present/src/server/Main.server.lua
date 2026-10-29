--[[
	Main.server.lua  (ServerScriptService.Server.Main)
	Boots every service in a fixed order: register -> Init (wire remotes, build world) -> Start (loops).
	Order matters for OnLoaded callbacks: PlotService must assign a base before others need it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Registry)

Remotes.Init()

local ORDER = {
	"NotifyService",
	"DataService",
	"PlotService",
	"CarryService",
	"ConveyorService",
	"PresentService",
	"StealService",
	"CombatService",
	"GrinchService",
	"EventService",
	"StrengthService",
	"TrapService",
	"RebirthService",
	"QuestService",
	"IndexService",
	"RetentionService",
	"GiftService",
	"MonetizationService",
	"LeaderstatsService",
}

local servicesFolder = script.Parent:WaitForChild("Services")
local loaded = {}
for _, name in ipairs(ORDER) do
	local module = servicesFolder:WaitForChild(name)
	local service = require(module)
	Registry.Register(name, service)
	table.insert(loaded, { Name = name, Service = service })
end

for _, entry in ipairs(loaded) do
	if entry.Service.Init then
		local ok, err = pcall(entry.Service.Init)
		if not ok then warn("[Main] " .. entry.Name .. ".Init failed: " .. tostring(err)) end
	end
end
for _, entry in ipairs(loaded) do
	if entry.Service.Start then
		local ok, err = pcall(entry.Service.Start)
		if not ok then warn("[Main] " .. entry.Name .. ".Start failed: " .. tostring(err)) end
	end
end

print(string.format("[%s] server ready - %d services, max %d players", Config.GameName, #loaded, Config.MaxPlayersPerServer))
