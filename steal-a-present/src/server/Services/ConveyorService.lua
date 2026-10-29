--[[
	ConveyorService.lua
	Spawns wrapped boxes on the belt, moves them, sells them (ProximityPrompt), and manages
	loose "floor boxes" (dropped boxes, sleigh-drop sacks, reward boxes at your base).
	Rarity is NEVER decided here - only the box TIER. Rarity is rolled at the base on unwrap.
]]

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PresentModels = require(ReplicatedStorage.Shared.PresentModels)
local Registry = require(script.Parent.Parent.Registry)
local Validate = require(script.Parent.Parent.Validate)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

local ConveyorService = {}

local beltBoxes = {}     -- list of { Id, Model, Tier, Progress }
local beltById = {}
local floorBoxes = {}    -- [Id] = { Model, Tier }
local startPos, endPos, direction, beltLength
local beltFolder, pickupFolder
local rng = Random.new()

local function Data() return Registry.Get("DataService") end
local function Notify() return Registry.Get("NotifyService") end

---------------------------------------------------------------------------
-- Shared "can this player take this box" check + hand-over
---------------------------------------------------------------------------
local function tryTake(player, tierKey, model, price)
	local profile = Data().GetProfile(player)
	if not profile then return false end
	local Carry = Registry.Get("CarryService")
	if Carry.IsCarrying(player) then
		Notify().Notify(player, "You're already carrying something! Drop it first.", "error")
		return false
	end
	if not Validate.Near(player, model, Config.MaxInteractDistance + 4) then
		return false
	end
	local tier = PresentModels.GetTier(tierKey)
	local strength = profile.Strength
	if Data().HasGamepass(player, "Strong") then strength = strength * 2 end
	if strength < tier.Strength then
		Notify().Notify(player, string.format("Too heavy! You need %s Strength (train at your bench).", Util.FormatNumber(tier.Strength)), "error")
		return false
	end
	if not Validate.GetRoot(player) then
		return false -- dead / no character
	end
	if price > 0 then
		if not Data().SpendCash(player, price) then
			Notify().Notify(player, "Not enough cash! Need $" .. Util.FormatNumber(price), "error")
			return false
		end
	end
	local ok = Carry.Give(player, { Kind = "Box", Tier = tier.Key, Model = model })
	if not ok then
		if price > 0 then Data().AddCash(player, price) end -- refund, nothing was taken
		return false
	end
	if price > 0 then
		profile.Stats.Bought = (profile.Stats.Bought or 0) + 1
		Registry.Get("QuestService").Progress(player, "Buy", 1)
	end
	return true
end

---------------------------------------------------------------------------
-- Belt
---------------------------------------------------------------------------
local function removeFromBelt(box)
	beltById[box.Id] = nil
	for i, b in ipairs(beltBoxes) do
		if b == box then
			table.remove(beltBoxes, i)
			break
		end
	end
end

local function spawnBeltBox()
	if #beltBoxes >= Config.Conveyor.MaxOnBelt then return end
	-- keep a gap after the last spawned box
	local last = beltBoxes[#beltBoxes]
	if last and last.Progress < Config.Conveyor.BoxGap then return end
	local tier = Util.WeightedPick(Config.BoxTiers, "SpawnWeight", rng)
	if not tier then return end
	local model = PresentModels.MakeBox(tier.Key)
	local id = Util.NewId("box")
	model:SetAttribute("BoxId", id)
	model:SetAttribute("Price", tier.Price)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy  $" .. Util.FormatNumber(tier.Price)
	prompt.ObjectText = tier.Name .. (tier.Strength > 0 and ("  (needs " .. Util.FormatNumber(tier.Strength) .. " STR)") or "")
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	local box = { Id = id, Model = model, Tier = tier.Key, Progress = 0, Price = tier.Price }
	prompt.Triggered:Connect(function(player)
		if not RateLimiter.Check(player, "BuyBox") then return end
		if not beltById[id] then return end
		if tryTake(player, tier.Key, model, tier.Price) then
			removeFromBelt(box)
		end
	end)
	model:PivotTo(CFrame.new(startPos + Vector3.new(0, model.PrimaryPart.Size.Y / 2 + 0.2, 0)))
	model.Parent = beltFolder
	table.insert(beltBoxes, box)
	beltById[id] = box
end

local function stepBelt(dt)
	local i = 1
	while i <= #beltBoxes do
		local box = beltBoxes[i]
		box.Progress = box.Progress + Config.Conveyor.Speed * dt
		if box.Progress >= beltLength or not box.Model.Parent then
			box.Model:Destroy()
			removeFromBelt(box)
		else
			local body = box.Model.PrimaryPart
			local y = body.Size.Y / 2 + 0.2 + math.sin(os.clock() * 4 + i) * 0.08
			local pos = startPos + direction * box.Progress + Vector3.new(0, y, 0)
			box.Model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(os.clock() * 25 % 360), 0))
			i = i + 1
		end
	end
