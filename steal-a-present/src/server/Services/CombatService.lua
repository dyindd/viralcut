--[[
	CombatService.lua
	Everyone gets a Candy Cane Bat. Whack a thief and they DROP the present (it flies back
	to the owner's base). Snowballs (handed out during Grinch Mode) are thrown via the
	ThrowSnowball remote because only the client knows where the player is aiming.
	Nobody takes damage in this game - hits knock back and stun.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Parent.Registry)
local Validate = require(script.Parent.Parent.Validate)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

local CombatService = {}

local lastSwing = {}   -- [player] = os.clock()
local lastThrow = {}

local function Data() return Registry.Get("DataService") end
local function Notify() return Registry.Get("NotifyService") end

---------------------------------------------------------------------------
-- Tools (built in code so there is nothing to set up in Studio)
---------------------------------------------------------------------------
local function makeBat()
	local tool = Instance.new("Tool")
	tool.Name = Config.Combat.BatName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Whack thieves!"
	tool.TextureId = Icons.Get("Tools", "Bat") or ""
	tool.Grip = CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(90), 0, 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 4, 0.6)
	handle.Color = Color3.fromRGB(255, 255, 255)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	for i = 0, 3 do
		local stripe = Instance.new("Part")
		stripe.Name = "Stripe"
		stripe.Size = Vector3.new(0.62, 0.4, 0.62)
		stripe.Color = Color3.fromRGB(255, 50, 60)
		stripe.Material = Enum.Material.SmoothPlastic
		stripe.CanCollide = false
		stripe.Massless = true
		stripe.CFrame = handle.CFrame * CFrame.new(0, -1.5 + i * 1, 0)
		stripe.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = stripe
		weld.Parent = stripe
	end
	local hook = Instance.new("Part")
	hook.Name = "Hook"
	hook.Size = Vector3.new(0.6, 0.6, 1.4)
	hook.Color = Color3.fromRGB(255, 50, 60)
	hook.CanCollide = false
	hook.Massless = true
	hook.CFrame = handle.CFrame * CFrame.new(0, 2.1, 0.5)
	hook.Parent = tool
	local w2 = Instance.new("WeldConstraint")
	w2.Part0 = handle
	w2.Part1 = hook
	w2.Parent = hook
	return tool
end

local function makeSnowball()
	local tool = Instance.new("Tool")
	tool.Name = Config.Combat.SnowballName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Throw at the Grinch!"
	tool.TextureId = Icons.Get("Tools", "Snowball") or ""
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Ball
	handle.Size = Vector3.new(1.2, 1.2, 1.2)
	handle.Color = Color3.fromRGB(245, 250, 255)
	handle.Material = Enum.Material.Snow
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	return tool
end

function CombatService.GiveSnowball(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	if backpack:FindFirstChild(Config.Combat.SnowballName) then return end
	if player.Character and player.Character:FindFirstChild(Config.Combat.SnowballName) then return end
	makeSnowball().Parent = backpack
end

function CombatService.RemoveSnowball(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ backpack, player.Character }) do
		if container then
			local t = container:FindFirstChild(Config.Combat.SnowballName)
			if t then t:Destroy() end
		end
	end
end

---------------------------------------------------------------------------
-- Hits
---------------------------------------------------------------------------
-- Characters are simulated by their own client, so setting AssemblyLinearVelocity from the
-- server can be overwritten. A short-lived LinearVelocity constraint replicates and the owning
-- client applies it, so the launch always happens.
function CombatService.Impulse(root, velocity, duration)
	if not root or not root.Parent then return end
	local att = root:FindFirstChild("ImpulseAttachment")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "ImpulseAttachment"
		att.Parent = root
	end
	local old = root:FindFirstChild("Impulse")
	if old then old:Destroy() end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Impulse"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = velocity
	lv.MaxForce = math.huge
	lv.Parent = root
	Debris:AddItem(lv, duration or 0.15)
end

local function knockback(targetRoot, fromPosition, force)
	local dir = (targetRoot.Position - fromPosition)
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
	dir = dir.Unit
	CombatService.Impulse(targetRoot, dir * force + Vector3.new(0, force * 0.6, 0), 0.15)
end

local function stun(target, seconds)
	local Carry = Registry.Get("CarryService")
	Carry.SetSpeedModifier(target, "Stun", 0)
	task.delay(seconds, function()
		if target.Parent then
			Carry.SetSpeedModifier(target, "Stun", nil)
		end
	end)
end

-- A hit lands on `target` from `attacker`. source: "bat" | "snowball" | "trap"
function CombatService.Hit(attacker, target, source)
	if target == attacker then return end
	local targetRoot = Validate.GetRoot(target)
	if not targetRoot then return end
	local attackerRoot = attacker and Validate.GetRoot(attacker)
	local fromPos = attackerRoot and attackerRoot.Position or (targetRoot.Position - targetRoot.CFrame.LookVector)
	local Carry = Registry.Get("CarryService")
	local Grinch = Registry.Get("GrinchService")

	knockback(targetRoot, fromPos, Config.Combat.KnockbackForce)
	Notify().Effect("Hit", targetRoot.Position, nil)

	if Grinch.IsGrinch(target) and attacker then
		Grinch.RegisterHit(attacker, target, source)
		return
	end
	if Carry.IsCarrying(target) then
		local carry = Carry.Get(target)
		stun(target, Config.Steal.ThiefRagdollSeconds)
		Carry.Drop(target, "hit")
		if attacker then
			local profile = Data().GetProfile(attacker)
			if profile and carry.Kind == "Present" then
				profile.Stats.Hits = (profile.Stats.Hits or 0) + 1
				Registry.Get("QuestService").Progress(attacker, "Hit", 1)
				Notify().Notify(attacker, "You stopped " .. target.DisplayName .. "!", "success")
			end
		end
		Notify().Notify(target, "You got whacked and dropped it!", "error")
	end
end

local function onBatActivated(player, tool)
	local t = os.clock()
	if lastSwing[player] and t - lastSwing[player] < Config.Combat.BatCooldown then return end
	lastSwing[player] = t
	local root = Validate.GetRoot(player)
	if not root then return end
	Notify().Effect("Swing", root.Position, { UserId = player.UserId })
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local otherRoot = Validate.GetRoot(other)
			if otherRoot then
				local offset = otherRoot.Position - root.Position
				if offset.Magnitude <= Config.Combat.BatRange then
					local facing = root.CFrame.LookVector:Dot(offset.Unit)
					if facing > 0.1 then
						CombatService.Hit(player, other, "bat")
					end
				end
			end
		end
	end
end

local function onThrowSnowball(player, direction)
	if not RateLimiter.Check(player, "Throw") then return end
	if not Validate.IsVector3(direction) then return end
	local t = os.clock()
	if lastThrow[player] and t - lastThrow[player] < Config.Combat.SnowballCooldown then return end
	local char = player.Character
	local root = Validate.GetRoot(player)
	if not root or not char then return end
	local tool = char:FindFirstChild(Config.Combat.SnowballName)
	if not tool then return end -- must have the snowball equipped
	lastThrow[player] = t
	if direction.Magnitude < 0.01 then return end
	direction = direction.Unit

	local ball = Instance.new("Part")
	ball.Name = "SnowballProjectile"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1.2, 1.2, 1.2)
	ball.Color = Color3.fromRGB(245, 250, 255)
	ball.Material = Enum.Material.Snow
	ball.CanCollide = false
	ball.CFrame = CFrame.new(root.Position + direction * 2.5 + Vector3.new(0, 1.5, 0))
	ball.AssemblyLinearVelocity = direction * Config.Combat.SnowballSpeed + Vector3.new(0, 12, 0)
	ball:SetAttribute("Thrower", player.UserId)
	ball.Parent = Workspace
	ball:SetNetworkOwner(nil)
	Debris:AddItem(ball, Config.Combat.SnowballLifetime)
	local done = false
	ball.Touched:Connect(function(hit)
		if done then return end
		local hitChar = hit.Parent
		local target = hitChar and Players:GetPlayerFromCharacter(hitChar)
		if not target and hitChar and hitChar.Parent then
			target = Players:GetPlayerFromCharacter(hitChar.Parent)
		end
		if target == player then return end
		if hit.Name == "SnowballProjectile" or hit:IsDescendantOf(char) then return end
		done = true
		Notify().Effect("Splat", ball.Position, nil)
		ball:Destroy()
		if target then
			CombatService.Hit(player, target, "snowball")
		end
	end)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local function hookCharacter(player, char)
	local backpack = player:WaitForChild("Backpack", 5)
	if not backpack then return end
	if not backpack:FindFirstChild(Config.Combat.BatName) then
		local bat = makeBat()
		bat.Parent = backpack
		bat.Activated:Connect(function() onBatActivated(player, bat) end)
	end
end

function CombatService.Init()
	Remotes.Get("ThrowSnowball").OnServerEvent:Connect(onThrowSnowball)
end

function CombatService.Start()
	local function hook(player)
		player.CharacterAdded:Connect(function(char) hookCharacter(player, char) end)
		if player.Character then hookCharacter(player, player.Character) end
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do hook(player) end
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		lastThrow[player] = nil
	end)
end

return CombatService
