--[[
	InputController.lua - keybinds (Q drop, L lock, Escape close panels) and the snowball
	throw: only the client knows where the player is aiming, so Tool.Activated -> ThrowSnowball(dir).
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local InputController = {}
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local function hookTool(tool)
	if tool.Name ~= Config.Combat.SnowballName then return end
	if tool:GetAttribute("Hooked") then return end
	tool:SetAttribute("Hooked", true)
	tool.Activated:Connect(function()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local target = mouse.Hit and mouse.Hit.Position or (root.Position + root.CFrame.LookVector * 50)
		local dir = (target - root.Position)
		if dir.Magnitude < 1 then dir = root.CFrame.LookVector end
		Remotes.Get("ThrowSnowball"):FireServer(dir.Unit)
	end)
end

local function hookCharacter(char)
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") then hookTool(c) end
	end
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then hookTool(c) end
	end)
end

function InputController.Start(HUD)
	if player.Character then hookCharacter(player.Character) end
	player.CharacterAdded:Connect(hookCharacter)
	-- tools in the backpack get hooked when equipped (they move into the character)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.Q then
			Remotes.Get("DropCarry"):FireServer()
		elseif input.KeyCode == Enum.KeyCode.L then
			Remotes.Get("LockBase"):FireServer()
		elseif input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			HUD.CloseAll()
		end
	end)
end

return InputController
