--[[
	Config.lua  (ReplicatedStorage.Shared.Config)

	EVERY tunable number in the game lives here. Balance the game by editing this file,
	never by digging through the logic scripts.

	Sections:
	  1. Core / data
	  2. Economy (cash, income, offline)
	  3. Conveyor + Box tiers (what you buy, hidden rarity until unwrap)
	  4. Carrying + Strength
	  5. Bases / plots / lock
	  6. Stealing + combat
	  7. Grinch Mode
	  8. Server events (weather-style)
	  9. Rebirth
	 10. Retention (streak calendar, playtime gift, daily quests, index rewards)
	 11. Gifting (co-play)
	 12. Traps
	 13. Monetization (fill in your IDs from the Creator Dashboard)
	 14. Sounds
	 15. Rate limits / anti-exploit
]]

local Config = {}

---------------------------------------------------------------------------
-- 1. CORE
---------------------------------------------------------------------------
Config.GameName = "Steal a Present"
Config.DataStoreName = "SAP_Profiles"      -- change this to WIPE everyone's data (new store)
Config.ReceiptStoreName = "SAP_Receipts"
Config.SchemaVersion = 1                   -- bump + add a migration in DataService when the schema changes
Config.AutosaveInterval = 120              -- seconds
Config.SessionLockTimeout = 600            -- seconds before a stale session lock is ignored
Config.MaxPlayersPerServer = 8             -- also set this in Studio: Game Settings > Places > Max Players

---------------------------------------------------------------------------
-- 2. ECONOMY
---------------------------------------------------------------------------
Config.StartingCash = 50
Config.StartingSnowflakes = 0
Config.SellSeconds = 120                   -- selling a present pays this many seconds of its income
Config.IncomeTickSeconds = 1               -- how often present income is added to the base's "pile"
Config.CollectRadius = 14                  -- how close to the Collect pad you must stand
Config.OfflineEarnings = {
	Enabled = true,
	MaxSeconds = 8 * 3600,                 -- cap: 8 hours of offline income
	Rate = 0.5,                            -- offline income is 50% of online income
}

---------------------------------------------------------------------------
-- 3. CONVEYOR + BOX TIERS
--    Players never see the rarity on the belt. They choose a BOX SIZE.
--    Bigger box = better odds, higher price, more Strength needed to carry.
--    Odds are in percent per tier and should add up to 100 (checked by tests).
---------------------------------------------------------------------------
Config.Conveyor = {
	Length = 140,              -- studs, straight belt through the middle of the hub
	Speed = 5,                 -- studs/sec the boxes travel
	SpawnInterval = 2.2,       -- seconds between boxes
	MaxOnBelt = 16,
	BoxGap = 7,                -- minimum studs between boxes
}

-- Which tiers can spawn and how often (weights, not percents)
Config.BoxTiers = {
	{
		Key = "Small", Name = "Small Box", Price = 25, Strength = 0, Weight = 0,
		SpawnWeight = 50, Size = 2.2, Color = Color3.fromRGB(240, 90, 100),
		Odds = { Coal = 15, Common = 62, Uncommon = 19, Rare = 3.6, Epic = 0.4 },
	},
	{
		Key = "Medium", Name = "Medium Box", Price = 200, Strength = 15, Weight = 10,
		SpawnWeight = 28, Size = 2.8, Color = Color3.fromRGB(90, 170, 255),
		Odds = { Coal = 10, Common = 44, Uncommon = 32, Rare = 11.5, Epic = 2.3, Legendary = 0.2 },
	},
	{
		Key = "Large", Name = "Large Box", Price = 1500, Strength = 75, Weight = 40,
		SpawnWeight = 14, Size = 3.5, Color = Color3.fromRGB(120, 220, 120),
		Odds = { Coal = 6, Common = 22, Uncommon = 38, Rare = 25, Epic = 7.8, Legendary = 1.15, Mythic = 0.05 },
	},
	{
		Key = "Huge", Name = "Huge Box", Price = 12000, Strength = 400, Weight = 150,
		SpawnWeight = 6, Size = 4.4, Color = Color3.fromRGB(200, 120, 255),
		Odds = { Coal = 3, Common = 10, Uncommon = 30, Rare = 34, Epic = 17, Legendary = 5.4, Mythic = 0.58, Secret = 0.02 },
	},
	{
		Key = "Giant", Name = "GIANT Box", Price = 100000, Strength = 2000, Weight = 600,
		SpawnWeight = 2, Size = 5.6, Color = Color3.fromRGB(255, 200, 60),
		Odds = { Common = 4, Uncommon = 14, Rare = 30, Epic = 32, Legendary = 16, Mythic = 3.7, Secret = 0.3 },
	},
	-- Event-only tiers (SpawnWeight 0 = never on the belt; given by events/rewards)
	{
		Key = "Sack", Name = "Santa's Sack", Price = 0, Strength = 0, Weight = 20,
		SpawnWeight = 0, Size = 3.2, Color = Color3.fromRGB(255, 60, 60),
		Odds = { Uncommon = 25, Rare = 40, Epic = 25, Legendary = 8.5, Mythic = 1.4, Secret = 0.1 },
	},
	{
		Key = "Gift", Name = "Playtime Gift", Price = 0, Strength = 0, Weight = 0,
		SpawnWeight = 0, Size = 3.0, Color = Color3.fromRGB(255, 150, 220),
		Odds = { Rare = 65, Epic = 28, Legendary = 6.5, Mythic = 0.5 },
	},
}

