--[[
	PescaDeMemes • GameConfig (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Config > GameConfig

	Reglas del juego en un solo sitio. Todos los números son VALORES INICIALES DE BALANCE:
	se ajustan después de probar el prototipo con jugadores reales.
	El cliente puede leer este módulo, pero el servidor es el único que decide.
]]

local GameConfig = {}

GameConfig.GameName = "PESCA DE MEMES"
GameConfig.Version = "P0 0.3"

-- ===== Moneda =====
GameConfig.CurrencyName = "MemeCoin"
GameConfig.CurrencyEmoji = "🪙"

-- ===== Niveles =====
function GameConfig.XPForLevel(level: number): number
	return 60 + (level - 1) * 40
end

-- ===== Caña (herramienta del slot 1) =====
GameConfig.RodToolName = "Caña"

-- ===== Parcela y mochila-acuario =====
GameConfig.PlotSlots = 8 -- huecos en el césped de la parcela
GameConfig.PlotIncomeRate = 0.08 -- fracción del valor de cada meme expuesto, por minuto
GameConfig.OfflineIncomeMultiplier = 0.5 -- la parcela rinde la mitad mientras no estás
GameConfig.OfflineCapHours = 8
GameConfig.DepositCheckInterval = 0.5 -- cada cuánto se mira si estás dentro de tu parcela

-- ===== Mapa: río en el centro, 4 parcelas a cada lado (estilo "en fila"). Debe coincidir con WorldBuilder =====
GameConfig.River = {
	HalfWidth = 20, -- el agua va de x = -20 a x = 20 (coincide con las casillas de 10 del suelo)
	MinZ = -140,
	MaxZ = 140,
	SurfaceY = -1,
}

-- Pon el máximo de jugadores del servidor en 8 (Game Settings → Places) para que nadie se quede sin parcela.
GameConfig.Plots = {
	Count = 8,
	Size = 44,
	CenterX = 58, -- distancia del centro del río al centro de cada parcela
	Z = { 96, 32, -32, -96 }, -- filas (las parcelas impares a la derecha, las pares a la izquierda)
	DockEndX = 12, -- el pasillo del muelle privado llega hasta |x| = 12; luego la plataforma de pesca (7 studs)
	FishingRange = 12, -- distancia máxima al final de TU muelle para poder pescar
	GoHomeCooldown = 3,
}

-- CFrame del centro de la parcela i, mirando hacia el río (el frente local es -Z).
function GameConfig.PlotCFrame(index: number): CFrame
	local plots = GameConfig.Plots
	local side = if index % 2 == 1 then 1 else -1
	local z = plots.Z[math.floor((index - 1) / 2) + 1]
	local pos = Vector3.new(side * plots.CenterX, 0, z)
	return CFrame.lookAt(pos, Vector3.new(0, 0, z))
end

-- Punto del final del muelle privado de la parcela i (desde donde se pesca).
function GameConfig.DockSpot(index: number): Vector3
	local plots = GameConfig.Plots
	local cf = GameConfig.PlotCFrame(index)
	return (cf * CFrame.new(0, 0, -(plots.CenterX - plots.DockEndX) - 3.5)).Position
end

function GameConfig.InRiver(pos: Vector3, margin: number?): boolean
	local r = GameConfig.River
	local m = margin or 0
	return math.abs(pos.X) <= r.HalfWidth - m and pos.Z >= r.MinZ + m and pos.Z <= r.MaxZ - m
end

-- ===== Pesca =====
GameConfig.Fishing = {
	CastCooldown = 0.8,
	CastMinDistance = 6, -- studs
	CastMaxDistance = 26,
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
GameConfig.DataVersion = 3
GameConfig.StartingData = {
	Version = GameConfig.DataVersion,
	MemeCoin = 50,
	Level = 1,
	XP = 0,
	-- [catchId] = { Id, MemeId, Weight, Size, Golden, Impossible, Value, Time }
	-- Una captura está en la PARCELA si su id está en Plot; si no, va en la mochila-acuario.
	Catches = {},
	-- huecos de la parcela: catchId o ""
	Plot = { "", "", "", "", "", "", "", "" },
	AquariumTier = 1, -- mochila-acuario equipada (Config/Gear)
	BrokenRods = {}, -- [rodId] = true si está rota (se repara en la tienda)
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
