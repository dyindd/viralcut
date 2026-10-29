-- Instance tree + Signals for the headless engine. Properties are plain fields (validated
-- against a per-class allow-list so typos in property names get reported), children are
-- reachable by name (properties shadow children, like Roblox), events are lazy Signals.

---------------------------------------------------------------- Signal
Signal = { __typeof = "RBXScriptSignal" }
Signal.__index = Signal
function Signal.new(name) return setmetatable({ _handlers = {}, _name = name }, Signal) end
function Signal:Connect(fn)
	local conn = { Connected = true, _fn = fn }
	function conn:Disconnect() self.Connected = false end
	conn.disconnect = conn.Disconnect
	table.insert(self._handlers, conn)
	return conn
end
Signal.connect = Signal.Connect
function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...) conn:Disconnect() fn(...) end)
	return conn
end
function Signal:ConnectParallel(fn) return self:Connect(fn) end
function Signal:Fire(...)
	local snapshot = {}
	for _, c in ipairs(self._handlers) do if c.Connected then table.insert(snapshot, c) end end
	-- prune disconnected
	local alive = {}
	for _, c in ipairs(self._handlers) do if c.Connected then table.insert(alive, c) end end
	self._handlers = alive
	for _, c in ipairs(snapshot) do
		if c.Connected then task.spawn(c._fn, ...) end
	end
end
function Signal:Wait()
	local co = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		Sched.resume(co, ...)
	end)
	return coroutine.yield()
end

---------------------------------------------------------------- class hierarchy
local PARENT = {
	PVInstance = "Instance", Model = "PVInstance", BasePart = "PVInstance", Part = "BasePart", WedgePart = "BasePart", MeshPart = "BasePart",
	SpawnLocation = "Part", Seat = "Part", Terrain = "BasePart", UnionOperation = "BasePart",
	Folder = "Instance", Configuration = "Instance", LuaSourceContainer = "Instance", BaseScript = "LuaSourceContainer",
	Script = "BaseScript", LocalScript = "BaseScript", ModuleScript = "LuaSourceContainer",
	Player = "Instance", Backpack = "Instance", PlayerGui = "Instance", StarterGear = "Instance", PlayerScripts = "Instance",
	Humanoid = "Instance", Tool = "Instance", Accessory = "Instance", Attachment = "Instance", Animator = "Instance",
	Constraint = "Instance", WeldConstraint = "Instance", LinearVelocity = "Constraint", AlignPosition = "Constraint", BodyVelocity = "Instance", BodyPosition = "Instance",
	Light = "Instance", PointLight = "Light", SpotLight = "Light", SurfaceLight = "Light",
	ParticleEmitter = "Instance", Sparkles = "Instance", Fire = "Instance", Smoke = "Instance", Highlight = "Instance", Sound = "Instance", SoundGroup = "Instance", Beam = "Instance", Trail = "Instance",
	GuiBase = "Instance", GuiBase2d = "GuiBase", LayerCollector = "GuiBase2d", ScreenGui = "LayerCollector", BillboardGui = "LayerCollector", SurfaceGui = "LayerCollector",
	GuiObject = "GuiBase2d", Frame = "GuiObject", ScrollingFrame = "GuiObject", TextLabel = "GuiObject", GuiButton = "GuiObject", TextButton = "GuiButton", TextBox = "GuiObject",
	ImageLabel = "GuiObject", ImageButton = "GuiButton", ViewportFrame = "GuiObject", CanvasGroup = "GuiObject", VideoFrame = "GuiObject",
	UIBase = "Instance", UIComponent = "UIBase", UIConstraint = "UIComponent", UICorner = "UIComponent", UIStroke = "UIComponent", UIGradient = "UIComponent", UIScale = "UIComponent",
	UIPadding = "UIComponent", UITextSizeConstraint = "UIConstraint", UIAspectRatioConstraint = "UIConstraint", UISizeConstraint = "UIConstraint",
	UILayout = "UIComponent", UIGridStyleLayout = "UILayout", UIListLayout = "UIGridStyleLayout", UIGridLayout = "UIGridStyleLayout", UIPageLayout = "UIGridStyleLayout", UITableLayout = "UIGridStyleLayout",
	ProximityPrompt = "Instance", ClickDetector = "Instance", RemoteEvent = "Instance", UnreliableRemoteEvent = "Instance", RemoteFunction = "Instance", BindableEvent = "Instance", BindableFunction = "Instance",
	ValueBase = "Instance", IntValue = "ValueBase", NumberValue = "ValueBase", StringValue = "ValueBase", BoolValue = "ValueBase", ObjectValue = "ValueBase",
	ServiceProvider = "Instance", DataModel = "ServiceProvider", Workspace = "Instance", Players = "Instance", ReplicatedStorage = "Instance", ReplicatedFirst = "Instance",
	ServerScriptService = "Instance", ServerStorage = "Instance", StarterPlayer = "Instance", StarterPlayerScripts = "Instance", StarterCharacterScripts = "Instance", StarterGui = "Instance", StarterPack = "Instance",
	Lighting = "Instance", SoundService = "Instance", RunService = "Instance", DataStoreService = "Instance", HttpService = "Instance", MarketplaceService = "Instance",
	Debris = "Instance", TweenService = "Instance", UserInputService = "Instance", Camera = "Instance", Mouse = "Instance", CoreGui = "Instance", TextChatService = "Instance",
	CollectionService = "Instance", TeleportService = "Instance", BadgeService = "Instance", Chat = "Instance", Teams = "Instance", PhysicsService = "Instance", GuiService = "Instance", ContextActionService = "Instance",
	Atmosphere = "Instance", Sky = "Instance", BloomEffect = "Instance", ColorCorrectionEffect = "Instance",
}

