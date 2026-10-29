--[[
	Seasons.lua  (ReplicatedStorage.Shared.Seasons)
	Which season is active right now, which present Set drops, and the countdown.
]]

local Catalog = require(script.Parent.Catalog)
local Util = require(script.Parent.Util)

local Seasons = {}

-- Returns the active season table (or Catalog.DefaultSeason) and seconds until it ends (or nil)
function Seasons.GetActive(now)
	now = now or os.time()
	for _, season in ipairs(Catalog.Seasons) do
		local startT = Util.DateToUnix(season.Start)
		local endT = Util.DateToUnix(season.End)
		if now >= startT and now < endT then
			return season, endT - now
		end
	end
	-- Not in a season: count down to the next one that starts
	local nextStart
	for _, season in ipairs(Catalog.Seasons) do
		local startT = Util.DateToUnix(season.Start)
		if startT > now and (not nextStart or startT < nextStart) then
			nextStart = startT
		end
	end
	return Catalog.DefaultSeason, nextStart and (nextStart - now) or nil
end

-- Which present sets can drop right now
function Seasons.GetActiveSets(now)
	local season = Seasons.GetActive(now)
	local sets = { Classic = true }
	if season.Set then
		sets[season.Set] = true
	end
	return sets
end

-- Presents of a rarity that can drop right now (falls back to all of that rarity)
function Seasons.GetDroppablePresents(rarity, now)
	local sets = Seasons.GetActiveSets(now)
	local out = {}
	for _, present in ipairs(Catalog.PresentsByRarity[rarity] or {}) do
		if sets[present.Set] then
			table.insert(out, present)
		end
	end
	if #out == 0 then
		out = Catalog.PresentsByRarity[rarity] or {}
	end
	return out
end

return Seasons