---------------------------------------------------------------------------
-- 4. CARRYING + STRENGTH
---------------------------------------------------------------------------
Config.Carry = {
	BaseWalkSpeed = 16,
	MinWalkSpeed = 7,
	-- speed = BaseWalkSpeed * (1 - Penalty)   where Penalty = Weight / (Weight + Strength + Softness) * MaxPenalty
	MaxPenalty = 0.6,
	Softness = 12,
	JumpWhileCarrying = true,
	DropOnDeath = true,
}

Config.Strength = {
	GainPerSecond = 1,            -- base strength per second on the training bench
	RebirthBonusPerLevel = 0.5,   -- +50% training speed per rebirth
	ProteinMultiplier = 2,        -- dev product "Protein Shake" (temporary)
	ProteinDuration = 15 * 60,
}

---------------------------------------------------------------------------
-- 5. BASES / PLOTS / LOCK
---------------------------------------------------------------------------
Config.Plots = {
	Count = 8,                   -- number of bases in the ring (>= MaxPlayersPerServer)
	RingRadius = 150,            -- distance from hub center
	BaseSize = Vector3.new(44, 1, 48),
	StartingSlots = 6,
	MaxSlots = 20,
	SlotsPerRebirth = 1,
	SlotsPerRow = 5,
	SlotSpacing = 7,
}

Config.Lock = {
	Duration = 60,               -- seconds the shield stays up
	Cooldown = 180,              -- seconds before you can lock again (starts when the lock ends)
	VIPDurationBonus = 30,       -- VIP gamepass adds this many seconds
	ExtendProductSeconds = 300,  -- dev product "Lock Extender" adds this
}

---------------------------------------------------------------------------
-- 6. STEALING + COMBAT
---------------------------------------------------------------------------
Config.Steal = {
	PromptHoldSeconds = 1.5,     -- hold E this long to grab a present from someone's base
	InteractDistance = 10,       -- max studs from the present (server-validated)
	StolenSpeedPenaltyBonus = 0.1,  -- extra 10% slow when carrying a STOLEN present
	ReturnOnHit = true,          -- when a thief is hit, the present teleports back to the owner's base
	ThiefRagdollSeconds = 1.5,
}

Config.Combat = {
	BatName = "Candy Cane Bat",
	BatDamage = 0,               -- we don't kill players, we knock them back + make them drop
	BatCooldown = 1.0,
	BatRange = 9,
	KnockbackForce = 60,
	SnowballName = "Snowball",
	SnowballSpeed = 90,
	SnowballCooldown = 0.6,
	SnowballLifetime = 3,
}

---------------------------------------------------------------------------
-- 7. GRINCH MODE  (signature chaos event)
---------------------------------------------------------------------------
Config.Grinch = {
	Enabled = true,
	Interval = 8 * 60,           -- seconds between Grinch rounds
	WarningSeconds = 10,
	Duration = 60,
	WalkSpeed = 30,
	CanStealLocked = true,
	HitsToDefeat = 3,            -- snowball hits needed to end the Grinch early
	-- Rewards scale with the player's rebirth count: Base * (1 + Rebirths * RebirthScale)
	TagReward = 600,             -- cash to the player who lands the FINAL snowball
	AssistReward = 150,          -- cash per snowball hit
	SurviveReward = 3000,        -- cash to the Grinch if they survive the full duration
	SurviveBoxTier = "Huge",     -- plus a free box of this tier
	RebirthScale = 0.5,
	MinPlayers = 2,
	SnowflakesForTag = 5,
	SnowflakesForSurvive = 15,
}

