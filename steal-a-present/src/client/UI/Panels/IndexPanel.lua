--[[ IndexPanel.lua - the collection book, grouped by rarity ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Util = require(ReplicatedStorage.Shared.Util)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local State = require(script.Parent.Parent.Parent.State)

local IndexPanel = {}

function IndexPanel.Create(HUD)
	local panel = UIKit.Panel({ Name = "Index", Title = "Present Index", Icon = "📖", Parent = HUD.Layers.Panels })
	local header = UIKit.Text({ Text = "Collected 0/0", Size = UDim2.new(1, 0, 0, 36), TextSize = 30, Color = Theme.Colors.Blue, StrokeThickness = 2.5, Parent = panel.Content })
	local scroll = UIKit.Scroll({ Layout = "List", Size = UDim2.new(1, 0, 1, -44), Position = UDim2.new(0, 0, 0, 42), Parent = panel.Content })

	local function render()
		for _, c in ipairs(scroll:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		local profile = State.Profile
		local index = profile and profile.Index or {}
		local total, have = 0, 0
		local order = 0
		for _, rarityKey in ipairs(Catalog.RarityOrder) do
			local list = Catalog.PresentsByRarity[rarityKey]
			if #list > 0 then
				local r = Catalog.Rarities[rarityKey]
				order = order + 1
				local section = UIKit.Create("Frame", { Size = UDim2.new(1, -16, 0, 46 + 150 * math.ceil(#list / 5)), BackgroundTransparency = 1, LayoutOrder = order, Parent = scroll })
				local got = 0
				for _, p in ipairs(list) do if index[p.Key] then got = got + 1 end end
				total = total + #list
				have = have + got
				local reward = Config.Index.SetRewards[rarityKey]
				local claimed = profile and profile.IndexSetsClaimed and profile.IndexSetsClaimed[rarityKey]
				UIKit.Text({ Text = r.Name .. "  " .. UIKit.Stars(r.Stars) .. "   " .. got .. "/" .. #list .. (reward and ("   Set reward: $" .. Util.FormatNumber(reward) .. (claimed and " ✅" or "")) or ""),
					Size = UDim2.new(1, 0, 0, 40), TextSize = 26, XAlign = Enum.TextXAlignment.Left, Color = r.Color, StrokeThickness = 2.5, Parent = section })
				local grid = UIKit.Create("Frame", { Size = UDim2.new(1, 0, 1, -44), Position = UDim2.new(0, 0, 0, 44), BackgroundTransparency = 1, Parent = section })
				UIKit.Create("UIGridLayout", { CellSize = UDim2.new(0, 140, 0, 140), CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
				for i, p in ipairs(list) do
					local unlocked = index[p.Key] == true
					local card = UIKit.Card({ Size = UDim2.new(0, 140, 0, 140), LayoutOrder = i, Color = unlocked and Theme.Colors.Panel or Theme.Colors.Grey, StrokeColor = unlocked and r.Color or Theme.Colors.GreyDark, Parent = grid })
					UIKit.Text({ Text = unlocked and p.Icon or "❔", Size = UDim2.new(1, 0, 0, 70), Position = UDim2.new(0, 0, 0, 6), TextSize = 54, Stroke = false, ZIndex = 14, Parent = card })
					UIKit.Text({ Text = unlocked and p.Name or "???", Size = UDim2.new(1, -8, 0, 30), Position = UDim2.new(0, 4, 0, 78), TextSize = 18, Scaled = true, MaxTextSize = 18, Color = Theme.Colors.TextDark, Stroke = false, ZIndex = 14, Parent = card })
					UIKit.Text({ Text = unlocked and ("$" .. Util.FormatNumber(p.Income) .. "/s") or "", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 108), TextSize = 16, Color = Theme.Colors.GreenDark, Stroke = false, ZIndex = 14, Parent = card })
				end
			end
		end
		header.Text = "Collected " .. have .. "/" .. total
	end

	panel.Root:GetPropertyChangedSignal("Visible"):Connect(function() if panel.Root.Visible then render() end end)
	State.On("Profile", function() if panel.IsOpen then render() end end)
	HUD.RegisterPanel("Index", panel)
	return panel
end

return IndexPanel
