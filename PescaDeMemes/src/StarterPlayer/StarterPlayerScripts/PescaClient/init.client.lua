--[[
	PescaDeMemes • Cliente (LocalScript)
	StarterPlayerScripts > PescaClient

	Arranca los controladores en orden. La lógica vive en Controllers/.
]]

local Controllers = script:WaitForChild("Controllers")

local order = { "State", "Audio", "HUD", "WeatherController", "CatchCard", "FishingController", "Panels", "PlotController", "Ambience", "Tutorial" }
for _, name in ipairs(order) do
	local ok, err = pcall(function()
		require(Controllers[name]).Init()
	end)
	if not ok then
		warn(("[PescaDeMemes] Error iniciando %s: %s"):format(name, tostring(err)))
	end
end
