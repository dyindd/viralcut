-- Services, the DataModel tree built from the Rojo layout, module loading with per-script
-- `script` globals, remotes wiring, players/characters helpers, raycast, DataStore mock.

Engine = { datastores = {}, datastoreFailNext = 0, ownedPasses = {}, prompts = {}, purchases = {}, kicks = {}, clientPlayer = nil, remoteLog = {}, bindToClose = {} }

local newInstance = Engine_newInstance
local isA = Engine_isA

---------------------------------------------------------------- DataModel + services
game = newInstance("DataModel")
game._props.Name = "Game"
game._props.JobId = ""
game._props.PlaceId = 0
game._props.GameId = 0
game._props.PrivateServerId = ""
game._props.CreatorId = 1

local services = {}
local function service(className, name)
	local s = newInstance(className)
	s._props.Name = name or className
	rawset(s, "_isService", true)
	rawset(s, "_parent", game)
	table.insert(game._children, s)
	services[name or className] = s
	return s
end
local Workspace = service("Workspace")
local Players = service("Players")
local ReplicatedStorage = service("ReplicatedStorage")
local ServerScriptService = service("ServerScriptService")
local ServerStorage = service("ServerStorage")
local StarterPlayer = service("StarterPlayer")
local StarterGui = service("StarterGui")
local Lighting = service("Lighting")
local SoundService = service("SoundService")
local RunService = service("RunService")
local DataStoreService = service("DataStoreService")
local HttpService = service("HttpService")
local MarketplaceService = service("MarketplaceService")
local Debris = service("Debris")
local TweenService = service("TweenService")
local UserInputService = service("UserInputService")
local ReplicatedFirst = service("ReplicatedFirst")
local CollectionService = service("CollectionService")
local TextChatService = service("TextChatService")
local GuiService = service("GuiService")
local ContextActionService = service("ContextActionService")
local BadgeService = service("BadgeService")
local TeleportService = service("TeleportService")
local PhysicsService = service("PhysicsService")
local CoreGui = service("CoreGui")
local Teams = service("Teams")
local SPS = newInstance("StarterPlayerScripts") SPS._props.Name = "StarterPlayerScripts" SPS.Parent = StarterPlayer
local SCS = newInstance("StarterCharacterScripts") SCS._props.Name = "StarterCharacterScripts" SCS.Parent = StarterPlayer

workspace = Workspace
Workspace._props.Gravity = 196.2
local camera = newInstance("Camera") camera._props.Name = "Camera" camera.Parent = Workspace
Workspace._props.CurrentCamera = camera
-- pinhole projection so client guide arrows can be tested
local function project(cam, pos)
	local rel = cam._props.CFrame:Inverse() * pos
	local depth = -rel.Z
	local vp = cam._props.ViewportSize
	local f = (vp.Y / 2) / math.tan(math.rad((cam._props.FieldOfView or 70) / 2))
	local sx, sy
	if math.abs(depth) < 1e-6 then sx, sy = vp.X / 2, vp.Y / 2 else sx = vp.X / 2 + rel.X / depth * f sy = vp.Y / 2 - rel.Y / depth * f end
	local onScreen = depth > 0 and sx >= 0 and sx <= vp.X and sy >= 0 and sy <= vp.Y
	return Vector3.new(sx, sy, depth), onScreen
end
camera._props.WorldToViewportPoint = function(self, pos) return project(self, pos) end
camera._props.WorldToScreenPoint = function(self, pos) return project(self, pos) end
camera._props.ViewportPointToRay = function(self, x, y) return { Origin = self._props.CFrame.Position, Direction = self._props.CFrame.LookVector } end
local terrain = newInstance("Terrain") terrain._props.Name = "Terrain" terrain.Parent = Workspace
Workspace._props.Terrain = terrain

function game.GetService(_, name)
	local s = services[name]
	if not s then error("Unknown service " .. tostring(name)) end
	return s
end
game.FindService = game.GetService
function game.BindToClose(_, fn) table.insert(Engine.bindToClose, fn) end
function game.IsLoaded() return true end

---------------------------------------------------------------- RunService
RunService._props.IsServerFlag = true
function RunService.IsServer() return RunService._props.IsServerFlag end
function RunService.IsClient() return not RunService._props.IsServerFlag end
function RunService.IsStudio() return Engine.isStudio == true end
function RunService.IsRunning() return true end
function RunService.IsRunMode() return false end
function RunService.BindToRenderStep() end
function RunService.UnbindFromRenderStep() end
Sched.heartbeat = Engine_getSignal(RunService, "Heartbeat")

