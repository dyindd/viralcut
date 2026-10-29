--[[
	CodeService.lua - redeem codes (Config.Codes). Each player can use each code once.
	Share codes in your TikToks / Discord; expire them with the Expires date.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Registry = require(script.Parent.Parent.Registry)
local Validate = require(script.Parent.Parent.Validate)
local RateLimiter = require(script.Parent.Parent.RateLimiter)

local CodeService = {}

local function Data() return Registry.Get("DataService") end
local function Notify() return Registry.Get("NotifyService") end

function CodeService.Redeem(player, code)
	if not RateLimiter.Check(player, "Code") then return false end
	if not Validate.IsString(code, 32) then return false end
	local profile = Data().GetProfile(player)
	if not profile then return false end
	code = code:upper():gsub("[^%w]", "")
	local def = Config.Codes[code]
	if not def then
		Notify().Notify(player, "Unknown code. Follow us on TikTok for new codes!", "error")
		return false
	end
	if def.Expires and os.time() >= Util.DateToUnix(def.Expires) then
		Notify().Notify(player, "That code has expired!", "error")
		return false
	end
	if profile.CodesUsed[code] then
		Notify().Notify(player, "You already used that code!", "info")
		return false
	end
	profile.CodesUsed[code] = os.time()
	local parts = {}
	local Retention = Registry.Get("RetentionService")
	if def.Cash then table.insert(parts, Retention.Grant(player, profile, { Type = "Cash", Amount = def.Cash })) end
	if def.Snowflakes then table.insert(parts, Retention.Grant(player, profile, { Type = "Snowflakes", Amount = def.Snowflakes })) end
	if def.Box then table.insert(parts, Retention.Grant(player, profile, { Type = "Box", Tier = def.Box })) end
	if def.Luck then table.insert(parts, Retention.Grant(player, profile, { Type = "Luck", Minutes = def.Luck })) end
	Notify().Notify(player, "Code " .. code .. " redeemed: " .. table.concat(parts, ", ") .. "!", "success")
	Notify().Effect("Reward", nil, nil)
	Data().Replicate(player)
	return true
end

function CodeService.Init()
	Remotes.Get("RedeemCode").OnServerEvent:Connect(CodeService.Redeem)
end

function CodeService.Start() end

return CodeService
