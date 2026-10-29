--[[
	Toasts.lua - server announcements (big colored banners) and personal notifications
	(small pills). Both stack under the top timers and slide away on their own.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local Toasts = {}
local KIND_COLORS = {
	info = Theme.Colors.Blue, success = Theme.Colors.Green, error = Theme.Colors.Red, rare = Theme.Colors.Purple,
	grinch = Color3.fromRGB(70, 220, 100), warning = Theme.Colors.Yellow, event = Theme.Colors.Cyan, steal = Theme.Colors.Orange, rebirth = Theme.Colors.Pink,
}

local container

local function push(text, color, big, duration)
	local height = big and 58 or 42
	local toast = UIKit.Create("Frame", {
		Size = UDim2.new(0, big and 760 or 520, 0, height), BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0, ZIndex = 31, LayoutOrder = -math.floor(os.clock() * 1000), Parent = container,
	})
	UIKit.Corner(toast, 14)
	UIKit.Stroke(toast, Theme.Stroke)
	UIKit.Gradient(toast, color or Theme.Colors.Blue, UIKit.Darken(color or Theme.Colors.Blue, 0.72), 90)
	local scale = UIKit.Create("UIScale", { Scale = 0.5, Parent = toast })
	UIKit.Text({ Text = text, TextSize = big and 28 or 22, Scaled = true, MaxTextSize = big and 28 or 22, StrokeThickness = big and 3 or 2, ZIndex = 32, Parent = toast })
	UIKit.Padding(toast, 8)
	UIKit.Tween(scale, { Scale = 1 }, 0.3)
	task.delay(duration or (big and 6 or 3.5), function()
		UIKit.Tween(scale, { Scale = 0.2 }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.25)
		toast:Destroy()
	end)
	-- keep the stack short
	local children = container:GetChildren()
	local count = 0
	for _, c in ipairs(children) do if c:IsA("Frame") then count = count + 1 end end
	if count > 5 then
		for _, c in ipairs(children) do
			if c:IsA("Frame") then c:Destroy() break end
		end
	end
end

function Toasts.Announce(text, color, kind)
	push(text, color or KIND_COLORS[kind] or Theme.Colors.Blue, true)
end

function Toasts.Notify(text, kind)
	push(text, KIND_COLORS[kind] or Theme.Colors.Blue, false)
end

function Toasts.Create(HUD)
	container = UIKit.Create("Frame", {
		Name = "Toasts", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.new(0, 800, 0, 400),
		BackgroundTransparency = 1, ZIndex = 30, Parent = HUD.Layers.Toasts,
	})
	UIKit.Create("UIScale", { Scale = HUD.Scale or 1, Parent = container })
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = container })
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		container.UIScale.Scale = HUD.Scale or 1
	end)
	Remotes.Get("Announce").OnClientEvent:Connect(Toasts.Announce)
	Remotes.Get("Notify").OnClientEvent:Connect(Toasts.Notify)
	return Toasts
end

return Toasts
