--[[
	PescaDeMemes • WeatherController (ModuleScript, cliente)
	StarterPlayerScripts > PescaClient > Controllers > WeatherController

	Pinta el clima que publica el servidor (Workspace "Weather" / "WeatherEnds", Config/Weather):
	  ☀️ Soleado    la luz normal del mapa
	  🌧️ Lluvia     cielo gris, menos luz, lluvia alrededor de la cámara
	  ⛈️ Tormenta   más oscuro, lluvia fuerte y RAYOS (destello + trueno) cada pocos segundos
	  🌕 Luna llena de noche, luz violeta y polvo de luna
	Y un aviso arriba con el clima, la mutación que puede salir y cuánto queda. Todo es local (solo se ve).
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local Weather = require(Root.Config.Weather)

local Controllers = script.Parent
local UIKit = require(Controllers.UIKit)
local DiveScene = require(Controllers.DiveScene)

local T = UIKit.Theme
local RGB = Color3.fromRGB
local WeatherController = {}

-- Cómo se ve cada clima (relativo a la luz que puso el servidor al construir el mapa).
local LOOKS = {
	Sunny = { Brightness = 3, ClockTime = 14, Ambient = RGB(120, 120, 120), Outdoor = RGB(160, 160, 160),
		AtmoDensity = 0.2, AtmoColor = RGB(200, 225, 245), Saturation = 0.2, Tint = RGB(255, 255, 255), Rain = 0, Dust = 0 },
	Rain = { Brightness = 1.8, ClockTime = 14, Ambient = RGB(100, 105, 115), Outdoor = RGB(120, 128, 140),
		AtmoDensity = 0.42, AtmoColor = RGB(170, 180, 195), Saturation = 0, Tint = RGB(225, 232, 245), Rain = 260, Dust = 0 },
	Storm = { Brightness = 1.1, ClockTime = 16.5, Ambient = RGB(70, 75, 90), Outdoor = RGB(90, 95, 115),
		AtmoDensity = 0.55, AtmoColor = RGB(120, 125, 145), Saturation = -0.1, Tint = RGB(205, 210, 235), Rain = 520, Dust = 0 },
	Moon = { Brightness = 1.2, ClockTime = 0, Ambient = RGB(70, 55, 110), Outdoor = RGB(110, 90, 170),
		AtmoDensity = 0.3, AtmoColor = RGB(120, 100, 180), Saturation = 0.1, Tint = RGB(225, 210, 255), Rain = 0, Dust = 14 },
}

local current: string? = nil
local rainPart: Part
local rain: ParticleEmitter
local dust: ParticleEmitter
local chip: TextLabel
local nextBolt = 0

local function tween(inst: Instance?, props: { [string]: any })
	if inst then
		TweenService:Create(inst, TweenInfo.new(3, Enum.EasingStyle.Sine), props):Play()
	end
end

local function apply(id: string)
	local look = LOOKS[id] or LOOKS.Sunny
	current = id
	tween(Lighting, { Brightness = look.Brightness, ClockTime = look.ClockTime, Ambient = look.Ambient, OutdoorAmbient = look.Outdoor })
	tween(Lighting:FindFirstChildOfClass("Atmosphere"), { Density = look.AtmoDensity, Color = look.AtmoColor })
	tween(Lighting:FindFirstChild("PescaColor"), { Saturation = look.Saturation, TintColor = look.Tint })
	rain.Rate = look.Rain
	dust.Rate = look.Dust
end

-- Rayo: destello blanco, la luz se dispara un instante y truena (con un poco de retraso, como de verdad).
local function lightning()
	UIKit.flash(RGB(235, 240, 255), 0.55)
	-- ExposureCompensation (no Brightness): el cambio de clima está interpolando Brightness y lo pisaría
	local base = Lighting.ExposureCompensation
	Lighting.ExposureCompensation = base + 1.5
	task.delay(0.12, function()
		Lighting.ExposureCompensation = base
	end)
	task.delay(math.random() * 0.8 + 0.3, function()
		UIKit.playSound("Boom", 0.55)
	end)
end

local function updateChip()
	local id = Workspace:GetAttribute("Weather")
	local state = Weather.States[id or "Sunny"] or Weather.States.Sunny
	local endsAt = Workspace:GetAttribute("WeatherEnds")
	local left = if type(endsAt) == "number" then math.max(0, endsAt - Workspace:GetServerTimeNow()) else 0
	local mutation = state.Mutation and Weather.Mutations[state.Mutation]
	chip.Text = ("%s %s%s · %d:%02d"):format(state.Emoji, state.Name,
		if mutation then (" · %s ×%d"):format(mutation.Emoji, mutation.Multiplier) else "", math.floor(left / 60), math.floor(left % 60))
	chip.TextColor3 = if mutation then mutation.Color else T.Text
end

function WeatherController.Init()
	-- lluvia y polvo de luna: una pieza invisible que sigue a la cámara (solo en este cliente)
	rainPart = UIKit.new("Part", { Name = "PescaRain", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		Transparency = 1, Size = Vector3.new(90, 1, 90), Parent = Workspace })
	rain = UIKit.new("ParticleEmitter", { Name = "Rain", Rate = 0, EmissionDirection = Enum.NormalId.Bottom, Speed = NumberRange.new(70, 90),
		Lifetime = NumberRange.new(0.6, 0.9), Size = NumberSequence.new(0.12), SpreadAngle = Vector2.new(4, 4), LightEmission = 0.2,
		Color = ColorSequence.new(RGB(200, 220, 255)), Transparency = NumberSequence.new(0.35), Parent = rainPart })
	dust = UIKit.new("ParticleEmitter", { Name = "MoonDust", Rate = 0, EmissionDirection = Enum.NormalId.Bottom, Speed = NumberRange.new(2, 5),
		Lifetime = NumberRange.new(4, 6), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) }),
		SpreadAngle = Vector2.new(30, 30), LightEmission = 1, Color = ColorSequence.new(RGB(210, 170, 255), RGB(150, 110, 255)), Parent = rainPart })

	local gui = UIKit.new("ScreenGui", { Name = "PescaWeather", ResetOnSpawn = false, DisplayOrder = 4,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	local frame = UIKit.new("Frame", { Name = "WeatherChip", Position = UDim2.fromOffset(14, 58), Size = UDim2.fromOffset(300, 34),
		BackgroundColor3 = T.PanelDark, BackgroundTransparency = 0.15, Parent = gui })
	UIKit.corner(frame, 17)
	UIKit.responsive(frame)
	chip = UIKit.label({ Text = "☀️ Soleado", Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), Font = T.FontTitle,
		Parent = frame }, { Stroke = 2, MaxSize = 20 })

	RunService.Heartbeat:Connect(function()
		local camera = Workspace.CurrentCamera
		local diving = DiveScene.Active()
		if camera then
			rainPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 35, 0))
		end
		rain.Enabled = not diving
		dust.Enabled = not diving
		if current == "Storm" and not diving and os.clock() >= nextBolt then
			nextBolt = os.clock() + math.random(6, 14)
			lightning()
		end
	end)
	local function onWeather()
		local id = Workspace:GetAttribute("Weather")
		if type(id) == "string" and id ~= current then
			apply(id)
			updateChip()
			UIKit.pop(frame, 1.2)
		end
	end
	Workspace:GetAttributeChangedSignal("Weather"):Connect(onWeather)
	onWeather()
	task.spawn(function()
		while true do
			updateChip()
			task.wait(1)
		end
	end)
end

return WeatherController
