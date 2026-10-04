--[[
	MemeGame • GameConfig (ModuleScript)
	ReplicatedStorage > MemeGame > Config > GameConfig

	Reglas del juego en un solo sitio: moneda, niveles, slots, cabinas, dificultades, mapas y partidas.
	El cliente puede leer este módulo, pero el servidor es el único que decide.
]]

local GameConfig = {}

GameConfig.GameName = "MEME WARRIORS"
GameConfig.Version = "MVP 0.1"

-- ===== Moneda =====
GameConfig.CurrencyName = "MemeCoin"
GameConfig.CurrencyEmoji = "🪙"

-- ===== Equipamiento =====
GameConfig.MaxEquipped = 3 -- máximo absoluto de memes equipados. Nunca 4.

-- ===== Niveles =====
function GameConfig.XPForLevel(level: number): number
	return 100 + (level - 1) * 50
end

-- ===== Datos iniciales del jugador (Version = versión del schema) =====
GameConfig.DataVersion = 1
GameConfig.StartingData = {
	Version = 1,
	MemeCoin = 500,
	Level = 1,
	XP = 0,
	-- [MemeId] = cantidad
	OwnedMemes = { NoobFeliz = 1, Sospechoso = 1, PerroBonk = 1, Stonks = 1 },
	-- 3 slots fijos; "" = vacío
	EquippedMemes = { "", "", "" },
	Settings = {
		Music = true,
		SFX = true,
		Volume = 0.8,
		Effects = true,
		Quality = "High", -- "Low" | "Medium" | "High"
		Sensitivity = 1,
	},
	Stats = {
		MatchesPlayed = 0,
		MatchesWon = 0,
		MemesBought = 0,
		TradesCompleted = 0,
		MemeCoinEarned = 0,
	},
}

-- ===== Mundo =====
-- El lobby es una isla flotante, así no choca con nada que ya tengas en el Workspace.
GameConfig.World = {
	LobbyOrigin = Vector3.new(0, 400, 0),
	IslandDiameter = 280,
}

-- ===== Cabinas de partida =====
GameConfig.Stations = {
	{ Id = "Cabina1", Name = "CABINA 1", Capacity = 1, Color = Color3.fromRGB(70, 195, 255) },
	{ Id = "Cabina2", Name = "CABINA 2", Capacity = 2, Color = Color3.fromRGB(80, 215, 110) },
	{ Id = "Cabina3", Name = "CABINA 3", Capacity = 3, Color = Color3.fromRGB(255, 170, 40) },
	{ Id = "Cabina4", Name = "CABINA 4", Capacity = 4, Color = Color3.fromRGB(255, 70, 140) },
}
GameConfig.CountdownSeconds = 10

-- ===== Dificultades =====
-- RewardMultiplier multiplica las recompensas de la partida.
GameConfig.Difficulties = {
	{ Id = "Easy", Name = "EASY", Color = Color3.fromRGB(80, 215, 110), RewardMultiplier = 1 },
	{ Id = "Normal", Name = "NORMAL", Color = Color3.fromRGB(70, 160, 255), RewardMultiplier = 1.5 },
	{ Id = "Hard", Name = "HARD", Color = Color3.fromRGB(255, 150, 40), RewardMultiplier = 2 },
	{ Id = "Extreme", Name = "EXTREME", Color = Color3.fromRGB(255, 50, 80), RewardMultiplier = 3 },
}

-- ===== Mapas =====
-- El sistema busca Workspace > Maps > <Id>. Si no existe, crea un PLACEHOLDER marcado.
-- Para usar tu mapa real: pon un Model/Folder llamado igual (ej. "Map1") dentro de Workspace > Maps,
-- con una carpeta "Spawns" (Parts o SpawnLocations) y, opcionalmente, una Part "Goal" (meta).
-- PlaceId ~= 0 → en el juego publicado se teletransporta a ese place (misma experiencia).
GameConfig.Maps = {
	{ Id = "Map1", Name = "MAPA 1", Description = "Pendiente de construir", PlaceId = 0,
		PlaceholderOffset = Vector3.new(700, 0, 0), Color = Color3.fromRGB(120, 200, 90) },
	{ Id = "Map2", Name = "MAPA 2", Description = "Pendiente de construir", PlaceId = 0,
		PlaceholderOffset = Vector3.new(1000, 0, 0), Color = Color3.fromRGB(230, 170, 70) },
	{ Id = "Map3", Name = "MAPA 3", Description = "Pendiente de construir", PlaceId = 0,
		PlaceholderOffset = Vector3.new(1300, 0, 0), Color = Color3.fromRGB(150, 110, 230) },
}

-- ===== Partidas =====
GameConfig.Match = {
	Duration = 120, -- segundos; al acabar el tiempo todos vuelven al lobby
	ReturnDelay = 5, -- segundos mostrando el resultado antes de volver
	WinReward = { MemeCoin = 150, XP = 60 },
	ParticipationReward = { MemeCoin = 40, XP = 25 },
}

-- ===== Tienda =====
GameConfig.ShopName = "MemeMarket"

-- ===== Trading =====
GameConfig.Trade = {
	MaxItemsPerSide = 6,
	InviteTimeout = 20,
}

-- ===== Helpers =====
local function index(list)
	local map = {}
	for i, item in ipairs(list) do
		item.Order = i
		map[item.Id] = item
	end
	return map
end
local stationsById = index(GameConfig.Stations)
local difficultiesById = index(GameConfig.Difficulties)
local mapsById = index(GameConfig.Maps)

function GameConfig.GetStation(id: string?)
	return id and stationsById[id] or nil
end
function GameConfig.GetDifficulty(id: string?)
	return id and difficultiesById[id] or nil
end
function GameConfig.GetMap(id: string?)
	return id and mapsById[id] or nil
end

return GameConfig
