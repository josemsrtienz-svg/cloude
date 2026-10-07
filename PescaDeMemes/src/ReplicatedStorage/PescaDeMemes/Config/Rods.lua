--[[
	PescaDeMemes • Rods (ModuleScript)
	ReplicatedStorage > PescaDeMemes > Config > Rods

	Cañas, mochilas-acuario y objetos de la tienda.
	La caña es una herramienta (slot 1 de la barra). Cada caña sube la CAPACIDAD de peso y cambia algo del minijuego:
	  Capacity      kg que aguanta sin riesgo.
	  GreenWidth    multiplicador del ancho de la zona verde.
	  FillSpeed     multiplicador de la velocidad del progreso.
	  Luck          multiplicador de suerte (rarezas altas).
	  RedTolerance  segundos que aguanta el sedal en la zona roja antes de romperse.
	  RepairCost    precio de reparación si se rompe (fallar un TIRÓN con sobrecarga la rompe). 0 = irrompible.
	  Hooks         memes que puedes enganchar en una inmersión.
	  MaxDepth      metros que baja el anzuelo (más hondo = memes más raros).
	  DiveSpeed     metros por segundo que baja el anzuelo.

	Mochila-acuario (Aquariums): lo que llevas a la espalda. Capacity = kg totales que caben
	(el TAMAÑO de un meme es su peso redondeado hacia arriba). Cuando está llena no puedes pescar:
	vuelve a tu parcela y se descarga sola.
]]

local Rods = {}

local RGB = Color3.fromRGB

Rods.List = {
	{ Id = "Palo", Name = "Caña de Palo", Emoji = "🪵", Price = 0, RepairCost = 0, Capacity = 12, Hooks = 1, MaxDepth = 50, DiveSpeed = 6,
		GreenWidth = 1.0, FillSpeed = 1.0, Luck = 1.0, RedTolerance = 0.5,
		Color = RGB(150, 105, 60), Description = "Un palo con hilo. 1 anzuelo y 50 m, pero nunca se rompe." },
	{ Id = "Fibra", Name = "Caña de Fibra", Emoji = "🎣", Price = 1500, RepairCost = 300, Capacity = 50, Hooks = 2, MaxDepth = 150, DiveSpeed = 10,
		GreenWidth = 1.2, FillSpeed = 1.0, Luck = 1.05, RedTolerance = 0.55,
		Color = RGB(70, 170, 255), Description = "2 anzuelos y baja a 150 m (Arrecife Meme). Zona verde más ancha." },
	{ Id = "Turbo", Name = "Caña Turbo", Emoji = "⚡", Price = 15000, RepairCost = 3000, Capacity = 150, Hooks = 3, MaxDepth = 300, DiveSpeed = 16,
		GreenWidth = 1.2, FillSpeed = 1.3, Luck = 1.1, RedTolerance = 0.6,
		Color = RGB(255, 205, 40), Description = "3 anzuelos y baja a 300 m (Abismo Brainrot). El progreso sube mucho más rápido." },
	{ Id = "Abisal", Name = "Caña Abisal", Emoji = "🌊", Price = 150000, RepairCost = 30000, Capacity = 400, Hooks = 4, MaxDepth = 600, DiveSpeed = 25,
		GreenWidth = 1.3, FillSpeed = 1.3, Luck = 1.2, RedTolerance = 0.8,
		Color = RGB(120, 60, 200), Description = "4 anzuelos y baja a 600 m: la Fosa Abisal, donde viven los secretos." },
}