---------------------------------------------------------------- Workspace
function Workspace.GetServerTimeNow() return Sched.now end
local function partAABB(part)
	local cf, size = part._props.CFrame, part._props.Size
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local minX, minY, minZ, maxX, maxY, maxZ = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	for _, sx in ipairs({ -1, 1 }) do for _, sy in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
		local p = cf * Vector3.new(sx * hx, sy * hy, sz * hz)
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minY, maxY = math.min(minY, p.Y), math.max(maxY, p.Y)
		minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
	end end end
	return minX, minY, minZ, maxX, maxY, maxZ
end
-- vertical-ish raycast against part AABBs (enough for "find the ground")
function Workspace.Raycast(_, origin, direction, params)
	local excluded = {}
	if params and params.FilterDescendantsInstances then
		for _, inst in ipairs(params.FilterDescendantsInstances) do excluded[inst] = true end
	end
	local function isExcluded(part)
		local n = part
		while n do if excluded[n] then return true end n = n._parent end
		return false
	end
	local endY = origin.Y + direction.Y
	local best, bestY
	for _, part in ipairs(Workspace:GetDescendants()) do
		if isA(part._class, "BasePart") and part._props.CanQuery ~= false and not isExcluded(part) and part._props.Transparency < 1 then
			local minX, minY, minZ, maxX, maxY, maxZ = partAABB(part)
			if origin.X >= minX and origin.X <= maxX and origin.Z >= minZ and origin.Z <= maxZ then
				local top = maxY
				if top <= origin.Y and top >= endY and (not bestY or top > bestY) then
					best, bestY = part, top
				end
			end
		end
	end
	if not best then return nil end
	return { Position = Vector3.new(origin.X, bestY, origin.Z), Instance = best, Normal = Vector3.new(0, 1, 0), Material = best._props.Material, Distance = origin.Y - bestY }
end
function Workspace.GetPartBoundsInRadius() return {} end
function Workspace.GetPartsInPart() return {} end

---------------------------------------------------------------- Players
local playerList = {}
Players._props.MaxPlayers = 8
Players._props.RespawnTime = 5
Players._props.CharacterAutoLoads = true
Players._props.LocalPlayer = nil
function Players.GetPlayers() local out = {} for i, p in ipairs(playerList) do out[i] = p end return out end
function Players.GetPlayerByUserId(_, id) for _, p in ipairs(playerList) do if p._props.UserId == id then return p end end return nil end
function Players.GetPlayerFromCharacter(_, char) if not char then return nil end return rawget(char, "_player") end
function Players.GetUserIdFromNameAsync() return 1 end
function Players.GetNameFromUserIdAsync(_, id) return "User" .. id end

local nextUserId = 1000
function Engine.addPlayer(name, userId)
	nextUserId = nextUserId + 1
	userId = userId or nextUserId
	local player = newInstance("Player")
	player._props.Name = name
	player._props.DisplayName = name
	player._props.UserId = userId
	local backpack = newInstance("Backpack") backpack._props.Name = "Backpack" backpack.Parent = player
	local gui = newInstance("PlayerGui") gui._props.Name = "PlayerGui" gui.Parent = player
	local pscripts = newInstance("PlayerScripts") pscripts._props.Name = "PlayerScripts" pscripts.Parent = player
	function player.Kick(_, msg) table.insert(Engine.kicks, { player = player, msg = msg }) Engine.removePlayer(player) end
	function player.IsFriendsWith(_, otherId) return Engine.friends and Engine.friends[player._props.UserId] and Engine.friends[player._props.UserId][otherId] or false end
	function player.GetMouse() return Engine.mouse end
	function player.LoadCharacter() Engine.spawnCharacter(player) end
	function player.GetJoinData() return {} end
	function player.HasAppearanceLoaded() return true end
	table.insert(playerList, player)
	player.Parent = Players
	Engine_getSignal(Players, "PlayerAdded"):Fire(player)
	Engine.spawnCharacter(player)
	return player
end

