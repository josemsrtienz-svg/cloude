--[[
	PescaDeMemes • WeatherService (ModuleScript)
	ServerScriptService > PescaServer > Systems > WeatherService

	Publica el clima actual (Config/Weather) para que el cliente pinte el cielo y el HUD:
	  Workspace "Weather" (id del estado) y "WeatherEnds" (segundos de servidor en que cambia).
	Avisa a todos cuando cambia a algo con mutaciones. FishingService lo lee con WeatherService.Current() (así respeta el clima forzado).
	Modo prueba (Studio): GameConfig.DevMode.Weather fuerza un clima ("Rain", "Storm", "Moon"…) para probarlo.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local GameConfig = require(Root.Config.GameConfig)
local Weather = require(Root.Config.Weather)

local PlayerData = require(script.Parent.PlayerData)

local WeatherService = {}

local FORCED = if RunService:IsStudio() and GameConfig.DevMode.Enabled then Weather.States[GameConfig.DevMode.Weather or ""] else nil

-- Clima que manda ahora mismo (el forzado de Studio, o el de la ronda).
function WeatherService.Current(): (any, number)
	local state, _, endsAt = Weather.At(os.time())
	return FORCED or state, endsAt
end

function WeatherService.Init()
	local last: string? = nil
	task.spawn(function()
		while true do
			local state, endsAt = WeatherService.Current()
			Workspace:SetAttribute("Weather", state.Id)
			Workspace:SetAttribute("WeatherEnds", endsAt)
			if state.Id ~= last then
				if last ~= nil and state.Mutation then
					local mutation = Weather.Mutations[state.Mutation]
					for _, player in ipairs(Players:GetPlayers()) do
						PlayerData.Notify(player, ("%s ¡%s! Los memes pueden salir %s %s (×%d)"):format(state.Emoji, state.Name,
							mutation.Emoji, mutation.Name, mutation.Multiplier), "Info")
					end
				end
				last = state.Id
			end
			task.wait(1)
		end
	end)
end

return WeatherService
