--[[
	TrapService.lua
	Base defense. Buy a trap for a socket: Ice Patch (slow), Mistletoe Snare (freeze),
	Elf Guard (auto-whacks carrying thieves in range). Traps never affect the owner.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Parent.Registry)
local Validate = require(script.Parent.Parent.Validate)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

local TrapService = {}
local trapDefs = {}
for _, def in ipairs(Config.Traps.List) do trapDefs[def.Key] = def end

local function Data() return Registry.Get("DataService") end
local function Plots() return Registry.Get("PlotService") end
local function Notify() return Registry.Get("NotifyService") end

local function getSocket(plot, index)
	return plot.SocketsFolder:FindFirstChild("Socket" .. index)
end

local function playerFromHit(hit)
	local char = hit and hit.Parent
	if not char then return nil end
	return Players:GetPlayerFromCharacter(char) or Players:GetPlayerFromCharacter(char.Parent)
end

local function buildTrapModel(plot, socket, def)
	local model = Instance.new("Model")
	model.Name = "Trap_" .. def.Key
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.CanCollide = false
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(0.4, 6, 6)
	base.Color = def.Color
	base.Material = def.Key == "IcePatch" and Enum.Material.Ice or Enum.Material.Neon
	base.CFrame = socket.CFrame * CFrame.new(0.3, 0, 0)
	base.Parent = model
	model.PrimaryPart = base
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 160, 0, 40)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.MaxDistance = 60
	bb.Parent = base
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.Font = Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.Text = def.Name
	tl.TextColor3 = def.Color
	tl.TextStrokeTransparency = 0
	tl.Parent = bb
	if def.Key == "ElfGuard" then
		local elf = Instance.new("Part")
		elf.Name = "Elf"
		elf.Anchored = true
		elf.CanCollide = false
		elf.Size = Vector3.new(2, 4, 2)
		elf.Color = Color3.fromRGB(80, 200, 90)
		elf.CFrame = socket.CFrame * CFrame.new(2.5, 0, 0)
		elf.Parent = model
	end
	model.Parent = plot.Model
	return model
end

local function wireTrap(plot, socketIndex, def, model)
	local cooldowns = {}  -- [player] = os.clock()
	local base = model.PrimaryPart
	local function ready(player)
		local t = os.clock()
		if cooldowns[player] and t - cooldowns[player] < def.Cooldown then return false end
		cooldowns[player] = t
		return true
	end
	if def.Key == "IcePatch" or def.Key == "Mistletoe" then
		base.CanTouch = true
		base.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if not player or player == plot.Owner then return end
			if not ready(player) then return end
			local Carry = Registry.Get("CarryService")
			if def.Key == "IcePatch" then
				Carry.SetSpeedModifier(player, "Ice", def.SlowMultiplier)
				Notify().Notify(player, "You slipped on ice!", "error")
				task.delay(def.SlowSeconds, function() if player.Parent then Carry.SetSpeedModifier(player, "Ice", nil) end end)
			else
				Carry.SetSpeedModifier(player, "Freeze", 0)
				Notify().Notify(player, "Caught in the mistletoe snare!", "error")
				task.delay(def.FreezeSeconds, function() if player.Parent then Carry.SetSpeedModifier(player, "Freeze", nil) end end)
			end
			Notify().Effect("Trap", base.Position, { Trap = def.Key })
		end)
	elseif def.Key == "ElfGuard" then
		task.spawn(function()
			while model.Parent do
				task.wait(1)
				local Carry = Registry.Get("CarryService")
				for _, player in ipairs(Players:GetPlayers()) do
					if player ~= plot.Owner and Carry.IsCarrying(player) and Validate.Near(player, base, def.Range) and ready(player) then
						Registry.Get("CombatService").Hit(nil, player, "trap")
						Notify().Notify(player, "The Elf Guard whacked you!", "error")
						if plot.Owner then Notify().Notify(plot.Owner, "Your Elf Guard stopped " .. player.DisplayName .. "!", "success") end
						Notify().Effect("Trap", base.Position, { Trap = def.Key })
					end
				end
			end
		end)
	end
end

function TrapService.PlaceTrap(plot, socketIndex, trapKey)
	local def = trapDefs[trapKey]
	local socket = getSocket(plot, socketIndex)
	if not def or not socket then return end
	if plot.TrapModels[socketIndex] then
		plot.TrapModels[socketIndex]:Destroy()
	end
	local model = buildTrapModel(plot, socket, def)
	plot.TrapModels[socketIndex] = model
	socket:SetAttribute("Trap", def.Key)
	local prompt = socket:FindFirstChild("TrapPrompt")
	if prompt then
		prompt.ObjectText = def.Name
		prompt.ActionText = "Replace Trap"
	end
	wireTrap(plot, socketIndex, def, model)
end

function TrapService.ClearTraps(plot)
	for index, model in pairs(plot.TrapModels) do
		model:Destroy()
		plot.TrapModels[index] = nil
		local socket = getSocket(plot, index)
		if socket then
			socket:SetAttribute("Trap", "")
			local prompt = socket:FindFirstChild("TrapPrompt")
			if prompt then
				prompt.ObjectText = "Empty socket"
				prompt.ActionText = "Place Trap"
			end
		end
	end
end

function TrapService.RebuildTraps(player)
	local plot = Plots().GetPlot(player)
	local profile = Data().GetProfile(player)
	if not plot or not profile then return end
	TrapService.ClearTraps(plot)
	for key, trapKey in pairs(profile.Traps or {}) do
		local index = tonumber(key)
		if index and trapDefs[trapKey] then
			TrapService.PlaceTrap(plot, index, trapKey)
		end
	end
end

local function onBuyTrap(player, trapKey, socketIndex)
	if not RateLimiter.Check(player, "Default") then return end
	if not Validate.IsString(trapKey, 32) or not Validate.IsNumber(socketIndex, 1, Config.Traps.Sockets) then return end
	socketIndex = math.floor(socketIndex)
	local def = trapDefs[trapKey]
	local plot = Plots().GetPlot(player)
	local profile = Data().GetProfile(player)
	if not def or not plot or not profile then return end
	if profile.Traps[tostring(socketIndex)] == trapKey then
		Notify().Notify(player, "That trap is already there!", "info")
		return
	end
	if not Data().SpendCash(player, def.Price) then
		Notify().Notify(player, "Not enough cash! Need $" .. Util.FormatNumber(def.Price), "error")
		return
	end
	profile.Traps[tostring(socketIndex)] = trapKey
	TrapService.PlaceTrap(plot, socketIndex, trapKey)
	Notify().Notify(player, def.Name .. " placed!", "success")
	Data().Replicate(player)
end

function TrapService.Init()
	Remotes.Get("BuyTrap").OnServerEvent:Connect(onBuyTrap)
end

function TrapService.Start() end

return TrapService
