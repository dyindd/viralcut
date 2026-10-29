--[[ TrainingController.lua - big LIFT button while training (click anywhere / tap / F also lifts) ]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local TrainingController = {}
local player = Players.LocalPlayer

function TrainingController.IsTraining()
	local char = player.Character
	return char ~= nil and char:GetAttribute("Training") == true
end

function TrainingController.Lift()
	Remotes.Get("Lift"):FireServer()
	if TrainingController.Button then UIKit.Pop(TrainingController.Button, 1.12) end
end

function TrainingController.Start(HUD)
	local holder = UIKit.Create("Frame", { Name = "LiftHolder", Size = UDim2.new(0, 260, 0, 86), Position = UDim2.new(0.5, 0, 1, -250), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = HUD.Gui })
	local button = UIKit.Button({ Text = "LIFT!", Icon = "💪", Color = Theme.Colors.Orange, Size = UDim2.new(1, 0, 1, 0), TextSize = 40, ZIndex = 21, Parent = holder, OnClick = function() TrainingController.Lift() end })
	UIKit.Shine(button, 1.5)
	UIKit.Text({ Text = "Click / tap / press F to lift", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, 4), TextSize = 18, ZIndex = 21, Parent = holder })
	TrainingController.Holder = holder
	TrainingController.Button = button
	UserInputService.InputBegan:Connect(function(input, processed)
		if not TrainingController.IsTraining() then return end
		if input.KeyCode == Enum.KeyCode.F then TrainingController.Lift() return end
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then TrainingController.Lift() end
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			holder.Visible = TrainingController.IsTraining()
		end
	end)
end

return TrainingController
