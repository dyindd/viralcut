--[[
	PlotService.lua
	Owns the ring of bases: assigns a plot on join, frees it on leave, slot counts,
	the base lock/shield, the sign, and routes pad touches / prompts to other services.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Parent.Registry)
local Validate = require(script.Parent.Parent.Validate)
local RateLimiter = require(script.Parent.Parent.RateLimiter)
local WorldBuilder = require(script.Parent.Parent.WorldBuilder)
local Decor = require(script.Parent.Parent.Decor)

local PlotService = {}

local plots = {}      -- [index] = plot
local byUser = {}     -- [userId] = plot
local touchDebounce = {} -- [player] = os.clock()

local function now()
	return Workspace:GetServerTimeNow()
end

local function Data() return Registry.Get("DataService") end

---------------------------------------------------------------------------
-- Build + wire
---------------------------------------------------------------------------
local function wrapPlot(model)
	local sign = model:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChild("SignGui")
	local plot = {
		Index = model:GetAttribute("Index"),
		Model = model,
		CFrame = model.PrimaryPart.CFrame,
		Floor = model.PrimaryPart,
		Deposit = model:FindFirstChild("DepositPad"),
		Collect = model:FindFirstChild("CollectPad"),
		LockButton = model:FindFirstChild("LockButton"),
		Bench = model:FindFirstChild("Bench"),
		Dome = model:FindFirstChild("Dome"),
		LockLamp = model:FindFirstChild("LockLamp", true),
		LaunchPad = model:FindFirstChild("LaunchPad", true),
		PileAnchor = model:FindFirstChild("PileAnchor"),
		PileModel = nil,
		Color = nil,
		Delivery = model:FindFirstChild("Delivery"),
		SpawnPoint = model:FindFirstChild("SpawnPoint"),
		SlotsFolder = model:FindFirstChild("Slots"),
		SocketsFolder = model:FindFirstChild("TrapSockets"),
		Sign = gui and {
			Owner = gui:FindFirstChild("Owner"),
			Income = gui:FindFirstChild("Income"),
			Pile = gui:FindFirstChild("Pile"),
			Status = gui:FindFirstChild("Status"),
		} or nil,
		Slots = {},
		Owner = nil,
		LockUntil = 0,
		CooldownUntil = 0,
		IncomePerSec = 0,
		PresentModels = {},  -- [presentId] = model
		TrapModels = {},     -- [socketIndex] = model
	}
	for _, ped in ipairs(plot.SlotsFolder:GetChildren()) do
		plot.Slots[ped:GetAttribute("SlotIndex")] = ped
	end
	local presentsFolder = Instance.new("Folder")
	presentsFolder.Name = "Presents"
	presentsFolder.Parent = model
	plot.PresentsFolder = presentsFolder
	return plot
end

local function playerFromHit(hit)
	local char = hit and hit.Parent
	if not char then return nil end
	local player = Players:GetPlayerFromCharacter(char)
	if not player then
		-- accessories are one level deeper
		player = Players:GetPlayerFromCharacter(char.Parent)
	end
	return player
end

local function debounced(player, key, seconds)
	local t = os.clock()
	local k = tostring(player.UserId) .. key
	if touchDebounce[k] and t - touchDebounce[k] < seconds then
		return true
	end
	touchDebounce[k] = t
	return false
end

local function wirePlot(plot)
	plot.Deposit.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or plot.Owner ~= player then return end
		if debounced(player, "deposit", 0.4) then return end
		Registry.Get("PresentService").TryDeposit(player, plot)
	end)
	plot.Collect.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player or plot.Owner ~= player then return end
		if debounced(player, "collect", 0.5) then return end
		Registry.Get("PresentService").Collect(player, plot)
	end)
	if plot.LaunchPad then
		plot.LaunchPad.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			if not player or plot.Owner ~= player or not Config.LaunchPad.Enabled then return end
			if Registry.Get("CarryService").IsCarrying(player) then return end
			if debounced(player, "launch", Config.LaunchPad.Cooldown) then return end
			local root = Validate.GetRoot(player)
			if not root then return end
			local flat = Vector3.new(-root.Position.X, 0, -root.Position.Z)
			if flat.Magnitude < 1 then return end
			Registry.Get("CombatService").Impulse(root, flat.Unit * Config.LaunchPad.Speed + Vector3.new(0, Config.LaunchPad.Up, 0), 0.25)
			Registry.Get("NotifyService").Effect("Launch", root.Position, nil)
		end)
	end
	local lockPrompt = plot.LockButton:FindFirstChild("LockPrompt")
	if lockPrompt then
		lockPrompt.Triggered:Connect(function(player)
			if plot.Owner ~= player then
				Registry.Get("NotifyService").Notify(player, "This isn't your base!", "error")
				return
			end
			PlotService.Lock(player)
		end)
	end
	local trainPrompt = plot.Bench:FindFirstChild("TrainPrompt")
	if trainPrompt then
		trainPrompt.Triggered:Connect(function(player)
			if plot.Owner ~= player then
				Registry.Get("NotifyService").Notify(player, "Train at YOUR base!", "error")
				return
			end
			Registry.Get("StrengthService").Toggle(player, plot)
		end)
	end
	for _, socket in ipairs(plot.SocketsFolder:GetChildren()) do
		local prompt = socket:FindFirstChild("TrapPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				if plot.Owner ~= player then return end
				Remotes.Get("OpenPanel"):FireClient(player, "Traps", { Socket = socket:GetAttribute("SocketIndex") })
			end)
		end
	end
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
function PlotService.GetPlot(player)
	return player and byUser[player.UserId] or nil
