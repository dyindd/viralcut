--[[
	Decor.lua  (ServerScriptService.Server.Decor)
	A library of procedural Christmas models built from plain Parts: decorated trees, snowmen,
	lamp posts, candy canes, gingerbread houses, present piles, igloos, picket fences, padlocks,
	mailboxes, wreaths, string lights and the training barbell. No assets needed; replace any
	of these with real meshes later by editing one function.
]]

local Decor = {}
local rng = Random.new(1337)

Decor.Colors = {
	Red = Color3.fromRGB(230, 50, 60), Green = Color3.fromRGB(40, 150, 70), DarkGreen = Color3.fromRGB(25, 105, 55),
	Gold = Color3.fromRGB(255, 205, 60), White = Color3.fromRGB(250, 250, 255), Snow = Color3.fromRGB(240, 246, 255),
	Blue = Color3.fromRGB(90, 160, 255), Pink = Color3.fromRGB(255, 120, 190), Brown = Color3.fromRGB(150, 95, 55),
	Gingerbread = Color3.fromRGB(176, 112, 60), Icing = Color3.fromRGB(255, 252, 245), Candy = Color3.fromRGB(255, 60, 70),
	Wood = Color3.fromRGB(110, 70, 40), Stone = Color3.fromRGB(150, 155, 170), Warm = Color3.fromRGB(255, 190, 110),
}
local ORNAMENTS = { Decor.Colors.Red, Decor.Colors.Gold, Decor.Colors.Blue, Decor.Colors.Pink, Color3.fromRGB(120, 230, 255) }
local LIGHTS = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(80, 255, 120), Color3.fromRGB(80, 160, 255), Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 120, 255) }

---------------------------------------------------------------------------
-- part helpers
---------------------------------------------------------------------------
function Decor.Part(props)
	local className = "Part"
	if props.Shape == "Wedge" then className = "WedgePart" elseif props.Shape == "CornerWedge" then className = "CornerWedgePart" end
	local p = Instance.new(className)
	p.Anchored = true
	p.CanCollide = props.CanCollide ~= false
	p.CanQuery = props.CanQuery ~= false
	p.CanTouch = props.CanTouch ~= false
	p.CastShadow = props.CastShadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.Name or "Part"
	p.Size = props.Size or Vector3.new(1, 1, 1)
	p.CFrame = props.CFrame or CFrame.new()
	p.Color = props.Color or Decor.Colors.White
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	if props.Shape == "Ball" then p.Shape = Enum.PartType.Ball elseif props.Shape == "Cylinder" then p.Shape = Enum.PartType.Cylinder end
	if props.Reflectance then p.Reflectance = props.Reflectance end
	p.Parent = props.Parent
	return p
end
local part = Decor.Part

-- a vertical cylinder (Roblox cylinders lie along X, so we rotate)
local function pillar(parent, cf, radius, height, color, material, name)
	return part({ Name = name or "Pillar", Shape = "Cylinder", Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = material, Parent = parent })
end

local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 14
	l.Brightness = brightness or 1.2
	l.Shadows = false
	l.Parent = parent
	return l
end

local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

