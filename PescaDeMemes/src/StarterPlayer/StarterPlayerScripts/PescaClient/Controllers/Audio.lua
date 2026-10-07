--[[
	PescaDeMemes • Audio (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > Audio

	Fase 3 (vertical slice): todo lo que suena.
	  · Grupos de sonido "Efectos" y "Música" (SoundService) y precarga de los efectos (UIKit.PreloadSounds).
	  · Música en bucle con dos ambientes que se cruzan suavemente: superficie ↔ bajo el agua (Config/Assets.Music).
	  · Ajustes guardados en tus datos (Settings.Music / Settings.SFX): se cambian en ⚙️ Ajustes.
	  · Sonidos de eventos del mundo: llega el mercader, alguien pesca algo épico.
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local Assets = require(Root.Config.Assets)
local Remotes = require(Root.Shared.Remotes)

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)
local State = require(Controllers.State)
local DiveScene = require(Controllers.DiveScene)

local Audio = {}

local sfxGroup: SoundGroup
local musicGroup: SoundGroup
local tracks: { [string]: Sound } = {}
local currentMood: string? = nil
local musicOn = true
local rng = Random.new()

local function group(name: string, volume: number): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	return UIKit.new("SoundGroup", { Name = name, Volume = volume, Parent = SoundService })
end

-- Una pista por ambiente (elige una al azar de su lista). nil si la lista está vacía.
local function trackFor(mood: string): Sound?
	if tracks[mood] then
		return tracks[mood]
	end
	local list = Assets.Music[mood]
	if type(list) ~= "table" or #list == 0 then
		return nil
	end
	local sound = UIKit.new("Sound", { Name = "Music_" .. mood, SoundId = list[rng:NextInteger(1, #list)], Looped = true,
		Volume = 0, SoundGroup = musicGroup, Parent = SoundService })
	tracks[mood] = sound
	return sound
end

local function fadeTo(mood: string?)
	for name, sound in pairs(tracks) do
		if name ~= mood and sound.IsPlaying then
			local tween = TweenService:Create(sound, TweenInfo.new(1.2), { Volume = 0 })
			tween.Completed:Once(function()
				if currentMood ~= name or not musicOn then
					sound:Pause()
				end
			end)
			tween:Play()
		end
	end
	local sound = mood and musicOn and trackFor(mood)
	if sound then
		if not sound.IsPlaying then
			sound:Resume()
			if not sound.IsPlaying then
				sound:Play()
			end
		end
		TweenService:Create(sound, TweenInfo.new(1.2), { Volume = Assets.MusicVolume }):Play()
	end
end

local function applySettings()
	local data = State.Data
	local settings = data and data.Settings
	local sfx = not settings or settings.SFX ~= false
	local music = not settings or settings.Music ~= false
	UIKit.SFXEnabled = sfx
	sfxGroup.Volume = if sfx then 1 else 0
	if music ~= musicOn then
		musicOn = music
		fadeTo(if music then currentMood else nil)
	end
end

function Audio.Init()
	sfxGroup = group("Efectos", 1)
	musicGroup = group("Musica", 1)
	UIKit.SFXGroup = sfxGroup
	UIKit.PreloadSounds()
	State.Changed:Connect(applySettings)
	applySettings()

	-- ambiente: superficie o bajo el agua
	task.spawn(function()
		while true do
			local mood = if DiveScene.Active() then "Dive" else "Surface"
			if mood ~= currentMood then
				currentMood = mood
				fadeTo(mood)
			end
			task.wait(0.5)
		end
	end)

	workspace:GetAttributeChangedSignal("MerchantOpen"):Connect(function()
		if workspace:GetAttribute("MerchantOpen") == true then
			UIKit.playSound("Merchant")
		end
	end)
	Remotes.Get("Announce").OnClientEvent:Connect(function(_, _, userId)
		-- la captura de OTRO jugador: un destello; la tuya ya tiene su celebración
		if userId ~= game:GetService("Players").LocalPlayer.UserId then
			UIKit.playSound("Rare")
		end
	end)
end

return Audio
