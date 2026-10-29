--[[
	Remotes.lua  (ReplicatedStorage.Shared.Remotes)

	ONE place that defines every RemoteEvent / RemoteFunction. The server creates them,
	the client waits for them. Use Remotes.Get("Name") on either side.

	Direction legend:  C->S client fires server,  S->C server fires client(s)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Events = {
	-- C->S
	"BuyBox",            -- (boxInstanceId)   buy the box you are standing next to on the conveyor
	"DropCarry",         -- ()                drop what you are carrying
	"LockBase",          -- ()
	"Rebirth",           -- ()
	"ClaimStreak",       -- ()                claim today's calendar reward
	"ClaimQuest",        -- (questId)
	"ClaimPlaytimeGift", -- ()
	"GiftPresent",       -- (presentId, targetUserId)
	"BuyTrap",           -- (trapKey, socketIndex)
	"BuySnowflakeItem",  -- (shopKey)
	"ThrowSnowball",     -- (direction: Vector3)
	"SellPresent",       -- (presentId)       sell a present at your base for cash
	"SetSetting",        -- (key, value)
	"PromptPurchase",    -- (kind, key)       kind = "Gamepass" | "Product"
	-- S->C
	"DataChanged",       -- (partialProfile)  cheap fields the HUD shows
	"UnwrapResult",      -- (presentRecord, boxTier)   -> unwrap popup for the owner
	"Announce",          -- (text, color, kind)        -> server-wide toast
	"Notify",            -- (text, kind)               -> small personal toast
	"GrinchState",       -- (state table)
	"EventState",        -- (state table)
	"CarryState",        -- (carryInfo or nil)
	"BaseState",         -- (baseInfo)                 lock timer, pile, slots
	"QuestsChanged",     -- (questList)
	"StreakChanged",     -- (streakInfo)
	"PlayEffect",        -- (effectName, position, extra)
	"OpenPanel",         -- (panelName, data)           server asks the client to open a panel (e.g. trap socket prompt)
}

Remotes.Functions = {
	"GetProfile",        -- () -> profile snapshot (called once on join)
}

local folder

local function ensureFolder()
	if folder then return folder end
	if RunService:IsServer() then
		folder = ReplicatedStorage:FindFirstChild("Remotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end
		for _, name in ipairs(Remotes.Events) do
			if not folder:FindFirstChild(name) then
				local ev = Instance.new("RemoteEvent")
				ev.Name = name
				ev.Parent = folder
			end
		end
		for _, name in ipairs(Remotes.Functions) do
			if not folder:FindFirstChild(name) then
				local fn = Instance.new("RemoteFunction")
				fn.Name = name
				fn.Parent = folder
			end
		end
	else
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end
	return folder
end

function Remotes.Get(name)
	local f = ensureFolder()
	if RunService:IsServer() then
		local r = f:FindFirstChild(name)
		if not r then
			error("Unknown remote: " .. tostring(name))
		end
		return r
	end
	return f:WaitForChild(name)
end

-- Server only: create everything up front
function Remotes.Init()
	ensureFolder()
end

return Remotes
