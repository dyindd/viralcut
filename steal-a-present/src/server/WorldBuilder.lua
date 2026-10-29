--[[
	WorldBuilder.lua  (ServerScriptService.Server.WorldBuilder)

	Generates the whole map from code so the game runs the moment you press Play:
	snowy hub, the conveyor belt, the season tree, and a ring of player bases.
	Every piece is a plain Part so you can replace it with real art later. Names matter:
	PlotService finds parts by name (DepositPad, CollectPad, LockButton, Bench, Sign, Dome, Slots, TrapSockets, Delivery, SpawnPoint).
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local WorldBuilder = {}

local function part(props)
	local p = Instance.new(props.Shape == "Wedge" and "WedgePart" or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.Name or "Part"
	p.Size = props.Size or Vector3.new(4, 1, 4)
	p.CFrame = props.CFrame or CFrame.new()
	p.Color = props.Color or Color3.fromRGB(255, 255, 255)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.CanCollide = props.CanCollide ~= false
	if props.Shape == "Ball" then p.Shape = Enum.PartType.Ball end
	if props.Shape == "Cylinder" then p.Shape = Enum.PartType.Cylinder end
	p.Parent = props.Parent
	return p
end

local function label(parent, text, size, color, offsetY)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.new(0, 200, 0, 50)
	bb.StudsOffset = Vector3.new(0, offsetY or 3, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 120
	bb.Parent = parent
	local tl = Instance.new("TextLabel")
	tl.Name = "Text"
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.Font = Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.Text = text
	tl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	tl.TextStrokeTransparency = 0
	tl.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
	tl.Parent = bb
	return bb
end

local PALETTE = {
	Color3.fromRGB(255, 120, 140), Color3.fromRGB(110, 190, 255), Color3.fromRGB(140, 230, 150), Color3.fromRGB(255, 200, 90),
	Color3.fromRGB(200, 140, 255), Color3.fromRGB(255, 160, 90), Color3.fromRGB(120, 230, 230), Color3.fromRGB(255, 140, 220),
}

local function buildHub(world)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = world

	-- ground
	part({ Name = "Ground", Size = Vector3.new(560, 2, 560), CFrame = CFrame.new(0, -1, 0),
		Color = Color3.fromRGB(235, 245, 255), Material = Enum.Material.Snow, Parent = hub })
	-- plaza
	part({ Name = "Plaza", Size = Vector3.new(0.5, 180, 180), CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(200, 225, 245), Material = Enum.Material.Ice, Shape = "Cylinder", Parent = hub })

	-- conveyor belt along X axis, boxes travel +X
	local conv = Instance.new("Model")
	conv.Name = "Conveyor"
	conv.Parent = hub
	local len = Config.Conveyor.Length
	local belt = part({ Name = "Belt", Size = Vector3.new(len, 1.2, 7), CFrame = CFrame.new(0, 0.9, 0),
		Color = Color3.fromRGB(45, 45, 55), Material = Enum.Material.Metal, Parent = conv })
	for i = 0, len / 8 do
		part({ Name = "Stripe", Size = Vector3.new(0.6, 0.1, 6.4), CFrame = CFrame.new(-len / 2 + i * 8, 1.55, 0),
			Color = Color3.fromRGB(255, 220, 80), Material = Enum.Material.Neon, CanCollide = false, Parent = conv })
	end
	part({ Name = "RailA", Size = Vector3.new(len, 1.0, 0.6), CFrame = CFrame.new(0, 1.6, 3.8), Color = Color3.fromRGB(200, 60, 70), Parent = conv })
	part({ Name = "RailB", Size = Vector3.new(len, 1.0, 0.6), CFrame = CFrame.new(0, 1.6, -3.8), Color = Color3.fromRGB(200, 60, 70), Parent = conv })
	local startMarker = part({ Name = "Start", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(-len / 2 + 2, 1.5, 0), Transparency = 1, CanCollide = false, Parent = conv })
	local endMarker = part({ Name = "End", Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(len / 2 - 2, 1.5, 0), Transparency = 1, CanCollide = false, Parent = conv })
	-- a "factory" at the start, a "shredder" at the end
	local factory = part({ Name = "Factory", Size = Vector3.new(10, 12, 12), CFrame = CFrame.new(-len / 2 - 5, 6, 0),
		Color = Color3.fromRGB(230, 70, 80), Material = Enum.Material.SmoothPlastic, Parent = conv })
	label(factory, "🎁 PRESENT FACTORY", 1, Color3.fromRGB(255, 255, 255), 8)
	local shredder = part({ Name = "Shredder", Size = Vector3.new(8, 8, 10), CFrame = CFrame.new(len / 2 + 4, 4, 0),
		Color = Color3.fromRGB(80, 80, 90), Material = Enum.Material.DiamondPlate, Parent = conv })
	label(shredder, "SHREDDER - don't let them get here!", 1, Color3.fromRGB(255, 120, 120), 6)
	conv.PrimaryPart = belt
	conv:SetAttribute("Start", startMarker.Position)
	conv:SetAttribute("End", endMarker.Position)

	-- spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.5, 28)
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Material = Enum.Material.Ice
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	-- season tree
	local tree = Instance.new("Model")
	tree.Name = "SeasonTree"
	tree.Parent = hub
	local trunk = part({ Name = "Trunk", Size = Vector3.new(4, 8, 4), CFrame = CFrame.new(0, 4, -40), Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.Wood, Parent = tree })
	for i = 0, 3 do
		local s = 22 - i * 5
		part({ Name = "Leaves" .. i, Size = Vector3.new(s, 5, s), CFrame = CFrame.new(0, 10 + i * 4.5, -40) * CFrame.Angles(0, math.rad(i * 22), 0),
			Color = Color3.fromRGB(40, 150, 70), Material = Enum.Material.Grass, Parent = tree })
	end
	local star = part({ Name = "Star", Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(0, 30, -40), Color = Color3.fromRGB(255, 230, 80), Material = Enum.Material.Neon, CanCollide = false, Shape = "Ball", Parent = tree })
	local pl = Instance.new("PointLight")
	pl.Color = star.Color
	pl.Range = 30
	pl.Brightness = 2
	pl.Parent = star
	tree.PrimaryPart = trunk
	label(star, "SEASON", 1, Color3.fromRGB(255, 240, 150), 4).Name = "SeasonLabel"

	-- candy cane poles
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local pos = Vector3.new(math.cos(a) * 85, 5, math.sin(a) * 85)
		part({ Name = "Pole", Size = Vector3.new(1.5, 10, 1.5), CFrame = CFrame.new(pos), Color = (i % 2 == 0) and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 255, 255), Parent = hub })
		part({ Name = "PoleTop", Size = Vector3.new(2.2, 2.2, 2.2), CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)), Color = Color3.fromRGB(255, 230, 80), Material = Enum.Material.Neon, Shape = "Ball", CanCollide = false, Parent = hub })
	end

	-- snowfall
	local emitterPart = part({ Name = "SnowEmitter", Size = Vector3.new(400, 1, 400), CFrame = CFrame.new(0, 90, 0), Transparency = 1, CanCollide = false, Parent = hub })
	local em = Instance.new("ParticleEmitter")
	em.Rate = 60
	em.Lifetime = NumberRange.new(10, 14)
	em.Speed = NumberRange.new(6, 9)
	em.Size = NumberSequence.new(0.35)
	em.Transparency = NumberSequence.new(0.2)
	em.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	em.EmissionDirection = Enum.NormalId.Bottom
	em.Parent = emitterPart

	return hub
