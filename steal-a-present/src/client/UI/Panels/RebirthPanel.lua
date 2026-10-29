--[[ RebirthPanel.lua ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local State = require(script.Parent.Parent.Parent.State)

local RebirthPanel = {}

function RebirthPanel.Create(HUD)
	local panel = UIKit.Panel({ Name = "Rebirth", Title = "Rebirth!", Icon = "🔄", Width = 640, Height = 460, Parent = HUD.Layers.Panels })
	local big = UIKit.Text({ Text = "x1.0 ➜ x1.5 income", Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0, 10), TextSize = 44, Color = Theme.Colors.Purple, StrokeThickness = 3, Parent = panel.Content })
	local cost = UIKit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 72), TextSize = 30, Color = Theme.Colors.TextDark, Stroke = false, Parent = panel.Content })
	local info = UIKit.Text({
		Text = "You LOSE: all cash and all presents at your base.\nYou KEEP: Strength, Index, Snowflakes, traps, gamepasses.\nYou GAIN: permanent income multiplier, +1 base slot, " .. Config.Rebirth.SnowflakesReward .. " Snowflakes.",
		Size = UDim2.new(1, -20, 0, 150), Position = UDim2.new(0, 10, 0, 120), TextSize = 20, Wrapped = true, Color = Theme.Colors.TextMuted, Stroke = false, Parent = panel.Content,
	})
	local btn = UIKit.Button({ Text = "REBIRTH!", Color = Theme.Colors.Purple, Size = UDim2.new(0, 300, 0, 70), Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 1), TextSize = 34, Parent = panel.Content,
		OnClick = function() Remotes.Get("Rebirth"):FireServer() end })

	local function render()
		local profile = State.Profile
		if not profile then return end
		local n = profile.Rebirths
		local price = math.floor(Config.Rebirth.BaseCost * (Config.Rebirth.CostMultiplier ^ n))
		big.Text = string.format("x%.1f  ➜  x%.1f income", 1 + n * Config.Rebirth.IncomeBonusPerRebirth, 1 + (n + 1) * Config.Rebirth.IncomeBonusPerRebirth)
		cost.Text = "Cost: $" .. Util.Commas(price) .. "   (you have $" .. Util.FormatNumber(profile.Cash) .. ")"
		UIKit.SetButtonEnabled(btn, profile.Cash >= price, "Need $" .. Util.FormatNumber(price))
		if profile.Cash >= price then UIKit.SetButtonText(btn, "REBIRTH!") end
	end
	State.On("Profile", function() if panel.IsOpen then render() end end)
	panel.Root:GetPropertyChangedSignal("Visible"):Connect(function() if panel.Root.Visible then render() end end)
	HUD.RegisterPanel("Rebirth", panel)
	return panel
end

return RebirthPanel
