--[[
	Catalog.lua  (ReplicatedStorage.Shared.Catalog)

	The CONTENT of the game: rarities, every present type, mutations, quests, seasons.
	Add a new present by adding one line to Catalog.Presents. The index, unwrap popup,
	announcements and placeholder models all read from here.

	Present fields:
	  Key      unique id (also the name of an optional model in ReplicatedStorage.Models.Presents)
	  Name     display name
	  Rarity   one of Catalog.RarityOrder
	  Income   base cash per second
	  Icon     emoji used by the UI until you add real icons (Image = "rbxassetid://...")
	  Set      "Classic" is always available. Seasonal sets only drop while that season is active.
]]

local Catalog = {}

---------------------------------------------------------------------------
-- RARITIES  (order matters: low -> high)
---------------------------------------------------------------------------
Catalog.RarityOrder = { "Coal", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Catalog.Rarities = {
	Coal      = { Name = "Coal",      Color = Color3.fromRGB(70, 70, 75),    Color2 = Color3.fromRGB(35, 35, 40),   Announce = "none",   Tier = 1, Stars = 0, Weight = 0 },
	Common    = { Name = "Common",    Color = Color3.fromRGB(190, 190, 200), Color2 = Color3.fromRGB(140, 140, 150),Announce = "none",   Tier = 2, Stars = 1, Weight = 0 },
	Uncommon  = { Name = "Uncommon",  Color = Color3.fromRGB(90, 220, 110),  Color2 = Color3.fromRGB(40, 160, 70),  Announce = "none",   Tier = 3, Stars = 2, Weight = 5 },
	Rare      = { Name = "Rare",      Color = Color3.fromRGB(70, 160, 255),  Color2 = Color3.fromRGB(30, 90, 220),  Announce = "self",   Tier = 4, Stars = 3, Weight = 15 },
	Epic      = { Name = "Epic",      Color = Color3.fromRGB(190, 90, 255),  Color2 = Color3.fromRGB(120, 40, 200), Announce = "self",   Tier = 5, Stars = 4, Weight = 40 },
	Legendary = { Name = "Legendary", Color = Color3.fromRGB(255, 180, 40),  Color2 = Color3.fromRGB(230, 110, 20), Announce = "server", Tier = 6, Stars = 5, Weight = 100 },
	Mythic    = { Name = "Mythic",    Color = Color3.fromRGB(255, 70, 110),  Color2 = Color3.fromRGB(180, 20, 70),  Announce = "server", Tier = 7, Stars = 6, Weight = 250 },
	Secret    = { Name = "SECRET",    Color = Color3.fromRGB(40, 40, 60),    Color2 = Color3.fromRGB(255, 255, 255),Announce = "server", Tier = 8, Stars = 7, Weight = 500 },
}

---------------------------------------------------------------------------
-- PRESENTS
---------------------------------------------------------------------------
Catalog.Presents = {
	-- Coal (the troll tier: worth nothing, pops a Jack-in-the-box that knocks you back)
	{ Key = "LumpOfCoal",     Name = "Lump of Coal",       Rarity = "Coal",      Income = 0,     Icon = "🪨", Set = "Classic" },
	{ Key = "SoggySock",      Name = "Soggy Sock",         Rarity = "Coal",      Income = 0,     Icon = "🧦", Set = "Classic" },
	{ Key = "Fruitcake",      Name = "Ancient Fruitcake",  Rarity = "Coal",      Income = 0,     Icon = "🍰", Set = "Classic" },

	-- Common
	{ Key = "TeddyBear",      Name = "Teddy Bear",         Rarity = "Common",    Income = 1,     Icon = "🧸", Set = "Classic" },
	{ Key = "RubberDuck",     Name = "Rubber Duck",        Rarity = "Common",    Income = 1,     Icon = "🦆", Set = "Classic" },
	{ Key = "YoYo",           Name = "Yo-Yo",              Rarity = "Common",    Income = 1.5,   Icon = "🪀", Set = "Classic" },
	{ Key = "ToyCar",         Name = "Toy Car",            Rarity = "Common",    Income = 1.5,   Icon = "🚗", Set = "Classic" },
	{ Key = "SnowGlobe",      Name = "Snow Globe",         Rarity = "Common",    Income = 2,     Icon = "🔮", Set = "Classic" },
	{ Key = "WoolSocks",      Name = "Wool Socks",         Rarity = "Common",    Income = 2,     Icon = "🧦", Set = "Christmas" },

	-- Uncommon
	{ Key = "RobotToy",       Name = "Robot Toy",          Rarity = "Uncommon",  Income = 3,     Icon = "🤖", Set = "Classic" },
	{ Key = "Skateboard",     Name = "Skateboard",         Rarity = "Uncommon",  Income = 4,     Icon = "🛹", Set = "Classic" },
	{ Key = "Gingerbread",    Name = "Gingerbread Man",    Rarity = "Uncommon",  Income = 4,     Icon = "🍪", Set = "Christmas" },
	{ Key = "Nutcracker",     Name = "Nutcracker",         Rarity = "Uncommon",  Income = 5,     Icon = "💂", Set = "Christmas" },
	{ Key = "CocoaMug",       Name = "Hot Cocoa Mug",      Rarity = "Uncommon",  Income = 5,     Icon = "☕", Set = "Christmas" },

	-- Rare
	{ Key = "GameConsole",    Name = "Game Console",       Rarity = "Rare",      Income = 8,    Icon = "🎮", Set = "Classic" },
	{ Key = "Drone",          Name = "Drone",              Rarity = "Rare",      Income = 9,    Icon = "🚁", Set = "Classic" },
	{ Key = "CandyCaneSword", Name = "Candy Cane Sword",   Rarity = "Rare",      Income = 10,    Icon = "🍬", Set = "Christmas" },
	{ Key = "ElfHat",         Name = "Elf Hat",            Rarity = "Rare",      Income = 11,    Icon = "🎩", Set = "Christmas" },
	{ Key = "ReindeerPlush",  Name = "Reindeer Plush",     Rarity = "Rare",      Income = 12,    Icon = "🦌", Set = "Christmas" },

	-- Epic
	{ Key = "GoldenSled",     Name = "Golden Sled",        Rarity = "Epic",      Income = 25,    Icon = "🛷", Set = "Christmas" },
	{ Key = "SnowmanKing",    Name = "Snowman King",       Rarity = "Epic",      Income = 30,    Icon = "⛄", Set = "Christmas" },
	{ Key = "Jetpack",        Name = "Jetpack",            Rarity = "Epic",      Income = 35,    Icon = "🚀", Set = "Classic" },
	{ Key = "IceDragonEgg",   Name = "Ice Dragon Egg",     Rarity = "Epic",      Income = 40,   Icon = "🥚", Set = "Classic" },

	-- Legendary
	{ Key = "SantasBoots",    Name = "Santa's Boots",      Rarity = "Legendary", Income = 80,   Icon = "👢", Set = "Christmas" },
	{ Key = "YetiCub",        Name = "Yeti Cub",           Rarity = "Legendary", Income = 100,   Icon = "🦍", Set = "Classic" },
	{ Key = "FrostPhoenix",   Name = "Frost Phoenix",      Rarity = "Legendary", Income = 120,   Icon = "🐦", Set = "Classic" },
	{ Key = "DiamondSnowflake",Name = "Diamond Snowflake", Rarity = "Legendary", Income = 150,   Icon = "💎", Set = "Christmas" },

	-- Mythic
	{ Key = "RedNoseReindeer",Name = "Red-Nose Reindeer",  Rarity = "Mythic",    Income = 400,  Icon = "🔴", Set = "Christmas" },
	{ Key = "NorthernOrb",    Name = "Northern Lights Orb",Rarity = "Mythic",    Income = 500,  Icon = "🌌", Set = "Classic" },
	{ Key = "KrampusIdol",    Name = "Krampus Idol",       Rarity = "Mythic",    Income = 700,  Icon = "👹", Set = "Christmas" },

	-- Secret
	{ Key = "SantasSleigh",   Name = "Santa's Sleigh",     Rarity = "Secret",    Income = 3000, Icon = "🛷", Set = "Christmas" },
	{ Key = "GrinchHeart",    Name = "The Grinch's Heart", Rarity = "Secret",    Income = 5000, Icon = "💚", Set = "Classic" },

	-- New Year's set (drops Jan 2 -> Feb 1, see Catalog.Seasons)
	{ Key = "PartyPopper",    Name = "Party Popper",       Rarity = "Common",    Income = 2,     Icon = "🎉", Set = "NewYear" },
	{ Key = "DiscoBall",      Name = "Disco Ball",         Rarity = "Uncommon",  Income = 5,     Icon = "🪩", Set = "NewYear" },
	{ Key = "ChampagneTower", Name = "Champagne Tower",    Rarity = "Rare",      Income = 11,    Icon = "🥂", Set = "NewYear" },
	{ Key = "CountdownClock", Name = "Countdown Clock",    Rarity = "Epic",      Income = 35,    Icon = "⏰", Set = "NewYear" },
	{ Key = "GoldenFireworks",Name = "Golden Fireworks",   Rarity = "Legendary", Income = 130,   Icon = "🎆", Set = "NewYear" },
	{ Key = "TimeCapsule",    Name = "Time Capsule",       Rarity = "Mythic",    Income = 600,   Icon = "🕰️", Set = "NewYear" },
	{ Key = "BallDrop",       Name = "The Ball Drop",      Rarity = "Secret",    Income = 4000,  Icon = "🔮", Set = "NewYear" },

	-- Valentine's set (drops Feb 1 -> Mar 1)
	{ Key = "LoveLetter",     Name = "Love Letter",        Rarity = "Common",    Income = 2,     Icon = "💌", Set = "Valentines" },
	{ Key = "ChocolateBox",   Name = "Chocolate Box",      Rarity = "Uncommon",  Income = 5,     Icon = "🍫", Set = "Valentines" },
	{ Key = "HeartTeddy",     Name = "Teddy with Heart",   Rarity = "Rare",      Income = 11,    Icon = "🧸", Set = "Valentines" },
	{ Key = "CupidsBow",      Name = "Cupid's Bow",        Rarity = "Epic",      Income = 35,    Icon = "🏹", Set = "Valentines" },
	{ Key = "DiamondRing",    Name = "Diamond Ring",       Rarity = "Legendary", Income = 140,   Icon = "💍", Set = "Valentines" },
	{ Key = "HeartOfGold",    Name = "Heart of Gold",      Rarity = "Mythic",    Income = 650,   Icon = "💛", Set = "Valentines" },
	{ Key = "CupidHimself",   Name = "Cupid Himself",      Rarity = "Secret",    Income = 4500,  Icon = "👼", Set = "Valentines" },
}

-- Fast lookups (built once)
Catalog.PresentByKey = {}
Catalog.PresentsByRarity = {}
for _, rarity in ipairs(Catalog.RarityOrder) do
	Catalog.PresentsByRarity[rarity] = {}
end
for _, present in ipairs(Catalog.Presents) do
	Catalog.PresentByKey[present.Key] = present
	table.insert(Catalog.PresentsByRarity[present.Rarity], present)
end

---------------------------------------------------------------------------
-- MUTATIONS (one per present, rolled on unwrap). Chance is percent.
-- Event-only mutations have Chance = 0 and are granted by EventService.
---------------------------------------------------------------------------
Catalog.MutationOrder = { "Golden", "Frosted", "CandyCane", "Rainbow", "Galaxy", "Cursed" }
Catalog.Mutations = {
	Golden    = { Name = "Golden",     Multiplier = 1.5, Chance = 8,   Color = Color3.fromRGB(255, 215, 0),   EventBoost = nil },
	Frosted   = { Name = "Frosted",    Multiplier = 2,   Chance = 4,   Color = Color3.fromRGB(170, 230, 255), EventBoost = "Blizzard" },
	CandyCane = { Name = "Candy Cane", Multiplier = 3,   Chance = 2,   Color = Color3.fromRGB(255, 80, 90),   EventBoost = nil },
	Rainbow   = { Name = "Rainbow",    Multiplier = 6,   Chance = 0.9, Color = Color3.fromRGB(255, 120, 255), EventBoost = "Aurora" },
	Galaxy    = { Name = "Galaxy",     Multiplier = 10,  Chance = 0.1, Color = Color3.fromRGB(110, 60, 255),  EventBoost = nil },
	Cursed    = { Name = "Cursed",     Multiplier = 4,   Chance = 0,   Color = Color3.fromRGB(120, 0, 30),    EventBoost = nil },
}

---------------------------------------------------------------------------
-- TRAITS (stackable flags on a present; each adds a flat % to its value)
---------------------------------------------------------------------------
Catalog.Traits = {
	Gifted  = { Name = "Wrapped with Love", Bonus = 0.10, Icon = "💝" },
	Friends = { Name = "Best Friends",      Bonus = 0.10, Icon = "🤝" },
	Stolen  = { Name = "Hot Goods",         Bonus = 0.05, Icon = "🥷" },
	Grinch  = { Name = "Grinch Loot",       Bonus = 0.15, Icon = "💚" },
}

---------------------------------------------------------------------------
-- DAILY QUESTS (3 are picked per day). Stat keys are fired by the server:
--   Buy, Unwrap, UnwrapRare (Rare+), UnwrapEpic (Epic+), Steal, Hit, GrinchTag, Collect (cash), Train (strength), Gift, Lock
---------------------------------------------------------------------------
Catalog.Quests = {
	{ Id = "buy5",        Text = "Buy 5 boxes",                      Stat = "Buy",        Goal = 5,     Reward = { Cash = 500,   Snowflakes = 5 } },
	{ Id = "buy20",       Text = "Buy 20 boxes",                     Stat = "Buy",        Goal = 20,    Reward = { Cash = 2500,  Snowflakes = 10 } },
	{ Id = "unwrap10",    Text = "Unwrap 10 presents",               Stat = "Unwrap",     Goal = 10,    Reward = { Cash = 1000,  Snowflakes = 5 } },
	{ Id = "rare3",       Text = "Unwrap 3 Rare or better",          Stat = "UnwrapRare", Goal = 3,     Reward = { Cash = 2000,  Snowflakes = 8 } },
	{ Id = "epic1",       Text = "Unwrap an Epic or better",         Stat = "UnwrapEpic", Goal = 1,     Reward = { Cash = 5000,  Snowflakes = 12 } },
	{ Id = "steal3",      Text = "Steal 3 presents",                 Stat = "Steal",      Goal = 3,     Reward = { Cash = 2500,  Snowflakes = 10 } },
	{ Id = "steal10",     Text = "Steal 10 presents",                Stat = "Steal",      Goal = 10,    Reward = { Cash = 10000, Snowflakes = 20 } },
	{ Id = "hit5",        Text = "Whack 5 thieves",                  Stat = "Hit",        Goal = 5,     Reward = { Cash = 1500,  Snowflakes = 6 } },
	{ Id = "grinch1",     Text = "Hit the Grinch with a snowball",   Stat = "GrinchTag",  Goal = 1,     Reward = { Cash = 3000,  Snowflakes = 10 } },
	{ Id = "collect5k",   Text = "Collect $5,000 from your base",    Stat = "Collect",    Goal = 5000,  Reward = { Cash = 1500,  Snowflakes = 5 } },
	{ Id = "train100",    Text = "Gain 100 Strength",                Stat = "Train",      Goal = 100,   Reward = { Cash = 2000,  Snowflakes = 6 } },
	{ Id = "gift1",       Text = "Gift a present to someone",        Stat = "Gift",       Goal = 1,     Reward = { Cash = 2000,  Snowflakes = 10 } },
	{ Id = "lock3",       Text = "Lock your base 3 times",           Stat = "Lock",       Goal = 3,     Reward = { Cash = 800,   Snowflakes = 4 } },
	{ Id = "unwrap25",    Text = "Unwrap 25 presents",               Stat = "Unwrap",     Goal = 25,    Reward = { Cash = 4000,  Snowflakes = 12 } },
	{ Id = "epic3",       Text = "Unwrap 3 Epic or better",          Stat = "UnwrapEpic", Goal = 3,     Reward = { Cash = 12000, Snowflakes = 20 } },
	{ Id = "steal5",      Text = "Steal 5 presents",                 Stat = "Steal",      Goal = 5,     Reward = { Cash = 5000,  Snowflakes = 14 } },
	{ Id = "hit10",       Text = "Whack 10 thieves",                 Stat = "Hit",        Goal = 10,    Reward = { Cash = 4000,  Snowflakes = 12 } },
	{ Id = "grinch3",     Text = "Hit the Grinch 3 times",           Stat = "GrinchTag",  Goal = 3,     Reward = { Cash = 8000,  Snowflakes = 20 } },
	{ Id = "collect25k",  Text = "Collect $25,000 from your base",   Stat = "Collect",    Goal = 25000, Reward = { Cash = 6000,  Snowflakes = 12 } },
	{ Id = "train300",    Text = "Gain 300 Strength",                Stat = "Train",      Goal = 300,   Reward = { Cash = 6000,  Snowflakes = 14 } },
	{ Id = "gift2",       Text = "Gift 2 presents to other players", Stat = "Gift",       Goal = 2,     Reward = { Cash = 5000,  Snowflakes = 16 } },
	{ Id = "lock5",       Text = "Lock your base 5 times",           Stat = "Lock",       Goal = 5,     Reward = { Cash = 1500,  Snowflakes = 6 } },
}

---------------------------------------------------------------------------
-- SEASONS. The active season decides which present Set drops, the calendar theme,
-- and the on-screen countdown. Dates are UTC (year, month, day).
---------------------------------------------------------------------------
Catalog.Seasons = {
	{ Key = "Christmas",  Name = "Christmas",      Set = "Christmas",  Start = { 2026, 11, 20 }, End = { 2027, 1, 2 },
	  Color = Color3.fromRGB(255, 70, 70),   Icon = "🎄", CalendarName = "Advent Calendar" },
	{ Key = "NewYear",    Name = "New Year's",     Set = "NewYear",    Start = { 2027, 1, 2 },  End = { 2027, 2, 1 },
	  Color = Color3.fromRGB(255, 215, 0),   Icon = "🎆", CalendarName = "Party Calendar" },
	{ Key = "Valentines", Name = "Valentine's",    Set = "Valentines", Start = { 2027, 2, 1 },  End = { 2027, 3, 1 },
	  Color = Color3.fromRGB(255, 100, 160), Icon = "💘", CalendarName = "Love Calendar" },
}
-- When no season is active, the game uses this:
Catalog.DefaultSeason = { Key = "Classic", Name = "Present Season", Set = "Classic", Color = Color3.fromRGB(90, 170, 255), Icon = "🎁", CalendarName = "Daily Calendar" }

---------------------------------------------------------------------------
-- SNOWFLAKE SHOP (event currency sink; gives players a reason to come back)
---------------------------------------------------------------------------
Catalog.SnowflakeShop = {
	{ Key = "SF_Medium", Name = "Medium Box",       Cost = 15,  Give = { Box = "Medium" } },
	{ Key = "SF_Large",  Name = "Large Box",        Cost = 50,  Give = { Box = "Large" } },
	{ Key = "SF_Huge",   Name = "Huge Box",         Cost = 150, Give = { Box = "Huge" } },
	{ Key = "SF_Sack",   Name = "Santa's Sack",     Cost = 300, Give = { Box = "Sack" } },
	{ Key = "SF_Luck",   Name = "Luck Potion (30m)",Cost = 40,  Give = { Luck = 30 } },
	{ Key = "SF_Slot",   Name = "+1 Base Slot",     Cost = 250, Give = { Slot = 1 } },
	{ Key = "SF_Paint",  Name = "Repaint Base",     Cost = 40,  Give = { Paint = true } },
}

return Catalog
