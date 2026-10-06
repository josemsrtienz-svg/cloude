--[[
	PescaDeMemes • Main (Script)
	ServerScriptService > PescaServer > Main

	Punto de entrada del servidor. Solo arranca los sistemas en orden; la lógica vive en Systems/.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Root = ReplicatedStorage:WaitForChild("PescaDeMemes")
local Remotes = require(Root.Shared.Remotes)
Remotes.Setup()

local Systems = script.Parent:WaitForChild("Systems")

-- 1) Mundo primero, para que los jugadores aparezcan en su parcela
local ok, err = pcall(function()
	require(Systems.WorldBuilder).Build()
end)
if not ok then
	warn("[PescaDeMemes] Error construyendo el mapa: " .. tostring(err))
end

-- 2) Sistemas (el orden importa: datos → equipo → pesca → parcelas → economía)
local order = { "PlayerData", "GearService", "FishingService", "PlotService", "EconomyService" }
for _, name in ipairs(order) do
	local okInit, errInit = pcall(function()
		require(Systems[name]).Init()
	end)
	if not okInit then
		warn(("[PescaDeMemes] Error iniciando %s: %s"):format(name, tostring(errInit)))
	end
end

print(("[PescaDeMemes] Servidor listo · %d sistemas"):format(#order))