function Engine.spawnCharacter(player, position)
	local old = player._props.Character
	if old then
		Engine_getSignal(player, "CharacterRemoving"):Fire(old)
		old:Destroy()
	end
	local char = newInstance("Model")
	char._props.Name = player._props.Name
	rawset(char, "_player", player)
	local root = newInstance("Part") root._props.Name = "HumanoidRootPart" root.Size = Vector3.new(2, 2, 1)
	local head = newInstance("Part") head._props.Name = "Head" head.Size = Vector3.new(2, 1, 1)
	local torso = newInstance("Part") torso._props.Name = "UpperTorso"
	local hum = newInstance("Humanoid") hum._props.Name = "Humanoid"
	local spawnPos = position
	if not spawnPos then
		local sp = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		spawnPos = sp and (sp._props.CFrame.Position + Vector3.new(0, 3, 0)) or Vector3.new(0, 3, 0)
	end
	root.CFrame = CFrame.new(spawnPos)
	head.CFrame = CFrame.new(spawnPos + Vector3.new(0, 1.5, 0))
	torso.CFrame = CFrame.new(spawnPos)
	root.Parent = char head.Parent = char torso.Parent = char hum.Parent = char
	char.PrimaryPart = root
	-- new backpack per spawn (Roblox clears it)
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then bp:ClearAllChildren() end
	player.Character = char
	char.Parent = Workspace
	Engine_getSignal(player, "CharacterAdded"):Fire(char)
	Sched.advance(0.05)
	return char
end