end

function PlotService.GetPlotByUserId(userId)
	return byUser[userId]
end

function PlotService.GetPlotByIndex(index)
	return plots[index]
end

function PlotService.AllPlots()
	return plots
end

function PlotService.GetSlotCount(player)
	local profile = Data().GetProfile(player)
	if not profile then return 0 end
	local count = Config.Plots.StartingSlots
		+ profile.Rebirths * Config.Plots.SlotsPerRebirth
		+ (profile.BonusSlots or 0)
	if Data().HasGamepass(player, "ExtraSlots") then
		count = count + Config.Monetization.ExtraSlotsAmount
	end
	return math.min(count, Config.Plots.MaxSlots)
end

function PlotService.GetFreeSlot(player)
	local profile = Data().GetProfile(player)
	if not profile then return nil end
	local used = {}
	for _, record in ipairs(profile.Presents) do
		if record.Slot then used[record.Slot] = true end
	end
	for i = 1, PlotService.GetSlotCount(player) do
		if not used[i] then
			return i
		end
	end
	return nil
end

function PlotService.IsLocked(plot)
	return plot ~= nil and now() < plot.LockUntil
end

function PlotService.RefreshSlots(plot)
	local count = plot.Owner and PlotService.GetSlotCount(plot.Owner) or 0
	for i, ped in pairs(plot.Slots) do
		local visible = i <= count
		ped.Transparency = visible and 0 or 1
		ped.CanCollide = visible
		for _, child in ipairs(ped:GetChildren()) do
			if child:IsA("BasePart") then child.Transparency = visible and 0 or 1 end
		end
	end
end

function PlotService.UpdateSign(plot)
	if not plot.Sign then return end
	local owner = plot.Owner
	if not owner then
		plot.Sign.Owner.Text = "EMPTY BASE"
		plot.Sign.Income.Text = ""
		plot.Sign.Pile.Text = ""
		plot.Sign.Status.Text = ""
		return
	end
	local profile = Data().GetProfile(owner)
	plot.Sign.Owner.Text = owner.DisplayName .. "'s Base"
	plot.Sign.Income.Text = "$" .. Util.FormatNumber(plot.IncomePerSec) .. "/s"
	plot.Sign.Pile.Text = profile and ("Pile: $" .. Util.FormatNumber(profile.Pile)) or ""
	if PlotService.IsLocked(plot) then
		plot.Sign.Status.Text = "🔒 LOCKED " .. Util.FormatTime(plot.LockUntil - now())
	else
		plot.Sign.Status.Text = ""
	end
