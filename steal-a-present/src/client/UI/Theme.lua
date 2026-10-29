--[[
	Theme.lua - the "chunky cartoon" look (Pet Simulator 99 style):
	white rounded panels, thick dark outlines, Fredoka font with black text strokes,
	candy-colored gradient buttons, pink X close buttons, rainbow for the rarest stuff.
]]

local Theme = {}

Theme.Font = Enum.Font.FredokaOne
Theme.FontBody = Enum.Font.FredokaOne

Theme.Colors = {
	Panel = Color3.fromRGB(255, 255, 255),
	PanelInner = Color3.fromRGB(240, 244, 252),
	Outline = Color3.fromRGB(38, 38, 58),
	TextDark = Color3.fromRGB(45, 45, 70),
	TextLight = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(130, 135, 160),
	Shadow = Color3.fromRGB(0, 0, 0),

	Green = Color3.fromRGB(96, 228, 96),
	GreenDark = Color3.fromRGB(52, 178, 60),
	Red = Color3.fromRGB(255, 82, 110),
	RedDark = Color3.fromRGB(210, 40, 80),
	Blue = Color3.fromRGB(86, 170, 255),
	BlueDark = Color3.fromRGB(40, 110, 230),
	Yellow = Color3.fromRGB(255, 208, 64),
	YellowDark = Color3.fromRGB(240, 150, 30),
	Purple = Color3.fromRGB(190, 110, 255),
	PurpleDark = Color3.fromRGB(130, 60, 220),
	Pink = Color3.fromRGB(255, 120, 200),
	PinkDark = Color3.fromRGB(220, 70, 160),
	Orange = Color3.fromRGB(255, 150, 70),
	OrangeDark = Color3.fromRGB(230, 100, 30),
	Cyan = Color3.fromRGB(100, 230, 240),
	CyanDark = Color3.fromRGB(40, 170, 200),
	Grey = Color3.fromRGB(200, 205, 220),
	GreyDark = Color3.fromRGB(140, 145, 165),
	Cash = Color3.fromRGB(120, 230, 110),
	Snowflake = Color3.fromRGB(150, 220, 255),
}

Theme.Rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 190, 70)),
	ColorSequenceKeypoint.new(0.34, Color3.fromRGB(120, 240, 110)),
	ColorSequenceKeypoint.new(0.51, Color3.fromRGB(90, 200, 255)),
	ColorSequenceKeypoint.new(0.68, Color3.fromRGB(170, 110, 255)),
	ColorSequenceKeypoint.new(0.85, Color3.fromRGB(255, 120, 220)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 90, 90)),
})

Theme.Corner = 14
Theme.CornerSmall = 10
Theme.Stroke = 3.5
Theme.StrokeThin = 2.5
Theme.TextStroke = 2

-- Sizes (in "design pixels" before UIScale)
Theme.SideButton = 92
Theme.BottomButton = 86
Theme.PanelWidth = 860
Theme.PanelHeight = 560

return Theme