local function isA(class, target)
	local c = class
	while c do
		if c == target then return true end
		c = PARENT[c]
	end
	return false
end

---------------------------------------------------------------- property allow-list (for typo reports)
local PROPS = {
	Instance = { Name = 1, Parent = 1, Archivable = 1 },
	PVInstance = {},
	BasePart = { Size = 1, CFrame = 1, Position = 1, Orientation = 1, Rotation = 1, Anchored = 1, CanCollide = 1, CanTouch = 1, CanQuery = 1, Transparency = 1, Color = 1, BrickColor = 1, Material = 1, MaterialVariant = 1, Massless = 1, Reflectance = 1,
		TopSurface = 1, BottomSurface = 1, LeftSurface = 1, RightSurface = 1, FrontSurface = 1, BackSurface = 1, CastShadow = 1, AssemblyLinearVelocity = 1, AssemblyAngularVelocity = 1, Velocity = 1, CollisionGroup = 1, Locked = 1, CustomPhysicalProperties = 1, PivotOffset = 1, EnableFluidForces = 1 },
	Part = { Shape = 1 },
	SpawnLocation = { Neutral = 1, Duration = 1, TeamColor = 1, AllowTeamChangeOnTouch = 1, Enabled = 1 },
	Model = { PrimaryPart = 1, WorldPivot = 1, ModelStreamingMode = 1, LevelOfDetail = 1 },
	Humanoid = { Health = 1, MaxHealth = 1, WalkSpeed = 1, JumpPower = 1, JumpHeight = 1, UseJumpPower = 1, PlatformStand = 1, AutoRotate = 1, DisplayName = 1, HipHeight = 1, Sit = 1, Jump = 1, DisplayDistanceType = 1, HealthDisplayDistance = 1, NameDisplayDistance = 1, BreakJointsOnDeath = 1, RequiresNeck = 1, RigType = 1 },
	Tool = { RequiresHandle = 1, CanBeDropped = 1, ToolTip = 1, Grip = 1, GripPos = 1, GripForward = 1, GripRight = 1, GripUp = 1, Enabled = 1, ManualActivationOnly = 1, TextureId = 1 },
	Accessory = { AccessoryType = 1 },
	Attachment = { Position = 1, CFrame = 1, WorldPosition = 1, WorldCFrame = 1, Axis = 1, SecondaryAxis = 1, Orientation = 1, Visible = 1 },
	WeldConstraint = { Part0 = 1, Part1 = 1, Enabled = 1 },
	Constraint = { Attachment0 = 1, Attachment1 = 1, Enabled = 1, Visible = 1, Color = 1 },
	LinearVelocity = { MaxForce = 1, VectorVelocity = 1, VelocityConstraintMode = 1, RelativeTo = 1, ForceLimitsEnabled = 1, ForceLimitMode = 1, LineVelocity = 1, PlaneVelocity = 1, PrimaryTangentAxis = 1, SecondaryTangentAxis = 1, MaxAxesForce = 1, MaxPlanarAxesForce = 1, LineDirection = 1 },
	BodyVelocity = { Velocity = 1, MaxForce = 1, P = 1 },
	Light = { Color = 1, Brightness = 1, Enabled = 1, Shadows = 1 }, PointLight = { Range = 1 }, SpotLight = { Range = 1, Angle = 1, Face = 1 },
	ParticleEmitter = { Rate = 1, Lifetime = 1, Speed = 1, Size = 1, Transparency = 1, Color = 1, EmissionDirection = 1, SpreadAngle = 1, LightEmission = 1, LightInfluence = 1, Enabled = 1, Texture = 1, Rotation = 1, RotSpeed = 1, Acceleration = 1, Drag = 1, LockedToPart = 1, ZOffset = 1, Brightness = 1, Squash = 1, Shape = 1, ShapeStyle = 1, ShapeInOut = 1, ShapePartial = 1, TimeScale = 1, VelocityInheritance = 1, Orientation = 1, FlipbookLayout = 1, FlipbookMode = 1, FlipbookFramerate = 1, FlipbookStartRandom = 1, WindAffectsDrag = 1 },
	Sparkles = { SparkleColor = 1, Enabled = 1, Color = 1 },
	Highlight = { FillColor = 1, OutlineColor = 1, FillTransparency = 1, OutlineTransparency = 1, Adornee = 1, Enabled = 1, DepthMode = 1 },
	Sound = { SoundId = 1, Volume = 1, Looped = 1, PlaybackSpeed = 1, RollOffMaxDistance = 1, RollOffMinDistance = 1, RollOffMode = 1, IsPlaying = 1, Playing = 1, TimePosition = 1, SoundGroup = 1, PlayOnRemove = 1, Pitch = 1 },
	GuiBase2d = { AutoLocalize = 1, RootLocalizationTable = 1 },
	LayerCollector = { Enabled = 1, ResetOnSpawn = 1, ZIndexBehavior = 1 },
	ScreenGui = { IgnoreGuiInset = 1, DisplayOrder = 1, ScreenInsets = 1, ClipToDeviceSafeArea = 1, SafeAreaCompatibility = 1, OnTopOfCoreBlur = 1 },
	BillboardGui = { Size = 1, StudsOffset = 1, StudsOffsetWorldSpace = 1, AlwaysOnTop = 1, MaxDistance = 1, Adornee = 1, LightInfluence = 1, ExtentsOffset = 1, ExtentsOffsetWorldSpace = 1, SizeOffset = 1, Active = 1, ClipsDescendants = 1, Brightness = 1, DistanceLowerLimit = 1, DistanceUpperLimit = 1, DistanceStep = 1, PlayerToHideFrom = 1 },
	SurfaceGui = { Face = 1, CanvasSize = 1, Adornee = 1, AlwaysOnTop = 1, SizingMode = 1, PixelsPerStud = 1, LightInfluence = 1, Brightness = 1, ZOffset = 1, ClipsDescendants = 1, ToolPunchThroughDistance = 1, MaxDistance = 1 },
	GuiObject = { Size = 1, Position = 1, AnchorPoint = 1, BackgroundColor3 = 1, BackgroundTransparency = 1, BorderSizePixel = 1, BorderColor3 = 1, BorderMode = 1, Visible = 1, ZIndex = 1, LayoutOrder = 1, Active = 1, ClipsDescendants = 1, Rotation = 1, AutomaticSize = 1, Selectable = 1, SizeConstraint = 1, Transparency = 1, Interactable = 1, NextSelectionDown = 1, NextSelectionUp = 1, NextSelectionLeft = 1, NextSelectionRight = 1, SelectionOrder = 1, SelectionImageObject = 1, Draggable = 1 },
	TextLabel = { Text = 1, TextColor3 = 1, TextSize = 1, TextScaled = 1, TextWrapped = 1, TextXAlignment = 1, TextYAlignment = 1, Font = 1, FontFace = 1, RichText = 1, TextStrokeTransparency = 1, TextStrokeColor3 = 1, TextTransparency = 1, LineHeight = 1, MaxVisibleGraphemes = 1, TextTruncate = 1, TextDirection = 1, LocalizedText = 1, TextFits = 1, TextBounds = 1, ContentText = 1 },
	GuiButton = { AutoButtonColor = 1, Modal = 1, Style = 1, Selected = 1 },
	TextButton = { Text = 1, TextColor3 = 1, TextSize = 1, TextScaled = 1, TextWrapped = 1, TextXAlignment = 1, TextYAlignment = 1, Font = 1, FontFace = 1, RichText = 1, TextStrokeTransparency = 1, TextStrokeColor3 = 1, TextTransparency = 1, LineHeight = 1, MaxVisibleGraphemes = 1, TextTruncate = 1, TextDirection = 1, LocalizedText = 1 },
	TextBox = { Text = 1, PlaceholderText = 1, PlaceholderColor3 = 1, ClearTextOnFocus = 1, TextEditable = 1, MultiLine = 1, TextColor3 = 1, TextSize = 1, TextScaled = 1, TextWrapped = 1, TextXAlignment = 1, TextYAlignment = 1, Font = 1, FontFace = 1, RichText = 1, TextStrokeTransparency = 1, TextStrokeColor3 = 1, TextTransparency = 1, CursorPosition = 1, SelectionStart = 1, ShowNativeInput = 1 },
	ImageLabel = { Image = 1, ImageColor3 = 1, ImageTransparency = 1, ScaleType = 1, SliceCenter = 1, SliceScale = 1, TileSize = 1, ImageRectOffset = 1, ImageRectSize = 1, ResampleMode = 1 },
	ImageButton = { Image = 1, ImageColor3 = 1, ImageTransparency = 1, ScaleType = 1, SliceCenter = 1, SliceScale = 1, TileSize = 1, ImageRectOffset = 1, ImageRectSize = 1, ResampleMode = 1, HoverImage = 1, PressedImage = 1 },
	ScrollingFrame = { CanvasSize = 1, CanvasPosition = 1, ScrollBarThickness = 1, ScrollBarImageColor3 = 1, ScrollBarImageTransparency = 1, ScrollingDirection = 1, AutomaticCanvasSize = 1, ScrollingEnabled = 1, ElasticBehavior = 1, VerticalScrollBarPosition = 1, VerticalScrollBarInset = 1, HorizontalScrollBarInset = 1, TopImage = 1, BottomImage = 1, MidImage = 1, AbsoluteCanvasSize = 1, AbsoluteWindowSize = 1 },
	UICorner = { CornerRadius = 1 }, UIStroke = { Thickness = 1, Color = 1, Transparency = 1, ApplyStrokeMode = 1, LineJoinMode = 1, Enabled = 1 },
	UIGradient = { Color = 1, Transparency = 1, Rotation = 1, Offset = 1, Enabled = 1 }, UIScale = { Scale = 1 },
	UIPadding = { PaddingTop = 1, PaddingBottom = 1, PaddingLeft = 1, PaddingRight = 1 },
	UIGridStyleLayout = { FillDirection = 1, HorizontalAlignment = 1, VerticalAlignment = 1, SortOrder = 1, AbsoluteContentSize = 1 },
	UIListLayout = { Padding = 1, Wraps = 1, HorizontalFlex = 1, VerticalFlex = 1, ItemLineAlignment = 1 },
	UIGridLayout = { CellSize = 1, CellPadding = 1, FillDirectionMaxCells = 1, StartCorner = 1 },
	UITextSizeConstraint = { MaxTextSize = 1, MinTextSize = 1 }, UIAspectRatioConstraint = { AspectRatio = 1, AspectType = 1, DominantAxis = 1 }, UISizeConstraint = { MaxSize = 1, MinSize = 1 },
	ProximityPrompt = { ActionText = 1, ObjectText = 1, HoldDuration = 1, MaxActivationDistance = 1, RequiresLineOfSight = 1, Enabled = 1, KeyboardKeyCode = 1, GamepadKeyCode = 1, Exclusivity = 1, Style = 1, UIOffset = 1, ClickablePrompt = 1, AutoLocalize = 1 },
	ClickDetector = { MaxActivationDistance = 1, CursorIcon = 1 },
	RemoteFunction = { OnServerInvoke = 1, OnClientInvoke = 1 }, BindableFunction = { OnInvoke = 1 },
	ValueBase = { Value = 1 },
	Camera = { CFrame = 1, ViewportSize = 1, FieldOfView = 1, CameraType = 1, CameraSubject = 1, Focus = 1, HeadLocked = 1, HeadScale = 1 },
	Player = { Character = 1, UserId = 1, DisplayName = 1, Team = 1, TeamColor = 1, Neutral = 1, CharacterAppearanceId = 1, RespawnLocation = 1, CameraMode = 1, CameraMaxZoomDistance = 1, CameraMinZoomDistance = 1, DevComputerMovementMode = 1, DevTouchMovementMode = 1, DevEnableMouseLock = 1, HealthDisplayDistance = 1, NameDisplayDistance = 1, AutoJumpEnabled = 1, ReplicationFocus = 1, CanLoadCharacterAppearance = 1, AccountAge = 1, MembershipType = 1, LocaleId = 1 },
	MarketplaceService = { ProcessReceipt = 1 },
	Atmosphere = { Density = 1, Offset = 1, Color = 1, Decay = 1, Glare = 1, Haze = 1 },
}
local function propAllowed(class, key)
	if type(key) ~= "string" or key:sub(1, 1) == "_" then return true end
	local c = class
	while c do
		local set = PROPS[c]
		if set and set[key] then return true end
		c = PARENT[c]
	end
	return false
