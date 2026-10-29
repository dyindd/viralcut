--[[
	WorldBuilder.lua  (ServerScriptService.Server.WorldBuilder)

	Generates the whole map from code: a snowy North Pole hub (Santa's workshop feeding the conveyor,
	a giant decorated tree, lamp posts, candy canes, snowmen, igloos, present piles, leaderboards),
	stone paths to a ring of player bases (fenced yards with a gingerbread cottage, an unwrap arch,
	a gold vault, a padlock gate, a gym, pedestals), plus lighting, atmosphere, terrain mountains,
	aurora and snowfall (Environment.lua). Models come from Decor.lua; swap any of them for meshes.

	Names matter: PlotService finds parts by name (DepositPad, CollectPad, LockButton, Bench, Sign,
	Dome, Slots, TrapSockets, Delivery, SpawnPoint, LockLamp).
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local Decor = require(script.Parent.Decor)
local Environment = require(script.Parent.Environment)

local WorldBuilder = {}
local part = Decor.Part
local C = Decor.Colors
local rng = Random.new(7)

local function label(parent, text, color, offsetY, maxDistance)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.new(0, 260, 0, 56)
	bb.StudsOffset = Vector3.new(0, offsetY or 3, 0)
	bb.MaxDistance = maxDistance or 150
	bb.Parent = parent
	local tl = Instance.new("TextLabel")
	tl.Name = "Text"
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.Font = Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.Text = text
	tl.TextColor3 = color or C.White
	tl.TextStrokeTransparency = 0
	tl.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
	tl.Parent = bb
	return bb
end

local PALETTE = {
	Color3.fromRGB(230, 60, 70), Color3.fromRGB(70, 150, 240), Color3.fromRGB(70, 180, 100), Color3.fromRGB(240, 170, 50),
	Color3.fromRGB(160, 90, 230), Color3.fromRGB(240, 120, 60), Color3.fromRGB(60, 190, 200), Color3.fromRGB(235, 100, 180),
}

local function prompt(parent, name, action, object, hold, dist)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = dist or 8
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

---------------------------------------------------------------------------
-- HUB
---------------------------------------------------------------------------
local function buildHub(world)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = world

	-- ground + icy plaza
	part({ Name = "Ground", Size = Vector3.new(560, 2, 560), CFrame = CFrame.new(0, -1, 0), Color = C.Snow, Material = Enum.Material.Snow, Parent = hub })
	part({ Name = "Plaza", Shape = "Cylinder", Size = Vector3.new(0.5, 190, 190), CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(190, 225, 250), Material = Enum.Material.Ice, Reflectance = 0.15, Parent = hub })
	part({ Name = "PlazaRim", Shape = "Cylinder", Size = Vector3.new(0.6, 198, 198), CFrame = CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = C.Stone, Material = Enum.Material.Cobblestone, Parent = hub })

	-- stone paths from the plaza to every base
	for i = 1, Config.Plots.Count do
		local a = (i - 1) / Config.Plots.Count * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local from, to = 95, Config.Plots.RingRadius - 26
		local mid = dir * ((from + to) / 2)
		part({ Name = "Path", Size = Vector3.new(to - from, 0.4, 9), CFrame = CFrame.new(mid.X, 0.2, mid.Z) * CFrame.Angles(0, -a, 0), Color = Color3.fromRGB(165, 170, 185), Material = Enum.Material.Cobblestone, Parent = hub })
	end

	------------------------------------------------------------ conveyor + workshop + shredder
	local conv = Instance.new("Model")
	conv.Name = "Conveyor"
	conv.Parent = hub
	local len = Config.Conveyor.Length
	local belt = part({ Name = "Belt", Size = Vector3.new(len, 1.2, 7), CFrame = CFrame.new(0, 0.9, 0), Color = Color3.fromRGB(45, 45, 58), Material = Enum.Material.Metal, Parent = conv })
	for i = 0, len / 8 do
		part({ Name = "Stripe", Size = Vector3.new(0.6, 0.1, 6.4), CFrame = CFrame.new(-len / 2 + i * 8, 1.55, 0), Color = C.Gold, Material = Enum.Material.Neon, CanCollide = false, Parent = conv })
	end
	for _, z in ipairs({ 3.8, -3.8 }) do
		part({ Name = "Rail", Size = Vector3.new(len, 1.0, 0.6), CFrame = CFrame.new(0, 1.6, z), Color = C.Candy, Parent = conv })
		for i = 0, len / 6 do
			part({ Name = "RailLight", Shape = "Ball", Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(-len / 2 + i * 6, 2.2, z), Color = (i % 2 == 0) and C.Gold or Color3.fromRGB(80, 255, 120), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = conv })
		end
	end
	local startMarker = part({ Name = "Start", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(-len / 2 + 2, 1.5, 0), Transparency = 1, CanCollide = false, Parent = conv })
	local endMarker = part({ Name = "End", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(len / 2 - 2, 1.5, 0), Transparency = 1, CanCollide = false, Parent = conv })
	conv.PrimaryPart = belt
	conv:SetAttribute("Start", startMarker.Position)
	conv:SetAttribute("End", endMarker.Position)

	-- Santa's workshop: the belt comes out of its front door
	local workshop = Decor.GingerbreadHouse(conv, CFrame.new(-len / 2 - 20, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), 34, 26, 16, C.Red, { Name = "Factory" })
	local signPart = part({ Name = "WorkshopSign", Size = Vector3.new(24, 4, 0.6), CFrame = CFrame.new(-len / 2 - 7.5, 19.5, 0) * CFrame.Angles(0, math.rad(90), 0), Color = C.Wood, Material = Enum.Material.Wood, CanCollide = false, Parent = workshop })
	Decor.FaceText(signPart, "SANTA'S WORKSHOP", C.Gold)
	for _, z in ipairs({ -10, 10 }) do
		Decor.CandyCane(workshop, CFrame.new(-len / 2 - 8, 0, z), 12, 0.7)
	end
	Decor.PresentPile(workshop, CFrame.new(-len / 2 - 4, 0, 12), 5)
	Decor.PresentPile(workshop, CFrame.new(-len / 2 - 4, 0, -12), 4)

	-- the Grinch's shredder at the end of the belt
	local shredder = Instance.new("Model")
	shredder.Name = "Shredder"
	shredder.Parent = conv
	local body = part({ Name = "Body", Size = Vector3.new(10, 9, 12), CFrame = CFrame.new(len / 2 + 5, 4.5, 0), Color = Color3.fromRGB(60, 62, 72), Material = Enum.Material.DiamondPlate, Parent = shredder })
	shredder.PrimaryPart = body
	for _, z in ipairs({ -2.2, 2.2 }) do
		part({ Name = "Blade", Shape = "Cylinder", Size = Vector3.new(3, 5, 5), CFrame = CFrame.new(len / 2 + 0.5, 3.5, z) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 70, 70), Material = Enum.Material.Neon, CanCollide = false, Parent = shredder })
	end
	for i = 0, 4 do
		part({ Name = "Warning", Size = Vector3.new(0.3, 9.2, 2.2), CFrame = CFrame.new(len / 2 - 0.1, 4.5, -5.5 + i * 2.75), Color = (i % 2 == 0) and C.Gold or Color3.fromRGB(30, 30, 35), CanCollide = false, Parent = shredder })
	end
	label(body, "SHREDDER - don't let boxes reach it!", Color3.fromRGB(255, 120, 120), 7, 220)
	local smoke = Instance.new("Smoke")
	smoke.Size = 2
	smoke.Opacity = 0.3
	smoke.RiseVelocity = 4
	smoke.Color = Color3.fromRGB(80, 80, 90)
	smoke.Parent = body

	------------------------------------------------------------ spawn platform
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 0.5, 28)
	spawn.Color = Color3.fromRGB(200, 235, 255)
	spawn.Material = Enum.Material.Ice
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Decor.CandyCane(hub, CFrame.new(math.cos(a) * 9, 0, 28 + math.sin(a) * 9), 5, 0.4)
	end

	------------------------------------------------------------ the giant season tree
	local tree = Decor.Tree(hub, CFrame.new(0, 0, -45), 3.3, { Layers = 6 })
	tree.Name = "SeasonTree"
	local star = tree:FindFirstChild("Star")
	if star then
		local season = Seasons.GetActive()
		label(star, (season.Icon or "🎄") .. " " .. (season.Name or "Christmas"), C.Gold, 5, 400).Name = "SeasonLabel"
		task.spawn(function()
			local star2 = tree:FindFirstChild("Star2")
			local base = star.CFrame
			while star.Parent do
				local t = os.clock()
				star.CFrame = base * CFrame.Angles(0, t * 1.2, 0)
				if star2 then star2.CFrame = base * CFrame.Angles(0, t * 1.2 + math.rad(45), 0) end
				task.wait(0.05)
			end
		end)
	end
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		Decor.PresentPile(hub, CFrame.new(math.cos(a) * 22, 0, -45 + math.sin(a) * 22), 5)
	end

	------------------------------------------------------------ leaderboards (wooden signs by the spawn)
	local boards = Instance.new("Model")
	boards.Name = "Leaderboards"
	boards.Parent = hub
	for i, def in ipairs(Config.Leaderboard.Boards) do
		local x = (i == 1) and -24 or 24
		for _, px in ipairs({ -7, 7 }) do
			part({ Name = "BoardPost", Size = Vector3.new(1, 16, 1), CFrame = CFrame.new(x + px, 8, 48), Color = C.Wood, Material = Enum.Material.Wood, Parent = boards })
		end
		local board = part({ Name = def.Key .. "Board", Size = Vector3.new(16, 14, 1), CFrame = CFrame.new(x, 9, 48) * CFrame.Angles(0, math.rad(180), 0), Color = Color3.fromRGB(45, 42, 60), Material = Enum.Material.Wood, Parent = boards })
		part({ Name = "BoardSnow", Size = Vector3.new(17, 0.8, 1.6), CFrame = CFrame.new(x, 16.4, 48), Color = C.Snow, Material = Enum.Material.Snow, CanCollide = false, Parent = boards })
		local gui = Instance.new("SurfaceGui")
		gui.Name = "BoardGui"
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(640, 560)
		gui.Parent = board
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0, 70)
		title.Font = Enum.Font.FredokaOne
		title.TextSize = 52
		title.TextColor3 = C.Gold
		title.TextStrokeTransparency = 0
		title.Text = def.Title
		title.Parent = gui
		for row = 1, Config.Leaderboard.Top do
			local tl = Instance.new("TextLabel")
			tl.Name = "Row" .. row
			tl.BackgroundTransparency = 1
			tl.Position = UDim2.new(0, 20, 0, 70 + (row - 1) * 46)
			tl.Size = UDim2.new(1, -40, 0, 44)
			tl.Font = Enum.Font.FredokaOne
			tl.TextSize = 34
			tl.TextXAlignment = Enum.TextXAlignment.Left
			tl.TextColor3 = C.White
			tl.TextStrokeTransparency = 0.3
			tl.Text = row .. ".  ---"
			tl.Parent = gui
		end
	end

	------------------------------------------------------------ decoration rings
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2 + math.rad(15)
		Decor.LampPost(hub, CFrame.new(math.cos(a) * 104, 0, math.sin(a) * 104) * CFrame.Angles(0, -a, 0))
	end
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		if i % 2 == 0 then
			Decor.CandyCane(hub, CFrame.new(math.cos(a) * 88, 0, math.sin(a) * 88), 10, 0.6)
		end
	end
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2 + math.rad(7.5)
		local r = 118 + (i % 2) * 10
		Decor.Tree(hub, CFrame.new(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(0.8, 1.3), { Layers = 5 })
	end
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + math.rad(30)
		Decor.Snowman(hub, CFrame.new(math.cos(a) * 70, 0, math.sin(a) * 70) * CFrame.Angles(0, -a + math.rad(90), 0), rng:NextNumber(0.8, 1.1))
	end
	Decor.Igloo(hub, CFrame.new(-60, 0, 60) * CFrame.Angles(0, math.rad(135), 0), 7)
	Decor.Igloo(hub, CFrame.new(62, 0, 58) * CFrame.Angles(0, math.rad(-135), 0), 6)
	-- forest on the foothills around the whole map
	for i = 0, 35 do
		local a = i / 36 * math.pi * 2
		local r = Config.Plots.RingRadius + 120 + rng:NextNumber(-25, 60)
		Decor.Tree(hub, CFrame.new(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(1.6, 2.6), { Layers = 5, Decorated = false, Star = false })
	end

	Environment.BuildSnowfall(hub)
	Environment.BuildAurora(hub)
	return hub
end

---------------------------------------------------------------------------
-- BASE (plot). Functional part names and positions are stable; everything else is decoration.
---------------------------------------------------------------------------
local function buildPlot(index, world)
	local cfg = Config.Plots
	local angle = (index - 1) / cfg.Count * math.pi * 2
	local center = Vector3.new(math.cos(angle) * cfg.RingRadius, 0, math.sin(angle) * cfg.RingRadius)
	local cf = CFrame.lookAt(center, Vector3.new(0, 0, 0)) -- local -Z faces the hub
	local color = PALETTE[((index - 1) % #PALETTE) + 1]
	local size = cfg.BaseSize

	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("Index", index)
	plot:SetAttribute("Owner", 0)
	plot.Parent = world

	local floor = part({ Name = "Floor", Size = size, CFrame = cf * CFrame.new(0, 0.5, 0), Color = C.Snow, Material = Enum.Material.Snow, Parent = plot })
	plot.PrimaryPart = floor
	part({ Name = "YardPath", Size = Vector3.new(7, 0.2, size.Z - 2), CFrame = cf * CFrame.new(0, 1.1, 0), Color = Color3.fromRGB(165, 170, 185), Material = Enum.Material.Cobblestone, CanCollide = false, Parent = plot })
	part({ Name = "Rug", Size = Vector3.new(size.X - 4, 0.15, 10), CFrame = cf * CFrame.new(0, 1.1, 5), Color = color, Material = Enum.Material.Fabric, Transparency = 0.35, CanCollide = false, Parent = plot })

	-- fences: sides, back, and the front with a gate gap
	Decor.Fence(plot, cf * CFrame.new(-size.X / 2 - 0.5, 1, 0) * CFrame.Angles(0, math.rad(90), 0), size.Z + 2)
	Decor.Fence(plot, cf * CFrame.new(size.X / 2 + 0.5, 1, 0) * CFrame.Angles(0, math.rad(90), 0), size.Z + 2)
	Decor.Fence(plot, cf * CFrame.new(0, 1, -size.Z / 2 - 0.5), size.X + 2, 14)
	for _, x in ipairs({ -8, 8 }) do
		local post = part({ Name = "GatePost", Size = Vector3.new(1.2, 6, 1.2), CFrame = cf * CFrame.new(x, 4, -size.Z / 2 - 0.5), Color = C.White, Parent = plot })
		part({ Name = "GateCap", Shape = "Ball", Size = Vector3.new(1.6, 1.6, 1.6), CFrame = cf * CFrame.new(x, 7.3, -size.Z / 2 - 0.5), Color = color, Material = Enum.Material.Neon, CanCollide = false, Parent = plot })
		Decor.Wreath(plot, cf * CFrame.new(x, 4.5, -size.Z / 2 - 1.3), 1.1)
		Decor.LampPost(plot, cf * CFrame.new(x * 1.9, 1, -size.Z / 2 - 4))
	end

	-- cottage at the back; the owner sign hangs on its front wall
	Decor.GingerbreadHouse(plot, cf * CFrame.new(0, 1, size.Z / 2 + 7), 26, 12, 12, color, { Name = "House" })
	local sign = part({ Name = "Sign", Size = Vector3.new(20, 7, 1), CFrame = cf * CFrame.new(0, 10.6, size.Z / 2 + 1), Color = Color3.fromRGB(255, 252, 245), Parent = plot })
	part({ Name = "SignFrame", Size = Vector3.new(21, 8, 0.8), CFrame = cf * CFrame.new(0, 10.6, size.Z / 2 + 1.2), Color = color, Parent = plot })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(800, 350)
	gui.Parent = sign
	local function signText(name, y, h, textSize, textColor)
		local tl = Instance.new("TextLabel")
		tl.Name = name
		tl.BackgroundTransparency = 1
		tl.Position = UDim2.new(0, 0, 0, y)
		tl.Size = UDim2.new(1, 0, 0, h)
		tl.Font = Enum.Font.FredokaOne
		tl.TextSize = textSize
		tl.TextColor3 = textColor
		tl.TextStrokeTransparency = 0.2
		tl.Text = ""
		tl.Parent = gui
		return tl
	end
	signText("Owner", 10, 110, 80, Color3.fromRGB(40, 40, 60)).Text = "EMPTY BASE"
	signText("Income", 130, 80, 60, Color3.fromRGB(60, 180, 90)).Text = ""
	signText("Pile", 220, 80, 60, Color3.fromRGB(230, 170, 30)).Text = ""
	signText("Status", 290, 50, 40, Color3.fromRGB(255, 80, 90)).Text = ""

	-- deposit pad under an "UNWRAP HERE" candy arch
	local deposit = part({ Name = "DepositPad", Size = Vector3.new(9, 0.4, 9), CFrame = cf * CFrame.new(0, 1.2, -11), Color = Color3.fromRGB(90, 255, 120), Material = Enum.Material.Neon, Parent = plot })
	label(deposit, "DROP PRESENTS HERE", Color3.fromRGB(140, 255, 160), 3)
	local padGlow = Instance.new("ParticleEmitter")
	padGlow.Rate = 6
	padGlow.Lifetime = NumberRange.new(1.2, 1.8)
	padGlow.Speed = NumberRange.new(2, 3)
	padGlow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	padGlow.Transparency = NumberSequence.new(0.3)
	padGlow.Color = ColorSequence.new(Color3.fromRGB(150, 255, 170))
	padGlow.LightEmission = 1
	padGlow.Parent = deposit
	for _, x in ipairs({ -6.5, 6.5 }) do
		Decor.CandyCane(plot, cf * CFrame.new(x, 1, -11), 9, 0.6)
	end
	local arch = part({ Name = "Arch", Size = Vector3.new(15, 2.2, 0.8), CFrame = cf * CFrame.new(0, 10.6, -11), Color = C.Wood, Material = Enum.Material.Wood, CanCollide = false, Parent = plot })
	Decor.FaceText(arch, "🎁 UNWRAP HERE 🎁", C.Gold, nil, Enum.NormalId.Front)
	Decor.FaceText(arch, "🎁 UNWRAP HERE 🎁", C.Gold, nil, Enum.NormalId.Back)

	-- collect pad + gold vault
	local collect = part({ Name = "CollectPad", Size = Vector3.new(6, 0.4, 6), CFrame = cf * CFrame.new(-15, 1.2, -11), Color = C.Gold, Material = Enum.Material.Neon, Parent = plot })
	label(collect, "$ COLLECT", Color3.fromRGB(255, 230, 120), 3).Name = "CollectLabel"
	local vault = part({ Name = "Vault", Size = Vector3.new(4, 3.2, 3), CFrame = cf * CFrame.new(-15, 2.6, -16.5), Color = C.Gold, Material = Enum.Material.Metal, Reflectance = 0.35, Parent = plot })
	part({ Name = "VaultLid", Size = Vector3.new(4.2, 0.6, 3.2), CFrame = cf * CFrame.new(-15, 4.4, -16.5), Color = Color3.fromRGB(200, 150, 40), Material = Enum.Material.Metal, CanCollide = false, Parent = plot })
	Decor.FaceText(vault, "$", Color3.fromRGB(60, 40, 10), nil, Enum.NormalId.Front)
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = C.Gold
	sparkles.Parent = vault

	-- lock gate: post, button (prompt), padlock with status lamp
	part({ Name = "LockPost", Size = Vector3.new(1.5, 4, 1.5), CFrame = cf * CFrame.new(15, 2.5, -11), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal, Parent = plot })
	local lockButton = part({ Name = "LockButton", Size = Vector3.new(2.5, 1, 2.5), CFrame = cf * CFrame.new(15, 5, -11), Color = Color3.fromRGB(255, 70, 80), Material = Enum.Material.Neon, Parent = plot })
	label(lockButton, "🔒 LOCK", C.White, 2.5).Name = "LockLabel"
	prompt(lockButton, "LockPrompt", "Lock Base", "Shield", 0.25, 10)
	Decor.Padlock(plot, cf * CFrame.new(15, 5.6, -11), 1.1)

	-- gym: bench (prompt), barbell, mat, rack, punching bag
	local bench = part({ Name = "Bench", Size = Vector3.new(5, 1.5, 7), CFrame = cf * CFrame.new(18, 1.95, 8), Color = Color3.fromRGB(80, 90, 110), Material = Enum.Material.Metal, Parent = plot })
	part({ Name = "Barbell", Size = Vector3.new(6, 0.5, 0.5), CFrame = cf * CFrame.new(18, 4.2, 8), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal, CanCollide = false, Parent = plot })
	part({ Name = "WeightL", Shape = "Cylinder", Size = Vector3.new(0.6, 2, 2), CFrame = cf * CFrame.new(15.3, 4.2, 8), Color = Color3.fromRGB(30, 30, 35), CanCollide = false, Parent = plot })
	part({ Name = "WeightR", Shape = "Cylinder", Size = Vector3.new(0.6, 2, 2), CFrame = cf * CFrame.new(20.7, 4.2, 8), Color = Color3.fromRGB(30, 30, 35), CanCollide = false, Parent = plot })
	label(bench, "💪 TRAIN STRENGTH", C.White, 4).Name = "BenchLabel"
	prompt(bench, "TrainPrompt", "Train", "Bench", 0, 8)
	Decor.GymSet(plot, cf * CFrame.new(17, 1, 9))

	-- trap sockets
	local sockets = Instance.new("Folder")
	sockets.Name = "TrapSockets"
	sockets.Parent = plot
	local socketOffsets = { Vector3.new(-8, 1.05, -7), Vector3.new(8, 1.05, -7), Vector3.new(-18, 1.05, 16) }
	for i = 1, Config.Traps.Sockets do
		local off = socketOffsets[i] or Vector3.new(0, 1.05, 0)
		local s = part({ Name = "Socket" .. i, Size = Vector3.new(0.2, 5, 5), CFrame = cf * CFrame.new(off) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(205, 215, 235), Material = Enum.Material.Ice, CanCollide = false, Parent = sockets })
		part({ Name = "SocketRim", Shape = "Cylinder", Size = Vector3.new(0.25, 5.6, 5.6), CFrame = cf * CFrame.new(off - Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = s })
		s:SetAttribute("SocketIndex", i)
		s:SetAttribute("Trap", "")
		prompt(s, "TrapPrompt", "Place Trap", "Empty socket", 0, 8)
	end

	-- pedestals (slots): stone top + colored rim; hidden until unlocked (PlotService.RefreshSlots)
	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = plot
	for i = 1, cfg.MaxSlots do
		local row = math.floor((i - 1) / cfg.SlotsPerRow)
		local col = (i - 1) % cfg.SlotsPerRow
		local x = (col - (cfg.SlotsPerRow - 1) / 2) * cfg.SlotSpacing
		local z = -2 + row * cfg.SlotSpacing
		local ped = part({ Name = "Slot" .. i, Size = Vector3.new(4.5, 1, 4.5), CFrame = cf * CFrame.new(x, 1.5, z), Color = Color3.fromRGB(225, 228, 240), Material = Enum.Material.Marble, Parent = slots })
		part({ Name = "Rim", Size = Vector3.new(5, 0.25, 5), CFrame = cf * CFrame.new(x, 1.05, z), Color = color, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = ped })
		ped:SetAttribute("SlotIndex", i)
		ped.Transparency = 1
		ped.CanCollide = false
		ped.Rim.Transparency = 1
	end

	-- reward delivery spot + mailbox, owner spawn point, decorations
	part({ Name = "Delivery", Size = Vector3.new(4, 0.2, 4), CFrame = cf * CFrame.new(-18, 1.1, 4), Color = Color3.fromRGB(255, 150, 220), Material = Enum.Material.Neon, CanCollide = false, Parent = plot })
	Decor.Mailbox(plot, cf * CFrame.new(-21, 1, 4) * CFrame.Angles(0, math.rad(90), 0), color)
	part({ Name = "SpawnPoint", Size = Vector3.new(2, 1, 2), CFrame = cf * CFrame.new(0, 3, -size.Z / 2), Transparency = 1, CanCollide = false, Parent = plot })
	Decor.Tree(plot, cf * CFrame.new(-19.5, 1, 21.5), 0.62, { Layers = 5 })
	Decor.Snowman(plot, cf * CFrame.new(19.5, 1, 20) * CFrame.Angles(0, math.rad(180), 0), 0.7)
	Decor.PresentPile(plot, cf * CFrame.new(20, 1, -18), 3)

	-- shield dome (visual only; the server refuses steals while locked)
	local dome = part({ Name = "Dome", Size = Vector3.new(size.X + 16, size.X + 16, size.X + 16), CFrame = cf * CFrame.new(0, 0, 2), Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.ForceField, Transparency = 1, CanCollide = false, Shape = "Ball", Parent = plot })
	dome.CanQuery = false
	dome.CanTouch = false

	return plot
end

function WorldBuilder.Build()
	Environment.ApplyLighting()
	Environment.BuildTerrain(Config.Plots.RingRadius)

	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = Workspace
	buildHub(world)
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = world
	for i = 1, Config.Plots.Count do
		buildPlot(i, plots)
	end
	local pickups = Instance.new("Folder")
	pickups.Name = "Pickups"
	pickups.Parent = world
	local belt = Instance.new("Folder")
	belt.Name = "BeltBoxes"
	belt.Parent = world
	return world
end

return WorldBuilder
