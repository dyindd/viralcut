--[[
	Icons.lua  (ReplicatedStorage.Shared.Icons)
	Image asset IDs for the UI. 0 = not uploaded yet (the UI falls back to the emoji).
	Generate the images with docs/IMAGE_PROMPTS.md, upload them in Studio (Asset Manager > Images),
	right-click > Copy ID, paste the number here. Icons.Get("Presents", "TeddyBear") returns
	"rbxassetid://<id>" or nil.
]]

local Icons = {}

-- side / bottom buttons (files ui_*.png)
Icons.UI = {
	Rewards = 0,
	Rebirth = 0,
	Gift = 0,
	Lock = 0,
	Base = 0,
	Shop = 0,
	Index = 0,
	Quests = 0,
	Traps = 0,
	Settings = 0,
}

-- currency pills (cur_*.png)
Icons.Currency = {
	Cash = 0,
	Snowflakes = 0,
	Strength = 0,
}

-- box tiers (box_*.png)
Icons.Boxes = {
	Small = 0,
	Medium = 0,
	Large = 0,
	Huge = 0,
	Giant = 0,
	Sack = 0,
	Gift = 0,
}

-- traps (trap_*.png)
Icons.Traps = {
	IcePatch = 0,
	Mistletoe = 0,
	ElfGuard = 0,
}

-- mutation badges (mut_*.png)
Icons.Mutations = {
	Golden = 0,
	Frosted = 0,
	CandyCane = 0,
	Rainbow = 0,
	Galaxy = 0,
	Cursed = 0,
}

-- gamepasses (pass_*.png)
Icons.Passes = {
	VIP = 0,
	ExtraSlots = 0,
	Speed = 0,
	AutoCollect = 0,
	Strong = 0,
}

-- developer products (prod_*.png)
Icons.Products = {
	Cash1 = 0,
	Cash2 = 0,
	Cash3 = 0,
	Snowflakes1 = 0,
	LuckPotion = 0,
	Protein = 0,
	LockExtend = 0,
	GrinchTurn = 0,
}

-- every collectible (present_<Key>.png); keys match Catalog.Presents
Icons.Presents = {
	LumpOfCoal = 0,
	SoggySock = 0,
	Fruitcake = 0,
	TeddyBear = 0,
	RubberDuck = 0,
	YoYo = 0,
	ToyCar = 0,
	SnowGlobe = 0,
	WoolSocks = 0,
	RobotToy = 0,
	Skateboard = 0,
	Gingerbread = 0,
	Nutcracker = 0,
	CocoaMug = 0,
	GameConsole = 0,
	Drone = 0,
	CandyCaneSword = 0,
	ElfHat = 0,
	ReindeerPlush = 0,
	GoldenSled = 0,
	SnowmanKing = 0,
	Jetpack = 0,
	IceDragonEgg = 0,
	SantasBoots = 0,
	YetiCub = 0,
	FrostPhoenix = 0,
	DiamondSnowflake = 0,
	RedNoseReindeer = 0,
	NorthernOrb = 0,
	KrampusIdol = 0,
	SantasSleigh = 0,
	GrinchHeart = 0,
	PartyPopper = 0,
	DiscoBall = 0,
	ChampagneTower = 0,
	CountdownClock = 0,
	GoldenFireworks = 0,
	TimeCapsule = 0,
	BallDrop = 0,
	LoveLetter = 0,
	ChocolateBox = 0,
	HeartTeddy = 0,
	CupidsBow = 0,
	DiamondRing = 0,
	HeartOfGold = 0,
	CupidHimself = 0,
}

-- seamless wrapping-paper textures (wrapping_*.png); applied to belt boxes when set
Icons.Textures = {
	CandyCane = 0,
	Hearts = 0,
	PolkaDots = 0,
	Snowflakes = 0,
}
-- which pattern each box tier wears (nil = plain color)
Icons.BoxWrap = { Small = "CandyCane", Medium = "Snowflakes", Large = "PolkaDots", Huge = "Hearts", Giant = "PolkaDots", Gift = "Hearts" }

-- Tool hotbar pictures (Tool.TextureId). 0 = use the alias below (reuses existing art)
Icons.Tools = { Bat = 0, Snowball = 0, Barbell = 0 }
Icons.Alias = {
	Tools = { Bat = { "Presents", "CandyCaneSword" }, Snowball = { "Currency", "Snowflakes" }, Barbell = { "Currency", "Strength" } },
}

-- file-name prefix per category (matches assets/images/*.png and the ReplicatedStorage.Icons folder)
Icons.Prefix = { UI = "ui_", Currency = "cur_", Boxes = "box_", Traps = "trap_", Mutations = "mut_", Passes = "pass_", Products = "prod_", Presents = "present_", Textures = "wrapping_", Tools = "tool_" }

-- ZERO-TYPING OPTION: in Studio, Bulk Import the PNGs (Asset Manager > Images), select them all,
-- right-click > Insert, then drag the inserted Decals into a Folder named "Icons" in ReplicatedStorage.
-- Icons.Get finds them by name (ui_Rewards, present_TeddyBear, ...). Decals, ImageLabels, StringValues
-- and IntValues all work.
local folderCache = {}
local function fromFolder(category, key)
	local ok, folder = pcall(function()
		return game:GetService("ReplicatedStorage"):FindFirstChild("Icons")
	end)
	if not ok or not folder then return nil end
	local name = (Icons.Prefix[category] or "") .. tostring(key)
	if folderCache[name] ~= nil then return folderCache[name] or nil end
	local obj = folder:FindFirstChild(name) or folder:FindFirstChild(name .. ".png")
	local result = nil
	if obj then
		if obj:IsA("Decal") then
			result = obj.Texture ~= "" and obj.Texture or nil
		elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
			result = obj.Image ~= "" and obj.Image or nil
		elseif obj:IsA("StringValue") then
			result = obj.Value ~= "" and obj.Value or nil
		elseif obj:IsA("IntValue") or obj:IsA("NumberValue") then
			result = obj.Value > 0 and ("rbxassetid://" .. math.floor(obj.Value)) or nil
		end
	end
	folderCache[name] = result or false
	return result
end

function Icons.Get(category, key)
	local group = Icons[category]
	local id = group and group[key]
	if type(id) == "number" and id > 0 then
		return "rbxassetid://" .. id
	end
	local fromF = fromFolder(category, key)
	if fromF then return fromF end
	local alias = Icons.Alias[category] and Icons.Alias[category][key]
	if alias then
		return Icons.Get(alias[1], alias[2])
	end
	return nil
end

function Icons.ClearCache()
	folderCache = {}
end

return Icons
