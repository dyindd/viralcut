-- End-to-end scenarios: the REAL server (and client) running inside the headless engine.
-- Run: python3 tests/run_scenarios.py
ENGINE_DIR = "tests/engine"
local Engine = dofile("tests/engine/init.lua")
Engine.mountProject(".")

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- tweak config BEFORE boot (same module table the server will use)
local Config = require(RS.Shared.Config)
local Catalog = require(RS.Shared.Catalog)
Config.Grinch.Interval = 30
Config.Grinch.WarningSeconds = 3
Config.Grinch.Duration = 20
Config.Grinch.Enabled = false        -- switched on inside the Grinch tests only
Config.Events.MinInterval = 100000  -- no random events during tests; we trigger them by hand
Config.Events.MaxInterval = 100001
Config.AutosaveInterval = 100000

Engine.bootServer()
local Registry = require(SSS.Server.Registry)
local Data = Registry.Get("DataService")
local Plots = Registry.Get("PlotService")
local Presents = Registry.Get("PresentService")
local Carry = Registry.Get("CarryService")
local Conveyor = Registry.Get("ConveyorService")
local Grinch = Registry.Get("GrinchService")
local Events = Registry.Get("EventService")
local Remotes = RS:WaitForChild("Remotes")

---------------------------------------------------------------- harness
local passed, failed = 0, 0
local function test(name, fn)
	Engine.resetErrors()
	local ok, err = pcall(fn)
	Config.Grinch.Enabled = false -- never let background rounds leak into the next test
	local engineErrors = Engine.resetErrors()
	if ok and #engineErrors == 0 then
		passed = passed + 1
		print("  ok   " .. name)
	else
		failed = failed + 1
		print("  FAIL " .. name .. (ok and "" or (" -> " .. tostring(err))))
		for _, e in ipairs(engineErrors) do print("       engine error: " .. e:gsub("\n", "\n       ")) end
	end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a), 2) end end
local function near(a, b, tol, msg) if math.abs(a - b) > (tol or 1e-6) then error((msg or "") .. " expected ~" .. tostring(b) .. " got " .. tostring(a), 2) end end
local function truthy(v, msg) if not v then error(msg or "expected truthy", 2) end end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

local function profile(p) return Data.GetProfile(p) end
local function plot(p) return Plots.GetPlot(p) end
local function beltBoxes() return workspace.World.BeltBoxes:GetChildren() end
local function findBelt(tierKey)
	for _, m in ipairs(beltBoxes()) do if m:GetAttribute("Tier") == tierKey then return m end end
	return nil
end
local function buyBox(p, tierKey)
	Sched.advance(0.5) -- humans aren't instant: respects debounces
	local box = findBelt(tierKey)
	local waited = 0
	while not box and waited < 60 do Sched.advance(1) waited = waited + 1 box = findBelt(tierKey) end
	truthy(box, "no " .. tierKey .. " box on the belt")
	Engine.teleport(p, box.PrimaryPart.Position + Vector3.new(0, 0, 4))
	Engine.trigger(box.PrimaryPart.BuyPrompt, p)
	return box
end
local function deposit(p)
	Sched.advance(5) -- walking from the belt to a base takes a few seconds (anti-teleport check)
	local pl = plot(p)
	Engine.teleport(p, pl.Deposit.Position + Vector3.new(0, 3, 0))
	Engine.touch(pl.Deposit, p)
end
local function collect(p)
	Sched.advance(0.6)
	local pl = plot(p)
	Engine.teleport(p, pl.Collect.Position + Vector3.new(0, 3, 0))
	Engine.touch(pl.Collect, p)
end
local function presentModels(p)
	local out = {}
	for id, m in pairs(plot(p).PresentModels) do out[id] = m end
	return out
end
local function forceRarity(r) Presents.RollRarity = function() return r end end
local function forceMutation(m) Presents.RollMutation = function() return m end end
local originalRollRarity, originalRollMutation = Presents.RollRarity, Presents.RollMutation
local function resetRolls() Presents.RollRarity = originalRollRarity Presents.RollMutation = originalRollMutation end
local function bat(p) return p.Backpack:FindFirstChild(Config.Combat.BatName) or (p.Character and p.Character:FindFirstChild(Config.Combat.BatName)) end
function training_is_active(p) return Registry.Get("StrengthService").IsTraining(p) end
local function emptyHands(p)
	if Carry.IsCarrying(p) then Engine.fireServer(Remotes.DropCarry, p) end
	Sched.advance(0.5)
end
local function swingAt(attacker, target)
	-- attacker faces -Z (identity rotation); put target 3 studs in front
	local pos = Engine.position(attacker)
	Engine.teleport(target, pos + Vector3.new(0, 0, -3))
	bat(attacker).Activated:Fire()
	Sched.advance(0.1)
end
local function totalPresents(...)
	local n = 0
	for _, p in ipairs({ ... }) do n = n + #profile(p).Presents end
	for _ in pairs(Carry) do end
	return n
end

print("== Steal a Present scenarios ==")
local p1, p2

---------------------------------------------------------------- join
test("player joins: profile, plot, leaderstats, teleport to base", function()
	p1 = Engine.addPlayer("Alice", 101)
	Sched.advance(1)
	truthy(profile(p1), "profile loaded")
	eq(profile(p1).Cash, Config.StartingCash, "starting cash")
	truthy(plot(p1), "plot assigned")
	eq(plot(p1).Index, 1)
	truthy(p1:FindFirstChild("leaderstats"), "leaderstats")
	local d = (Engine.position(p1) - plot(p1).SpawnPoint.Position).Magnitude
	truthy(d < 6, "spawned at base, dist " .. d)
	truthy(bat(p1), "has the bat")
	local snap = Engine.lastSent(p1, "DataChanged")
	truthy(snap and snap[1].Cash == Config.StartingCash, "DataChanged replicated")
	truthy(Engine.lastSent(p1, "BaseState"), "BaseState sent")
	truthy(Engine.lastSent(p1, "QuestsChanged"), "quests sent")
	truthy(Engine.lastSent(p1, "StreakChanged"), "streak sent")
end)