end

function PlotService.SendBaseState(player)
	local plot = byUser[player.UserId]
	local profile = Data().GetProfile(player)
	if not plot or not profile then return end
	local used = #profile.Presents
	Remotes.Get("BaseState"):FireClient(player, {
		LockUntil = plot.LockUntil,
		CooldownUntil = plot.CooldownUntil,
		Pile = profile.Pile,
		Slots = PlotService.GetSlotCount(player),
		Used = used,
		Income = plot.IncomePerSec,
		Now = now(),
		PlotIndex = plot.Index,
	})
end

local function setDome(plot, visible)
	if plot.Dome then
		plot.Dome.Transparency = visible and 0.55 or 1
	end
	local lamp = plot.LockLamp
	if lamp then
		local color = visible and Color3.fromRGB(90, 255, 120) or Color3.fromRGB(255, 80, 80)
		lamp.Color = color
		local light = lamp:FindFirstChildOfClass("PointLight")
		if light then light.Color = color end
	end
end

function PlotService.Lock(player)
	if not RateLimiter.Check(player, "Lock") then return false end
	local plot = byUser[player.UserId]
	local profile = Data().GetProfile(player)
	local Notify = Registry.Get("NotifyService")
	if not plot or not profile then return false end
	local t = now()
	if t < plot.LockUntil then
		Notify.Notify(player, "Your base is already locked!", "info")
		return false
	end
	if t < plot.CooldownUntil then
		Notify.Notify(player, "Lock on cooldown: " .. Util.FormatTime(plot.CooldownUntil - t), "error")
		return false
	end
	local duration = Config.Lock.Duration
	if Data().HasGamepass(player, "VIP") then
		duration = duration + Config.Lock.VIPDurationBonus
	end
	if (profile.Boosts.LockExtendSeconds or 0) > 0 then
		duration = duration + profile.Boosts.LockExtendSeconds
		profile.Boosts.LockExtendSeconds = 0
	end
	duration = duration * Registry.Get("EventService").GetLockMultiplier()
	plot.LockUntil = t + duration
	plot.CooldownUntil = plot.LockUntil + Config.Lock.Cooldown
	setDome(plot, true)
	profile.Stats.Locks = (profile.Stats.Locks or 0) + 1
	Registry.Get("QuestService").Progress(player, "Lock", 1)
	Registry.Get("TutorialService").Complete(player, "Lock")
	Notify.Notify(player, "Base locked for " .. Util.FormatTime(duration) .. "!", "success")
	PlotService.SendBaseState(player)
	PlotService.UpdateSign(plot)
	local myLock = plot.LockUntil
	task.delay(duration + 0.25, function()
		if plot.Owner == player and plot.LockUntil == myLock then
			setDome(plot, false)
			PlotService.UpdateSign(plot)
			if player.Parent then
				Notify.Notify(player, "Your base lock expired!", "info")
				PlotService.SendBaseState(player)
			end
		end
	end)
	return true
end

