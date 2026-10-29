--[[
	GrinchOverlay.lua - the big green banner + screen vignette during Grinch Mode.
	If YOU are the Grinch, the screen tells you exactly what to do.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.Parent.State)

local GrinchOverlay = {}
local player = Players.LocalPlayer
local banner, bannerText, bannerSub, vignette, container

local GREEN = Color3.fromRGB(70, 220, 100)

function GrinchOverlay.Create(HUD)
	container = UIKit.Create("Frame", { Name = "GrinchOverlay", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 128), Size = UDim2.new(0, 800, 0, 120), BackgroundTransparency = 1, ZIndex = 40, Parent = HUD.Layers.Overlay })
	UIKit.Create("UIScale", { Scale = HUD.Scale or 1, Parent = container })
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() container.UIScale.Scale = HUD.Scale or 1 end)
	vignette = UIKit.Create("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = GREEN, BackgroundTransparency = 1, Visible = false, ZIndex = 39, Parent = HUD.Layers.Overlay })
	UIKit.Create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0.75) }), Rotation = 90, Parent = vignette })
	banner = UIKit.Create("Frame", { Size = UDim2.new(0, 700, 0, 100), Position = UDim2.new(0.5, 0, 0, 0), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = GREEN, Visible = false, ZIndex = 41, Parent = container })
	UIKit.Corner(banner, 18)
	UIKit.Stroke(banner, 4)
	UIKit.Gradient(banner, GREEN, UIKit.Darken(GREEN, 0.7), 90)
	bannerText = UIKit.Text({ Text = "", Size = UDim2.new(1, -20, 0, 48), Position = UDim2.new(0, 10, 0, 6), TextSize = 36, Scaled = true, MaxTextSize = 36, StrokeThickness = 3, ZIndex = 42, Parent = banner })
	bannerSub = UIKit.Text({ Text = "", Size = UDim2.new(1, -20, 0, 36), Position = UDim2.new(0, 10, 0, 56), TextSize = 24, Scaled = true, MaxTextSize = 24, ZIndex = 42, Parent = banner })

	task.spawn(function()
		while true do
			GrinchOverlay.Update()
			task.wait(0.2)
		end
	end)
	return GrinchOverlay
end

function GrinchOverlay.Update()
	local g = State.Grinch
	if not g then banner.Visible = false vignette.Visible = false return end
	if g.Active then
		local isMe = g.UserId == player.UserId
		banner.Visible = true
		vignette.Visible = isMe
		vignette.BackgroundTransparency = 0.3 + 0.2 * math.sin(os.clock() * 4)
		if isMe then
			bannerText.Text = "💚 YOU ARE THE GRINCH! 💚  " .. Util.FormatTime(State.Remaining(g.EndsAt))
			bannerSub.Text = "Steal from LOCKED bases! Survive to win. Hits taken: " .. g.Hits .. "/" .. g.HitsToDefeat
		else
			bannerText.Text = "💚 THE GRINCH: " .. tostring(g.Name) .. "  " .. Util.FormatTime(State.Remaining(g.EndsAt))
			bannerSub.Text = "Throw snowballs (equip from your hotbar)! Hits: " .. g.Hits .. "/" .. g.HitsToDefeat .. "  ·  Lock your base!"
		end
	elseif g.WarningUserId then
		banner.Visible = true
		vignette.Visible = false
		local isMe = g.WarningUserId == player.UserId
		bannerText.Text = (isMe and "⚠️ YOU are turning into the GRINCH in " or ("⚠️ " .. tostring(g.WarningName) .. " becomes the GRINCH in ")) .. Util.FormatTime(State.Remaining(g.WarningEndsAt))
		bannerSub.Text = isMe and "Get ready to raid every base!" or "LOCK YOUR BASE NOW!"
	else
		banner.Visible = false
		vignette.Visible = false
	end
end

return GrinchOverlay
