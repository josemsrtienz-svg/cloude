--[[
	V2MMW • Main (Script)
	ServerScriptService > V2MMWServer > Main

	Punto de entrada del servidor. Solo arranca los sistemas en orden; la lógica vive en Systems/.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("V2MMW")
local Remotes = require(Shared.Shared.Remotes)
Remotes.Setup()

local Systems = script.Parent:WaitForChild("Systems")
local WorldBuilder = require(Systems.WorldBuilder)

-- 1) Mundo primero, para que los jugadores aparezcan en el lobby
WorldBuilder.Build()

-- 2) Sistemas (el orden importa: datos → economía → resto)
local order = {
	"Teleport",
	"PlayerData",
	"MemeCoin",
	"Inventory",
	"Shop",
	"Trading",
	"Matchmaking",
	"MatchService",
	"Abilities",
}
for _, name in ipairs(order) do
	local ok, err = pcall(function()
		require(Systems[name]).Init()
	end)
	if not ok then
		warn(("[V2MMW] Error iniciando %s: %s"):format(name, tostring(err)))
	end
end

print(("[V2MMW] Servidor listo · %d sistemas"):format(#order))