end

---------------------------------------------------------------- events
local EVENTS = {}
for _, n in ipairs({ "Touched", "TouchEnded", "Triggered", "TriggerEnded", "PromptButtonHoldBegan", "PromptButtonHoldEnded", "Activated", "Deactivated", "Equipped", "Unequipped",
	"Died", "HealthChanged", "StateChanged", "Running", "Jumping", "FreeFalling", "Seated", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged", "Changed", "Destroying", "AttributeChanged",
	"OnServerEvent", "OnClientEvent", "Event", "PlayerAdded", "PlayerRemoving", "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "Heartbeat", "Stepped", "RenderStepped", "PreSimulation", "PostSimulation", "PreRender",
	"Ended", "Played", "Stopped", "Paused", "Loaded", "DidLoop", "MouseEnter", "MouseLeave", "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "MouseButton2Click", "MouseMoved", "InputBegan", "InputEnded", "InputChanged", "TouchTap",
	"PromptGamePassPurchaseFinished", "PromptProductPurchaseFinished", "PromptPurchaseFinished", "Completed", "Closing", "Close", "FocusLost", "Focused", "ReturnPressedFromOnScreenKeyboard", "WindowFocused", "WindowFocusReleased", "Idled", "MouseClick", "Button1Down", "Button1Up", "Move", "KeyDown", "KeyUp" }) do EVENTS[n] = true end

