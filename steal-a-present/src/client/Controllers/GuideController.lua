--[[
	GuideController.lua - the on-screen guide arrow for the tutorial objective.
	Points at: the nearest belt box (Buy), your green pad (Unwrap), gold pad (Collect), lock button,
	bench, or another base's present (Steal). Clamps to the screen edge when the target is off-screen.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local State = require(script.Parent.Parent.State)

local GuideController = {}
local player = Players.LocalPlayer

local STEP_TEXT = {
	Buy = "Buy a box", Unwrap = "Your green pad", Collect = "Your gold pad", Lock = "Lock button", Train = "Your bench", Steal = "Steal from here",
}

local function myPlot()
	local base = State.Base
	local plots = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Plots")
	if not base or not plots then return nil end
	return plots:FindFirstChild("Plot" .. tostring(base.PlotIndex))
end

local function nearestBeltBox(from)
	local folder = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("BeltBoxes")
	if not folder then return nil end
	local best, bestDist
	for _, box in ipairs(folder:GetChildren()) do
		local pp = box.PrimaryPart
		if pp then
			local d = (pp.Position - from).Magnitude
			if not bestDist or d < bestDist then best, bestDist = pp.Position, d end
		end
	end
	if best then return best end
	local conveyor = workspace.World.Hub:FindFirstChild("Conveyor")
	return conveyor and conveyor.PrimaryPart and conveyor.PrimaryPart.Position or nil
end

local function stealTarget()
	local plots = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Plots")
	local base = State.Base
	if not plots then return nil end
	for _, plot in ipairs(plots:GetChildren()) do
		local owner = plot:GetAttribute("Owner") or 0
		if owner ~= 0 and owner ~= player.UserId then
			local presents = plot:FindFirstChild("Presents")
			local first = presents and presents:GetChildren()[1]
			if first and first.PrimaryPart then return first.PrimaryPart.Position end
		end
	end
	return nil
end

-- Returns the world position to point at and the label text, or nil to hide
function GuideController.CurrentTarget()
	local profile = State.Profile
	if not Config.Tutorial.Enabled or not profile or not profile.Tutorial or profile.Tutorial.Finished then return nil end
	local step
	for _, s in ipairs(Config.Tutorial.Steps) do
		if not profile.Tutorial.Completed[s.Key] then step = s break end
	end
	if not step then return nil end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local plot = myPlot()
	local key = step.Key
	if key == "Buy" then
		if State.Carry then return plot and plot.DepositPad.Position, STEP_TEXT.Unwrap end
		return nearestBeltBox(root.Position), STEP_TEXT.Buy
	elseif key == "Unwrap" then
		if not State.Carry then return nearestBeltBox(root.Position), STEP_TEXT.Buy end
		return plot and plot.DepositPad.Position, STEP_TEXT.Unwrap
	elseif key == "Collect" then
		return plot and plot.CollectPad.Position, STEP_TEXT.Collect
	elseif key == "Lock" then
		return plot and plot.LockButton.Position, STEP_TEXT.Lock
	elseif key == "Train" then
		return plot and plot.Bench.Position, STEP_TEXT.Train
	elseif key == "Steal" then
		if State.Carry then return plot and plot.DepositPad.Position, STEP_TEXT.Unwrap end
		return stealTarget(), STEP_TEXT.Steal
	end
	return nil
end

function GuideController.Start(HUD)
	local marker = UIKit.Create("Frame", { Name = "GuideMarker", Size = UDim2.new(0, 160, 0, 70), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 6, Parent = HUD.Gui })
	local arrow = UIKit.Text({ Text = "⬇", Size = UDim2.new(1, 0, 0, 44), TextSize = 40, Color = Theme.Colors.Yellow, StrokeThickness = 3, ZIndex = 6, Parent = marker })
	local label = UIKit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 44), TextSize = 18, Scaled = true, MaxTextSize = 18, ZIndex = 6, Parent = marker })
	GuideController.Marker = marker
	GuideController.Label = label

	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(function()
				local target, text = GuideController.CurrentTarget()
				local cam = workspace.CurrentCamera
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if not target or not cam or not root then
					marker.Visible = false
					return
				end
				local dist = (target - root.Position).Magnitude
				local pos, onScreen = cam:WorldToViewportPoint(target)
				local vp = cam.ViewportSize
				if onScreen and dist > 6 then
					marker.Position = UDim2.new(0, pos.X, 0, pos.Y - 50)
					arrow.Rotation = 0
				elseif onScreen then
					marker.Position = UDim2.new(0, pos.X, 0, pos.Y - 50)
					arrow.Rotation = 0
				else
					local dir = Vector2.new(pos.X - vp.X / 2, pos.Y - vp.Y / 2)
					if pos.Z < 0 then dir = -dir end
					if dir.Magnitude < 1 then dir = Vector2.new(0, -1) end
					dir = dir.Unit
					local radius = math.min(vp.X, vp.Y) / 2 - 90
					marker.Position = UDim2.new(0, vp.X / 2 + dir.X * radius, 0, vp.Y / 2 + dir.Y * radius)
					arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) - 90
				end
				label.Text = string.format("%s  %dm", text, math.floor(dist))
				marker.Visible = true
			end)
			if not ok then warn("[Guide] " .. tostring(err)) end
		end
	end)
end

return GuideController
