--[[
	EffectsController.lua - world effects the server asks for via PlayEffect(name, position, extra):
	particle bursts at positions, screen shakes, sounds. Purely cosmetic.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundController = require(script.Parent.SoundController)

local EffectsController = {}

local function burst(position, color, count, size, speed, lifetime)
	if not position then return end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.Position = position
	part.Parent = workspace
	local em = Instance.new("ParticleEmitter")
	em.Color = ColorSequence.new(color)
	em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 0.8), NumberSequenceKeypoint.new(1, 0) })
	em.Lifetime = NumberRange.new((lifetime or 1) * 0.6, lifetime or 1)
	em.Speed = NumberRange.new((speed or 20) * 0.5, speed or 20)
	em.SpreadAngle = Vector2.new(180, 180)
	em.Rate = 0
	em.LightEmission = 0.7
	em.Parent = part
	em:Emit(count or 40)
	Debris:AddItem(part, (lifetime or 1) + 0.5)
end

local function shake(intensity, duration)
	local cam = workspace.CurrentCamera
	if not cam then return end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < duration do
			local a = 1 - (os.clock() - t0) / duration
			cam.CFrame = cam.CFrame * CFrame.new(math.random(-100, 100) / 100 * intensity * a, math.random(-100, 100) / 100 * intensity * a, 0)
			task.wait()
		end
	end)
end

local handlers = {}

handlers.Unwrap = function(position, extra)
	local r = Catalog.Rarities[extra and extra.Rarity or "Common"] or Catalog.Rarities.Common
	burst(position, r.Color, 30 + r.Tier * 10, 0.6 + r.Tier * 0.15, 20 + r.Tier * 5, 1.2)
	if r.Tier >= 6 then
		burst(position, Color3.fromRGB(255, 255, 255), 60, 1.2, 40, 2)
		shake(0.6, 0.5)
		SoundController.PlayAt("Legendary", position, 1)
	elseif r.Tier >= 4 then
		SoundController.PlayAt("Rare", position, 0.8)
	else
		SoundController.PlayAt("Unwrap", position, 0.7)
	end
	if extra and extra.Mutation then
		local m = Catalog.Mutations[extra.Mutation]
		if m then burst(position + Vector3.new(0, 2, 0), m.Color, 40, 0.5, 25, 1.5) end
	end
end
handlers.Coal = function(position)
	burst(position, Color3.fromRGB(40, 40, 40), 50, 1.2, 15, 1.5)
	shake(0.5, 0.4)
	SoundController.PlayAt("Hit", position, 1)
end
handlers.Cash = function(position, extra)
	burst(position, Color3.fromRGB(120, 230, 110), 30, 0.5, 18, 1)
	SoundController.PlayAt("Cash", position, 0.8)
end
handlers.Hit = function(position)
	burst(position, Color3.fromRGB(255, 220, 80), 20, 0.6, 25, 0.6)
	SoundController.PlayAt("Hit", position, 0.9)
end
handlers.Swing = function(position) SoundController.PlayAt("Whoosh", position, 0.5) end
handlers.Splat = function(position) burst(position, Color3.fromRGB(240, 248, 255), 25, 0.5, 15, 0.8) end
handlers.StealStart = function(position, extra) burst(position, Color3.fromRGB(255, 80, 80), 25, 0.6, 20, 1) SoundController.PlayAt("Pop", position, 0.8) end
handlers.Steal = function(position, extra) burst(position, Color3.fromRGB(255, 150, 60), 35, 0.7, 20, 1) SoundController.PlayAt("Cash", position, 0.8) end
handlers.Gift = function(position) burst(position, Color3.fromRGB(255, 120, 200), 40, 0.7, 22, 1.2) SoundController.PlayAt("Rare", position, 0.8) end
handlers.Trap = function(position, extra) burst(position, Color3.fromRGB(170, 230, 255), 25, 0.6, 15, 0.8) SoundController.PlayAt("Pop", position, 0.6) end
handlers.Train = function(position, extra)
	burst(position + Vector3.new(0, 3, 0), Color3.fromRGB(255, 160, 70), 6, 0.4, 8, 0.6)
	-- "+1 💪" pops over the bench
	local part = Instance.new("Part")
	part.Anchored = true part.CanCollide = false part.Transparency = 1 part.Size = Vector3.new(1, 1, 1)
	part.Position = position + Vector3.new(math.random(-2, 2), 4, math.random(-2, 2))
	part.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 80, 0, 30) bb.AlwaysOnTop = true bb.Parent = part
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1 tl.Size = UDim2.new(1, 0, 1, 0) tl.Font = Enum.Font.FredokaOne tl.TextScaled = true
	tl.Text = "+💪" tl.TextColor3 = Color3.fromRGB(255, 170, 70) tl.TextStrokeTransparency = 0 tl.Parent = bb
	task.spawn(function()
		for i = 1, 12 do part.Position = part.Position + Vector3.new(0, 0.25, 0) task.wait(0.05) end
		part:Destroy()
	end)
