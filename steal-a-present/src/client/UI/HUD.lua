--[[
	HUD.lua - the always-visible screen: currencies (top-left), icon buttons (left + bottom),
	rebirth/quest tracker + Rewards (right), event/Grinch timers (top), carry card (bottom).
	Also owns the modal panel layer: HUD.RegisterPanel / HUD.OpenPanel / HUD.CloseAll.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)
local State = require(script.Parent.Parent.State)

local HUD = {}
local player = Players.LocalPlayer
local panels = {}
local buttons = {}
local docks = {}
local TOOLTIPS = { Rewards = "Rewards", Rebirth = "Rebirth", Gift = "Gift a present", Lock = "Lock your base", Base = "My Presents", Shop = "Shop", Index = "Present Index", Quests = "Daily Quests", Traps = "Base Defense", Settings = "Settings & Codes" }

---------------------------------------------------------------------------
-- Scaling (phones get a smaller UI but buttons stay tappable)
---------------------------------------------------------------------------
local function makeDock(name, anchor, position, size, zindex)
	local dock = UIKit.Create("Frame", {
		Name = name, AnchorPoint = anchor, Position = position, Size = size,
		BackgroundTransparency = 1, ZIndex = zindex or 2, Parent = HUD.Gui,
	})
	UIKit.Create("UIScale", { Scale = 1, Parent = dock })
	docks[name] = dock
	return dock
end

function HUD.UpdateScale()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	local scale = math.clamp(math.min(vp.Y / 980, vp.X / 1500), 0.5, 1.1)
	for _, dock in pairs(docks) do
		local s = dock:FindFirstChildOfClass("UIScale")
		if s then s.Scale = scale end
	end
	UIKit.PanelScale = math.clamp(math.min(vp.X / 920, vp.Y / 640), 0.45, 1)
	-- the left icon column sits right under the top-left stack (currencies + base line + objective card)
	-- and shrinks further if it would run into the bottom bar
	local topLeft, left = docks.TopLeft, docks.Left
	if topLeft and left then
		local topBottom = 66 + 340 * scale
		left.Position = UDim2.new(0, 14, 0, topBottom + 6)
		local room = vp.Y - 120 * scale - (topBottom + 6)
		local leftScale = math.clamp(math.min(scale, room / 498), 0.4, scale)
		local s = left:FindFirstChildOfClass("UIScale")
		if s then s.Scale = leftScale end
	end
	for _, panel in pairs(panels) do
		if panel.Root then
			local s = panel.Root:FindFirstChildOfClass("UIScale")
			if s and panel.IsOpen then s.Scale = UIKit.PanelScale end
		end
	end
	HUD.Scale = scale
end

---------------------------------------------------------------------------
-- Panels
---------------------------------------------------------------------------
function HUD.RegisterPanel(name, panelApi)
	panels[name] = panelApi
end

function HUD.GetPanel(name)
	return panels[name]
end

function HUD.OpenPanel(name, data)
	for key, panel in pairs(panels) do
		if key ~= name and panel.IsOpen then panel.Close() end
	end
	local panel = panels[name]
	if panel then
		if panel.SetData then panel.SetData(data) end
		panel.Open()
	end
end

function HUD.TogglePanel(name)
	local panel = panels[name]
	if panel and panel.IsOpen then panel.Close() else HUD.OpenPanel(name) end
end

function HUD.CloseAll()
	for _, panel in pairs(panels) do
		if panel.IsOpen then panel.Close() end
	end
end

function HUD.SetBadge(buttonName, value)
	local b = buttons[buttonName]
	if b then b.SetBadge(value) end
end

function HUD.GetButton(name)
	return buttons[name]
end

---------------------------------------------------------------------------
-- Currency pills
---------------------------------------------------------------------------
local function currencyPill(parent, icon, color, order, key)
	local holder = UIKit.Create("Frame", { Size = UDim2.new(0, 260, 0, 58), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	local circle = UIKit.Create("Frame", { Size = UDim2.new(0, 54, 0, 54), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 3, Parent = holder })
	UIKit.Corner(circle, 27)
	UIKit.Stroke(circle, Theme.Stroke)
	UIKit.Gradient(circle, color, UIKit.Darken(color, 0.7), 90)
	UIKit.Icon({ Category = "Currency", Key = key, Fallback = icon, TextSize = 30, Size = UDim2.new(0.78, 0, 0.78, 0), Position = UDim2.new(0.11, 0, 0.11, 0), ZIndex = 4, Parent = circle })
	local value = UIKit.Text({ Text = "0", Size = UDim2.new(1, -66, 1, 0), Position = UDim2.new(0, 64, 0, 0), TextSize = 40,
		XAlign = Enum.TextXAlignment.Left, StrokeThickness = 3, ZIndex = 3, Parent = holder })
	return { Frame = holder, Value = value, Circle = circle }
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function HUD.Build()
	local gui = UIKit.Create("ScreenGui", {
		Name = "SAP_HUD", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10, Parent = player:WaitForChild("PlayerGui"),
	})
	HUD.Gui = gui

	-- layers for modals / toasts / overlays
	HUD.Layers = {}
	HUD.Layers.Panels = UIKit.Create("Frame", { Name = "PanelLayer", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 10, Parent = gui })
	HUD.Layers.Toasts = UIKit.Create("Frame", { Name = "ToastLayer", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 30, Parent = gui })
	HUD.Layers.Overlay = UIKit.Create("Frame", { Name = "OverlayLayer", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 40, Parent = gui })

	------------------------------------------------------------------ top-left: currencies + base status
	-- IgnoreGuiInset is on, so keep clear of Roblox's own top bar (~58px) ourselves
	local topLeft = makeDock("TopLeft", Vector2.new(0, 0), UDim2.new(0, 14, 0, 66), UDim2.new(0, 290, 0, 360))
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = topLeft })
	HUD.CashPill = currencyPill(topLeft, "💵", Theme.Colors.Green, 1, "Cash")
	HUD.SnowPill = currencyPill(topLeft, "❄️", Theme.Colors.Cyan, 2, "Snowflakes")
	HUD.StrengthPill = currencyPill(topLeft, "💪", Theme.Colors.Orange, 3, "Strength")
	HUD.StrengthPill.Value.TextSize = 30
	-- base status line
	local baseLine = UIKit.Create("Frame", { Size = UDim2.new(0, 270, 0, 34), BackgroundColor3 = Theme.Colors.Outline, BackgroundTransparency = 0.35, LayoutOrder = 4, Parent = topLeft })
	UIKit.Corner(baseLine, 10)
	HUD.BaseLine = UIKit.Text({ Text = "🏠 Pile $0  ·  0/6 slots", TextSize = 20, Scaled = true, MaxTextSize = 20, XAlign = Enum.TextXAlignment.Left, Parent = baseLine })
	UIKit.Padding(baseLine, 6)
	-- objective card (tutorial): hidden once the tutorial is finished
	local objective = UIKit.Create("Frame", { Size = UDim2.new(0, 280, 0, 96), BackgroundColor3 = Theme.Colors.Panel, LayoutOrder = 5, Visible = false, Parent = topLeft })
	UIKit.Corner(objective, 14)
	UIKit.Stroke(objective, Theme.Stroke)
	HUD.ObjectiveCard = objective
	HUD.ObjectiveTitle = UIKit.Text({ Text = "🎯 OBJECTIVE 1/6", Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0, 8, 0, 6), TextSize = 22, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.Orange, StrokeThickness = 2, ZIndex = 3, Parent = objective })
	HUD.ObjectiveText = UIKit.Text({ Text = "", Size = UDim2.new(1, -16, 0, 40), Position = UDim2.new(0, 8, 0, 34), TextSize = 17, Scaled = true, MaxTextSize = 17, Wrapped = true, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.TextDark, Stroke = false, ZIndex = 3, Parent = objective })
	HUD.ObjectiveBar = UIKit.ProgressBar({ Size = UDim2.new(1, -16, 0, 12), Position = UDim2.new(0, 8, 1, -18), Color = Theme.Colors.Orange, TextSize = 10, ZIndex = 3, Parent = objective })

	------------------------------------------------------------------ left column
	local left = makeDock("Left", Vector2.new(0, 0), UDim2.new(0, 14, 0, 400), UDim2.new(0, 110, 0, 498))
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
	buttons.Rewards = UIKit.IconButton({ Tooltip = TOOLTIPS.Rewards, Image = Icons.Get("UI", "Rewards"), Icon = "🎁", Label = "Rewards", Color = Theme.Colors.Pink, LayoutOrder = 1, Parent = left, OnClick = function() HUD.TogglePanel("Rewards") end })
	buttons.Rebirth = UIKit.IconButton({ Tooltip = TOOLTIPS.Rebirth, Image = Icons.Get("UI", "Rebirth"), Icon = "🔄", Label = "Rebirth", Color = Theme.Colors.Purple, LayoutOrder = 2, Parent = left, OnClick = function() HUD.TogglePanel("Rebirth") end })
	buttons.Gift = UIKit.IconButton({ Tooltip = TOOLTIPS.Gift, Image = Icons.Get("UI", "Gift"), Icon = "💝", Label = "Gift", Color = Theme.Colors.Red, LayoutOrder = 3, Parent = left, OnClick = function() HUD.TogglePanel("Gift") end })
	buttons.Lock = UIKit.IconButton({ Tooltip = TOOLTIPS.Lock, Image = Icons.Get("UI", "Lock"), Icon = "🔒", Label = "Lock Base", Color = Theme.Colors.Blue, LayoutOrder = 4, Parent = left, OnClick = function() Remotes.Get("LockBase"):FireServer() end })

	------------------------------------------------------------------ bottom bar
	-- sits ABOVE the Roblox tool hotbar (bat / snowball) instead of covering it
	local bottom = makeDock("Bottom", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -84), UDim2.new(0, 700, 0, 100))
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder, Parent = bottom })
	local bsize = Theme.BottomButton
	buttons.Base = UIKit.IconButton({ Tooltip = TOOLTIPS.Base, Image = Icons.Get("UI", "Base"), Icon = "📦", Size = bsize, Color = Theme.Colors.Yellow, LayoutOrder = 1, Parent = bottom, OnClick = function() HUD.TogglePanel("Base") end })
	buttons.Shop = UIKit.IconButton({ Tooltip = TOOLTIPS.Shop, Image = Icons.Get("UI", "Shop"), Icon = "🛒", Size = bsize, Color = Theme.Colors.Red, LayoutOrder = 2, Parent = bottom, OnClick = function() HUD.TogglePanel("Shop") end })
	buttons.Index = UIKit.IconButton({ Tooltip = TOOLTIPS.Index, Image = Icons.Get("UI", "Index"), Icon = "📖", Size = bsize, Color = Theme.Colors.Orange, LayoutOrder = 3, Parent = bottom, OnClick = function() HUD.TogglePanel("Index") end })
	buttons.Quests = UIKit.IconButton({ Tooltip = TOOLTIPS.Quests, Image = Icons.Get("UI", "Quests"), Icon = "⭐", Size = bsize, Color = Theme.Colors.Pink, LayoutOrder = 4, Parent = bottom, OnClick = function() HUD.TogglePanel("Quests") end })
	buttons.Traps = UIKit.IconButton({ Tooltip = TOOLTIPS.Traps, Image = Icons.Get("UI", "Traps"), Icon = "🛡️", Size = bsize, Color = Theme.Colors.Blue, LayoutOrder = 5, Parent = bottom, OnClick = function() HUD.TogglePanel("Traps") end })
	buttons.Settings = UIKit.IconButton({ Tooltip = TOOLTIPS.Settings, Image = Icons.Get("UI", "Settings"), Icon = "⚙️", Size = bsize, Color = Theme.Colors.Grey, LayoutOrder = 6, Parent = bottom, OnClick = function() HUD.TogglePanel("Settings") end })

	------------------------------------------------------------------ right: rebirth, quest tracker, rewards
	local right = makeDock("Right", Vector2.new(1, 0.5), UDim2.new(1, -14, 0.5, 0), UDim2.new(0, 330, 0, 420))
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = right })
	HUD.RebirthLabel = UIKit.Text({ Text = "Rebirth 0", Size = UDim2.new(1, 0, 0, 30), TextSize = 26, XAlign = Enum.TextXAlignment.Right, Color = Theme.Colors.Purple, LayoutOrder = 1, Parent = right })
	HUD.RankLabel = UIKit.Text({ Text = "Rank 1 - Elf Trainee", Size = UDim2.new(1, 0, 0, 26), TextSize = 22, XAlign = Enum.TextXAlignment.Right, Color = Theme.Colors.Yellow, LayoutOrder = 2, Parent = right })
	HUD.QuestLines = {}
	for i = 1, Config.DailyQuests.Count do
		local line = UIKit.Create("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, LayoutOrder = 2 + i, Parent = right })
		local text = UIKit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 26), TextSize = 22, Scaled = true, MaxTextSize = 22, XAlign = Enum.TextXAlignment.Right, Parent = line })
		local prog = UIKit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 26), TextSize = 20, XAlign = Enum.TextXAlignment.Right, Color = Theme.Colors.Yellow, Parent = line })
		HUD.QuestLines[i] = { Frame = line, Text = text, Progress = prog }
	end
	local rewardsBtn = UIKit.Button({ Text = "Rewards", Icon = "🎁", Color = Theme.Colors.Green, Size = UDim2.new(0, 220, 0, 64), TextSize = 32, LayoutOrder = 10, Parent = right,
		OnClick = function() HUD.TogglePanel("Rewards") end })
	UIKit.Shine(rewardsBtn, 3)
	HUD.RewardsStroke = rewardsBtn:FindFirstChildOfClass("UIStroke")
	HUD.RewardsBadge = UIKit.Create("Frame", { Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -4, 0, -4), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Theme.Colors.Red, Visible = false, ZIndex = 5, Parent = rewardsBtn })
	UIKit.Corner(HUD.RewardsBadge, 15)
	UIKit.Stroke(HUD.RewardsBadge, 2.5)
	HUD.RewardsBadgeText = UIKit.Text({ Text = "1", TextSize = 18, ZIndex = 6, Parent = HUD.RewardsBadge })

	------------------------------------------------------------------ top: season + event + grinch timers
	local top = makeDock("Top", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 12), UDim2.new(0, 520, 0, 120))
	HUD.SeasonLabel = UIKit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 26), TextSize = 22, Color = Theme.Colors.Yellow, Parent = top })
	HUD.EventTitle = UIKit.Text({ Text = "Next Event", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.new(0, 0, 0, 24), TextSize = 32, StrokeThickness = 3, Parent = top })
	HUD.EventBar = UIKit.ProgressBar({ Size = UDim2.new(0, 320, 0, 22), Position = UDim2.new(0.5, 0, 0, 62), AnchorPoint = Vector2.new(0.5, 0), Color = Theme.Colors.Cyan, Parent = top })
	HUD.GrinchLine = UIKit.Text({ Text = "", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.new(0, 0, 0, 88), TextSize = 24, Color = Color3.fromRGB(120, 255, 140), Parent = top })

	------------------------------------------------------------------ carry card (bottom center, above the bar)
	local carry = makeDock("Carry", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -196), UDim2.new(0, 520, 0, 86))
	local card = UIKit.Create("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Colors.Panel, Visible = false, ZIndex = 3, Parent = carry })
	UIKit.Corner(card, 16)
	UIKit.Stroke(card, Theme.Stroke)
	HUD.CarryCard = card
	HUD.CarryIcon = UIKit.Create("Frame", { Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Theme.Colors.Red, ZIndex = 4, Parent = card })
	UIKit.Corner(HUD.CarryIcon, 14)
	UIKit.Stroke(HUD.CarryIcon, Theme.StrokeThin)
	HUD.CarryIconInner = UIKit.Icon({ Category = "Boxes", Key = "Small", Fallback = "🎁", TextSize = 34, Size = UDim2.new(0.8, 0, 0.8, 0), Position = UDim2.new(0.1, 0, 0.1, 0), ZIndex = 5, Parent = HUD.CarryIcon })
	HUD.CarryTitle = UIKit.Text({ Text = "", Size = UDim2.new(1, -230, 0, 36), Position = UDim2.new(0, 84, 0, 8), TextSize = 26, Scaled = true, MaxTextSize = 26, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.TextDark, Stroke = false, ZIndex = 4, Parent = card })
	HUD.CarrySub = UIKit.Text({ Text = "", Size = UDim2.new(1, -230, 0, 26), Position = UDim2.new(0, 84, 0, 46), TextSize = 20, Scaled = true, MaxTextSize = 20, XAlign = Enum.TextXAlignment.Left, Color = Theme.Colors.TextMuted, Stroke = false, ZIndex = 4, Parent = card })
	UIKit.Button({ Text = "DROP", Color = Theme.Colors.Red, Size = UDim2.new(0, 120, 0, 56), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), TextSize = 26, ZIndex = 4, Parent = card,
		OnClick = function() Remotes.Get("DropCarry"):FireServer() end })

	HUD.UpdateScale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(HUD.UpdateScale)

	HUD.Wire()
