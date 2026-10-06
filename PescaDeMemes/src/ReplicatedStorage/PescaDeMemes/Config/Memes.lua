--[[
	PescaDeMemes • Memes (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Config > Memes

	Los memes que se pueden pescar. Para añadir uno:
	  1. Añade una entrada en Memes.List (Id único).
	  2. Elige una Personality de Shared/FishBehaviors (cómo pelea).
	  3. (Opcional) Pon su imagen en Config > Assets > MemeImages[Id].
	Todos son parodias originales: no se usan logos ni diseños protegidos.

	WeightMin/WeightMax = rango de peso en kg. El tamaño (S…Gigante) sale de dónde cae el peso
	dentro de ese rango.
	MinDepth (opcional) = metros mínimos a los que aparece en la inmersión: los memes difíciles viven
	en el fondo (capas de profundidad en vez de zonas separadas).

	Orden de rarezas (decisión del equipo): Común → Poco común → Raro → Épico → MÍTICO → LEGENDARIO
	→ SECRETO → DIOS. "DIOS" está reservado para eventos: Odds = 0, no sale nunca en la tirada normal.
]]

local Memes = {}

local RGB = Color3.fromRGB

-- Odds = peso relativo para la tirada · BaseValue = MemeCoins de un ejemplar mediano
-- Difficulty divide la velocidad de llenado · Pull = cuánto empuja el meme tu indicador
Memes.Rarities = {
	COMMON = { Name = "COMÚN", Color = RGB(175, 178, 190), Order = 1, Odds = 60, BaseValue = 10, XP = 10, Difficulty = 1.0, Pull = 0.6 },
	UNCOMMON = { Name = "POCO COMÚN", Color = RGB(90, 210, 110), Order = 2, Odds = 25, BaseValue = 40, XP = 20, Difficulty = 1.2, Pull = 0.8 },
	RARE = { Name = "RARO", Color = RGB(70, 160, 255), Order = 3, Odds = 10, BaseValue = 150, XP = 45, Difficulty = 1.45, Pull = 1.0 },
	EPIC = { Name = "ÉPICO", Color = RGB(185, 90, 255), Order = 4, Odds = 4, BaseValue = 600, XP = 100, Difficulty = 1.8, Pull = 1.25 },
	MYTHIC = { Name = "MÍTICO", Color = RGB(255, 60, 120), Order = 5, Odds = 1.5, BaseValue = 1500, XP = 180, Difficulty = 2.1, Pull = 1.4 },
	LEGENDARY = { Name = "LEGENDARIO", Color = RGB(255, 190, 40), Order = 6, Odds = 0.6, BaseValue = 3000, XP = 300, Difficulty = 2.3, Pull = 1.5 },
	SECRET = { Name = "SECRETO", Color = RGB(80, 240, 255), Order = 7, Odds = 0.02, BaseValue = 25000, XP = 1200, Difficulty = 2.8, Pull = 1.8 },
	-- reservado para eventos: no sale en la tirada normal (Odds = 0)
	GOD = { Name = "DIOS", Color = RGB(255, 245, 200), Order = 8, Odds = 0, BaseValue = 250000, XP = 5000, Difficulty = 3.2, Pull = 2.1 },
}

Memes.RarityOrder = { "COMMON", "UNCOMMON", "RARE", "EPIC", "MYTHIC", "LEGENDARY", "SECRET", "GOD" }

-- Nombre visible de cada personalidad (para el bestiario y la pelea).
Memes.PersonalityNames = {
	Calm = "Tranquilo",
	Jerky = "Tirones bruscos",
	Market = "Sube y se desploma",
	Freeze = "Quieto… y salta",
	Spin = "No para de dar vueltas",
	Rhythm = "Sigue la melodía",
	Heavy = "Pesado como una piedra",
	Brute = "Fuerza bruta",
}

Memes.List = {
	{ Id = "NoobFeliz", Name = "Noob Feliz", Rarity = "COMMON", Emoji = "🙂", Zone = 1,
		Personality = "Calm", WeightMin = 1, WeightMax = 6,
		Description = "El primer meme que pesca todo el mundo. Cero peleas." },
	{ Id = "PerroBonk", Name = "Perro Bonk", Rarity = "COMMON", Emoji = "🐕", Zone = 1,
		Personality = "Jerky", WeightMin = 2, WeightMax = 8,
		Description = "Da tirones como si quisiera mandarte a la cárcel de los cuernos." },
	{ Id = "Stonks", Name = "Señor Stonks", Rarity = "COMMON", Emoji = "📈", Zone = 1,
		Personality = "Market", WeightMin = 1, WeightMax = 7,
		Description = "Sube, sube, sube… y de repente se desploma." },
	{ Id = "Sospechoso", Name = "El Sospechoso", Rarity = "UNCOMMON", Emoji = "🤨", Zone = 1,
		Personality = "Freeze", WeightMin = 5, WeightMax = 20,
		Description = "Se queda mirándote muy quieto. Demasiado quieto." },
	{ Id = "PatoInfinito", Name = "Pato Infinito", Rarity = "UNCOMMON", Emoji = "🦆", Zone = 1,
		Personality = "Spin", WeightMin = 5, WeightMax = 25,
		Description = "Da vueltas sin fin. Nadie sabe dónde empieza ni dónde acaba." },
	{ Id = "GatoPianista", Name = "Gato Pianista", Rarity = "RARE", Emoji = "🎹", Zone = 1,
		Personality = "Rhythm", WeightMin = 20, WeightMax = 60,
		Description = "Pelea al ritmo de su melodía. Si la sigues, es tuyo." },
	{ Id = "Moai", Name = "Moai", Rarity = "EPIC", Emoji = "🗿", Zone = 1,
		Personality = "Heavy", WeightMin = 90, WeightMax = 250,
		Description = "Casi no se mueve. Tampoco se deja sacar." },
	{ Id = "GigaChad", Name = "GigaChad", Rarity = "LEGENDARY", Emoji = "💪", Zone = 1,
		Personality = "Brute", WeightMin = 200, WeightMax = 900, MinDepth = 20,
		Description = "Zona verde enorme, pero tira con la fuerza de mil gimnasios." },
	-- ===== MÍTICOS (desde 12 m) =====
	{ Id = "GatoPop", Name = "Gato Pop", Rarity = "MYTHIC", Emoji = "😮", Zone = 1,
		Personality = "Jerky", WeightMin = 40, WeightMax = 180, MinDepth = 12,
		Description = "Abre la boca y suelta un ¡POP! que se oye en todo el río." },
	{ Id = "PlatanoBailarin", Name = "Plátano Bailarín", Rarity = "MYTHIC", Emoji = "🍌", Zone = 1,
		Personality = "Rhythm", WeightMin = 30, WeightMax = 150, MinDepth = 12,
		Description = "Nunca deja de bailar. Ni siquiera enganchado al anzuelo." },
	{ Id = "HamsterDramatico", Name = "Hámster Dramático", Rarity = "MYTHIC", Emoji = "🐹", Zone = 1,
		Personality = "Freeze", WeightMin = 25, WeightMax = 120, MinDepth = 12,
		Description = "Se gira despacio, te mira… y suena música de suspense." },
	-- ===== SECRETOS (desde 30 m, con efectos) =====
	{ Id = "TiburonZapatillero", Name = "Tiburón Zapatillero", Rarity = "SECRET", Emoji = "🦈", Zone = 1,
		Personality = "Spin", WeightMin = 300, WeightMax = 1500, MinDepth = 30,
		Description = "Un tiburón con zapatillas de deporte. Nada a lo loco y deja una estela azul." },
	{ Id = "CapibaraZen", Name = "Capibara Zen", Rarity = "SECRET", Emoji = "🍊", Zone = 1,
		Personality = "Calm", WeightMin = 200, WeightMax = 1000, MinDepth = 30,
		Description = "Medita con una naranja en la cabeza. Su aura dorada calma el río entero." },
	{ Id = "CocodriloAviador", Name = "Cocodrilo Aviador", Rarity = "SECRET", Emoji = "🐊", Zone = 1,
		Personality = "Brute", WeightMin = 400, WeightMax = 2000, MinDepth = 40,
		Description = "Medio cocodrilo, medio avioneta. Nadie sabe cómo acabó en el río." },
}

local byId: { [string]: any } = {}
for i, meme in ipairs(Memes.List) do
	meme.Index = i
	byId[meme.Id] = meme
end

function Memes.Get(id: any): any?
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

function Memes.GetRarity(id: string): any
	local meme = byId[id]
	return Memes.Rarities[meme and meme.Rarity or "COMMON"]
end

-- Pools precalculados por zona y rareza: [zone][rarity] = { meme, ... }
local pools: { [number]: { [string]: { any } } } = {}
for _, meme in ipairs(Memes.List) do
	pools[meme.Zone] = pools[meme.Zone] or {}
	pools[meme.Zone][meme.Rarity] = pools[meme.Zone][meme.Rarity] or {}
	table.insert(pools[meme.Zone][meme.Rarity], meme)
end
local EMPTY = table.freeze({})

-- No modifiques la tabla devuelta (es compartida).
function Memes.InZone(zone: number, rarity: string): { any }
	local byRarity = pools[zone]
	return byRarity and byRarity[rarity] or EMPTY
end

return Memes
