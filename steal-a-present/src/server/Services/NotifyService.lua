--[[
	NotifyService.lua
	Tiny helpers for personal toasts, server-wide announcements and world effects.
	kind: "info" | "success" | "error" | "rare"
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local NotifyService = {}

function NotifyService.Notify(player, text, kind)
	if player and player.Parent then
		Remotes.Get("Notify"):FireClient(player, text, kind or "info")
	end
end

function NotifyService.Announce(text, color, kind)
	Remotes.Get("Announce"):FireAllClients(text, color, kind or "info")
end

function NotifyService.Effect(name, position, extra)
	Remotes.Get("PlayEffect"):FireAllClients(name, position, extra)
end

function NotifyService.Init() end
function NotifyService.Start() end

return NotifyService
