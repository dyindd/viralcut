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
	local header = UIKit.Text({ Text = "Collected 0/0", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 0, 60), TextSize = 30, Color = Theme.Colors.Blue, StrokeThickness = 2.5, Parent = panel.Content })
	local scroll = UIKit.Scroll({ Layout = "List", Size = UDim2.new(1, 0, 1, -104), Position = UDim2.new(0, 0, 0, 102), Parent = panel.Content })
	local oddsScroll = UIKit.Scroll({ Layout = "List", Size = UDim2.new(1, 0, 1, -66), Position = UDim2.new(0, 0, 0, 64), Parent = panel.Content })
	oddsScroll.Visible = false

	local function currentLuck()
		local profile = State.Profile
		local luck = 1
		if profile and (profile.Boosts.LuckUntil or 0) > os.time() then luck = luck * Config.Luck.PotionMultiplier end
		if profile and profile.Gamepasses.VIP then luck = luck * Config.Luck.VIPMultiplier end
		if State.Event and State.Event.Active and State.Event.Active.Key == "LuckyHour" then luck = luck * Config.Events.LuckyHour.LuckMultiplier end
		return luck
	end

	local function renderOdds()
		for _, c in ipairs(oddsScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		local tiers = {}
		for k, v in pairs(Catalog.Rarities) do tiers[k] = v.Tier end
		local luck = currentLuck()
		for i, tier in ipairs(Config.BoxTiers) do
			local card = UIKit.Card({ Size = UDim2.new(1, -16, 0, 60 + 26 * 4), LayoutOrder = i, StrokeColor = tier.Color, Parent = oddsScroll })
			UIKit.Text({ Text = tier.Name .. (tier.Price > 0 and ("   $" .. Util.FormatNumber(tier.Price)) or "   FREE (events/rewards)") .. (tier.Strength > 0 and ("   needs " .. Util.FormatNumber(tier.Strength) .. " STR") or ""),
				Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0, 8, 0, 6), TextSize = 24, Scaled = true, MaxTextSize = 24, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.TextDark, Stroke = false, ZIndex = 14, Parent = card })
			local odds = Util.ApplyLuck(tier.Odds, luck, tiers)
			local total = 0
			for _, v in pairs(odds) do total = total + v end
			local y = 42
			local col = 0
			for _, rarityKey in ipairs(Catalog.RarityOrder) do
				local chance = odds[rarityKey]
				if chance then
					local r = Catalog.Rarities[rarityKey]
					local pct = chance / total * 100
					local text = pct >= 1 and string.format("%s %.1f%%", r.Name, pct) or string.format("%s %.3f%%", r.Name, pct)
					UIKit.Text({ Text = text, Size = UDim2.new(0.5, -12, 0, 24), Position = UDim2.new(col * 0.5, 8, 0, y), TextSize = 18, XAlign = Enum.TextXAlignment.Left, Color = r.Color, StrokeThickness = 1.5, ZIndex = 14, Parent = card })
					col = col + 1
					if col == 2 then col = 0 y = y + 26 end
				end
			end
		end
		UIKit.Text({ Text = luck > 1 and string.format("Your luck right now: x%.2f (applied above)", luck) or "Luck potions, VIP and Lucky Hour boost Rare+ odds.", Size = UDim2.new(1, -16, 0, 30), LayoutOrder = 99, TextSize = 18, Color = Theme.Colors.TextMuted, Stroke = false, Parent = oddsScroll })
	end

	local tabs = UIKit.Tabs(panel.Content, {
		{ Key = "Collection", Text = "📖 Collection", Color = Theme.Colors.Orange },
		{ Key = "Odds", Text = "🎲 Box Odds", Color = Theme.Colors.Blue },
	}, function(key)
		local odds = key == "Odds"
		scroll.Visible = not odds
		header.Visible = not odds
		oddsScroll.Visible = odds
		if odds then renderOdds() end
	end)

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