---------------------------------------------------------------- defaults
local DEFAULTS = {
	BasePart = function(p) p.Size = Vector3.new(4, 1, 2) p.CFrame = CFrame.new() p.Anchored = false p.CanCollide = true p.CanTouch = true p.CanQuery = true p.Transparency = 0 p.Color = Color3.fromRGB(163, 162, 165) p.Material = Enum.Material.Plastic p.Massless = false p.Reflectance = 0 p.Shape = Enum.PartType.Block p.AssemblyLinearVelocity = Vector3.new() p.CastShadow = true p.Locked = false end,
	Humanoid = function(p) p.Health = 100 p.MaxHealth = 100 p.WalkSpeed = 16 p.JumpPower = 50 p.PlatformStand = false p.AutoRotate = true p.HipHeight = 2 p.DisplayName = "" end,
	Tool = function(p) p.RequiresHandle = true p.CanBeDropped = true p.ToolTip = "" p.Grip = CFrame.new() p.Enabled = true p.ManualActivationOnly = false end,
	ProximityPrompt = function(p) p.Enabled = true p.HoldDuration = 0 p.MaxActivationDistance = 10 p.ActionText = "Interact" p.ObjectText = "" p.RequiresLineOfSight = true p.ClickablePrompt = true end,
	GuiObject = function(p) p.Visible = true p.Size = UDim2.new(0, 100, 0, 100) p.Position = UDim2.new() p.AnchorPoint = Vector2.new() p.BackgroundTransparency = 0 p.BackgroundColor3 = Color3.fromRGB(255, 255, 255) p.ZIndex = 1 p.LayoutOrder = 0 p.Active = false p.ClipsDescendants = false p.BorderSizePixel = 1 p.Rotation = 0 p.Selectable = false end,
	TextLabel = function(p) p.Text = "Label" p.TextSize = 14 p.TextScaled = false p.TextWrapped = false p.RichText = false p.TextStrokeTransparency = 1 p.TextTransparency = 0 p.TextColor3 = Color3.new(0, 0, 0) p.Font = Enum.Font.Legacy p.TextXAlignment = Enum.TextXAlignment.Center p.TextYAlignment = Enum.TextYAlignment.Center end,
	TextButton = function(p) p.Text = "Button" p.TextSize = 14 p.TextScaled = false p.TextWrapped = false p.RichText = false p.TextStrokeTransparency = 1 p.TextTransparency = 0 p.TextColor3 = Color3.new(0, 0, 0) p.Font = Enum.Font.Legacy p.AutoButtonColor = true p.Selected = false end,
	TextBox = function(p) p.Text = "" p.PlaceholderText = "" p.TextSize = 14 p.ClearTextOnFocus = true end,
	ImageLabel = function(p) p.Image = "" p.ImageTransparency = 0 p.ScaleType = Enum.ScaleType.Stretch end,
	ImageButton = function(p) p.Image = "" p.ImageTransparency = 0 p.AutoButtonColor = true end,
	ScrollingFrame = function(p) p.CanvasSize = UDim2.new(0, 0, 2, 0) p.CanvasPosition = Vector2.new() p.ScrollBarThickness = 12 p.ScrollingEnabled = true end,
	UIScale = function(p) p.Scale = 1 end, UIStroke = function(p) p.Thickness = 1 p.Transparency = 0 p.Color = Color3.new(0, 0, 0) p.Enabled = true end,
	UIGradient = function(p) p.Rotation = 0 p.Offset = Vector2.new() p.Enabled = true end, UICorner = function(p) p.CornerRadius = UDim.new(0, 8) end,
	UIListLayout = function(p) p.Padding = UDim.new() p.FillDirection = Enum.FillDirection.Vertical p.SortOrder = Enum.SortOrder.Name end,
	UIGridLayout = function(p) p.CellSize = UDim2.new(0, 100, 0, 100) p.CellPadding = UDim2.new(0, 5, 0, 5) end,
	LayerCollector = function(p) p.Enabled = true p.ResetOnSpawn = true end,
	BillboardGui = function(p) p.Size = UDim2.new() p.StudsOffset = Vector3.new() p.AlwaysOnTop = false p.MaxDistance = math.huge p.Active = false end,
	SurfaceGui = function(p) p.Face = Enum.NormalId.Front p.CanvasSize = Vector2.new(800, 600) p.AlwaysOnTop = false end,
	ScreenGui = function(p) p.IgnoreGuiInset = false p.DisplayOrder = 0 end,
	Sound = function(p) p.SoundId = "" p.Volume = 0.5 p.Looped = false p.PlaybackSpeed = 1 p.IsPlaying = false p.Playing = false p.TimePosition = 0 p.RollOffMaxDistance = 10000 end,
	ParticleEmitter = function(p) p.Rate = 20 p.Enabled = true p.Lifetime = NumberRange.new(5, 10) p.Speed = NumberRange.new(5, 5) p.Size = NumberSequence.new(1) p.Transparency = NumberSequence.new(0) p.Color = ColorSequence.new(Color3.new(1, 1, 1)) end,
	PointLight = function(p) p.Range = 8 p.Brightness = 1 p.Color = Color3.new(1, 1, 1) p.Enabled = true end,
	Highlight = function(p) p.FillTransparency = 0.5 p.OutlineTransparency = 0 p.Enabled = true end,
	ValueBase = function(p) p.Value = nil end, IntValue = function(p) p.Value = 0 end, NumberValue = function(p) p.Value = 0 end, StringValue = function(p) p.Value = "" end, BoolValue = function(p) p.Value = false end,
	LinearVelocity = function(p) p.MaxForce = 0 p.VectorVelocity = Vector3.new() p.ForceLimitsEnabled = true p.Enabled = true p.RelativeTo = Enum.ActuatorRelativeTo.Attachment0 p.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector end,
	Attachment = function(p) p.Position = Vector3.new() p.CFrame = CFrame.new() end,
	WeldConstraint = function(p) p.Enabled = true end,
	Camera = function(p) p.CFrame = CFrame.new(0, 10, 20) p.ViewportSize = Vector2.new(1920, 1080) p.FieldOfView = 70 end,
	SpawnLocation = function(p) p.Neutral = true p.Duration = 10 p.Enabled = true end,
	Player = function(p) p.Character = nil p.UserId = 0 p.DisplayName = "" p.Neutral = true p.AccountAge = 30 end,
}

