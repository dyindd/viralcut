--[[
	CarryService.lua
	One player can carry ONE thing: a wrapped Box (bought/picked up) or an unwrapped Present
	(stolen or gifted). Handles the weld, the walk-speed penalty, dropping, death and leaving.

	carry = {
	  Kind = "Box" | "Present",
	  Tier = "Small"...        (Box)
	  Record = {...}           (Present)  the present record (Id, Key, Rarity, Mutation, Traits, Slot)
	  FromUserId = n | nil     (Present)  who it was stolen from
	  Model = Model
	  Stolen = bool
	}
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PresentModels = require(ReplicatedStorage.Shared.PresentModels)
local Registry = require(script.Parent.Parent.Registry)
local Validate = require(script.Parent.Parent.Validate)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

local CarryService = {}

local carries = {}      -- [player] = carry
local speedMods = {}    -- [player] = { key = multiplier }

local function Data() return Registry.Get("DataService") end

---------------------------------------------------------------------------
-- Speed
---------------------------------------------------------------------------
function CarryService.SetSpeedModifier(player, key, mult)
	speedMods[player] = speedMods[player] or {}
	speedMods[player][key] = mult
	CarryService.ApplySpeed(player)
end

local function carryWeight(carry)
	if not carry then return 0 end
	if carry.Kind == "Box" then
		return PresentModels.GetTier(carry.Tier).Weight
	end
	local rarity = Catalog.Rarities[carry.Record.Rarity]
	return rarity and rarity.Weight or 0
end

function CarryService.ApplySpeed(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local profile = Data().GetProfile(player)
	local speed = Config.Carry.BaseWalkSpeed
	if Data().HasGamepass(player, "Speed") then
		speed = speed * Config.Monetization.SpeedMultiplier
	end
	local frozen = false
	for _, mult in pairs(speedMods[player] or {}) do
		if mult <= 0 then frozen = true end
		speed = speed * mult
	end
	local carry = carries[player]
	if carry then
		local weight = carryWeight(carry)
		local strength = profile and profile.Strength or 0
		if Data().HasGamepass(player, "Strong") then
			strength = strength * 2
		end
		local penalty = 0
		if weight > 0 then
			penalty = weight / (weight + strength + Config.Carry.Softness) * Config.Carry.MaxPenalty
		end
		if carry.Stolen then
			penalty = penalty + Config.Steal.StolenSpeedPenaltyBonus
		end
		speed = speed * (1 - math.min(penalty, 0.85))
	end
	if frozen then
		hum.WalkSpeed = 0
	else
		hum.WalkSpeed = math.max(Config.Carry.MinWalkSpeed, speed)
	end
end

---------------------------------------------------------------------------
-- Carry state
---------------------------------------------------------------------------
function CarryService.Get(player)
	return carries[player]
end

function CarryService.IsCarrying(player)
	return carries[player] ~= nil
end

local function describe(carry)
	if not carry then return nil end
	if carry.Kind == "Box" then
		local tier = PresentModels.GetTier(carry.Tier)
		return { Kind = "Box", Name = tier.Name, Tier = tier.Key, Weight = tier.Weight, Color = tier.Color }
	end
	local info = Catalog.PresentByKey[carry.Record.Key]
	local rarity = Catalog.Rarities[carry.Record.Rarity]
	return { Kind = "Present", Name = info and info.Name or carry.Record.Key, Key = carry.Record.Key, Icon = info and info.Icon, Rarity = carry.Record.Rarity,
		Mutation = carry.Record.Mutation, Weight = rarity and rarity.Weight or 0, Color = rarity and rarity.Color, Stolen = carry.Stolen }
end

local function sendState(player)
	Remotes.Get("CarryState"):FireClient(player, describe(carries[player]))
end

local function attachModel(player, model)
	local root = Validate.GetRoot(player)
	if not root then return false end
	local body = model.PrimaryPart
	if not body then return false end
	local size = body.Size.Y
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.Massless = true
		elseif part:IsA("ProximityPrompt") then
			part:Destroy()
		end
	end
	model:PivotTo(root.CFrame * CFrame.new(0, 2.6 + size / 2, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = body
	weld.Parent = body
	model.Name = "Carried"
	model.Parent = player.Character
	return true
end

-- Give something to carry. Returns true on success.
function CarryService.Give(player, carry)
	if carries[player] then return false end
	local root = Validate.GetRoot(player)
	if not root then return false end
	if not carry.Model then
		if carry.Kind == "Box" then
			carry.Model = PresentModels.MakeBox(carry.Tier)
		else
			carry.Model = PresentModels.MakeUnwrapped(carry.Record)
		end
	end
	if not attachModel(player, carry.Model) then
		carry.Model:Destroy()
		return false
	end
	carry.StartedAt = os.clock()
	carry.StartPos = root.Position
	carries[player] = carry
	CarryService.ApplySpeed(player)
	sendState(player)
	return true
end

-- Silently remove the carry (used by deposit). Returns the carry.
function CarryService.Take(player)
	local carry = carries[player]
	if not carry then return nil end
	carries[player] = nil
	if carry.Model then carry.Model:Destroy() end
	CarryService.ApplySpeed(player)
	sendState(player)
	return carry
end

-- Drop with consequences. reason: "manual" | "hit" | "death" | "left" | "trap" | "ownerLeft"
function CarryService.Drop(player, reason)
	local carry = carries[player]
	if not carry then return nil end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local position = root and root.Position or nil
	CarryService.Take(player)
	if carry.Kind == "Box" then
		-- a bought box falls to the floor so someone can pick it up
		if position then
			Registry.Get("ConveyorService").SpawnFloorBox(carry.Tier, position + Vector3.new(0, 1, 0), 90, nil, { char })
		end
	else
		Registry.Get("StealService").OnDropped(player, carry, reason)
	end
	return carry
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function CarryService.Init()
	Remotes.Get("DropCarry").OnServerEvent:Connect(function(player)
		if not RateLimiter.Check(player, "Default") then return end
		CarryService.Drop(player, "manual")
	end)
	Data().OnBeforeRelease(function(player)
		CarryService.Drop(player, "left")
		speedMods[player] = nil
	end)
end

function CarryService.Start()
	local function hookCharacter(player, char)
		local hum = char:WaitForChild("Humanoid", 5)
		if hum then
			hum.Died:Connect(function()
				if Config.Carry.DropOnDeath then
					CarryService.Drop(player, "death")
				end
			end)
			task.defer(CarryService.ApplySpeed, player)
		end
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char) hookCharacter(player, char) end)
		if player.Character then hookCharacter(player, player.Character) end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(char) hookCharacter(player, char) end)
		if player.Character then hookCharacter(player, player.Character) end
	end
end

return CarryService
