--[[
	PescaDeMemes • GameConfig (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Config > GameConfig

	Reglas del juego en un solo sitio. Todos los números son VALORES INICIALES DE BALANCE:
	se ajustan después de probar el prototipo con jugadores reales.
	El cliente puede leer este módulo, pero el servidor es el único que decide.
]]

local GameConfig = {}

GameConfig.GameName = "PESCA DE MEMES"
GameConfig.Version = "P0 0.6"

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
	HalfWidth = 40, -- el agua va de x = -40 a x = 40 (coincide con las casillas de 10 del suelo)
	MinZ = -180,
	MaxZ = 180,
	SurfaceY = -1,
}

-- Pon el máximo de jugadores del servidor en 8 (Game Settings → Places) para que nadie se quede sin parcela.
GameConfig.Plots = {
	Count = 8,
	Size = 44,
	CenterX = 78, -- distancia del centro del río al centro de cada parcela
	Z = { 120, 40, -40, -120 }, -- filas (las parcelas impares a la derecha, las pares a la izquierda)
	DockEndX = 26, -- el pasillo del muelle privado llega hasta |x| = 26; luego la plataforma de pesca (7 studs)
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
-- Flujo v0.4 (INMERSIÓN, como en los juegos de pescar huevos):
--   mantener click con la caña en la mano → barra de fuerza → soltar = lanzar
--   → la cámara se mete bajo el agua: el anzuelo baja solo y tú lo GUÍAS (A/D, ratón o dedo)
--   → tocar un meme lo engancha (hasta los anzuelos de tu caña). Si pesa más que tu caña, PELEA.
--   → al llenar los anzuelos, tocar el fondo o pulsar SUBIR, el sedal sube y te llevas lo enganchado.
-- Profundidad en METROS. En la escena submarina 1 m = Dive.StudsPerMeter studs.
GameConfig.Fishing = {
	CastCooldown = 0.8,
	PerfectPower = { Min = 0.82, Max = 0.95 }, -- zona "PERFECTO" de la barra de fuerza (+suerte)
	-- pelea (igual que antes: barra de tensión y tirones si pesa más que tu caña)
	StartProgress = 0.25,
	DrainFactor = 0.7, -- el progreso baja a este % de la velocidad de llenado
	RedZoneStart = 0.94, -- a partir de aquí la barra está en rojo (demasiada tensión)
	BaseGreenWidth = 0.26,
	BaseFillRate = 0.3, -- progreso por segundo con un común y la caña básica
	FightTimeout = 90,
	TugCount = 3, -- tirones fuertes cuando el meme pesa más que la capacidad
	TugThresholds = { 0.4, 0.65, 0.88 }, -- progreso en el que llega cada tirón
	TugWarning = 0.7, -- segundos de aviso antes de que se resuelva el tirón
	TugGreenBonus = 1.5,
	TugGreenMax = 0.95,
	MaxOverload = 5, -- más de 5× la capacidad = no se puede ni enganchar (etiqueta roja)
	MinSurvival = 0.001,
	GoldenChance = 0.01,
	GoldenMultiplier = 3,
}

GameConfig.Dive = {
	IntroTime = 1.4, -- s desde el lanzamiento hasta que el anzuelo empieza a bajar (vuelo + chapuzón)
	StartDepth = 2, -- m: los memes empiezan a esta profundidad
	MemesPerSecond = 1.6, -- memes por segundo de bajada (así una inmersión honda no se queda vacía)
	LaneHalfWidth = 9, -- m: el anzuelo y los memes se mueven entre -9 y 9
	GrabRadius = 1.7, -- m: distancia a la que el anzuelo engancha un meme
	GrabSlack = 2.5, -- m de margen del servidor al validar la x (latencia + nado del meme)
	SteerSpeed = 12, -- m/s máximos del anzuelo hacia los lados (cliente y servidor)
	GrabEarly = 0.5, -- s de margen por si el cliente va un poco por delante
	GrabLate = 2, -- s de margen por la latencia (después ya lo has pasado)
	BottomWait = 1.2, -- s en el fondo antes de subir solo
	Timeout = 150, -- s máximos de una inmersión (contando peleas)
	DepthLuck = 1, -- suerte extra según la profundidad: ×(1 + DepthLuck·m/MaxWorldDepth) — ×1.25 a 150 m, ×2 a 600 m
	MaxWorldDepth = 600, -- m: el fondo del río por ahora (se ampliará con nuevas capas en actualizaciones)
	MaxMemes = 40, -- tope de memes por inmersión (rendimiento)
	StudsPerMeter = 2,
}

-- Capas de profundidad: cada una tiene nombre y su color de agua (de arriba a abajo de la capa).
-- Cuanto más hondo, más oscuro; la última brilla (bioluminiscencia). Para un EVENTO (p. ej. "modo tóxico")
-- basta con cambiar los colores de una capa o añadir otra más abajo.
local RGB = Color3.fromRGB
GameConfig.DepthLayers = {
	{ From = 0, Name = "Charca del Noob", Top = RGB(80, 195, 235), Bottom = RGB(45, 150, 210) },
	{ From = 50, Name = "Arrecife Meme", Top = RGB(45, 150, 210), Bottom = RGB(25, 95, 170) },
	{ From = 150, Name = "Abismo Brainrot", Top = RGB(25, 95, 170), Bottom = RGB(15, 45, 110) },
	{ From = 300, Name = "Fosa Abisal", Top = RGB(15, 45, 110), Bottom = RGB(5, 10, 35), Glow = RGB(120, 255, 220) },
}

-- Capa en la que está una profundidad (m) y cuánto se ha avanzado dentro de ella (0–1).
function GameConfig.LayerAt(depth: number): (any, number)
	local layers = GameConfig.DepthLayers
	for i = #layers, 1, -1 do
		local layer = layers[i]
		if depth >= layer.From then
			local nextFrom = if layers[i + 1] then layers[i + 1].From else GameConfig.Dive.MaxWorldDepth
			return layer, math.clamp((depth - layer.From) / math.max(1, nextFrom - layer.From), 0, 1)
		end
	end
	return layers[1], 0
end

-- ===== Modo prueba (SOLO en Roblox Studio) =====
-- Con Enabled = true, al darle a Play en Studio empiezas con dinero "infinito" para probar todas las cañas,
-- mochilas y objetos. Esa sesión NO SE GUARDA (no toca tus datos reales). En un servidor de verdad
-- (juego publicado) nunca se activa, aunque se te olvide ponerlo en false.
-- ⚠️ Antes de publicar: ponlo en false igualmente (está en la lista de la Fase 6).
GameConfig.DevMode = {
	Enabled = true,
	Money = 1e12,
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
	Boosts = {}, -- [boostId] = os.time() en que caduca (Config/Boosts)
	-- filtros (rarezas): CatchSkip = el anzuelo las ignora · AutoSell = se venden solas al subir
	Settings = { CatchSkip = {}, AutoSell = {} },
	FreeRound = 0, -- última ronda del tablón de la Gran Tienda cuyo boost gratis ya recogió
	-- [memeId] = { Count, Heaviest }
	Discovered = {},
	LastSeen = 0,
	Stats = { TotalCatches = 0, Impossible = 0, Heaviest = 0 },
}

return GameConfig
