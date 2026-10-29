--[[ GiftPanel.lua - pick a player in the server, pick one of your presents, send it ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local State = require(script.Parent.Parent.Parent.State)

local GiftPanel = {}
local player = Players.LocalPlayer

function GiftPanel.Create(HUD)
	local panel = UIKit.Panel({ Name = "Gift", Title = "Gift a Present", Icon = "💝", Parent = HUD.Layers.Panels })
	UIKit.Text({ Text = "Gifted presents earn +" .. math.floor(Config.Gift.ValueBonus * 100) .. "% forever (+" .. math.floor(Config.Gift.FriendBonus * 100) .. "% more for Roblox friends). You both get ❄️ " .. Config.Gift.SnowflakesForBoth .. "!",
		Size = UDim2.new(1, 0, 0, 28), TextSize = 18, Scaled = true, MaxTextSize = 18, Color = Theme.Colors.TextMuted, Stroke = false, Parent = panel.Content })
	local left = UIKit.Create("Frame", { Size = UDim2.new(0.42, -8, 1, -100), Position = UDim2.new(0, 0, 0, 34), BackgroundTransparency = 1, Parent = panel.Content })
	local right = UIKit.Create("Frame", { Size = UDim2.new(0.58, -8, 1, -100), Position = UDim2.new(0.42, 8, 0, 34), BackgroundTransparency = 1, Parent = panel.Content })
	UIKit.Text({ Text = "1. Pick a player", Size = UDim2.new(1, 0, 0, 30), TextSize = 24, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.Red, StrokeThickness = 2.5, Parent = left })
	UIKit.Text({ Text = "2. Pick a present", Size = UDim2.new(1, 0, 0, 30), TextSize = 24, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.Red, StrokeThickness = 2.5, Parent = right })
	local playerList = UIKit.Scroll({ Layout = "List", Size = UDim2.new(1, 0, 1, -34), Position = UDim2.new(0, 0, 0, 34), Parent = left })
	local presentList = UIKit.Scroll({ Layout = "List", Size = UDim2.new(1, 0, 1, -34), Position = UDim2.new(0, 0, 0, 34), Parent = right })
	local status = UIKit.Text({ Text = "", Size = UDim2.new(0.6, 0, 0, 50), Position = UDim2.new(0, 0, 1, -56), TextSize = 20, Scaled = true, MaxTextSize = 20, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.TextDark, Stroke = false, Parent = panel.Content })
	local sendBtn = UIKit.Button({ Text = "SEND GIFT 💝", Color = Theme.Colors.Red, Size = UDim2.new(0, 260, 0, 60), Position = UDim2.new(1, 0, 1, -8), AnchorPoint = Vector2.new(1, 1), TextSize = 28, Parent = panel.Content })

	local selectedPlayer, selectedPresent
	local playerButtons, presentButtons = {}, {}

	local function refreshStatus()
		local p = selectedPlayer and Players:GetPlayerByUserId(selectedPlayer)
		local info = selectedPresent and Catalog.PresentByKey[selectedPresent.Key]
		status.Text = (p and ("To: " .. p.DisplayName) or "To: (nobody yet)") .. "\n" .. (info and ("Gift: " .. info.Name) or "Gift: (pick a present)")
		UIKit.SetButtonEnabled(sendBtn, p ~= nil and selectedPresent ~= nil, "Pick both")
		if p and selectedPresent then sendBtn.Text.Text = "SEND GIFT 💝" end
		for id, b in pairs(playerButtons) do b.BackgroundColor3 = id == selectedPlayer and Theme.Colors.Green or Theme.Colors.Blue end
		for id, b in pairs(presentButtons) do b.BackgroundColor3 = (selectedPresent and id == selectedPresent.Id) and Theme.Colors.Green or Theme.Colors.Pink end
	end

	local function render()
		for _, c in ipairs(playerList:GetChildren()) do if c:IsA("TextButton") or c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end end
		for _, c in ipairs(presentList:GetChildren()) do if c:IsA("TextButton") or c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end end
		playerButtons, presentButtons = {}, {}
		local others = 0
		for i, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				others = others + 1
				playerButtons[other.UserId] = UIKit.Button({ Text = other.DisplayName, Color = Theme.Colors.Blue, Size = UDim2.new(1, -16, 0, 48), TextSize = 22, LayoutOrder = i, Parent = playerList,
					OnClick = function() selectedPlayer = other.UserId refreshStatus() end })
			end
		end
		if others == 0 then
			UIKit.Text({ Text = "Nobody else is here yet. Invite a friend!", Size = UDim2.new(1, -16, 0, 60), TextSize = 20, Wrapped = true, Color = Theme.Colors.TextMuted, Stroke = false, Parent = playerList })
		end
		local profile = State.Profile
		for i, record in ipairs(profile and profile.Presents or {}) do
			local info = Catalog.PresentByKey[record.Key] or { Name = record.Key, Icon = "🎁" }
			local r = Catalog.Rarities[record.Rarity] or Catalog.Rarities.Common
			presentButtons[record.Id] = UIKit.Button({ Text = info.Icon .. " " .. (record.Mutation and (record.Mutation .. " ") or "") .. info.Name .. " (" .. r.Name .. ")", Color = Theme.Colors.Pink, Size = UDim2.new(1, -16, 0, 48), TextSize = 20, LayoutOrder = i, Parent = presentList,
				OnClick = function() selectedPresent = record refreshStatus() end })
		end
		refreshStatus()
	end

	sendBtn.Activated:Connect(function()
		if selectedPlayer and selectedPresent then
			Remotes.Get("GiftPresent"):FireServer(selectedPresent.Id, selectedPlayer)
			selectedPresent = nil
			task.delay(0.5, render)
		end
	end)
	State.On("Profile", function() if panel.IsOpen then render() end end)
	panel.Root:GetPropertyChangedSignal("Visible"):Connect(function() if panel.Root.Visible then selectedPlayer = nil selectedPresent = nil render() end end)
	Players.PlayerAdded:Connect(function() if panel.IsOpen then render() end end)
	Players.PlayerRemoving:Connect(function() if panel.IsOpen then render() end end)
	HUD.RegisterPanel("Gift", panel)
	return panel
end

return GiftPanel
