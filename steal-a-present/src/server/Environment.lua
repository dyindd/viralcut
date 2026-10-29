--[[
	Environment.lua  (ServerScriptService.Server.Environment)
	Sky, lighting, atmosphere, post-processing, clouds, snowy terrain mountains, a frozen lake,
	snowfall and an animated aurora. All code, no assets. Lighting.Technology is set to "Future"
	in default.project.json (it isn't scriptable).
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Environment = {}

local function fx(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do inst[k] = v end
	inst.Parent = parent or Lighting
	return inst
end

function Environment.ApplyLighting()
	-- golden-hour winter evening: warm sun low on the horizon, deep blue sky, long shadows
	-- crisp, saturated winter afternoon: clear air, no haze, highlights kept under control
	Lighting.ClockTime = 15.2
	Lighting.Brightness = 1.8
	Lighting.ExposureCompensation = 0
	Lighting.Ambient = Color3.fromRGB(105, 115, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(125, 135, 175)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 240, 220)
	Lighting.ColorShift_Bottom = Color3.fromRGB(150, 170, 220)
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	Lighting.FogStart = 900
	Lighting.FogEnd = 3500
	Lighting.FogColor = Color3.fromRGB(200, 220, 250)

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Atmosphere") or child:IsA("BloomEffect") or child:IsA("ColorCorrectionEffect") or child:IsA("SunRaysEffect") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	fx("Sky", { StarCount = 5000, CelestialBodiesShown = true, SunAngularSize = 14, MoonAngularSize = 12 })
	fx("Atmosphere", { Density = 0.1, Offset = 0.15, Color = Color3.fromRGB(200, 220, 255), Decay = Color3.fromRGB(120, 150, 220), Glare = 0.08, Haze = 0.15 })
	fx("BloomEffect", { Intensity = 0.25, Size = 20, Threshold = 1.15 })
	fx("ColorCorrectionEffect", { Saturation = 0.25, Contrast = 0.1, Brightness = -0.02, TintColor = Color3.fromRGB(255, 252, 248) })
	fx("SunRaysEffect", { Intensity = 0.05, Spread = 0.5 })

	local terrain = Workspace.Terrain
	for _, c in ipairs(terrain:GetChildren()) do if c:IsA("Clouds") then c:Destroy() end end
	fx("Clouds", { Cover = 0.4, Density = 0.25, Color = Color3.fromRGB(255, 245, 250), Enabled = true }, terrain)
end

-- Snowy ground beyond the hub, rolling mountains around the map, a frozen lake
function Environment.BuildTerrain(ringRadius)
	local terrain = Workspace.Terrain
	local ok, err = pcall(function()
		terrain:FillBlock(CFrame.new(0, -12, 0), Vector3.new(2400, 20, 2400), Enum.Material.Snow)
		local rng = Random.new(42)
		local mountainRadius = ringRadius + 230
		for i = 0, 27 do
			local a = i / 28 * math.pi * 2
			local dist = mountainRadius + rng:NextNumber(-40, 60)
			local r = rng:NextNumber(70, 150)
			local pos = Vector3.new(math.cos(a) * dist, -r * 0.35 + rng:NextNumber(0, 30), math.sin(a) * dist)
			terrain:FillBall(pos, r, Enum.Material.Snow)
			if i % 3 == 0 then
				terrain:FillBall(pos + Vector3.new(rng:NextNumber(-60, 60), r * 0.25, rng:NextNumber(-60, 60)), r * 0.55, Enum.Material.Glacier)
			end
		end
		-- a second, farther ring of taller peaks
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2 + 0.2
			local dist = mountainRadius + 260
			local r = rng:NextNumber(150, 260)
			terrain:FillBall(Vector3.new(math.cos(a) * dist, -r * 0.2, math.sin(a) * dist), r, Enum.Material.Snow)
		end
		-- frozen lake just outside the ring
		terrain:FillCylinder(CFrame.new(0, -1, -(ringRadius + 95)), 2, 70, Enum.Material.Ice)
	end)
	if not ok then warn("[Environment] terrain generation failed: " .. tostring(err)) end
end

-- Aurora: three translucent neon ribbons across the sky whose colors drift
function Environment.BuildAurora(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Aurora"
	folder.Parent = parent
	local ribbons = {}
	for r = 1, 3 do
		local segments = 26
		local radius = 420 + r * 70
		local baseY = 150 + r * 45
		local ribbon = {}
		for i = 1, segments do
			local a = math.rad(-70 + (i - 1) * (140 / (segments - 1)) + r * 10)
			local x, z = math.cos(a) * radius, math.sin(a) * radius - 200
			local y = baseY + math.sin(i * 0.7 + r) * 25
			local p = Instance.new("Part")
			p.Name = "Ribbon"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Size = Vector3.new(radius * math.rad(140 / (segments - 1)) * 1.15, 60 + r * 10, 1)
			p.CFrame = CFrame.new(Vector3.new(x, y, z), Vector3.new(0, y, -200)) * CFrame.Angles(0, 0, math.rad(math.sin(i + r) * 8))
			p.Material = Enum.Material.Neon
			p.Transparency = 0.6
			p.Color = Color3.fromRGB(90, 255, 160)
			p.Parent = folder
			table.insert(ribbon, p)
		end
		table.insert(ribbons, ribbon)
	end
	-- slow color drift
	task.spawn(function()
		local green, purple, blue = Color3.fromRGB(90, 255, 170), Color3.fromRGB(190, 110, 255), Color3.fromRGB(80, 170, 255)
		while folder.Parent do
			local t = os.clock()
			for r, ribbon in ipairs(ribbons) do
				for i, p in ipairs(ribbon) do
					local phase = (math.sin(t * 0.35 + i * 0.25 + r) + 1) / 2
					local c = phase < 0.5 and green:Lerp(blue, phase * 2) or blue:Lerp(purple, (phase - 0.5) * 2)
					p.Color = c
					p.Transparency = 0.5 + 0.25 * math.sin(t * 0.6 + i * 0.4)
				end
			end
			task.wait(0.15)
		end
	end)
	return folder
end

function Environment.BuildSnowfall(parent)
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "SnowEmitter"
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(600, 1, 600)
	emitterPart.CFrame = CFrame.new(0, 95, 0)
	emitterPart.Parent = parent
	local em = Instance.new("ParticleEmitter")
	em.Rate = 140
	em.Lifetime = NumberRange.new(11, 15)
	em.Speed = NumberRange.new(6, 9)
	em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0.3) })
	em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.6) })
	em.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	em.EmissionDirection = Enum.NormalId.Bottom
	em.SpreadAngle = Vector2.new(15, 15)
	em.Acceleration = Vector3.new(1.5, 0, 0)
	em.LightEmission = 0.3
	em.Parent = emitterPart
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Rate = 25
	sparkle.Lifetime = NumberRange.new(8, 12)
	sparkle.Speed = NumberRange.new(4, 6)
	sparkle.Size = NumberSequence.new(0.15)
	sparkle.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	sparkle.Color = ColorSequence.new(Color3.fromRGB(200, 230, 255))
	sparkle.EmissionDirection = Enum.NormalId.Bottom
	sparkle.LightEmission = 1
	sparkle.Parent = emitterPart
	return emitterPart
end

return Environment