---------------------------------------------------------------------------
-- Christmas tree: trunk, star-shaped foliage layers, snow caps, ornaments, string lights, star
---------------------------------------------------------------------------
function Decor.Tree(parent, cf, scale, opts)
	opts = opts or {}
	local s = scale or 1
	local m = model("Tree", parent)
	local layers = opts.Layers or 5
	local base = 14 * s
	local trunk = pillar(m, cf * CFrame.new(0, 2.5 * s, 0), 1.1 * s, 5 * s, Decor.Colors.Wood, Enum.Material.Wood, "Trunk")
	m.PrimaryPart = trunk
	local lightCount = 0
	for i = 1, layers do
		local size = base - (i - 1) * (base / (layers + 0.5))
		local h = 3.4 * s
		local y = 4 * s + (i - 1) * (h * 0.85)
		local green = Decor.Colors.DarkGreen:Lerp(Decor.Colors.Green, (i - 1) / math.max(1, layers - 1))
		for _, rot in ipairs({ 0, 45 }) do
			part({ Name = "Foliage", Size = Vector3.new(size, h, size), CFrame = cf * CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(rot), 0),
				Color = green, Material = Enum.Material.Grass, CanCollide = false, Parent = m })
		end
		if opts.Snow ~= false then
			part({ Name = "SnowCap", Size = Vector3.new(size * 0.8, 0.5 * s, size * 0.8), CFrame = cf * CFrame.new(0, y + h / 2 + 0.2 * s, 0) * CFrame.Angles(0, math.rad(22), 0),
				Color = Decor.Colors.Snow, Material = Enum.Material.Snow, CanCollide = false, Parent = m })
		end
		if opts.Decorated ~= false then
			local count = 5 + i
			for k = 1, count do
				local a = (k / count) * math.pi * 2 + i
				local r = size / 2 * 0.98
				local pos = Vector3.new(math.cos(a) * r, y - h * 0.2 + rng:NextNumber(-0.4, 0.4) * s, math.sin(a) * r)
				if k % 2 == 0 then
					part({ Name = "Ornament", Shape = "Ball", Size = Vector3.new(0.8 * s, 0.8 * s, 0.8 * s), CFrame = cf * CFrame.new(pos),
						Color = ORNAMENTS[rng:NextInteger(1, #ORNAMENTS)], Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = m })
				else
					local bulb = part({ Name = "Bulb", Shape = "Ball", Size = Vector3.new(0.45 * s, 0.45 * s, 0.45 * s), CFrame = cf * CFrame.new(pos),
						Color = LIGHTS[(k + i) % #LIGHTS + 1], Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false, Parent = m })
					lightCount = lightCount + 1
				end
			end
		end
	end
	local topY = 4 * s + (layers - 1) * (3.4 * s * 0.85) + 2.2 * s
	if opts.Star ~= false then
		local star = part({ Name = "Star", Size = Vector3.new(2.2 * s, 2.2 * s, 0.6 * s), CFrame = cf * CFrame.new(0, topY, 0) * CFrame.Angles(0, 0, math.rad(45)),
			Color = Decor.Colors.Gold, Material = Enum.Material.Neon, CanCollide = false, Parent = m })
		part({ Name = "Star2", Size = Vector3.new(2.2 * s, 2.2 * s, 0.6 * s), CFrame = cf * CFrame.new(0, topY, 0), Color = Decor.Colors.Gold, Material = Enum.Material.Neon, CanCollide = false, Parent = m })
		light(star, Decor.Colors.Gold, 16 * s, 1.5)
	end
	if opts.Decorated ~= false then
		light(trunk, Decor.Colors.Warm, 18 * s, 0.8)
	end
	m:SetAttribute("Scale", s)
	return m
end

---------------------------------------------------------------------------
-- Snowman
---------------------------------------------------------------------------
function Decor.Snowman(parent, cf, scale)
	local s = scale or 1
	local m = model("Snowman", parent)
	local bottom = part({ Name = "Bottom", Shape = "Ball", Size = Vector3.new(4.2 * s, 4.2 * s, 4.2 * s), CFrame = cf * CFrame.new(0, 2 * s, 0), Color = Decor.Colors.Snow, Material = Enum.Material.Snow, Parent = m })
	m.PrimaryPart = bottom
	part({ Name = "Middle", Shape = "Ball", Size = Vector3.new(3.2 * s, 3.2 * s, 3.2 * s), CFrame = cf * CFrame.new(0, 5 * s, 0), Color = Decor.Colors.Snow, Material = Enum.Material.Snow, Parent = m })
	local head = part({ Name = "Head", Shape = "Ball", Size = Vector3.new(2.4 * s, 2.4 * s, 2.4 * s), CFrame = cf * CFrame.new(0, 7.4 * s, 0), Color = Decor.Colors.Snow, Material = Enum.Material.Snow, Parent = m })
	for _, x in ipairs({ -0.4, 0.4 }) do
		part({ Name = "Eye", Shape = "Ball", Size = Vector3.new(0.35 * s, 0.35 * s, 0.35 * s), CFrame = cf * CFrame.new(x * s, 7.7 * s, -1.05 * s), Color = Color3.fromRGB(20, 20, 20), CanCollide = false, Parent = m })
	end
	part({ Name = "Nose", Shape = "Cylinder", Size = Vector3.new(1.4 * s, 0.4 * s, 0.4 * s), CFrame = cf * CFrame.new(0, 7.4 * s, -1.6 * s) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 140, 40), CanCollide = false, Parent = m })
	for i = 1, 3 do
		part({ Name = "Button", Shape = "Ball", Size = Vector3.new(0.35 * s, 0.35 * s, 0.35 * s), CFrame = cf * CFrame.new(0, (4.3 + i * 0.55) * s, -1.5 * s), Color = Color3.fromRGB(20, 20, 20), CanCollide = false, Parent = m })
	end
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Arm", Shape = "Cylinder", Size = Vector3.new(3 * s, 0.25 * s, 0.25 * s), CFrame = cf * CFrame.new(side * 2.6 * s, 5.6 * s, 0) * CFrame.Angles(0, 0, math.rad(side * 30)), Color = Decor.Colors.Wood, CanCollide = false, Parent = m })
	end
	part({ Name = "Scarf", Size = Vector3.new(2.3 * s, 0.5 * s, 2.3 * s), CFrame = cf * CFrame.new(0, 6.3 * s, 0), Color = Decor.Colors.Red, Material = Enum.Material.Fabric, CanCollide = false, Parent = m })
	part({ Name = "HatBrim", Shape = "Cylinder", Size = Vector3.new(0.2 * s, 2.6 * s, 2.6 * s), CFrame = cf * CFrame.new(0, 8.45 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(30, 30, 35), CanCollide = false, Parent = m })
	part({ Name = "Hat", Shape = "Cylinder", Size = Vector3.new(1.6 * s, 1.8 * s, 1.8 * s), CFrame = cf * CFrame.new(0, 9.3 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(30, 30, 35), CanCollide = false, Parent = m })
	part({ Name = "HatBand", Shape = "Cylinder", Size = Vector3.new(0.35 * s, 1.85 * s, 1.85 * s), CFrame = cf * CFrame.new(0, 8.75 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Decor.Colors.Red, CanCollide = false, Parent = m })
	return m
end

---------------------------------------------------------------------------
-- Lamp post with a warm lantern and a wreath
---------------------------------------------------------------------------
function Decor.LampPost(parent, cf)
	local m = model("LampPost", parent)
	local pole = pillar(m, cf * CFrame.new(0, 5, 0), 0.35, 10, Color3.fromRGB(35, 35, 45), Enum.Material.Metal, "Pole")
	m.PrimaryPart = pole
	part({ Name = "Base", Shape = "Cylinder", Size = Vector3.new(0.6, 1.8, 1.8), CFrame = cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(35, 35, 45), Material = Enum.Material.Metal, Parent = m })
	local lantern = part({ Name = "Lantern", Size = Vector3.new(1.6, 2, 1.6), CFrame = cf * CFrame.new(0, 10.6, 0), Color = Decor.Colors.Warm, Material = Enum.Material.Neon, CanCollide = false, Parent = m })
	part({ Name = "Cap", Size = Vector3.new(2, 0.5, 2), CFrame = cf * CFrame.new(0, 11.8, 0), Color = Color3.fromRGB(35, 35, 45), CanCollide = false, Parent = m })
	light(lantern, Decor.Colors.Warm, 24, 1.6)
	Decor.Wreath(m, cf * CFrame.new(0, 7.5, -0.5), 1.2)
	return m
end

function Decor.Wreath(parent, cf, radius)
	local r = radius or 1.5
	local ring = part({ Name = "Wreath", Shape = "Cylinder", Size = Vector3.new(0.5, r * 2, r * 2), CFrame = cf * CFrame.Angles(0, math.rad(90), 0), Color = Decor.Colors.DarkGreen, Material = Enum.Material.Grass, CanCollide = false, Parent = parent })
	part({ Name = "WreathHole", Shape = "Cylinder", Size = Vector3.new(0.6, r * 0.9, r * 0.9), CFrame = cf * CFrame.Angles(0, math.rad(90), 0), Color = Decor.Colors.Snow, Material = Enum.Material.SmoothPlastic, Transparency = 1, CanCollide = false, Parent = parent })
	part({ Name = "Bow", Size = Vector3.new(r * 0.8, r * 0.5, 0.4), CFrame = cf * CFrame.new(0, -r * 0.8, 0), Color = Decor.Colors.Red, CanCollide = false, Parent = parent })
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		part({ Name = "Berry", Shape = "Ball", Size = Vector3.new(0.3, 0.3, 0.3), CFrame = cf * CFrame.new(math.cos(a) * r * 0.75, math.sin(a) * r * 0.75, -0.2), Color = k % 2 == 0 and Decor.Colors.Red or Decor.Colors.Gold, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
	end
	return ring
end

---------------------------------------------------------------------------
-- Candy cane: striped pole with a hook
---------------------------------------------------------------------------
function Decor.CandyCane(parent, cf, height, radius)
	local h = height or 10
	local r = radius or 0.5
	local m = model("CandyCane", parent)
	local segments = math.floor(h / 1.25)
	local first
	for i = 1, segments do
		local seg = pillar(m, cf * CFrame.new(0, (i - 0.5) * (h / segments), 0), r, h / segments + 0.02, (i % 2 == 0) and Decor.Colors.Candy or Decor.Colors.White, Enum.Material.SmoothPlastic, "Stripe")
		first = first or seg
	end
	m.PrimaryPart = first
	-- hook: three short angled pieces
	for i = 1, 3 do
		local a = math.rad(i * 45)
		part({ Name = "Hook", Shape = "Cylinder", Size = Vector3.new(r * 2.6, r * 2, r * 2), CFrame = cf * CFrame.new(math.sin(a) * r * 2.6 * 1.1, h + math.cos(a) * r * 2.6 * 0.9 - r, 0) * CFrame.Angles(0, 0, -a + math.rad(90)),
			Color = (i % 2 == 0) and Decor.Colors.Candy or Decor.Colors.White, CanCollide = false, Parent = m })
	end
	return m
end

---------------------------------------------------------------------------
-- Gingerbread house. Returns the model; model.FrontWall faces -Z of `cf` (toward the viewer)
---------------------------------------------------------------------------
function Decor.GingerbreadHouse(parent, cf, w, d, h, roofColor, opts)
	opts = opts or {}
	local m = model(opts.Name or "GingerbreadHouse", parent)
	local walls = part({ Name = "Walls", Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, h / 2, 0), Color = Decor.Colors.Gingerbread, Material = Enum.Material.SmoothPlastic, Parent = m })
	m.PrimaryPart = walls
	local front = part({ Name = "FrontWall", Size = Vector3.new(w - 0.2, h - 0.2, 0.3), CFrame = cf * CFrame.new(0, h / 2, -d / 2 - 0.1), Color = Decor.Colors.Gingerbread, Parent = m })
	-- roof: two wedges meeting at the ridge
	local roofH = h * 0.55
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Roof", Shape = "Wedge", Size = Vector3.new(w + 1.5, roofH, d / 2 + 0.75), CFrame = cf * CFrame.new(0, h + roofH / 2, side * (d / 4 + 0.35)) * CFrame.Angles(0, side > 0 and 0 or math.rad(180), 0),
			Color = roofColor or Decor.Colors.Red, Material = Enum.Material.SmoothPlastic, Parent = m })
		-- icing trim + snow on the roof edge
		part({ Name = "Icing", Size = Vector3.new(w + 1.8, 0.5, 0.9), CFrame = cf * CFrame.new(0, h + 0.2, side * (d / 2 + 0.6)), Color = Decor.Colors.Icing, CanCollide = false, Parent = m })
	end
	part({ Name = "Ridge", Size = Vector3.new(w + 1.8, 0.6, 1.2), CFrame = cf * CFrame.new(0, h + roofH, 0), Color = Decor.Colors.Snow, Material = Enum.Material.Snow, CanCollide = false, Parent = m })
	-- door + windows (glowing)
	part({ Name = "Door", Size = Vector3.new(3, 4.5, 0.3), CFrame = cf * CFrame.new(opts.DoorX or 0, 2.25, -d / 2 - 0.3), Color = Decor.Colors.Wood, Material = Enum.Material.Wood, CanCollide = false, Parent = m })
	Decor.Wreath(m, cf * CFrame.new(opts.DoorX or 0, 3.6, -d / 2 - 0.55), 0.9)
	for _, x in ipairs({ -w / 3.2, w / 3.2 }) do
		local win = part({ Name = "Window", Size = Vector3.new(2.4, 2.4, 0.25), CFrame = cf * CFrame.new(x, h * 0.6, -d / 2 - 0.3), Color = Decor.Colors.Warm, Material = Enum.Material.Neon, CanCollide = false, Parent = m })
		part({ Name = "Frame", Size = Vector3.new(2.9, 2.9, 0.2), CFrame = cf * CFrame.new(x, h * 0.6, -d / 2 - 0.2), Color = Decor.Colors.Icing, CanCollide = false, Parent = m })
		light(win, Decor.Colors.Warm, 14, 1)
	end
	-- candy buttons along the front
	for i = 1, 5 do
		part({ Name = "Gumdrop", Shape = "Ball", Size = Vector3.new(0.8, 0.8, 0.8), CFrame = cf * CFrame.new(-w / 2 + i * (w / 6), h - 1, -d / 2 - 0.4), Color = ORNAMENTS[(i % #ORNAMENTS) + 1], Material = Enum.Material.Neon, CanCollide = false, Parent = m })
	end
	-- chimney with smoke
	local chimney = part({ Name = "Chimney", Size = Vector3.new(2, roofH + 2, 2), CFrame = cf * CFrame.new(w / 3, h + roofH / 2 + 1, d / 6), Color = Color3.fromRGB(120, 60, 50), Material = Enum.Material.Brick, CanCollide = false, Parent = m })
	local smoke = Instance.new("Smoke")
	smoke.Size = 1.5
	smoke.Opacity = 0.25
	smoke.RiseVelocity = 3
	smoke.Color = Color3.fromRGB(235, 235, 245)
	smoke.Parent = chimney
	return m
end

---------------------------------------------------------------------------
-- Present pile (decorative wrapped boxes)
---------------------------------------------------------------------------
function Decor.PresentPile(parent, cf, count)
	local m = model("PresentPile", parent)
	local n = count or 5
	local first
	for i = 1, n do
		local s = rng:NextNumber(1.6, 3)
		local pos = Vector3.new(rng:NextNumber(-2.5, 2.5), s / 2, rng:NextNumber(-2.5, 2.5))
		local box = part({ Name = "Gift", Size = Vector3.new(s, s, s), CFrame = cf * CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = ORNAMENTS[rng:NextInteger(1, #ORNAMENTS)], CanCollide = false, Parent = m })
		first = first or box
		part({ Name = "Ribbon", Size = Vector3.new(s * 0.2, s + 0.04, s + 0.04), CFrame = box.CFrame, Color = Decor.Colors.Gold, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = m })
		part({ Name = "Ribbon", Size = Vector3.new(s + 0.04, s + 0.04, s * 0.2), CFrame = box.CFrame, Color = Decor.Colors.Gold, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = m })
	end
	m.PrimaryPart = first
	return m
end

---------------------------------------------------------------------------
-- Igloo
---------------------------------------------------------------------------
function Decor.Igloo(parent, cf, radius)
	local r = radius or 6
	local m = model("Igloo", parent)
	local dome = part({ Name = "Dome", Shape = "Ball", Size = Vector3.new(r * 2, r * 2, r * 2), CFrame = cf * CFrame.new(0, r * 0.45, 0), Color = Decor.Colors.Snow, Material = Enum.Material.Snow, Parent = m })
	m.PrimaryPart = dome
	part({ Name = "Entrance", Shape = "Cylinder", Size = Vector3.new(r * 0.9, r * 0.8, r * 0.8), CFrame = cf * CFrame.new(0, r * 0.3, -r * 0.9) * CFrame.Angles(0, math.rad(90), 0), Color = Decor.Colors.Snow, Material = Enum.Material.Snow, Parent = m })
	part({ Name = "Hole", Shape = "Cylinder", Size = Vector3.new(r * 0.95, r * 0.5, r * 0.5), CFrame = cf * CFrame.new(0, r * 0.3, -r * 0.95) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(40, 50, 80), CanCollide = false, Parent = m })
	return m
end

---------------------------------------------------------------------------
-- Picket fence along local X from -length/2 to +length/2, optional gap in the middle
---------------------------------------------------------------------------
function Decor.Fence(parent, cf, length, gapWidth, color)
	local m = model("Fence", parent)
	local step = 2.2
	local posts = math.floor(length / step)
	local first
	for i = 0, posts do
		local x = -length / 2 + i * step
		if not gapWidth or math.abs(x) > gapWidth / 2 then
			local post = part({ Name = "Post", Size = Vector3.new(0.5, 3.2, 0.5), CFrame = cf * CFrame.new(x, 1.6, 0), Color = color or Decor.Colors.White, Parent = m })
			part({ Name = "Tip", Shape = "Wedge", Size = Vector3.new(0.5, 0.5, 0.5), CFrame = cf * CFrame.new(x, 3.45, 0), Color = color or Decor.Colors.White, CanCollide = false, Parent = m })
			first = first or post
		end
	end
	for _, y in ipairs({ 1.0, 2.4 }) do
		if gapWidth then
			local railLen = (length - gapWidth) / 2
			for _, side in ipairs({ -1, 1 }) do
				part({ Name = "Rail", Size = Vector3.new(railLen, 0.35, 0.3), CFrame = cf * CFrame.new(side * (gapWidth / 2 + railLen / 2), y, 0), Color = color or Decor.Colors.White, Parent = m })
			end
		else
			part({ Name = "Rail", Size = Vector3.new(length, 0.35, 0.3), CFrame = cf * CFrame.new(0, y, 0), Color = color or Decor.Colors.White, Parent = m })
		end
	end
	-- string lights along the top rail
	local bulbs = math.floor(length / 1.6)
	for i = 0, bulbs do
		local x = -length / 2 + i * 1.6
		if not gapWidth or math.abs(x) > gapWidth / 2 then
			part({ Name = "Bulb", Shape = "Ball", Size = Vector3.new(0.4, 0.4, 0.4), CFrame = cf * CFrame.new(x, 2.75, 0), Color = LIGHTS[i % #LIGHTS + 1], Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false, Parent = m })
		end
	end
	m.PrimaryPart = first
	return m
end

---------------------------------------------------------------------------
-- Padlock (gold) with a status lamp named "LockLamp"
---------------------------------------------------------------------------
function Decor.Padlock(parent, cf, scale)
	local s = scale or 1
	local m = model("Padlock", parent)
	local body = part({ Name = "Body", Size = Vector3.new(2.4 * s, 2 * s, 1 * s), CFrame = cf * CFrame.new(0, 1 * s, 0), Color = Decor.Colors.Gold, Material = Enum.Material.Metal, Reflectance = 0.3, CanCollide = false, Parent = m })
	m.PrimaryPart = body
	part({ Name = "Shackle", Shape = "Cylinder", Size = Vector3.new(0.45 * s, 1.9 * s, 1.9 * s), CFrame = cf * CFrame.new(0, 2.5 * s, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal, CanCollide = false, Parent = m })
	part({ Name = "ShackleGap", Shape = "Cylinder", Size = Vector3.new(0.5 * s, 1.1 * s, 1.1 * s), CFrame = cf * CFrame.new(0, 2.5 * s, 0) * CFrame.Angles(0, math.rad(90), 0), Color = Decor.Colors.Snow, Transparency = 1, CanCollide = false, Parent = m })
	local lamp = part({ Name = "LockLamp", Shape = "Ball", Size = Vector3.new(0.7 * s, 0.7 * s, 0.7 * s), CFrame = cf * CFrame.new(0, 1 * s, -0.6 * s), Color = Color3.fromRGB(255, 80, 80), Material = Enum.Material.Neon, CanCollide = false, Parent = m })
	light(lamp, Color3.fromRGB(255, 80, 80), 8, 1)
	return m
end

---------------------------------------------------------------------------
-- Mailbox (reward delivery spot)
---------------------------------------------------------------------------
function Decor.Mailbox(parent, cf, color)
	local m = model("Mailbox", parent)
	local post = part({ Name = "Post", Size = Vector3.new(0.5, 3, 0.5), CFrame = cf * CFrame.new(0, 1.5, 0), Color = Decor.Colors.Wood, Material = Enum.Material.Wood, Parent = m })
	m.PrimaryPart = post
	part({ Name = "Box", Size = Vector3.new(2.2, 1.6, 1.4), CFrame = cf * CFrame.new(0, 3.6, 0), Color = color or Decor.Colors.Red, Parent = m })
	part({ Name = "BoxTop", Shape = "Cylinder", Size = Vector3.new(2.2, 1.4, 1.4), CFrame = cf * CFrame.new(0, 4.4, 0), Color = color or Decor.Colors.Red, CanCollide = false, Parent = m })
	part({ Name = "Flag", Size = Vector3.new(0.15, 1.2, 0.6), CFrame = cf * CFrame.new(1.2, 4.2, 0), Color = Decor.Colors.Gold, Material = Enum.Material.Neon, CanCollide = false, Parent = m })
	return m
end

---------------------------------------------------------------------------
-- Gym set: rubber mat, weight rack, punching bag (the bench itself is functional and stays)
---------------------------------------------------------------------------
function Decor.GymSet(parent, cf)
	local m = model("GymSet", parent)
	local mat = part({ Name = "Mat", Size = Vector3.new(12, 0.3, 12), CFrame = cf * CFrame.new(0, 0.15, 0), Color = Color3.fromRGB(45, 45, 60), Material = Enum.Material.Rubber, Parent = m })
	m.PrimaryPart = mat
	-- rack with plates
	part({ Name = "Rack", Size = Vector3.new(6, 0.4, 1), CFrame = cf * CFrame.new(0, 2.5, 5), Color = Color3.fromRGB(60, 65, 80), Material = Enum.Material.Metal, CanCollide = false, Parent = m })
	for i = 1, 4 do
		part({ Name = "Plate", Shape = "Cylinder", Size = Vector3.new(0.5, 1.6 + i * 0.3, 1.6 + i * 0.3), CFrame = cf * CFrame.new(-2.5 + i * 1.1, 1.2 + i * 0.15, 5) * CFrame.Angles(0, math.rad(90), 0), Color = i % 2 == 0 and Decor.Colors.Red or Color3.fromRGB(30, 30, 35), Material = Enum.Material.Metal, CanCollide = false, Parent = m })
	end
	-- punching bag
	part({ Name = "BagChain", Size = Vector3.new(0.2, 3, 0.2), CFrame = cf * CFrame.new(-4.5, 7, -3), Color = Color3.fromRGB(120, 120, 130), Material = Enum.Material.Metal, CanCollide = false, Parent = m })
	pillar(m, cf * CFrame.new(-4.5, 3.8, -3), 1.1, 3.6, Decor.Colors.Red, Enum.Material.Fabric, "Bag")
	part({ Name = "BagArm", Size = Vector3.new(0.3, 8.6, 0.3), CFrame = cf * CFrame.new(-5.5, 4.3, -3), Color = Color3.fromRGB(60, 65, 80), Material = Enum.Material.Metal, Parent = m })
	part({ Name = "BagTop", Size = Vector3.new(1.4, 0.3, 0.3), CFrame = cf * CFrame.new(-5, 8.6, -3), Color = Color3.fromRGB(60, 65, 80), Material = Enum.Material.Metal, CanCollide = false, Parent = m })
	return m
end

---------------------------------------------------------------------------
-- Training barbell TOOL: the default tool-holding pose raises the arm; we pump the Grip up/down.
---------------------------------------------------------------------------
function Decor.Barbell()
	local tool = Instance.new("Tool")
	tool.Name = "Barbell"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true
	tool.ToolTip = "Training..."
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(6, 0.35, 0.35)
	handle.Color = Color3.fromRGB(70, 70, 80)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	for _, x in ipairs({ -2.6, 2.6 }) do
		local plate = Instance.new("Part")
		plate.Name = "Plate"
		plate.Shape = Enum.PartType.Cylinder
		plate.Size = Vector3.new(0.6, 2, 2)
		plate.Color = Color3.fromRGB(30, 30, 35)
		plate.Material = Enum.Material.Metal
		plate.CanCollide = false
		plate.Massless = true
		plate.CFrame = handle.CFrame * CFrame.new(x, 0, 0)
		plate.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = plate
		weld.Parent = plate
	end
	tool.Grip = CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
	return tool
end
Decor.GripDown = CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
Decor.GripUp = CFrame.new(0, -2.6, -0.4) * CFrame.Angles(0, 0, math.rad(90))

---------------------------------------------------------------------------
-- Text on a part face (SurfaceGui helper)
---------------------------------------------------------------------------
function Decor.FaceText(part, text, color, size, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 100)
	gui.Parent = part
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.Font = Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.Text = text
	tl.TextColor3 = color or Decor.Colors.White
	tl.TextStrokeTransparency = 0
	tl.Parent = gui
	return gui
end

return Decor