---------------------------------------------------------------- instance core
Engine_unknownProps = {}   -- ["Class.Prop"] = count
local Instance = {}
local InstanceMT = { __isInstance = true }
local Methods = {}

local function applyDefaults(inst, class)
	local chain = {}
	local c = class
	while c do table.insert(chain, 1, c) c = PARENT[c] end
	for _, cls in ipairs(chain) do
		local fn = DEFAULTS[cls]
		if fn then fn(inst._props) end
	end
end

local function newInstance(className)
	local inst = setmetatable({}, InstanceMT)
	rawset(inst, "_class", className)
	rawset(inst, "_props", { Name = className })
	rawset(inst, "_children", {})
	rawset(inst, "_parent", nil)
	rawset(inst, "_attributes", {})
	rawset(inst, "_signals", {})
	rawset(inst, "_propSignals", {})
	rawset(inst, "_attrSignals", {})
	rawset(inst, "_destroyed", false)
	applyDefaults(inst, className)
	return inst
end

local function getSignal(inst, name)
	local s = inst._signals[name]
	if not s then
		s = Signal.new(name)
		inst._signals[name] = s
	end
	return s
end

local function findChild(inst, name)
	for _, c in ipairs(inst._children) do
		if c._props.Name == name then return c end
	end
	return nil
