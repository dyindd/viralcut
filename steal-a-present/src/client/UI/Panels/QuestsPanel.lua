--[[ QuestsPanel.lua - today's 3 quests with progress bars + claim buttons ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local State = require(script.Parent.Parent.Parent.State)

local QuestsPanel = {}

function QuestsPanel.Create(HUD)
	local panel = UIKit.Panel({ Name = "Quests", Title = "Daily Quests", Icon = "⭐", Height = 480, Parent = HUD.Layers.Panels })
	UIKit.Text({ Text = "New quests every day. Rewards: cash + ❄️ Snowflakes for the Snowflake Shop!", Size = UDim2.new(1, 0, 0, 30), TextSize = 20, Color = Theme.Colors.TextMuted, Stroke = false, Parent = panel.Content })
	local list = UIKit.Scroll({ Layout = "List", Size = UDim2.new(1, 0, 1, -40), Position = UDim2.new(0, 0, 0, 38), Parent = panel.Content })

	local function render(quests)
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		for i, q in ipairs(quests or {}) do
			local card = UIKit.Card({ Size = UDim2.new(1, -16, 0, 110), LayoutOrder = i, Parent = list })
			UIKit.Text({ Text = q.Text, Size = UDim2.new(0.65, 0, 0, 36), Position = UDim2.new(0, 16, 0, 10), TextSize = 26, Scaled = true, MaxTextSize = 26, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.TextDark, Stroke = false, ZIndex = 14, Parent = card })
			UIKit.Text({ Text = "Reward: $" .. Util.FormatNumber(q.Reward.Cash or 0) .. "  +  ❄️ " .. (q.Reward.Snowflakes or 0), Size = UDim2.new(0.65, 0, 0, 24), Position = UDim2.new(0, 16, 0, 46), TextSize = 18, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.GreenDark, Stroke = false, ZIndex = 14, Parent = card })
			local bar = UIKit.ProgressBar({ Size = UDim2.new(0.65, -16, 0, 24), Position = UDim2.new(0, 16, 0, 76), Color = Theme.Colors.Yellow, ZIndex = 14, Parent = card })
			bar.Set(q.Progress / math.max(1, q.Goal), Util.FormatNumber(q.Progress) .. " / " .. Util.FormatNumber(q.Goal))
			local btn = UIKit.Button({ Text = q.Claimed and "CLAIMED ✓" or (q.Done and "CLAIM!" or "In progress"), Color = q.Claimed and Theme.Colors.Grey or Theme.Colors.Green,
				Size = UDim2.new(0, 190, 0, 56), Position = UDim2.new(1, -16, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), TextSize = 26, ZIndex = 14, Parent = card,
				OnClick = function() if q.Done and not q.Claimed then Remotes.Get("ClaimQuest"):FireServer(q.Id) end end })
			if not q.Done or q.Claimed then UIKit.SetButtonEnabled(btn, false, q.Claimed and "CLAIMED ✓" or "In progress") end
		end
	end

	State.On("Quests", render)
	panel.Root:GetPropertyChangedSignal("Visible"):Connect(function() if panel.Root.Visible then render(State.Quests) end end)
	HUD.RegisterPanel("Quests", panel)
	return panel
end

return QuestsPanel
