-- Logic tests for the shared modules. Run with: python3 tests/run_tests.py
local mock = dofile("tests/mock.lua")
local Config = require(mock.folder("src/shared").Config)
local Catalog = require(mock.folder("src/shared").Catalog)
local Util = require(mock.folder("src/shared").Util)
local Seasons = require(mock.folder("src/shared").Seasons)

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then passed = passed + 1 else failed = failed + 1 print("FAIL: " .. name .. " -> " .. tostring(err)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2) end end

test("box tier odds sum to 100", function()
	for _, tier in ipairs(Config.BoxTiers) do
		local sum = 0
		for rarity, pct in pairs(tier.Odds) do
			assert(Catalog.Rarities[rarity], tier.Key .. " has unknown rarity " .. rarity)
			sum = sum + pct
		end
		assert(math.abs(sum - 100) < 0.001, tier.Key .. " odds sum to " .. sum)
	end
end)

test("every present has a valid rarity, unique key, positive income unless coal", function()
	local seen = {}
	for _, p in ipairs(Catalog.Presents) do
		assert(Catalog.Rarities[p.Rarity], p.Key .. " bad rarity")
		assert(not seen[p.Key], "duplicate key " .. p.Key)
		seen[p.Key] = true
		if p.Rarity == "Coal" then eq(p.Income, 0, p.Key) else assert(p.Income > 0, p.Key) end
	end
	for _, rarity in ipairs(Catalog.RarityOrder) do
		assert(#Catalog.PresentsByRarity[rarity] > 0, "no presents for " .. rarity)
	end
end)

test("mutations chances leave room for None", function()
	local sum = 0
	for _, key in ipairs(Catalog.MutationOrder) do sum = sum + Catalog.Mutations[key].Chance end
	assert(sum < 100, "mutation chances " .. sum)
end)

test("streak has exactly Config.Streak.Days rewards with valid types", function()
	eq(#Config.Streak.Rewards, Config.Streak.Days)
	for i, r in ipairs(Config.Streak.Rewards) do
		assert(({ Cash = 1, Snowflakes = 1, Box = 1, Luck = 1, Slot = 1 })[r.Type], "day " .. i .. " bad type")
		if r.Type == "Box" then
			local found = false
			for _, t in ipairs(Config.BoxTiers) do if t.Key == r.Tier then found = true end end
			assert(found, "day " .. i .. " unknown tier " .. tostring(r.Tier))
		end
	end
end)

test("quests reference known stats and have rewards", function()
	local stats = { Buy = 1, Unwrap = 1, UnwrapRare = 1, UnwrapEpic = 1, Steal = 1, Hit = 1, GrinchTag = 1, Collect = 1, Train = 1, Gift = 1, Lock = 1 }
	assert(#Catalog.Quests >= Config.DailyQuests.Count)
	for _, q in ipairs(Catalog.Quests) do
		assert(stats[q.Stat], q.Id .. " unknown stat " .. q.Stat)
		assert(q.Goal > 0 and q.Reward and (q.Reward.Cash or q.Reward.Snowflakes), q.Id)
	end
end)

test("FormatNumber", function()
	eq(Util.FormatNumber(0), "0")
	eq(Util.FormatNumber(999), "999")
	eq(Util.FormatNumber(1000), "1k")
	eq(Util.FormatNumber(1234), "1.23k")
	eq(Util.FormatNumber(12345), "12.3k")
	eq(Util.FormatNumber(123456), "123k")
	eq(Util.FormatNumber(2100000000), "2.1B")
	eq(Util.FormatNumber(-1500), "-1.5k")
end)

test("Commas / FormatTime", function()
	eq(Util.Commas(1234567), "1,234,567")
	eq(Util.Commas(999), "999")
	eq(Util.FormatTime(125), "2:05")
	eq(Util.FormatTime(3725), "1:02:05")
	eq(Util.FormatTime(90000), "1d 1h")
end)

test("WeightedPickDict respects weights (statistically)", function()
	local counts = { A = 0, B = 0 }
	for _ = 1, 20000 do
		local k = Util.WeightedPickDict({ A = 90, B = 10 })
		counts[k] = counts[k] + 1
	end
	local frac = counts.B / 20000
	assert(frac > 0.08 and frac < 0.12, "B fraction " .. frac)
end)

test("WeightedPick with zero weights returns nil", function()
	eq(Util.WeightedPick({ { W = 0 }, { W = 0 } }, "W"), nil)
end)

test("ApplyLuck only boosts Rare+", function()
	local tiers = {}
	for k, v in pairs(Catalog.Rarities) do tiers[k] = v.Tier end
	local odds = Util.ApplyLuck({ Common = 50, Rare = 10, Legendary = 1 }, 2, tiers)
	eq(odds.Common, 50) eq(odds.Rare, 20) eq(odds.Legendary, 2)
	local same = Util.ApplyLuck({ Common = 50 }, 1, tiers)
	eq(same.Common, 50)
end)

test("Reconcile fills missing keys without overwriting", function()
	local target = { Cash = 5, Stats = { A = 1 } }
	Util.Reconcile(target, { Cash = 50, Snow = 0, Stats = { A = 0, B = 2 } })
	eq(target.Cash, 5) eq(target.Snow, 0) eq(target.Stats.A, 1) eq(target.Stats.B, 2)
end)

test("Seasons: Christmas active on Dec 10 2026, default in Oct", function()
	local dec = os.time({ year = 2026, month = 12, day = 10, hour = 12 })
	local season, left = Seasons.GetActive(dec)
	eq(season.Key, "Christmas")
	assert(left > 0)
	local oct = os.time({ year = 2026, month = 10, day = 29, hour = 12 })
	local s2, left2 = Seasons.GetActive(oct)
	eq(s2.Key, "Classic")
	assert(left2 and left2 > 0, "countdown to next season")
	local sets = Seasons.GetActiveSets(dec)
	assert(sets.Classic and sets.Christmas)
	assert(#Seasons.GetDroppablePresents("Legendary", dec) >= 1)
end)

test("rebirth cost grows", function()
	local c0 = Config.Rebirth.BaseCost * Config.Rebirth.CostMultiplier ^ 0
	local c1 = Config.Rebirth.BaseCost * Config.Rebirth.CostMultiplier ^ 1
	assert(c1 > c0)
end)

test("monetization keys referenced by the shop exist", function()
	for _, key in ipairs({ "VIP", "ExtraSlots", "Speed", "AutoCollect", "Strong" }) do assert(Config.Monetization.Gamepasses[key], key) end
	for _, key in ipairs({ "Cash1", "Cash2", "Cash3", "Snowflakes1", "LuckPotion", "Protein", "LockExtend", "GrinchTurn" }) do assert(Config.Monetization.Products[key], key) end
	for _, item in ipairs(Catalog.SnowflakeShop) do
		if item.Give.Box then
			local found = false
			for _, t in ipairs(Config.BoxTiers) do if t.Key == item.Give.Box then found = true end end
			assert(found, item.Key)
		end
	end
end)

test("traps and events are well formed", function()
	for _, t in ipairs(Config.Traps.List) do assert(t.Key and t.Price > 0 and t.Cooldown) end
	for _, e in ipairs(Config.Events.List) do assert(e.Key and e.Duration > 0 and e.Weight > 0) end
	assert(#Config.Events.List > 0)
	assert(Config.Grinch.SurviveBoxTier and Config.PlaytimeGift.Tier)
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
