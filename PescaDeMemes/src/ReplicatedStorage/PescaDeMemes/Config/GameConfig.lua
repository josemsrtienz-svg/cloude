--[[
	PescaDeMemes • GameConfig (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Config > GameConfig

	Reglas del juego en un solo sitio. Todos los números son VALORES INICIALES DE BALANCE:
	se ajustan después de probar el prototipo con jugadores reales.
	El cliente puede leer este módulo, pero el servidor es el único que decide.
]]

local GameConfig = {}

GameConfig.GameName = "PESCA DE MEMES"
GameConfig.Version = "P0 0.1"

-- ===== Moneda =====
GameConfig.CurrencyName = "MemeCoin"
GameConfig.CurrencyEmoji = "🪙"

-- ===== Niveles =====
function GameConfig.XPForLevel(level: number): number
	return 60 + (level - 1) * 40
end

-- ===== Mochila y parcela =====
GameConfig.MaxBackpack = 30 -- capturas que no están en un pedestal de tu parcela
GameConfig.PlotSlots = 8 -- pedestales por parcela
GameConfig.PlotIncomeRate = 0.08 -- fracción del valor de cada meme expuesto, por minuto
GameConfig.OfflineIncomeMultiplier = 0.5 -- la parcela rinde la mitad mientras no estás
GameConfig.OfflineCapHours = 8

-- ===== Parcelas (una por jugador) alrededor de la charca. Debe coincidir con WorldBuilder =====
-- Pon el máximo de jugadores del servidor en 8 (Game Settings → Places) para que nadie se quede sin parcela.
GameConfig.Plots = {
	Count = 8,
	Radius = 135, -- distancia del centro de la charca al centro de cada parcela
	Size = 40,
	-- ángulo (grados) de cada parcela alrededor de la charca; 0 = hacia el spawn
	Angles = { 40, -40, 75, -75, 110, -110, 145, -145 },
	PierEndRadius = 68, -- el muelle privado llega hasta aquí (dentro del agua)
	GoHomeCooldown = 3,
}

-- CFrame del centro de la parcela i, mirando hacia la charca (el frente local es -Z).
function GameConfig.PlotCFrame(index: number): CFrame
	local plots = GameConfig.Plots
	local center = GameConfig.Pond.Center
	local angle = math.rad(plots.Angles[index])
	local pos = center + Vector3.new(math.sin(angle) * plots.Radius, 0, math.cos(angle) * plots.Radius)
	return CFrame.lookAt(pos, Vector3.new(center.X, 0, center.Z))
end

-- ===== Charca (zona 1). Debe coincidir con WorldBuilder =====
GameConfig.Pond = {
	Center = Vector3.new(0, 0, -100),
	WaterRadius = 78, -- radio del agua (para colocar el corcho)
	FishingRadius = 100, -- distancia máxima del jugador al centro para poder pescar
	SurfaceY = 0,
}

-- ===== Pesca =====
GameConfig.Fishing = {
	CastCooldown = 0.8,
	CastMinDistance = 10, -- studs
	CastMaxDistance = 42,
	PerfectPower = { Min = 0.82, Max = 0.95 }, -- zona "PERFECTO" de la barra de fuerza
	BiteDelay = { Min = 2, Max = 7 },
	HookWindow = 0.6, -- segundos que ve el jugador para tocar tras el "!"
	HookServerGrace = 0.9, -- margen extra del servidor por la latencia
	StartProgress = 0.25,
	DrainFactor = 0.7, -- el progreso baja a este % de la velocidad de llenado
	RedZoneStart = 0.94, -- a partir de aquí la barra está en rojo (demasiada tensión)
	BaseGreenWidth = 0.26,
	BaseFillRate = 0.3, -- progreso por segundo con un común y la caña básica
	FightTimeout = 90,
	SessionTimeout = 30, -- un lanzamiento sin picada se cancela solo
	TugCount = 3, -- tirones fuertes cuando el meme pesa más que la capacidad
	TugThresholds = { 0.4, 0.65, 0.88 }, -- progreso en el que llega cada tirón
	TugWarning = 0.7, -- segundos de aviso antes de que se resuelva el tirón
	TugGreenBonus = 1.5,
	TugGreenMax = 0.95,
	MaxOverload = 5, -- más de 5× la capacidad = el sedal se rompe en la picada
	MinSurvival = 0.001,
	GoldenChance = 0.01,
	GoldenMultiplier = 3,
}

-- ===== Datos iniciales del jugador (Version = versión del schema) =====
GameConfig.DataVersion = 2
GameConfig.StartingData = {
	Version = GameConfig.DataVersion,
	MemeCoin = 50,
	Level = 1,
	XP = 0,
	-- [catchId] = { Id, MemeId, Weight, Golden, Impossible, Value, Time }
	Catches = {},
	-- pedestales de la parcela: catchId o ""
	Plot = { "", "", "", "", "", "", "", "" },
	PlotBank = 0, -- monedas acumuladas en el cobrador de la parcela
	Rods = { Palo = true },
	EquippedRod = "Palo",
	Items = { SedalReforzado = 0 },
	-- [memeId] = { Count, Heaviest }
	Discovered = {},
	LastSeen = 0,
	Stats = { TotalCatches = 0, Impossible = 0, Heaviest = 0 },
}

return GameConfig
