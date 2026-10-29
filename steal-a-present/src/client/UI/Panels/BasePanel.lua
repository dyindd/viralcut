--[[ BasePanel.lua - "My Presents": everything at your base, with a 2-step Sell button ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local State = require(script.Parent.Parent.Parent.State)

local BasePanel = {}

local function baseValue(record)
	local info = Catalog.PresentByKey[record.Key]
	if not info then return 0 end
	local v = info.Income
	local m = record.Mutation and Catalog.Mutations[record.Mutation]
	if m then v = v * m.Multiplier end
	local bonus = 0
	for k in pairs(record.Traits or {}) do
		local t = Catalog.Traits[k]
		if t then bonus = bonus + t.Bonus end
	end
	return v * (1 + bonus)
end

function BasePanel.Create(HUD)
	local panel = UIKit.Panel({ Name = "Base", Title = "My Presents", Icon = "📦", Parent = HUD.Layers.Panels })
	local header = UIKit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 34), TextSize = 26, Color = Theme.Colors.Blue, StrokeThickness = 2.5, Parent = panel.Content })
	local list = UIKit.Scroll({ Layout = "List", Size = UDim2.new(1, 0, 1, -42), Position = UDim2.new(0, 0, 0, 40), Parent = panel.Content })

	local function render()
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		local profile = State.Profile
		if not profile then return end
		local mult = 1 + profile.Rebirths * Config.Rebirth.IncomeBonusPerRebirth
		if profile.Gamepasses.VIP then mult = mult * Config.Monetization.VIPCashMultiplier end
		local base = State.Base
		header.Text = string.format("%d / %d slots used   ·   $%s/s total", #profile.Presents, base and base.Slots or 0, Util.FormatNumber(base and base.Income or 0))
		local sorted = {}
		for _, r in ipairs(profile.Presents) do table.insert(sorted, r) end
		table.sort(sorted, function(a, b) return baseValue(a) > baseValue(b) end)
		for i, record in ipairs(sorted) do
			local info = Catalog.PresentByKey[record.Key] or { Name = record.Key, Icon = "🎁" }
			local r = Catalog.Rarities[record.Rarity] or Catalog.Rarities.Common
			local card = UIKit.Card({ Size = UDim2.new(1, -16, 0, 80), LayoutOrder = i, StrokeColor = r.Color, Parent = list })
			UIKit.Text({ Text = info.Icon, Size = UDim2.new(0, 60, 1, 0), Position = UDim2.new(0, 8, 0, 0), TextSize = 40, Stroke = false, ZIndex = 14, Parent = card })
			local traits = ""
			for k in pairs(record.Traits or {}) do
				local t = Catalog.Traits[k]
				if t then traits = traits .. " " .. t.Icon end
			end
			UIKit.Text({ Text = (record.Mutation and (record.Mutation .. " ") or "") .. info.Name .. traits, Size = UDim2.new(0.5, 0, 0, 34), Position = UDim2.new(0, 72, 0, 8), TextSize = 24, Scaled = true, MaxTextSize = 24, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.TextDark, Stroke = false, ZIndex = 14, Parent = card })
			UIKit.Text({ Text = r.Name .. " " .. UIKit.Stars(r.Stars) .. "   $" .. Util.FormatNumber(baseValue(record) * mult) .. "/s   (slot " .. tostring(record.Slot) .. ")", Size = UDim2.new(0.6, 0, 0, 24), Position = UDim2.new(0, 72, 0, 44), TextSize = 18, XAlign = Enum.TextXAlignment.Left, Color = r.Color2, Stroke = false, ZIndex = 14, Parent = card })
			local sellValue = math.max(10, math.floor(baseValue(record) * mult * Config.SellSeconds))
			local armed = false
			local btn
			btn = UIKit.Button({ Text = "Sell $" .. Util.FormatNumber(sellValue), Color = Theme.Colors.Orange, Size = UDim2.new(0, 190, 0, 52), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), TextSize = 22, ZIndex = 14, Parent = card,
				OnClick = function()
					if not armed then
						armed = true
						btn.Text.Text = "Confirm?"
						btn.BackgroundColor3 = Theme.Colors.Red
						task.delay(3, function() if armed and btn.Parent then armed = false btn.Text.Text = "Sell $" .. Util.FormatNumber(sellValue) btn.BackgroundColor3 = Theme.Colors.Orange end end)
					else
						Remotes.Get("SellPresent"):FireServer(record.Id)
					end
				end })
		end
		if #sorted == 0 then
			UIKit.Text({ Text = "No presents yet! Buy a box from the conveyor and bring it to the green pad at your base.", Size = UDim2.new(1, -16, 0, 80), TextSize = 22, Wrapped = true, Color = Theme.Colors.TextMuted, Stroke = false, Parent = list })
		end
	end

	State.On("Profile", function() if panel.IsOpen then render() end end)
	State.On("Base", function() if panel.IsOpen then render() end end)
	panel.Root:GetPropertyChangedSignal("Visible"):Connect(function() if panel.Root.Visible then render() end end)
	HUD.RegisterPanel("Base", panel)
	return panel
end

return BasePanel
