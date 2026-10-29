--[[ ShopPanel.lua - Gamepasses / Robux products / Snowflake shop ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local State = require(script.Parent.Parent.Parent.State)

local ShopPanel = {}

local function clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
	end
end

local function itemCard(parent, order, icon, name, desc, priceText, color, enabled, onClick, owned)
	local card = UIKit.Card({ Size = UDim2.new(0, 240, 0, 210), LayoutOrder = order, Parent = parent })
	UIKit.Text({ Text = icon, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0, 6), TextSize = 48, Stroke = false, ZIndex = 14, Parent = card })
	UIKit.Text({ Text = name, Size = UDim2.new(1, -12, 0, 30), Position = UDim2.new(0, 6, 0, 66), TextSize = 24, Scaled = true, MaxTextSize = 24, Color = Theme.Colors.TextDark, Stroke = false, ZIndex = 14, Parent = card })
	UIKit.Text({ Text = desc, Size = UDim2.new(1, -16, 0, 50), Position = UDim2.new(0, 8, 0, 96), TextSize = 16, Scaled = true, MaxTextSize = 16, Wrapped = true, Color = Theme.Colors.TextMuted, Stroke = false, ZIndex = 14, Parent = card })
	local btn = UIKit.Button({ Text = owned and "OWNED ✓" or priceText, Color = owned and Theme.Colors.Grey or color, Size = UDim2.new(1, -24, 0, 46), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), TextSize = 22, ZIndex = 14, Parent = card, OnClick = onClick })
	if not enabled and not owned then UIKit.SetButtonEnabled(btn, false, "Not set up") end
	return card
end

function ShopPanel.Create(HUD)
	local panel = UIKit.Panel({ Name = "Shop", Title = "Shop!", Icon = "🛒", Parent = HUD.Layers.Panels })
	local grid = UIKit.Scroll({ Layout = "Grid", CellSize = UDim2.new(0, 240, 0, 210), Size = UDim2.new(1, 0, 1, -70), Position = UDim2.new(0, 0, 0, 66), Parent = panel.Content })

	local function render(tab)
		clear(grid)
		local profile = State.Profile
		local order = 0
		if tab == "Passes" then
			local keys = { "VIP", "ExtraSlots", "Speed", "AutoCollect", "Strong" }
			local icons = { VIP = "👑", ExtraSlots = "📦", Speed = "⚡", AutoCollect = "🧲", Strong = "💪" }
			for _, key in ipairs(keys) do
				local pass = Config.Monetization.Gamepasses[key]
				order = order + 1
				itemCard(grid, order, icons[key] or "⭐", pass.Name, pass.Description, "R$ " .. pass.Price, Theme.Colors.Green, pass.Id > 0,
					function() Remotes.Get("PromptPurchase"):FireServer("Gamepass", key) end, profile and profile.Gamepasses[key])
			end
		elseif tab == "Products" then
			local keys = { "Cash1", "Cash2", "Cash3", "Snowflakes1", "LuckPotion", "Protein", "LockExtend", "GrinchTurn" }
			local icons = { Cash1 = "💵", Cash2 = "💰", Cash3 = "🏦", Snowflakes1 = "❄️", LuckPotion = "🍀", Protein = "🥤", LockExtend = "🔒", GrinchTurn = "💚" }
			local descs = { LuckPotion = "2x luck on every unwrap for 30 minutes.", Protein = "Train 2x faster for 15 minutes.", LockExtend = "Your next base lock lasts 5 extra minutes.", GrinchTurn = "Become the Grinch right now (or next in line)." }
			for _, key in ipairs(keys) do
				local product = Config.Monetization.Products[key]
				order = order + 1
				itemCard(grid, order, icons[key] or "⭐", product.Name, descs[key] or "Instant delivery!", "R$ " .. product.Price, Theme.Colors.Blue, product.Id > 0,
					function() Remotes.Get("PromptPurchase"):FireServer("Product", key) end, false)
			end
		else
			for _, item in ipairs(Catalog.SnowflakeShop) do
				order = order + 1
				local desc = item.Give.Box and "A free box delivered to your base." or item.Give.Luck and "2x luck for 30 minutes." or "One more present slot, forever."
				itemCard(grid, order, item.Give.Box and "🎁" or item.Give.Luck and "🍀" or "➕", item.Name, desc, "❄️ " .. item.Cost, Theme.Colors.Cyan, true,
					function() Remotes.Get("BuySnowflakeItem"):FireServer(item.Key) end, false)
			end
		end
	end

	local tabs = UIKit.Tabs(panel.Content, {
		{ Key = "Passes", Text = "Gamepasses", Color = Theme.Colors.Green },
		{ Key = "Products", Text = "Boosts", Color = Theme.Colors.Blue },
		{ Key = "Snow", Text = "❄️ Snowflakes", Color = Theme.Colors.Cyan },
	}, render)

	panel.SetData = function(data)
		if data and data.Tab then tabs.Select(data.Tab) end
	end
	State.On("Profile", function() if panel.IsOpen then render(tabs.Current()) end end)
	HUD.RegisterPanel("Shop", panel)
	return panel
end

return ShopPanel
