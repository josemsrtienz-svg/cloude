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
	{ Id = "Palo", Name = "Caña de Palo", Emoji = "🪵", Price = 0, RepairCost = 0, Capacity = 12, Hooks = 1, MaxDepth = 15, DiveSpeed = 3,
		GreenWidth = 1.0, FillSpeed = 1.0, Luck = 1.0, RedTolerance = 0.5,
		Color = RGB(150, 105, 60), Description = "Un palo con hilo. 1 anzuelo y poca profundidad, pero nunca se rompe." },
	{ Id = "Fibra", Name = "Caña de Fibra", Emoji = "🎣", Price = 600, RepairCost = 150, Capacity = 50, Hooks = 2, MaxDepth = 25, DiveSpeed = 3.5,
		GreenWidth = 1.2, FillSpeed = 1.0, Luck = 1.05, RedTolerance = 0.55,
		Color = RGB(70, 170, 255), Description = "2 anzuelos y baja a 25 m. Zona verde más ancha." },
	{ Id = "Turbo", Name = "Caña Turbo", Emoji = "⚡", Price = 4000, RepairCost = 1000, Capacity = 150, Hooks = 3, MaxDepth = 40, DiveSpeed = 4.5,
		GreenWidth = 1.2, FillSpeed = 1.3, Luck = 1.1, RedTolerance = 0.6,
		Color = RGB(255, 205, 40), Description = "3 anzuelos y baja a 40 m. El progreso sube mucho más rápido." },
	{ Id = "Abisal", Name = "Caña Abisal", Emoji = "🌊", Price = 25000, RepairCost = 6000, Capacity = 400, Hooks = 4, MaxDepth = 60, DiveSpeed = 5.5,
		GreenWidth = 1.3, FillSpeed = 1.3, Luck = 1.2, RedTolerance = 0.8,
		Color = RGB(120, 60, 200), Description = "4 anzuelos y baja a 60 m, donde viven las bestias." },
}

Rods.Aquariums = {
	{ Tier = 1, Name = "Pecera de Bolsillo", Emoji = "🫙", Price = 0, Capacity = 25, Color = Color3.fromRGB(150, 220, 255) },
	{ Tier = 2, Name = "Mochila Pecera", Emoji = "🎒", Price = 1500, Capacity = 80, Color = Color3.fromRGB(90, 210, 110) },
	{ Tier = 3, Name = "Acuario Mochila", Emoji = "🐠", Price = 9000, Capacity = 250, Color = Color3.fromRGB(70, 160, 255) },
	{ Tier = 4, Name = "Gran Tanque", Emoji = "🛢️", Price = 45000, Capacity = 800, Color = Color3.fromRGB(185, 90, 255) },
	{ Tier = 5, Name = "Océano Portátil", Emoji = "🌊", Price = 200000, Capacity = 2500, Color = Color3.fromRGB(255, 190, 40) },
}

function Rods.GetAquarium(tier: any): any?
	if type(tier) ~= "number" then
		return nil
	end
	return Rods.Aquariums[tier]
end

Rods.Items = {
	SedalReforzado = { Id = "SedalReforzado", Name = "Sedal Reforzado", Emoji = "🧵", Price = 120,
		CapacityBonus = 0.25, Description = "+25 % de capacidad durante UN lanzamiento." },
}

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
