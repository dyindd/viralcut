--[[ SettingsPanel.lua - music / sfx toggles + controls help ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local State = require(script.Parent.Parent.Parent.State)

local SettingsPanel = {}

function SettingsPanel.Create(HUD)
	local panel = UIKit.Panel({ Name = "Settings", Title = "Settings", Icon = "⚙️", Width = 620, Height = 440, Parent = HUD.Layers.Panels })
	local list = UIKit.Create("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = panel.Content })
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local toggles = {}
	local function toggleRow(key, label, order)
		local row = UIKit.Card({ Size = UDim2.new(1, -16, 0, 64), LayoutOrder = order, Parent = list })
		UIKit.Text({ Text = label, Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.new(0, 16, 0, 0), TextSize = 26, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.TextDark, Stroke = false, ZIndex = 14, Parent = row })
		local btn = UIKit.Button({ Text = "ON", Color = Theme.Colors.Green, Size = UDim2.new(0, 140, 0, 46), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), TextSize = 24, ZIndex = 14, Parent = row,
			OnClick = function()
				local profile = State.Profile
				if not profile then return end
				local value = not profile.Settings[key]
				profile.Settings[key] = value
				Remotes.Get("SetSetting"):FireServer(key, value)
				State.Fire("Settings", key, value)
				toggles[key](value)
			end })
		toggles[key] = function(value)
			btn.Text.Text = value and "ON" or "OFF"
			btn.BackgroundColor3 = value and Theme.Colors.Green or Theme.Colors.Red
		end
	end
	toggleRow("Music", "🎵 Music", 1)
	toggleRow("SFX", "🔊 Sound Effects", 2)
	local help = UIKit.Card({ Size = UDim2.new(1, -16, 0, 170), LayoutOrder = 3, Parent = list })
	UIKit.Text({ Text = "CONTROLS\nE / tap prompt = buy, pick up, steal, train\nQ = drop what you're carrying   ·   L = lock your base\nClick = swing your Candy Cane Bat (knocks thieves!)\nDuring Grinch Mode: equip the Snowball and click to throw",
		Size = UDim2.new(1, -20, 1, -10), Position = UDim2.new(0, 10, 0, 5), TextSize = 18, Wrapped = true, Color = Theme.Colors.TextDark, Stroke = false, ZIndex = 14, Parent = help })

	local function render()
		local profile = State.Profile
		if not profile then return end
		for key, fn in pairs(toggles) do fn(profile.Settings[key] ~= false) end
	end
	State.On("Profile", function() if panel.IsOpen then render() end end)
	panel.Root:GetPropertyChangedSignal("Visible"):Connect(function() if panel.Root.Visible then render() end end)
	HUD.RegisterPanel("Settings", panel)
	return panel
end

return SettingsPanel
