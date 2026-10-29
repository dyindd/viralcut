--[[
	GrinchService.lua  - the signature "clip this" moment.
	Every Config.Grinch.Interval seconds one random player becomes THE GRINCH for 60s:
	glowing green, fast, can steal from LOCKED bases. Everyone else gets snowballs.
	Land the final hit = big reward. Survive the full timer as the Grinch = bigger reward.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Parent.Registry)

local GrinchService = {}

local state = {
	Active = false,
	Player = nil,
	EndsAt = 0,
	Hits = 0,
	NextAt = 0,
	Warning = nil,   -- player being warned
	WarningEndsAt = 0,
}
local lastGrinch = {}  -- [userId] = os.clock()
local forced = nil
local highlight

local function now() return Workspace:GetServerTimeNow() end
local function Data() return Registry.Get("DataService") end
local function Notify() return Registry.Get("NotifyService") end
local function Combat() return Registry.Get("CombatService") end

local function broadcast()
	Remotes.Get("GrinchState"):FireAllClients({
		Active = state.Active,
		UserId = state.Player and state.Player.UserId or nil,
		Name = state.Player and state.Player.DisplayName or nil,
		EndsAt = state.EndsAt,
		Hits = state.Hits,
		HitsToDefeat = Config.Grinch.HitsToDefeat,
		NextAt = state.NextAt,
		WarningUserId = state.Warning and state.Warning.UserId or nil,
		WarningName = state.Warning and state.Warning.DisplayName or nil,
		WarningEndsAt = state.WarningEndsAt,
		Now = now(),
	})
end

local function scale(player, base)
	local profile = Data().GetProfile(player)
	local rebirths = profile and profile.Rebirths or 0
	return math.floor(base * (1 + rebirths * Config.Grinch.RebirthScale))
end

function GrinchService.SendTo(player)
	-- same payload as broadcast(), to one player
	Remotes.Get("GrinchState"):FireClient(player, {
		Active = state.Active,
		UserId = state.Player and state.Player.UserId or nil,
		Name = state.Player and state.Player.DisplayName or nil,
		EndsAt = state.EndsAt,
		Hits = state.Hits,
		HitsToDefeat = Config.Grinch.HitsToDefeat,
		NextAt = state.NextAt,
		WarningUserId = state.Warning and state.Warning.UserId or nil,
		WarningName = state.Warning and state.Warning.DisplayName or nil,
		WarningEndsAt = state.WarningEndsAt,
		Now = now(),
	})
end

function GrinchService.IsGrinch(player)
	return state.Active and state.Player == player
end

function GrinchService.GetState()
	return state
end

local function pickCandidate()
	if forced and forced.Parent and Data().GetProfile(forced) then
		local p = forced
		forced = nil
		return p
	end
	local pool = {}
	local oldest = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and Data().GetProfile(player) then
			local last = lastGrinch[player.UserId] or 0
			if last < oldest then oldest = last end
			table.insert(pool, player)
		end
	end
	if #pool == 0 then return nil end
	-- prefer players who haven't been the Grinch recently
	local fresh = {}
	for _, p in ipairs(pool) do
		if (lastGrinch[p.UserId] or 0) <= oldest then table.insert(fresh, p) end
	end
	local list = #fresh > 0 and fresh or pool
	return list[math.random(1, #list)]
end

local function applyGrinchVisuals(player)
	local char = player.Character
	if not char then return end
	highlight = Instance.new("Highlight")
	highlight.Name = "GrinchGlow"
	highlight.FillColor = Color3.fromRGB(60, 255, 90)
	highlight.OutlineColor = Color3.fromRGB(20, 120, 40)
	highlight.FillTransparency = 0.35
	highlight.Parent = char
	local bb = Instance.new("BillboardGui")
	bb.Name = "GrinchTag"
	bb.Size = UDim2.new(0, 220, 0, 60)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = char:FindFirstChild("Head") or char.PrimaryPart
	bb.Parent = char
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.new(1, 0, 1, 0)
	tl.Font = Enum.Font.FredokaOne
	tl.TextScaled = true
	tl.Text = "💚 THE GRINCH 💚"
	tl.TextColor3 = Color3.fromRGB(80, 255, 110)
	tl.TextStrokeTransparency = 0
	tl.Parent = bb
end

local function removeGrinchVisuals(player)
	local char = player.Character
	if char then
		local h = char:FindFirstChild("GrinchGlow")
		if h then h:Destroy() end
		local t = char:FindFirstChild("GrinchTag")
		if t then t:Destroy() end
	end
	highlight = nil
end

local function endRound(reason, finisher)
	if not state.Active then return end
	local grinch = state.Player
	state.Active = false
	local Carry = Registry.Get("CarryService")
	if grinch and grinch.Parent then
		removeGrinchVisuals(grinch)
		Carry.SetSpeedModifier(grinch, "Grinch", nil)
		lastGrinch[grinch.UserId] = os.clock()
	end
	for _, player in ipairs(Players:GetPlayers()) do
		Combat().RemoveSnowball(player)
	end
	if reason == "survived" and grinch and grinch.Parent then
		local profile = Data().GetProfile(grinch)
		local cash = scale(grinch, Config.Grinch.SurviveReward)
		Data().AddCash(grinch, cash)
		Data().AddSnowflakes(grinch, Config.Grinch.SnowflakesForSurvive)
		if profile then profile.Stats.GrinchWins = (profile.Stats.GrinchWins or 0) + 1 end
		Registry.Get("ConveyorService").GiveBoxAtBase(grinch, Config.Grinch.SurviveBoxTier)
		Notify().Announce(grinch.DisplayName .. " SURVIVED as the Grinch and stole Christmas! +$" .. Util.FormatNumber(cash), Color3.fromRGB(80, 255, 110), "grinch")
	elseif reason == "defeated" then
		if grinch and grinch.Parent then
			Carry.Drop(grinch, "hit")
			Carry.SetSpeedModifier(grinch, "Stun", 0)
			task.delay(2, function() if grinch.Parent then Carry.SetSpeedModifier(grinch, "Stun", nil) end end)
		end
		if finisher and finisher.Parent then
			local cash = scale(finisher, Config.Grinch.TagReward)
			Data().AddCash(finisher, cash)
			Data().AddSnowflakes(finisher, Config.Grinch.SnowflakesForTag)
			Notify().Announce(finisher.DisplayName .. " defeated the Grinch! +$" .. Util.FormatNumber(cash), Color3.fromRGB(255, 230, 80), "grinch")
		end
	else
		Notify().Announce("The Grinch has fled!", Color3.fromRGB(200, 200, 200), "grinch")
	end
	state.Player = nil
	state.Hits = 0
	state.EndsAt = 0
	state.NextAt = now() + Config.Grinch.Interval
	broadcast()
end

local function startRound(player)
	if state.Active or not player.Parent or not player.Character then return end
	state.Active = true
	state.Player = player
	state.Hits = 0
	state.EndsAt = now() + Config.Grinch.Duration
	state.Warning = nil
	applyGrinchVisuals(player)
	Registry.Get("CarryService").SetSpeedModifier(player, "Grinch", Config.Grinch.WalkSpeed / Config.Carry.BaseWalkSpeed)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			Combat().GiveSnowball(other)
		end
	end
	Notify().Announce("💚 " .. player.DisplayName .. " IS THE GRINCH! Hit them with snowballs " .. Config.Grinch.HitsToDefeat .. " times!", Color3.fromRGB(80, 255, 110), "grinch")
	Notify().Notify(player, "YOU are the Grinch! You can steal from LOCKED bases. Survive " .. Config.Grinch.Duration .. "s for a huge reward!", "success")
	broadcast()
	local thisRound = state.EndsAt
	task.delay(Config.Grinch.Duration, function()
		if state.Active and state.EndsAt == thisRound then
			endRound("survived")
		end
	end)
end

function GrinchService.RegisterHit(attacker, grinch, source)
	if not state.Active or state.Player ~= grinch or attacker == grinch then return end
	state.Hits = state.Hits + 1
	local profile = Data().GetProfile(attacker)
	if profile then
		profile.Stats.GrinchTags = (profile.Stats.GrinchTags or 0) + 1
	end
	Data().AddCash(attacker, scale(attacker, Config.Grinch.AssistReward))
	Registry.Get("QuestService").Progress(attacker, "GrinchTag", 1)
	Notify().Effect("GrinchHit", nil, { Hits = state.Hits })
	if state.Hits >= Config.Grinch.HitsToDefeat then
		endRound("defeated", attacker)
	else
		Notify().Announce(attacker.DisplayName .. " hit the Grinch! (" .. state.Hits .. "/" .. Config.Grinch.HitsToDefeat .. ")", Color3.fromRGB(200, 255, 220), "info")
		broadcast()
	end
end

-- Dev product: become the Grinch (starts now if nobody is the Grinch, else you're next)
function GrinchService.ForceGrinch(player)
	forced = player
	if not state.Active and not state.Warning then
		state.NextAt = now()
	else
		Notify().Notify(player, "You'll be the next Grinch!", "success")
	end
end

local function scheduler()
	state.NextAt = now() + Config.Grinch.Interval
	broadcast()
	while true do
		task.wait(1)
		if Config.Grinch.Enabled and not state.Active and not state.Warning and now() >= state.NextAt then
			if #Players:GetPlayers() >= Config.Grinch.MinPlayers or forced then
				local candidate = pickCandidate()
				if candidate then
					state.Warning = candidate
					state.WarningEndsAt = now() + Config.Grinch.WarningSeconds
					Notify().Announce("⚠️ " .. candidate.DisplayName .. " is turning into the GRINCH in " .. Config.Grinch.WarningSeconds .. " seconds! Lock your bases!", Color3.fromRGB(255, 200, 80), "warning")
					broadcast()
					task.wait(Config.Grinch.WarningSeconds)
					local who = state.Warning
					state.Warning = nil
					if who and who.Parent and who.Character then
						startRound(who)
					else
						state.NextAt = now() + 30
						broadcast()
					end
				else
					state.NextAt = now() + 60
				end
			else
				state.NextAt = now() + 60
				broadcast()
			end
		end
	end
end

function GrinchService.Init() end

function GrinchService.Start()
	task.spawn(scheduler)
	Players.PlayerRemoving:Connect(function(player)
		if state.Active and state.Player == player then
			endRound("left")
		end
		if forced == player then forced = nil end
		lastGrinch[player.UserId] = nil
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			if state.Active and state.Player == player then
				task.wait(0.3)
				applyGrinchVisuals(player)
			elseif state.Active then
				task.wait(0.5)
				Combat().GiveSnowball(player)
			end
		end)
		task.delay(2, broadcast)
	end)
end

return GrinchService