---------------------------------------------------------------------------
-- 8. SERVER EVENTS (random "weather" style events the whole server shares)
---------------------------------------------------------------------------
Config.Events = {
	Enabled = true,
	MinInterval = 7 * 60,
	MaxInterval = 12 * 60,
	List = {
		{ Key = "Blizzard", Name = "BLIZZARD!", Duration = 90, Weight = 30,
		  Color = Color3.fromRGB(150, 220, 255), Description = "Frosted mutation chance x10!" },
		{ Key = "Aurora", Name = "AURORA LIGHTS", Duration = 90, Weight = 20,
		  Color = Color3.fromRGB(120, 255, 200), Description = "Rainbow mutation chance x10!" },
		{ Key = "SleighDrop", Name = "SANTA'S SLEIGH DROP", Duration = 60, Weight = 30,
		  Color = Color3.fromRGB(255, 80, 80), Description = "Free Santa's Sacks are raining down!" },
		{ Key = "KrampusNight", Name = "KRAMPUS NIGHT", Duration = 120, Weight = 15,
		  Color = Color3.fromRGB(180, 40, 60), Description = "Locks are HALF as long. Cursed presents can appear." },
		{ Key = "LuckyHour", Name = "LUCKY HOUR", Duration = 120, Weight = 20,
		  Color = Color3.fromRGB(255, 220, 80), Description = "Everyone has 2x luck!" },
		{ Key = "DoubleCash", Name = "DOUBLE CASH", Duration = 120, Weight = 20,
		  Color = Color3.fromRGB(120, 255, 120), Description = "All presents earn 2x for 2 minutes!" },
		{ Key = "MutationMadness", Name = "MUTATION MADNESS", Duration = 90, Weight = 15,
		  Color = Color3.fromRGB(255, 120, 255), Description = "Every mutation is 3x more likely!" },
	},
	DoubleCash = { Multiplier = 2 },
	MutationMadness = { Multiplier = 3 },
	SleighDrop = { SackCount = 10, DropHeight = 60, Radius = 90 },
	KrampusNight = { LockMultiplier = 0.5, CursedChance = 15 }, -- percent chance an unwrap is Cursed
	LuckyHour = { LuckMultiplier = 2 },
	MutationBoost = 10,
}

---------------------------------------------------------------------------
-- 9. REBIRTH
---------------------------------------------------------------------------
Config.Rebirth = {
	BaseCost = 100000,
	CostMultiplier = 4,          -- cost(n) = BaseCost * CostMultiplier ^ n   (n = current rebirths)
	IncomeBonusPerRebirth = 0.5, -- x1.5, x2.0, x2.5 ...
	KeepStrength = true,
	KeepIndex = true,
	SnowflakesReward = 25,
}

---------------------------------------------------------------------------
-- 10. RETENTION
---------------------------------------------------------------------------
-- Streak calendar: 25 days (an Advent calendar in December, re-skinned by season).
-- Miss a day and the streak resets to day 1. Reward types: Cash, Snowflakes, Box, Luck.
Config.Streak = {
	Days = 25,
	ResetIfMissed = true,
	Rewards = {
		{ Type = "Cash", Amount = 250 },            -- day 1
		{ Type = "Cash", Amount = 500 },
		{ Type = "Box", Tier = "Medium" },
		{ Type = "Snowflakes", Amount = 10 },
		{ Type = "Cash", Amount = 1500 },
		{ Type = "Box", Tier = "Large" },
		{ Type = "Luck", Minutes = 30 },            -- day 7
		{ Type = "Cash", Amount = 4000 },
		{ Type = "Snowflakes", Amount = 20 },
		{ Type = "Box", Tier = "Large" },
		{ Type = "Cash", Amount = 8000 },
		{ Type = "Snowflakes", Amount = 25 },
		{ Type = "Box", Tier = "Huge" },
		{ Type = "Luck", Minutes = 60 },            -- day 14
		{ Type = "Cash", Amount = 15000 },
		{ Type = "Snowflakes", Amount = 30 },
		{ Type = "Box", Tier = "Huge" },
		{ Type = "Cash", Amount = 25000 },
		{ Type = "Snowflakes", Amount = 40 },
		{ Type = "Box", Tier = "Huge" },
		{ Type = "Luck", Minutes = 120 },           -- day 21
		{ Type = "Cash", Amount = 50000 },
		{ Type = "Snowflakes", Amount = 60 },
		{ Type = "Box", Tier = "Giant" },
		{ Type = "Box", Tier = "Giant" },           -- day 25: big finale
	},
}

