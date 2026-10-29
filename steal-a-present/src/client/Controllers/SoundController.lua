--[[
	SoundController.lua - plays sounds by key from Config.Sounds, respects the Music/SFX settings.
	IDs of 0 are silent. Replace the IDs in Config with your own uploads.
]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.Parent.State)

local SoundController = {}
local cache = {}
local music

local function sfxEnabled()
	return not State.Profile or State.Profile.Settings.SFX ~= false
end

function SoundController.Play(key, volume, pitch)
	if not sfxEnabled() then return end
	local id = Config.Sounds[key]
	if not id or id == 0 then return end
	local sound = cache[key]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = key
		sound.SoundId = "rbxassetid://" .. id
		sound.Parent = SoundService
		cache[key] = sound
	end
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = pitch or 1
	sound:Play()
end

function SoundController.PlayAt(key, position, volume)
	if not sfxEnabled() or not position then return end
	local id = Config.Sounds[key]
	if not id or id == 0 then return end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.Position = position
	part.Parent = workspace
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. id
	sound.Volume = volume or 0.8
	sound.RollOffMaxDistance = 90
	sound.Parent = part
	sound:Play()
	sound.Ended:Connect(function() part:Destroy() end)
	task.delay(6, function() if part.Parent then part:Destroy() end end)
end

function SoundController.UpdateMusic()
	local wants = not State.Profile or State.Profile.Settings.Music ~= false
	if Config.Sounds.Music == 0 then return end
	if not music then
		music = Instance.new("Sound")
		music.Name = "Music"
		music.SoundId = "rbxassetid://" .. Config.Sounds.Music
		music.Looped = true
		music.Volume = Config.Sounds.MusicVolume
		music.Parent = SoundService
	end
	if wants and not music.IsPlaying then music:Play() end
	if not wants and music.IsPlaying then music:Stop() end
end

function SoundController.Start()
	State.On("Profile", SoundController.UpdateMusic)
	State.On("Settings", SoundController.UpdateMusic)
	SoundController.UpdateMusic()
end

return SoundController
