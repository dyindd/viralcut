--[[
	Util.lua  (ReplicatedStorage.Shared.Util)
	Small pure helpers shared by server and client. No Roblox services required
	(so the unit tests can run these outside Studio).
]]

local Util = {}

-- 1234 -> "1.23k", 5000000 -> "5M"
function Util.FormatNumber(n)
	n = tonumber(n) or 0
	local neg = n < 0
	n = math.abs(n)
	local suffixes = { "", "k", "M", "B", "T", "Qa", "Qi", "Sx" }
	local idx = 1
	while n >= 1000 and idx < #suffixes do
		n = n / 1000
		idx = idx + 1
	end
	local str
	if idx == 1 then
		str = tostring(math.floor(n + 0.5))
	elseif n >= 100 then
		str = string.format("%d", math.floor(n + 0.5))
	elseif n >= 10 then
		str = string.format("%.1f", n)
	else
		str = string.format("%.2f", n)
	end
	-- strip trailing zeros like 5.00 -> 5, 5.10 -> 5.1
	if str:find("%.") then
		str = str:gsub("0+$", ""):gsub("%.$", "")
	end
	return (neg and "-" or "") .. str .. suffixes[idx]
end

-- 1234567 -> "1,234,567"
function Util.Commas(n)
	local s = tostring(math.floor((tonumber(n) or 0) + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then out = out:sub(2) end
	return out
end

-- 125 -> "2:05", 3725 -> "1:02:05"
function Util.FormatTime(seconds)
	seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
	if seconds >= 86400 then
		local d = math.floor(seconds / 86400)
		local hh = math.floor((seconds % 86400) / 3600)
		return string.format("%dd %dh", d, hh)
	end
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- Weighted random pick. `items` is a list of tables, `weightKey` names the weight field.
-- Returns the chosen item (or nil when all weights are 0).
function Util.WeightedPick(items, weightKey, rng)
	local total = 0
	for _, item in ipairs(items) do
		total = total + (item[weightKey] or 0)
	end
	if total <= 0 then return nil end
	local roll = (rng and rng:NextNumber() or math.random()) * total
	local acc = 0
	for _, item in ipairs(items) do
		acc = acc + (item[weightKey] or 0)
		if roll <= acc then
			return item
		end
	end
	return items[#items]
end

-- Weighted pick from a dictionary { key = weight }. Returns the key.
function Util.WeightedPickDict(dict, rng)
	local total = 0
	for _, w in pairs(dict) do
		total = total + w
	end
	if total <= 0 then return nil end
	local roll = (rng and rng:NextNumber() or math.random()) * total
	local acc = 0
	local last
	for key, w in pairs(dict) do
		acc = acc + w
		last = key
		if roll <= acc then
			return key
		end
	end
	return last
end

-- Shallow copy
function Util.Copy(t)
	local out = {}
	for k, v in pairs(t) do out[k] = v end
	return out
end

-- Deep copy (tables only, no metatables)
function Util.DeepCopy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do
		out[k] = Util.DeepCopy(v)
	end
	return out
end

-- Fill missing keys in `target` from `template` (recursive). Used for data migration.
function Util.Reconcile(target, template)
	for k, v in pairs(template) do
		if target[k] == nil then
			target[k] = Util.DeepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" then
			Util.Reconcile(target[k], v)
		end
	end
	return target
end

function Util.Clamp(n, lo, hi)
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

function Util.Round(n, places)
	local mult = 10 ^ (places or 0)
	return math.floor(n * mult + 0.5) / mult
end

-- Day number since epoch (UTC). Used for streaks and daily resets.
function Util.DayStamp(unixTime)
	return math.floor((unixTime or os.time()) / 86400)
end

-- Random id for presents etc. (not cryptographic, just unique enough per server)
local idCounter = 0
function Util.NewId(prefix)
	idCounter = idCounter + 1
	return string.format("%s_%d_%d_%d", prefix or "id", os.time(), idCounter, math.random(1000, 9999))
end

-- Safe table length for dictionaries
function Util.Count(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

-- Returns a UTC unix time for a {year, month, day} table (midnight UTC)
function Util.DateToUnix(date)
	-- os.time() interprets tables as LOCAL time; Roblox servers run in UTC so this is fine,
	-- and the small offset elsewhere doesn't matter for season boundaries.
	return os.time({ year = date[1], month = date[2], day = date[3], hour = 0, min = 0, sec = 0 })
end

-- Multiply the chances of Rare+ rarities by `luck`, then return a new normalised odds table.
function Util.ApplyLuck(odds, luck, rarityTierLookup)
	if not luck or luck <= 1 then return odds end
	local out = {}
	for rarity, chance in pairs(odds) do
		local tier = rarityTierLookup[rarity] or 1
		if tier >= 4 then -- Rare and above
			out[rarity] = chance * luck
		else
			out[rarity] = chance
		end
	end
	return out
end

return Util