Config.PlaytimeGift = {
	IntervalSeconds = 30 * 60,   -- every 30 minutes of play: a free "Gift" tier box (Rare or better)
	Tier = "Gift",
}

Config.DailyQuests = {
	Count = 3,
	ResetHourUTC = 0,
}

Config.Index = {
	-- cash reward for unlocking EVERY present of a rarity
	SetRewards = { Common = 500, Uncommon = 2000, Rare = 8000, Epic = 30000, Legendary = 100000, Mythic = 500000, Secret = 5000000 },
	SnowflakesPerNewEntry = 2,
}

Config.Luck = {
	-- "Luck" multiplies the odds of Rare and better, then re-normalises.
	PotionMultiplier = 2,
	PotionDuration = 30 * 60,
	VIPMultiplier = 1.25,
}

---------------------------------------------------------------------------
-- 11. GIFTING (co-play signal: give a present to another player in your server)
---------------------------------------------------------------------------
Config.Gift = {
	Enabled = true,
	Cooldown = 5 * 60,           -- seconds between gifts per player
	MaxPerDay = 5,
	ValueBonus = 0.10,           -- gifted presents earn +10% forever ("Wrapped with Love" trait)
	FriendBonus = 0.10,          -- +10% more if the two players are Roblox friends
	SnowflakesForBoth = 3,
}

---------------------------------------------------------------------------
-- 12. TRAPS (defend your base; bought with cash, placed in trap sockets)
---------------------------------------------------------------------------
Config.Traps = {
	Sockets = 3,
	List = {
		{ Key = "IcePatch", Name = "Ice Patch", Price = 2500, Description = "Thieves slip and slow down for 3s.",
		  Color = Color3.fromRGB(170, 230, 255), SlowMultiplier = 0.4, SlowSeconds = 3, Cooldown = 4 },
		{ Key = "Mistletoe", Name = "Mistletoe Snare", Price = 12000, Description = "Freezes thieves in place for 2s.",
		  Color = Color3.fromRGB(80, 200, 90), FreezeSeconds = 2, Cooldown = 8 },
		{ Key = "ElfGuard", Name = "Elf Guard", Price = 60000, Description = "Whacks nearby thieves every 6s. They drop the present!",
		  Color = Color3.fromRGB(255, 120, 120), Range = 18, Cooldown = 6 },
	},
}

---------------------------------------------------------------------------
-- 13. MONETIZATION  -- put your real IDs here (0 = disabled/hidden)
---------------------------------------------------------------------------
Config.Monetization = {
	Gamepasses = {
		VIP        = { Id = 0, Name = "VIP",          Price = 399, Description = "2x cash from presents, longer base lock, +25% luck, VIP tag!" },
		ExtraSlots = { Id = 0, Name = "+4 Base Slots", Price = 299, Description = "Four more present slots at your base." },
		Speed      = { Id = 0, Name = "Fast Legs",    Price = 199, Description = "+25% walk speed, forever." },
		AutoCollect= { Id = 0, Name = "Auto Collect", Price = 349, Description = "Your base cash pile is collected automatically." },
		Strong     = { Id = 0, Name = "Super Strength",Price = 249, Description = "Train 2x faster and carry heavy boxes easier." },
	},
	Products = {
		Cash1      = { Id = 0, Name = "1,000 Cash",     Price = 49,  Cash = 1000 },
		Cash2      = { Id = 0, Name = "10,000 Cash",    Price = 199, Cash = 10000 },
		Cash3      = { Id = 0, Name = "100,000 Cash",   Price = 999, Cash = 100000 },
		LuckPotion = { Id = 0, Name = "Luck Potion (30m)", Price = 99 },
		Protein    = { Id = 0, Name = "Protein Shake (15m)", Price = 79 },
		LockExtend = { Id = 0, Name = "Lock Extender (+5m)", Price = 59 },
		GrinchTurn = { Id = 0, Name = "Become the Grinch", Price = 149 },
		Snowflakes1= { Id = 0, Name = "100 Snowflakes", Price = 149, Snowflakes = 100 },
	},
	VIPCashMultiplier = 2,
	SpeedMultiplier = 1.25,
	ExtraSlotsAmount = 4,
}