end

---------------------------------------------------------------------------
-- Live updates
---------------------------------------------------------------------------
local RANKS = { "Elf Trainee", "Gift Wrapper", "Sleigh Loader", "Chimney Pro", "Toy Master", "North Pole Boss", "Santa's Rival", "Present King", "Grinch Slayer", "Master" }

local lastCash
local function updateProfile(profile)
	if not profile then return end
	-- floating "+$x" when cash goes up
	if lastCash and profile.Cash > lastCash + 0.5 then
		local pillPos = HUD.CashPill.Frame.AbsolutePosition
		UIKit.FloatText(HUD.Gui, "+$" .. Util.FormatNumber(profile.Cash - lastCash), Theme.Colors.Cash, UDim2.new(0, pillPos.X + 180, 0, pillPos.Y + 20))
	end
	lastCash = profile.Cash
	HUD.CashPill.Value.Text = "$" .. Util.FormatNumber(profile.Cash)
	HUD.SnowPill.Value.Text = Util.FormatNumber(profile.Snowflakes)
	HUD.StrengthPill.Value.Text = Util.FormatNumber(profile.Strength) .. " STR"
	HUD.RebirthLabel.Text = "Rebirth " .. profile.Rebirths .. "  (x" .. string.format("%.1f", 1 + profile.Rebirths * Config.Rebirth.IncomeBonusPerRebirth) .. ")"
	local rank = math.min(#RANKS, 1 + math.floor((profile.Stats.Unwrapped or 0) / 25) + profile.Rebirths)
	HUD.RankLabel.Text = "Rank " .. rank .. " - " .. RANKS[rank]
	-- rewards badge: calendar claimable or playtime gift ready
	local ready = 0
	if State.Streak and State.Streak.CanClaim then ready = ready + 1 end
	if (profile.PlaytimeGift.Progress or 0) >= Config.PlaytimeGift.IntervalSeconds then ready = ready + 1 end
	HUD.RewardsBadge.Visible = ready > 0
	HUD.RewardsBadgeText.Text = tostring(ready)
	buttons.Rewards.SetBadge(ready > 0 and ready or nil)
	-- rainbow outline on the Rewards button while something is claimable
	if HUD.RewardsStroke then
		local rainbow = HUD.RewardsStroke:FindFirstChildOfClass("UIGradient")
		if ready > 0 and not rainbow then
			UIKit.Rainbow(HUD.RewardsStroke, 0.8)
			HUD.RewardsStroke.Thickness = 5
		elseif ready == 0 and rainbow then
			rainbow:Destroy()
			HUD.RewardsStroke.Thickness = Theme.Stroke
		end
	end
	-- tutorial objective
	local tut = profile.Tutorial
	if Config.Tutorial.Enabled and tut and not tut.Finished then
		local done, nextStep = 0, nil
		for _, step in ipairs(Config.Tutorial.Steps) do
			if tut.Completed[step.Key] then done = done + 1 elseif not nextStep then nextStep = step end
		end
		HUD.ObjectiveCard.Visible = true
		HUD.ObjectiveTitle.Text = "🎯 OBJECTIVE " .. (done + 1) .. "/" .. #Config.Tutorial.Steps
		HUD.ObjectiveText.Text = nextStep and nextStep.Text or ""
		HUD.ObjectiveBar.Set(done / #Config.Tutorial.Steps, "")
	else
		HUD.ObjectiveCard.Visible = false
	end
end

local function updateBase(base)
	if not base then return end
	local lock = ""
	local remaining = State.Remaining(base.LockUntil)
	if remaining > 0 then lock = "  ·  🔒 " .. Util.FormatTime(remaining) end
	HUD.BaseLine.Text = string.format("🏠 Pile $%s  ·  %d/%d slots%s", Util.FormatNumber(base.Pile), base.Used, base.Slots, lock)
end

local function updateCarry(info)
	HUD.CarryCard.Visible = info ~= nil
	if not info then return end
	HUD.CarryIcon.BackgroundColor3 = info.Color or Theme.Colors.Red
	if HUD.CarryIconInner then HUD.CarryIconInner:Destroy() end
	HUD.CarryIconInner = UIKit.Icon({
		Category = info.Kind == "Box" and "Boxes" or "Presents", Key = info.Kind == "Box" and info.Tier or info.Key,
		Fallback = info.Kind == "Box" and "🎁" or (info.Icon or "🎁"), TextSize = 34,
		Size = UDim2.new(0.8, 0, 0.8, 0), Position = UDim2.new(0.1, 0, 0.1, 0), ZIndex = 5, Parent = HUD.CarryIcon,
	})
	if info.Kind == "Box" then
		HUD.CarryTitle.Text = "Carrying: " .. info.Name
		HUD.CarrySub.Text = "Bring it to the green pad at YOUR base to unwrap it!"
	else
		HUD.CarryTitle.Text = (info.Stolen and "STOLEN: " or "Carrying: ") .. (info.Mutation and (info.Mutation .. " ") or "") .. info.Name
		HUD.CarrySub.Text = info.Stolen and "RUN to your base! If you get whacked, it goes back." or "Bring it to your base."
	end
	UIKit.Pop(HUD.CarryCard, 1.05)
end

local function updateQuests(list)
	for i, line in ipairs(HUD.QuestLines) do
		local q = list[i]
		if q then
			line.Frame.Visible = true
			line.Text.Text = q.Text
			if q.Claimed then
				line.Progress.Text = "✅ Claimed"
			elseif q.Done then
				line.Progress.Text = "🎉 Complete! Claim it ⭐"
			else
				line.Progress.Text = Util.FormatNumber(q.Progress) .. "/" .. Util.FormatNumber(q.Goal) .. " ⭐"
			end
		else
			line.Frame.Visible = false
		end
	end
	local claimable = 0
	for _, q in ipairs(list) do
		if q.Done and not q.Claimed then claimable = claimable + 1 end
	end
	buttons.Quests.SetBadge(claimable > 0 and claimable or nil)
end

local function tick()
	-- season
	local season, secondsLeft = Seasons.GetActive()
	if secondsLeft then
		HUD.SeasonLabel.Text = season.Icon .. " " .. season.Name .. (season == Catalog.DefaultSeason and " · next season in " or " ends in ") .. Util.FormatTime(secondsLeft)
	else
		HUD.SeasonLabel.Text = season.Icon .. " " .. season.Name
	end
	-- event
	local ev = State.Event
	if ev and ev.Active then
		local rem = State.Remaining(ev.Active.EndsAt)
		HUD.EventTitle.Text = ev.Active.Name
		HUD.EventTitle.TextColor3 = ev.Active.Color or Theme.Colors.Cyan
		HUD.EventBar.Set(rem / math.max(1, (ev.Active.EndsAt - (ev.StartedLocal or ev.Active.EndsAt - 90))), Util.FormatTime(rem))
	else
		HUD.EventTitle.Text = "Next Event"
		HUD.EventTitle.TextColor3 = Theme.Colors.TextLight
		local rem = ev and State.Remaining(ev.NextAt) or 0
		HUD.EventBar.Set(0, Util.FormatTime(rem))
	end
	-- grinch line
	local g = State.Grinch
	if g then
		if g.Active then
			HUD.GrinchLine.Text = "💚 GRINCH: " .. tostring(g.Name) .. "  " .. g.Hits .. "/" .. g.HitsToDefeat .. "  " .. Util.FormatTime(State.Remaining(g.EndsAt))
		elseif g.WarningUserId then
			HUD.GrinchLine.Text = "⚠️ " .. tostring(g.WarningName) .. " becomes the Grinch in " .. Util.FormatTime(State.Remaining(g.WarningEndsAt))
		else
			HUD.GrinchLine.Text = "Grinch in " .. Util.FormatTime(State.Remaining(g.NextAt))
		end
	end
	updateBase(State.Base)
	-- lock button shows the shield timer / cooldown
	local base = State.Base
	if base then
		local locked = State.Remaining(base.LockUntil)
		local cooldown = State.Remaining(base.CooldownUntil)
		if locked > 0 then
			buttons.Lock.SetLabel("🔒 " .. Util.FormatTime(locked))
		elseif cooldown > 0 then
			buttons.Lock.SetLabel("Lock in " .. Util.FormatTime(cooldown))
		else
			buttons.Lock.SetLabel("Lock Base")
		end
	end
end

function HUD.Wire()
	State.On("Profile", updateProfile)
	State.On("Base", updateBase)
	State.On("Carry", updateCarry)
	State.On("Quests", updateQuests)
	State.On("Streak", function() updateProfile(State.Profile) end)
	State.On("Event", function(ev)
		if ev and ev.Active then ev.StartedLocal = workspace:GetServerTimeNow() end
	end)
	task.spawn(function()
		while true do
			tick()
			task.wait(0.25)
		end
	end)
end

return HUD
