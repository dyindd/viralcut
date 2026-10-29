--[[
	UIKit.lua - builds every UI element in code, in the Theme's chunky cartoon style.
	Nothing here talks to the server. Keep it dumb and reusable.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Icons = require(ReplicatedStorage.Shared.Icons)

local UIKit = {}
UIKit.PanelScale = 1   -- set by HUD.UpdateScale so modals fit on phones

---------------------------------------------------------------------------
-- Basics
---------------------------------------------------------------------------
function UIKit.Create(className, props, children)
	local obj = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then obj[k] = v end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = obj
	end
	if props and props.Parent then obj.Parent = props.Parent end
	return obj
end

function UIKit.Corner(parent, radius)
	return UIKit.Create("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Corner), Parent = parent })
end

function UIKit.Stroke(parent, thickness, color, transparency)
	return UIKit.Create("UIStroke", {
		Thickness = thickness or Theme.Stroke,
		Color = color or Theme.Colors.Outline,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function UIKit.Gradient(parent, top, bottom, rotation)
	return UIKit.Create("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, top), ColorSequenceKeypoint.new(1, bottom) }),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

function UIKit.Padding(parent, all)
	return UIKit.Create("UIPadding", {
		PaddingTop = UDim.new(0, all), PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all), PaddingRight = UDim.new(0, all), Parent = parent,
	})
end

function UIKit.Tween(obj, props, time, style, direction)
	local tween = TweenService:Create(obj, TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Back, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

-- Darken a color by a factor (0.8 = 20% darker)
function UIKit.Darken(color, factor)
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

-- IMPORTANT: a UIGradient MULTIPLIES the parent's BackgroundColor3. Every gradient element
-- therefore uses a white background and puts the real color in the gradient.
local function setGradient(obj, color)
	local grad = obj:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(1, UIKit.Darken(color, 0.75)) })
	else
		obj.BackgroundColor3 = color
	end
end

-- Change a button's color (works for anything built by UIKit.Button / IconButton)
function UIKit.SetButtonColor(button, color)
	button:SetAttribute("BaseColor", color)
	setGradient(button, color)
end

-- Animated rainbow gradient (for Secret / Mythic / Galaxy)
function UIKit.Rainbow(parent, speed)
	local g = UIKit.Create("UIGradient", { Color = Theme.Rainbow, Rotation = 0, Parent = parent })
	task.spawn(function()
		while g.Parent do
			g.Offset = Vector2.new((os.clock() * (speed or 0.5)) % 1, 0)
			task.wait(0.03)
		end
	end)
	return g
end

-- A diagonal white "shine" that sweeps across the element every `interval` seconds (PS99 buttons do this)
function UIKit.Shine(target, interval)
	local shine = UIKit.Create("Frame", {
		Name = "Shine", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0,
		ZIndex = (target.ZIndex or 1) + 1, Parent = target,
	})
	local corner = target:FindFirstChildOfClass("UICorner")
	if corner then UIKit.Corner(shine, corner.CornerRadius.Offset) end
	local grad = UIKit.Create("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) }),
		Rotation = 25, Offset = Vector2.new(-1, 0), Parent = shine,
	})
	task.spawn(function()
		while shine.Parent do
			task.wait(interval or 3.5)
			local t0 = os.clock()
			while os.clock() - t0 < 0.7 and shine.Parent do
				grad.Offset = Vector2.new(-1 + (os.clock() - t0) / 0.7 * 2, 0)
				task.wait(0.03)
			end
			grad.Offset = Vector2.new(-1, 0)
		end
	end)
	return shine
end

-- Spinning light rays (the unwrap reveal background)
function UIKit.Rays(parent, color, count)
	local holder = UIKit.Create("Frame", { Name = "Rays", Size = UDim2.new(0, 420, 0, 420), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = parent.ZIndex or 1, Parent = parent })
	local n = count or 12
	for i = 1, n do
		local ray = UIKit.Create("Frame", { Size = UDim2.new(0, 46, 1, 0), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color or Theme.Colors.Yellow, BackgroundTransparency = 0.55, Rotation = (i - 1) * (180 / n), ZIndex = holder.ZIndex, Parent = holder })
		UIKit.Create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90, Parent = ray })
	end
	task.spawn(function()
		while holder.Parent do
			holder.Rotation = (holder.Rotation + 0.6) % 360
			task.wait(0.03)
		end
	end)
	local api = { Frame = holder }
	function api.SetColor(c) for _, r in ipairs(holder:GetChildren()) do if r:IsA("Frame") then r.BackgroundColor3 = c end end end
	return api
end

-- "+$250" style text that rises and fades
function UIKit.FloatText(parent, text, color, position)
	local label = UIKit.Text({ Text = text, Size = UDim2.new(0, 200, 0, 36), Position = position or UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), TextSize = 30, Color = color or Theme.Colors.Cash, StrokeThickness = 2.5, ZIndex = 20, Parent = parent })
	local scale = UIKit.Create("UIScale", { Scale = 0.6, Parent = label })
	UIKit.Tween(scale, { Scale = 1.1 }, 0.18)
	UIKit.Tween(label, { Position = label.Position - UDim2.new(0, 0, 0, 60) }, 1.0, Enum.EasingStyle.Quad)
	task.delay(0.6, function() UIKit.Tween(label, { TextTransparency = 1 }, 0.4, Enum.EasingStyle.Quad) end)
	task.delay(1.1, function() label:Destroy() end)
	return label