end

InstanceMT.__index = function(inst, k)
	if k == "Parent" then return rawget(inst, "_parent") end
	if k == "ClassName" then return rawget(inst, "_class") end
	local props = rawget(inst, "_props")
	if k == "Position" and isA(inst._class, "BasePart") then return props.CFrame.Position end
	if k == "Orientation" and isA(inst._class, "BasePart") then return Vector3.new() end
	if k == "WorldPosition" and inst._class == "Attachment" then
		local p = inst._parent
		return p and isA(p._class, "BasePart") and (p._props.CFrame * props.Position) or props.Position
	end
	local m = Methods[k]
	if m then return m end
	local v = props[k]
	if v ~= nil then return v end
	if EVENTS[k] then return getSignal(inst, k) end
	local child = findChild(inst, k)
	if child then return child end
	return nil
end

local function setParent(inst, newParent)
	local old = rawget(inst, "_parent")
	if old == newParent then return end
	if old then
		for i, c in ipairs(old._children) do
			if c == inst then table.remove(old._children, i) break end
		end
		if old._signals.ChildRemoved then old._signals.ChildRemoved:Fire(inst) end
		local a = old
		while a do
			if a._signals.DescendantRemoving then a._signals.DescendantRemoving:Fire(inst) end
			a = a._parent
		end
	end
	rawset(inst, "_parent", newParent)
	if newParent then
		table.insert(newParent._children, inst)
		if newParent._signals.ChildAdded then newParent._signals.ChildAdded:Fire(inst) end
		local a = newParent
		while a do
			if a._signals.DescendantAdded then
				a._signals.DescendantAdded:Fire(inst)
				for _, d in ipairs(inst:GetDescendants()) do a._signals.DescendantAdded:Fire(d) end
			end
			a = a._parent
		end
	end
	if inst._signals.AncestryChanged then inst._signals.AncestryChanged:Fire(inst, newParent) end
end

