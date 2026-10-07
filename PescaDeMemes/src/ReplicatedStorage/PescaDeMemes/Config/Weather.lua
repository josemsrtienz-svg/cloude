--[[
	PescaDeMemes • Weather (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Config > Weather

	CLIMA Y MUTACIONES (Fase 4 · Alpha, decidido por el equipo).
	  · Cada Period (8 min) cambia el clima. Es el mismo en todos los servidores (semilla = número de ronda),
	    así que "¡está lloviendo, ven a pescar!" vale para todo el mundo.
	  · Con lluvia, tormenta o luna llena, cada meme de la inmersión puede salir MUTADO:
	      💧 Mojado ×2 (lluvia) · ⚡ Eléctrico ×5 (tormenta) · 🌙 Lunar ×10 (luna llena)
	    La mutación multiplica su valor (y se suma al dorado ×3) y se ve en el modelo.
	  · El Cebo Lunar duplica la probabilidad de mutación (Config/Rods → Items).
	Lo usa el servidor (FishingService, WeatherService) y el cliente (cielo, lluvia, rayos, HUD).
]]

local Weather = {}

local RGB = Color3.fromRGB

Weather.Period = 8 * 60

-- Weight = probabilidad relativa de que toque · Mutation/Chance = mutación que puede salir y su probabilidad por meme
Weather.States = {
	Sunny = { Id = "Sunny", Name = "Soleado", Emoji = "☀️", Weight = 45 },
	Rain = { Id = "Rain", Name = "Lluvia", Emoji = "🌧️", Weight = 25, Mutation = "Wet", Chance = 0.15 },
	Storm = { Id = "Storm", Name = "Tormenta", Emoji = "⛈️", Weight = 18, Mutation = "Electric", Chance = 0.10 },
	Moon = { Id = "Moon", Name = "Luna llena", Emoji = "🌕", Weight = 12, Mutation = "Lunar", Chance = 0.06 },
}
Weather.Order = { "Sunny", "Rain", "Storm", "Moon" }

Weather.Mutations = {
	Wet = { Id = "Wet", Name = "MOJADO", Emoji = "💧", Multiplier = 2, Color = RGB(90, 190, 255) },
	Electric = { Id = "Electric", Name = "ELÉCTRICO", Emoji = "⚡", Multiplier = 5, Color = RGB(255, 230, 60) },
	Lunar = { Id = "Lunar", Name = "LUNAR", Emoji = "🌙", Multiplier = 10, Color = RGB(190, 130, 255) },
}

function Weather.GetMutation(id: any): any?
	if type(id) ~= "string" then
		return nil
	end
	return Weather.Mutations[id]
end

-- Multiplicador de valor de una mutación (1 si no hay).
function Weather.Multiplier(id: any): number
	local m = Weather.GetMutation(id)
	return if m then m.Multiplier else 1
end

-- Tirada "en bruto" de una ronda (determinista: misma semilla en todos los servidores).
local function rollRound(round: number): any
	local rng = Random.new(round * 2654435761 % 2147483647 + 17)
	local total = 0
	for _, id in ipairs(Weather.Order) do
		total += Weather.States[id].Weight
	end
	local roll = rng:NextNumber() * total
	for _, id in ipairs(Weather.Order) do
		roll -= Weather.States[id].Weight
		if roll <= 0 then
			return Weather.States[id]
		end
	end
	return Weather.States.Sunny
end

-- Clima de una ronda (determinista). Nunca repite el mismo clima dos rondas seguidas salvo el sol:
-- si la tirada coincide con la de la ronda anterior, esta ronda sale soleada.
function Weather.ForRound(round: number): any
	local state = rollRound(round)
	if state ~= Weather.States.Sunny and rollRound(round - 1) == state then
		return Weather.States.Sunny
	end
	return state
end

-- Clima ahora: (estado, ronda, segundos en que termina).
function Weather.At(now: number): (any, number, number)
	local round = math.floor(now / Weather.Period)
	return Weather.ForRound(round), round, (round + 1) * Weather.Period
end

-- Etiqueta corta para nombres ("💧 " o "").
function Weather.Tag(id: any): string
	local m = Weather.GetMutation(id)
	return if m then m.Emoji .. " " else ""
end

return Weather
