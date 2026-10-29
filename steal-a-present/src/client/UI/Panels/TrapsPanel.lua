--[[ TrapsPanel.lua - choose a socket, buy a trap for it ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local State = require(script.Parent.Parent.Parent.State)

local TrapsPanel = {}

function TrapsPanel.Create(HUD)
	local panel = UIKit.Panel({ Name = "Traps", Title = "Base Defense", Icon = "🛡️", Parent = HUD.Layers.Panels })
	UIKit.Text({ Text = "Traps only hit OTHER players. Pick a socket, then a trap.", Size = UDim2.new(1, 0, 0, 26), TextSize = 18, Color = Theme.Colors.TextMuted, Stroke = false, Parent = panel.Content })
	local socketBar = UIKit.Create("Frame", { Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0, 30), BackgroundTransparency = 1, Parent = panel.Content })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = socketBar })
	local grid = UIKit.Scroll({ Layout = "Grid", CellSize = UDim2.new(0, 250, 0, 230), Size = UDim2.new(1, 0, 1, -100), Position = UDim2.new(0, 0, 0, 96), Parent = panel.Content })

	local selectedSocket = 1
	local socketButtons = {}

	local function render()
		local profile = State.Profile
		local traps = profile and profile.Traps or {}
		for i, b in ipairs(socketButtons) do
			local current = traps[tostring(i)]
			local def
			for _, d in ipairs(Config.Traps.List) do if d.Key == current then def = d end end
			UIKit.SetButtonText(b, "Socket " .. i .. ": " .. (def and def.Name or "Empty"))
			UIKit.SetButtonColor(b, i == selectedSocket and Theme.Colors.Green or Theme.Colors.Blue)
		end
		for _, c in ipairs(grid:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		for i, def in ipairs(Config.Traps.List) do
			local card = UIKit.Card({ Size = UDim2.new(0, 250, 0, 230), LayoutOrder = i, StrokeColor = def.Color, Parent = grid })
			UIKit.Icon({ Category = "Traps", Key = def.Key, Fallback = def.Key == "IcePatch" and "🧊" or def.Key == "Mistletoe" and "🌿" or "🧝", Size = UDim2.new(0, 66, 0, 66), Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), TextSize = 54, ZIndex = 14, Parent = card })
			UIKit.Text({ Text = def.Name, Size = UDim2.new(1, -10, 0, 32), Position = UDim2.new(0, 5, 0, 76), TextSize = 24, Scaled = true, MaxTextSize = 24, Color = Theme.Colors.TextDark, Stroke = false, ZIndex = 14, Parent = card })
			UIKit.Text({ Text = def.Description, Size = UDim2.new(1, -16, 0, 50), Position = UDim2.new(0, 8, 0, 108), TextSize = 16, Scaled = true, MaxTextSize = 16, Wrapped = true, Color = Theme.Colors.TextMuted, Stroke = false, ZIndex = 14, Parent = card })
			local placed = traps[tostring(selectedSocket)] == def.Key
			local btn = UIKit.Button({ Text = placed and "PLACED ✓" or ("$" .. Util.FormatNumber(def.Price)), Color = placed and Theme.Colors.Grey or Theme.Colors.Green, Size = UDim2.new(1, -24, 0, 48), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), TextSize = 24, ZIndex = 14, Parent = card,
				OnClick = function() if not placed then Remotes.Get("BuyTrap"):FireServer(def.Key, selectedSocket) end end })
			if placed then UIKit.SetButtonEnabled(btn, false, "PLACED ✓") end
		end
	end

	for i = 1, Config.Traps.Sockets do
		socketButtons[i] = UIKit.Button({ Text = "Socket " .. i, Color = Theme.Colors.Blue, Size = UDim2.new(0, 240, 0, 50), TextSize = 20, LayoutOrder = i, Parent = socketBar,
			OnClick = function() selectedSocket = i render() end })
	end

	panel.SetData = function(data)
		if data and data.Socket then selectedSocket = data.Socket end
	end
	State.On("Profile", function() if panel.IsOpen then render() end end)
	panel.Root:GetPropertyChangedSignal("Visible"):Connect(function() if panel.Root.Visible then render() end end)
	HUD.RegisterPanel("Traps", panel)
	return panel
end

return TrapsPanel