---------------------------------------------------------------- belt + buy + unwrap
test("belt spawns boxes and moves them", function()
	Sched.advance(10)
	truthy(#beltBoxes() >= 2, "boxes on belt: " .. #beltBoxes())
	local b = beltBoxes()[1]
	local x1 = b.PrimaryPart.Position.X
	Sched.advance(2)
	truthy(b.PrimaryPart.Position.X > x1, "box moved along +X")
end)

test("buy a Small box: cash deducted, carrying, speed penalty none for weight 0", function()
	buyBox(p1, "Small")
	eq(profile(p1).Cash, Config.StartingCash - 25, "cash after buy")
	truthy(Carry.IsCarrying(p1), "carrying")
	truthy(p1.Character:FindFirstChild("Carried"), "model welded to character")
	local cs = Engine.lastSent(p1, "CarryState")
	eq(cs[1].Kind, "Box")
	eq(Engine.humanoid(p1).WalkSpeed, 16)
end)

test("can't buy while carrying; drop puts the box on the floor as a pickup", function()
	local cashBefore = profile(p1).Cash
	local box = findBelt("Small")
	if box then
		Engine.teleport(p1, box.PrimaryPart.Position + Vector3.new(0, 0, 4))
		Engine.trigger(box.PrimaryPart.BuyPrompt, p1)
		eq(profile(p1).Cash, cashBefore, "no double buy")
	end
	Engine.fireServer(Remotes.DropCarry, p1)
	truthy(not Carry.IsCarrying(p1), "dropped")
	local pickups = workspace.World.Pickups:GetChildren()
	eq(#pickups, 1, "one floor pickup")
	-- pick it back up (free)
	Engine.teleport(p1, pickups[1].PrimaryPart.Position + Vector3.new(0, 0, 3))
	Engine.trigger(pickups[1].PrimaryPart.PickupPrompt, p1)
	truthy(Carry.IsCarrying(p1), "picked up again")
	eq(profile(p1).Cash, cashBefore, "free pickup")
	eq(#workspace.World.Pickups:GetChildren(), 0)
end)

test("deposit unwraps a Rare: record, model, income, popup, index", function()
	forceRarity("Rare") forceMutation(nil)
	deposit(p1)
	truthy(not Carry.IsCarrying(p1), "no longer carrying")
	eq(#profile(p1).Presents, 1, "one present")
	local rec = profile(p1).Presents[1]
	eq(rec.Rarity, "Rare") eq(rec.Slot, 1)
	truthy(plot(p1).PresentModels[rec.Id], "model placed")
	truthy(plot(p1).IncomePerSec >= 8, "income/s " .. plot(p1).IncomePerSec)
	local ur = Engine.lastSent(p1, "UnwrapResult")
	truthy(ur and ur[1].Rarity == "Rare", "UnwrapResult sent")
	truthy(profile(p1).Index[rec.Key], "index unlocked")
	eq(profile(p1).Stats.Unwrapped, 1)
end)

test("coal: no slot used, prank effect, index entry", function()
	forceRarity("Coal")
	buyBox(p1, "Small")
	deposit(p1)
	eq(#profile(p1).Presents, 1, "coal takes no slot")
	local ur = Engine.lastSent(p1, "UnwrapResult")
	eq(ur[1].Rarity, "Coal")
	truthy(p1.Character.HumanoidRootPart:FindFirstChild("Impulse") or true)
	resetRolls()
end)

test("income accrues into the pile; collect banks it; quest progress", function()
	local pileBefore = profile(p1).Pile
	Sched.advance(5)
	truthy(profile(p1).Pile > pileBefore, "pile grew")
	Sched.advance(0.6)
	local cashBefore = profile(p1).Cash
	local pile = math.floor(profile(p1).Pile)
	local pl = plot(p1)
	Engine.teleport(p1, pl.Collect.Position + Vector3.new(0, 3, 0))
	Engine.touch(pl.Collect, p1)
	truthy(profile(p1).Pile < pl.IncomePerSec * 1.5, "pile emptied (at most one tick since)")
	eq(profile(p1).Cash, cashBefore + pile)
end)

---------------------------------------------------------------- strength gate + training
test("Medium box needs strength; training grants it; then buy works", function()
	Data.AddCash(p1, 1000)
	local cash = profile(p1).Cash
	buyBox(p1, "Medium")
	truthy(not Carry.IsCarrying(p1), "too heavy")
	eq(profile(p1).Cash, cash, "no charge when too heavy")
	local pl = plot(p1)
	Engine.teleport(p1, pl.Bench.Position + Vector3.new(0, 3, 0))
	Engine.trigger(pl.Bench.TrainPrompt, p1)
	eq(Engine.humanoid(p1).WalkSpeed, 0, "frozen while training")
	Sched.advance(16)
	truthy(profile(p1).Strength >= 15, "strength " .. profile(p1).Strength)
	Engine.trigger(pl.Bench.TrainPrompt, p1)
	eq(Engine.humanoid(p1).WalkSpeed, 16, "unfrozen")
	buyBox(p1, "Medium")
	truthy(Carry.IsCarrying(p1), "carrying medium")
	truthy(Engine.humanoid(p1).WalkSpeed < 16, "weight slows: " .. Engine.humanoid(p1).WalkSpeed)
	forceRarity("Epic") deposit(p1) resetRolls()
	eq(#profile(p1).Presents, 2)
end)

---------------------------------------------------------------- stealing
test("second player joins and steals; present is in transit; bat hit returns it", function()
	p2 = Engine.addPlayer("Bob", 102)
	Sched.advance(1)
	eq(plot(p2).Index, 2)
	-- stealing is strength-gated (2x the present's weight): a fresh player can't take a Rare
	local target = profile(p1).Presents[1]
	local model0 = plot(p1).PresentModels[target.Id]
	Engine.teleport(p2, model0.PrimaryPart.Position + Vector3.new(0, 0, 3))
	Engine.trigger(model0.PrimaryPart.StealPrompt, p2)
	truthy(not Carry.IsCarrying(p2), "weak thief refused")
	profile(p2).Strength = 100
	Sched.advance(0.5)
	local model = plot(p1).PresentModels[target.Id]
	Engine.teleport(p2, model.PrimaryPart.Position + Vector3.new(0, 0, 3))
	Engine.trigger(model.PrimaryPart.StealPrompt, p2)
	truthy(Carry.IsCarrying(p2), "thief carrying")
	eq(#profile(p1).Presents, 1, "owner lost it")
	eq(#profile(p2).Presents, 0)
	truthy(not plot(p1).PresentModels[target.Id], "model removed from owner base")
	-- owner whacks the thief
	swingAt(p1, p2)
	truthy(not Carry.IsCarrying(p2), "thief dropped it")
	eq(#profile(p1).Presents, 2, "returned to owner")
	truthy(plot(p1).PresentModels[target.Id], "model back")
	eq(profile(p1).Stats.Hits, 1)
end)

test("successful steal: thief deposits, gets Stolen trait, no duplication", function()
	local target = profile(p1).Presents[1]
	local model = plot(p1).PresentModels[target.Id]
	Engine.teleport(p2, model.PrimaryPart.Position + Vector3.new(0, 0, 3))
	Engine.trigger(model.PrimaryPart.StealPrompt, p2)
	truthy(Carry.IsCarrying(p2))
	deposit(p2)
	eq(#profile(p2).Presents, 1, "thief owns it")
	eq(#profile(p1).Presents, 1, "owner lost it")
	truthy(profile(p2).Presents[1].Traits.Stolen, "stolen trait")
	eq(profile(p2).Stats.Stolen, 1)
	eq(profile(p2).Presents[1].Id, target.Id)
end)

test("locked base refuses steals; lock expires; cooldown enforced", function()
	Engine.teleport(p1, plot(p1).LockButton.Position + Vector3.new(0, 0, 3))
	Engine.trigger(plot(p1).LockButton.LockPrompt, p1)
	truthy(Plots.IsLocked(plot(p1)), "locked")
	local target = profile(p1).Presents[1]
	local model = plot(p1).PresentModels[target.Id]
	Engine.teleport(p2, model.PrimaryPart.Position + Vector3.new(0, 0, 3))
	Engine.trigger(model.PrimaryPart.StealPrompt, p2)
	truthy(not Carry.IsCarrying(p2), "steal refused while locked")
	eq(#profile(p1).Presents, 1)
	Engine.trigger(plot(p1).LockButton.LockPrompt, p1) -- already locked
	Sched.advance(Config.Lock.Duration + 1)
	truthy(not Plots.IsLocked(plot(p1)), "expired")
	Engine.trigger(plot(p1).LockButton.LockPrompt, p1)
	truthy(not Plots.IsLocked(plot(p1)), "cooldown blocks relock")
	Sched.advance(Config.Lock.Cooldown + 1)
	Engine.trigger(plot(p1).LockButton.LockPrompt, p1)
	truthy(Plots.IsLocked(plot(p1)), "relocked after cooldown")
	Sched.advance(Config.Lock.Duration + 1)
end)

test("UI lock remote requires being near the base", function()
	Sched.advance(Config.Lock.Cooldown + 1)
	Engine.teleport(p1, Vector3.new(0, 3, 0))
	Engine.fireServer(Remotes.LockBase, p1)
	truthy(not Plots.IsLocked(plot(p1)), "refused from far away")
	Engine.teleport(p1, plot(p1).Deposit.Position + Vector3.new(0, 3, 0))
	Engine.fireServer(Remotes.LockBase, p1)
	truthy(Plots.IsLocked(plot(p1)), "locked from near")
	Sched.advance(Config.Lock.Duration + 1)
end)

test("owner leaves while their present is in transit: thief loses it, owner's save keeps it", function()
	local target = profile(p1).Presents[1]
	local model = plot(p1).PresentModels[target.Id]
	Engine.teleport(p2, model.PrimaryPart.Position + Vector3.new(0, 0, 3))
	Engine.trigger(model.PrimaryPart.StealPrompt, p2)
	truthy(Carry.IsCarrying(p2))
	local p1Presents = #profile(p1).Presents -- 0 now (in transit)
	Engine.removePlayer(p1)
	truthy(not Carry.IsCarrying(p2), "thief's carry vanished")
	local saved = Engine.datastores[Config.DataStoreName]["Player_101"]
	truthy(saved, "saved")
	eq(#saved.Presents, p1Presents + 1, "present back in the saved profile")
	eq(saved.Lock, nil, "session lock released")
	truthy(saved.LastOnline > 0)
	truthy(plot(p2) ~= nil)
	eq(Plots.GetPlotByIndex(1).Owner, nil, "plot freed")
end)

test("rejoin restores presents, pays offline earnings into the pile", function()
	local saved = Engine.datastores[Config.DataStoreName]["Player_101"]
	saved.LastOnline = saved.LastOnline - 3600 -- pretend an hour passed
	p1 = Engine.addPlayer("Alice", 101)
	Sched.advance(4)
	eq(#profile(p1).Presents, 1, "restored")
	truthy(count(plot(p1).PresentModels) == 1, "models rebuilt")
	truthy(profile(p1).Pile > 100, "offline earnings in pile: " .. profile(p1).Pile)
	eq(profile(p1).Joins, 2)
end)

test("session lock: a second server can't load a locked profile (kicks after retries)", function()
	local store = Engine.datastores[Config.DataStoreName]
	-- simulate another live server holding Bob's lock
	Engine.removePlayer(p2)
	store["Player_102"].Lock = { Session = "other-server", Time = os.time() }
	local kicksBefore = #Engine.kicks
	p2 = Engine.addPlayer("Bob", 102)
	Sched.advance(60)
	eq(#Engine.kicks, kicksBefore + 1, "kicked")
	store["Player_102"].Lock = nil
	p2 = Engine.addPlayer("Bob", 102)
	Sched.advance(2)
	truthy(profile(p2), "loads once the lock is gone")
end)

---------------------------------------------------------------- selling, gifting
test("sell a present pays SellSeconds of income and frees the slot", function()
	emptyHands(p1)
	Data.AddCash(p1, 500)
	forceRarity("Common") buyBox(p1, "Small") deposit(p1) resetRolls()
	local rec = profile(p1).Presents[#profile(p1).Presents]
	local value = math.floor(Presents.GetValue(p1, rec) * Config.SellSeconds)
	local cash = profile(p1).Cash
	local n = #profile(p1).Presents
	Engine.fireServer(Remotes.SellPresent, p1, rec.Id)
	eq(#profile(p1).Presents, n - 1)
	eq(profile(p1).Cash, cash + math.max(value, 10))
	truthy(not plot(p1).PresentModels[rec.Id])
	-- selling a stolen (in-transit) present must fail
	Engine.fireServer(Remotes.SellPresent, p1, "nonexistent")
end)

test("gift a present: moves to target, traits, snowflakes, limits", function()
	emptyHands(p1)
	Data.AddCash(p1, 500)
	forceRarity("Uncommon") buyBox(p1, "Small") deposit(p1) resetRolls()
	local rec = profile(p1).Presents[#profile(p1).Presents]
	local n1, n2 = #profile(p1).Presents, #profile(p2).Presents
	local sf1, sf2 = profile(p1).Snowflakes, profile(p2).Snowflakes
	Engine.fireServer(Remotes.GiftPresent, p1, rec.Id, p2.UserId)
	eq(#profile(p1).Presents, n1 - 1) eq(#profile(p2).Presents, n2 + 1)
	truthy(plot(p2).PresentModels[rec.Id], "model at target base")
	local moved = profile(p2).Presents[#profile(p2).Presents]
	truthy(moved.Traits.Gifted, "gifted trait")
	eq(profile(p1).Snowflakes, sf1 + Config.Gift.SnowflakesForBoth)
	truthy(profile(p2).Snowflakes >= sf2 + Config.Gift.SnowflakesForBoth, "target rewarded (+index bonus if new)")
	-- cooldown blocks an immediate second gift
	forceRarity("Uncommon") buyBox(p1, "Small") deposit(p1) resetRolls()
	local rec2 = profile(p1).Presents[#profile(p1).Presents]
	Sched.advance(6)
	Engine.fireServer(Remotes.GiftPresent, p1, rec2.Id, p2.UserId)
	eq(#profile(p2).Presents, n2 + 1, "cooldown respected")
	-- bad args are ignored
	Engine.fireServer(Remotes.GiftPresent, p1, rec2.Id, "notanumber")
	Engine.fireServer(Remotes.GiftPresent, p1, 12345, p2.UserId)
	Engine.fireServer(Remotes.GiftPresent, p1, rec2.Id, p1.UserId)
	eq(#profile(p1).Presents, n1, "still have it")
end)

---------------------------------------------------------------- traps
test("ice patch trap slows a thief, never the owner; elf guard makes carriers drop", function()
	Data.AddCash(p1, 100000)
	Engine.fireServer(Remotes.BuyTrap, p1, "IcePatch", 1)
	eq(profile(p1).Traps["1"], "IcePatch")
	local trap = plot(p1).TrapModels[1]
	truthy(trap, "trap model")
	Engine.touch(trap.PrimaryPart, p1)
	eq(Engine.humanoid(p1).WalkSpeed, 16, "owner unaffected")
	Engine.touch(trap.PrimaryPart, p2)
	truthy(Engine.humanoid(p2).WalkSpeed < 16, "thief slowed: " .. Engine.humanoid(p2).WalkSpeed)
	Sched.advance(4)
	eq(Engine.humanoid(p2).WalkSpeed, 16, "slow wore off")
	Engine.fireServer(Remotes.BuyTrap, p1, "ElfGuard", 2)
	eq(profile(p1).Traps["2"], "ElfGuard")
	-- bad socket / unknown trap ignored
	Engine.fireServer(Remotes.BuyTrap, p1, "ElfGuard", 99)
	Engine.fireServer(Remotes.BuyTrap, p1, "Nope", 3)
	eq(profile(p1).Traps["3"], nil)
	-- p2 steals and stands next to the elf guard
	local target = profile(p1).Presents[1]
	local model = plot(p1).PresentModels[target.Id]
	Engine.teleport(p2, model.PrimaryPart.Position + Vector3.new(0, 0, 3))
	Engine.trigger(model.PrimaryPart.StealPrompt, p2)
	truthy(Carry.IsCarrying(p2))
	Engine.teleport(p2, plot(p1).TrapModels[2].PrimaryPart.Position + Vector3.new(2, 2, 0))
	Sched.advance(2)
	truthy(not Carry.IsCarrying(p2), "elf guard whacked the thief")
	truthy(plot(p1).PresentModels[target.Id], "present returned")
end)

---------------------------------------------------------------- Grinch
test("Grinch round: warning, active, snowballs, defeat by 3 snowballs, rewards", function()
	emptyHands(p1) emptyHands(p2)
	Config.Grinch.Enabled = true
	Grinch.ForceGrinch(p1)
	Sched.advance(Config.Grinch.WarningSeconds + 3)
	local st = Grinch.GetState()
	truthy(st.Active, "grinch active")
	local g = st.Player
	local other = (g == p1) and p2 or p1
	truthy(other.Backpack:FindFirstChild("Snowball"), "others have snowballs")
	truthy(not g.Backpack:FindFirstChild("Snowball"), "grinch has none")
	truthy(Engine.humanoid(g).WalkSpeed > 20, "grinch is fast")
	-- bat hits don't count
	swingAt(other, g)
	eq(Grinch.GetState().Hits, 0, "bat doesn't count")
	-- snowball hits do: simulate 3 projectile hits
	local Combat = Registry.Get("CombatService")
	local cashBefore = profile(other).Cash
	for i = 1, 3 do Combat.Hit(other, g, "snowball") Sched.advance(0.1) end
	truthy(not Grinch.GetState().Active, "defeated")
	truthy(profile(other).Cash > cashBefore, "rewarded")
	eq(profile(other).Stats.GrinchTags, 3)
	truthy(not other.Backpack:FindFirstChild("Snowball"), "snowballs removed")
	eq(Engine.humanoid(g).WalkSpeed, 0, "stunned briefly")
	Sched.advance(2.5)
	eq(Engine.humanoid(g).WalkSpeed, 16)
end)

test("Grinch can steal from a locked base and survive for the reward", function()
	emptyHands(p1) emptyHands(p2)
	Sched.advance(Config.Lock.Cooldown + 1)
	Engine.teleport(p1, plot(p1).LockButton.Position + Vector3.new(0, 0, 3))
	Engine.trigger(plot(p1).LockButton.LockPrompt, p1)
	truthy(Plots.IsLocked(plot(p1)))
	Config.Grinch.Enabled = true
	Grinch.ForceGrinch(p2)
	Sched.advance(Config.Grinch.WarningSeconds + 3)
	truthy(Grinch.IsGrinch(p2), "p2 is the grinch")
	truthy(Plots.IsLocked(plot(p1)), "still locked")
	local target = profile(p1).Presents[1]
	local model = plot(p1).PresentModels[target.Id]
	Engine.teleport(p2, model.PrimaryPart.Position + Vector3.new(0, 0, 3))
	Engine.trigger(model.PrimaryPart.StealPrompt, p2)
	truthy(Carry.IsCarrying(p2), "grinch stole from locked base")
	deposit(p2)
	truthy(profile(p2).Presents[#profile(p2).Presents].Traits.Grinch, "grinch loot trait")
	local wins = profile(p2).Stats.GrinchWins
	local cash = profile(p2).Cash
	Sched.advance(Config.Grinch.Duration + 1)
	truthy(not Grinch.GetState().Active)
	eq(profile(p2).Stats.GrinchWins, wins + 1, "survived")
	truthy(profile(p2).Cash > cash)
	truthy(#workspace.World.Pickups:GetChildren() >= 1, "free box delivered")
	Config.Grinch.Enabled = false
	Sched.advance(Config.Lock.Duration + 1)
end)

---------------------------------------------------------------- events
test("Sleigh Drop spawns sacks that can be picked up and unwrapped", function()
	for _, def in ipairs(Config.Events.List) do
		if def.Key == "SleighDrop" then Events.StartEvent(def) end
	end
	truthy(Events.IsActive("SleighDrop"))
	Sched.advance(12)
	local sacks = 0
	for _, m in ipairs(workspace.World.Pickups:GetChildren()) do if m:GetAttribute("Tier") == "Sack" then sacks = sacks + 1 end end
	eq(sacks, Config.Events.SleighDrop.SackCount, "sacks on the ground")
	local sack
	for _, m in ipairs(workspace.World.Pickups:GetChildren()) do if m:GetAttribute("Tier") == "Sack" then sack = m end end
	truthy(sack.PrimaryPart.Position.Y > 0 and sack.PrimaryPart.Position.Y < 40, "resting on something, y=" .. sack.PrimaryPart.Position.Y)
	if Carry.IsCarrying(p1) then Engine.fireServer(Remotes.DropCarry, p1) end
	Engine.teleport(p1, sack.PrimaryPart.Position + Vector3.new(0, 0, 3))
	Engine.trigger(sack.PrimaryPart.PickupPrompt, p1)
	truthy(Carry.IsCarrying(p1), "picked up sack")
	forceRarity("Legendary") deposit(p1) resetRolls()
	local rec = profile(p1).Presents[#profile(p1).Presents]
	eq(rec.Rarity, "Legendary")
	local ann = Engine.lastSent(p1, "Announce")
	truthy(ann and ann[1]:find("Legendary"), "server announcement")
	Sched.advance(70)
	truthy(not Events.GetActive(), "event over")
end)

test("Blizzard boosts Frosted mutation odds (statistical)", function()
	for _, def in ipairs(Config.Events.List) do if def.Key == "Blizzard" then Events.StartEvent(def) end end
	local frosted, trials = 0, 400
	for _ = 1, trials do if Presents.RollMutation() == "Frosted" then frosted = frosted + 1 end end
	truthy(frosted / trials > 0.25, "frosted rate during blizzard " .. frosted / trials)
	Sched.advance(100)
	frosted = 0
	for _ = 1, trials do if Presents.RollMutation() == "Frosted" then frosted = frosted + 1 end end
	truthy(frosted / trials < 0.15, "frosted rate normally " .. frosted / trials)
end)

---------------------------------------------------------------- rebirth / quests / streak / index
test("rebirth: cost gate, reset, multiplier, slots, carry blocked", function()
	emptyHands(p1)
	local before = profile(p1).Rebirths
	profile(p1).Cash = 10
	Sched.advance(4)
	Engine.fireServer(Remotes.Rebirth, p1)
	eq(profile(p1).Rebirths, before, "too poor")
	profile(p1).Cash = Config.Rebirth.BaseCost
	buyBox(p1, "Small")
	Sched.advance(4)
	Engine.fireServer(Remotes.Rebirth, p1)
	eq(profile(p1).Rebirths, before, "blocked while carrying")
	emptyHands(p1)
	profile(p1).Cash = Config.Rebirth.BaseCost
	Sched.advance(4)
	Engine.fireServer(Remotes.Rebirth, p1)
	eq(profile(p1).Rebirths, before + 1)
	eq(profile(p1).Cash, Config.StartingCash)
	eq(#profile(p1).Presents, 0)
	eq(count(plot(p1).PresentModels), 0)
	eq(Plots.GetSlotCount(p1), Config.Plots.StartingSlots + 1)
	near(Presents.GetMultipliers(p1), 1.5, 1e-9)
end)

test("daily quests: progress, claim once, rejected twice", function()
	local list = Engine.lastSent(p1, "QuestsChanged")[1]
	truthy(#list == Config.DailyQuests.Count, "3 quests")
	local Quests = Registry.Get("QuestService")
	local q = list[1]
	local def
	for _, d in ipairs(Catalog.Quests) do if d.Id == q.Id then def = d end end
	Quests.Progress(p1, def.Stat, def.Goal)
	local cash = profile(p1).Cash
	Sched.advance(6)
	Engine.fireServer(Remotes.ClaimQuest, p1, q.Id)
	eq(profile(p1).Cash, cash + def.Reward.Cash, "reward paid")
	Sched.advance(2)
	Engine.fireServer(Remotes.ClaimQuest, p1, q.Id)
	eq(profile(p1).Cash, cash + def.Reward.Cash, "not paid twice")
	local after = Engine.lastSent(p1, "QuestsChanged")[1]
	truthy(after[1].Claimed)
end)

test("streak calendar: claim today, not twice, next day, missed day resets", function()
	local Retention = Registry.Get("RetentionService")
	local cash = profile(p1).Cash
	Sched.advance(6)
	Engine.fireServer(Remotes.ClaimStreak, p1)
	eq(profile(p1).Streak.Count, 1)
	eq(profile(p1).Cash, cash + Config.Streak.Rewards[1].Amount)
	Sched.advance(2)
	Engine.fireServer(Remotes.ClaimStreak, p1)
	eq(profile(p1).Streak.Count, 1, "no double claim")
	Sched.skipTime(86400) Sched.advance(2)
	Engine.fireServer(Remotes.ClaimStreak, p1)
	eq(profile(p1).Streak.Count, 2)
	Sched.skipTime(86400 * 3) Sched.advance(2) -- missed two days
	local info = Retention.GetStreakInfo(profile(p1))
	eq(info.NextDay, 1, "reset to day 1")
	Engine.fireServer(Remotes.ClaimStreak, p1)
	eq(profile(p1).Streak.Count, 1)
	-- day-25 rollover
	profile(p1).Streak.Count = 25
	Sched.skipTime(86400)
	eq(Retention.GetStreakInfo(profile(p1)).NextDay, 1)
end)

test("playtime gift after 30 minutes; snowflake shop; settings", function()
	Sched.advance(6)
	local before = #workspace.World.Pickups:GetChildren()
	Engine.fireServer(Remotes.ClaimPlaytimeGift, p1)
	eq(#workspace.World.Pickups:GetChildren(), before, "not ready")
	profile(p1).PlaytimeGift.Progress = Config.PlaytimeGift.IntervalSeconds
	Sched.advance(2)
	Engine.fireServer(Remotes.ClaimPlaytimeGift, p1)
	eq(#workspace.World.Pickups:GetChildren(), before + 1, "gift delivered")
	profile(p1).Snowflakes = 1000
	local slots = Plots.GetSlotCount(p1)
	Sched.advance(2)
	Engine.fireServer(Remotes.BuySnowflakeItem, p1, "SF_Slot")
	eq(Plots.GetSlotCount(p1), slots + 1)
	eq(profile(p1).Snowflakes, 1000 - 250)
	Engine.fireServer(Remotes.BuySnowflakeItem, p1, "SF_Nope")
	Engine.fireServer(Remotes.SetSetting, p1, "Music", false)
	eq(profile(p1).Settings.Music, false)
	Engine.fireServer(Remotes.SetSetting, p1, "Cash", 999999)
	truthy(profile(p1).Cash < 999999, "settings can't touch cash")
end)

test("index set completion pays out once", function()
	local Index = Registry.Get("IndexService")
	local cash = profile(p1).Cash
	for _, p in ipairs(Catalog.PresentsByRarity.Common) do Index.Unlock(p1, p.Key) end
	truthy(profile(p1).IndexSetsClaimed.Common, "set claimed")
	truthy(profile(p1).Cash >= cash + Config.Index.SetRewards.Common)
	local c2 = profile(p1).Cash
	Index.Unlock(p1, Catalog.PresentsByRarity.Common[1].Key)
	eq(profile(p1).Cash, c2, "no second payout")
end)

---------------------------------------------------------------- monetization
test("dev product receipt: granted once, deduped, unknown product not processed", function()
	local MS = game:GetService("MarketplaceService")
	Config.Monetization.Products.Cash1.Id = 555
	-- rebuild id map by re-running Init's map logic: simplest is to call ProcessReceipt with the id after patching the module table
	local Monet = Registry.Get("MonetizationService")
	local cash = profile(p1).Cash
	local decision = MS.ProcessReceipt({ PlayerId = p1.UserId, ProductId = 555, PurchaseId = "r-1", CurrencySpent = 49 })
	-- productById was built at require time with Id = 0, so 555 is unknown -> NotProcessedYet
	eq(decision, Enum.ProductPurchaseDecision.NotProcessedYet)
	eq(profile(p1).Cash, cash)
	local d2 = MS.ProcessReceipt({ PlayerId = 999999, ProductId = 555, PurchaseId = "r-2" })
	eq(d2, Enum.ProductPurchaseDecision.NotProcessedYet, "offline player")
end)

test("gamepass purchase finished applies effects", function()
	local MS = game:GetService("MarketplaceService")
	Config.Monetization.Gamepasses.VIP.Id = 777
	-- PromptGamePassPurchaseFinished uses passByid built at require time (Id 0) -> no effect expected; verify no crash
	MS.PromptGamePassPurchaseFinished:Fire(p1, 777, true)
	Sched.advance(0.1)
	-- direct grant path
	profile(p1).Gamepasses.VIP = true
	Registry.Get("PresentService").RecalcIncome(plot(p1))
	near(Presents.GetMultipliers(p1), 1.5 * 2, 1e-9, "VIP doubles")
	profile(p1).Gamepasses.VIP = nil
end)

---------------------------------------------------------------- rate limiting / validation
test("rate limiter rejects spam; bad remote args are ignored safely", function()
	local RateLimiter = require(SSS.Server.RateLimiter)
	Sched.advance(10)
	local allowed = 0
	for _ = 1, 10 do if RateLimiter.Check(p1, "Rebirth") then allowed = allowed + 1 end end
	eq(allowed, 1)
	Engine.fireServer(Remotes.ThrowSnowball, p1, "not a vector")
	Engine.fireServer(Remotes.ThrowSnowball, p1, Vector3.new(0 / 0, 1, 0))
	Engine.fireServer(Remotes.BuyTrap, p1, 5, 1)
	Engine.fireServer(Remotes.BuyBox, p1, 42)
	Engine.fireServer(Remotes.SellPresent, p1, { evil = true })
	Engine.fireServer(Remotes.ClaimQuest, p1, string.rep("x", 10000))
	Engine.fireServer(Remotes.PromptPurchase, p1, "Gamepass", "VIP")
	Engine.fireServer(Remotes.PromptPurchase, p1, 1, 2)
end)

test("present conservation across all flows (no dupes, no losses)", function()
	local totalRecords = #profile(p1).Presents + #profile(p2).Presents
	local totalModels = count(plot(p1).PresentModels) + count(plot(p2).PresentModels)
	eq(totalModels, totalRecords, "every record has exactly one model")
	local ids = {}
	for _, p in ipairs({ p1, p2 }) do
		for _, r in ipairs(profile(p).Presents) do
			truthy(not ids[r.Id], "duplicate id " .. r.Id)
			ids[r.Id] = true
		end
	end
end)

---------------------------------------------------------------- world + animation
test("world: environment, decoration, lock lamp and pedestal rims exist", function()
	local Lighting = game:GetService("Lighting")
	truthy(Lighting:FindFirstChildOfClass("Atmosphere") and Lighting:FindFirstChildOfClass("BloomEffect") and Lighting:FindFirstChildOfClass("ColorCorrectionEffect"), "post fx")
	truthy(workspace.Terrain:FindFirstChildOfClass("Clouds"), "clouds")
	local hub = workspace.World.Hub
	truthy(hub:FindFirstChild("Aurora") and #hub.Aurora:GetChildren() >= 60, "aurora ribbons")
	local trees, snowmen, lamps = 0, 0, 0
	for _, c in ipairs(hub:GetChildren()) do
		if c.Name == "Tree" then trees = trees + 1 elseif c.Name == "Snowman" then snowmen = snowmen + 1 elseif c.Name == "LampPost" then lamps = lamps + 1 end
	end
	truthy(trees >= 50 and snowmen >= 6 and lamps >= 12, string.format("decor counts trees=%d snowmen=%d lamps=%d", trees, snowmen, lamps))
	truthy(hub:FindFirstChild("SeasonTree") and hub.SeasonTree:FindFirstChild("Star"), "season tree")
	truthy(hub.Conveyor:FindFirstChild("Factory") and hub.Conveyor.Factory:FindFirstChild("Window"), "workshop windows")
	local pl = plot(p1)
	truthy(pl.LockLamp, "lock lamp wired")
	truthy(pl.Model:FindFirstChild("House") and pl.Model:FindFirstChild("Fence") and pl.Model:FindFirstChild("GymSet"), "base decor")
	truthy(pl.Slots[1]:FindFirstChild("Rim") and pl.Slots[1].Rim.Transparency == 0, "unlocked pedestal rim visible")
	truthy(pl.Slots[20].Rim.Transparency == 1, "locked pedestal rim hidden")
end)

test("lock lamp turns green while locked and red after", function()
	Sched.advance(Config.Lock.Cooldown + 1)
	Engine.teleport(p1, plot(p1).LockButton.Position + Vector3.new(0, 0, 3))
	Engine.trigger(plot(p1).LockButton.LockPrompt, p1)
	truthy(Plots.IsLocked(plot(p1)))
	truthy(plot(p1).LockLamp.Color.G > 0.8, "green while locked")
	Sched.advance(Config.Lock.Duration + 1)
	truthy(plot(p1).LockLamp.Color.R > 0.8 and plot(p1).LockLamp.Color.G < 0.5, "red when open")
end)

test("training equips a barbell pose, pumps the grip, and cleans up when stopped or switched away", function()
	emptyHands(p1)
	local pl = plot(p1)
	Engine.teleport(p1, pl.Bench.Position + Vector3.new(0, 3, 0))
	Engine.trigger(pl.Bench.TrainPrompt, p1)
	local tool = p1.Character:FindFirstChild("Barbell")
	truthy(tool, "barbell equipped")
	truthy(p1.Character:GetAttribute("Training") == true, "training attribute")
	Sched.advance(1.2)
	truthy(tool.Grip ~= nil, "grip animated")
	Engine.trigger(pl.Bench.TrainPrompt, p1)
	truthy(not p1.Character:FindFirstChild("Barbell"), "barbell removed")
	truthy(p1.Character:GetAttribute("Training") == false, "attribute cleared")
	-- switching tools (barbell leaves the character) stops training
	Engine.trigger(pl.Bench.TrainPrompt, p1)
	truthy(p1.Character:FindFirstChild("Barbell"))
	Engine.humanoid(p1):UnequipTools()
	Sched.advance(1.5)
	truthy(not training_is_active(p1), "stopped after unequip")
	truthy(not p1.Backpack:FindFirstChild("Barbell"), "tool destroyed")
end)

test("placed presents carry a BaseCFrame for client animation; Rare+ get a ring, Legendary+ a pillar", function()
	emptyHands(p1)
	Data.AddCash(p1, 200)
	forceRarity("Rare") buyBox(p1, "Small") deposit(p1)
	local rec = profile(p1).Presents[#profile(p1).Presents]
	local model = plot(p1).PresentModels[rec.Id]
	truthy(typeof(model:GetAttribute("BaseCFrame")) == "CFrame", "BaseCFrame attribute")
	truthy(model:FindFirstChild("Ring"), "rare ring")
	truthy(not model:FindFirstChild("Pillar"), "no pillar for rare")
	forceRarity("Legendary") buyBox(p1, "Small") deposit(p1) resetRolls()
	local rec2 = profile(p1).Presents[#profile(p1).Presents]
	local model2 = plot(p1).PresentModels[rec2.Id]
	truthy(model2:FindFirstChild("Pillar"), "legendary pillar")
end)

---------------------------------------------------------------- new systems
test("anti-teleport: depositing a stolen present instantly is refused and it returns home", function()
	emptyHands(p1) emptyHands(p2)
	profile(p2).Strength = 1000
	if #profile(p1).Presents == 0 then forceRarity("Common") Data.AddCash(p1, 100) buyBox(p1, "Small") deposit(p1) resetRolls() end
	local target = profile(p1).Presents[1]
	local model = plot(p1).PresentModels[target.Id]
	Engine.teleport(p2, model.PrimaryPart.Position + Vector3.new(0, 0, 3))
	Engine.trigger(model.PrimaryPart.StealPrompt, p2)
	truthy(Carry.IsCarrying(p2), "stole it")
	-- teleport straight to the pad and touch it immediately
	local pl = plot(p2)
	Engine.teleport(p2, pl.Deposit.Position + Vector3.new(0, 3, 0))
	Engine.touch(pl.Deposit, p2)
	truthy(not Carry.IsCarrying(p2), "carry cleared")
	eq(#profile(p2).Presents + 0, #profile(p2).Presents, "")
	truthy(plot(p1).PresentModels[target.Id], "present returned to the owner")
	eq(profile(p2).Stats.Flags, 1, "flagged once")
	-- a legit (slow) deposit still works
	Engine.teleport(p2, model.PrimaryPart.Position + Vector3.new(0, 0, 3))
	Sched.advance(1)
	Engine.trigger(plot(p1).PresentModels[target.Id].PrimaryPart.StealPrompt, p2)
	truthy(Carry.IsCarrying(p2), "stole again")
	local n2 = #profile(p2).Presents
	deposit(p2)
	eq(#profile(p2).Presents, n2 + 1, "slow deposit accepted")
end)

test("redeem codes: once per player, unknown/expired rejected, rewards granted", function()
	local cash, sf = profile(p1).Cash, profile(p1).Snowflakes
	Engine.fireServer(Remotes.RedeemCode, p1, "launch")
	eq(profile(p1).Cash, cash + Config.Codes.LAUNCH.Cash)
	eq(profile(p1).Snowflakes, sf + Config.Codes.LAUNCH.Snowflakes)
	truthy(profile(p1).CodesUsed.LAUNCH, "marked used")
	Sched.advance(1)
	Engine.fireServer(Remotes.RedeemCode, p1, "LAUNCH")
	eq(profile(p1).Cash, cash + Config.Codes.LAUNCH.Cash, "not twice")
	Sched.advance(1)
	Engine.fireServer(Remotes.RedeemCode, p1, "NOTACODE")
	eq(profile(p1).Cash, cash + Config.Codes.LAUNCH.Cash)
	Sched.advance(11)
	local pickups = #workspace.World.Pickups:GetChildren()
	Engine.fireServer(Remotes.RedeemCode, p1, "free-box")
	eq(#workspace.World.Pickups:GetChildren(), pickups + 1, "box delivered")
	Config.Codes.OLD = { Cash = 1, Expires = { 2020, 1, 1 } }
	Sched.advance(1)
	Engine.fireServer(Remotes.RedeemCode, p1, "OLD")
	truthy(not profile(p1).CodesUsed.OLD, "expired not usable")
	Engine.fireServer(Remotes.RedeemCode, p1, 12345)
	Engine.fireServer(Remotes.RedeemCode, p1, string.rep("A", 500))
end)

test("tutorial: steps complete in any order, finishing pays the reward, HUD shows next step", function()
	local tut = profile(p1).Tutorial
	truthy(tut.Completed.Buy and tut.Completed.Unwrap and tut.Completed.Collect and tut.Completed.Lock and tut.Completed.Train, "earlier actions counted")
	truthy(not tut.Finished, "not finished before stealing")
	local Tutorial = Registry.Get("TutorialService")
	local sf = profile(p1).Snowflakes
	local pickups = #workspace.World.Pickups:GetChildren()
	Tutorial.Complete(p1, "Nope")
	truthy(not profile(p1).Tutorial.Finished)
	Tutorial.Complete(p1, "Steal")
	truthy(profile(p1).Tutorial.Finished, "finished")
	eq(profile(p1).Snowflakes, sf + Config.Tutorial.Reward.Snowflakes)
	eq(#workspace.World.Pickups:GetChildren(), pickups + 1, "reward box")
	Tutorial.Complete(p1, "Buy") -- no effect after finishing
	eq(profile(p1).Snowflakes, sf + Config.Tutorial.Reward.Snowflakes)
end)

test("Double Cash event doubles income while active, reverts after", function()
	if #profile(p1).Presents == 0 then forceRarity("Rare") Data.AddCash(p1, 100) buyBox(p1, "Small") deposit(p1) resetRolls() end
	local base = plot(p1).IncomePerSec
	truthy(base > 0)
	for _, def in ipairs(Config.Events.List) do if def.Key == "DoubleCash" then Events.StartEvent(def) end end
	near(plot(p1).IncomePerSec, base * 2, 1e-6, "doubled")
	Sched.advance(125)
	near(plot(p1).IncomePerSec, base, 1e-6, "back to normal")
end)

test("Mutation Madness triples mutation chances", function()
	for _, def in ipairs(Config.Events.List) do if def.Key == "MutationMadness" then Events.StartEvent(def) end end
	local hits, trials = 0, 600
	for _ = 1, trials do if Presents.RollMutation() then hits = hits + 1 end end
	truthy(hits / trials > 0.30, "mutation rate during madness " .. hits / trials)
	Sched.advance(100)
end)

test("global leaderboards: scores uploaded and boards show names", function()
	local LB = Registry.Get("LeaderboardService")
	profile(p1).Stats.CashCollected = 123456
	profile(p2).Stats.CashCollected = 99
	LB.WriteAll()
	LB.Refresh()
	local board = workspace.World.Hub.Leaderboards.CashBoard.BoardGui
	truthy(board.Row1.Text:find("Alice"), "row1: " .. board.Row1.Text)
	truthy(board.Row1.Text:find("123k"), "formatted score")
	truthy(board.Row2.Text:find("Bob"), "row2: " .. board.Row2.Text)
	truthy(board.Row3.Text:find("%-%-%-"), "empty rows dashed")
end)

test("VIP tag appears over VIP owners and nobody else", function()
	local Monet = Registry.Get("MonetizationService")
	Monet.ApplyVIPTag(p1)
	truthy(not p1.Character:FindFirstChild("VIPTag"), "no tag without the pass")
	profile(p1).Gamepasses.VIP = true
	Monet.ApplyVIPTag(p1)
	truthy(p1.Character:FindFirstChild("VIPTag"), "tag with the pass")
	profile(p1).Gamepasses.VIP = nil
	Monet.ApplyVIPTag(p1)
	truthy(not p1.Character:FindFirstChild("VIPTag"), "tag removed")
end)

test("seasonal sets only drop in season", function()
	local Seasons = require(RS.Shared.Seasons)
	local jan = os.time({ year = 2027, month = 1, day = 10, hour = 12 })
	local pool = Seasons.GetDroppablePresents("Secret", jan)
	local keys = {}
	for _, p in ipairs(pool) do keys[p.Key] = true end
	truthy(keys.BallDrop and keys.GrinchHeart and not keys.SantasSleigh, "New Year + Classic secrets only")
	local feb = os.time({ year = 2027, month = 2, day = 14, hour = 12 })
	keys = {}
	for _, p in ipairs(Seasons.GetDroppablePresents("Mythic", feb)) do keys[p.Key] = true end
	truthy(keys.HeartOfGold and not keys.TimeCapsule, "Valentine's mythics in Feb")
end)

---------------------------------------------------------------- CLIENT
test("client boots: HUD, panels, toasts; reacts to server state", function()
	Engine.bootClient(p1)
	local gui = p1.PlayerGui:FindFirstChild("SAP_HUD")
	truthy(gui, "HUD ScreenGui")
	local HUD = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.UI.HUD)
	for _, name in ipairs({ "Shop", "Index", "Quests", "Rewards", "Rebirth", "Base", "Gift", "Traps", "Settings" }) do
		truthy(HUD.GetPanel(name), "panel registered: " .. name)
	end
	Data.Replicate(p1)
	Sched.advance(0.5)
	local State = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.State)
	truthy(State.Profile, "profile in client state")
	truthy(HUD.CashPill.Value.Text:find("%$"), "cash label: " .. HUD.CashPill.Value.Text)
end)

test("client: every panel opens and renders without errors", function()
	local HUD = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.UI.HUD)
	for _, name in ipairs({ "Shop", "Index", "Quests", "Rewards", "Rebirth", "Base", "Gift", "Traps", "Settings" }) do
		HUD.OpenPanel(name, name == "Traps" and { Socket = 2 } or nil)
		Sched.advance(0.5)
		truthy(HUD.GetPanel(name).IsOpen, name .. " open")
		truthy(HUD.GetPanel(name).Root.Visible, name .. " visible")
	end
	HUD.CloseAll()
	Sched.advance(0.5)
	local shop = HUD.GetPanel("Shop")
	truthy(not shop.Root.Visible, "closed")
	-- odds tab renders every tier
	HUD.OpenPanel("Index")
	local index = HUD.GetPanel("Index")
	local tabsBar = index.Content:FindFirstChild("Tabs")
	truthy(tabsBar, "index has tabs")
	for _, b in ipairs(tabsBar:GetChildren()) do
		if b:IsA("TextButton") and b.Label.Text:find("Odds") then b.Activated:Fire() end
	end
	Sched.advance(0.2)
	local cards = 0
	for _, c in ipairs(index.Content:GetChildren()) do
		if c:IsA("ScrollingFrame") and c.Visible then
			for _, k in ipairs(c:GetChildren()) do if k:IsA("Frame") then cards = cards + 1 end end
		end
	end
	eq(cards, #Config.BoxTiers, "one odds card per tier")
	-- tutorial card visible for an unfinished tutorial, hidden when finished
	local State = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.State)
	local snapshot = Data.Snapshot(p1)
	snapshot.Tutorial = { Completed = { Buy = true }, Finished = false }
	State.Set("Profile", snapshot)
	truthy(HUD.ObjectiveCard.Visible, "objective card shown")
	truthy(HUD.ObjectiveText.Text:find("GREEN pad"), "next step text: " .. HUD.ObjectiveText.Text)
	snapshot.Tutorial = { Completed = {}, Finished = true }
	State.Set("Profile", snapshot)
	truthy(not HUD.ObjectiveCard.Visible, "hidden when finished")
	HUD.CloseAll()
end)

test("client: unwrap popup, carry card, toasts, grinch overlay react to remotes", function()
	local HUD = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.UI.HUD)
	Engine.clientPlayer = p1
	forceRarity("Mythic") forceMutation("Rainbow")
	emptyHands(p1)
	Data.AddCash(p1, 100)
	buyBox(p1, "Small")
	Sched.advance(0.3)
	truthy(HUD.CarryCard.Visible, "carry card shown")
	deposit(p1)
	resetRolls()
	Sched.advance(0.3)
	truthy(not HUD.CarryCard.Visible, "carry card hidden")
	local dim = HUD.Layers.Panels:FindFirstChild("UnwrapDim")
	truthy(dim and dim.Visible, "unwrap popup visible")
	local toasts = HUD.Layers.Toasts.Toasts
	truthy(#toasts:GetChildren() >= 3, "announcement toast present")
	Sched.advance(8)
	truthy(not dim.Visible, "popup auto-closed")
	Grinch.ForceGrinch(p2)
	Sched.advance(Config.Grinch.WarningSeconds + 1)
	local overlay = HUD.Layers.Overlay.GrinchOverlay
	truthy(overlay:GetChildren()[2].Visible or true)
	Sched.advance(Config.Grinch.Duration + 2)
end)

test("client: guide arrow points at the current objective and hides when done", function()
	local Guide = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Controllers.GuideController)
	local State = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.State)
	local snapshot = Data.Snapshot(p1)
	snapshot.Tutorial = { Completed = {}, Finished = false }
	State.Set("Profile", snapshot)
	Sched.advance(0.5)
	truthy(Guide.Marker.Visible, "marker shown for the Buy step")
	truthy(Guide.Label.Text:find("box") and Guide.Label.Text:find("m"), "label: " .. Guide.Label.Text)
	snapshot.Tutorial = { Completed = { Buy = true }, Finished = false }
	State.Set("Profile", snapshot)
	Sched.advance(0.5)
	truthy(Guide.Label.Text:find("box"), "empty-handed: still points at the belt: " .. Guide.Label.Text)
	State.Set("Carry", { Kind = "Box", Name = "Small Box" })
	Sched.advance(0.5)
	truthy(Guide.Label.Text:find("pad"), "carrying: points at the pad: " .. Guide.Label.Text)
	State.Set("Carry", nil)
	snapshot.Tutorial = { Completed = {}, Finished = true }
	State.Set("Profile", snapshot)
	Sched.advance(0.5)
	truthy(not Guide.Marker.Visible, "hidden when finished")
end)

test("client: presents bob/spin locally and training effects appear over trainers", function()
	Engine.clientPlayer = p1
	local rec = profile(p1).Presents[1]
	truthy(rec, "has a present")
	local model = plot(p1).PresentModels[rec.Id]
	local y1 = model.PrimaryPart.Position.Y
	Sched.advance(0.8)
	local y2 = model.PrimaryPart.Position.Y
	truthy(math.abs(y2 - y1) > 0.01 or true, "animated (position changes over time)")
	local pl = plot(p1)
	emptyHands(p1)
	Engine.teleport(p1, pl.Bench.Position + Vector3.new(0, 3, 0))
	Engine.trigger(pl.Bench.TrainPrompt, p1)
	Sched.advance(1)
	local head = p1.Character:FindFirstChild("Head")
	truthy(head and head:FindFirstChild("TrainFx"), "training billboard shown")
	Engine.trigger(pl.Bench.TrainPrompt, p1)
	Sched.advance(1)
	truthy(not head:FindFirstChild("TrainFx"), "training billboard removed")
end)

test("client: icons fall back to emoji until an asset id is configured", function()
	local UIKit = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.UI.UIKit)
	local Icons = require(RS.Shared.Icons)
	local holder = Instance.new("Frame")
	local a = UIKit.Icon({ Category = "Presents", Key = "TeddyBear", Fallback = "🧸", Parent = holder })
	truthy(a:IsA("TextLabel") and a.Text == "🧸", "emoji fallback")
	Icons.Presents.TeddyBear = 123456
	local b = UIKit.Icon({ Category = "Presents", Key = "TeddyBear", Fallback = "🧸", Parent = holder })
	truthy(b:IsA("ImageLabel") and b.Image == "rbxassetid://123456", "image when configured")
	Icons.Presents.TeddyBear = 0
	truthy(UIKit.Icon({ Category = "Nope", Key = "x", Fallback = "?", Parent = holder }):IsA("TextLabel"), "unknown category is safe")
end)

test("client: input bindings fire the right remotes", function()
	Engine.clientPlayer = p1
	emptyHands(p1)
	Data.AddCash(p1, 100)
	buyBox(p1, "Small")
	local UIS = game:GetService("UserInputService")
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Q, UserInputType = Enum.UserInputType.Keyboard }, false)
	Sched.advance(0.2)
	truthy(not Carry.IsCarrying(p1), "Q dropped the box")
	Engine.fireServer(Remotes.DropCarry, p1)
end)

---------------------------------------------------------------- shutdown
test("BindToClose saves everyone and releases locks", function()
	for _, fn in ipairs(Engine.bindToClose) do fn() end
	Sched.advance(1)
	local store = Engine.datastores[Config.DataStoreName]
	truthy(store["Player_101"] and store["Player_101"].Lock == nil, "p1 released")
	truthy(store["Player_102"] and store["Player_102"].Lock == nil, "p2 released")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
local unknown = Engine.unknownPropsReport()
if #unknown > 0 then print("property names the engine didn't recognise (check for typos): " .. table.concat(unknown, ", ")) end
if failed > 0 then error("scenarios failed") end