end

local function buildPlot(index, world)
	local cfg = Config.Plots
	local angle = (index - 1) / cfg.Count * math.pi * 2
	local center = Vector3.new(math.cos(angle) * cfg.RingRadius, 0, math.sin(angle) * cfg.RingRadius)
	-- -Z of the plot faces the hub center
	local cf = CFrame.lookAt(center, Vector3.new(0, 0, 0))
	local color = PALETTE[((index - 1) % #PALETTE) + 1]

	local plot = Instance.new("Model")
	plot.Name = "Plot" .. index
	plot:SetAttribute("Index", index)
	plot:SetAttribute("Owner", 0)
	plot.Parent = world

	local size = cfg.BaseSize
	local floor = part({ Name = "Floor", Size = size, CFrame = cf * CFrame.new(0, 0.5, 0), Color = color, Material = Enum.Material.SmoothPlastic, Parent = plot })
	plot.PrimaryPart = floor
	-- border
	part({ Name = "BorderBack", Size = Vector3.new(size.X + 2, 3, 1), CFrame = cf * CFrame.new(0, 1.5, size.Z / 2 + 0.5), Color = Color3.fromRGB(255, 255, 255), Parent = plot })
	part({ Name = "BorderL", Size = Vector3.new(1, 3, size.Z + 2), CFrame = cf * CFrame.new(-size.X / 2 - 0.5, 1.5, 0), Color = Color3.fromRGB(255, 255, 255), Parent = plot })
	part({ Name = "BorderR", Size = Vector3.new(1, 3, size.Z + 2), CFrame = cf * CFrame.new(size.X / 2 + 0.5, 1.5, 0), Color = Color3.fromRGB(255, 255, 255), Parent = plot })

	-- deposit pad (front middle)
	local deposit = part({ Name = "DepositPad", Size = Vector3.new(9, 0.4, 9), CFrame = cf * CFrame.new(0, 1.2, -11), Color = Color3.fromRGB(90, 255, 120), Material = Enum.Material.Neon, Parent = plot })
	label(deposit, "DROP PRESENTS HERE", 1, Color3.fromRGB(140, 255, 160), 3)

	-- collect pad (front left)
	local collect = part({ Name = "CollectPad", Size = Vector3.new(6, 0.4, 6), CFrame = cf * CFrame.new(-15, 1.2, -11), Color = Color3.fromRGB(255, 215, 60), Material = Enum.Material.Neon, Parent = plot })
	label(collect, "$ COLLECT", 1, Color3.fromRGB(255, 230, 120), 3).Name = "CollectLabel"

	-- lock button (front right)
	local lockPost = part({ Name = "LockPost", Size = Vector3.new(1.5, 4, 1.5), CFrame = cf * CFrame.new(15, 2.5, -11), Color = Color3.fromRGB(60, 60, 70), Parent = plot })
	local lockButton = part({ Name = "LockButton", Size = Vector3.new(2.5, 1, 2.5), CFrame = cf * CFrame.new(15, 5, -11), Color = Color3.fromRGB(255, 70, 80), Material = Enum.Material.Neon, Parent = plot })
	label(lockButton, "🔒 LOCK", 1, Color3.fromRGB(255, 255, 255), 2.5).Name = "LockLabel"
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LockPrompt"
	prompt.ActionText = "Lock Base"
	prompt.ObjectText = "Shield"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = lockButton

	-- training bench (right side)
	local bench = part({ Name = "Bench", Size = Vector3.new(5, 1.5, 7), CFrame = cf * CFrame.new(18, 1.75, 8), Color = Color3.fromRGB(80, 90, 110), Material = Enum.Material.Metal, Parent = plot })
	part({ Name = "Barbell", Size = Vector3.new(6, 0.5, 0.5), CFrame = cf * CFrame.new(18, 4, 8), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal, CanCollide = false, Parent = plot })
	part({ Name = "WeightL", Size = Vector3.new(0.6, 2, 2), CFrame = cf * CFrame.new(15.3, 4, 8), Color = Color3.fromRGB(30, 30, 35), Shape = "Cylinder", CanCollide = false, Parent = plot })
	part({ Name = "WeightR", Size = Vector3.new(0.6, 2, 2), CFrame = cf * CFrame.new(20.7, 4, 8), Color = Color3.fromRGB(30, 30, 35), Shape = "Cylinder", CanCollide = false, Parent = plot })
	label(bench, "💪 TRAIN STRENGTH", 1, Color3.fromRGB(255, 255, 255), 4).Name = "BenchLabel"
	local benchPrompt = Instance.new("ProximityPrompt")
	benchPrompt.Name = "TrainPrompt"
	benchPrompt.ActionText = "Train"
	benchPrompt.ObjectText = "Bench"
	benchPrompt.HoldDuration = 0
	benchPrompt.MaxActivationDistance = 8
	benchPrompt.RequiresLineOfSight = false
	benchPrompt.Parent = bench

	-- trap sockets
	local sockets = Instance.new("Folder")
	sockets.Name = "TrapSockets"
	sockets.Parent = plot
	local socketOffsets = { Vector3.new(-8, 1.05, -6), Vector3.new(8, 1.05, -6), Vector3.new(0, 1.05, 14) }
	for i = 1, Config.Traps.Sockets do
		local off = socketOffsets[i] or Vector3.new(0, 1.05, 0)
		local s = part({ Name = "Socket" .. i, Size = Vector3.new(0.2, 5, 5), CFrame = cf * CFrame.new(off) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(120, 120, 140), Material = Enum.Material.SmoothPlastic, Shape = "Cylinder", CanCollide = false, Parent = sockets })
		s:SetAttribute("SocketIndex", i)
		s:SetAttribute("Trap", "")
		local sp = Instance.new("ProximityPrompt")
		sp.Name = "TrapPrompt"
		sp.ActionText = "Place Trap"
		sp.ObjectText = "Empty socket"
		sp.HoldDuration = 0
		sp.MaxActivationDistance = 8
		sp.RequiresLineOfSight = false
		sp.Parent = s
	end

	-- present slots (pedestals), rows going toward the back
	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = plot
	for i = 1, cfg.MaxSlots do
		local row = math.floor((i - 1) / cfg.SlotsPerRow)
		local col = (i - 1) % cfg.SlotsPerRow
		local x = (col - (cfg.SlotsPerRow - 1) / 2) * cfg.SlotSpacing
		local z = -2 + row * cfg.SlotSpacing
		local ped = part({ Name = "Slot" .. i, Size = Vector3.new(4.5, 1, 4.5), CFrame = cf * CFrame.new(x, 1.5, z),
			Color = Color3.fromRGB(250, 250, 255), Material = Enum.Material.Marble, Parent = slots })
		ped:SetAttribute("SlotIndex", i)
		ped.Transparency = 1
		ped.CanCollide = false
	end

	-- delivery spot (free boxes from rewards appear here)
	part({ Name = "Delivery", Size = Vector3.new(4, 0.2, 4), CFrame = cf * CFrame.new(-18, 1.1, 4), Color = Color3.fromRGB(255, 150, 220), Material = Enum.Material.Neon, CanCollide = false, Parent = plot })

	-- owner spawn point (just outside the front)
	part({ Name = "SpawnPoint", Size = Vector3.new(2, 1, 2), CFrame = cf * CFrame.new(0, 3, -24), Transparency = 1, CanCollide = false, Parent = plot })

	-- shield dome (visual only; the server refuses steals while locked)
	local dome = part({ Name = "Dome", Size = Vector3.new(size.X + 16, size.X + 16, size.X + 16), CFrame = cf * CFrame.new(0, 0, 2),
		Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.ForceField, Transparency = 1, CanCollide = false, Shape = "Ball", Parent = plot })
	dome.CanQuery = false
	dome.CanTouch = false

	-- sign at the back
	local sign = part({ Name = "Sign", Size = Vector3.new(16, 7, 1), CFrame = cf * CFrame.new(0, 7, size.Z / 2 + 1), Color = Color3.fromRGB(255, 255, 255), Parent = plot })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(800, 350)
	gui.Parent = sign
	local function signText(name, y, h, textSize, color)
		local tl = Instance.new("TextLabel")
		tl.Name = name
		tl.BackgroundTransparency = 1
		tl.Position = UDim2.new(0, 0, 0, y)
		tl.Size = UDim2.new(1, 0, 0, h)
		tl.Font = Enum.Font.FredokaOne
		tl.TextSize = textSize
		tl.TextColor3 = color
		tl.TextStrokeTransparency = 0.2
		tl.Text = ""
		tl.Parent = gui
		return tl
	end
	signText("Owner", 10, 110, 80, Color3.fromRGB(40, 40, 60)).Text = "EMPTY BASE"
	signText("Income", 130, 80, 60, Color3.fromRGB(60, 180, 90)).Text = ""
	signText("Pile", 220, 80, 60, Color3.fromRGB(230, 170, 30)).Text = ""
	signText("Status", 290, 50, 40, Color3.fromRGB(255, 80, 90)).Text = ""

	return plot
end

function WorldBuilder.Build()
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
	-- drop zone for loose boxes/pickups
	local pickups = Instance.new("Folder")
	pickups.Name = "Pickups"
	pickups.Parent = world
	local belt = Instance.new("Folder")
	belt.Name = "BeltBoxes"
	belt.Parent = world
	return world
end

return WorldBuilder
