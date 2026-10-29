--[[ RewardsPanel.lua - playtime gift + the 25-day streak calendar (Advent Calendar in December) ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIKit = require(script.Parent.Parent.UIKit)
local State = require(script.Parent.Parent.Parent.State)

local RewardsPanel = {}

local function rewardText(reward)
	if reward.Type == "Cash" then return "💵 $" .. Util.FormatNumber(reward.Amount) end
	if reward.Type == "Snowflakes" then return "❄️ " .. reward.Amount end
	if reward.Type == "Box" then return "🎁 " .. reward.Tier .. " Box" end
	if reward.Type == "Luck" then return "🍀 " .. reward.Minutes .. "m Luck" end
	return "⭐"
end

function RewardsPanel.Create(HUD)
	local panel = UIKit.Panel({ Name = "Rewards", Title = "Rewards!", Icon = "🎁", Parent = HUD.Layers.Panels })

	-- playtime gift
	local giftCard = UIKit.Card({ Size = UDim2.new(1, 0, 0, 92), Parent = panel.Content })
	UIKit.Text({ Text = "🎁 Free Playtime Gift", Size = UDim2.new(0.5, 0, 0, 34), Position = UDim2.new(0, 16, 0, 8), TextSize = 26, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.TextDark, Stroke = false, ZIndex = 14, Parent = giftCard })
	UIKit.Text({ Text = "A Rare-or-better box every " .. math.floor(Config.PlaytimeGift.IntervalSeconds / 60) .. " minutes you play.", Size = UDim2.new(0.6, 0, 0, 22), Position = UDim2.new(0, 16, 0, 40), TextSize = 17, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.TextMuted, Stroke = false, ZIndex = 14, Parent = giftCard })
	local giftBar = UIKit.ProgressBar({ Size = UDim2.new(0.55, 0, 0, 20), Position = UDim2.new(0, 16, 0, 64), Color = Theme.Colors.Pink, ZIndex = 14, Parent = giftCard })
	local giftBtn = UIKit.Button({ Text = "CLAIM!", Color = Theme.Colors.Green, Size = UDim2.new(0, 180, 0, 56), Position = UDim2.new(1, -16, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), TextSize = 26, ZIndex = 14, Parent = giftCard,
		OnClick = function() Remotes.Get("ClaimPlaytimeGift"):FireServer() end })

	-- calendar
	local calTitle = UIKit.Text({ Text = "📅 Daily Calendar", Size = UDim2.new(0.6, 0, 0, 34), Position = UDim2.new(0, 0, 0, 100), TextSize = 28, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.Red, StrokeThickness = 2.5, Parent = panel.Content })
	local claimBtn = UIKit.Button({ Text = "CLAIM DAY 1!", Color = Theme.Colors.Green, Size = UDim2.new(0, 260, 0, 54), Position = UDim2.new(1, 0, 0, 96), AnchorPoint = Vector2.new(1, 0), TextSize = 26, Parent = panel.Content,
		OnClick = function() Remotes.Get("ClaimStreak"):FireServer() end })
	UIKit.Text({ Text = "Log in every day to keep your streak. Miss a day and it restarts at day 1!", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 136), TextSize = 17, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.TextMuted, Stroke = false, Parent = panel.Content })
	local grid = UIKit.Scroll({ Layout = "Grid", CellSize = UDim2.new(0, 140, 0, 96), Size = UDim2.new(1, 0, 1, -162), Position = UDim2.new(0, 0, 0, 160), Parent = panel.Content })

	local function render()
		local profile = State.Profile
		local streak = State.Streak
		local season = Seasons.GetActive()
		calTitle.Text = "📅 " .. (season.CalendarName or "Daily Calendar")
		if profile then
			local p = profile.PlaytimeGift.Progress or 0
			local ready = p >= Config.PlaytimeGift.IntervalSeconds
			giftBar.Set(math.min(1, p / Config.PlaytimeGift.IntervalSeconds), ready and "READY!" or Util.FormatTime(Config.PlaytimeGift.IntervalSeconds - p) .. " left")
			UIKit.SetButtonEnabled(giftBtn, ready, "Not yet")
			if ready then UIKit.SetButtonText(giftBtn, "CLAIM!") end
		end
		for _, c in ipairs(grid:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		local count = streak and streak.Count or 0
		local nextDay = streak and streak.NextDay or 1
		local canClaim = streak and streak.CanClaim
		for day = 1, Config.Streak.Days do
			local reward = Config.Streak.Rewards[day]
			local claimed = day <= (count % Config.Streak.Days == 0 and count > 0 and Config.Streak.Days or count % Config.Streak.Days)
			local isNext = canClaim and day == nextDay
			local color = claimed and Theme.Colors.Green or (isNext and Theme.Colors.Yellow or Theme.Colors.PanelInner)
			local card = UIKit.Card({ Size = UDim2.new(0, 140, 0, 96), LayoutOrder = day, Color = color, StrokeColor = isNext and Theme.Colors.YellowDark or Theme.Colors.Outline, Parent = grid })
			UIKit.Text({ Text = "Day " .. day .. (claimed and " ✓" or ""), Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 6), TextSize = 22, Color = claimed and Theme.Colors.TextLight or Theme.Colors.TextDark, Stroke = claimed, ZIndex = 14, Parent = card })
			UIKit.Text({ Text = rewardText(reward), Size = UDim2.new(1, -8, 0, 44), Position = UDim2.new(0, 4, 0, 40), TextSize = 20, Scaled = true, MaxTextSize = 20, Wrapped = true, Color = claimed and Theme.Colors.TextLight or Theme.Colors.TextDark, Stroke = claimed, ZIndex = 14, Parent = card })
			if isNext then
				UIKit.Rainbow(card:FindFirstChildOfClass("UIStroke"), 0.6)
			end
		end
		UIKit.SetButtonEnabled(claimBtn, canClaim == true, "Come back tomorrow!")
		if canClaim then UIKit.SetButtonText(claimBtn, "CLAIM DAY " .. nextDay .. "!") end
	end

	State.On("Profile", function() if panel.IsOpen then render() end end)
	State.On("Streak", function() if panel.IsOpen then render() end end)
	panel.Root:GetPropertyChangedSignal("Visible"):Connect(function() if panel.Root.Visible then render() end end)
	HUD.RegisterPanel("Rewards", panel)
	return panel
end

return RewardsPanel
