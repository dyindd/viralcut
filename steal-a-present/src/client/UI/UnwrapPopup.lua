--[[
	UnwrapPopup.lua - THE dopamine moment. A box was unwrapped at your base: dim the screen,
	bounce in a rarity-colored card with the present, stars, mutation, and $/s.
	Legendary+ gets a rainbow/glow treatment. Coal gets roasted. Results queue up.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local UnwrapPopup = {}
local queue = {}
local showing = false
local ui = {}

local function build(HUD)
	local dim = UIKit.Create("Frame", { Name = "UnwrapDim", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = HUD.Layers.Panels })
	local card = UIKit.Create("Frame", { Size = UDim2.new(0, 520, 0, 460), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Colors.Panel, ZIndex = 21, Parent = dim })
	UIKit.Corner(card, 24)
	local stroke = UIKit.Stroke(card, 5)
	local scale = UIKit.Create("UIScale", { Scale = 0.3, Parent = card })
	local header = UIKit.Create("Frame", { Size = UDim2.new(1, 0, 0, 90), BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 22, Parent = card })
	UIKit.Corner(header, 24)
	local headerGrad = UIKit.Gradient(header, Theme.Colors.Blue, Theme.Colors.BlueDark, 90)
	local headerText = UIKit.Text({ Text = "YOU UNWRAPPED", TextSize = 34, StrokeThickness = 3, ZIndex = 23, Parent = header })
	local icon = UIKit.Text({ Text = "🎁", Size = UDim2.new(1, 0, 0, 130), Position = UDim2.new(0, 0, 0, 100), TextSize = 110, Stroke = false, ZIndex = 22, Parent = card })
	local name = UIKit.Text({ Text = "", Size = UDim2.new(1, -30, 0, 50), Position = UDim2.new(0, 15, 0, 235), TextSize = 40, Scaled = true, MaxTextSize = 40, Color = Theme.Colors.TextDark, Stroke = false, ZIndex = 22, Parent = card })
	local rarity = UIKit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 0, 285), TextSize = 28, StrokeThickness = 2.5, ZIndex = 22, Parent = card })
	local value = UIKit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 0, 322), TextSize = 30, Color = Theme.Colors.Cash, ZIndex = 22, Parent = card })
	local button = UIKit.Button({ Text = "AWESOME!", Color = Theme.Colors.Green, Size = UDim2.new(0, 240, 0, 64), Position = UDim2.new(0.5, 0, 1, -22), AnchorPoint = Vector2.new(0.5, 1), TextSize = 30, ZIndex = 22, Parent = card })
	ui = { Dim = dim, Card = card, Stroke = stroke, Scale = scale, Header = header, HeaderGrad = headerGrad, HeaderText = headerText,
		Icon = icon, Name = name, Rarity = rarity, Value = value, Button = button }
	button.Activated:Connect(function() UnwrapPopup.Hide() end)
	dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			UnwrapPopup.Hide()
		end
	end)
end

local hideToken = 0

function UnwrapPopup.Hide()
	if not showing then return end
	showing = false
	hideToken = hideToken + 1
	UIKit.Tween(ui.Scale, { Scale = 0.2 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	UIKit.Tween(ui.Dim, { BackgroundTransparency = 1 }, 0.18, Enum.EasingStyle.Quad)
	task.delay(0.2, function()
		if not showing then
			ui.Dim.Visible = false
			local nextItem = table.remove(queue, 1)
			if nextItem then UnwrapPopup.Show(nextItem) end
		end
	end)
end

function UnwrapPopup.Show(item)
	if showing then
		table.insert(queue, item)
		return
	end
	showing = true
	local record, valuePerSec = item.Record, item.Value
	local info = Catalog.PresentByKey[record.Key] or { Name = record.Key, Icon = "🎁" }
	local r = Catalog.Rarities[record.Rarity] or Catalog.Rarities.Common
	local isCoal = record.Rarity == "Coal"
	local mutation = record.Mutation and Catalog.Mutations[record.Mutation]
	local old = ui.Header:FindFirstChildOfClass("UIGradient")
	if old then old:Destroy() end
	if r.Tier >= 7 or (mutation and mutation.Multiplier >= 6) then
		UIKit.Rainbow(ui.Header, 0.8)
	else
		UIKit.Gradient(ui.Header, r.Color, r.Color2, 90)
	end
	ui.Stroke.Color = r.Tier >= 6 and r.Color or Theme.Colors.Outline
	ui.HeaderText.Text = isCoal and "HO HO... NO." or (r.Tier >= 6 and ("✨ " .. r.Name:upper() .. "! ✨") or "YOU UNWRAPPED")
	ui.Icon.Text = info.Icon or "🎁"
	ui.Name.Text = (mutation and (mutation.Name .. " ") or "") .. info.Name
	ui.Rarity.Text = r.Name .. "  " .. UIKit.Stars(r.Stars)
	ui.Rarity.TextColor3 = r.Color
	if isCoal then
		ui.Value.Text = "Worth nothing. Also it exploded."
		ui.Value.TextColor3 = Theme.Colors.TextMuted
	else
		ui.Value.Text = "$" .. Util.FormatNumber(valuePerSec or 0) .. " / second" .. (mutation and ("   (x" .. mutation.Multiplier .. ")") or "")
		ui.Value.TextColor3 = Theme.Colors.Cash
	end
	ui.Dim.Visible = true
	ui.Dim.BackgroundTransparency = 1
	ui.Scale.Scale = 0.3
	UIKit.Tween(ui.Dim, { BackgroundTransparency = 0.45 }, 0.2, Enum.EasingStyle.Quad)
	UIKit.Tween(ui.Scale, { Scale = 1 }, 0.4)
	if r.Tier >= 6 then
		-- shake for the big ones
		task.spawn(function()
			for i = 1, 10 do
				ui.Card.Position = UDim2.new(0.5, math.random(-8, 8), 0.5, math.random(-8, 8))
				task.wait(0.04)
			end
			ui.Card.Position = UDim2.new(0.5, 0, 0.5, 0)
		end)
	end
	hideToken = hideToken + 1
	local token = hideToken
	task.delay(isCoal and 4 or 6, function()
		if showing and hideToken == token then UnwrapPopup.Hide() end
	end)
end

function UnwrapPopup.Create(HUD)
	build(HUD)
	Remotes.Get("UnwrapResult").OnClientEvent:Connect(function(record, valuePerSec, tierKey)
		UnwrapPopup.Show({ Record = record, Value = valuePerSec, Tier = tierKey })
	end)
	return UnwrapPopup
end

return UnwrapPopup
