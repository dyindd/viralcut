--[[
	RateLimiter.lua  (ServerScriptService.Server.RateLimiter)
	Simple sliding-window limiter: RateLimiter.Check(player, "BuyBox") -> true if allowed.
	Limits come from Config.RateLimits (falls back to Default).
]]

local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local RateLimiter = {}
local buckets = {}   -- [userId][key] = { times = {} }
local strikes = {}   -- [userId] = count of rejected calls (for logging / kicking)

local function getLimit(key)
	return Config.RateLimits[key] or Config.RateLimits.Default
end

function RateLimiter.Check(player, key)
	if not player or not player.Parent then return false end
	local limit = getLimit(key)
	local now = os.clock()
	local userBuckets = buckets[player.UserId]
	if not userBuckets then
		userBuckets = {}
		buckets[player.UserId] = userBuckets
	end
	local bucket = userBuckets[key]
	if not bucket then
		bucket = {}
		userBuckets[key] = bucket
	end
	-- drop old timestamps
	local i = 1
	while i <= #bucket do
		if now - bucket[i] > limit.Per then
			table.remove(bucket, i)
		else
			i = i + 1
		end
	end
	if #bucket >= limit.Calls then
		strikes[player.UserId] = (strikes[player.UserId] or 0) + 1
		if strikes[player.UserId] % 50 == 0 then
			warn(string.format("[RateLimiter] %s hit the limit for %s %d times", player.Name, key, strikes[player.UserId]))
		end
		return false
	end
	table.insert(bucket, now)
	return true
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player.UserId] = nil
	strikes[player.UserId] = nil
end)

return RateLimiter
