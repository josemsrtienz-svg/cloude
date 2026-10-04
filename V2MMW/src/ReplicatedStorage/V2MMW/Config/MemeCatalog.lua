--[[
	V2MMW • MemeCatalog (ModuleScript)
	ReplicatedStorage > V2MMW > Config > MemeCatalog

	Todos los memes coleccionables. Para añadir uno:
	  1. Añade una entrada aquí (Id único).
	  2. (Opcional) Pon su imagen en Config > Assets > MemeImages[Id] = "rbxassetid://ID".
	Todos los personajes son parodias originales: no se usan logos ni diseños protegidos.

	Value     = precio en MemeCoin (y valor orientativo para trading).
	InShop    = se vende en el MemeMarket.
	Ability   = habilidad que se activa desde la hotbar DURANTE una partida.
	            Type: "Speed" | "Jump" | "Shield" | "Dash"
]]

local MemeCatalog = {}

MemeCatalog.Rarities = {
	COMMON = { Name = "COMMON", Color = Color3.fromRGB(175, 178, 190), Order = 1 },
	UNCOMMON = { Name = "UNCOMMON", Color = Color3.fromRGB(90, 210, 110), Order = 2 },
	RARE = { Name = "RARE", Color = Color3.fromRGB(70, 160, 255), Order = 3 },
	EPIC = { Name = "EPIC", Color = Color3.fromRGB(185, 90, 255), Order = 4 },
	LEGENDARY = { Name = "LEGENDARY", Color = Color3.fromRGB(255, 190, 40), Order = 5 },
	MYTHIC = { Name = "MYTHIC", Color = Color3.fromRGB(255, 60, 120), Order = 6 },
}