end

-- A thick outline that carries a gradient (gold glow for primary buttons)
function UIKit.GlowStroke(obj, color, thickness)
	local stroke = UIKit.Stroke(obj, thickness or 4, color or Theme.Colors.Gold)
	UIKit.Create("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.5, color or Theme.Colors.Gold), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)) }),
		Rotation = 45, Parent = stroke,
	})
	return stroke
end

-- An icon: ImageLabel when an asset id is configured in Icons.lua, otherwise the emoji fallback.
-- props: Category, Key, Fallback, Size, Position, AnchorPoint, ZIndex, TextSize, Parent
function UIKit.Icon(props)
	local image = Icons.Get(props.Category, props.Key)
	if image then
		return UIKit.Create("ImageLabel", {
			Name = props.Name or "Icon",
			Size = props.Size or UDim2.new(1, 0, 1, 0),
			Position = props.Position or UDim2.new(0, 0, 0, 0),
			AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
			BackgroundTransparency = 1,
			Image = image,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = props.ZIndex or 1,
			LayoutOrder = props.LayoutOrder or 0,
			Parent = props.Parent,
		})
	end
	return UIKit.Text({
		Name = props.Name or "Icon", Text = props.Fallback or "❔", Size = props.Size or UDim2.new(1, 0, 1, 0), Position = props.Position,
		AnchorPoint = props.AnchorPoint, TextSize = props.TextSize or 40, Stroke = false, ZIndex = props.ZIndex or 1, LayoutOrder = props.LayoutOrder, Parent = props.Parent,
	})
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------
function UIKit.Text(props)
	local label = UIKit.Create("TextLabel", {
		Name = props.Name or "Label",  -- NOT "Text": TextButton.Text is a property and would shadow the child
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.new(1, 0, 1, 0),
		Position = props.Position or UDim2.new(0, 0, 0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Font = props.Font or Theme.Font,
		Text = props.Text or "",
		TextColor3 = props.Color or Theme.Colors.TextLight,
		TextSize = props.TextSize or 24,
		TextScaled = props.Scaled or false,
		TextWrapped = props.Wrapped or props.Scaled or false,
		TextXAlignment = props.XAlign or Enum.TextXAlignment.Center,
		TextYAlignment = props.YAlign or Enum.TextYAlignment.Center,
		RichText = props.Rich or false,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	if props.Stroke ~= false then
		UIKit.Create("UIStroke", {
			Thickness = props.StrokeThickness or Theme.TextStroke,
			Color = props.StrokeColor or Theme.Colors.Outline,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			LineJoinMode = Enum.LineJoinMode.Round,
			Parent = label,
		})
	end
	if props.MaxTextSize then
		UIKit.Create("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize, MinTextSize = props.MinTextSize or 8, Parent = label })
	end
	return label
end

-- Text input (codes etc.)
function UIKit.TextBox(props)
	local box = UIKit.Create("TextBox", {
		Name = props.Name or "Input",
		Size = props.Size or UDim2.new(0, 260, 0, 48),
		Position = props.Position or UDim2.new(0, 0, 0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		BackgroundColor3 = Theme.Colors.PanelInner,
		Font = Theme.Font,
		Text = "",
		PlaceholderText = props.Placeholder or "",
		PlaceholderColor3 = Theme.Colors.TextMuted,
		TextColor3 = Theme.Colors.TextDark,
		TextSize = props.TextSize or 24,
		ClearTextOnFocus = false,
		ZIndex = props.ZIndex or 14,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	UIKit.Corner(box, Theme.CornerSmall)
	UIKit.Stroke(box, Theme.StrokeThin)
	UIKit.Padding(box, 6)
	return box
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
local function pressFx(button, scaleHolder)
	local base = scaleHolder.Scale
	button.MouseEnter:Connect(function() UIKit.Tween(scaleHolder, { Scale = base * 1.06 }, 0.12) end)
	button.MouseLeave:Connect(function() UIKit.Tween(scaleHolder, { Scale = base }, 0.12) end)
	button.MouseButton1Down:Connect(function() UIKit.Tween(scaleHolder, { Scale = base * 0.92 }, 0.08, Enum.EasingStyle.Quad) end)
	button.MouseButton1Up:Connect(function() UIKit.Tween(scaleHolder, { Scale = base * 1.06 }, 0.12) end)
end

-- Chunky gradient button with text. props: Text, Color, ColorDark, Size, Position, AnchorPoint, Parent, OnClick, TextSize, Icon
function UIKit.Button(props)
	local color = props.Color or Theme.Colors.Green
	local dark = props.ColorDark or UIKit.Darken(color, 0.75)
	local button = UIKit.Create("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.new(0, 200, 0, 60),
		Position = props.Position or UDim2.new(0, 0, 0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		AutoButtonColor = false,
		Text = "",
		ZIndex = props.ZIndex or 2,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	UIKit.Corner(button, props.Corner or Theme.Corner)
	UIKit.Gradient(button, color, dark, 90)
	UIKit.Stroke(button, props.StrokeThickness or Theme.Stroke)
	local scale = UIKit.Create("UIScale", { Scale = 1, Parent = button })
	local label = UIKit.Text({
		Text = (props.Icon and (props.Icon .. " ") or "") .. (props.Text or ""),
		TextSize = props.TextSize or 26,
		Scaled = props.Scaled ~= false,
		MaxTextSize = props.TextSize or 26,
		ZIndex = (props.ZIndex or 2) + 1,
		Parent = button,
	})
	UIKit.Padding(button, 6)
	pressFx(button, scale)
	if props.OnClick then
		button.Activated:Connect(function()
			props.OnClick(button)
		end)
	end
	button:SetAttribute("BaseColor", color)
	return button, label
end

-- Change the text of a UIKit.Button (its label child is named "Label")
function UIKit.SetButtonText(button, text)
	local label = button:FindFirstChild("Label")
	if label then label.Text = text end
end

function UIKit.SetButtonEnabled(button, enabled, disabledText)
	local label = button:FindFirstChild("Label")
	button.Active = enabled
	button.AutoButtonColor = false
	local base = button:GetAttribute("BaseColor") or Theme.Colors.Green
	setGradient(button, enabled and base or Theme.Colors.Grey)
	if label and disabledText and not enabled then label.Text = disabledText end
end

-- Square icon button with an emoji/image, a small label under it, and an optional badge.
function UIKit.IconButton(props)
	local size = props.Size or Theme.SideButton
	local holder = UIKit.Create("Frame", {
		Name = props.Name or "IconButton",
		Size = UDim2.new(0, size, 0, size + (props.Label and 22 or 0)),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	local color = props.Color or Theme.Colors.Blue
	local button = UIKit.Create("TextButton", {
		Name = "Button",
		Size = UDim2.new(0, size, 0, size),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		AutoButtonColor = false,
		Text = "",
		ZIndex = 2,
		Parent = holder,
	})
	button:SetAttribute("BaseColor", color)
	UIKit.Corner(button, 18)
	UIKit.Gradient(button, color, UIKit.Darken(color, 0.72), 90)
	UIKit.Stroke(button, Theme.Stroke)
	local scale = UIKit.Create("UIScale", { Scale = 1, Parent = button })
	-- glossy top highlight
	local gloss = UIKit.Create("Frame", { Name = "Gloss", Size = UDim2.new(1, -8, 0.42, 0), Position = UDim2.new(0, 4, 0, 4), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.72, ZIndex = 3, Parent = button })
	UIKit.Corner(gloss, 14)
	UIKit.Create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90, Parent = gloss })
	if props.Image then
		UIKit.Create("ImageLabel", { Size = UDim2.new(0.74, 0, 0.74, 0), Position = UDim2.new(0.13, 0, 0.13, 0),
			BackgroundTransparency = 1, Image = props.Image, ScaleType = Enum.ScaleType.Fit, ZIndex = 4, Parent = button })
	else
		UIKit.Text({ Text = props.Icon or "?", TextSize = size * 0.6, Stroke = false, ZIndex = 4, Parent = button })
	end
	UIKit.Shine(button, 4 + (props.LayoutOrder or 0) * 0.7)
	if props.Label then
		UIKit.Text({ Text = props.Label, Size = UDim2.new(1.4, 0, 0, 22), Position = UDim2.new(-0.2, 0, 0, size - 2),
			TextSize = 18, Scaled = true, MaxTextSize = 18, ZIndex = 4, Parent = holder })
	end
	local badge = UIKit.Create("Frame", {
		Name = "Badge", Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(1, -8, 0, -8), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Colors.Red, Visible = false, ZIndex = 5, Parent = holder,
	})
	UIKit.Corner(badge, 15)
	UIKit.Stroke(badge, 2.5)
	local badgeText = UIKit.Text({ Text = "!", TextSize = 18, ZIndex = 6, Parent = badge })
	if props.Tooltip then
		local tip = UIKit.Create("Frame", { Name = "Tooltip", Size = UDim2.new(0, 160, 0, 32), Position = UDim2.new(0.5, 0, 0, -6), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = Theme.Colors.Outline, BackgroundTransparency = 0.1, Visible = false, ZIndex = 8, Parent = holder })
		UIKit.Corner(tip, 10)
		UIKit.Text({ Text = props.Tooltip, TextSize = 18, Scaled = true, MaxTextSize = 18, ZIndex = 9, Parent = tip })
		button.MouseEnter:Connect(function() tip.Visible = true end)
		button.MouseLeave:Connect(function() tip.Visible = false end)
	end
	pressFx(button, scale)
	if props.OnClick then
		button.Activated:Connect(function() props.OnClick() end)
	end
	local api = { Frame = holder, Button = button }
	function api.SetLabel(text)
		local label = holder:FindFirstChild("Label")
		if label then label.Text = text end
	end
	function api.SetBadge(value)
		if value == nil or value == false or value == 0 then
			badge.Visible = false
		else
			badge.Visible = true
			badgeText.Text = (value == true) and "!" or tostring(value)
			UIKit.Tween(badge, { Size = UDim2.new(0, 34, 0, 34) }, 0.15)
			task.delay(0.15, function() UIKit.Tween(badge, { Size = UDim2.new(0, 30, 0, 30) }, 0.15) end)
		end
	end
	return api
end

---------------------------------------------------------------------------
-- Panel (modal window)
---------------------------------------------------------------------------
function UIKit.Panel(props)
	local width = props.Width or Theme.PanelWidth
	local height = props.Height or Theme.PanelHeight
	local root = UIKit.Create("Frame", {
		Name = props.Name or "Panel",
		Size = UDim2.new(0, width, 0, height),
		Position = UDim2.new(0.5, 0, 0.5, 20),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
		Parent = props.Parent,
	})
	local scale = UIKit.Create("UIScale", { Scale = 0.6, Parent = root })
	-- shadow
	local shadow = UIKit.Create("Frame", {
		Name = "Shadow", Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 6, 0, 10),
		BackgroundColor3 = Theme.Colors.Shadow, BackgroundTransparency = 0.6, ZIndex = 10, Parent = root,
	})
	UIKit.Corner(shadow, Theme.Corner + 6)
	-- body
	local body = UIKit.Create("Frame", {
		Name = "Body", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.Colors.Panel, ZIndex = 11, Parent = root,
	})
	UIKit.Corner(body, Theme.Corner + 6)
	UIKit.Stroke(body, Theme.Stroke + 0.5)
	UIKit.Gradient(body, Color3.fromRGB(255, 255, 255), Color3.fromRGB(228, 238, 255), 90)
	-- title (overlapping the top edge like PS99)
	local titleHolder = UIKit.Create("Frame", {
		Name = "Title", Size = UDim2.new(0, 520, 0, 70), Position = UDim2.new(0, 18, 0, -38),
		BackgroundTransparency = 1, ZIndex = 14, Parent = root,
	})
	local title = UIKit.Text({
		Text = (props.Icon and (props.Icon .. " ") or "") .. (props.Title or ""), TextSize = 48, Scaled = true, MaxTextSize = 48,
		XAlign = Enum.TextXAlignment.Left, StrokeThickness = 3, ZIndex = 15, Parent = titleHolder,
	})
	UIKit.Create("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 225, 150)) }), Rotation = 90, Parent = title })
	-- close button
	local close = UIKit.Create("TextButton", {
		Name = "Close", Size = UDim2.new(0, 64, 0, 64), Position = UDim2.new(1, 10, 0, -18), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255), AutoButtonColor = false, Text = "", ZIndex = 15, Parent = root,
	})
	UIKit.Corner(close, 16)
	UIKit.Gradient(close, Theme.Colors.Red, Theme.Colors.RedDark, 90)
	UIKit.Stroke(close, Theme.Stroke)
	UIKit.Text({ Text = "✕", TextSize = 36, StrokeThickness = 2.5, ZIndex = 16, Parent = close })
	local closeScale = UIKit.Create("UIScale", { Scale = 1, Parent = close })
	pressFx(close, closeScale)
	-- content area
	local content = UIKit.Create("Frame", {
		Name = "Content", Size = UDim2.new(1, -36, 1, -60), Position = UDim2.new(0, 18, 0, 42),
		BackgroundTransparency = 1, ZIndex = 12, Parent = body,
	})

	local api = { Root = root, Body = body, Content = content, IsOpen = false, Name = props.Name }
	local openTween
	function api.Open()
		if api.IsOpen then return end
		api.IsOpen = true
		root.Visible = true
		scale.Scale = 0.6 * UIKit.PanelScale
		root.Position = UDim2.new(0.5, 0, 0.5, 40)
		UIKit.Tween(scale, { Scale = UIKit.PanelScale }, 0.28)
		UIKit.Tween(root, { Position = UDim2.new(0.5, 0, 0.5, 0) }, 0.28)
		if props.OnOpen then props.OnOpen() end
	end
	function api.Close()
		if not api.IsOpen then return end
		api.IsOpen = false
		UIKit.Tween(scale, { Scale = 0.6 }, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.16, function()
			if not api.IsOpen then root.Visible = false end
		end)
		if props.OnClose then props.OnClose() end
	end
	function api.Toggle()
		if api.IsOpen then api.Close() else api.Open() end
	end
	close.Activated:Connect(api.Close)
	return api
end

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------
-- Tab bar inside a panel. tabs = { {Key, Text, Color} }, onSelect(key)
function UIKit.Tabs(parent, tabs, onSelect)
	local bar = UIKit.Create("Frame", { Name = "Tabs", Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, ZIndex = 13, Parent = parent })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = bar })
	local buttons = {}
	local current
	local function select(key)
		current = key
		for k, b in pairs(buttons) do
			UIKit.SetButtonEnabled(b, k == key)
			b.Active = true
		end
		onSelect(key)
	end
	for i, tab in ipairs(tabs) do
		local b = UIKit.Button({ Text = tab.Text, Color = tab.Color or Theme.Colors.Blue, Size = UDim2.new(0, 180, 0, 50), TextSize = 24,
			LayoutOrder = i, ZIndex = 13, Parent = bar, OnClick = function() select(tab.Key) end })
		buttons[tab.Key] = b
	end
	select(tabs[1].Key)
	return { Bar = bar, Select = select, Current = function() return current end }
end

-- White inner card (for grid items)
function UIKit.Card(props)
	local card = UIKit.Create("Frame", {
		Name = props.Name or "Card",
		Size = props.Size or UDim2.new(0, 150, 0, 150),
		BackgroundColor3 = props.Color or Theme.Colors.PanelInner,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 13,
		Parent = props.Parent,
	})
	UIKit.Corner(card, Theme.CornerSmall + 2)
	UIKit.Stroke(card, Theme.StrokeThin, props.StrokeColor or Theme.Colors.Outline)
	return card
end

-- Scrolling grid/list. layout = "Grid" | "List"
function UIKit.Scroll(props)
	local scroll = UIKit.Create("ScrollingFrame", {
		Name = props.Name or "Scroll",
		Size = props.Size or UDim2.new(1, 0, 1, 0),
		Position = props.Position or UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 10,
		ScrollBarImageColor3 = Theme.Colors.GreyDark,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = props.ZIndex or 13,
		Parent = props.Parent,
	})
	if props.Layout == "Grid" then
		UIKit.Create("UIGridLayout", {
			CellSize = props.CellSize or UDim2.new(0, 150, 0, 150),
			CellPadding = UDim2.new(0, 12, 0, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = scroll,
		})
	else
		UIKit.Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = scroll })
	end
	UIKit.Padding(scroll, 8)
	return scroll
end

-- Progress bar. Returns { Frame, Set(fraction, text) }
function UIKit.ProgressBar(props)
	local frame = UIKit.Create("Frame", {
		Name = props.Name or "Progress",
		Size = props.Size or UDim2.new(1, 0, 0, 26),
		Position = props.Position or UDim2.new(0, 0, 0, 0),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		BackgroundColor3 = props.Background or Color3.fromRGB(60, 60, 80),
		ZIndex = props.ZIndex or 13,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	UIKit.Corner(frame, 999)
	UIKit.Stroke(frame, Theme.StrokeThin)
	local fill = UIKit.Create("Frame", {
		Name = "Fill", Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = (props.ZIndex or 13) + 1, Parent = frame,
	})
	UIKit.Corner(fill, 999)
	UIKit.Gradient(fill, props.Color or Theme.Colors.Green, UIKit.Darken(props.Color or Theme.Colors.Green, 0.75), 90)
	local text = UIKit.Text({ Text = "", TextSize = props.TextSize or 18, Scaled = true, MaxTextSize = props.TextSize or 18, ZIndex = (props.ZIndex or 13) + 2, Parent = frame })
	local api = { Frame = frame }
	function api.Set(fraction, label)
		fraction = math.clamp(fraction or 0, 0, 1)
		UIKit.Tween(fill, { Size = UDim2.new(fraction, 0, 1, 0) }, 0.25, Enum.EasingStyle.Quad)
		text.Text = label or ""
	end
	return api
end

-- Pop animation on any GuiObject with a UIScale (adds one if missing)
function UIKit.Pop(obj, amount)
	local s = obj:FindFirstChildOfClass("UIScale")
	if not s then s = UIKit.Create("UIScale", { Scale = 1, Parent = obj }) end
	s.Scale = 1
	UIKit.Tween(s, { Scale = amount or 1.15 }, 0.1, Enum.EasingStyle.Quad)
	task.delay(0.1, function() UIKit.Tween(s, { Scale = 1 }, 0.25) end)
end

function UIKit.Stars(n)
	if n <= 0 then return "" end
	return string.rep("⭐", math.min(n, 7))
end

return UIKit