end
handlers.Rebirth = function(position) burst(position, Color3.fromRGB(190, 110, 255), 100, 1.2, 40, 2) shake(0.8, 0.6) SoundController.PlayAt("Legendary", position, 1) end
handlers.Reward = function() SoundController.Play("Cash", 0.8) end
handlers.GrinchHit = function() SoundController.Play("Hit", 0.8, 1.2) end
handlers.SleighDrop = function(position) burst(position + Vector3.new(0, 30, 0), Color3.fromRGB(255, 80, 80), 20, 0.8, 10, 1.5) end

-- Presents at bases bob and spin (client-side only; the server owns their real position)
local function animatePresents()
	local plots = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Plots")
	if not plots then return end
	local t = os.clock()
	local i = 0
	for _, plot in ipairs(plots:GetChildren()) do
		local presents = plot:FindFirstChild("Presents")
		if presents then
			for _, model in ipairs(presents:GetChildren()) do
				i = i + 1
				local base = model:GetAttribute("BaseCFrame")
				local pp = model.PrimaryPart
				if base and pp then
					local target = base * CFrame.new(0, 0.35 + 0.3 * math.sin(t * 2 + i), 0) * CFrame.Angles(0, t * 0.9 + i, 0)
					local delta = target * pp.CFrame:Inverse()
					for _, part in ipairs(model:GetChildren()) do
						if part:IsA("BasePart") and part.Name ~= "Ring" and part.Name ~= "Pillar" then
							part.CFrame = delta * part.CFrame
						end
					end
					pp.CFrame = target
				end
			end
		end
	end
end

-- Sweat + "💪" over anyone who is training (server sets the Training attribute on the character)
local trainingFx = {}
local function updateTrainingEffects()
	for _, other in ipairs(game:GetService("Players"):GetPlayers()) do
		local char = other.Character
		local active = char and char:GetAttribute("Training") == true
		local fx = trainingFx[other]
		if active and not fx then
			local head = char:FindFirstChild("Head") or char.PrimaryPart
			if head then
				local em = Instance.new("ParticleEmitter")
				em.Name = "SweatFx"
				em.Rate = 6
				em.Lifetime = NumberRange.new(0.6, 1)
				em.Speed = NumberRange.new(3, 5)
				em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
				em.Color = ColorSequence.new(Color3.fromRGB(150, 210, 255))
				em.SpreadAngle = Vector2.new(60, 60)
				em.Parent = head
				local bb = Instance.new("BillboardGui")
				bb.Name = "TrainFx"
				bb.Size = UDim2.new(0, 120, 0, 40)
				bb.StudsOffset = Vector3.new(0, 3.2, 0)
				bb.AlwaysOnTop = true
				bb.Parent = head
				local tl = Instance.new("TextLabel")
				tl.BackgroundTransparency = 1
				tl.Size = UDim2.new(1, 0, 1, 0)
				tl.Font = Enum.Font.FredokaOne
				tl.TextScaled = true
				tl.Text = "💪 TRAINING"
				tl.TextColor3 = Color3.fromRGB(255, 170, 70)
				tl.TextStrokeTransparency = 0
				tl.Parent = bb
				trainingFx[other] = { Emitter = em, Gui = bb }
			end
		elseif not active and fx then
			if fx.Emitter then fx.Emitter:Destroy() end
			if fx.Gui then fx.Gui:Destroy() end
			trainingFx[other] = nil
		end
	end
end

function EffectsController.Start()
	task.spawn(function()
		while true do
			task.wait(0.05)
			pcall(animatePresents)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			pcall(updateTrainingEffects)
		end
	end)
	Remotes.Get("PlayEffect").OnClientEvent:Connect(function(name, position, extra)
		local fn = handlers[name]
		if fn then
			local ok, err = pcall(fn, position, extra)
			if not ok then warn("[Effects] " .. tostring(err)) end
		end
	end)
end

return EffectsController