-- Style = diseño del modelo (Shared/GearModels): cada mochila es distinta, no solo de color.
-- Las grandes existen para que un SECRETO (300–2.000 kg, o más si es colosal) quepa… ocupando media mochila.
Rods.Aquariums = {
	{ Tier = 1, Name = "Pecera de Bolsillo", Style = "Jar", Price = 0, Capacity = 25, Color = Color3.fromRGB(150, 220, 255) },
	{ Tier = 2, Name = "Mochila Pecera", Style = "Bowl", Price = 1500, Capacity = 80, Color = Color3.fromRGB(90, 210, 110) },
	{ Tier = 3, Name = "Acuario Mochila", Style = "Tank", Price = 10000, Capacity = 250, Color = Color3.fromRGB(70, 160, 255) },
	{ Tier = 4, Name = "Gran Tanque", Style = "Barrel", Price = 60000, Capacity = 800, Color = Color3.fromRGB(185, 90, 255) },
	{ Tier = 5, Name = "Océano Portátil", Style = "Globe", Price = 300000, Capacity = 2500, Color = Color3.fromRGB(255, 190, 40) },
	{ Tier = 6, Name = "Submarino Amarillo", Style = "Sub", Price = 1200000, Capacity = 5000, Color = Color3.fromRGB(255, 210, 40) },
	{ Tier = 7, Name = "Cofre Pecera", Style = "Chest", Price = 4000000, Capacity = 10000, Color = Color3.fromRGB(150, 95, 50) },
	{ Tier = 8, Name = "Pecera Cohete", Style = "Rocket", Price = 12000000, Capacity = 20000, Color = Color3.fromRGB(235, 60, 60) },
	{ Tier = 9, Name = "Burbuja Neón", Style = "Neon", Price = 35000000, Capacity = 40000, Color = Color3.fromRGB(255, 90, 220) },
	{ Tier = 10, Name = "Acuario Real", Style = "Royal", Price = 100000000, Capacity = 80000, Color = Color3.fromRGB(255, 200, 50) },
	{ Tier = 11, Name = "Pecera Cósmica", Style = "Cosmic", Price = 300000000, Capacity = 160000, Color = Color3.fromRGB(70, 40, 160) },
	{ Tier = 12, Name = "Agujero Negro de Bolsillo", Style = "BlackHole", Price = 1000000000, Capacity = 350000, Color = Color3.fromRGB(150, 60, 255) },
}

function Rods.GetAquarium(tier: any): any?
	if type(tier) ~= "number" then
		return nil
	end
	return Rods.Aquariums[tier]
end

-- ===== OBJETOS =====
-- Solo funcionan si los llevas EQUIPADOS, y hay pocos huecos: empiezas con 1 (más con el pase de Robux
-- y, en el futuro, con el Renacer). Así hay estrategia: ¿qué te llevas a esta inmersión?
--   Kind "Consumable": se compran por unidades y se gastan. Kind "Gear": se compran una vez y son para siempre.
Rods.Items = {
	SedalReforzado = { Id = "SedalReforzado", Name = "Sedal Reforzado", Emoji = "🧵", Kind = "Consumable", Price = 500,
		CapacityBonus = 0.25, Color = Color3.fromRGB(255, 90, 150),
		Description = "Equipado: se gasta 1 en cada lanzamiento y tu caña aguanta +25 % de peso." },
	Linterna = { Id = "Linterna", Name = "Linterna", Emoji = "🔦", Kind = "Gear", Price = 20000, Color = Color3.fromRGB(255, 220, 90),
		Description = "En las capas OSCURAS (Abismo y Fosa) sin linterna no ves qué meme es ni cuánto pesa." },
	Iman = { Id = "Iman", Name = "Imán", Emoji = "🧲", Kind = "Gear", Price = 60000, GrabBonus = 1.2, Color = Color3.fromRGB(230, 60, 60),
		Description = "El anzuelo engancha desde más lejos (+1,2 m). Más fácil coger lo que pasa rápido." },
	RedDorada = { Id = "RedDorada", Name = "Red Dorada", Emoji = "🥅", Kind = "Consumable", Price = 25000, Color = Color3.fromRGB(255, 200, 50),
		Description = "Equipada: en una pelea pulsa 🥅 y lo enganchas SIN pelear. No sirve con SECRETOS." },
}
Rods.ItemOrder = { "SedalReforzado", "Linterna", "Iman", "RedDorada" }
Rods.BaseItemSlots = 1
Rods.MaxItemSlots = 4

local byId: { [string]: any } = {}
for i, rod in ipairs(Rods.List) do
	rod.Order = i
	byId[rod.Id] = rod
end

function Rods.Get(id: any): any?
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

function Rods.GetItem(id: any): any?
	if type(id) ~= "string" then
		return nil
	end
	return Rods.Items[id]
end

return Rods