end

---------------------------------------------------------------------------
-- Floor boxes (dropped / sleigh / rewards)
---------------------------------------------------------------------------
function ConveyorService.SpawnFloorBox(tierKey, position, lifetime, fromHeight, ignore)
	local tier = PresentModels.GetTier(tierKey)
	local model = PresentModels.MakeBox(tier.Key)
	local id = Util.NewId("floor")
	model:SetAttribute("BoxId", id)
	-- find the ground under the position (ignore belt boxes, pickups, characters)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local filter = { beltFolder, pickupFolder }
	for _, inst in ipairs(ignore or {}) do table.insert(filter, inst) end
	for _, other in ipairs(game:GetService("Players"):GetPlayers()) do
		if other.Character then table.insert(filter, other.Character) end
	end
	params.FilterDescendantsInstances = filter
	local ray = Workspace:Raycast(position + Vector3.new(0, 20, 0), Vector3.new(0, -200, 0), params)
	local groundY = ray and ray.Position.Y or 0
	local restCF = CFrame.new(position.X, groundY + model.PrimaryPart.Size.Y / 2 + 0.1, position.Z)
	model:PivotTo(restCF)
	if fromHeight and fromHeight > 0 then
		-- "falls from the sky" for sleigh drops
		task.spawn(function()
			local t0 = os.clock()
			local dur = 1.6
			while os.clock() - t0 < dur and model.Parent do
				local a = (os.clock() - t0) / dur
				local y = fromHeight * (1 - a * a)
				model:PivotTo(restCF * CFrame.new(0, y, 0) * CFrame.Angles(0, a * 6, 0))
				task.wait()
			end
			if model.Parent then model:PivotTo(restCF) end
		end)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = tier.Name .. (tier.Strength > 0 and ("  (needs " .. Util.FormatNumber(tier.Strength) .. " STR)") or "")
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	local entry = { Model = model, Tier = tier.Key }
	floorBoxes[id] = entry
	prompt.Triggered:Connect(function(player)
		if not RateLimiter.Check(player, "BuyBox") then return end
		if not floorBoxes[id] then return end
		if tryTake(player, tier.Key, model, 0) then
			floorBoxes[id] = nil
		end
	end)
	model.Parent = pickupFolder
	task.delay(lifetime or 120, function()
		if floorBoxes[id] then
			floorBoxes[id] = nil
			model:Destroy()
		end
	end)
	return model
end

-- Rewards: a free box appears at the player's base delivery spot
function ConveyorService.GiveBoxAtBase(player, tierKey)
	local plot = Registry.Get("PlotService").GetPlot(player)
	if not plot then return nil end
	local jitter = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
	Notify().Notify(player, "A " .. PresentModels.GetTier(tierKey).Name .. " was delivered to your base!", "success")
	return ConveyorService.SpawnFloorBox(tierKey, plot.Delivery.Position + jitter, 600)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function ConveyorService.Init()
	local world = Workspace:WaitForChild("World")
	local conveyor = world:WaitForChild("Hub"):WaitForChild("Conveyor")
	startPos = conveyor:GetAttribute("Start")
	endPos = conveyor:GetAttribute("End")
	direction = (endPos - startPos).Unit
	beltLength = (endPos - startPos).Magnitude
	beltFolder = world:WaitForChild("BeltBoxes")
	pickupFolder = world:WaitForChild("Pickups")

	-- optional client-side "buy nearest box" remote (mobile convenience)
	Remotes.Get("BuyBox").OnServerEvent:Connect(function(player, boxId)
		if not RateLimiter.Check(player, "BuyBox") then return end
		if not Validate.IsString(boxId, 64) then return end
		local box = beltById[boxId]
		if box and tryTake(player, box.Tier, box.Model, box.Price) then
			removeFromBelt(box)
		end
	end)
end

function ConveyorService.Start()
	task.spawn(function()
		while true do
			spawnBeltBox()
			task.wait(Config.Conveyor.SpawnInterval)
		end
	end)
	RunService.Heartbeat:Connect(stepBelt)
end

return ConveyorService