local TYPE_CHECKS = {
	Text = "string", Visible = "boolean", Enabled = "boolean", Anchored = "boolean", CanCollide = "boolean",
	ZIndex = "number", LayoutOrder = "number", TextSize = "number", BackgroundTransparency = "number",
	Transparency = { GuiObject = "number", BasePart = "number", UIStroke = "number", ParticleEmitter = "NumberSequence", UIGradient = "NumberSequence" },
	Size = { GuiObject = "UDim2", BasePart = "Vector3", BillboardGui = "UDim2", ParticleEmitter = "NumberSequence" },
	Position = { GuiObject = "UDim2", BasePart = "Vector3", Attachment = "Vector3" },
	CFrame = "CFrame", BackgroundColor3 = "Color3", TextColor3 = "Color3",
	Color = { BasePart = "Color3", UIStroke = "Color3", PointLight = "Color3", ParticleEmitter = "ColorSequence", UIGradient = "ColorSequence" },
	AnchorPoint = "Vector2", Scale = "number", Thickness = "number",
	Rotation = { GuiObject = "number", UIGradient = "number", ParticleEmitter = "NumberRange" },
	Lifetime = { ParticleEmitter = "NumberRange" }, Speed = { ParticleEmitter = "NumberRange" },
}
local function checkType(inst, k, v)
	local expect = TYPE_CHECKS[k]
	if type(expect) == "table" then
		local found
		for cls, t in pairs(expect) do if isA(inst._class, cls) then found = t end end
		expect = found
	end
	if not expect or v == nil then return end
	local got = typeof(v)
	if got ~= expect then
		error(string.format("bad type for %s.%s: expected %s, got %s", inst._class, k, expect, got), 3)
	end
	if (k == "LayoutOrder" or k == "ZIndex") and math.floor(v) ~= v then
		error(string.format("%s.%s must be an integer, got %s", inst._class, k, tostring(v)), 3)
	end
end

InstanceMT.__newindex = function(inst, k, v)
	if k == "Parent" then
		if v ~= nil and typeof(v) ~= "Instance" then error("Parent must be an Instance or nil (got " .. typeof(v) .. ")", 2) end
		if rawget(inst, "_destroyed") and v ~= nil then error("The Parent property of " .. inst._props.Name .. " is locked (destroyed)", 2) end
		setParent(inst, v)
		return
	end
	if type(k) == "string" and k:sub(1, 1) == "_" then rawset(inst, k, v) return end
	local class = inst._class
	if k == "Position" and isA(class, "BasePart") then
		checkType(inst, k, v)
		local old = inst._props.CFrame
		inst._props.CFrame = CFrame.new(v.X, v.Y, v.Z) * old.Rotation
		k = "CFrame" v = inst._props.CFrame
	else
		if type(v) ~= "function" and not propAllowed(class, k) and not EVENTS[k] and not isA(class, "ServiceProvider") and not PROPS[class] == nil then
			local key = class .. "." .. tostring(k)
			Engine_unknownProps[key] = (Engine_unknownProps[key] or 0) + 1
		end
		checkType(inst, k, v)
		inst._props[k] = v
	end
	local ps = inst._propSignals[k]
	if ps then ps:Fire() end
	if inst._signals.Changed then inst._signals.Changed:Fire(k) end
end

InstanceMT.__tostring = function(inst) return inst._props.Name end

---------------------------------------------------------------- methods
function Methods.IsA(inst, cls) return isA(inst._class, cls) end
function Methods.GetChildren(inst) local out = {} for i, c in ipairs(inst._children) do out[i] = c end return out end
function Methods.GetDescendants(inst)
	local out = {}
	local function walk(n) for _, c in ipairs(n._children) do table.insert(out, c) walk(c) end end
	walk(inst)
	return out
end
function Methods.FindFirstChild(inst, name, recursive)
	local c = findChild(inst, name)
	if c or not recursive then return c end
	for _, d in ipairs(inst:GetDescendants()) do if d._props.Name == name then return d end end
	return nil
end
function Methods.FindFirstChildOfClass(inst, cls) for _, c in ipairs(inst._children) do if c._class == cls then return c end end return nil end
function Methods.FindFirstChildWhichIsA(inst, cls, recursive)
	for _, c in ipairs(inst._children) do if isA(c._class, cls) then return c end end
	if recursive then for _, d in ipairs(inst:GetDescendants()) do if isA(d._class, cls) then return d end end end
	return nil
end
function Methods.FindFirstAncestorOfClass(inst, cls) local p = inst._parent while p do if p._class == cls then return p end p = p._parent end return nil end
function Methods.FindFirstAncestorWhichIsA(inst, cls) local p = inst._parent while p do if isA(p._class, cls) then return p end p = p._parent end return nil end
function Methods.FindFirstAncestor(inst, name) local p = inst._parent while p do if p._props.Name == name then return p end p = p._parent end return nil end
function Methods.WaitForChild(inst, name, timeout)
	local c = findChild(inst, name)
	if c then return c end
	local co, main = coroutine.running()
	if main then error("WaitForChild(" .. name .. ") would yield on the main thread; child missing under " .. inst:GetFullName()) end
	local waited = 0
	local limit = timeout or 30
	while not c and waited < limit do
		waited = waited + task.wait(0.05)
		c = findChild(inst, name)
	end
	if not c and not timeout then
		io.stderr:write("[ENGINE] WaitForChild timed out: " .. inst:GetFullName() .. "." .. name .. "\n")
	end
	return c
end
function Methods.GetFullName(inst)
	local parts = {}
	local n = inst
	while n do table.insert(parts, 1, n._props.Name) n = n._parent end
	return table.concat(parts, ".")