MemeCatalog.List = {
	-- COMMON
	{ Id = "NoobFeliz", Name = "Noob Feliz", Rarity = "COMMON", Emoji = "🙂", Value = 100, InShop = true,
		Description = "Cara feliz, cero miedo. El original de siempre.",
		Ability = { Type = "Jump", Power = 1.4, Duration = 5, Cooldown = 12 } },
	{ Id = "Sospechoso", Name = "El Sospechoso", Rarity = "COMMON", Emoji = "🫘", Value = 150, InShop = true,
		Description = "Un frijol astronauta que se ve MUY sus.",
		Ability = { Type = "Speed", Power = 1.35, Duration = 5, Cooldown = 12 } },
	{ Id = "PerroBonk", Name = "Perro Bonk", Rarity = "COMMON", Emoji = "🐕", Value = 150, InShop = true,
		Description = "Much bonk. Very golpe. Wow.",
		Ability = { Type = "Dash", Power = 70, Duration = 0, Cooldown = 8 } },
	{ Id = "Stonks", Name = "Señor Stonks", Rarity = "COMMON", Emoji = "📈", Value = 200, InShop = true,
		Description = "Invirtió todo en memes. Le fue increíble.",
		Ability = { Type = "Speed", Power = 1.3, Duration = 6, Cooldown = 14 } },
	-- UNCOMMON
	{ Id = "CaraTroll", Name = "Cara Troll", Rarity = "UNCOMMON", Emoji = "😏", Value = 400, InShop = true,
		Description = "Problem? La sonrisa más irritante de internet.",
		Ability = { Type = "Jump", Power = 1.6, Duration = 5, Cooldown = 12 } },
	{ Id = "PatoInfinito", Name = "Pato Infinito", Rarity = "UNCOMMON", Emoji = "🦆", Value = 450, InShop = true,
		Description = "Cuack. Cuack. Cuack. Nunca se detiene.",
		Ability = { Type = "Dash", Power = 85, Duration = 0, Cooldown = 8 } },
	{ Id = "GatoPianista", Name = "Gato Pianista", Rarity = "UNCOMMON", Emoji = "🎹", Value = 500, InShop = true,
		Description = "Toca la melodía de tu derrota.",
		Ability = { Type = "Shield", Power = 1, Duration = 4, Cooldown = 18 } },
	-- RARE
	{ Id = "GatoArcoiris", Name = "Gato Arcoíris", Rarity = "RARE", Emoji = "🌈", Value = 1000, InShop = true,
		Description = "Medio gato, medio galleta, todo arcoíris.",
		Ability = { Type = "Speed", Power = 1.6, Duration = 6, Cooldown = 15 } },
	{ Id = "ChicoTienda", Name = "El Chico de la Tienda", Rarity = "RARE", Emoji = "🏪", Value = 1200, InShop = true,
		Description = "Trabaja en el MemeMarket. Siempre te pregunta si quieres redondear.",
		Ability = { Type = "Shield", Power = 1, Duration = 5, Cooldown = 16 } },
	{ Id = "Moai", Name = "Moai", Rarity = "RARE", Emoji = "🗿", Value = 1500, InShop = true,
		Description = "🗿 No dice nada. No lo necesita.",
		Ability = { Type = "Shield", Power = 1, Duration = 6, Cooldown = 18 } },
	-- EPIC
	{ Id = "OgroPantano", Name = "Ogro del Pantano", Rarity = "EPIC", Emoji = "🧅", Value = 3000, InShop = true,
		Description = "Los ogros son como las cebollas: tienen capas.",
		Ability = { Type = "Jump", Power = 1.9, Duration = 6, Cooldown = 14 } },
	{ Id = "RanaTriste", Name = "Rana Triste", Rarity = "EPIC", Emoji = "🐸", Value = 3500, InShop = true,
		Description = "Se siente mal, pero corre bien.",
		Ability = { Type = "Speed", Power = 1.8, Duration = 6, Cooldown = 15 } },
	-- LEGENDARY
	{ Id = "GigaChad", Name = "GigaChad", Rarity = "LEGENDARY", Emoji = "💪", Value = 8000, InShop = true,
		Description = "Mandíbula de acero. Nunca pierde la compostura.",
		Ability = { Type = "Shield", Power = 1, Duration = 8, Cooldown = 20 } },
	{ Id = "HeroeCalvo", Name = "Héroe Calvo de Un Golpe", Rarity = "LEGENDARY", Emoji = "👊", Value = 10000, InShop = true,
		Description = "Entrenó 100 flexiones al día. Ahora todo lo resuelve de un golpe.",
		Ability = { Type = "Dash", Power = 140, Duration = 0, Cooldown = 7 } },
	-- MYTHIC
	{ Id = "InodoroCantante", Name = "Inodoro Cantante", Rarity = "MYTHIC", Emoji = "🚽", Value = 25000, InShop = true,
		Description = "Nadie sabe de dónde salió. Nadie puede dejar de oírlo.",
		Ability = { Type = "Speed", Power = 2.2, Duration = 7, Cooldown = 15 } },
	{ Id = "DiosMeme", Name = "Dios de los Memes", Rarity = "MYTHIC", Emoji = "🌌", Value = 50000, InShop = false,
		Description = "Solo se consigue intercambiando. Si lo ves, presume.",
		Ability = { Type = "Jump", Power = 2.4, Duration = 8, Cooldown = 14 } },
}

local byId = {}
for i, meme in ipairs(MemeCatalog.List) do
	meme.Order = i
	byId[meme.Id] = meme
end

function MemeCatalog.Get(id: any)
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

function MemeCatalog.GetRarity(id: any)
	local meme = MemeCatalog.Get(id)
	return meme and MemeCatalog.Rarities[meme.Rarity] or MemeCatalog.Rarities.COMMON
end

-- Ordenado por rareza (de mayor a menor) y luego por orden del catálogo.
function MemeCatalog.Sort(ids: { string }): { string }
	table.sort(ids, function(a, b)
		local ra, rb = MemeCatalog.GetRarity(a).Order, MemeCatalog.GetRarity(b).Order
		if ra ~= rb then
			return ra > rb
		end
		return (byId[a] and byId[a].Order or 0) < (byId[b] and byId[b].Order or 0)
	end)
	return ids
end

return MemeCatalog
