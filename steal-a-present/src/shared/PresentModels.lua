--[[
	PresentModels.lua  (ReplicatedStorage.Shared.PresentModels)

	Builds the placeholder models for wrapped boxes and unwrapped presents.

	TO SWAP IN REAL ART: put a Model named exactly like the box tier key (e.g. "Large") in
	ReplicatedStorage.Models.Boxes, or a Model named like the present key (e.g. "TeddyBear")
	in ReplicatedStorage.Models.Presents. It must have a PrimaryPart. Everything else is automatic.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.Catalog)

local PresentModels = {}

local function getCustomModel(folderName, key)
	local models = ReplicatedStorage:FindFirstChild("Models")
	local folder = models and models:FindFirstChild(folderName)
	local model = folder and folder:FindFirstChild(key)
	if model and model:IsA("Model") and model.PrimaryPart then
		return model:Clone()
	end
	return nil
end

local function makePart(name, size, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = true
	p.CanTouch = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function PresentModels.GetTier(tierKey)
	for _, tier in ipairs(Config.BoxTiers) do
		if tier.Key == tierKey then
			return tier
		end
	end
	return Config.BoxTiers[1]
end

-- A wrapped box. Returns a Model whose PrimaryPart is the box body.
function PresentModels.MakeBox(tierKey)
	local tier = PresentModels.GetTier(tierKey)
	local custom = getCustomModel("Boxes", tier.Key)
	if custom then
		custom:SetAttribute("Tier", tier.Key)
		return custom
	end

	local model = Instance.new("Model")
	model.Name = "Box_" .. tier.Key
	local s = tier.Size
	local body = makePart("Body", Vector3.new(s, s, s), tier.Color, Enum.Material.SmoothPlastic, model)
	model.PrimaryPart = body

	-- ribbon (two thin bands crossing the box)
	local ribbonColor = Color3.fromRGB(255, 240, 120)
	local r1 = makePart("Ribbon1", Vector3.new(s * 0.18, s + 0.05, s + 0.05), ribbonColor, Enum.Material.Neon, model)
	r1.CFrame = body.CFrame
	local r2 = makePart("Ribbon2", Vector3.new(s + 0.05, s + 0.05, s * 0.18), ribbonColor, Enum.Material.Neon, model)
	r2.CFrame = body.CFrame
	-- bow
	local bow = makePart("Bow", Vector3.new(s * 0.45, s * 0.3, s * 0.45), ribbonColor, Enum.Material.Neon, model)
	bow.Shape = Enum.PartType.Ball
	bow.CFrame = body.CFrame * CFrame.new(0, s / 2 + s * 0.12, 0)

	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part ~= body then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = part
			weld.Parent = part
		end
	end

	model:SetAttribute("Tier", tier.Key)
	return model
end

-- An unwrapped present sitting on a pedestal. `record` = { Key, Rarity, Mutation, ... }
function PresentModels.MakeUnwrapped(record)
	local info = Catalog.PresentByKey[record.Key]
	local rarity = Catalog.Rarities[record.Rarity] or Catalog.Rarities.Common
	local custom = getCustomModel("Presents", record.Key)
	local model
	if custom then
		model = custom
	else
		model = Instance.new("Model")
		model.Name = "Present_" .. record.Key
		local size = 2 + (rarity.Tier * 0.25)
		local body = makePart("Body", Vector3.new(size, size, size), rarity.Color, Enum.Material.SmoothPlastic, model)
		model.PrimaryPart = body
		-- a little "item" on top so every rarity looks different
		local gem = makePart("Gem", Vector3.new(size * 0.5, size * 0.5, size * 0.5), rarity.Color2, Enum.Material.Neon, model)
		gem.Shape = Enum.PartType.Ball
		gem.CFrame = body.CFrame * CFrame.new(0, size * 0.75, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = gem
		weld.Parent = gem
		if rarity.Tier >= 6 then
			body.Material = Enum.Material.Neon
			local light = Instance.new("PointLight")
			light.Color = rarity.Color
			light.Range = 14
			light.Brightness = 2
			light.Parent = body
		end
	end
	model:SetAttribute("PresentKey", record.Key)
	model:SetAttribute("Rarity", record.Rarity)
	PresentModels.ApplyMutationVisual(model, record.Mutation)
	return model
end

function PresentModels.ApplyMutationVisual(model, mutationKey)
	if not mutationKey or mutationKey == "" then return end
	local mutation = Catalog.Mutations[mutationKey]
	if not mutation then return end
	local body = model.PrimaryPart
	if not body then return end
	body.Color = mutation.Color
	if mutationKey == "Rainbow" or mutationKey == "Galaxy" then
		body.Material = Enum.Material.Neon
	elseif mutationKey == "Golden" then
		body.Material = Enum.Material.Metal
		body.Reflectance = 0.4
	elseif mutationKey == "Frosted" then
		body.Material = Enum.Material.Ice
	elseif mutationKey == "Cursed" then
		body.Material = Enum.Material.CrackedLava
	end
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = mutation.Color
	sparkles.Parent = body
end

-- Removes a model safely
function PresentModels.Destroy(model)
	if model and model.Parent then
		model:Destroy()
	end
end

return PresentModels