end
function Methods.IsDescendantOf(inst, other) local p = inst._parent while p do if p == other then return true end p = p._parent end return false end
function Methods.IsAncestorOf(inst, other) return other:IsDescendantOf(inst) end
function Methods.ClearAllChildren(inst) for _, c in ipairs(inst:GetChildren()) do c:Destroy() end end
function Methods.Destroy(inst)
	if rawget(inst, "_destroyed") then return end
	if inst._signals.Destroying then inst._signals.Destroying:Fire() end
	setParent(inst, nil)
	rawset(inst, "_destroyed", true)
	for _, c in ipairs(inst:GetChildren()) do c:Destroy() end
	for _, s in pairs(inst._signals) do s._handlers = {} end
end
Methods.destroy = Methods.Destroy
function Methods.Remove(inst) setParent(inst, nil) end
function Methods.Clone(inst)
	local map = {}
	local function copy(n)
		local c = newInstance(n._class)
		for k, v in pairs(n._props) do c._props[k] = v end
		for k, v in pairs(n._attributes) do c._attributes[k] = v end
		map[n] = c
		for _, ch in ipairs(n._children) do
			local cc = copy(ch)
			rawset(cc, "_parent", c)
			table.insert(c._children, cc)
		end
		return c
	end
	local root = copy(inst)
	-- remap object references (PrimaryPart, Part0/1, Adornee, Attachment0) that point inside the tree
	for orig, cl in pairs(map) do
		for k, v in pairs(cl._props) do
			if typeof(v) == "Instance" and map[v] then cl._props[k] = map[v] end
		end
	end
	return root
end
function Methods.GetAttribute(inst, name) return inst._attributes[name] end
function Methods.GetAttributes(inst) local out = {} for k, v in pairs(inst._attributes) do out[k] = v end return out end
function Methods.SetAttribute(inst, name, value)
	inst._attributes[name] = value
	local s = inst._attrSignals[name]
	if s then s:Fire() end
	if inst._signals.AttributeChanged then inst._signals.AttributeChanged:Fire(name) end
end
function Methods.GetAttributeChangedSignal(inst, name)
	local s = inst._attrSignals[name]
	if not s then s = Signal.new("Attr." .. name) inst._attrSignals[name] = s end
	return s
end
function Methods.GetPropertyChangedSignal(inst, name)
	if not propAllowed(inst._class, name) and name ~= "Parent" then
		local key = inst._class .. "." .. name
		Engine_unknownProps[key] = (Engine_unknownProps[key] or 0) + 1
	end
	local s = inst._propSignals[name]
	if not s then s = Signal.new("Prop." .. name) inst._propSignals[name] = s end
	return s
end
function Methods.SetNetworkOwner() end
function Methods.GetNetworkOwner() return nil end
function Methods.GetPivot(inst)
	if isA(inst._class, "BasePart") then return inst._props.CFrame end
	local pp = inst._props.PrimaryPart
	if pp then return pp._props.CFrame end
	return rawget(inst, "_pivot") or CFrame.new()
end
function Methods.PivotTo(inst, cf)
	if isA(inst._class, "BasePart") then inst.CFrame = cf return end
	local pivot = inst:GetPivot()
	local delta = cf * pivot:Inverse()
	local pp = inst._props.PrimaryPart
	for _, d in ipairs(inst:GetDescendants()) do
		if isA(d._class, "BasePart") then
			-- the primary part lands EXACTLY on the target (otherwise float error compounds every frame)
			d.CFrame = (d == pp) and cf or (delta * d._props.CFrame)
		end
	end
	rawset(inst, "_pivot", cf)
end
function Methods.MoveTo(inst, pos) inst:PivotTo(CFrame.new(pos)) end
function Methods.GetBoundingBox(inst) return inst:GetPivot(), Vector3.new(4, 4, 4) end
function Methods.GetExtentsSize() return Vector3.new(4, 4, 4) end
function Methods.Emit() end
function Methods.Play(inst) inst._props.IsPlaying = true inst._props.Playing = true end
function Methods.Stop(inst) inst._props.IsPlaying = false inst._props.Playing = false if inst._signals.Ended then inst._signals.Ended:Fire() end end
function Methods.Pause(inst) inst._props.IsPlaying = false end
function Methods.ChangeState() end
function Methods.GetState() return Enum.HumanoidStateType.Running end
function Methods.TakeDamage(inst, n) inst.Health = math.max(0, inst._props.Health - n) if inst._props.Health <= 0 then inst.Died:Fire() end end
function Methods.LoadAnimation() return { Play = function() end, Stop = function() end } end
function Methods.AddTag() end
function Methods.HasTag() return false end
function Methods.GetTags() return {} end

Instance.new = function(className, parent)
	if not PARENT[className] and className ~= "Instance" then
		error("Unable to create an Instance of type \"" .. tostring(className) .. "\" (not in the engine's class list)", 2)
	end
	local inst = newInstance(className)
	if parent then inst.Parent = parent end
	return inst
end
_G.Instance = Instance
Engine_Methods = Methods
Engine_newInstance = newInstance
Engine_isA = isA
Engine_getSignal = getSignal