function Engine.removePlayer(player)
	Engine_getSignal(Players, "PlayerRemoving"):Fire(player)
	Sched.advance(0.05) -- let handlers run (they're coroutines)
	for i, p in ipairs(playerList) do if p == player then table.remove(playerList, i) break end end
	if player._props.Character then player._props.Character:Destroy() end
	player.Parent = nil
end

-- move a character so it's standing at `pos` (keeps the character Model + root in sync)
function Engine.teleport(player, pos)
	local char = player._props.Character
	if not char then return end
	char:PivotTo(CFrame.new(pos))
end
function Engine.position(player) local char = player._props.Character return char and char._props.PrimaryPart._props.CFrame.Position end
function Engine.humanoid(player) local char = player._props.Character return char and char:FindFirstChildOfClass("Humanoid") end
function Engine.kill(player)
	local hum = Engine.humanoid(player)
	if hum then hum.Health = 0 hum.Died:Fire() Sched.advance(0.05) end
end

---------------------------------------------------------------- remotes
-- RemoteEvent / RemoteFunction methods (client side simulated when Engine.clientPlayer is set)
local function logRemote(player, remote, args)
	local log = Engine.remoteLog
	log[#log + 1] = { player = player, name = remote._props.Name, args = args }
	if #log > 2000 then table.remove(log, 1) end
end
local RM = {}
function RM.FireClient(remote, player, ...)
	logRemote(player, remote, { ... })
	if Engine.clientPlayer == player then Engine_getSignal(remote, "OnClientEvent"):Fire(...) end
end
function RM.FireAllClients(remote, ...)
	for _, p in ipairs(playerList) do logRemote(p, remote, { ... }) end
	if Engine.clientPlayer then Engine_getSignal(remote, "OnClientEvent"):Fire(...) end
end
function RM.FireServer(remote, ...)
	if not Engine.clientPlayer then error("FireServer without a client player") end
	Engine_getSignal(remote, "OnServerEvent"):Fire(Engine.clientPlayer, ...)
end
function RM.InvokeServer(remote, ...)
	local fn = remote._props.OnServerInvoke
	if not fn then error("InvokeServer: no OnServerInvoke on " .. remote._props.Name) end
	return fn(Engine.clientPlayer, ...)
end
function RM.InvokeClient(remote, player, ...)
	local fn = remote._props.OnClientInvoke
	return fn and fn(...) or nil
end
function RM.Fire(remote, ...) Engine_getSignal(remote, "Event"):Fire(...) end
function RM.Invoke(remote, ...) local fn = remote._props.OnInvoke return fn and fn(...) end
for k, v in pairs(RM) do Engine_Methods[k] = v end

---------------------------------------------------------------- other services
function DataStoreService.GetDataStore(_, name)
	Engine.datastores[name] = Engine.datastores[name] or {}
	local data = Engine.datastores[name]
	local store = {}
	local function maybeFail()
		if Engine.datastoreFailNext > 0 then
			Engine.datastoreFailNext = Engine.datastoreFailNext - 1
			error("502: API Services rejected request (simulated)")
		end
	end
	local function deep(t) if type(t) ~= "table" then return t end local o = {} for k, v in pairs(t) do o[k] = deep(v) end return o end
	function store.UpdateAsync(_, key, fn)
		maybeFail()
		local new = fn(deep(data[key]))
		if new ~= nil then data[key] = deep(new) end
		return deep(data[key])
	end
	function store.GetAsync(_, key) maybeFail() return deep(data[key]) end
	function store.SetAsync(_, key, v) maybeFail() data[key] = deep(v) end
	function store.RemoveAsync(_, key) maybeFail() data[key] = nil end
	return store
end
DataStoreService.GetOrderedDataStore = function(_, name)
	Engine.datastores["ordered:" .. name] = Engine.datastores["ordered:" .. name] or {}
	local data = Engine.datastores["ordered:" .. name]
	local store = {}
	function store.SetAsync(_, key, v) data[key] = v end
	function store.UpdateAsync(_, key, fn) local nv = fn(data[key]) if nv ~= nil then data[key] = nv end return data[key] end
	function store.GetSortedAsync(_, ascending, pageSize)
		local items = {}
		for k, v in pairs(data) do table.insert(items, { key = k, value = v }) end
		table.sort(items, function(a, b) if ascending then return a.value < b.value end return a.value > b.value end)
		local page = {}
		for i = 1, math.min(pageSize or 50, #items) do page[i] = items[i] end
		return { GetCurrentPage = function() return page end, IsFinished = true, AdvanceToNextPageAsync = function() end }
	end
	return store
end

local guidCounter = 0
function HttpService.GenerateGUID(_, wrap) guidCounter = guidCounter + 1 return string.format("guid-%06d", guidCounter) end
function HttpService.JSONEncode(_, t) return tostring(t) end
function HttpService.JSONDecode() return {} end

function MarketplaceService.UserOwnsGamePassAsync(_, userId, passId)
	return Engine.ownedPasses[userId] and Engine.ownedPasses[userId][passId] == true or false
end
function MarketplaceService.PromptGamePassPurchase(_, player, id) table.insert(Engine.purchases, { kind = "pass", player = player, id = id }) end
function MarketplaceService.PromptProductPurchase(_, player, id) table.insert(Engine.purchases, { kind = "product", player = player, id = id }) end
function MarketplaceService.GetProductInfo() return { Name = "x", PriceInRobux = 1 } end

function Debris.AddItem(_, inst, t) task.delay(t or 10, function() if inst and inst.Destroy then inst:Destroy() end end) end

function TweenService.Create(_, obj, info, props)
	local tween = { PlaybackState = Enum.PlaybackState.Begin, Completed = Signal.new("Completed") }
	function tween.Play()
		for k, v in pairs(props) do obj[k] = v end
		tween.PlaybackState = Enum.PlaybackState.Playing
		task.delay(info.Time or 0, function() tween.PlaybackState = Enum.PlaybackState.Completed tween.Completed:Fire(Enum.PlaybackState.Completed) end)
	end
	function tween.Cancel() tween.PlaybackState = Enum.PlaybackState.Cancelled end
	function tween.Pause() end
	function tween.Destroy() end
	return tween
end
UserInputService._props.TouchEnabled = false
UserInputService._props.KeyboardEnabled = true
UserInputService._props.MouseEnabled = true
function UserInputService.GetLastInputType() return Enum.UserInputType.MouseButton1 end
function UserInputService.IsKeyDown() return false end
function GuiService.GetGuiInset() return Vector2.new(0, 58), Vector2.new() end
function ContextActionService.BindAction() end
function ContextActionService.UnbindAction() end
function CollectionService.GetTagged() return {} end
function CollectionService.AddTag() end
function CollectionService.HasTag() return false end
function CollectionService.GetInstanceAddedSignal() return Signal.new("tag") end
function CollectionService.GetInstanceRemovedSignal() return Signal.new("tag") end
function StarterGui.SetCoreGuiEnabled() end
function StarterGui.SetCore() end
function TextChatService.FindFirstChild() return nil end
function BadgeService.AwardBadge() return true end
function PhysicsService.RegisterCollisionGroup() end
function PhysicsService.CollisionGroupSetCollidable() end
Engine.mouse = { Hit = CFrame.new(0, 0, -50), Target = nil, X = 0, Y = 0, Move = Signal.new("Move"), Button1Down = Signal.new("B1D") }

---------------------------------------------------------------- module loading
Engine.moduleCache = {}
Engine.loading = {}
local baseEnvMT = { __index = _G }

local function loadChunkFor(inst)
	local path = rawget(inst, "_path")
	local f = assert(io.open(path, "r"))
	local src = f:read("a")
	f:close()
	local env = setmetatable({ script = inst }, baseEnvMT)
	local chunk, err = load(src, "=" .. path, "t", env)
	if not chunk then error("syntax error in " .. path .. ": " .. tostring(err)) end
	return chunk
end

local nativeRequire = require
function require(target)
	if type(target) == "string" then return nativeRequire(target) end
	if typeof(target) ~= "Instance" then error("require expects a ModuleScript instance, got " .. typeof(target), 2) end
	if target._class ~= "ModuleScript" then error("Attempted to call require with invalid argument(s): " .. target:GetFullName() .. " is a " .. target._class, 2) end
	local cached = Engine.moduleCache[target]
	if cached ~= nil then return cached end
	if Engine.loading[target] then error("Requested module was required recursively: " .. target:GetFullName(), 2) end
	Engine.loading[target] = true
	local chunk = loadChunkFor(target)
	local result = chunk()
	Engine.loading[target] = nil
	if result == nil then error("Module code did not return exactly one value: " .. target:GetFullName(), 2) end
	Engine.moduleCache[target] = result
	return result
end

function Engine.runScript(inst)
	local chunk = loadChunkFor(inst)
	return task.spawn(chunk)
end

-- Build Instances from a list of project-relative .lua paths (ENGINE_FILES, supplied by the
-- Python runner because io.popen is unavailable): *.lua -> ModuleScript / Script / LocalScript, dirs -> Folder
local function mountTree(files, root, prefix, parent, folderName)
	local folder = newInstance("Folder")
	folder._props.Name = folderName
	local subdirs, mods = {}, {}
	for _, f in ipairs(files) do
		if f:sub(1, #prefix + 1) == prefix .. "/" then
			local rest = f:sub(#prefix + 2)
			local first = rest:match("^([^/]+)/.+$")
			if first then
				subdirs[first] = true
			elseif rest:match("%.lua$") then
				table.insert(mods, rest)
			end
		end
	end
	table.sort(mods)
	for _, entry in ipairs(mods) do
		local class, name = "ModuleScript", entry:gsub("%.lua$", "")
		if name:match("%.server$") then class = "Script" name = name:gsub("%.server$", "")
		elseif name:match("%.client$") then class = "LocalScript" name = name:gsub("%.client$", "") end
		local inst = newInstance(class)
		inst._props.Name = name
		rawset(inst, "_path", root .. "/" .. prefix .. "/" .. entry)
		inst.Parent = folder
	end
	local names = {}
	for n in pairs(subdirs) do table.insert(names, n) end
	table.sort(names)
	for _, n in ipairs(names) do mountTree(files, root, prefix .. "/" .. n, folder, n) end
	folder.Parent = parent
	return folder
end

function Engine.mountProject(root, files)
	root = root or "."
	files = files or ENGINE_FILES
	assert(files, "Engine.mountProject needs the file list (ENGINE_FILES global from run_scenarios.py)")
	local list = {}
	for i = 1, #files do list[i] = files[i] end
	Engine.root = root
	mountTree(list, root, "src/shared", ReplicatedStorage, "Shared")
	local models = newInstance("Folder") models._props.Name = "Models" models.Parent = ReplicatedStorage
	for _, n in ipairs({ "Presents", "Boxes", "Traps" }) do local f = newInstance("Folder") f._props.Name = n f.Parent = models end
	mountTree(list, root, "src/server", ServerScriptService, "Server")
	mountTree(list, root, "src/client", SPS, "Client")
end

-- boot the server: runs ServerScriptService.Server.Main
function Engine.bootServer()
	local main = ServerScriptService:FindFirstChild("Server"):FindFirstChild("Main")
	Engine.runScript(main)
	Sched.advance(0.5)
end

-- boot the client for a player: Players.LocalPlayer + StarterPlayerScripts.Client.Main
function Engine.bootClient(player)
	Engine.clientPlayer = player
	Players._props.LocalPlayer = player
	RunService._props.IsServerFlag = false
	local main = SPS:FindFirstChild("Client"):FindFirstChild("Main")
	Engine.runScript(main)
	Sched.advance(1)
	RunService._props.IsServerFlag = true
end

-- test helpers
function Engine.trigger(prompt, player) Engine_getSignal(prompt, "Triggered"):Fire(player) Sched.advance(0.05) end
function Engine.touch(part, player)
	local char = player._props.Character
	Engine_getSignal(part, "Touched"):Fire(char:FindFirstChild("HumanoidRootPart"))
	Sched.advance(0.05)
end
function Engine.fireServer(remote, player, ...) Engine_getSignal(remote, "OnServerEvent"):Fire(player, ...) Sched.advance(0.05) end
function Engine.sentTo(player, remoteName)
	local out = {}
	for _, e in ipairs(Engine.remoteLog) do if e.player == player and e.name == remoteName then table.insert(out, e.args) end end
	return out
end
function Engine.lastSent(player, remoteName) local all = Engine.sentTo(player, remoteName) return all[#all] end
function Engine.clearLog() Engine.remoteLog = {} end
function Engine.unknownPropsReport()
	local keys = {}
	for k in pairs(Engine_unknownProps) do table.insert(keys, k) end
	table.sort(keys)
	return keys
end
function Engine.resetErrors() return Sched.clearErrors() end
