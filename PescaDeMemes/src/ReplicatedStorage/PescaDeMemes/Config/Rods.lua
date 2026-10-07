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

-- PERKS (lo que hace distinta a cada caña, además de los números):
--   GrabBonus   +metros de radio de enganche (como el Imán; se suman)
--   GoldenMult  × probabilidad de meme DORADO
--   GiantMult   × probabilidad de ejemplar GIGANTE / COLOSAL
--   SeeDark     ves los memes en las capas oscuras sin Linterna (la caña ya ilumina)
-- Desde la Abisal todas llegan al fondo (600 m): las siguientes ganan kg, anzuelos, suerte y perks.
Rods.List = {
	{ Id = "Palo", Name = "Caña de Palo", Emoji = "🪵", Price = 0, RepairCost = 0, Capacity = 12, Hooks = 1, MaxDepth = 50, DiveSpeed = 6,
		GreenWidth = 1.0, FillSpeed = 1.0, Luck = 1.0, RedTolerance = 0.5,
		Color = RGB(150, 105, 60), Description = "Un palo con hilo. 1 anzuelo y 50 m, pero nunca se rompe." },
	{ Id = "Bambu", Name = "Caña de Bambú", Emoji = "🎋", Price = 400, RepairCost = 80, Capacity = 25, Hooks = 1, MaxDepth = 80, DiveSpeed = 7,
		GreenWidth = 1.1, FillSpeed = 1.0, Luck = 1.02, RedTolerance = 0.5,
		Color = RGB(120, 190, 80), Description = "Ligera y flexible: el doble de kg que el palo y baja a 80 m." },
	{ Id = "Fibra", Name = "Caña de Fibra", Emoji = "🎣", Price = 2500, RepairCost = 500, Capacity = 50, Hooks = 2, MaxDepth = 150, DiveSpeed = 10,
		GreenWidth = 1.2, FillSpeed = 1.0, Luck = 1.05, RedTolerance = 0.55,
		Color = RGB(70, 170, 255), Description = "2 anzuelos y baja a 150 m (Arrecife Meme). Zona verde más ancha." },
	{ Id = "Pirata", Name = "Caña Pirata", Emoji = "🏴‍☠️", Price = 12000, RepairCost = 2400, Capacity = 90, Hooks = 2, MaxDepth = 200, DiveSpeed = 12,
		GreenWidth = 1.2, FillSpeed = 1.1, Luck = 1.07, RedTolerance = 0.55, GoldenMult = 2,
		Color = RGB(110, 70, 40), Description = "Olfato de tesoro: el DOBLE de memes dorados. Baja a 200 m." },
	{ Id = "Turbo", Name = "Caña Turbo", Emoji = "⚡", Price = 40000, RepairCost = 8000, Capacity = 150, Hooks = 3, MaxDepth = 300, DiveSpeed = 16,
		GreenWidth = 1.2, FillSpeed = 1.3, Luck = 1.1, RedTolerance = 0.6,
		Color = RGB(255, 205, 40), Description = "3 anzuelos y baja a 300 m (Abismo Brainrot). El progreso sube mucho más rápido." },
	{ Id = "Coral", Name = "Caña de Coral", Emoji = "🪸", Price = 120000, RepairCost = 24000, Capacity = 250, Hooks = 3, MaxDepth = 400, DiveSpeed = 19,
		GreenWidth = 1.25, FillSpeed = 1.3, Luck = 1.14, RedTolerance = 0.65, GrabBonus = 0.8,
		Color = RGB(255, 120, 130), Description = "Sus ramas de coral enganchan desde más lejos (+0,8 m). Baja a 400 m." },
	{ Id = "Abisal", Name = "Caña Abisal", Emoji = "🌊", Price = 400000, RepairCost = 80000, Capacity = 400, Hooks = 4, MaxDepth = 600, DiveSpeed = 25,
		GreenWidth = 1.3, FillSpeed = 1.3, Luck = 1.2, RedTolerance = 0.8,
		Color = RGB(120, 60, 200), Description = "4 anzuelos y baja a 600 m: la Fosa Abisal, donde viven los secretos." },
	{ Id = "Glaciar", Name = "Caña Glaciar", Emoji = "🧊", Price = 1200000, RepairCost = 240000, Capacity = 700, Hooks = 4, MaxDepth = 600, DiveSpeed = 26,
		GreenWidth = 1.6, FillSpeed = 1.3, Luck = 1.26, RedTolerance = 1.0,
		Color = RGB(150, 220, 255), Description = "El hielo calma la pelea: zona verde enorme y el sedal aguanta más en rojo." },
	{ Id = "Volcanica", Name = "Caña Volcánica", Emoji = "🌋", Price = 3000000, RepairCost = 600000, Capacity = 1100, Hooks = 5, MaxDepth = 600, DiveSpeed = 27,
		GreenWidth = 1.35, FillSpeed = 1.45, Luck = 1.32, RedTolerance = 0.85, GiantMult = 1.5,
		Color = RGB(255, 90, 30), Description = "5 anzuelos. El calor atrae ejemplares GIGANTES (+50 %)." },
	{ Id = "CyberNeon", Name = "Caña Cyber Neón", Emoji = "💾", Price = 7500000, RepairCost = 1500000, Capacity = 1700, Hooks = 5, MaxDepth = 600, DiveSpeed = 28,
		GreenWidth = 1.4, FillSpeed = 1.5, Luck = 1.38, RedTolerance = 0.9, SeeDark = true,
		Color = RGB(60, 240, 255), Description = "Escáner de neón: ves los memes de las capas OSCURAS sin Linterna." },
	{ Id = "Dragon", Name = "Caña del Dragón", Emoji = "🐉", Price = 18000000, RepairCost = 3600000, Capacity = 2500, Hooks = 6, MaxDepth = 600, DiveSpeed = 29,
		GreenWidth = 1.4, FillSpeed = 1.55, Luck = 1.45, RedTolerance = 0.95, GiantMult = 2.5,
		Color = RGB(200, 30, 40), Description = "6 anzuelos. El rugido del dragón: ×2,5 de GIGANTES y COLOSALES." },
	{ Id = "Galactica", Name = "Caña Galáctica", Emoji = "🪐", Price = 45000000, RepairCost = 9000000, Capacity = 3500, Hooks = 6, MaxDepth = 600, DiveSpeed = 30,
		GreenWidth = 1.45, FillSpeed = 1.6, Luck = 1.52, RedTolerance = 1.0, SeeDark = true, GrabBonus = 0.6,
		Color = RGB(60, 40, 160), Description = "Gravedad de planeta: engancha desde más lejos y ve en la oscuridad." },
	{ Id = "Arcoiris", Name = "Caña Arcoíris", Emoji = "🌈", Price = 100000000, RepairCost = 20000000, Capacity = 5000, Hooks = 7, MaxDepth = 600, DiveSpeed = 31,
		GreenWidth = 1.5, FillSpeed = 1.65, Luck = 1.6, RedTolerance = 1.0, GoldenMult = 2.5,
		Color = RGB(255, 120, 200), Description = "7 anzuelos. Al final del arcoíris hay oro: ×2,5 de memes DORADOS." },
	{ Id = "Diamante", Name = "Caña de Diamante", Emoji = "💎", Price = 220000000, RepairCost = 44000000, Capacity = 7000, Hooks = 7, MaxDepth = 600, DiveSpeed = 32,
		GreenWidth = 1.5, FillSpeed = 1.7, Luck = 1.68, RedTolerance = 1.05, GoldenMult = 3, GrabBonus = 1,
		Color = RGB(170, 235, 255), Description = "Brilla tanto que atrae dorados (×3) y engancha desde lejos (+1 m)." },
	{ Id = "Brainrot", Name = "Caña Brainrot Suprema", Emoji = "🧠", Price = 500000000, RepairCost = 100000000, Capacity = 10000, Hooks = 8, MaxDepth = 600, DiveSpeed = 33,
		GreenWidth = 1.55, FillSpeed = 1.75, Luck = 1.77, RedTolerance = 1.1, SeeDark = true, GiantMult = 2, GrabBonus = 1,
		Color = RGB(255, 110, 180), Description = "8 anzuelos. Cerebro meme: ve en la oscuridad, ×2 gigantes y +1 m de enganche." },
	{ Id = "Divina", Name = "Caña Divina", Emoji = "😇", Price = 1200000000, RepairCost = 240000000, Capacity = 15000, Hooks = 8, MaxDepth = 600, DiveSpeed = 35,
		GreenWidth = 1.6, FillSpeed = 1.8, Luck = 1.88, RedTolerance = 1.2, SeeDark = true, GoldenMult = 3, GiantMult = 3, GrabBonus = 1.5,
		Color = RGB(255, 235, 150), Description = "La caña definitiva: todo a la vez. Dorados ×3, gigantes ×3, ve en la oscuridad y +1,5 m." },
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
	-- ===== CEBOS (Alpha): consumibles; equipados, se gasta 1 de cada en cada lanzamiento =====
	CeboPicante = { Id = "CeboPicante", Name = "Cebo Picante", Emoji = "🌶️", Kind = "Consumable", Bait = true, Price = 3000, LuckMult = 1.5,
		Color = Color3.fromRGB(230, 60, 40), Description = "Equipado: +50 % de memes RAROS o mejores en ese lanzamiento." },
	CeboDorado = { Id = "CeboDorado", Name = "Cebo Dorado", Emoji = "🪙", Kind = "Consumable", Bait = true, Price = 8000, GoldenMult = 3,
		Color = Color3.fromRGB(255, 200, 50), Description = "Equipado: el TRIPLE de memes dorados en ese lanzamiento." },
	CeboPesado = { Id = "CeboPesado", Name = "Cebo Pesado", Emoji = "⚓", Kind = "Consumable", Bait = true, Price = 5000, GiantMult = 2.5,
		Color = Color3.fromRGB(120, 125, 140), Description = "Equipado: ×2,5 de ejemplares GIGANTES y COLOSALES." },
	CeboLunar = { Id = "CeboLunar", Name = "Cebo Lunar", Emoji = "🌙", Kind = "Consumable", Bait = true, Price = 15000, MutationMult = 2,
		Color = Color3.fromRGB(170, 110, 255), Description = "Equipado: el DOBLE de mutaciones (💧⚡🌙) con lluvia, tormenta o luna llena." },
}
Rods.ItemOrder = { "SedalReforzado", "Linterna", "Iman", "RedDorada", "CeboPicante", "CeboDorado", "CeboPesado", "CeboLunar" }
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
