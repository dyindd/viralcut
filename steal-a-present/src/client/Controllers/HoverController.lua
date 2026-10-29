--[[ HoverController.lua - hover anything with a "Tooltip" attribute (pads, cannon, presents...) to see what it is ]]

local Players = game:GetService("Players")
local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)

local HoverController = {}
local player = Players.LocalPlayer

local function tooltipFor(inst)
	local node = inst
	for _ = 1, 6 do
		if not node or node == workspace then return nil end
		local t = node:GetAttribute("Tooltip")
		if t then return t end
		node = node.Parent
	end
	return nil
end

function HoverController.Start(HUD)
	local mouse = player:GetMouse()
	local tip = UIKit.Create("Frame", { Name = "WorldTooltip", Size = UDim2.new(0, 320, 0, 42), BackgroundColor3 = Theme.Colors.Outline, BackgroundTransparency = 0.1, Visible = false, ZIndex = 50, Parent = HUD.Gui })
	UIKit.Corner(tip, 10)
	UIKit.Stroke(tip, 2, Theme.Colors.Gold)
	local label = UIKit.Text({ Text = "", TextSize = 18, Scaled = true, MaxTextSize = 18, Wrapped = true, ZIndex = 51, Parent = tip })
	UIKit.Padding(tip, 6)
	HoverController.Tip = tip
	HoverController.Label = label
	task.spawn(function()
		while true do
			task.wait(0.1)
			pcall(function()
				local target = mouse.Target
				local text = target and tooltipFor(target)
				if text then
					label.Text = text
					tip.Position = UDim2.new(0, mouse.X + 18, 0, mouse.Y + 12)
					tip.Visible = true
				else
					tip.Visible = false
				end
			end)
		end
	end)
end

return HoverController