---------------------------------------------------------------------------
-- Colors + the growing present pile
---------------------------------------------------------------------------
function PlotService.DefaultColor(plot)
	local palette = WorldBuilder.Palette
	return palette[((plot.Index - 1) % #palette) + 1]
end

function PlotService.ColorFor(player, plot)
	local profile = Data().GetProfile(player)
	local palette = WorldBuilder.Palette
	if profile and (profile.BaseColor or 0) > 0 and palette[profile.BaseColor] then
		return palette[profile.BaseColor]
	end
	return PlotService.DefaultColor(plot)
end

function PlotService.ApplyColor(plot, color)
	plot.Color = color
	for _, part in ipairs(plot.Model:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("Colorable") then
			part.Color = color
		end
	end
end

-- Snowflake shop: cycle to the next palette color
function PlotService.Repaint(player)
	local plot = byUser[player.UserId]
	local profile = Data().GetProfile(player)
	if not plot or not profile then return false end
	profile.BaseColor = ((profile.BaseColor or 0) % #WorldBuilder.Palette) + 1
	PlotService.ApplyColor(plot, PlotService.ColorFor(player, plot))
	Registry.Get("NotifyService").Effect("Rebirth", plot.Deposit.Position, nil)
	Data().Replicate(player)
	return true
end

function PlotService.UpdatePile(plot, count)
	if plot.PileModel then
		plot.PileModel:Destroy()
		plot.PileModel = nil
	end
	if count > 0 and plot.PileAnchor then
		plot.PileModel = Decor.PresentPile(plot.Model, plot.PileAnchor.CFrame, math.min(count, 4))
	end
end

function PlotService.TeleportToPlot(player)
	local plot = byUser[player.UserId]
	local root = Validate.GetRoot(player)
	if plot and root then
		root.CFrame = plot.SpawnPoint.CFrame + Vector3.new(0, 3, 0)
	end
end

---------------------------------------------------------------------------
-- Assign / release
---------------------------------------------------------------------------
local function assign(player, profile)
	if byUser[player.UserId] then return end
	for _, plot in ipairs(plots) do
		if plot.Owner == nil then
			plot.Owner = player
			plot.LockUntil = 0
			plot.CooldownUntil = 0
			plot.Model:SetAttribute("Owner", player.UserId)
			byUser[player.UserId] = plot
			PlotService.ApplyColor(plot, PlotService.ColorFor(player, plot))
			PlotService.RefreshSlots(plot)
			Registry.Get("PresentService").RebuildBase(player)
			Registry.Get("TrapService").RebuildTraps(player)
			PlotService.UpdateSign(plot)
			PlotService.SendBaseState(player)
			if player.Character then
				PlotService.TeleportToPlot(player)
			end
			return
		end
	end
	warn("[PlotService] No free plot for " .. player.Name)
	player:Kick("The server is full. Please try again!")
end

local function release(player, profile)
	local plot = byUser[player.UserId]
	if not plot then return end
	Registry.Get("PresentService").ClearBase(plot)
	Registry.Get("TrapService").ClearTraps(plot)
	plot.Owner = nil
	plot.LockUntil = 0
	plot.CooldownUntil = 0
	plot.IncomePerSec = 0
	plot.Model:SetAttribute("Owner", 0)
	setDome(plot, false)
	PlotService.UpdatePile(plot, 0)
	PlotService.ApplyColor(plot, PlotService.DefaultColor(plot))
	PlotService.RefreshSlots(plot)
	PlotService.UpdateSign(plot)
	byUser[player.UserId] = nil
end

function PlotService.Init()
	WorldBuilder.Build()
	local folder = Workspace:WaitForChild("World"):WaitForChild("Plots")
	for _, model in ipairs(folder:GetChildren()) do
		local plot = wrapPlot(model)
		plots[plot.Index] = plot
		wirePlot(plot)
	end
	Data().OnLoaded(assign)
	Data().OnBeforeRelease(release)
	-- UI lock button (mobile friendly): must be near your own base
	Remotes.Get("LockBase").OnServerEvent:Connect(function(player)
		local plot = byUser[player.UserId]
		if not plot then return end
		if not Validate.Near(player, plot.Floor, 45) then
			Registry.Get("NotifyService").Notify(player, "Go to your base to lock it!", "error")
			return
		end
		PlotService.Lock(player)
	end)
end

function PlotService.Start()
	local function hook(player)
		player.CharacterAdded:Connect(function(char)
			task.wait(0.2)
			PlotService.TeleportToPlot(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do hook(player) end
	-- keep signs fresh (lock countdown) once a second
	task.spawn(function()
		while true do
			task.wait(1)
			for _, plot in ipairs(plots) do
				if plot.Owner then
					PlotService.UpdateSign(plot)
				end
			end
		end
	end)
end

return PlotService