---------------------------------------------------------------------------
-- 14. SOUNDS  (0 = silent). Replace with your own uploaded sound IDs.
---------------------------------------------------------------------------
Config.Sounds = {
	Click = 6895079853,
	Pop = 6026984224,
	Unwrap = 1837838620,
	Rare = 4612375233,
	Legendary = 1837863509,
	Cash = 8358558096,
	Hit = 5765979244,
	GrinchStart = 1839236211,
	Whoosh = 2767081, 
	Music = 1837879082,
	MusicVolume = 0.25,
}

---------------------------------------------------------------------------
-- 16. REDEEM CODES  (share these on TikTok / YouTube; each player can use each code once)
--     Reward keys: Cash, Snowflakes, Box (tier key), Luck (minutes). Expires = { year, month, day } UTC (optional)
---------------------------------------------------------------------------
Config.Codes = {
	LAUNCH   = { Cash = 500, Snowflakes = 10 },
	XMAS2026 = { Box = "Large", Snowflakes = 25, Expires = { 2027, 1, 2 } },
	GRINCH   = { Luck = 30 },
	TIKTOK   = { Cash = 1000, Snowflakes = 15 },
	FREEBOX  = { Box = "Medium" },
}

---------------------------------------------------------------------------
-- 17. TUTORIAL (first-join objectives; finishing all of them pays the reward)
---------------------------------------------------------------------------
Config.Tutorial = {
	Enabled = true,
	Steps = {
		{ Key = "Buy",     Text = "Buy a box from the conveyor in the middle (hold E)" },
		{ Key = "Unwrap",  Text = "Carry it to the GREEN pad at your base to unwrap it" },
		{ Key = "Collect", Text = "Touch the GOLD pad at your base to collect cash" },
		{ Key = "Lock",    Text = "Lock your base so nobody can steal (press L)" },
		{ Key = "Train",   Text = "Train at your bench so you can carry bigger boxes" },
		{ Key = "Steal",   Text = "Steal a present from another base and bring it home!" },
	},
	Reward = { Box = "Large", Snowflakes = 30 },
}

---------------------------------------------------------------------------
-- 18. LEADERBOARDS (global, OrderedDataStore)
---------------------------------------------------------------------------
Config.Leaderboard = {
	Enabled = true,
	WriteInterval = 60,      -- seconds between score uploads per server
	ReadInterval = 90,       -- seconds between board refreshes
	Top = 10,
	Boards = {
		{ Key = "Cash",     Store = "SAP_LB_Cash",     Title = "💵 Most Cash Earned", Stat = "CashCollected" },
		{ Key = "Rebirths", Store = "SAP_LB_Rebirths", Title = "🔄 Most Rebirths",    Stat = "Rebirths" },
	},
}

---------------------------------------------------------------------------
-- 19. ANTI-CHEAT
---------------------------------------------------------------------------
Config.AntiCheat = {
	Enabled = true,
	MaxTravelSpeed = 60,     -- studs/second; a deposit that implies faster travel than this is refused (teleport exploits)
}

---------------------------------------------------------------------------
-- 15. RATE LIMITS / ANTI-EXPLOIT
---------------------------------------------------------------------------
Config.RateLimits = {
	Default = { Calls = 10, Per = 5 },        -- max 10 calls per 5 seconds per remote per player
	BuyBox = { Calls = 4, Per = 2 },
	Lock = { Calls = 2, Per = 5 },
	Rebirth = { Calls = 1, Per = 3 },
	Gift = { Calls = 1, Per = 5 },
	Claim = { Calls = 5, Per = 5 },
	Throw = { Calls = 3, Per = 1 },
	Code = { Calls = 3, Per = 10 },
}
Config.MaxInteractDistance = 12               -- generic distance check for prompts/pads
Config.KickOnDataFail = true                  -- kick instead of letting someone play with no data

return Config
