--[[
	Main.client.lua  (StarterPlayerScripts.Client.Main)
	Builds the HUD + panels, wires every server remote into State, starts the controllers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local UI = script.Parent.UI
local Controllers = script.Parent.Controllers

local HUD = require(UI.HUD)
HUD.Build()

require(UI.Toasts).Create(HUD)
require(UI.UnwrapPopup).Create(HUD)
require(UI.GrinchOverlay).Create(HUD)

local Panels = UI.Panels
for _, name in ipairs({ "ShopPanel", "IndexPanel", "QuestsPanel", "RewardsPanel", "RebirthPanel", "BasePanel", "GiftPanel", "TrapsPanel", "SettingsPanel" }) do
	local ok, err = pcall(function() require(Panels[name]).Create(HUD) end)
	if not ok then warn("[Client] panel failed: " .. name .. " - " .. tostring(err)) end
end

-- remotes -> state
Remotes.Get("DataChanged").OnClientEvent:Connect(function(profile) State.Set("Profile", profile) end)
Remotes.Get("BaseState").OnClientEvent:Connect(function(base) State.Set("Base", base) end)
Remotes.Get("CarryState").OnClientEvent:Connect(function(info) State.Set("Carry", info) end)
Remotes.Get("GrinchState").OnClientEvent:Connect(function(g) State.Set("Grinch", g) end)
Remotes.Get("EventState").OnClientEvent:Connect(function(e) State.Set("Event", e) end)
Remotes.Get("QuestsChanged").OnClientEvent:Connect(function(list) State.Set("Quests", list) end)
Remotes.Get("StreakChanged").OnClientEvent:Connect(function(info) State.Set("Streak", info) end)
Remotes.Get("OpenPanel").OnClientEvent:Connect(function(name, data) HUD.OpenPanel(name, data) end)

-- controllers
require(Controllers.SoundController).Start()
require(Controllers.EffectsController).Start()
require(Controllers.InputController).Start(HUD)
task.spawn(function() require(Controllers.PromptController).Start() end)

-- initial snapshot (in case DataChanged fired before we were listening)
task.spawn(function()
	local ok, profile = pcall(function() return Remotes.Get("GetProfile"):InvokeServer() end)
	if ok and profile and not State.Profile then
		State.Set("Profile", profile)
	end
end)

print("[Steal a Present] client ready")
